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
    // use sui::dynamic_field as df;/

    const EInvalidLot:u64 = 2;
    const EInvalidLeverage:u64 = 3;
    const EInvalidPositionType:u64 = 4;
    const EInvalidDirection:u64 = 5;
    const ENoPermission:u64 = 6;
    const EInvalidPositionStatus:u64 = 7;
    const ENumericOverflow:u64 = 8;
    const ERiskControlBlockingExposure:u64 = 9;

    const MAX_U64_VALUE: u128 = 18446744073709551615;
    /// The exposure ratio should not exceed 70% of the current pool,
    /// so as to avoid the risk that the platform's current pool is empty.
    const POSITION_DIFF_PROPORTION: u64 = 70;
    const POSITION_DENOMINATOR: u64 = 100;
    
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
        position_type: u8,
        /// Position status: 1 normal, 2 normal closing, 3 Forced closing, 4 pending.
        position_status: u8,
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
        profit: u64,
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

    public fun get_margin_size<P,T>(market: &Market<P,T>,position: &Position<T>) :u64 {
        margin_size(
            get_fund_size<T>(position),
            (position.leverage as u64),
            market::get_margin_rate(market),
            market::get_denominator(market),
        )
    }

    fun margin_size(fund_size:u64,leverage:u64, margin_rate: u64,denominator: u64) :u64{
        let r = (fund_size as u128) / (leverage as u128) * (margin_rate as u128) / (denominator as u128);
        (r as u64)
    }
    /// get Floating P/L
    public fun get_pl<T>(position: &Position<T>,price: &Price) :u64 {
        if (position.direction == 1) {
            fund_size(position.size,position.lot,market::get_sell_price(price)) - get_fund_size<T>(position)
        } else {
            get_fund_size<T>(position) - fund_size(position.size,position.lot,market::get_direction_price(price,2))
        }
    }

    fun create_position_inner<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        leverage: u8,
        position_type: u8,
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
            position_type,
            position_status:1,
            direction,
            size: market::get_size(market),
            lot,
            open_price: market::get_direction_price(price,direction),
            open_spread : market::get_spread(market),
            open_real_price: market::get_real_price(price),
            close_price: 0,
            close_spread: 0,
            close_real_price: 0,
            profit: 0,
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
        let margin = get_margin_size<P,T>(market,&position);
        position.margin = margin;
        if ( position_type == 2 ){
            balance::join(&mut position.margin_balance,account::split_balance(account,margin));
        };
        inc_margin<P,T>(market,account,position_type,direction,margin);
        position
    }

    fun inc_margin<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position_type: u8,
        direction: u8,
        margin: u64
    ) {
        account::inc_margin_total(account,margin);
        if ( position_type == 1 ){
            account::inc_margin_full_total(account,margin);
            // market::
            if ( direction == 1 ){
                account::inc_margin_full_buy_total(account,margin);
                market::inc_long_position_totail(market,margin);
            } else {
                account::inc_margin_full_sell_total(account,margin);
                market::inc_short_position_totail(market,margin);
            };
        } else {
            account::inc_margin_independent_total(account,margin);
            if ( direction == 1 ){
                account::inc_margin_independent_buy_total(account,margin);
                market::inc_long_position_totail(market,margin);
            } else {
                account::inc_margin_independent_sell_total(account,margin);
                market::inc_short_position_totail(market,margin);
            };
        };
    }

    fun dec_margin<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        position_type: u8,
        direction: u8,
        margin: u64
    ) {
        account::dec_margin_total(account,margin);
        if ( position_type == 1 ){
            account::dec_margin_full_total(account,margin);
            if ( direction == 1 ){
                account::dec_margin_full_buy_total(account,margin);
                market::dec_long_position_totail(market,margin);
            } else {
                account::dec_margin_full_sell_total(account,margin);
                market::dec_short_position_totail(market,margin);
            };
        } else {
            account::dec_margin_independent_total(account,margin);
            if ( direction == 1 ){
                account::dec_margin_independent_buy_total(account,margin);
                market::dec_long_position_totail(market,margin);
            } else {
                account::dec_margin_independent_sell_total(account,margin);
                market::dec_short_position_totail(market,margin);
            };
        };
    }

    fun collect_insurance<P,T>(market: &mut Market<P,T>,account: &mut Account<T>,margin: u64){
        let insurance_rate = market::get_insurance_rate(market);
        let insurance_size = (margin as u128) * (insurance_rate as u128) / (market::get_denominator(market) as u128);
        let insurance_balance = account::split_balance(account,(insurance_size as u64));
        pool::join_insurance_balance<P,T>(market::get_pool_mut<P,T>(market),insurance_balance);
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
            assert!(position.position_status == 1,EInvalidPositionStatus);

            let fund_size_old = get_fund_size<T>(position);
            let fund_size_new = fund_size(size, lot, market::get_direction_price(price,direction));

            // Reset average price
            market::set_direction_price(price,direction, (fund_size_old + fund_size_new) / (size * lot + position.size * position.lot));
            position.open_price = market::get_direction_price(price,direction);
            position.open_spread = market::get_spread(market);
            position.open_real_price = market::get_real_price(price);
            position.lot = position.lot + lot;
            position.leverage = leverage;
            // todo : set open time
            position.open_time = 0;

            let margin_old = position.margin;
            let position_type = position.position_type;

            let margin_new = margin_size(
                fund_size_new,
                (leverage as u64),
                market::get_margin_rate(market),
                market::get_denominator(market),
            );
            position.margin = margin_new;

            dec_margin<P,T>(market,account,position_type,direction,margin_old);
            inc_margin<P,T>(market,account,position_type,direction,margin_new);
            collect_insurance<P,T>(market,account,margin_new);
            true
        } else {
            false
        }
    }

    public fun get_equity<P,T>(
        market_list: &mut MarketList,
        curr_market: &Market<P,T>,
        curr_price: &Price,
        account: &Account<T>,
    ) {
        let ids = account::get_pfk_ids<T>(account);
        let n = vector::length(&ids);
        let i = 0;
        while ( i < n ){
            let id = vector::borrow(&ids,i);
            let ps: &Position<T> = dof::borrow(account::get_uid(account),*id);

            if ( ps.position_status == 1 ){
                let curr_market_id = object::uid_to_inner(market::get_uid(curr_market));
                let (market, price) = if ( ps.market_id == curr_market_id ){
                    (curr_market, curr_price)
                } else {
                    let m: &Market<P,T> = dof::borrow(market::get_list_uid(market_list),ps.market_id);
                    let price = market::get_price(m);
                    (m, &price)
                };
                // let fund_size = get_fund_size<P,T>(p);
                // let margin_size = get_margin_size<P,T>(market,p);
                // let margin_rate = (margin_size as u128) * (market::get_denominator(market) as u128) / (fund_size as u128);
                // assert!(margin_rate <= (market::get_max_margin_rate(market) as u128), EInvalidMarginRate);
            };
            i = i + 1;
        };
    }
    
    public fun risk_assertion<P,T>(
        market: &Market<P,T>,
        account: &Account<T>,
        position: &Position<T>,
        pre_exposure: u64,
    ){
            let exposure = market::get_exposure<P,T>(market);
            let total_liquidity = market::get_total_liquidity<P,T>(market);
            assert!(
                exposure <= total_liquidity * POSITION_DIFF_PROPORTION / POSITION_DENOMINATOR && exposure > pre_exposure,
                ERiskControlBlockingExposure
            );
    }

    /// The value of lot field in encrypted transaction is 0 by default
    public entry fun open_position<P,T>(
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
            // transfer::share_object(position);
        };
    }
}