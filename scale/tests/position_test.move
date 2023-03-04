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
    // use sui::transfer;
    // use sui::tx_context;
    use sui_coin::scale::{SCALE};
    // use sui::balance;

    struct TestContext {
        owner: address,
        scenario: Scenario,
        market_id: ID,
        position_id: ID,
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
        let feed_id = oracle::create_price_feed_for_testing(&mut oracle_admin,&mut root,b"BTC/USD",ctx);
        oracle::update_price(&mut root,feed_id,1000,11234567,ctx);
        let n = b"BTC/USD";
        let d = b"BTC/USD testing";
        market_id = market::create_market(&mut list,&scale_coin,n,d,1u64,100u64,feed_id,ctx);
        account::create_account(&scale_coin,ctx);

        test_scenario::next_tx(tx,owner);
        let account = test_scenario::take_shared<Account<SCALE>>(tx);
        // deposit
        account::deposit(&mut account,coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx)),10000,test_scenario::ctx(tx));
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
            // fund_size = lot/DENOMINATOR128 * leverage * size => 1000/10000 * 2 * 1
            assert!(position::get_offset<SCALE>(position) == 1,102);
            // margin = size * price * DENOMINATOR128 / leverage => 1 * 1000 * 10000 / 2
            assert!(position::get_margin<SCALE>(position) == 20,103);
            assert!(position::get_size_value<SCALE>(position) == 1,103);
        };
        drop_test_ctx(TestContext {
            owner,
            scenario,
            market_id,
            position_id,
            account,
            scale_coin,
            list,
            root,
        });
    }
    #[test]
    fun test_burst_position(){
    //    test_scenario::next_tx(tx,owner);
    //     {
    //         let list = test_scenario::take_shared<MarketList>(tx);
    //         let account = test_scenario::take_shared<Account<SCALE>>(tx);
    //         let root = test_scenario::take_shared<oracle::Root>(tx);
    //         let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
    //         debug::print(&account);
    //         market::set_opening_price_for_testing(market,1);
    //         // current price is 1000
    //         let price = market::get_price(market,&root);
    //         assert!(market::get_real_price(&price) == 1000_000000,300);
    //         position::burst_position<Tag,SCALE>(&mut list, &mut account, &root,position_id,test_scenario::ctx(tx));
    //         test_scenario::return_shared(account);
    //         test_scenario::return_shared(root);
    //         test_scenario::return_shared(list);
    //     };
    }
}