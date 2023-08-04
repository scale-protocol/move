#[test_only]
module oracle::oracle_tests {
    use oracle::oracle;
    use sui::test_scenario;
    use std::debug;
    use sui::clock;
    // use sui::dynamic_object_field as dof;

    #[test]
    fun test_price(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let symbol: vector<u8>;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let state = test_scenario::take_shared<oracle::State>(tx);
            symbol = b"Crypto.BTC/USD";
            oracle::create_price_feed(&mut admin_cap, &mut state, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(tx,owner);
        {
            let state = test_scenario::take_shared<oracle::State>(tx);
            // let feed: &oracle::PriceFeed = dof::borrow(oracle::get_uid(&state), id);
            let c = clock::create_for_testing(test_scenario::ctx(tx));
            clock::set_for_testing(&mut c, 101*1000);
            oracle::update_price_for_testing(&mut state,symbol, 100, 100, test_scenario::ctx(tx));
            let (price, timestamp) = oracle::get_price(&state, symbol,&c);
            assert!(price == 100,1);
            assert!(timestamp == 100,1);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(c);
        };
        test_scenario::next_tx(tx,owner);
        {
            let state = test_scenario::take_shared<oracle::State>(tx);
            // let feed: &oracle::PriceFeed = dof::borrow(oracle::get_uid(&state), id);
            let c = clock::create_for_testing(test_scenario::ctx(tx));
            clock::set_for_testing(&mut c, 101*1000);
            let (price, timestamp) = oracle::get_price(&state, symbol,&c);
            assert!(price == 100,1);
            assert!(timestamp == 100,2);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(c);
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
            let state = test_scenario::take_shared<oracle::State>(tx);
            let symbol = b"";
            oracle::create_price_feed(&mut admin_cap, &mut state,symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(state);
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
            let state = test_scenario::take_shared<oracle::State>(tx);
            oracle::create_price_feed(&mut admin_cap,&mut state, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::end(test_tx);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = oracle)]
    fun test_exception_price_timestamp(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let symbol: vector<u8>;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            symbol = b"Crypto.BTC/USD";
            let state = test_scenario::take_shared<oracle::State>(tx);
            oracle::create_price_feed(&mut admin_cap,&mut state, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
             test_scenario::return_shared(state);
        };
        test_scenario::next_tx(tx,owner);
        {
            let state = test_scenario::take_shared<oracle::State>(tx);
            oracle::update_price_for_testing(&mut state, symbol, 100, 200, test_scenario::ctx(tx));
            // abort code 3
            oracle::update_price_for_testing(&mut state, symbol, 100, 100, test_scenario::ctx(tx));
            test_scenario::return_shared(state);
        };
        test_scenario::end(test_tx);
    }
    #[test]
    #[expected_failure(abort_code = 3, location = oracle)]
    fun test_exception_price_timestamp_1(){
        let owner = @0x1;
        let owner2 = @0x2;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let symbol: vector<u8>;
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            oracle::init_for_testing(test_scenario::ctx(tx));
            let admin_cap = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            symbol = b"Crypto.BTC/USD";
            let state = test_scenario::take_shared<oracle::State>(tx);
            oracle::create_price_feed(&mut admin_cap, &mut state, symbol, test_scenario::ctx(tx));
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(tx,owner);
        {
            let state = test_scenario::take_shared<oracle::State>(tx);
            oracle::update_price_for_testing(&mut state, symbol, 100, 99, test_scenario::ctx(tx));
            debug::print(&state);
            test_scenario::return_shared(state);
        };
        test_scenario::next_tx(tx,owner2);
        {
            let state = test_scenario::take_shared<oracle::State>(tx);
            let c = clock::create_for_testing(test_scenario::ctx(tx));
            clock::set_for_testing(&mut c, 104*1000);
            // abort code 3
            let (price, timestamp) = oracle::get_price(&state, symbol,&c);
            assert!(price == 100,1);
            assert!(timestamp == 99,2);
            test_scenario::return_shared(state);
            clock::destroy_for_testing(c);
        };
        test_scenario::end(test_tx);
    }
}