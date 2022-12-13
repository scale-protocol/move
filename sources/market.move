module scale::market{
    use sui::object::{Self,UID,ID};
    use std::string::{Self,String};
    use sui::tx_context::{Self,TxContext};
    use scale::admin::{Self,ScaleAdminCap,AdminCap};
    use scale::pool::{Self,Pool};
    use sui::coin::{Coin};
    use sui::transfer;
    use std::vector;
    use sui::math;
    use sui::dynamic_object_field as dof;

    const ELSPCreatorPermissionRequired:u64 = 1;
    const EInvalidLeverage:u64 = 2;
    const EInvalidSpread:u64 = 3;
    const EInvalidInsuranceRate:u64 = 4;
    const EInvalidMarginRate:u64 = 5;
    const EInvalidStatus:u64 = 6;
    const ENameRequired:u64 = 7;
    const EDescriptionRequired:u64 = 8;
    const ENoPermission:u64 = 9;
    const EInvalidSellPrice:u64 = 10;
    const EInvalidSize:u64 = 11;
    

    const MAX_VALUE: u64 = {
        18446744073709551615 / 10000
    };
    ///  For example, when the exposure proportion is 70%, this value is 7/1000.
    const FUND_RATE: u64 = 100;

    struct MarketList has key {
        id: UID,
        total: u64,
    }

    struct Market<phantom P, phantom T> has key,store {
        id: UID,
        /// Maximum allowable leverage ratio
        max_leverage: u8,
        /// insurance rate
        insurance_rate: u64,
        /// margin rate,Current constant positioning 100%
        margin_rate: u64,
        /// Market status:
        /// 1 Normal;
        /// 2. Lock the market, allow closing settlement and not open positions;
        /// 3 The market is frozen, and opening and closing positions are not allowed.
        status: u8,
        /// Total amount of long positions in the market
        long_position_total: u64,
        /// Total amount of short positions in the market
        short_position_total: u64,
        /// Transaction pair (token type, such as BTC, ETH)
        /// len: 4+20
        name: String,
        /// market description
        description: String,
        /// Point difference (can be understood as slip point),
        /// deviation between the executed quotation and the actual quotation
        spread: u64,
        /// Market operator, 1 project party, other marks to be defined
        officer: bool,
        /// coin pool of the market
        pool: Pool<P,T>,
        /// Basic size of transaction pair contract
        /// Constant 1 in the field of encryption
        size: u64,
        /// Denominator reference when scaling, default is 10000
        /// e.g. 5% = 5000/10000
        denominator: u64,
        pyth_id: ID,
    }

    struct Price has drop,copy {
        buy_price: u64,
        sell_price: u64,
        real_price: u64,
        // spread: u64,
    }

    fun new_market_list(ctx: &mut TxContext):MarketList{
        MarketList{
            id: object::new(ctx),
            total: 0,
        }
    }

    fun init(ctx: &mut TxContext){
        transfer::share_object(new_market_list(ctx));
    }

    public fun get_direction_price(price:&Price, direction: u8) : u64{
        if (direction == 1) {
            price.buy_price
        }else{
            price.sell_price
        }
    }
    
    public fun set_direction_price(price:&mut Price, direction: u8, price_value: u64) {
        if (direction == 1) {
            price.buy_price = price_value;
        }else{
            price.sell_price = price_value;
        }
    }

    public fun get_real_price(price:&Price) : u64{
        price.real_price
    }

    public fun get_buy_price(price:&Price) : u64{
        price.buy_price
    }

    public fun get_sell_price(price:&Price) : u64{
        price.sell_price
    }

    public fun get_price<P,T>(market: &Market<P,T>): Price {
        let real_price = 1000_000_000;
        assert!(real_price > market.spread, EInvalidSellPrice);
        let sell_price = real_price - market.spread;
        Price{
            buy_price: real_price + market.spread,
            sell_price,
            real_price,
            // spread: market.spread,
        }
    }

    public fun get_exposure<P,T>(market: &Market<P,T>):u64{
        math::max(market.long_position_total, market.short_position_total) - math::min(market.long_position_total, market.short_position_total)
    }
    /// 1 buy
    /// 2 sell
    public fun get_dominant_direction<P,T>(market: &Market<P,T>) :u8{
        if (market.long_position_total > market.short_position_total) {
            1
        }else{
            2
        }
    }

    public fun get_total_liquidity<P,T>(market: &Market<P,T>) :u64{
        pool::get_vault_balance(&market.pool) + pool::get_profit_balance(&market.pool)
    }

    // public fun get_fund_rate<P,T>(market: &Market<P,T>) :u64{
    //     FUND_RATE
    // }

    public fun get_uid<P,T>(market:&Market<P,T>) : &UID{
        &market.id
    }
    public fun get_uid_mut<P,T>(market:&mut Market<P,T>) : &mut UID{
        &mut market.id
    }
    public fun get_max_leverage<P,T>(market: &Market<P,T>) : u8{
        market.max_leverage
    }
    public fun get_insurance_rate<P,T>(market: &Market<P,T>) : u64{
        market.insurance_rate
    }
    public fun get_margin_rate<P,T>(market: &Market<P,T>) : u64{
        market.margin_rate
    }
    public fun get_status<P,T>(market: &Market<P,T>) : u8{
        market.status
    }
    public fun get_long_position_total<P,T>(market: &Market<P,T>) : u64{
        market.long_position_total
    }
    public fun get_short_position_total<P,T>(market: &Market<P,T>) : u64{
        market.short_position_total
    }
    public fun inc_long_position_totail<P,T>(self: &mut Market<P,T>, value: u64) {
        self.long_position_total = self.long_position_total + value;
    }
    public fun dec_long_position_totail<P,T>(self: &mut Market<P,T>, value: u64) {
        self.long_position_total = self.long_position_total - value;
    }
    public fun inc_short_position_totail<P,T>(self: &mut Market<P,T>, value: u64) {
        self.short_position_total = self.short_position_total + value;
    }
    public fun dec_short_position_totail<P,T>(self: &mut Market<P,T>, value: u64) {
        self.short_position_total = self.short_position_total - value;
    }
    public fun get_name<P,T>(market: &Market<P,T>) : &String{
        &market.name
    }
    public fun get_description<P,T>(market: &Market<P,T>) : &String{
        &market.description
    }
    public fun get_spread<P,T>(market: &Market<P,T>) : u64{
        market.spread
    }
    public fun is_officer<P,T>(market: &Market<P,T>) : bool{
        market.officer
    }
    public fun get_pool<P,T>(market: &Market<P,T>) : &Pool<P,T>{
        &market.pool
    }
    public fun get_pool_mut<P,T>(market:&mut Market<P,T>) : &mut Pool<P,T>{
        &mut market.pool
    }
    public fun get_size<P,T>(market: &Market<P,T>) : u64{
        market.size
    }
    public fun get_denominator<P,T>(market: &Market<P,T>) : u64{
        market.denominator
    }
    public fun get_max_value() : u64 {
        MAX_VALUE
    }
    public fun get_list_uid(list: &MarketList):&UID {
        &list.id
    }
    public fun get_list_uid_mut(list: &mut MarketList):&mut UID {
        &mut list.id
    }
    public fun get_matket_total(list: &MarketList):u64 {
        list.total
    }
    /// Create a market
    public entry fun create_market <P,T>(
        list: &mut MarketList,
        token: &Coin<T>,
        name: vector<u8>,
        description: vector<u8>,
        size: u64,
        spread: u64,
        pyth_id: ID,
        ctx: &mut TxContext
    ){
        assert!(!vector::is_empty(&name), ENameRequired);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        assert!(spread > 0,EInvalidSpread);
        assert!(size > 0,EInvalidSize);
        let uid = object::new(ctx);
        dof::add(&mut list.id,object::uid_to_inner(&uid),Market{
            id: uid,
            max_leverage: 125,
            insurance_rate: 5,
            margin_rate: 10000,
            status: 1,
            long_position_total: 0,
            short_position_total: 0,
            name: string::utf8(name),
            description: string::utf8(description),
            spread: spread,
            officer: false,
            pool: pool::create_pool_(token),
            size,
            denominator: 10000,
            pyth_id,
        });
    }

    public entry fun update_max_leverage<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        max_leverage: u8,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(max_leverage > 0 && max_leverage < 255,EInvalidLeverage);
        market.max_leverage = max_leverage;
    }

    public entry fun update_insurance_rate<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        insurance_rate: u64,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(insurance_rate > 0 && insurance_rate <= MAX_VALUE, EInvalidInsuranceRate);
        market.insurance_rate = insurance_rate;
    }

    public entry fun update_margin_rate<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        margin_rate: u64,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(margin_rate > 0 && margin_rate <= MAX_VALUE, EInvalidMarginRate);
        market.margin_rate = margin_rate;
    }

    public entry fun update_status<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        status: u8,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(status > 0 && status <= 3,EInvalidStatus);
        market.status = status;
    }

    public entry fun update_description<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        description: vector<u8>,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        market.description = string::utf8(description);
    }

    public entry fun update_spread<P,T>(
        pac:&mut ScaleAdminCap,
        market:&mut Market<P,T>,
        spread: u64,
        ctx: &mut TxContext
    ){
        assert!(admin::is_admin(pac,&tx_context::sender(ctx),object::uid_to_inner(&mut market.id)),ENoPermission);
        assert!(spread > 0,EInvalidSpread);
        market.spread = spread;
    }
    /// Update the officer of the market
    /// Only the contract creator has permission to modify this item
    public entry fun update_officer<P,T>(
        _cap:&mut AdminCap,
        market:&mut Market<P,T>,
        officer: bool,
        _ctx: &mut TxContext
    ){
        market.officer = officer;
    }
}