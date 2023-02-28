#[test_only]
module scale::position_tests {
    use scale::market::{Self,MarketList,Market};
    use scale::account::{Self,Account};
    use scale::position::{Self};
    use scale::pool::Tag;
    use sui::test_scenario;
    use sui::dynamic_object_field as dof;
    use sui::object::ID;
    use std::debug;
    use scale::pool;
    use oracle::oracle;
    // use sui::transfer;
    // use sui::tx_context;
    use sui::coin;
    use sui_coin::scale::{SCALE};
    // use sui::balance;

    #[test]
    fun test_open_position(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let market_id: ID;
        test_scenario::next_tx(tx,owner);
        {
            // market init
            market::init_for_testing(test_scenario::ctx(tx));
            oracle::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let root = test_scenario::take_shared<oracle::Root>(tx);
            let oracle_admin = test_scenario::take_from_sender<oracle::AdminCap>(tx);
            let list = test_scenario::take_shared<MarketList>(tx);
            let ctx = test_scenario::ctx(tx);
            let token =  coin::mint_for_testing<SCALE>(1,ctx);
            let feed_id = oracle::create_price_feed_for_testing(&mut oracle_admin,&mut root,b"BTC/USD",ctx);
            oracle::update_price(&mut root,feed_id,1000,11234567,ctx);
            let n = b"BTC/USD";
            let d = b"BTC/USD";
            market_id = market::create_market(&mut list,&token,n,d,1u64,100u64,feed_id,ctx);
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),100);
            account::create_account(&token,ctx);
            coin::destroy_for_testing(token);
            test_scenario::return_shared(list);
            test_scenario::return_to_sender(tx,oracle_admin);
            test_scenario::return_shared(root);
        };
        test_scenario::next_tx(tx,owner);
        {
            let list = test_scenario::take_shared<MarketList>(tx);
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),200);
            // let id = dof::id(market::get_list_uid_mut(&mut list),market_id);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // set opening price
            market::set_opening_price_for_testing(market,100);
            let account = test_scenario::take_shared<Account<SCALE>>(tx);
            let liquidity = coin::mint_for_testing<SCALE>(1000_000_000_000_000,test_scenario::ctx(tx));
            let token = coin::mint_for_testing<SCALE>(1000_000_000,test_scenario::ctx(tx));
            account::deposit(&mut account,token,1000_000_000,test_scenario::ctx(tx));
            // add liquidity
            let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut(market),liquidity,test_scenario::ctx(tx));
            coin::destroy_for_testing(lsp_coin);
            test_scenario::return_shared(account);
            test_scenario::return_shared(list);
        };
        test_scenario::next_tx(tx,owner);
        {
            let list = test_scenario::take_shared<MarketList>(tx);
            let account = test_scenario::take_shared<Account<SCALE>>(tx);
            let root = test_scenario::take_shared<oracle::Root>(tx);
            let _position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1,2,1,2,test_scenario::ctx(tx));
            debug::print_stack_trace();
            // let position: &mut Position<SCALE> = dof::borrow_mut(account::get_uid_mut<SCALE>(&mut account),position_id);
            test_scenario::return_shared(account);
            test_scenario::return_shared(root);
            test_scenario::return_shared(list);
        };
        test_scenario::end(test_tx);
    }
}