#[lint_allow(self_transfer)]
module scale::position {
    use sui::object::{Self,UID,ID};
    use sui::balance::{Self,Balance};
    use sui::coin::{Self,Coin};
    use sui::transfer;
    use scale::market::{Self,Market,Price,List};
    use scale::account::{Self,Account,PFK};
    use sui::tx_context::{Self,TxContext};
    use sui::dynamic_object_field as dof;
    use scale::pool::{Self,Scale};
    use std::vector;
    use scale::i64::{Self, I64};
    use oracle::oracle;
    use scale::event;
    use sui::clock::{Self, Clock};
    use std::string::{Self,String};
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
    // const EInvalidMarketId:u64 = 614;
    const EInvalidAccountId:u64 = 615;
    // const ERiskControlNegativeEquity:u64 = 616;
    const EBurstConditionsNotMet:u64 = 617;
    const EInvalidAutoOpenPrice:u64 = 618;
    const EInvalidStopPrice:u64 = 619;
    // const EInvalidStopSurplusPrice:u64 = 620;
    const EInvalidStopLossPrice:u64 = 621;
    const EInsufficientCoins:u64 = 622;
    const EInvalidSettlementTime:u64 = 623;

    // const MAX_U64_VALUEU64: u64 = 18446744073709551615;
    const MAX_U64_VALUEU128: u128 = 18446744073709551615;

    const DENOMINATOR: u64 = 10000;
    const DENOMINATORU128: u128 = 10000;
    /// The exposure ratio should not exceed 70% of the current pool,
    /// so as to avoid the risk that the platform's current pool is empty.
    // const POSITION_DIFF_PROPORTION: u64 = 7000;
    const POSITION_DIFF_PROPORTIONU128: u128 = 7000;
    /// The liquidation line ratio means that if the user's margin loss exceeds this ratio in one quotation,
    /// the system will be liquidated and the position will be forced to close.
    const FORCE_LIQUIDATION_RATE: u64 = 5000;
    /// so as to avoid the risk of malicious position opening.
    const POSITION_PROPORTION_U128: u128 = 15000;
    /// The size of a single position shall not be greater than 20% of the exposure
    const POSITION_PROPORTION_ONE_U128: u128 = 2000;

    struct Position<phantom T> has key,store {
        id: UID,
        margin_balance: Balance<T>,
        info: Info,
    }

    struct Info has copy,store {
        offset: u64,
        /// Initial position margin
        margin: u64,
        /// Current actual margin balance of isolated
        /// leverage size
        leverage: u8,
        /// 1 cross position mode, 2 isolated position modes.
        type: u8,
        /// Position status: 1 normal, 2 normal closing, 3 Forced closing, 4 pending , 5 partial closeing , 6 auto closing , 7 merge close
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
        /// Opening operator (the user manually, or the clearing robot in the listing mode)
        open_operator: address,
        /// Account number of warehouse closing operator (user manual, or clearing robot Qiangping)
        close_operator: address,
        symbol: String,
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
        position.info.offset
    }
    public fun get_margin<T>(position: &Position<T>) :u64 {
        position.info.margin
    }
    public fun get_margin_balance<T>(position: &Position<T>) :u64 {
        balance::value(&position.margin_balance)
    }
    public fun get_leverage<T>(position: &Position<T>) :u8 {
        position.info.leverage
    }
    public fun get_type<T>(position: &Position<T>) :u8 {
        position.info.type
    }
    public fun get_status<T>(position: &Position<T>) :u8 {
        position.info.status
    }
    public fun get_direction<T>(position: &Position<T>) :u8 {
        position.info.direction
    }
    public fun get_unit_size_value<T>(position: &Position<T>) :u64 {
        position.info.unit_size
    }
    public fun get_lot<T>(position: &Position<T>) :u64 {
        position.info.lot
    }
    public fun get_open_price<T>(position: &Position<T>) :u64 {
        position.info.open_price
    }
    public fun get_open_spread<T>(position: &Position<T>) :u64 {
        position.info.open_spread
    }
    public fun get_open_real_price<T>(position: &Position<T>) :u64 {
        position.info.open_real_price
    }
    public fun get_close_price<T>(position: &Position<T>) :u64 {
        position.info.close_price
    }
    public fun get_close_spread<T>(position: &Position<T>) :u64 {
        position.info.close_spread
    }
    public fun get_close_real_price<T>(position: &Position<T>) :u64 {
        position.info.close_real_price
    }
    public fun get_profit<T>(position: &Position<T>) :&I64 {
        &position.info.profit
    }

