module scale::position {
    use sui::object::{Self,UID,ID};
    // use sui::coin::{Self,Coin};
    use sui::balance::{Self,Balance};
    use scale::market::{Self,Market,Price,MarketList};
    use scale::account::{Self,Account,PFK};
    use sui::tx_context::{Self,TxContext};
    // use sui::transfer;
    use sui::dynamic_object_field as dof;
    use scale::pool;
    use std::vector;
    use scale::i64::{Self, I64};
    // use sui::dynamic_field as df;/

    
    const EInvalidLot:u64 = 2;
    const EInvalidLeverage:u64 = 3;
    const EInvalidPositionType:u64 = 4;
    const EInvalidDirection:u64 = 5;
    const ENoPermission:u64 = 6;
    const EInvalidPositionStatus:u64 = 7;
    const ENumericOverflow:u64 = 8;
    const EInvalidMarketStatus:u64 = 9;
    const ERiskControlBlockingExposure:u64 = 10;
    const ERiskControlBurstRate:u64 = 11;
    const RiskControlBlockingFundSize:u64 = 12;
    const RiskControlBlockingFundPool:u64 = 13;
    const EInvalidMarketId:u64 = 14;
    const EInvalidAccountId:u64 = 15;
    const ERiskControlNegativeEquity:u64 = 16;
    const EBurstConditionsNotMet:u64 = 17;

    const MAX_U64_VALUE: u128 = 18446744073709551615;

    const DENOMINATOR: u64 = 10000;
    /// The exposure ratio should not exceed 70% of the current pool,
    /// so as to avoid the risk that the platform's current pool is empty.
    const POSITION_DIFF_PROPORTION: u64 = 7000;
    /// The liquidation line ratio means that if the user's margin loss exceeds this ratio in one quotation,
    /// the system will be liquidated and the position will be forced to close.
    const BURST_RATE: u64 = 5000;
    /// so as to avoid the risk of malicious position opening.
    const POSITION_PROPORTION: u64 = 15000;
    /// The size of a single position shall not be greater than 20% of the exposure
    const POSITION_PROPORTION_ONE: u64 = 2000;

    struct Position<phantom T> has key,store {
        id: UID,
        offset: u64,
        /// Initial position margin
        margin: u64,
        /// Current actual margin balance of independent
        margin_balance: Balance<T>,
        /// leverage size
        leverage: u8,
        /// 1 full position mode, 2 independent position modes.
        type: u8,
        /// Position status: 1 normal, 2 normal closing, 3 Forced closing, 4 pending.
        status: u8,
        /// 1 buy long, 2 sell short.
        direction: u8,
        /// the position size
        size: u64,
        /// lot size
        lot: u64,
        /// Opening quotation (expected opening price under the listing mode)
        open_price: u64,
        /// Point difference data on which the quotation is based
        open_spread: u64,
        // Actual quotation currently obtained
        open_real_price: u64,
        /// Closing quotation
        close_price: u64,
        /// Point difference data on which the quotation is based
        close_spread: u64,
        // Actual quotation currently obtained
        close_real_price: u64,
        // PL
        profit: I64,
        /// Automatic profit stop price
        stop_surplus_price: u64,
        /// Automatic stop loss price
        stop_loss_price: u64,
        /// Order creation time
        create_time: u64,
        open_time: u64,
        close_time: u64,
        /// The effective time of the order.
        /// If the position is not opened successfully after this time in the order listing mode,
        /// the order will be closed directly
        validity_time: u64,
        /// Opening operator (the user manually, or the clearing robot in the listing mode)
        open_operator: address,
        /// Account number of warehouse closing operator (user manual, or clearing robot Qiangping)
        close_operator: address,
        /// Market account number of the position
        market_id: ID,
        account_id: ID,
    }
    
    public fun get_fund_size<T>(position: &Position<T>) :u64 {
        fund_size(position.size , position.lot , position.open_price)
    }

