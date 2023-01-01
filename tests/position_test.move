#[test_only]
module scale::position_tests {
    use scale::market::{Self,Market,MarketList};
    use scale::account::{Self,Account};
    use scale::position::{Self,Position};
    use scale::pool::Tag;
    use sui::test_scenario;
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    use std::debug;
    use scale::pool;
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
        };
        test_scenario::next_tx(tx,owner);
        {
            let list = test_scenario::take_shared<MarketList>(tx);
            let ctx = test_scenario::ctx(tx);
            let token =  coin::mint_for_testing<SCALE>(1,ctx);
            let id = object::last_created(ctx);
            let n = b"BTC/USD";
            let d = b"BTC/USD";
            market::create_market(&mut list,&token,n,d,1u64,id,ctx);
            market_id = object::last_created(ctx);
            account::create_account(&token,ctx);
            coin::destroy_for_testing(token);
            test_scenario::return_shared(list);
        };
        test_scenario::next_tx(tx,owner);
        {
            let list = test_scenario::take_shared<MarketList>(tx);
            let market:&mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // set opening price
            market::set_opening_price_for_testing(market,100);
            let account = test_scenario::take_shared<Account<SCALE>>(tx);
            let liquidity = coin::mint_for_testing<SCALE>(1000_000_000,test_scenario::ctx(tx));
            let token = coin::mint_for_testing<SCALE>(1000_000_000,test_scenario::ctx(tx));
            account::deposit(&mut account,token,10000,test_scenario::ctx(tx));
            // add liquidity
            let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut(market),liquidity,test_scenario::ctx(tx));
            position::open_position<Tag,SCALE>(&mut list,market_id,&mut account,1,1,1,1,test_scenario::ctx(tx));
            let position: &mut Position<SCALE> = dof::borrow_mut(account::get_uid_mut<SCALE>(&mut account),object::last_created(test_scenario::ctx(tx)));
            debug::print(position);
            // todo: check position
            // coin::destroy_for_testing(token);
            coin::destroy_for_testing(lsp_coin);
            test_scenario::return_shared(list);
            test_scenario::return_shared(account);
        };
        test_scenario::end(test_tx);
    }
}