    public fun get_stop_surplus_price<T>(position: &Position<T>) :u64 {
        position.info.stop_surplus_price
    }
    public fun get_stop_loss_price<T>(position: &Position<T>) :u64 {
        position.info.stop_loss_price
    }
    public fun get_create_time<T>(position: &Position<T>) :u64 {
        position.info.create_time
    }
    public fun get_open_time<T>(position: &Position<T>) :u64 {
        position.info.open_time
    }
    public fun get_close_time<T>(position: &Position<T>) :u64 {
        position.info.close_time
    }
    public fun get_open_operator<T>(position: &Position<T>) :&address {
        &position.info.open_operator
    }
    public fun get_close_operator<T>(position: &Position<T>) :&address {
        &position.info.close_operator
    }
    public fun get_market_id<T>(position: &Position<T>) :&ID {
        &position.info.market_id
    }
    public fun get_account_id<T>(position: &Position<T>) :&ID {
        &position.info.account_id
    }
    public fun get_denominator128() :u64 {
        (DENOMINATORU128 as u64)
    }
    public fun get_denominator() :u64 {
        DENOMINATOR
    }
    public fun get_auto_open_price<T>(position: &Position<T>) :u64 {
        position.info.auto_open_price
    }

    public fun get_fund_size<T>(position: &Position<T>) :u64 {
        fund_size(size(position.info.unit_size , position.info.lot) , position.info.open_real_price)
    }

    public fun fund_size(size :u64, price: u64) :u64 {
        // reduce lot
        let r = (size as u128) * (price as u128) / DENOMINATORU128;
        assert!(r <= MAX_U64_VALUEU128 ,ENumericOverflow);
        (r as u64)
    }

    public fun get_size<T>(position: &Position<T>) :u64{
        size(position.info.lot,position.info.unit_size)
    }

    fun size(lot: u64, unit_size:u64) :u64 {
        let r = (unit_size as u128) * (lot as u128);
        assert!(r <= MAX_U64_VALUEU128 ,ENumericOverflow);
        (r as u64)
    }

    public fun get_margin_size<T>(market: &Market,position: &Position<T>) :u64 {
        margin_size(
            get_fund_size<T>(position),
            position.info.leverage,
            market::get_margin_fee(market),
        )
    }

    fun margin_size(fund_size: u64, leverage: u8, margin_fee: u64) :u64{
        let r = (fund_size as u128) / (leverage as u128) * (margin_fee as u128) / (DENOMINATOR as u128);
        (r as u64)
    }

