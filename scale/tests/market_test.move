#[test_only]
#[lint_allow(self_transfer)]
module scale::market_tests {
    use scale::market::{Self, List, Market};
    // use scale::pool::Scale;
    use sui::test_scenario::{Self,Scenario};
    use sui::dynamic_object_field as dof;
    use sui::coin::{Self,Coin};
    use std::debug;
    use scale::pool::{Self,Scale};
    // use oracle::oracle;
    // use sui::test_utils;
    // use scale::i64;
    use sui_coin::scale::{SCALE};
    use std::string::{Self,String};


    #[lint_allow(coin_field)]
    struct TestContext<phantom P, phantom T> {
        owner: address,
        scenario: Scenario,
        symbol: String,
        scale_coin: Coin<SCALE>,
        list: List<Scale,SCALE>,
    }
    #[test]
    fun get_test_ctx(): TestContext<Scale,SCALE> {
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let scale_coin: Coin<SCALE>;
        scale_coin =  coin::mint_for_testing<SCALE>(100_0000,test_scenario::ctx(tx));
        test_scenario::next_tx(tx,owner);
        {
            market::create_list<Scale,SCALE>(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        let list = test_scenario::take_shared<List<Scale,SCALE>>(tx);
        let ctx = test_scenario::ctx(tx);
        let n = b"ETH/USD";
        let d = b"ETH/USD testing";
        let i = b"https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-2408-43e1-ad4c-78b47b448a6a.png";
        market::create_market<Scale,SCALE>(
                &mut list,
                n,
                i,
                d,
                1u64,
                800u64,
                ctx
            );
        test_scenario::next_tx(tx,owner);
        let symbol = string::utf8(n);
        // add liquidity
        assert!(dof::exists_(market::get_list_uid_mut<Scale,SCALE>(&mut list),symbol),1);
        // let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),n);
        assert!(pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list)) == 0u64,4);
        let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut_for_testing(&mut list),coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx)),test_scenario::ctx(tx));
        coin::burn_for_testing(lsp_coin);
        TestContext {
            owner: owner,
            scenario: test_tx,
            symbol,
            scale_coin,
            list,
        }
    }

    fun drop_test_ctx<Scale,SCALE>(ctx: TestContext<Scale,SCALE>) {
        let TestContext {
            owner: _,
            scenario,
            symbol: _,
            scale_coin,
            list,
        } = ctx;
        test_scenario::return_shared(list);
        coin::burn_for_testing(scale_coin);
        test_scenario::end(scenario);
    }
    #[test]
    fun test_create_market(){
        let TestContext<Scale,SCALE> {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        } = get_test_ctx();
        debug::print(&symbol);
        let n = b"BTC/USD";
        let d = b"BTC/USD testing";
        let i = b"https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-2408-43e1-ad4c-78b47b448a6a.png";
        market::create_market<Scale,SCALE>(
                &mut list,
                n,
                i,
                d,
                1u64,
                800u64,
                test_scenario::ctx(&mut scenario)
            );
        let symbol = string::utf8(n);
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),symbol),1);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
        assert!(*string::bytes(market::get_symbol(market)) == b"BTC/USD",2);
        assert!(*string::bytes(market::get_description(market)) == b"BTC/USD testing",3);
        assert!(market::get_max_leverage(market) == 125u8,4);
        assert!(market::get_insurance_fee(market) == 5u64,5);
        assert!(market::get_margin_fee(market) == 10000u64,6);
        assert!(market::get_status(market) == 1,7);
        assert!(market::get_opening_price_value(market) == 800u64,8);
        assert!(market::get_officer<Scale,SCALE>(&list) == 2,9);
        drop_test_ctx<Scale,SCALE>(TestContext {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        });
    }
    #[test]
    #[expected_failure(abort_code = 307, location = market)]
    fun test_create_market_symbol_empty(){
        let TestContext<Scale,SCALE> {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        } = get_test_ctx();
        let n = b"";
        let d = b"BTC/USD testing";
        let i = b"https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-2408-43e1-ad4c-78b47b448a6a.png";
        let _new_symbol = market::create_market<Scale,SCALE>(
                &mut list,
                n,
                i,
                d,
                1u64,
                800u64,
                test_scenario::ctx(&mut scenario)
            );
        drop_test_ctx<Scale,SCALE>(TestContext {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        });
    }
    #[test]
    #[expected_failure(abort_code = 315, location = market)]
    fun test_create_market_symbol_len(){
        let TestContext<Scale,SCALE> {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        } = get_test_ctx();
        let n = b"abcdefghijkabcdefghij";
        let d = b"BTC/USD testing";
        let i = b"https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-2408-43e1-ad4c-78b47b448a6a.png";
        let _new_symbol = market::create_market<Scale,SCALE>(
                &mut list,
                n,
                i,
                d,
                1u64,
                800u64,
                test_scenario::ctx(&mut scenario)
            );
        drop_test_ctx<Scale,SCALE>(TestContext {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        });
    }
    #[test]
    fun test_fund_fee(){
        let TestContext<Scale,SCALE> {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        } = get_test_ctx();
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),symbol),1);
        let market: Market = dof::remove(market::get_list_uid_mut(&mut list),symbol);
        assert!(market::get_exposure(&market) == 0u64,2);
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 0u64,3);
        // let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut_for_testing(market),coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(&mut scenario)),test_scenario::ctx(&mut scenario));
        assert!(market::get_exposure(&market) == 0u64,4);
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 0u64,5);
        assert!(pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list)) == 10000u64,4);
        market::set_long_position_total_for_testing(&mut market,100u64);
        assert!(market::get_exposure(&market) == 100u64,6);
        market::set_short_position_total_for_testing(&mut market,900u64);
        assert!(market::get_exposure(&market) == 800u64,7);
        // rate = 800/10000 = 0.08 so fund_fee = 3/10000 = 0.0003
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 3u64,8);
        market::set_long_position_total_for_testing(&mut market,6500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 1500u64,9);
        // rate = 1500/10000 = 0.15 so fund_fee = 5/10000 = 0.0005
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 5u64,10);
        market::set_long_position_total_for_testing(&mut market,5500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 2500u64,11);
        // rate = 2500/10000 = 0.25 so fund_fee = 7/10000 = 0.0007
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 7u64,12);
        market::set_long_position_total_for_testing(&mut market,4500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 3500u64,13);
        // rate = 3500/10000 = 0.35 so fund_fee = 1/1000 = 0.001
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 10u64,14);
        market::set_long_position_total_for_testing(&mut market,3500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 4500u64,15);
        // rate = 4500/10000 = 0.45 so fund_fee = 2/1000 = 0.002
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 20u64,16);
        market::set_long_position_total_for_testing(&mut market,2500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 5500u64,17);
        // rate = 5500/10000 = 0.55 so fund_fee = 4/1000 = 0.004
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 40u64,18);
        market::set_long_position_total_for_testing(&mut market,1500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 6500u64,19);
        // rate = 6500/10000 = 0.65 so fund_fee = 7/1000 = 0.007
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 70u64,20);
        market::set_long_position_total_for_testing(&mut market,500u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 7500u64,21);
        // rate = 7500/10000 = 0.75 so fund_fee = 7/1000 = 0.007
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 70u64,22);
        market::set_long_position_total_for_testing(&mut market,0u64);
        market::set_short_position_total_for_testing(&mut market,8000u64);
        assert!(market::get_exposure(&market) == 8000u64,23);
        // rate = 8000/10000 = 0.8 so fund_fee = 7/1000 = 0.007
        assert!(market::get_fund_fee(&market,pool::get_total_liquidity<Scale,SCALE>(market::get_pool(&list))) == 70u64,24);
        // coin::destroy_for_testing(lsp_coin);
        dof::add(market::get_list_uid_mut(&mut list),symbol,market);
        drop_test_ctx<Scale,SCALE>(TestContext {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        });
    }
    #[test]
    fun test_spread_fee(){
        let TestContext<Scale,SCALE> {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        } = get_test_ctx();
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),symbol),1);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
        // opening_price = 800
        // change = |real_price - opening_price| / openging_price = |790 - 800| / 800 = 0.0125 = 1.25% so fee = 3/1000 = 0.003
        let fee =  market::get_spread_fee(market,790u64);
        // debug::print(&fee);
        assert!(fee == 30u64,2);
        // change = |real_price - opening_price| / openging_price = |750 - 800| / 800 = 0.0625 = 6.25% so fee  = 6.25/1000 = 0.00625
        let fee = market::get_spread_fee(market,750u64);
        assert!(fee == 62u64,3);
        // change = |real_price - opening_price| / openging_price = |740 - 800| / 800 = 0.075 = 7.5% so fee  = 7.5/1000 = 0.0075
        assert!(market::get_spread_fee(market,740u64) == 75u64,4);
        // change = |real_price - opening_price| / openging_price = |730 - 800| / 800 = 0.0875 = 8.75% so fee = 8.75/1000 = 0.00875
        assert!(market::get_spread_fee(market,730u64) == 87u64,5);
        // change = |real_price - opening_price| / openging_price = |720 - 800| / 800 = 0.1 = 10% so fee  = 10/1000 = 0.01
        assert!(market::get_spread_fee(market,720u64) == 100u64,6);
        // change = |real_price - opening_price| / openging_price = |710 - 800| / 800 = 0.1125 = 11.25% so fee = 1.5% = 1.5/100 = 0.015
        assert!(market::get_spread_fee(market,710u64) == 150u64,7);
        // change = |real_price - opening_price| / openging_price = |700 - 800| / 800 = 0.125 = 12.5% so fee = 1.5% = 1.5/100 = 0.015
        assert!(market::get_spread_fee(market,700u64) == 150u64,8);
        // change = |real_price - opening_price| / openging_price = |690 - 800| / 800 = 0.1375 = 13.75% so fee = 1.5% = 1.5/100 = 0.015
        assert!(market::get_spread_fee(market,690u64) == 150u64,9);
        // change = |real_price - opening_price| / openging_price = |600 - 800| / 800 = 0.25 = 25% so fee = 1.5% = 1.5/100 = 0.015
        assert!(market::get_spread_fee(market,600u64) == 150u64,10);
        drop_test_ctx<Scale,SCALE>(TestContext {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        });
    }
    #[test]
    fun test_get_price(){
        let TestContext<Scale,SCALE> {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        } = get_test_ctx();
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),symbol),1);
        let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
        // opening_price = 800
        // price = 1000
        // change = |real_price - opening_price| / openging_price = |1000 - 800| / 800 = 0.25 = 25% so fee = 1.5/100 = 0.015
        // spread = real_price * fee = 1000 * 0.015 = 15
        // buy_price = real_price + spread/2 = 1000 + 15/2 = 1007.5
        // sell_price = real_price - spread/2 = 1000 - 15/2 = 992.5
        let price = market::get_price_by_real(market,1000u64);
        assert!(market::get_real_price(&price) == 1000u64,2);
        assert!(market::get_buy_price(&price) == 1007u64,3);
        assert!(market::get_sell_price(&price) == 992u64,4);
        assert!(market::get_spread(&price) == 150000u64,5);
        // price = 790
        // change = |real_price - opening_price| / openging_price = |790 - 800| / 800 = 0.0125 = 1.25% so fee = 3/1000 = 0.003
        // spread = real_price * fee = 790 * 0.003 = 2.37
        // buy_price = real_price + spread/2 = 790 + 2.37/2 = 790.5
        // sell_price = real_price - spread/2 = 790 - 2.37/2 = 788.5
        let price = market::get_price_by_real(market,790u64);
        assert!(market::get_real_price(&price) == 790u64,6);
        assert!(market::get_buy_price(&price) == 791u64,7);
        assert!(market::get_sell_price(&price) == 788u64,8);
        assert!(market::get_spread(&price) == 23700u64,9);
        // price = 750
        // change = |real_price - opening_price| / openging_price = |750 - 800| / 800 = 0.0625 = 6.25% so fee  = 6.25/1000 = 0.00625
        // spread = real_price * fee = 750 * 0.0062 = 4.65
        // buy_price = real_price + spread/2 = 750 + 4.65/2 = 752.325
        // sell_price = real_price - spread/2 = 750 - 4.65/2 = 747.675
        let price = market::get_price_by_real(market,750u64);
        // debug::print(&price);
        assert!(market::get_real_price(&price) == 750u64,10);
        assert!(market::get_buy_price(&price) == 752u64,11);
        assert!(market::get_sell_price(&price) == 747u64,12);
        assert!(market::get_spread(&price) == 46500u64,13);
        drop_test_ctx<Scale,SCALE>(TestContext {
            owner,
            scenario,
            symbol,
            scale_coin,
            list,
        });
    }
}