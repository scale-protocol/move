module price::oracle {
    use std::string::{Self,String};
    use sui::object::{Self,UID};
    use std::vector;
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;

    const ENameRequired:u64 = 1;
    const ENameTooLong:u64 = 2;
    const EInvalidTimestamp:u64 = 3;
    const EInvalidOwner:u64 = 4;

    struct AdminCap has key {
        id: UID
    }

    struct PriceFeed has key{
        id:UID,
        symbol: String,
        price: u64,
        owner: address,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        },tx_context::sender(ctx));
    }

    public entry fun create_price_feed(_admin: &mut AdminCap, symbol:vector<u8>, ctx: &mut TxContext){
        assert!(!vector::is_empty(&symbol), ENameRequired);
        assert!(vector::length(&symbol) < 20, ENameTooLong);
        transfer::share_object(PriceFeed{
            id: object::new(ctx),
            symbol: string::utf8(symbol),
            price: 0,
            owner: tx_context::sender(ctx),
            timestamp: 0,
        });
    }

    public entry fun update_owner(
        _admin: &mut AdminCap,
        feed: &mut PriceFeed,
        new_owner: address,
        _ctx: &TxContext
    ){
        feed.owner = new_owner;
    }

    public entry fun update_price(
        feed: &mut PriceFeed,
        price: u64,
        timestamp: u64,
        ctx: &TxContext
    ){
        assert!(timestamp > feed.timestamp, EInvalidTimestamp);
        assert!(tx_context::sender(ctx) == feed.owner, EInvalidOwner);
        feed.price = price;
        feed.timestamp = timestamp;
    }

    public fun get_price(feed: &PriceFeed): (u64, u64){
        (feed.price, feed.timestamp)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
}

#[test_only]
module price::oracle_tests {
    use price::oracle;
    use sui::test_scenario;
    use std::debug;

    #[test]
    fun test_price(){
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
            let symbol = b"Crypto.BTC/USD";
            oracle::create_price_feed(&mut admin_cap, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::next_tx(tx,owner);
        {
            let feed = test_scenario::take_shared<oracle::PriceFeed>(tx);
            let (price, timestamp) = oracle::get_price(&feed);
            assert!(price == 0,1);
            assert!(timestamp == 0,1);
            oracle::update_price(&mut feed, 100, 100, test_scenario::ctx(tx));
            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(tx,owner);
        {
            let feed = test_scenario::take_shared<oracle::PriceFeed>(tx);
            let (price, timestamp) = oracle::get_price(&feed);
            assert!(price == 100,1);
            assert!(timestamp == 100,2);
            test_scenario::return_shared(feed);
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
            let symbol = b"";
            oracle::create_price_feed(&mut admin_cap, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
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
            oracle::create_price_feed(&mut admin_cap, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::end(test_tx);
    }
    #[test]
    #[expected_failure(abort_code = 3, location = oracle)]
    fun test_exception_price_timestamp(){
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
            let symbol = b"Crypto.BTC/USD";
            oracle::create_price_feed(&mut admin_cap, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::next_tx(tx,owner);
        {
            let feed = test_scenario::take_shared<oracle::PriceFeed>(tx);
            oracle::update_price(&mut feed, 100, 200, test_scenario::ctx(tx));
            // abort code 3
            oracle::update_price(&mut feed, 100, 100, test_scenario::ctx(tx));
            test_scenario::return_shared(feed);
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
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let symbol = b"Crypto.BTC/USD";
            oracle::create_price_feed(&mut admin_cap, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::next_tx(tx,owner);
        {
            let feed = test_scenario::take_shared<oracle::PriceFeed>(tx);
            oracle::update_price(&mut feed, 100, 99, test_scenario::ctx(tx));
            debug::print(&feed);
            test_scenario::return_shared(feed);
        };
        test_scenario::next_tx(tx,owner2);
        {
            let feed = test_scenario::take_shared<oracle::PriceFeed>(tx);
            let (price, timestamp) = oracle::get_price(&feed);
            assert!(price == 100,1);
            assert!(timestamp == 99,2);
            // abort code 4
            oracle::update_price(&mut feed, 100, 200, test_scenario::ctx(tx));
            test_scenario::return_shared(feed);
        };
        test_scenario::end(test_tx);
    }
}