    fun inc_margin_fund<T>(
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

    fun dec_margin_fund<T>(
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

    public fun get_equity<T>(
        total_liquidity: u64,
        list: &List<T>,
        account: &Account<T>,
        state: &oracle::State,
        c: &Clock,
    ) :I64 {
        let ids = account::get_pfk_ids<T>(account);
        let n = vector::length(&ids);
        let i = 0;
        let pl = i64::new(0,false);
        // let total_liquidity = pool::get_total_liquidity<T>(market::get_pool(list));
        while ( i < n ){
            let id = vector::borrow(&ids,i);
            if (!dof::exists_(account::get_uid(account),*id)){
                i = i + 1;
                continue
            };
            let ps: &Position<T> = dof::borrow(account::get_uid(account),*id);
            if ( ps.info.status == 1 ){
                let market: &Market = dof::borrow(market::get_list_uid(list),ps.info.symbol);
                let price = market::get_price(market,state,c);
                pl = position_pl_fund_fee(total_liquidity, market, &price, ps);
            };
            i = i + 1;
        };
        i64::inc_u64(&mut pl,account::get_balance(account));
        pl
    }

    fun position_pl_fund_fee<T>(total_liquidity:u64, market: &Market, price: &Price, ps: &Position<T>): I64{
        let pl = i64::new(0,false);
        let size = size(ps.info.lot,ps.info.unit_size);
        let fund_size = fund_size(size,ps.info.open_real_price);
        let p = get_pl(size, fund_size, ps.info.direction, price);
        let fund_fee = get_position_fund_fee(total_liquidity, fund_size, ps.info.direction, market);
        i64::i64_add(&pl,&i64::i64_add(&fund_fee, &p))
    }
    /// get Floating P/L
    public fun get_pl(size: u64, fund_size: u64, direction: u8,price: &Price) :I64 {
        if (direction == 1) {
            i64::u64_sub(fund_size(size,market::get_sell_price(price)), fund_size)
        } else {
            i64::u64_sub(fund_size, fund_size(size,market::get_buy_price(price)))
        }
    }

    public fun get_position_fund_fee(
        total_liquidity: u64,
        fund_size: u64,
        direction: u8,
        market: &Market,
    ) :I64 {
        let dominant_direction = market::get_dominant_direction(market);
        if (dominant_direction == 3){
            return i64::new(0,false)
        };
        if (direction == dominant_direction) {
            i64::new(fund_size * market::get_fund_fee(market,total_liquidity) / DENOMINATOR,true)
        } else {
            let max = market::get_max_position_total(market);
            let min = market::get_min_position_total(market);
            if (min == 0){
                return i64::new(0,false)
            };
            i64::new(max * market::get_fund_fee(market,total_liquidity) * fund_size / (DENOMINATOR * min),false)
        }
    }

    fun check_open_position(  
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
        assert!(position.info.status == 1, EInvalidPositionStatus);
        let size_old = size(position.info.lot,position.info.unit_size);
        let fund_size_old = fund_size(size_old,position.info.open_real_price);
        let new_real_price = ((fund_size_old as u128) + (fund_size as u128)) * DENOMINATORU128 / ((size + size_old) as u128);
        // assert!(new_real_price <= MAX_U64_VALUEU128 ,ENumericOverflow);
        let new_price = market::get_price_by_real(market, (new_real_price as u64));
        position.info.open_price = market::get_direction_price(&new_price, direction);
        position.info.open_spread = market::get_spread(&new_price);
        position.info.open_real_price = market::get_real_price(&new_price);
        position.info.lot = position.info.lot + lot;
        position.info.leverage = leverage;
        position.info.open_time = unix_time;
        let margin_old = position.info.margin;
        let position_type = position.info.type;
        let fund_size_new = get_fund_size(position);
        let margin_new = margin_size(fund_size_new,leverage,margin_fee);
        position.info.margin = margin_new;
        dec_margin_fund<T>(market, account, position_type, direction, margin_old, fund_size_old);
        inc_margin_fund<T>(market, account, position_type, direction, margin_new,fund_size_new);
        (margin_new,id)
    }

    public fun risk_assertion(
        total_liquidity: u64,
        fund_size: u64,
        pre_exposure: u64,
        exposure: u64,
        position_total: u64
    ){
        let total_liquidity = (total_liquidity as u128);
        let fund_size = (fund_size as u128);
        let pre_exposure = (pre_exposure as u128);
        let exposure = (exposure as u128);
        let position_total = (position_total as u128);
        if (exposure * DENOMINATORU128 > total_liquidity * POSITION_DIFF_PROPORTIONU128) {
            assert!(
                exposure < pre_exposure,
                ERiskControlBlockingExposure
            );
        };
        assert!(
            fund_size * DENOMINATORU128 < total_liquidity * POSITION_PROPORTION_ONE_U128,
            RiskControlBlockingFundSize
        );
        assert!(
            position_total * DENOMINATORU128 < total_liquidity * POSITION_PROPORTION_U128,
            RiskControlBlockingFundPool
        );
    }

    public fun check_margin<T>(
        account: &Account<T>,
        equity: &I64
    ){
        assert!(!is_force_liquidation(equity, account::get_margin_used(account)),ERiskControlBurstRate);
    }

    public fun is_force_liquidation(
        equity: &I64,
        margin_used: u64
    ):bool{
        if (margin_used == 0) {
            return false
        };
        i64::is_negative(equity) || i64::get_value(equity) <= FORCE_LIQUIDATION_RATE * margin_used / DENOMINATOR
    }

    public fun is_auto_close(direction:u8,real_price:u64,stop_surplus_price: u64,stop_loss_price: u64): bool{
        if (direction == 1){
            (stop_surplus_price > 0 && stop_surplus_price >= real_price) || (stop_loss_price > 0 && real_price <= stop_loss_price)
        }else{
            (stop_surplus_price > 0 && real_price <= stop_surplus_price) || (stop_loss_price > 0 && stop_loss_price >= real_price)
        }
    }

    fun get_insurance_amount(margin: u64,insurance_fee: u64): u64{
        let r = ((margin as u128) * (insurance_fee as u128) / (DENOMINATOR as u128) as u64);
        if (r == 0) {
            return 1
        } else {
            return r
        }
    }

    fun get_spread_amount(spread: u64, size: u64):u64 {
        // spread / 2 * size / DENOMINATOR / DENOMINATOR
        let r = (size as u128) * (spread as u128) / 2u128 / DENOMINATORU128 / DENOMINATORU128;
        if (r == 0) {
            return 1
        } else {
            return (r as u64)
        }
    }

    fun create_position<T>(
        lot: u64,
        leverage: u8,
        direction: u8,
        type: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        symbol: String,
        market: &mut Market,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ):(u64,u64,u64,u64,u64,ID){
        let price = market::get_price(market, state,c);
        let unit_size = market::get_unit_size(market);
        let size = size(lot,unit_size);
        let real_price = market::get_real_price(&price);
        let fund_size = fund_size(size,real_price);
        let margin_fee = market::get_margin_fee(market);
        let insurance_fee = market::get_insurance_fee(market);
        let spread = market::get_spread(&price);
        let unix_time = clock::timestamp_ms(c);
        let account_id = object::id(account);
        let market_id = object::id(market);
        let pfk = account::new_PFK(market_id,account_id,direction);
        if (type == 1 && auto_open_price == 0 && account::contains_pfk(account,&pfk)){
            let (margin, id) = merge_cross_position<T>(market,account,&pfk,lot,leverage,direction,margin_fee,size,fund_size,unix_time);
            event::update<Position<T>>(id);
            event::update<Account<T>>(account_id);
            event::update<Market>(market_id);
            return (margin,size,fund_size,insurance_fee,spread,id)
        };
        let offset = account::get_offset(account) + 1;
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        let position = Position<T> {
            id: uid,
            margin_balance: balance::zero<T>(),
            info: Info{
                offset,
                margin: 0,
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
                open_operator: tx_context::sender(ctx),
                close_operator: @0x0,
                symbol,
                market_id: market_id,
                account_id: account_id,
            }
        };
        let offset = account::get_offset(account) + 1;
        if (auto_open_price > 0) {
            position.info.status = 4;
            position.info.open_time = 0;
        };
        let margin = margin_size(
            fund_size,
            leverage,
            margin_fee
        );
        position.info.margin = margin;
        account:: set_offset(account, offset);
        if ( auto_open_price == 0 ){
            inc_margin_fund<T>(market, account, type, direction, margin, fund_size);
        };
        if (type == 1 ){
            if ( auto_open_price == 0 ){
                account::add_pfk_id(account, pfk, id);
            };
        } else {
            balance::join(&mut position.margin_balance, account::split_balance(account,type, margin ));
            account::add_isolated_position_id(account, id);
        };
        dof::add(account::get_uid_mut(account),id,position);
        event::create<Position<T>>(id);
        event::update<Account<T>>(account_id);
        event::update<Market>(market_id);
        (margin,size,fund_size,insurance_fee,spread,id)
    }

    public fun open_position<T>(
        symbol: vector<u8>,
        lot: u64,
        leverage: u8,
        direction: u8,
        type: u8,
        auto_open_price: u64,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ): ID {
        let symbol = string::utf8(symbol);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),symbol);
        assert!(tx_context::sender(ctx) == account::get_owner(account), ENoPermission);
        check_open_position(market,lot,leverage,type,direction);
        let pre_exposure = market::get_exposure(market);
        let (margin,size,fund_size,insurance_fee,spread,id) = create_position<T>(
                lot,
                leverage,
                direction,
                type,
                auto_open_price,
                stop_surplus_price,
                stop_loss_price,
                symbol,
                market,
                account,
                state,
                c,
                ctx
            );
        if ( auto_open_price > 0 ){
            return id
        };
        let exposure = market::get_exposure(market);
        let position_total = market::get_curr_position_total(market,direction);
        let total_liquidity = pool::get_total_liquidity<Scale,T>(market::get_pool(list));
        risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
        if ( type == 1 ){
            let equity = get_equity<T>(
                total_liquidity,
                list,
                account,
                state,
                c,
            );
            check_margin<T>(account,&equity);
        };
        event::update<List<T>>(object::id(list));
        let p = market::get_pool_mut<T>(list);
        // collect insurance
        let insurance_balance = account::split_balance(account,type, get_insurance_amount(margin,insurance_fee));
        pool::join_insurance_balance<Scale,T>(p,insurance_balance);
        // collect spread
        let spread_balance = pool::split_profit_balance(p,get_spread_amount(spread,size),tx_context::epoch(ctx));
        pool::join_spread_profit<Scale,T>(p,spread_balance);
        id
    }

