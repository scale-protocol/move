#[test_only]
module scale::position_tests {
    use scale::market::{Self, MarketList, Market};
    use scale::account::{Self,Account};
    use scale::position::{Self,Position};
    use scale::pool::Tag;
    use sui::test_scenario::{Self,Scenario};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    use sui::coin::{Self,Coin};
    use std::debug;
    use scale::pool;
    use oracle::oracle;
    use sui::test_utils;
    use scale::i64;
    // use sui::transfer;
    // use sui::tx_context;
    use sui_coin::scale::{SCALE};
    // use sui::balance;

    struct TestContext {
        owner: address,
        scenario: Scenario,
        market_id: ID,
        position_id: ID,
        feed_id: ID,
        account: Account<SCALE>,
        scale_coin: Coin<SCALE>,
        list: MarketList,
        root: oracle::Root,
    }
    #[test]
    fun get_test_ctx(): TestContext {
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let market_id: ID;
        let feed_id: ID;
        let scale_coin: Coin<SCALE>;
        test_scenario::next_tx(tx,owner);
        {
            // market init
            market::init_for_testing(test_scenario::ctx(tx));
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        let root = test_scenario::take_shared<oracle::Root>(tx);
        let oracle_admin = test_scenario::take_from_sender<oracle::AdminCap>(tx);
        let list = test_scenario::take_shared<MarketList>(tx);
        let ctx = test_scenario::ctx(tx);
        scale_coin =  coin::mint_for_testing<SCALE>(100_0000,ctx);
        feed_id = oracle::create_price_feed_for_testing(&mut oracle_admin,&mut root,b"BTC/USD",ctx);
        oracle::update_price(&mut root,feed_id,1000,11234567,ctx);
        let n = b"BTC/USD";
        let d = b"BTC/USD testing";
        market_id = market::create_market(&mut list,&scale_coin,n,d,1u64,800u64,feed_id,ctx);
        account::create_account(&scale_coin,ctx);

        test_scenario::next_tx(tx,owner);
        let account = test_scenario::take_shared<Account<SCALE>>(tx);
        // deposit
        account::deposit(&mut account,coin::mint_for_testing<SCALE>(1000,test_scenario::ctx(tx)),1000,test_scenario::ctx(tx));
        // add liquidity
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
        let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
        let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut(market),coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx)),test_scenario::ctx(tx));
        coin::destroy_for_testing(lsp_coin);
        test_scenario::return_to_sender(tx,oracle_admin);

        TestContext {
            owner: owner,
            scenario: test_tx,
            market_id,
            position_id: object::id_from_address(@0x1),
            feed_id,
            account,
            scale_coin,
            list,
            root,
        }
    }

    fun drop_test_ctx(ctx: TestContext) {
        let TestContext {
            owner: _,
            scenario,
            market_id: _,
            position_id: _,
            feed_id:_,
            account,
            scale_coin,
            list,
            root,
        } = ctx;
        test_scenario::return_shared(list);
        test_scenario::return_shared(account);
        test_scenario::return_shared(root);
        coin::destroy_for_testing(scale_coin);
        test_scenario::end(scenario);
    }
    #[test]
    fun test_open_position(){
        let test_ctx = get_test_ctx();
        let TestContext {
            owner,
            scenario,
            market_id,
            position_id:_,
            feed_id,
            account,
            scale_coin,
            list,
            root,
        } = test_ctx;
        let tx = &mut scenario;
        let position_id :ID;
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),1);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            assert!(position::get_offset<SCALE>(position) == 1,101);
            debug::print(position);
            assert!(position::get_offset<SCALE>(position) == 1,102);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = buy_price * size * (lot / DENOMINATOR128) / leverage => 1007.5 * 1 * 1000/10000 / 2 => 50.375
            assert!(position::get_margin<SCALE>(position) == 50,103);
            assert!(position::get_size_value<SCALE>(position) == 1,103);
            assert!(position::get_offset(position) == 1,104);
            assert!(position::get_leverage(position) == 2,105);
            assert!(position::get_margin_balance(position) == 0,106);
            assert!(position::get_type(position) == 1,107);
            assert!(position::get_status(position) == 1,108);
            assert!(position::get_direction(position) == 1,109);
            assert!(position::get_lot(position) == 1000,110);
            assert!(position::get_open_price(position) == 1007,111);
            assert!(position::get_open_spread(position) == 15,112);
            assert!(position::get_open_real_price(position) == 1000,113);
            assert!(position::get_close_price(position) == 0,114);
            assert!(position::get_close_spread(position) == 0,115);
            assert!(position::get_close_real_price(position) == 0,116);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,117);
            assert!(i64::is_negative(profit) == false,117);
            assert!(position::get_stop_surplus_price(position) == 0,118);
            assert!(position::get_stop_loss_price(position) == 0,119);
            assert!(position::get_create_time(position) == 0,120);
            assert!(position::get_close_time(position) == 0,121);
            assert!(position::get_validity_time(position) == 0,122);
            assert!(*position::get_open_operator(position) == owner,123);
            assert!(*position::get_close_operator(position) == @0x0,124);
            assert!(*position::get_market_id(position) == market_id,125);
            assert!(*position::get_account_id(position) == object::id(&account),126);
        };
        drop_test_ctx(TestContext {
            owner,
            scenario,
            market_id,
            position_id,
            feed_id,
            account,
            scale_coin,
            list,
            root,
        });
    }
    #[test]
    fun test_burst_position(){
        let test_ctx = get_test_ctx();
        let TestContext {
            owner,
            scenario,
            market_id,
            position_id:_,
            feed_id,
            account,
            scale_coin,
            list,
            root,
        } = test_ctx;
        let tx = &mut scenario;
        let position_id :ID;
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),1);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            assert!(dof::exists_(oracle::get_uid(&root),feed_id),2);
            oracle::update_price(&mut root,feed_id,780,112345678,test_scenario::ctx(tx));

            // // change = |opening_price-price|/opening_price => |800-780|/800 => 0.025
            // spread_fee => because change < 3% so spread_fee is 3/1000
            // spread = 780 * 3/1000 => 2.34
            // buy_price: real_price+(spread/2)=> 780 + 2.34/2 => 781.17
            // sell_price: real_price - (spread/2)=> 780 - 2.34/2 => 778.83


            // exposure = |buy_total-sell_total| = buy_price * size * (lot / DENOMINATOR128) = 1007.5 * 1 * 1000/10000 => 100.75
            // fund_fee : because (exposure / liquidity_total => 100.75 / 10000 => 0.01) so fund_fee = 0.0003
            // fund = 100.75 * 0.0003 = 0.030225
            // pl = (sell_price - open_price) * (lot / DENOMINATOR128) * size =>(778.83 - 1007.5) * 1000/10000 * 1 => -22.867
            account::set_balance_for_testing(&mut account, 80, test_scenario::ctx(tx));
            assert!(account::get_balance(&account) == 80,3);
            // balance = 80 - 50.375 => 29.625
            // equity = balance + pl + fund => 29.625 - 22.867 + 0.030225 => 7.087225
            // margin_used = 50.375
            // equity / margin_used < 50% then close position => 7.087225 / 50.375 < 0.5 => true
            test_utils::print(b"print account info");
            debug::print(&account);
            position::burst_position<Tag,SCALE>(&mut list, &mut account, &root,position_id,test_scenario::ctx(tx));
            debug::print(&account);
        };
        drop_test_ctx(TestContext {
            owner,
            scenario,
            market_id,
            position_id,
            feed_id,
            account,
            scale_coin,
            list,
            root,
        });
    }
}