    fun fund_size(size:u64, lot:u64, price:u64) :u64 {
        let r = (size as u128) * (lot as u128) * (price as u128);
        assert!(r <= MAX_U64_VALUE ,ENumericOverflow);
        (r as u64)
    }

    fun get_size<T>(position: &Position<T>) :u64{
        size(position.lot,position.size)
    }

    fun size(lot:u64, size:u64) :u64 {
        let r = (size as u128) * (lot as u128);
        assert!(r <= MAX_U64_VALUE ,ENumericOverflow);
        (r as u64)
    }

    public fun get_margin_size<P,T>(market: &Market<P,T>,position: &Position<T>) :u64 {
        margin_size(
            get_fund_size<T>(position),
            (position.leverage as u64),
            market::get_margin_fee(market),
            market::get_denominator(),
        )
    }

    fun margin_size(fund_size:u64,leverage:u64, margin_fee: u64,denominator: u64) :u64{
        let r = (fund_size as u128) / (leverage as u128) * (margin_fee as u128) / (denominator as u128);
        (r as u64)
    }

    /// get Floating P/L
    public fun get_pl<T>(position: &Position<T>,price: &Price) :I64 {
        if (position.direction == 1) {
            i64::u64_sub(fund_size(position.size,position.lot,market::get_sell_price(price)) , get_fund_size<T>(position))
        } else {
            i64::u64_sub(get_fund_size<T>(position) , fund_size(position.size,position.lot,market::get_buy_price(price)))
        }
    }

    public fun get_position_fund_fee<P,T>(
        market: &Market<P,T>,
        position: &Position<T>,
    ) :I64 {
        let dominant_direction = market::get_dominant_direction(market);
        if (dominant_direction == 3){
            return i64::new(0,false)
        };
        if (position.direction == market::get_dominant_direction(market)) {
            i64::new(get_fund_size(position) * market::get_fund_fee(market),true)
        } else {
            let max = market::get_max_position_total(market);
            let min = market::get_min_position_total(market);
            i64::new(max * market::get_fund_fee(market) * get_fund_size(position) / min,false)
        }
    }

    public fun get_equity<P,T>(
        market_list: &MarketList,
        account: &Account<T>,
    ) :I64 {
        let ids = account::get_pfk_ids<T>(account);
        let n = vector::length(&ids);
        let i = 0;
        let pl = i64::new(0,false);
        while ( i < n ){
            let id = vector::borrow(&ids,i);
            let ps: &Position<T> = dof::borrow(account::get_uid(account),*id);

            if ( ps.status == 1 ){
                let market: &Market<P,T> = dof::borrow(market::get_list_uid(market_list),ps.market_id);
                let price = market::get_price(market);
                pl = i64::i64_add(&pl,&i64::i64_add(&get_position_fund_fee(market,ps),&get_pl<T>(ps,&price)));
            };
            i = i + 1;
        };
        i64::inc_u64(&mut pl,account::get_balance(account));
        pl
    }