    fun split_position<T>(ps: &mut Position<T>, lot: u64, margin_fee: u64, ctx: &mut TxContext): Position<T> {
        let fund_size = fund_size(size(lot,ps.info.unit_size),ps.info.open_real_price);
        let margin = margin_size(
            fund_size,
            ps.info.leverage,
            margin_fee
        );
        let new_position = Position {
            id: object::new(ctx),
            margin_balance: balance::zero<T>(),
            info: ps.info,
        };
        ps.info.lot = ps.info.lot - lot;
        ps.info.margin = ps.info.margin - margin;
        new_position.info.lot = lot;
        new_position.info.margin = margin;
        if (ps.info.type == 2u8) {
            balance::join(&mut new_position.margin_balance,balance::split(&mut ps.margin_balance, margin));
        };
        new_position
    }

    fun settlement_pl<T>(
        close_operator: address,
        auto: bool,
        list: &mut List<T>,
        market: &mut Market,
        account: &mut Account<T>,
        state: &oracle::State,
        position: &mut Position<T>,
        c: &Clock,
        ctx: &TxContext,
    ){
        let price = market::get_price(market,state,c);
        let real_price = market::get_real_price(&price);
        if (auto) {
            assert!(is_auto_close(position.info.direction,real_price,position.info.stop_surplus_price,position.info.stop_loss_price), EInvalidStopLossPrice);
        };
        let size = size(position.info.lot,position.info.unit_size);
        // let spread = market::get_spread(&price);
        let fund_size = fund_size(size,position.info.open_real_price);
        position.info.close_spread = market::get_spread(&price);
        position.info.close_price = market::get_direction_price(&price,position.info.direction);
        position.info.close_real_price = real_price;
        position.info.close_time = clock::timestamp_ms(c);
        position.info.close_operator = close_operator;
        let p = market::get_pool_mut<T>(list);
        // collect spread
        // let spread_balance = pool::split_profit_balance(p,get_spread_amount(spread,size));
        // pool::join_spread_profit<T>(p,spread_balance);
        let pl = get_pl(size, fund_size, position.info.direction, &price);
        if (!i64::is_negative(&pl)){
            account::join_balance(account, position.info.type, pool::split_profit_balance(p,i64::get_value(&pl),tx_context::epoch(ctx)));
        }else{
            let loss = if (position.info.type == 1){
                account::split_balance(account,position.info.type,i64::get_value(&pl))
            }else{
                let amount = i64::get_value(&pl);
                let margin_balance_value = balance::value(&position.margin_balance);
                // force to split all
                if (amount > margin_balance_value){
                    amount = margin_balance_value;
                };
                balance::split(&mut position.margin_balance,amount)
            };
            pool::join_profit_balance(p,loss,tx_context::epoch(ctx));
        };
        let margin_balance_value = balance::value(&position.margin_balance);
        if (margin_balance_value > 0){
            account::join_balance(account,position.info.type,balance::split(&mut position.margin_balance,margin_balance_value));
        };
        if (i64::is_negative(&pl)){
            account::dec_profit(account,i64::get_value(&pl));
        }else{
            account::inc_profit(account,i64::get_value(&pl));
        };
        position.info.profit = pl;
        dec_margin_fund<T>(market, account, position.info.type, position.info.direction, position.info.margin, fund_size);
        if (position.info.type == 1) {
            let pfk = account::new_PFK(position.info.market_id,position.info.account_id,position.info.direction);
            if ( account::get_pfk_id(account,&pfk) == object::id(position) ){
                account::remove_pfk_id(account,&pfk);
            };
        }else{
            account::remove_isolated_position_id(account,object::uid_to_inner(&position.id));
        };
    }

