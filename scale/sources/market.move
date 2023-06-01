module scale::market{
    use sui::object::{Self,UID,ID};
    use std::string::{Self,String};
    use sui::tx_context::{Self,TxContext};
    use scale::admin::{Self,ScaleAdminCap,AdminCap};
    use scale::pool::{Self,Pool,Scale};
    use sui::transfer;
    use std::vector;
    use sui::math;
    use sui::dynamic_object_field as dof;
    use oracle::oracle;
    use sui::url::{Self, Url};
    use scale::event;

    friend scale::position;
    friend scale::bond;
    
    const ELSPCreatorPermissionRequired:u64 = 301;
    const EInvalidLeverage:u64 = 302;
    const EInvalidSpread:u64 = 303;
    const EInvalidInsuranceRate:u64 = 304;
    const EInvalidMarginRate:u64 = 305;
    const EInvalidStatus:u64 = 306;
    const ENameRequired:u64 = 307;
    const EDescriptionRequired:u64 = 308;
    const ENoPermission:u64 = 309;
    const EInvalidSellPrice:u64 = 310;
    const EInvalidSize:u64 = 311;
    const EInvalidFundRate:u64 = 312;
    const EInvalidOpingPrice:u64 = 313;
    const EInvalidOfficer:u64 = 314;
    const ENameTooLong:u64 = 315;
    const EDescriptionTooLong:u64 = 316;
    const EInvalidOpeningPrice:u64 = 317;
    const EIconRequired:u64 = 318;
    const EIconTooLong:u64 = 319;
    /// Denominator reference when scaling, default is 10000
    /// e.g. 5% = 5000/10000
    const DENOMINATOR: u64 = 10000;
    const DENOMINATORU128: u128 = 10000;
    const MAX_VALUE: u64 = {
        18446744073709551615 / 10000
    };

    struct List<phantom P, phantom T> has key,store {
        id: UID,
        total: u64,
        /// Market operator, 
        /// 1 project team
        /// 2 Certified Third Party
        /// 3 Community
        officer: u8,
        /// coin pool of the market
        pool: Pool<P,T>,
    }

    struct Market has key,store {
        id: UID,
        /// Maximum allowable leverage ratio
        max_leverage: u8,
        /// insurance rate
        insurance_fee: u64,
        /// margin rate,Current constant positioning 100%
        margin_fee: u64,
        /// The position fund rate will be calculated automatically according to the rules, 
        /// and this value will be used when manually set
        fund_fee: u64,
        /// Take the value of fund_fee when this value is true
        fund_fee_manual: bool,
        /// Point difference (can be understood as slip point),
        /// deviation between the executed quotation and the actual quotation
        spread_fee: u64,
        /// Take the value of spread_fee when this value is true
        spread_fee_manual: bool,
        /// Market status:
        /// 1. Normal;
        /// 2. Lock the market, allow closing settlement and not open positions;
        /// 3. The market is frozen, and opening and closing positions are not allowed.
        status: u8,
        /// Total amount of long positions in the market
        long_position_total: u64,
        /// Total amount of short positions in the market
        short_position_total: u64,
        /// Transaction pair (token type, such as BTC, ETH)
        symbol: String,
        icon: Url,
        officer: u8,
        /// market description
        description: String,
        /// Basic size of transaction pair contract
        /// Constant 1 in the field of encryption
        unit_size: u64,
        /// The price at 0 o'clock in the utc of the current day, which is used to calculate the spread_fee
        opening_price: u64,
        pyth_id: ID,
    }

    struct Price has drop,copy {
        buy_price: u64,
        sell_price: u64,
        real_price: u64,
        spread: u64,
    }

    public fun create_list<P: drop,T>(ctx: &mut TxContext): ID{
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        transfer::share_object( List<P,T>{
            id: uid,
            total: 0,
            officer: 2,
            pool: pool::create_pool<P,T>(),
        });
        event::create<List<Scale,T>>(id);
        id
    }

    public fun create_list_<T>(ctx: &mut TxContext): ID{
       create_list<Scale,T>(ctx)
    }
    
    public fun get_direction_price(price:&Price, direction: u8) : u64{
        if (direction == 1) {
            price.buy_price
        }else{
            price.sell_price
        }
    }

    public fun get_real_price(price: &Price) : u64{
        price.real_price
    }

    public fun get_buy_price(price: &Price) : u64{
        price.buy_price
    }

    public fun get_sell_price(price: &Price) : u64{
        price.sell_price
    }
    public fun get_spread(price: &Price) : u64{
        price.spread
    }

    fun get_price_(market: &Market, real_price: u64):Price{
        let spread = get_spread_fee(market,real_price) * real_price;
        // To increase the calculation accuracy
        let half_spread = spread / 2;
        Price{
            buy_price: (real_price * DENOMINATOR + half_spread) / DENOMINATOR,
            sell_price: (real_price * DENOMINATOR - half_spread) / DENOMINATOR,
            real_price,
            spread: spread,
        }
    }

    public fun get_pyth_price(root: &oracle::Root,id: ID):u64 {
        // todo: get real price from pyth
        let (price , _timestamp) = oracle::get_price(root,id);
        price
    }

    public fun get_price(market: &Market,root: &oracle::Root): Price {
        let real_price = get_pyth_price(root, market.pyth_id);
        get_price_(market, real_price)
    }

    public fun get_price_by_real(market: &Market, real_price: u64):Price {
        get_price_(market, real_price)
    }
    
    #[test_only]
    public fun set_opening_price_for_testing(market: &mut Market, opening_price: u64) {
        assert!(opening_price > 0 ,EInvalidOpingPrice);
        market.opening_price = opening_price;
    }
    public fun get_exposure(market: &Market):u64{
        math::max(market.long_position_total, market.short_position_total) - math::min(market.long_position_total, market.short_position_total)
    }
    /// 1 buy
    /// 2 sell
    /// 3 Balanced
    public fun get_dominant_direction(market: &Market) :u8{
        if (market.long_position_total == market.short_position_total) {
            3
        } else if (market.long_position_total > market.short_position_total) {
            1
        }else{
            2
        }
    }

    public fun get_curr_position_total(market: &Market,direction:u8):u64{
        if (direction==1){
            market.long_position_total
        }else{
            market.short_position_total
        }
    }
    public fun get_max_position_total(market: &Market):u64{
        math::max(market.long_position_total , market.short_position_total)
    }
    public fun get_min_position_total(market: &Market):u64{
        math::min(market.long_position_total , market.short_position_total)
    }

    public fun get_fund_fee(market: &Market,total_liquidity: u64) :u64{
        if (market.fund_fee_manual) {
            return market.fund_fee
        };
        let exposure = get_exposure(market);
        if (exposure == 0 || total_liquidity == 0) {
            return 0
        };
        let exposure_rate = exposure * DENOMINATOR / total_liquidity;
        if (exposure_rate <= 1000) { return 3 };
        if (exposure_rate > 1000 && exposure_rate <= 2000) {return 5 };
        if (exposure_rate > 2000 && exposure_rate <= 3000) {return 7 };
        if (exposure_rate > 3000 && exposure_rate <= 4000) {return 10};
        if (exposure_rate > 4000 && exposure_rate <= 5000) {return 20};
        if (exposure_rate > 5000 && exposure_rate <= 6000) {return 40};
        return 70
    }

    public fun get_spread_fee(market: &Market,real_price: u64) : u64{
        if (market.spread_fee_manual) {
            return market.spread_fee
        };
        assert!(market.opening_price > 0, EInvalidOpeningPrice);
        let change_price = math::max(real_price, market.opening_price) - math::min(real_price, market.opening_price);
        let change = change_price * DENOMINATOR / market.opening_price;
        if (change <= 300) {return 30};
        if (change > 300 && change <= 1000) {
            return change / 10
        };
        return 150
    }

    public fun get_uid(market: &Market ) : &UID{
        &market.id
    }

    public(friend) fun get_uid_mut(market: &mut Market) : &mut UID{
        &mut market.id
    }

    public fun get_max_leverage(market: &Market) : u8 {
        market.max_leverage
    }

    public fun get_insurance_fee(market: &Market) : u64{
        market.insurance_fee
    }

    public fun get_margin_fee(market: &Market) : u64{
        market.margin_fee
    }

    public fun get_status(market: &Market) : u8{
        market.status
    }

    public fun get_long_position_total(market: &Market) : u64{
        market.long_position_total
    }
    #[test_only]
    public fun set_long_position_total_for_testing(market: &mut Market, value: u64) {
        market.long_position_total = value
    }
    public fun get_short_position_total(market: &Market) : u64{
        market.short_position_total
    }
    #[test_only]
    public fun set_short_position_total_for_testing(market: &mut Market, value: u64) {
        market.short_position_total = value
    }
    public(friend) fun inc_long_position_total(self: &mut Market, value: u64) {
        self.long_position_total = self.long_position_total + value;
    }
    public(friend) fun dec_long_position_total(self: &mut Market, value: u64) {
        self.long_position_total = self.long_position_total - value;
    }
    public(friend) fun inc_short_position_total(self: &mut Market, value: u64) {
        self.short_position_total = self.short_position_total + value;
    }
    public(friend) fun dec_short_position_total(self: &mut Market, value: u64) {
        self.short_position_total = self.short_position_total - value;
    }
    public fun get_symbol(market: &Market) : &String{
        &market.symbol
    }
    public fun get_description(market: &Market) : &String{
        &market.description
    }
    public fun get_officer<P,T>(list: &List<P,T>) : u8{
        list.officer
    }
    public fun get_pool<P,T>(list: &List<P,T>) : &Pool<P,T>{
        &list.pool
    }
    public fun get_opening_price_value(market: &Market) : u64{
        market.opening_price
    }
    public(friend) fun get_pool_mut<P,T>(list:&mut List<P,T>) : &mut Pool<P,T>{
        &mut list.pool
    }
    #[test_only]
    public fun get_pool_mut_for_testing<P,T>(list: &mut List<P,T>) : &mut Pool<P,T>{
        &mut list.pool
    }
    public fun get_unit_size(market: &Market) : u64{
        market.unit_size
    }
    public fun get_denominator() : u64{
        DENOMINATOR
    }
    public fun get_max_value() : u64 {
        MAX_VALUE
    }
    public fun get_list_uid<P,T>(list: &List<P,T>):&UID {
        &list.id
    }
    public fun get_list_uid_mut<P,T>(list: &mut List<P,T>):&mut UID {
        &mut list.id
    }
    public fun get_matket_total<P,T>(list: &List<P,T>):u64 {
        list.total
    }
    /// Create a market
    public fun create_market <P,T>(
        list: &mut List<P,T>,
        symbol: vector<u8>,
        icon: vector<u8>,
        description: vector<u8>,
        unit_size: u64,
        opening_price: u64,
        pyth_id: ID,
        ctx: &mut TxContext
    ): ID {
        assert!(!vector::is_empty(&symbol), ENameRequired);
        assert!(vector::length(&symbol) < 20, ENameTooLong);
        assert!(!vector::is_empty(&icon), EIconRequired);
        assert!(vector::length(&icon) < 280, EIconTooLong);
        assert!(vector::length(&description) < 180, EDescriptionTooLong);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        assert!(unit_size > 0,EInvalidSize);
        assert!(opening_price > 0,EInvalidOpeningPrice);
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        admin::create_scale_admin(id,ctx);
        dof::add(&mut list.id, symbol, Market{
            id: uid,
            max_leverage: 125,
            insurance_fee: 5,
            margin_fee: 10000,
            fund_fee: 1,
            fund_fee_manual: false,
            status: 1,
            long_position_total: 0,
            short_position_total: 0,
            symbol: string::utf8(symbol),
            icon: url::new_unsafe_from_bytes(icon),
            description: string::utf8(description),
            spread_fee: 1000,
            spread_fee_manual: false,
            officer: 2,
            unit_size,
            opening_price,
            pyth_id,
        });
        list.total = list.total + 1;
        event::create<Market>(id);
        id
    }

    public fun update_max_leverage(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        max_leverage: u8,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(max_leverage > 0 && max_leverage < 255,EInvalidLeverage);
        market.max_leverage = max_leverage;
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    public fun update_insurance_fee(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        insurance_fee: u64,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(insurance_fee > 0 && insurance_fee <= DENOMINATOR, EInvalidInsuranceRate);
        market.insurance_fee = insurance_fee;
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    public fun update_margin_fee(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        margin_fee: u64,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(margin_fee > 0 && margin_fee <= DENOMINATOR, EInvalidMarginRate);
        market.margin_fee = margin_fee;
        event::update<Market>(object::uid_to_inner(&market.id));
    }
    public fun update_fund_fee(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        fund_fee: u64,
        manual: bool,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(fund_fee > 0 && fund_fee <= DENOMINATOR, EInvalidFundRate);
        market.fund_fee = fund_fee;
        market.fund_fee_manual = manual;
        event::update<Market>(object::uid_to_inner(&market.id));
    }
    public fun update_status(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        status: u8,
        ctx: &mut TxContext
    ){
        assert!(admin::is_super_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(status > 0 && status <= 3,EInvalidStatus);
        market.status = status;
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    public fun update_description(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        description: vector<u8>,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        market.description = string::utf8(description);
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    public fun update_icon(
        pac:&mut ScaleAdminCap,
        market:&mut Market,
        icon: vector<u8>,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(!vector::is_empty(&icon), EIconRequired);
        assert!(vector::length(&icon) < 280, EIconTooLong);
        market.icon = url::new_unsafe_from_bytes(icon);
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    public fun update_spread_fee(
        pac: &mut ScaleAdminCap,
        market:&mut Market,
        spread_fee: u64,
        manual: bool,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(spread_fee > 0 && spread_fee <= DENOMINATOR,EInvalidSpread);
        market.spread_fee = spread_fee;
        market.spread_fee_manual = manual;
        event::update<Market>(object::uid_to_inner(&market.id));
    }
    /// Update the officer of the market
    /// Only the contract creator has permission to modify this item
    public fun update_officer(
        _cap:&mut AdminCap,
        market:&mut Market,
        officer: u8,
        _ctx: &mut TxContext
    ){
        assert!(officer > 0 && officer < 4,EInvalidOfficer);
        market.officer = officer;
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    /// When the robot fails to update the price, update manually
    // public fun update_oping_price(
    //     pac:&mut ScaleAdminCap,
    //     market:&mut Market,
    //     opening_price: u64,
    //     ctx: &mut TxContext
    // ){
    //     assert!(admin::is_super_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
    //     assert!(opening_price > 0 ,EInvalidOpingPrice);
    //     market.opening_price = opening_price;
    // }

    /// The robot triggers at 0:00 every day to update the price of the day
    public fun trigger_update_opening_price(
        market: &mut Market,
        root: &oracle::Root,
        _ctx: &mut TxContext
    ){
        let real_price = get_pyth_price(root, market.pyth_id);
        // todo check price time and openg price must gt 0
        assert!(real_price > 0,EInvalidOpingPrice);
        market.opening_price = real_price;
        event::update<Market>(object::uid_to_inner(&market.id));
    }

    // #[test_only]
    // public fun init_for_testing(ctx: &mut TxContext){
    //     init(ctx);
    // }
}