module scale::position {
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::balance::{Self,Balance};
    use scale::market::{Self,Market,Price,List};
    use scale::account::{Self,Account,PFK};
    use sui::tx_context::{Self,TxContext};
    use sui::dynamic_object_field as dof;
    use scale::pool;
    use std::vector;
    use scale::i64::{Self, I64};
    use oracle::oracle;
    use scale::event;
    use sui::clock::{Self, Clock};
    // use std::debug;
    // use sui::dynamic_field as df;/

    
    const EInvalidLot:u64 = 602;
    const EInvalidLeverage:u64 = 603;
    const EInvalidPositionType:u64 = 604;
    const EInvalidDirection:u64 = 605;
    const ENoPermission:u64 = 606;
    const EInvalidPositionStatus:u64 = 607;
    const ENumericOverflow:u64 = 608;
    const EInvalidMarketStatus:u64 = 609;
    const ERiskControlBlockingExposure:u64 = 610;
    const ERiskControlBurstRate:u64 = 611;
    const RiskControlBlockingFundSize:u64 = 612;
    const RiskControlBlockingFundPool:u64 = 613;
    const EInvalidMarketId:u64 = 614;
    const EInvalidAccountId:u64 = 615;
    const ERiskControlNegativeEquity:u64 = 616;
    const EBurstConditionsNotMet:u64 = 617;

    const MAX_U64_VALUEU64: u64 = 18446744073709551615;
    const MAX_U64_VALUEU128: u128 = 18446744073709551615;

    const DENOMINATOR: u64 = 10000;
    const DENOMINATORU128: u128 = 10000;
    /// The exposure ratio should not exceed 70% of the current pool,
    /// so as to avoid the risk that the platform's current pool is empty.
    const POSITION_DIFF_PROPORTION: u64 = 7000;
    const POSITION_DIFF_PROPORTIONU128: u128 = 7000;
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
        /// Current actual margin balance of isolated
        margin_balance: Balance<T>,
        /// leverage size
        leverage: u8,
        /// 1 cross position mode, 2 isolated position modes.
        type: u8,
        /// Position status: 1 normal, 2 normal closing, 3 Forced closing, 4 pending.
        status: u8,
        /// 1 buy long, 2 sell short.
        direction: u8,
        /// the position size
        unit_size: u64,
        /// lot size
        lot: u64,
        /// Opening quotation (expected opening price under the listing mode)
        open_price: u64,
        /// Point difference data on which the quotation is based, scale 10000
        open_spread: u64,
        // Actual quotation currently obtained
        open_real_price: u64,
        /// Closing quotation
        close_price: u64,
        /// Point difference data on which the quotation is based , scale 10000
        close_spread: u64,
        // Actual quotation currently obtained
        close_real_price: u64,
        // PL
        profit: I64,
        auto_open_price: u64,
        /// Automatic profit stop price
        stop_surplus_price: u64,
        /// Automatic stop loss price
        stop_loss_price: u64,
        /// Order creation time
        create_time: u64,
        open_time: u64,
        close_time: u64,
        /// The effective time of the order.
        /// If the position is not opened successcrossy after this time in the order listing mode,
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
    public fun get_uid<T>(position: &Position<T>) :&UID {
        &position.id
    }
    public fun get_uid_mut<T>(position: &mut Position<T>) :&mut UID {
        &mut position.id
    }
    public fun get_offset<T>(position: &Position<T>) :u64 {
        position.offset
    }
    public fun get_margin<T>(position: &Position<T>) :u64 {
        position.margin
    }
    public fun get_margin_balance<T>(position: &Position<T>) :u64 {
        balance::value(&position.margin_balance)
    }
    public fun get_leverage<T>(position: &Position<T>) :u8 {
        position.leverage
    }
    public fun get_type<T>(position: &Position<T>) :u8 {
        position.type
    }
    public fun get_status<T>(position: &Position<T>) :u8 {
        position.status
    }
    public fun get_direction<T>(position: &Position<T>) :u8 {
        position.direction
    }
    public fun get_unit_size_value<T>(position: &Position<T>) :u64 {
        position.unit_size
    }
    public fun get_lot<T>(position: &Position<T>) :u64 {
        position.lot
    }
    public fun get_open_price<T>(position: &Position<T>) :u64 {
        position.open_price
    }
    public fun get_open_spread<T>(position: &Position<T>) :u64 {
        position.open_spread
    }
    public fun get_open_real_price<T>(position: &Position<T>) :u64 {
        position.open_real_price
    }
    public fun get_close_price<T>(position: &Position<T>) :u64 {
        position.close_price
    }
    public fun get_close_spread<T>(position: &Position<T>) :u64 {
        position.close_spread
    }
    public fun get_close_real_price<T>(position: &Position<T>) :u64 {
        position.close_real_price
    }
    public fun get_profit<T>(position: &Position<T>) :&I64 {
        &position.profit
    }