    public fun close_position<T>(
        position_id: ID,
        lot: u64,
        state: &oracle::State,
        account: &mut Account<T>,
        list: &mut List<T>,
        c: &Clock,
        ctx: &mut TxContext,
    ):ID{
        let owner = tx_context::sender(ctx);
        assert!(owner == account::get_owner(account), ENoPermission);
        let position: Position<T> = dof::remove(account::get_uid_mut(account),position_id);
        assert!(lot >= 0 && lot <= position.info.lot, EInvalidLot);
        assert!(position.info.status == 1, EInvalidPositionStatus);
        let market: Market = dof::remove(market::get_list_uid_mut(list),position.info.symbol);
        assert!(market::get_status(&market) < 3, EInvalidMarketStatus);
        let account_id = object::id(account);
        assert!(account_id == position.info.account_id, EInvalidAccountId);
        let id:ID;
        // partial close
        if (lot < position.info.lot && lot > 0){
            let new_position = split_position<T>(&mut position,lot,market::get_margin_fee(&market),ctx);
            new_position.info.status = 5;
            settlement_pl<T>(owner,false,list,&mut market, account, state, &mut new_position,c,ctx);
            let new_position_id = object::id(&new_position);
            event::create<Position<T>>(new_position_id);
            event::update<Position<T>>(position_id);
            dof::add(account::get_uid_mut(account),new_position_id,new_position);
            id = new_position_id;
        }else{
            position.info.status = 2;
            settlement_pl<T>(owner,false,list,&mut market, account, state, &mut position,c,ctx);
            event::delete<Position<T>>(position_id);
            id = position_id;
        };
        // transfer::transfer(position,owner);
        event::update<List<T>>(object::id(list));
        event::update<Market>(object::id(&market));
        event::update<Account<T>>(account_id);
        dof::add(market::get_list_uid_mut(list),position.info.symbol,market);
        dof::add(account::get_uid_mut(account),position_id,position);
        id
    }

