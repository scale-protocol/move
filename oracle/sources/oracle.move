module oracle::oracle {
    use std::string::{Self,String};
    use sui::object::{Self,UID,ID};
    use std::vector;
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;
    use sui::dynamic_object_field as dof;

    const ENameRequired:u64 = 1;
    const ENameTooLong:u64 = 2;
    const EInvalidTimestamp:u64 = 3;
    const EInvalidOwner:u64 = 4;

    struct AdminCap has key {
        id: UID
    }

    struct Root has key {
        id: UID,
        total: u64,
    }

    struct PriceFeed has key,store {
        id: UID,
        symbol: String,
        price: u64,
        owner: address,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        },tx_context::sender(ctx));
        transfer::share_object(Root{
            id: object::new(ctx),
            total: 0,
        });
    }

    fun new_price_feed(symbol: vector<u8>, ctx: &mut TxContext): PriceFeed {
        assert!(!vector::is_empty(&symbol), ENameRequired);
        assert!(vector::length(&symbol) < 20, ENameTooLong);
        PriceFeed{
            id: object::new(ctx),
            symbol: string::utf8(symbol),
            price: 0,
            owner: tx_context::sender(ctx),
            timestamp: 0,
        }
    }

    public entry fun create_price_feed(
        _admin: &mut AdminCap,
        root: &mut Root,
        symbol: vector<u8>,
        ctx: &mut TxContext,
        ){
        let price_feed = new_price_feed(symbol,ctx);
        let id = object::uid_to_inner(&price_feed.id);
        dof::add(&mut root.id,id,price_feed);
    }

    #[test_only]
    public fun create_price_feed_for_testing(
        _admin: &mut AdminCap,
        root: &mut Root,
        symbol: vector<u8>,
        ctx: &mut TxContext,
        ): ID {
        let price_feed = new_price_feed(symbol, ctx);
        let id = object::uid_to_inner(&price_feed.id);
        dof::add(&mut root.id, id, price_feed);
        id
    }
    
    public entry fun update_owner(
        _admin: &mut AdminCap,
        root: &mut Root,
        feed_id: ID,
        new_owner: address,
        _ctx: &TxContext
    ){
        let feed: &mut PriceFeed = dof::borrow_mut(&mut root.id, feed_id);
        feed.owner = new_owner;
    }

    public entry fun update_price(
        root: &mut Root,
        feed_id: ID,
        price: u64,
        timestamp: u64,
        ctx: &TxContext
    ){
        let feed: &mut PriceFeed = dof::borrow_mut(&mut root.id, feed_id);
        assert!(timestamp > feed.timestamp, EInvalidTimestamp);
        assert!(tx_context::sender(ctx) == feed.owner, EInvalidOwner);
        feed.price = price;
        feed.timestamp = timestamp;
    }

    public fun get_price(root: &Root,feed_id: ID): (u64, u64){
        let feed: &PriceFeed = dof::borrow(&root.id, feed_id);
        (feed.price, feed.timestamp)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
    public fun get_uid(root: &Root): &UID {
        &root.id
    }
}

#[test_only]
module oracle::oracle_tests {
    use oracle::oracle;
    use sui::test_scenario;
    use std::debug;
    use sui::object::ID;
    // use sui::dynamic_object_field as dof;

    #[test]
    fun test_price(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let id: ID;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let root = test_scenario::take_shared<oracle::Root>(tx);
            let symbol = b"Crypto.BTC/USD";
            id = oracle::create_price_feed_for_testing(&mut admin_cap, &mut root, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(root);
        };
        test_scenario::next_tx(tx,owner);
        {
            let root = test_scenario::take_shared<oracle::Root>(tx);
            // let feed: &oracle::PriceFeed = dof::borrow(oracle::get_uid(&root), id);
            let (price, timestamp) = oracle::get_price(&root, id);
            assert!(price == 0,1);
            assert!(timestamp == 0,1);
            oracle::update_price(&mut root,id, 100, 100, test_scenario::ctx(tx));
            test_scenario::return_shared(root);
        };
        test_scenario::next_tx(tx,owner);
        {
            let root = test_scenario::take_shared<oracle::Root>(tx);
            // let feed: &oracle::PriceFeed = dof::borrow(oracle::get_uid(&root), id);
            let (price, timestamp) = oracle::get_price(&root, id);
            assert!(price == 100,1);
            assert!(timestamp == 100,2);
            test_scenario::return_shared(root);
        };
        test_scenario::end(test_tx);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = oracle)]
    fun test_exception_symbol_required(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let root = test_scenario::take_shared<oracle::Root>(tx);
            let symbol = b"";
            oracle::create_price_feed_for_testing(&mut admin_cap, &mut root,symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(root);
        };
        test_scenario::end(test_tx);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = oracle)]
    fun test_exception_symbol_length(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let symbol = b"Crypto.BTC/USDCrypto.BTC/USDCrypto.BTC/USDCrypto.BTC/USD";
            let root = test_scenario::take_shared<oracle::Root>(tx);
            oracle::create_price_feed_for_testing(&mut admin_cap,&mut root, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(root);
        };
        test_scenario::end(test_tx);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = oracle)]
    fun test_exception_price_timestamp(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let id: ID;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let symbol = b"Crypto.BTC/USD";
            let root = test_scenario::take_shared<oracle::Root>(tx);
            id = oracle::create_price_feed_for_testing(&mut admin_cap,&mut root, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
             test_scenario::return_shared(root);
        };
        test_scenario::next_tx(tx,owner);
        {
            let root = test_scenario::take_shared<oracle::Root>(tx);
            oracle::update_price(&mut root, id, 100, 200, test_scenario::ctx(tx));
            // abort code 3
            oracle::update_price(&mut root, id, 100, 100, test_scenario::ctx(tx));
            test_scenario::return_shared(root);
        };
        test_scenario::end(test_tx);
    }
    #[test]
    #[expected_failure(abort_code = 4, location = oracle)]
    fun test_exception_owner(){
        let owner = @0x1;
        let owner2 = @0x2;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let id: ID;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let symbol = b"Crypto.BTC/USD";
            let root = test_scenario::take_shared<oracle::Root>(tx);
            id = oracle::create_price_feed_for_testing(&mut admin_cap, &mut root, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(root);
        };
        test_scenario::next_tx(tx,owner);
        {
            let root = test_scenario::take_shared<oracle::Root>(tx);
            oracle::update_price(&mut root, id, 100, 99, test_scenario::ctx(tx));
            debug::print(&root);
            test_scenario::return_shared(root);
        };
        test_scenario::next_tx(tx,owner2);
        {
            let root = test_scenario::take_shared<oracle::Root>(tx);
            let (price, timestamp) = oracle::get_price(&root, id);
            assert!(price == 100,1);
            assert!(timestamp == 99,2);
            // abort code 4
            oracle::update_price(&mut root,id, 100, 200, test_scenario::ctx(tx));
            test_scenario::return_shared(root);
        };
        test_scenario::end(test_tx);
    }
}