    public fun get_stop_surplus_price<T>(position: &Position<T>) :u64 {
        position.stop_surplus_price
    }
    public fun get_stop_loss_price<T>(position: &Position<T>) :u64 {
        position.stop_loss_price
    }
    public fun get_create_time<T>(position: &Position<T>) :u64 {
        position.create_time
    }
    public fun get_open_time<T>(position: &Position<T>) :u64 {
        position.open_time
    }
    public fun get_close_time<T>(position: &Position<T>) :u64 {
        position.close_time
    }
    public fun get_validity_time<T>(position: &Position<T>) :u64 {
        position.validity_time
    }
    public fun get_open_operator<T>(position: &Position<T>) :&address {
        &position.open_operator
    }
    public fun get_close_operator<T>(position: &Position<T>) :&address {
        &position.close_operator
    }
    public fun get_market_id<T>(position: &Position<T>) :&ID {
        &position.market_id
    }
    public fun get_account_id<T>(position: &Position<T>) :&ID {
        &position.account_id
    }
    public fun get_denominator128<T>() :u64 {
        (DENOMINATORU128 as u64)
    }
    public fun get_denominator<T>() :u64 {
        DENOMINATOR
    }
    public fun get_auto_open_price<T>(position: &Position<T>) :u64 {
        position.auto_open_price
    }

    public fun get_fund_size<T>(position: &Position<T>) :u64 {
        fund_size(size(position.unit_size , position.lot) , position.open_real_price)
    }

    public fun fund_size(size :u64, price: u64) :u64 {
        let r = (size as u128) * (price as u128);
        assert!(r <= MAX_U64_VALUEU128 ,ENumericOverflow);
        (r as u64)
    }

    public fun get_size<T>(position: &Position<T>) :u64{
        size(position.lot,position.unit_size)
    }

    fun size(lot: u64, unit_size:u64) :u64 {
        let r = (unit_size as u128) * (lot as u128) / DENOMINATORU128;
        assert!(r <= MAX_U64_VALUEU128 ,ENumericOverflow);
        (r as u64)
    }

    public fun get_margin_size<T>(market: &Market,position: &Position<T>) :u64 {
        margin_size(
            get_fund_size<T>(position),
            position.leverage,
            market::get_margin_fee(market),
        )
    }

    fun margin_size(fund_size: u64, leverage: u8, margin_fee: u64) :u64{
        let r = (fund_size as u128) / (leverage as u128) * (margin_fee as u128) / (DENOMINATOR as u128);
        (r as u64)
    }

    fun inc_margin<T>(
        market: &mut Market,
        account: &mut Account<T>,
        position_type: u8,
        direction: u8,
        margin: u64,
        fund_size: u64
    ) {
        account::inc_margin_total(account,margin);
        if ( position_type == 1 ){
            account::inc_margin_cross_total(account,margin);
            if ( direction == 1 ){
                account::inc_margin_cross_buy_total(account,margin);
                market::inc_long_position_total(market,fund_size);
            } else {
                account::inc_margin_cross_sell_total(account,margin);
                market::inc_short_position_total(market,fund_size);
            };
        } else {
            account::inc_margin_isolated_total(account,margin);
            if ( direction == 1 ){
                account::inc_margin_isolated_buy_total(account,margin);
                market::inc_long_position_total(market,fund_size);
            } else {
                account::inc_margin_isolated_sell_total(account,margin);
                market::inc_short_position_total(market,fund_size);
            };
        };
    }