    public fun auto_close_position<T>(
        position_id: ID,
        state: &oracle::State,
        account: &mut Account<T>,
        list: &mut List<T>,
        c: &Clock,
        ctx: &mut TxContext,
    ){
        let position: Position<T> = dof::remove(account::get_uid_mut(account),position_id);
        assert!(position.info.status == 1, EInvalidPositionStatus);
        assert!(position.info.stop_loss_price > 0 || position.info.stop_surplus_price > 0, EInvalidStopPrice);
        let market: Market = dof::remove(market::get_list_uid_mut(list),position.info.symbol);
        assert!(market::get_status(&market) < 3, EInvalidMarketStatus);
        position.info.status = 6;
        settlement_pl<T>(tx_context::sender(ctx),true,list,&mut market, account, state, &mut position,c,ctx);
        event::delete<Position<T>>(position_id);
        event::update<List<T>>(object::id(list));
        event::update<Market>(object::id(&market));
        event::update<Account<T>>(object::id(account));
        dof::add(market::get_list_uid_mut(list),position.info.symbol,market);
        dof::add(account::get_uid_mut(account),position_id,position);
    }

    public fun force_liquidation<T>(        
        position_id: ID,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext,
    ){
        let position: Position<T> = dof::remove(account::get_uid_mut(account),position_id);
        assert!(position.info.status == 1, EInvalidPositionStatus);
        let account_id = object::id(account);
        assert!(account_id == position.info.account_id, EInvalidAccountId);
        // settlement
        position.info.status = 3;
        let margin_used = account::get_margin_used(account);
        let market: Market = dof::remove(market::get_list_uid_mut(list),position.info.symbol);
        assert!(market::get_status(&market) < 3, EInvalidMarketStatus);
        settlement_pl<T>(tx_context::sender(ctx),false,list,&mut market,account, state, &mut position,c,ctx);
        let market_id = object::id(&market);
        dof::add(market::get_list_uid_mut(list),position.info.symbol,market);
        if (position.info.type == 1){
            let total_liquidity = pool::get_total_liquidity<Scale,T>(market::get_pool(list));
            let equity = get_equity<T>(
                total_liquidity,
                list,
                account,
                state,
                c,
            );
            equity = i64::i64_add(&equity,&position.info.profit);
            assert!(is_force_liquidation(&equity,margin_used), EBurstConditionsNotMet);
        } else {
            let pl = position.info.profit;
            i64::inc_u64(&mut pl,position.info.margin);
            assert!(is_force_liquidation(&pl,position.info.margin), EBurstConditionsNotMet);
        };
        event::update<List<T>>(object::id(list));
        event::update<Market>(market_id);
        event::update<Account<T>>(account_id);
        event::delete<Position<T>>(position_id);
        dof::add(account::get_uid_mut(account),position_id,position);
    }

