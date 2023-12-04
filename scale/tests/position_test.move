#[test_only]
module scale::position_tests {
    use scale::market::{Self, List};
    use scale::account::{Self,Account};
    use scale::position;
    use scale::pool::{Self,Scale};
    use sui::test_scenario::{Self,Scenario};
    use sui::dynamic_object_field as dof;
    // use sui::object::{ID};
    use sui::coin::{Self,Coin};
    use oracle::oracle;
    use scale::i64;
    // use std::debug;
    use sui_coin::scale::{SCALE};
    use std::string::{Self,String};
    use sui::clock;

    public fun get_test_ctx<T>():
     (
        address,
        Scenario,
        String,
        Account<T>,
        Coin<T>,
        List<T>,
        oracle::State,
        clock::Clock
     ) {
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let scale_coin: Coin<T>;
        scale_coin =  coin::mint_for_testing<T>(1_000_000,test_scenario::ctx(tx));
        let n = b"BTC/USD";
        let symbol = string::utf8(n);
        test_scenario::next_tx(tx,owner);
        {
            // list init
            market::create_list<T>(test_scenario::ctx(tx));
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        let state = test_scenario::take_shared<oracle::State>(tx);
        let oracle_admin = test_scenario::take_from_sender<oracle::AdminCap>(tx);
        let list = test_scenario::take_shared<List<T>>(tx);
        let ctx = test_scenario::ctx(tx);
        oracle::create_price_feed_for_testing(&mut state,n,ctx);
        oracle::update_price_for_testing(&mut state,n,1000,123,ctx);
        let d = b"BTC/USD testing";
        let i = b"https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-2408-43e1-ad4c-78b47b448a6a.png";
        market::create_market<T>(
            &mut list,
            n,
            i,
            d,
            1u64,
            800u64,
            ctx
        );
        account::create_account<T>(ctx);

        test_scenario::next_tx(tx,owner);
        let account = test_scenario::take_shared<Account<T>>(tx);
        // deposit
        account::deposit(&mut account,coin::mint_for_testing<T>(10000,test_scenario::ctx(tx)),0,test_scenario::ctx(tx));
        let coin = coin::mint_for_testing<T>(20000,test_scenario::ctx(tx));
        account::isolated_deposit_for_testing(&mut account,coin);
        // add liquidity
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),symbol),1);
        let lsp_coin = pool::add_liquidity_for_testing<Scale,T>(market::get_pool_mut_for_testing<T>(&mut list),coin::mint_for_testing<T>(1000000,test_scenario::ctx(tx)),test_scenario::ctx(tx));
        coin::burn_for_testing(lsp_coin);
        let c = clock::create_for_testing(test_scenario::ctx(tx));
        clock::set_for_testing(&mut c,123000);
        test_scenario::return_to_sender(tx,oracle_admin);
        (
            owner,
            test_tx,
            symbol,
            account,
            scale_coin,
            list,
            state,
            c,
        )
    }

    public fun drop_test_ctx<T>(
        scenario: Scenario,
        account: Account<SCALE>,
        scale_coin: Coin<SCALE>,
        list: List<T>,
        state: oracle::State,
        c: clock::Clock,
    ) {
        test_scenario::return_shared(list);
        test_scenario::return_shared(account);
        test_scenario::return_shared(state);
        coin::burn_for_testing(scale_coin);
        test_scenario::end(scenario);
        clock::destroy_for_testing(c);
    }

    #[test]
    #[expected_failure(abort_code = 610, location = position)]
    fun test_risk_assertion(){
        let total_liquidity = 100u64;
        let fund_size = 10u64;
        let pre_exposure = 10u64;
        let exposure = 71u64;
        let position_total = 10u64;
        // 
        position::risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
    }
    #[test]
    #[expected_failure(abort_code = 612, location = position)]
    fun test_risk_assertion_1(){
        let total_liquidity = 100u64;
        let fund_size = 21u64;
        let pre_exposure = 10u64;
        let exposure = 11u64;
        let position_total = 10u64;
        position::risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
    }
    #[test]
    #[expected_failure(abort_code = 613, location = position)]
    fun test_risk_assertion_2(){
        let total_liquidity = 100u64;
        let fund_size = 10u64;
        let pre_exposure = 100u64;
        let exposure = 90u64;
        let position_total = 15001u64;
        position::risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
    }
    #[test]
    fun test_risk_assertion_3(){
        let total_liquidity = 100u64;
        let fund_size = 10u64;
        let pre_exposure = 100u64;
        let exposure = 90u64;
        let position_total = 15u64;
        position::risk_assertion(
            total_liquidity,
            fund_size,
            pre_exposure,
            exposure,
            position_total
        );
    }
    #[test]
    fun test_equity(){
        let(
            owner,
            scenario,
            symbol,
            account,
            scale_coin,
            list,
            state,
            c,
        ) = get_test_ctx<SCALE>();
        let tx = &mut scenario;
        let sb=*string::bytes(&symbol);
        test_scenario::next_tx(tx,owner);
        {
           let _position_id = position::open_position(
                sb,
                100,
                1,
                1,
                1,
                0,
                0,
                0,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx)
            );
            let total_liquidity = pool::get_total_liquidity(market::get_pool(&list));
            // let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            // let price = market::get_price(market,&state,&c);
            // balabce = balance - insurance_fee - fund_fee => 10000 - 1 - 0 = 9999
            // buy position ,pl = (sell_price - open_real_price ) * size
            // =>  992 * 100 / 10000 - 1000 * 100 / 10000
            // =>  9.92 - 10
            // =>  9 - 10 
            // =>  -1
            let equity = position::get_equity(
                    total_liquidity,
                    &list,
                    &account,
                    &state,
                    &c,
                );
            assert!(i64::get_value(&equity) == 9998,1);
            assert!(account::get_balance(&account) == 9999,2);
        };
        test_scenario::next_tx(tx,owner);
        {
            let ctx = test_scenario::ctx(tx);
            clock::set_for_testing(&mut c,134000);
            oracle::update_price_for_testing(&mut state,sb,1500,133,ctx);
            let _position_id = position::open_position(
                sb,
                100000,
                1,
                1,
                2,
                0,
                0,
                0,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx)
            );
            let total_liquidity = pool::get_total_liquidity(market::get_pool(&list));
            // let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            // let price = market::get_price(market,&state,&c);
            // pl_1= (sell_price - open_real_price ) * size
            // =>  1488 * 100 / 10000 - 1000 * 100 / 10000
            // =>  14.88 - 10
            // =>  14 - 10
            // =>  4
            // becose this position is isolated so the balance is not changed
            // buy position ,pl = (open_real_price - buy_price ) * size
            // =>  1500 * 100000 / 10000 - 1511 * 100000 / 10000
            // =>  150 - 151.1
            // =>  -1.1
            let equity = position::get_equity(
                    total_liquidity,
                    &list,
                    &account,
                    &state,
                    &c,
                );
            // 10000 -1 + 4  = 10003
            assert!(i64::get_value(&equity) == 10003,1);
        };
        drop_test_ctx(
            scenario,
            account,
            scale_coin,
            list,
            state,
            c,
        );
    }
    #[test]
    fun test_not_force_liquidation(){
        // When the margin ratio is less 50% , forced liquidation
        let equity = i64::new(6,false);
        assert!(position::is_force_liquidation(&equity,10) == false,1);
        let equity = i64::new(10,false);
        assert!(position::is_force_liquidation(&equity,10) == false,1);
        let equity = i64::new(11,false);
        assert!(position::is_force_liquidation(&equity,10) == false,1);
    }
    #[test]
    fun test_force_liquidation(){
        let equity = i64::new(5,false);
        assert!(position::is_force_liquidation(&equity,10) == true,1);
        let equity = i64::new(1,false);
        assert!(position::is_force_liquidation(&equity,10) == true,1);
        let equity = i64::new(3333,false);
        assert!(position::is_force_liquidation(&equity,9999) == true,1);
    }

    #[test]
    fun test_value_overflow(){
        let(
            owner,
            scenario,
            symbol,
            account,
            scale_coin,
            list,
            state,
            c,
        ) = get_test_ctx<SCALE>();
        let tx = &mut scenario;
        let sb=*string::bytes(&symbol);
        test_scenario::next_tx(tx,owner);
        {
            let ctx = test_scenario::ctx(tx);
            clock::set_for_testing(&mut c,134000);
            oracle::update_price_for_testing(&mut state,sb,9_223_372_036_854_775_807/20000,133,ctx);
            account::deposit(
                &mut account,
                coin::mint_for_testing<SCALE>(
                (9_223_372_036_854_775_807 - 10000),
                test_scenario::ctx(tx)),
                0,
                test_scenario::ctx(tx)
            );
            // add liquidity
            let lsp_coin = pool::add_liquidity_for_testing<Scale,SCALE>(
                market::get_pool_mut_for_testing<SCALE>(&mut list),
                coin::mint_for_testing<SCALE>(18446744073709551615 - 1000000 -1,
                test_scenario::ctx(tx)),test_scenario::ctx(tx)
            );
            // 18446744073709551615
            // 9223372036854775807
            coin::burn_for_testing(lsp_coin);
            let _position_id = position::open_position(
                sb,
                10000,
                1,
                1,
                1,
                0,
                0,
                0,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx)
            );
        };
        drop_test_ctx(
            scenario,
            account,
            scale_coin,
            list,
            state,
            c,
        );
    }
}