    fun dec_margin<T>(
        market: &mut Market,
        account: &mut Account<T>,
        position_type: u8,
        direction: u8,
        margin: u64,
        fund_size: u64
    ) {
        account::dec_margin_total(account,margin);
        if ( position_type == 1 ){
            account::dec_margin_cross_total(account,margin);
            if ( direction == 1 ){
                account::dec_margin_cross_buy_total(account,margin);
                market::dec_long_position_total(market,fund_size);
            } else {
                account::dec_margin_cross_sell_total(account,margin);
                market::dec_short_position_total(market,fund_size);
            };
        } else {
            account::dec_margin_isolated_total(account,margin);
            if ( direction == 1 ){
                account::dec_margin_isolated_buy_total(account,margin);
                market::dec_long_position_total(market,fund_size);
            } else {
                account::dec_margin_isolated_sell_total(account,margin);
                market::dec_short_position_total(market,fund_size);
            };
        };
    }

    public fun get_equity<P,T>(
        list: &List<P,T>,
        account: &Account<T>,
        root: &oracle::Root,
    ) :I64 {
        let ids = account::get_pfk_ids<T>(account);
        let n = vector::length(&ids);
        let i = 0;
        let pl = i64::new(0,false);
        while ( i < n ){
            let id = vector::borrow(&ids,i);
            let ps: &Position<T> = dof::borrow(account::get_uid(account),*id);
            if ( ps.status == 1 ){
                let market: &Market = dof::borrow(market::get_list_uid(list),ps.market_id);
                let price = market::get_price(market,root);
                let unit_size = market::get_unit_size(market);
                let size = size(ps.lot,unit_size);
                let fund_size = fund_size(size,market::get_real_price(&price));
                pl = i64::i64_add(&pl,&i64::i64_add(&get_position_fund_fee(list, market, fund_size, ps.direction), &get_pl<T>(size, fund_size, ps.direction, &price)));
            };
            i = i + 1;
        };
        i64::inc_u64(&mut pl,account::get_balance(account));
        pl
    }
    /// get Floating P/L
    public fun get_pl<T>(size: u64, fund_size: u64, direction: u8,price: &Price) :I64 {
        if (direction == 1) {
            i64::u64_sub(fund_size(size,market::get_sell_price(price)), fund_size)
        } else {
            i64::u64_sub(fund_size, fund_size(size,market::get_buy_price(price)))
        }
    }

    public fun get_position_fund_fee<P,T>(
        list: &List<P,T>,
        market: &Market,
        fund_size: u64,
        direction: u8,
    ) :I64 {
        let dominant_direction = market::get_dominant_direction(market);
        if (dominant_direction == 3){
            return i64::new(0,false)
        };
        let total_liquidity = pool::get_total_liquidity<P,T>(market::get_pool(list));
        if (direction == dominant_direction) {
            i64::new(fund_size * market::get_fund_fee(market,total_liquidity) / market::get_denominator(),true)
        } else {
            let max = market::get_max_position_total(market);
            let min = market::get_min_position_total(market);
            if (min == 0){
                return i64::new(0,false)
            };
            i64::new(max * market::get_fund_fee(market,total_liquidity) / market::get_denominator() * fund_size / min,false)
        }
    }

    fun check_open_position<T>(  
        market: &Market, 
        lot: u64,
        leverage: u8,
        position_type: u8,
        direction: u8
    ){
        assert!(market::get_status(market) == 1, EInvalidMarketStatus);
        assert!(lot > 0, EInvalidLot);
        assert!(leverage > 0 && leverage <= market::get_max_leverage(market), EInvalidLeverage);
        assert!(position_type == 1 || position_type == 2, EInvalidPositionType);
        assert!(direction == 1 || direction == 2, EInvalidDirection);
    }