    public fun process_fund_fee<T>(
        list: &mut List<T>,
        account: &mut Account<T>,
        c: &Clock,
        ctx: &TxContext,
    ){
        let ids = account::get_all_position_ids(account);
        let i = 0;
        let n = vector::length(&ids);
        let total_liquidity = pool::get_total_liquidity<Scale,T>(market::get_pool(list));
        let latest_time = account::get_latest_settlement_ms(account);
        let timestamp_ms = clock::timestamp_ms(c);
        // Charge at least once every 8 hours
        // Allow one minute in advance
        assert!(timestamp_ms - latest_time > (8 * 60 * 60 - 60) * 1000, EInvalidSettlementTime);
        while (i < n) {
            let id = vector::borrow(&ids, i);
            let position: &mut Position<T> = dof::borrow_mut(account::get_uid_mut(account),*id);
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),position.info.symbol);
            let size = size(position.info.lot,position.info.unit_size);
            let fund_size = fund_size(size,position.info.open_real_price);
            let fund_fee = get_position_fund_fee(total_liquidity, fund_size, position.info.direction, market);
            if (i64::is_negative(&fund_fee)){
                let bl = if (position.info.type == 1) {
                    account::split_balance(account,1,i64::get_value(&fund_fee))
                }else{
                    event::update<Position<T>>(*id);
                    balance::split(&mut position.margin_balance,i64::get_value(&fund_fee))
                };
                pool::join_profit_balance(market::get_pool_mut(list),bl,tx_context::epoch(ctx));
            }else{
                let bl = pool::split_profit_balance(market::get_pool_mut(list),i64::get_value(&fund_fee),tx_context::epoch(ctx));
                if (position.info.type == 1) {
                    account::join_balance(account,1,bl);
                }else{
                    event::update<Position<T>>(*id);
                    balance::join(&mut position.margin_balance,bl);
                };
            };
            i = i + 1;
        };
        account::set_latest_settlement_ms(account,timestamp_ms);
        event::update<Account<T>>(object::id(account));
    }

    public fun update_limit_position<T>(
        position_id: ID,
        lot: u64,
        leverage: u8,
        auto_open_price: u64,
        list: &mut List<T>,
        account: &mut Account<T>,
        ctx: &TxContext,
    ){
        let owner = tx_context::sender(ctx);
        assert!(owner == account::get_owner(account), ENoPermission);
        assert!(lot > 0, EInvalidLot);
        assert!(auto_open_price > 0, EInvalidAutoOpenPrice);
        let position: Position<T> = dof::remove(account::get_uid_mut(account),position_id);
        assert!(position.info.status == 4, EInvalidPositionStatus);
        assert!(object::id(account) == position.info.account_id, EInvalidAccountId);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),position.info.symbol);
        assert!(leverage > 0 && leverage <= market::get_max_leverage(market), EInvalidLeverage);
        let unit_size = market::get_unit_size(market);
        let size = size(lot,unit_size);
        let fund_size = fund_size(size,position.info.open_real_price);
        let margin_fee = market::get_margin_fee(market);
        let margin_new = margin_size(fund_size,leverage,margin_fee);
        if ( position.info.type == 2 ){
            if (margin_new > position.info.margin) {
                let d = margin_new - position.info.margin;
                balance::join(&mut position.margin_balance,account::split_balance(account,2,d));
            };
            if (margin_new < position.info.margin) {
                let d = position.info.margin - margin_new;
                account::join_balance(account,2,balance::split(&mut position.margin_balance,d));
            };
        };
        position.info.lot = lot;
        position.info.leverage = leverage;
        position.info.margin = margin_new;
        position.info.auto_open_price = auto_open_price;
        dof::add(account::get_uid_mut(account),position_id,position);
        event::update<Market>(object::id(market));
        event::update<Account<T>>(object::id(account));
        event::update<Position<T>>(position_id);
    }

    public fun open_limit_position<T>(
        position_id: ID,
        list: &mut List<T>,
        account: &mut Account<T>,
        state: &oracle::State,
        c: &Clock,
        ctx: &mut TxContext,
    ){
        let position: Position<T> = dof::remove(account::get_uid_mut(account),position_id);
        assert!(position.info.status == 4, EInvalidPositionStatus);
        let market: Market = dof::remove(market::get_list_uid_mut(list),position.info.symbol);
        assert!(market::get_status(&market) != 3, EInvalidMarketStatus);
        assert!(position.info.auto_open_price > 0, EInvalidAutoOpenPrice);
        let price = market::get_price(&market,state,c);
        let real_price = market::get_real_price(&price);
        if (position.info.direction == 1) {
            assert!(position.info.auto_open_price <= real_price, EInvalidAutoOpenPrice);
        }else{
            assert!(position.info.auto_open_price >= real_price, EInvalidAutoOpenPrice);
        };
        let insurance_fee = market::get_insurance_fee(&market);
        let pre_exposure = market::get_exposure(&market);
        let size = get_size(&position);
        let fund_size = fund_size(size,real_price);
        let margin_fee = market::get_margin_fee(&market);
        let unix_time = clock::timestamp_ms(c);
        let market_id = object::id(&market);
        let account_id = object::id(account);
        let pfk = account::new_PFK(market_id,account_id,position.info.direction);
        position.info.status = 1;
        let merge = false;
        if (position.info.type == 1){
            if (account::contains_pfk(account,&pfk)) {
               let (_,id) = merge_cross_position<T>(
                    &mut market,
                    account,
                    &pfk,
                    position.info.lot,
                    position.info.leverage,
                    position.info.direction,
                    margin_fee,
                    size,
                    fund_size,
                    unix_time
                );
                position.info.status = 7;
                merge = true;
                event::update<Position<T>>(id);
            }else{
                account::add_pfk_id(account, pfk, object::id(&position));
            }
        };
        if (!merge) {
            inc_margin_fund<T>(&mut market, account, position.info.type, position.info.direction, position.info.margin, fund_size);
        };
        let position_total = market::get_curr_position_total(&market,position.info.direction);
        let exposure = market::get_exposure(&market);
        let spread = market::get_spread(&price);
        let total_liquidity = pool::get_total_liquidity<Scale,T>(market::get_pool(list));
        risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
        // Failure to do so may result in the inability to calculate equity
        dof::add(market::get_list_uid_mut(list),position.info.symbol,market);
        if ( position.info.type == 1 ){
            let equity = get_equity<T>(
                total_liquidity,
                list,
                account,
                state,
                c,
            );
            check_margin<T>(account,&equity);
        };
        position.info.open_time = clock::timestamp_ms(c);
        event::update<List<T>>(object::id(list));
        event::update<Account<T>>(account_id);
        event::update<Market>(market_id);
        event::update<Position<T>>(position_id);
        let p = market::get_pool_mut<T>(list);
        let insurance_amount = get_insurance_amount(position.info.margin,insurance_fee);
        let insurance_balance = if ( position.info.type == 1){
            account::split_balance(account,position.info.type, insurance_amount)
        }else{
            balance::split(&mut position.margin_balance,insurance_amount)
        };
        let spread_balance = pool::split_profit_balance(p,get_spread_amount(spread,size),tx_context::epoch(ctx));
        // collect insurance
        pool::join_insurance_balance<Scale,T>(p,insurance_balance);
        // collect spread
        pool::join_spread_profit<Scale,T>(p,spread_balance);
        dof::add(account::get_uid_mut(account),position_id,position);
    }

    public fun update_automatic_price<T>(
        position_id: ID,
        stop_surplus_price: u64,
        stop_loss_price: u64,
        account: &mut Account<T>,
        ctx: &TxContext,
    ){
        let owner = tx_context::sender(ctx);
        assert!(owner == account::get_owner(account), ENoPermission);
        let account_id = object::id(account);
        let position: &mut Position<T> = dof::borrow_mut(account::get_uid_mut(account),position_id);
        assert!(account_id == position.info.account_id, EInvalidAccountId);
        assert!(position.info.status == 1 || position.info.status == 4 , EInvalidPositionStatus);
        position.info.stop_surplus_price = stop_surplus_price;
        position.info.stop_loss_price = stop_loss_price;
        event::update<Position<T>>(position_id);
    }

    public fun isolated_deposit<T>(
        position_id: ID,
        token: Coin<T>,
        amount: u64,
        account: &mut Account<T>,
        list: &mut List<T>,
        ctx: &mut TxContext,
    ){
        let owner = tx_context::sender(ctx);
        let addount_id = object::id(account);
        assert!(owner == account::get_owner(account), ENoPermission);
        let position: &mut Position<T> = dof::borrow_mut(account::get_uid_mut(account),position_id);
        assert!(addount_id == position.info.account_id, EInvalidAccountId);
        assert!(position.info.status == 1, EInvalidPositionStatus);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(list),position.info.symbol);
        assert!(market::get_status(market) != 3, EInvalidMarketStatus);
        if (amount == 0) {
            amount = coin::value(&token);
            balance::join(&mut position.margin_balance, coin::into_balance(token));
        }else{
            assert!(amount <= coin::value(&token), EInsufficientCoins);
            balance::join(&mut position.margin_balance, coin::into_balance(coin::split(&mut token, amount,ctx)));
            transfer::public_transfer(token,tx_context::sender(ctx));
        };
        position.info.margin = position.info.margin + amount;
        inc_margin_fund<T>(market, account, position.info.type, position.info.direction, amount, 0);
        event::update<Market>(object::id(market));
        event::update<Account<T>>(object::id(account));
        event::delete<Position<T>>(position_id);
    }
}