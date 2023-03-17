#[test_only]
module scale::position_tests {
    use scale::market::{Self, MarketList, Market};
    use scale::account::{Self,Account};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Tag};
    use sui::test_scenario::{Self,Scenario};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    use sui::coin::{Self,Coin};
    use std::debug;
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
        account::deposit(&mut account,coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx)),0,test_scenario::ctx(tx));
        // add liquidity
        assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
        let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
        let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut(market),coin::mint_for_testing<SCALE>(100000,test_scenario::ctx(tx)),test_scenario::ctx(tx));
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
        // test open full position
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),1);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 1000/10000 / 2 => 50
            assert!(position::get_margin<SCALE>(position) == 50,103);
            assert!(position::get_size_value<SCALE>(position) == 1,1003);
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
            // check account
            assert!(account::get_offset(&account) == 1,127);
            // deposit 1000 scale coin , balance = 10000
            // becouse  full position so balance = 10000
            assert!(account::get_balance(&account) == 10000,128);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,129);
            assert!(i64::is_negative(p) == false,130);
            assert!(account::get_margin_total(&account) == 50,131);
            assert!(account::get_margin_full_total(&account) == 50,132);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_independent_total(&account) == 0,134);
            assert!(account::get_margin_full_buy_total(&account) == 50,135);
            assert!(account::get_margin_full_sell_total(&account) == 0,136);
            assert!(account::get_margin_independent_buy_total(&account) == 0,137);
            assert!(account::get_margin_independent_sell_total(&account) == 0,138);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,139);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),140);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = buy_price * size * (lot / DENOMINATOR128) => 1007.5 * 1 * 1000/10000 => 100.75
            assert!(market::get_long_position_total(market) == 100,141);
            assert!(market::get_short_position_total(market) == 0,142);
            let pool = market::get_pool(market);
            assert!(pool::get_vault_balance(pool) == 100000,143);
            assert!(pool::get_profit_balance(pool) == 0,144);
            // insurance = position_fund_total * 5/10000 = 1007.5 * 1 * 1000/10000 * 5 / 10000 => 0.050375
            assert!(pool::get_insurance_balance(pool) == 0,145);
            assert!(pool::get_spread_profit(pool) == 0,146);
        };
        // test open independent position
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,1,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),2);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(position);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 5  => 2000
            assert!(position::get_margin<SCALE>(position) == 2000,203);
            assert!(position::get_size_value<SCALE>(position) == 1,2003);
            assert!(position::get_offset(position) == 2,204);
            assert!(position::get_leverage(position) == 5,205);
            assert!(position::get_margin_balance(position) == 2000,206);
            assert!(position::get_type(position) == 2,207);
            assert!(position::get_status(position) == 1,208);
            assert!(position::get_direction(position) == 1,209);
            assert!(position::get_lot(position) == 100000,210);
            assert!(position::get_open_price(position) == 1007,211);
            assert!(position::get_open_spread(position) == 15,212);
            assert!(position::get_open_real_price(position) == 1000,213);
            assert!(position::get_close_price(position) == 0,214);
            assert!(position::get_close_spread(position) == 0,215);
            assert!(position::get_close_real_price(position) == 0,216);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,217);
            assert!(i64::is_negative(profit) == false,217);
            assert!(position::get_stop_surplus_price(position) == 0,218);
            assert!(position::get_stop_loss_price(position) == 0,219);
            assert!(position::get_create_time(position) == 0,220);
            assert!(position::get_close_time(position) == 0,221);
            assert!(position::get_validity_time(position) == 0,222);
            assert!(*position::get_open_operator(position) == owner,223);
            assert!(*position::get_close_operator(position) == @0x0,224);
            assert!(*position::get_market_id(position) == market_id,225);
            assert!(*position::get_account_id(position) == object::id(&account),226);
            // check account
            assert!(account::get_offset(&account) == 2,227);
            // deposit 10000 scale coin , balance = 10000
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse independent position so balance = 10000 - 2000 - 1  => 7999
            assert!(account::get_balance(&account) == 7999,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,229);
            assert!(i64::is_negative(p) == false,230);
            // total = 50 + 2000 => 2050
            assert!(account::get_margin_total(&account) == 2050,231);
            assert!(account::get_margin_full_total(&account) == 50,232);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_independent_total(&account) == 2000,234);
            assert!(account::get_margin_full_buy_total(&account) == 50,235);
            assert!(account::get_margin_full_sell_total(&account) == 0,236);
            assert!(account::get_margin_independent_buy_total(&account) == 2000,237);
            assert!(account::get_margin_independent_sell_total(&account) == 0,238);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,239);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),240);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = 50 * 2 + 2000 * 5 => 10100
            assert!(market::get_long_position_total(market) == 10100,241);
            assert!(market::get_short_position_total(market) == 0,242);
            let pool = market::get_pool(market);
            debug::print(pool);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (100000/10000 * 1 * (15/2))
            // 100000 - spread_fee => 100000 - 70 => 99930
            assert!(pool::get_vault_balance(pool) == 99930,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 1,245);
            assert!(pool::get_spread_profit(pool) == 70,246);
        };
        // test open full position sell
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,2,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),301);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * (1000/10000) / 2 => 50
            assert!(position::get_margin<SCALE>(position) == 50,303);
            assert!(position::get_size_value<SCALE>(position) == 1,3003);
            assert!(position::get_offset(position) == 3,304);
            assert!(position::get_leverage(position) == 2,305);
            assert!(position::get_margin_balance(position) == 0,306);
            assert!(position::get_type(position) == 1,307);
            assert!(position::get_status(position) == 1,308);
            assert!(position::get_direction(position) == 2,309);
            assert!(position::get_lot(position) == 1000,110);
            assert!(position::get_open_price(position) == 992,311);
            assert!(position::get_open_spread(position) == 15,312);
            assert!(position::get_open_real_price(position) == 1000,313);
            assert!(position::get_close_price(position) == 0,314);
            assert!(position::get_close_spread(position) == 0,315);
            assert!(position::get_close_real_price(position) == 0,316);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,317);
            assert!(i64::is_negative(profit) == false,317);
            assert!(position::get_stop_surplus_price(position) == 0,318);
            assert!(position::get_stop_loss_price(position) == 0,319);
            assert!(position::get_create_time(position) == 0,320);
            assert!(position::get_close_time(position) == 0,321);
            assert!(position::get_validity_time(position) == 0,322);
            assert!(*position::get_open_operator(position) == owner,323);
            assert!(*position::get_close_operator(position) == @0x0,324);
            assert!(*position::get_market_id(position) == market_id,325);
            assert!(*position::get_account_id(position) == object::id(&account),326);
            // check account
            assert!(account::get_offset(&account) == 3,327);
            // deposit 1000 scale coin , balance = 7999
            // becouse  full position so balance = 7999
            assert!(account::get_balance(&account) == 7999,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 2100,331);
            assert!(account::get_margin_full_total(&account) == 100,332);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_independent_total(&account) == 2000,334);
            assert!(account::get_margin_full_buy_total(&account) == 50,335);
            assert!(account::get_margin_full_sell_total(&account) == 50,336);
            assert!(account::get_margin_independent_buy_total(&account) == 2000,337);
            assert!(account::get_margin_independent_sell_total(&account) == 0,338);
            let pfk = account::new_PFK(market_id,object::id(&account),2);
            assert!(account::contains_pfk(&account,&pfk) == true ,339);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),340);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 10100,341);
            assert!(market::get_short_position_total(market) == 100,342);
            let pool = market::get_pool(market);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (1000/10000 * 1 * 15/2) => 0.75
            // 99930 - spread_fee => 99930 - 0 => 99930
            assert!(pool::get_vault_balance(pool) == 99930,343);
            assert!(pool::get_profit_balance(pool) == 0,344);
            // insurance = position_fund_total * 5/10000 = real_price * size * (lot / DENOMINATOR128) * 5/10000 => 1000 * 1 * (1000/10000) * 5/10000 => 0.05
            assert!(pool::get_insurance_balance(pool) == 1,345);
            assert!(pool::get_spread_profit(pool) == 70,346);
        };
        // test open independent position sell
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,2,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),401);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(position);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * (100000/10000) / 5 => 2000
            assert!(position::get_margin<SCALE>(position) == 2000,402);
            assert!(position::get_size_value<SCALE>(position) == 1,403);
            assert!(position::get_offset(position) == 4,404);
            assert!(position::get_leverage(position) == 5,405);
            assert!(position::get_margin_balance(position) == 2000,406);
            assert!(position::get_type(position) == 2,407);
            assert!(position::get_status(position) == 1,408);
            assert!(position::get_direction(position) == 2,409);
            assert!(position::get_lot(position) == 100000,410);
            assert!(position::get_open_price(position) == 992,411);
            assert!(position::get_open_spread(position) == 15,412);
            assert!(position::get_open_real_price(position) == 1000,413);
            assert!(position::get_close_price(position) == 0,414);
            assert!(position::get_close_spread(position) == 0,415);
            assert!(position::get_close_real_price(position) == 0,416);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,417);
            assert!(i64::is_negative(profit) == false,417);
            assert!(position::get_stop_surplus_price(position) == 0,418);
            assert!(position::get_stop_loss_price(position) == 0,419);
            assert!(position::get_create_time(position) == 0,420);
            assert!(position::get_close_time(position) == 0,421);
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == @0x0,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 4,427);
            // deposit 10000 scale coin , balance = 7999
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse independent position so balance = 7999 - 2000 - 1  => 5998
            assert!(account::get_balance(&account) == 5998,428);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,429);
            assert!(i64::is_negative(p) == false,430);
            // total = 2100 + 2000 => 4100
            assert!(account::get_margin_total(&account) == 4100,431);
            assert!(account::get_margin_full_total(&account) == 100,432);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_independent_total(&account) == 4000,434);
            assert!(account::get_margin_full_buy_total(&account) == 50,435);
            assert!(account::get_margin_full_sell_total(&account) == 50,436);
            assert!(account::get_margin_independent_buy_total(&account) == 2000,437);
            assert!(account::get_margin_independent_sell_total(&account) == 2000,438);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,439);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),440);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = 50 * 2 + 2000 * 5 => 10100
            assert!(market::get_long_position_total(market) == 10100,441);
            // long_total = 50 * 2 + 2000 * 5 => 10100
            assert!(market::get_short_position_total(market) == 10100,442);
            let pool = market::get_pool(market);
            // debug::print(pool);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (100000/10000 * 1 * (15/2)) = 70
            // 100000 - spread_fee => 99930 - 70 => 99930
            assert!(pool::get_vault_balance(pool) == 99860,443);
            assert!(pool::get_profit_balance(pool) == 0,444);
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            assert!(pool::get_insurance_balance(pool) == 2,445);
            assert!(pool::get_spread_profit(pool) == 140,446);
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
    fun test_close_position(){
        let test_ctx = get_test_ctx();
        let TestContext {
            owner,
            scenario,
            market_id,
            position_id,
            feed_id,
            account,
            scale_coin,
            list,
            root,
        } = test_ctx;
        let tx = &mut scenario;
        test_scenario::next_tx(tx,owner);
        {
            // let position_id_1 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            // let _position_id_2 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,1,test_scenario::ctx(tx));
            // let _position_id_3 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,2,test_scenario::ctx(tx));
            // let position_id_4 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,2,test_scenario::ctx(tx));
            // assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),440);
            // let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // position::close_position<Tag,SCALE>(market, &mut account, &root,position_id_1,test_scenario::ctx(tx));
            // assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),501);
            // let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
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