    fun create_position_inner<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        leverage: u8,
        type: u8,
        direction: u8,
        lot: u64,
        price: &Price,
        ctx: &mut TxContext
    ) :Position<T> {
        let offset = account::get_offset(account) + 1;
        let position = Position<T> {
            id: object::new(ctx),
            offset,
            margin: 0,
            margin_balance: balance::zero<T>(),
            leverage,
            type,
            status:1,
            direction,
            size: market::get_size(market),
            lot,
            open_price: market::get_direction_price(price,direction),
            open_spread : market::get_spread(price),
            open_real_price: market::get_real_price(price),
            close_price: 0,
            close_spread: 0,
            close_real_price: 0,
            profit: i64::new(0,false),
            stop_surplus_price: 0,
            stop_loss_price: 0,
            create_time: 0,
            open_time: 0,
            close_time: 0,
            validity_time:0 ,
            open_operator: tx_context::sender(ctx),
            close_operator: @0x0,
            market_id: object::id(market),
            account_id: object::id(account),
        };
        let fund_size = get_fund_size(&position);
        let margin = margin_size(
            fund_size,
            (position.leverage as u64),
            market::get_margin_fee(market),
            market::get_denominator(),
        );
        position.margin = margin;
        account:: set_offset(account,offset);
        let pre_exposure = market::get_exposure<P,T>(market);
        inc_margin<P,T>(market,account,type,direction,margin,fund_size);
        risk_assertion<P,T>(
            market,
            fund_size,
            direction,
            pre_exposure,
        );
        if ( type == 2 ){
            balance::join(&mut position.margin_balance,account::split_balance(account,margin));
        };
        collect_insurance<P,T>(market,account,margin);
        collect_spread<P,T>(market,position.open_spread,size(lot,position.size));
        position
    }

    fun inc_margin<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position_type: u8,
        direction: u8,
        margin: u64,
        fund_size: u64
    ) {
        account::inc_margin_total(account,margin);
        if ( position_type == 1 ){
            account::inc_margin_full_total(account,margin);
            // market::
            if ( direction == 1 ){
                account::inc_margin_full_buy_total(account,margin);
                market::inc_long_position_total(market,fund_size);
            } else {
                account::inc_margin_full_sell_total(account,margin);
                market::inc_short_position_total(market,fund_size);
            };
        } else {
            account::inc_margin_independent_total(account,margin);
            if ( direction == 1 ){
                account::inc_margin_independent_buy_total(account,margin);
                market::inc_long_position_total(market,fund_size);
            } else {
                account::inc_margin_independent_sell_total(account,margin);
                market::inc_short_position_total(market,fund_size);
            };
        };
    }

    fun dec_margin<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position_type: u8,
        direction: u8,
        margin: u64,
        fund_size: u64
    ) {
        account::dec_margin_total(account,margin);
        if ( position_type == 1 ){
            account::dec_margin_full_total(account,margin);
            if ( direction == 1 ){
                account::dec_margin_full_buy_total(account,margin);
                market::dec_long_position_total(market,fund_size);
            } else {
                account::dec_margin_full_sell_total(account,margin);
                market::dec_short_position_total(market,fund_size);
            };
        } else {
            account::dec_margin_independent_total(account,margin);
            if ( direction == 1 ){
                account::dec_margin_independent_buy_total(account,margin);
                market::dec_long_position_total(market,fund_size);
            } else {
                account::dec_margin_independent_sell_total(account,margin);
                market::dec_short_position_total(market,fund_size);
            };
        };
    }

    fun collect_insurance<P,T>(market: &mut Market<P,T>,account: &mut Account<T>,margin: u64){
        let insurance_fee = market::get_insurance_fee(market);
        let insurance_size = (margin as u128) * (insurance_fee as u128) / (market::get_denominator() as u128);
        let insurance_balance = account::split_balance(account,(insurance_size as u64));
        pool::join_insurance_balance<P,T>(market::get_pool_mut<P,T>(market),insurance_balance);
    }

    fun collect_spread<P,T>(market: &mut Market<P,T>,spread: u64, size: u64){
        // let spread_size = (position_fund_size as u128) * (market::get_spread_fee(market) as u128) / (market::get_denominator() as u128);
        let pool = market::get_pool_mut<P,T>(market);
        let spread_balance = pool::split_profit_balance(pool,(size * spread / 2));
        // let balance_value = balance::value(&spread_balance);
        pool::join_spread_profit<P,T>(pool,spread_balance);
        // balance_value
    }

    fun merge_position<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        price: &mut Price,
        pfk: &PFK,
        size: u64,
        leverage: u8,
        direction: u8,
        lot: u64,
    ) :bool {
        // Check if the full position already exists
        if ( account::contains_pfk(account,pfk) ){
            let id = account::get_pfk_id(account,pfk);
            let position: &mut Position<T> = dof::borrow_mut(account::get_uid_mut(account),id);
            assert!(position.status == 1,EInvalidPositionStatus);

            let fund_size_old = get_fund_size<T>(position);
            let fund_size_add = fund_size(size, lot, market::get_direction_price(price,direction));
            let open_spread = market::get_spread(price);
            // Reset average price
            market::set_direction_price(price,direction, (fund_size_old + fund_size_add) / (size * lot + position.size * position.lot));
            position.open_price = market::get_direction_price(price,direction);
            position.open_spread = open_spread;
            position.open_real_price = market::get_real_price(price);
            position.lot = position.lot + lot;
            position.leverage = leverage;
            // todo : set open time
            position.open_time = 0;

            let margin_old = position.margin;
            let position_type = position.type;

            let margin_new = margin_size(
                get_fund_size(position),
                (leverage as u64),
                market::get_margin_fee(market),
                market::get_denominator(),
            );
            position.margin = margin_new;
            let pre_exposure = market::get_exposure(market);
            let fund_size = get_fund_size<T>(position);
            let size = position.size;
            dec_margin<P,T>(market,account,position_type,direction,margin_old,fund_size_old);
            inc_margin<P,T>(market,account,position_type,direction,margin_new,fund_size);
            risk_assertion<P,T>(
                market,
                fund_size,
                direction,
                pre_exposure,
            );
            collect_insurance<P,T>(market,account,margin_new);
            collect_spread<P,T>(market,open_spread,size(lot,size));
            true
        } else {
            false
        }
    }

    fun risk_assertion<P,T>(
        market: &Market<P,T>,
        fund_size: u64,
        direction: u8,
        pre_exposure: u64,
    ){
        let exposure = market::get_exposure<P,T>(market);
        let total_liquidity = market::get_total_liquidity<P,T>(market);
        assert!(
            exposure <= total_liquidity * POSITION_DIFF_PROPORTION / DENOMINATOR && exposure > pre_exposure,
            ERiskControlBlockingExposure
        );
        assert!(
            fund_size < total_liquidity * POSITION_PROPORTION_ONE / DENOMINATOR,
            RiskControlBlockingFundSize
        );
        assert!(
            market::get_curr_position_total(market,direction) < total_liquidity * POSITION_PROPORTION / DENOMINATOR,
            RiskControlBlockingFundPool
        );
    }

    fun check_margin<P,T>(
        market_list: &MarketList,
        account: &Account<T>,
    ){
        let equity = get_equity<P,T>(
            market_list,
            account,
        );
        assert!(!i64::is_negative(&equity), ERiskControlNegativeEquity);
        let margin_used = account::get_margin_used(account);
        if (margin_used > 0) {
            assert!(i64::get_value(&equity) * DENOMINATOR / margin_used > BURST_RATE, ERiskControlBurstRate);
        }
    }
    
    public fun open_position<P,T>(
        market_list: &mut MarketList,
        market_id: ID,
        account: &mut Account<T>,
        lot: u64,
        leverage: u8,
        position_type: u8,
        direction: u8,
        ctx: &mut TxContext
    ) {
        let market: &mut Market<P,T> = dof::borrow_mut(market::get_list_uid_mut(market_list),market_id);
        assert!(market::get_status(market) == 1, EInvalidMarketStatus);
        assert!(lot > 0, EInvalidLot);
        assert!(leverage > 0 && leverage <= market::get_max_leverage(market), EInvalidLeverage);
        assert!(position_type == 1 || position_type == 2, EInvalidPositionType);
        assert!(direction == 1 || direction == 2, EInvalidDirection);
        assert!(tx_context::sender(ctx) == account::get_owner(account), ENoPermission);

        let price = market::get_price(market);
        let size = market::get_size(market);
        let pfk = account::new_PFK<T>(object::id(market),object::id(account),direction);

        let is_marge = {
            if ( position_type == 1 ){
                merge_position<P,T>(market, account, &mut price, &pfk,size, leverage, direction,lot)
            } else {
                false
            }
        };
        // Try to merge positions
        if (!is_marge){
            // If the position is not merged, the position is opened directly
            let position = create_position_inner(
                market,
                account,
                leverage,
                position_type,
                direction,
                lot,
                &price,
                ctx);
            let id = object::uid_to_inner(&position.id);
            dof::add(account::get_uid_mut(account),id,position);
            if ( position_type == 1 ){
                account::add_pfk_id(account,pfk,id);
            };
        };
        check_margin<P,T>(market_list,account);
    }

    public fun close_position<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position: &mut Position<T>,
        ctx: &mut TxContext,
    ){
        let owner = tx_context::sender(ctx);
        assert!(owner == account::get_owner(account), ENoPermission);
        assert!(position.status == 1, EInvalidPositionStatus);
        assert!(market::get_status(market) != 3, EInvalidMarketStatus);
        assert!(object::id(market) == position.market_id, EInvalidMarketId);
        assert!(object::id(account) == position.account_id, EInvalidAccountId);
        settlement_pl<P,T>(market,account,position,owner);
    }

    fun settlement_pl<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position: &mut Position<T>,
        close_operator: address,
    ){
        let price = market::get_price(market);
        let size = size(position.lot,position.size);
        
        position.close_spread = market::get_spread(&price);
        position.close_price = market::get_direction_price(&price,position.direction);
        position.close_real_price = market::get_real_price(&price);
        // todo: update close_time
        position.close_time = 0;
        position.close_operator = close_operator;
        position.status = 2;

        collect_spread<P,T>(market,position.close_spread,size);
        let pl = get_pl(position,&price);

        if (!i64::is_negative(&pl)){
            account::join_balance(account,pool::split_profit_balance(market::get_pool_mut(market),i64::get_value(&pl)));
        }else{
            let loss = if (position.type == 1){
                account::split_balance(account,i64::get_value(&pl))
            }else{
                balance::split(&mut position.margin_balance,i64::get_value(&pl))
            };
            pool::join_profit_balance(market::get_pool_mut(market),loss);
        };
        let margin_balance_value = balance::value(&position.margin_balance);
        account::join_balance(account,balance::split(&mut position.margin_balance,margin_balance_value));
        if (i64::is_negative(&pl)){
            account::dec_profit(account,i64::get_value(&pl));
        }else{
            account::inc_profit(account,i64::get_value(&pl));
        };
        position.profit = pl;
        dec_margin<P,T>(market,account,position.type,position.direction,position.margin,get_fund_size(position));
    }

    public fun burst_position<P,T>(
        market_list: &mut MarketList,
        account: &mut Account<T>,
        position: &mut Position<T>,
        ctx: &mut TxContext,
    ){
        assert!(position.status == 1, EInvalidPositionStatus);
        assert!(object::id(account) == position.account_id, EInvalidAccountId);
        // assert
        {
            let market: &Market<P,T> = dof::borrow(market::get_list_uid(market_list),position.market_id);
            assert!(market::get_status(market) < 3, EInvalidMarketStatus);
            if (position.type == 1){
                let equity = get_equity<P,T>(
                    market_list,
                    account,
                );
                if (!i64::is_negative(&equity)){
                    let margin_used = account::get_margin_used(account);
                    if (margin_used > 0) {
                        assert!(i64::get_value(&equity) * DENOMINATOR / margin_used <= BURST_RATE, EBurstConditionsNotMet);
                    }
                }
            } else {
                let price = market::get_price(market);
                let pl = i64::i64_add(&get_position_fund_fee(market,position),&get_pl<T>(position,&price));
                // equity = pl + margin
                i64::inc_u64(&mut pl,position.margin);
                if (!i64::is_negative(&pl)){
                    assert!(i64::get_value(&pl) * DENOMINATOR / position.margin <= BURST_RATE, EBurstConditionsNotMet);
                }
            }
        };
        let market: &mut Market<P,T> = dof::borrow_mut(market::get_list_uid_mut(market_list),position.market_id);
        settlement_pl<P,T>(market,account,position,tx_context::sender(ctx));
    }
}