    fun merge_cross_position<T>(
        market: &mut Market,
        account: &mut Account<T>,
        pfk: &PFK,
        lot: u64,
        leverage: u8,
        direction: u8,
        margin_fee: u64,
        size: u64,
        fund_size: u64,
        unix_time: u64,
    ) :(u64,ID) {
        let id = account::get_pfk_id(account,pfk);
        let position: &mut Position<T> = dof::borrow_mut(account::get_uid_mut(account),id);
        assert!(position.status == 1, EInvalidPositionStatus);
        let size_old = size(position.lot,position.unit_size);
        let fund_size_old = fund_size(size_old,position.open_real_price);
        let new_real_price = ((fund_size_old as u128) + (fund_size as u128)) * DENOMINATORU128 / ((size + size_old) as u128);
        // assert!(new_real_price <= MAX_U64_VALUEU128 ,ENumericOverflow);
        let new_price = market::get_price_by_real(market, (new_real_price as u64));
        position.open_price = market::get_direction_price(&new_price, direction);
        position.open_spread = market::get_spread(&new_price);
        position.open_real_price = market::get_real_price(&new_price);
        position.lot = position.lot + lot;
        position.leverage = leverage;
        position.open_time = unix_time;
        let margin_old = position.margin;
        let position_type = position.type;
        let fund_size_new =  get_fund_size(position);
        let margin_new = margin_size(fund_size,leverage,margin_fee);
        position.margin = margin_new;
        dec_margin<T>(market, account, position_type, direction, margin_old, fund_size_old);
        inc_margin<T>(market, account, position_type, direction, margin_new,fund_size_new);
        (margin_new,id)
    }

    fun risk_assertion(
        total_liquidity: u64,
        fund_size: u64,
        pre_exposure: u64,
        exposure: u64,
        position_total: u64
    ){
        if (exposure > total_liquidity / DENOMINATOR * POSITION_DIFF_PROPORTION){
            assert!(
                exposure < pre_exposure,
                ERiskControlBlockingExposure
            );
        };
        assert!(
            fund_size < total_liquidity / DENOMINATOR * POSITION_PROPORTION_ONE,
            RiskControlBlockingFundSize
        );
        assert!(
            position_total / POSITION_PROPORTION < total_liquidity / DENOMINATOR,
            RiskControlBlockingFundPool
        );
    }

    public fun check_margin<T>(
        account: &Account<T>,
        equity: &I64
    ){
        assert!(!i64::is_negative(equity), ERiskControlNegativeEquity);
        let margin_used = account::get_margin_used(account);
        if (margin_used > 0) {
            assert!(i64::get_value(equity) >= BURST_RATE * margin_used / DENOMINATOR, ERiskControlBurstRate);
        }
    }

    fun get_insurance_amount(margin: u64,insurance_fee: u64): u64{
        ((margin as u128) * (insurance_fee as u128) / (DENOMINATOR as u128) as u64)
    }

    fun get_spread_amount(spread: u64, size: u64):u64 {
        size * (spread / DENOMINATOR / 2)
    }

