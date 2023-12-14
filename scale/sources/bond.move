#[lint_allow(self_transfer)]
#[allow(unused_function)]
module scale::bond {
    use sui::object::{Self,UID,ID};
    use std::string::{Self,utf8, String};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self,Balance};
    use scale::pool::{Self,LSP,Scale};
    use scale::market::{Self,List};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self,TxContext,sender};
    use std::vector;
    use sui::transfer;
    use sui::table::{Self,Table};
    use scale::admin::AdminCap;
    use sui::dynamic_field as field;
    use scale::event;
    use sui::package::{Self, Publisher};
    use sui::display;

    friend scale::enter;
    #[test_only]
    friend scale::bond_tests;
    // day
    const SETTLEMENT_CYCLE:u64 = 30;
    const DENOMINATOR: u64 = 10000;

    const ENameRequired:u64 = 401;
    const EDescriptionRequired:u64 = 402;
    const EUrlRequired:u64 = 403;
    // const EInvalidNFTID:u64 = 404;
    const EInvalidMarketID:u64 = 405;
    const EInsufficientCoins:u64 = 406;
    const EInvalidIssueTime:u64 = 407;
    const EInvalidPenaltyFee:u64 = 408;
    const EInvalidSettlementCycle:u64 = 409;

    /// scale bond nft
    struct ScaleBond<phantom T> has key ,store {
        id: UID,
        name: String,
	    description: String,
	    image_url: String,
        mint_time: u64,
        denomination: Balance<LSP<Scale,T>>,
        issue_expiration_time: u64,
        list_id: ID,
        latest_settlement_ms: u64,
    }

    struct BOND has drop {}

    /// The scale nft factory stores some token templates and styles
    struct BondFactory has key {
        id: UID,
        penalty_fee: u64,
        mould: Table<String,BondItem>,
        latest_epoch: u64,
        // Reward a portion of profits to the NFT holder
        award_ratio: u64, 
    }
    /// The scale nft item
    struct BondItem has store {
        name: String,
	    description: String,
	    image_url: String,
    }

    fun init(otw: BOND, ctx: &mut TxContext){
        let publisher = package::claim(otw, ctx);
        transfer::public_transfer(publisher, sender(ctx));
        transfer::share_object(BondFactory{
            id: object::new(ctx),
            penalty_fee: 300,
            mould: table::new<String,BondItem>(ctx),
            latest_epoch: 0,
            award_ratio: 1000,
        })
    }

    public(friend) fun create_display<T>(publisher: &Publisher,ctx: &mut TxContext){
        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        let values = vector[
            utf8(b"{name}"),
            utf8(b"https://clutchy.io/marketplace/item/{id}"),
            utf8(b"{image_url}"),
            utf8(b"{description}"),
            utf8(b"https://scale.exchange"),
            utf8(b"Scale Protocol Team"),
        ];
        let display = display::new_with_fields<ScaleBond<T>>(
            publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(display, sender(ctx));
    }
    /// Provide current pool funds and obtain NFT bond certificates
    public fun investment<T>(
        token: Coin<T>,
        nft_name: vector<u8>,
        amount: u64,
        issue_time_ms: u64,
        list: &mut List<T>,
        factory: &mut BondFactory,
        c: &Clock,
        ctx: &mut TxContext
    ){
        assert!(issue_time_ms > 0, EInvalidIssueTime);
        let now = clock::timestamp_ms(c);
        assert!(issue_time_ms > now, EInvalidIssueTime);
        let coins = coin::zero<T>(ctx);
        if (amount == 0){
            coin::join(&mut coins,token);
        }else{
            assert!(amount <= coin::value(&token), EInsufficientCoins);
            coin::join(&mut coins,coin::split(&mut token, amount, ctx));
            transfer::public_transfer(token,tx_context::sender(ctx));
        };
        assert!(!vector::is_empty(&nft_name), ENameRequired);
        let mould = table::borrow(&factory.mould,string::utf8(nft_name));
        let uid = object::new(ctx);
        // Index all existing NFTs for interest distribution
        field::add(&mut factory.id,object::uid_to_inner(&uid),now);
        transfer::transfer(ScaleBond<T> {
            id: uid,
            name: mould.name,
            description: mould.description,
            image_url: mould.image_url,
            mint_time: now,
            denomination: coin::into_balance(pool::add_liquidity(market::get_pool_mut(list),coins,ctx)),
            issue_expiration_time: now + issue_time_ms,
            list_id: object::id(list),
            latest_settlement_ms: clock::timestamp_ms(c),
        },tx_context::sender(ctx));
        event::update<List<T>>(object::id(list));
    }

    /// Withdraw funds from the current pool and destroy NFT bond certificates
    public fun divestment<T>(
        nft: ScaleBond<T>,
        list: &mut List<T>,
        factory: &mut BondFactory,
        c: &Clock,
        ctx: &mut TxContext
    ){
        let ScaleBond<T> {
            id,
            name,
            description:_,
            image_url:_,
            mint_time:_,
            denomination,
            issue_expiration_time,
            list_id,
            latest_settlement_ms:_,
        } = nft;
        assert!(list_id == object::id(list), EInvalidMarketID);
        let p = market::get_pool_mut(list);
        let bl = pool::remove_liquidity(p,denomination,ctx);
        // Collect penalty for breach of contract
        if (clock::timestamp_ms(c) < issue_expiration_time  && factory.penalty_fee > 0 && name != string::utf8(b"freely")){
            let penalty = coin::value(&bl) * factory.penalty_fee / DENOMINATOR;
            pool::join_profit_balance<Scale,T>(p,coin::into_balance(coin::split(&mut bl,penalty,ctx)),tx_context::epoch(ctx));
        };
        let _: u64 = field::remove(&mut factory.id,object::uid_to_inner(&id));
        transfer::public_transfer(bl,tx_context::sender(ctx));
        object::delete(id);
    }

    /// Project side add NFT style
    public fun add_factory_mould(
        _admin_cap:&mut AdminCap,
        factory: &mut BondFactory,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        _ctx: &TxContext
    ) {
        assert!(!vector::is_empty(&name), ENameRequired);
        assert!(!vector::is_empty(&description), EDescriptionRequired);
        assert!(!vector::is_empty(&url), EUrlRequired);
        let name = string::utf8(name);
        table::add(&mut factory.mould,name,BondItem{
            name,
            description: string::utf8(description),
            image_url: string::utf8(url),
        });
    }

    /// Project side delete NFT style
    public fun remove_factory_mould(
        _admin_cap: &mut AdminCap,
        factory: &mut BondFactory,
        name: vector<u8>,
        _ctx: &TxContext
    ) {
        assert!(!vector::is_empty(&name), ENameRequired);
        let BondItem {name:_,description:_,image_url:_} = table::remove(&mut factory.mould,string::utf8(name));
    }

    public fun set_penalty_fee(
        _admin_cap: &mut AdminCap,
        factory: &mut BondFactory,
        penalty_fee: u64,
    ) {
        assert!(penalty_fee > 0 && factory.penalty_fee <= DENOMINATOR, EInvalidPenaltyFee);
        factory.penalty_fee = penalty_fee;
    }

    public fun set_award_ratio(
        _admin_cap: &mut AdminCap,
        factory: &mut BondFactory,
        ratio: u64,
    ) {
        assert!(ratio > 0 && ratio <= DENOMINATOR, EInvalidPenaltyFee);
        factory.award_ratio = ratio;
    }

    public fun receive_award<T>(
        nft: &mut ScaleBond<T>,
        list: &mut List<T>,
        factory: &BondFactory,
        c: &Clock,
        ctx: &mut TxContext,
    ) {
        let now = clock::timestamp_ms(c);
        assert!(now - nft.latest_settlement_ms >= SETTLEMENT_CYCLE * 24 * 60 * 60 * 1000, EInvalidSettlementCycle);
        assert!(nft.list_id == object::id(list), EInvalidMarketID);
        let p = market::get_pool_mut(list);
        let total_award = pool::get_total_epoch_profit(p,SETTLEMENT_CYCLE);
        let award = total_award * factory.award_ratio * balance::value(&nft.denomination) / (pool::get_vault_supply(p) * DENOMINATOR);
        if (award > 0) {
            let c: Coin<T> = coin::from_balance(pool::take_profit_award(p,award),ctx);
            transfer::public_transfer(c,sender(ctx));
            nft.latest_settlement_ms = now;
        }
    }

    public fun get_bond_denomination<T>(nft: &ScaleBond<T>): u64{
        balance::value(&nft.denomination)
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(BOND{},ctx);
    }
    #[test_only]
    public fun create_bond_for_testing():BOND{
        BOND{}
    }
}