    fun create_position<T>(
        lot: u64,
        leverage: u8,
        direction: u8,
        type: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        market: &mut Market,
        account: &mut Account<T>,
        root: &oracle::Root,
        c: &Clock,
        ctx: &mut TxContext
    ):(u64,u64,u64,u64,ID){
        assert!(tx_context::sender(ctx) == account::get_owner(account), ENoPermission);
        check_open_position<T>(market,lot,leverage,1,direction);
        let price = market::get_price(market, root);
        let unit_size = market::get_unit_size(market);
        let pfk = account::new_PFK(object::id(market),object::id(account),direction);
        let size = size(lot,unit_size);
        let real_price = market::get_real_price(&price);
        let fund_size = fund_size(size,real_price);
        let margin_fee = market::get_margin_fee(market);
        let unix_time = clock::timestamp_ms(c);
        if ( type == 1 && account::contains_pfk(account,&pfk) ){
            let (margin, id) = merge_cross_position<T>(market,account,&pfk,lot,leverage,direction,margin_fee,size,fund_size,unix_time);
            event::update<Position<T>>(id);
            event::update<Account<T>>(object::id(account));
            event::update<Market>(object::id(market));
            return (margin,size,fund_size,real_price, id)
        };
        let offset = account::get_offset(account) + 1;
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        let position = Position<T> {
            id: uid,
            offset,
            margin: 0,
            margin_balance: balance::zero<T>(),
            leverage,
            type,
            status: 1,
            direction,
            unit_size,
            lot,
            open_price: market::get_direction_price(&price, direction),
            open_spread : market::get_spread(&price),
            open_real_price: real_price,
            close_price: 0,
            close_spread: 0,
            close_real_price: 0,
            profit: i64::new(0,false),
            stop_surplus_price,
            stop_loss_price,
            auto_open_price,
            create_time: unix_time,
            open_time: unix_time,
            close_time: 0,
            validity_time: 0,
            open_operator: tx_context::sender(ctx),
            close_operator: @0x0,
            market_id: object::id(market),
            account_id: object::id(account),
        };
        let offset = account::get_offset(account) + 1;
        if (auto_open_price > 0) {
            position.status = 4;
            position.open_time = 0;
        };
        let margin = margin_size(
            fund_size,
            leverage,
            margin_fee
        );
        position.margin = margin;
        account:: set_offset(account, offset);
        inc_margin<T>(market, account, type, direction, margin, fund_size);
        dof::add(account::get_uid_mut(account),id,position);
        if (type == 1){
            account::add_pfk_id(account, pfk, id);
        }else{
            account::add_isolated_position_id(account,id);
        };
        event::create<Position<T>>(id);
        event::update<Account<T>>(object::id(account));
        event::update<Market>(object::id(market));
        (margin,size,fund_size,real_price,id)
    }
    public fun open_cross_position<P,T>(
        symbol: vector<u8>,
        lot: u64,
        leverage: u8,
        direction: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        list: &mut List<P,T>,
        account: &mut Account<T>,
        root: &oracle::Root,
        c: &Clock,
        ctx: &mut TxContext
    ): ID {
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),symbol);
        let pre_exposure = market::get_exposure(market);
        let (margin,size,fund_size,real_price,id) = create_position<T>(
            lot,
            leverage,
            direction,
            1u8,
            auto_open_price,
            stop_surplus_price,
            stop_loss_price,
            market,
            account,
            root,
            c,
            ctx
        );
        let insurance_fee = market::get_insurance_fee(market);
        let spread_fee = market::get_spread_fee(market, real_price);
        let exposure = market::get_exposure(market);
        let position_total = market::get_curr_position_total(market,direction);
        let total_liquidity = pool::get_total_liquidity<P,T>(market::get_pool(list));
        risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
        let equity = get_equity<P,T>(
            list,
            account,
            root,
        );
        check_margin<T>(account,&equity);
        event::update<List<P,T>>(object::id(list));
        let p = market::get_pool_mut<P,T>(list);
        // collect insurance
        let insurance_balance = account::split_balance(account, get_insurance_amount(margin,insurance_fee));
        pool::join_insurance_balance<P,T>(p,insurance_balance);
        // collect spread
        let spread_balance = pool::split_profit_balance(p,get_spread_amount(spread_fee,size));
        pool::join_spread_profit<P,T>(p,spread_balance);
        id
    }

    public fun open_isolated_position<P,T>(
        symbol: vector<u8>,
        lot: u64,
        leverage: u8,
        direction: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        token: &mut Coin<T>,
        list: &mut List<P,T>,
        account: &mut Account<T>,
        root: &oracle::Root,
        c: &Clock,
        ctx: &mut TxContext
    ): ID{
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),symbol);
        let pre_exposure = market::get_exposure(market);
        let (margin,size,fund_size,real_price,id) = create_position<T>(
            lot,
            leverage,
            direction,
            1u8,
            auto_open_price,
            stop_surplus_price,
            stop_loss_price,
            market,
            account,
            root,
            c,
            ctx
        );
        let insurance_fee = market::get_insurance_fee(market);
        let spread_fee = market::get_spread_fee(market, real_price);
        let exposure = market::get_exposure(market);
        let position_total = market::get_curr_position_total(market,direction);
        let total_liquidity = pool::get_total_liquidity<P,T>(market::get_pool(list));

        risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
        let equity = i64::new(margin,false);
        check_margin<T>(account, &equity);
        event::update<List<P,T>>(object::id(list));
        let p = market::get_pool_mut<P,T>(list);
        // collect insurance
        let insurance_balance = coin::split(token, get_insurance_amount(margin,insurance_fee),ctx);
        pool::join_insurance_balance<P,T>(p,coin::into_balance(insurance_balance));
        // collect spread
        let spread_balance = pool::split_profit_balance(p,get_spread_amount(spread_fee,size));
        pool::join_spread_profit<P,T>(p,spread_balance);
        id
    }

    fun settlement_pl<P,T>(
        list:&mut List<P,T>,
        market: &mut Market,
        account: &mut Account<T>,
        root: &oracle::Root,
        position: &mut Position<T>,
        close_operator: address,
    ){
        let price = market::get_price(market,root);
        let size = size(position.lot,position.size);
        
        position.close_spread = market::get_spread(&price);
        position.close_price = market::get_direction_price(&price,position.direction);
        position.close_real_price = market::get_real_price(&price);
        // todo: update close_time
        position.close_time = 0;
        position.close_operator = close_operator;

        collect_spread<P,T>(list,position.close_spread,size);
        let pl = get_pl(position,&price);
        if (!i64::is_negative(&pl)){
            account::join_balance(account,pool::split_profit_balance(market::get_pool_mut(list),i64::get_value(&pl)));
        }else{
            let loss = if (position.type == 1){
                account::split_balance(account,i64::get_value(&pl))
            }else{
                balance::split(&mut position.margin_balance,i64::get_value(&pl))
            };
            pool::join_profit_balance(market::get_pool_mut(list),loss);
        };
        let margin_balance_value = balance::value(&position.margin_balance);
        if (margin_balance_value > 0){
            account::join_balance(account,balance::split(&mut position.margin_balance,margin_balance_value));
        };
        
        if (i64::is_negative(&pl)){
            account::dec_profit(account,i64::get_value(&pl));
        }else{
            account::inc_profit(account,i64::get_value(&pl));
        };
        position.profit = pl;
        dec_margin<P,T>(market,account,position.type,position.direction,position.margin,get_fund_size(position));
        if (position.type == 1) {
            let pfk = account::new_PFK(position.market_id,position.account_id,position.direction);
            account::remove_pfk_id(account,&pfk);
        }else{
            account::remove_isolated_position_id(account,object::uid_to_inner(&position.id));
        };
    }

    public fun close_position<P,T>(
        symbol: vector<u8>,
        position_id: ID,
        lot: u64,
        root: &oracle::Root,
        account: &mut Account<T>,
        list: &mut List<P,T>,
        ctx: &mut TxContext,
    ){
        let owner = tx_context::sender(ctx);
        assert!(owner == account::get_owner(account), ENoPermission);
        let position: Position<T> = dof::remove(account::get_uid_mut(account),position_id);
        assert!(position.status == 1, EInvalidPositionStatus);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),symbol);
        assert!(market::get_status(market) != 3, EInvalidMarketStatus);
        assert!(object::id(market) == position.market_id, EInvalidMarketId);
        assert!(object::id(account) == position.account_id, EInvalidAccountId);
        position.status = 2;
        settlement_pl<P,T>(list,market,account,root, &mut position,owner);
        // transfer::transfer(position,owner);
        event::update<List<P,T>>(object::id(list));
        event::update<Market>(object::id(market));
        event::update<Account<T>>(object::id(account));
        event::update<Position<T>>(position_id);
    }
}