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
        // test open cross position
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
            assert!(position::get_open_spread(position) == 150000,112);
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
            // becouse  cross position so balance = 10000
            assert!(account::get_balance(&account) == 10000,128);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,129);
            assert!(i64::is_negative(p) == false,130);
            assert!(account::get_margin_total(&account) == 50,131);
            assert!(account::get_margin_cross_total(&account) == 50,132);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 0,134);
            assert!(account::get_margin_cross_buy_total(&account) == 50,135);
            assert!(account::get_margin_cross_sell_total(&account) == 0,136);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,137);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,138);
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
        // test open isolated position
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
            assert!(position::get_open_spread(position) == 150000,212);
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
            // becouse isolated position so balance = 10000 - 2000 - 1  => 7999
            assert!(account::get_balance(&account) == 7999,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,229);
            assert!(i64::is_negative(p) == false,230);
            // total = 50 + 2000 => 2050
            assert!(account::get_margin_total(&account) == 2050,231);
            assert!(account::get_margin_cross_total(&account) == 50,232);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 2000,234);
            assert!(account::get_margin_cross_buy_total(&account) == 50,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,238);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,239);
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
        // test open cross position sell
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
            assert!(position::get_open_spread(position) == 150000,312);
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
            // becouse  cross position so balance = 7999
            assert!(account::get_balance(&account) == 7999,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 2100,331);
            assert!(account::get_margin_cross_total(&account) == 100,332);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 2000,334);
            assert!(account::get_margin_cross_buy_total(&account) == 50,335);
            assert!(account::get_margin_cross_sell_total(&account) == 50,336);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,337);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,338);
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
        // test open isolated position sell
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
            assert!(position::get_open_spread(position) == 150000,412);
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
            // becouse isolated position so balance = 7999 - 2000 - 1  => 5998
            assert!(account::get_balance(&account) == 5998,428);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,429);
            assert!(i64::is_negative(p) == false,430);
            // total = 2100 + 2000 => 4100
            assert!(account::get_margin_total(&account) == 4100,431);
            assert!(account::get_margin_cross_total(&account) == 100,432);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 4000,434);
            assert!(account::get_margin_cross_buy_total(&account) == 50,435);
            assert!(account::get_margin_cross_sell_total(&account) == 50,436);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,437);
            assert!(account::get_margin_isolated_sell_total(&account) == 2000,438);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,439);
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
    fun test_open_position_cross_more(){
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
        let position_id : ID;
        test_scenario::next_tx(tx,owner);
        {
            // deposit
            // accoune balance = 310000
            account::deposit(&mut account,coin::mint_for_testing<SCALE>(300000,test_scenario::ctx(tx)),0,test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,1,1,test_scenario::ctx(tx));
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
            assert!(position::get_offset(position) == 1,204);
            assert!(position::get_leverage(position) == 5,205);
            assert!(position::get_margin_balance(position) == 0,206);
            assert!(position::get_type(position) == 1,207);
            assert!(position::get_status(position) == 1,208);
            assert!(position::get_direction(position) == 1,209);
            assert!(position::get_lot(position) == 100000,210);
            assert!(position::get_open_price(position) == 1007,211);
            assert!(position::get_open_spread(position) == 150000,212);
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
            assert!(account::get_offset(&account) == 1,227);
            // balance = 310000
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse cross position so balance = 310000 - 1  => 309999
            // debug::print(&account);
            assert!(account::get_balance(&account) == 309999,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,229);
            assert!(i64::is_negative(p) == false,230);
            assert!(account::get_margin_total(&account) == 2000,231);
            assert!(account::get_margin_cross_total(&account) == 2000,232);
            assert!(account::get_margin_used(&account) == 2000,133);
            assert!(account::get_margin_isolated_total(&account) == 0,234);
            assert!(account::get_margin_cross_buy_total(&account) == 2000,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,238);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,239);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),240);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = 2000 * 5 => 10000
            assert!(market::get_long_position_total(market) == 10000,241);
            assert!(market::get_short_position_total(market) == 0,242);
            let pool = market::get_pool(market);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (100000/10000 * 1 * (15/2))
            // 100000 - spread_fee => 100000 - 70 => 99930
            assert!(pool::get_vault_balance(pool) == 99930,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 1,245);
            assert!(pool::get_spread_profit(pool) == 70,246);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position_id_new = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,10000,4,1,1,test_scenario::ctx(tx));
            assert!(position_id_new == position_id,300);
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),301);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(position);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 10000/10000 / 4  => 200
            debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 2200,303);
            assert!(position::get_size_value<SCALE>(position) == 1,302);
            assert!(position::get_offset(position) == 1,304);
            assert!(position::get_leverage(position) == 4,305);
            assert!(position::get_margin_balance(position) == 0,306);
            assert!(position::get_type(position) == 1,307);
            assert!(position::get_status(position) == 1,308);
            assert!(position::get_direction(position) == 1,309);
            assert!(position::get_lot(position) == 10000,310);
            assert!(position::get_open_price(position) == 1007,311);
            assert!(position::get_open_spread(position) == 150000,312);
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
            assert!(account::get_offset(&account) == 1,327);
            // balance = 310000
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse cross position so balance = 310000 - 1  => 309999
            // debug::print(&account);
            assert!(account::get_balance(&account) == 309999,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 2000,331);
            assert!(account::get_margin_cross_total(&account) == 2000,332);
            assert!(account::get_margin_used(&account) == 2000,333);
            assert!(account::get_margin_isolated_total(&account) == 0,334);
            assert!(account::get_margin_cross_buy_total(&account) == 2000,335);
            assert!(account::get_margin_cross_sell_total(&account) == 0,336);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,337);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,338);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,339);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),340);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = 2000 * 5 => 10000
            assert!(market::get_long_position_total(market) == 10000,341);
            assert!(market::get_short_position_total(market) == 0,342);
            let pool = market::get_pool(market);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (100000/10000 * 1 * (15/2))
            // 100000 - spread_fee => 100000 - 70 => 99930
            assert!(pool::get_vault_balance(pool) == 99930,343);
            assert!(pool::get_profit_balance(pool) == 0,344);
            assert!(pool::get_insurance_balance(pool) == 1,345);
            assert!(pool::get_spread_profit(pool) == 70,346);
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
        let position_id_1: ID;
        let position_id_2: ID;
        let position_id_3: ID;
        let position_id_4: ID;
        test_scenario::next_tx(tx,owner);
        {
            position_id_1 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            position_id_2 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,1,test_scenario::ctx(tx));
            position_id_3 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,2,test_scenario::ctx(tx));
            position_id_4 = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,2,test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            // price increases
            oracle::update_price(&mut root,feed_id,2000,11234569,test_scenario::ctx(tx));
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),500);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            market::set_opening_price_for_testing(market, 900);
            position::close_position<Tag,SCALE>(market, &mut account, &root,position_id_1,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_1),501);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // opening_price = 900
            // price = 2000
            // change = |opening_price - price|/opening_price => |900-2000|/900 => 1.2222222222222223
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 2000 * 1.5% => 30
            // buy_price: real_price+(spread/2)=> 2000 + 30/2 => 2015
            // sell_price: real_price - (spread/2)=> 2000 - 30/2 => 1985
            assert!(position::get_margin<SCALE>(&position) == 50,502);
            assert!(position::get_size_value<SCALE>(&position) == 1,503);
            assert!(position::get_offset(&position) == 1,504);
            assert!(position::get_leverage(&position) == 2,505);
            assert!(position::get_margin_balance(&position) == 0,506);
            assert!(position::get_type(&position) == 1,507);
            assert!(position::get_status(&position) == 2,508);
            assert!(position::get_direction(&position) == 1,509);
            assert!(position::get_lot(&position) == 1000,510);
            assert!(position::get_open_price(&position) == 1007,511);
            assert!(position::get_open_spread(&position) == 150000,512);
            assert!(position::get_open_real_price(&position) == 1000,513);
            assert!(position::get_close_price(&position) == 2015,514);
            assert!(position::get_close_spread(&position) == 300000,515);
            assert!(position::get_close_real_price(&position) == 2000,516);
            // pl = (sell_price - open_real_price) * size * (lot/DENOMINATOR128) => (1985 - 1000) * 1 * (1000/10000) => 98.5
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 98,517);
            assert!(i64::is_negative(profit) == false,517);
            assert!(position::get_stop_surplus_price(&position) == 0,518);
            assert!(position::get_stop_loss_price(&position) == 0,519);
            assert!(position::get_create_time(&position) == 0,520);
            assert!(position::get_close_time(&position) == 0,521);
            assert!(position::get_validity_time(&position) == 0,522);
            assert!(*position::get_open_operator(&position) == owner,523);
            assert!(*position::get_close_operator(&position) == owner,524);
            assert!(*position::get_market_id(&position) == market_id,525);
            assert!(*position::get_account_id(&position) == object::id(&account),526);
            // check account
            assert!(account::get_offset(&account) == 4,527);
            // balance = 5998
            // balance = balance + pl => 5998 + 98.5 => 6096
            assert!(account::get_balance(&account) == 6096,528);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 98,529);
            assert!(i64::is_negative(p) == false,530);

            assert!(account::get_margin_total(&account) == 4050,531);
            assert!(account::get_margin_cross_total(&account) == 50,532);
            assert!(account::get_margin_used(&account) == 50,533);
            assert!(account::get_margin_isolated_total(&account) == 4000,534);
            assert!(account::get_margin_cross_buy_total(&account) == 0,535);
            assert!(account::get_margin_cross_sell_total(&account) == 50,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 2000,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(!account::contains_pfk(&account,&pfk) == true ,539);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),540);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 10000,541);
            assert!(market::get_short_position_total(market) == 10100,542);
            let pool = market::get_pool(market);
            // check pool
            // 99860 - 98 = 99762
            assert!(pool::get_vault_balance(pool) == 99762,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 2,545);
            assert!(pool::get_spread_profit(pool) == 140,546);

            test_scenario::return_to_sender(tx,position);
        };
        test_scenario::next_tx(tx,owner);
        {
            oracle::update_price(&mut root,feed_id,1100,11234789,test_scenario::ctx(tx));
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),600);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);

            position::close_position<Tag,SCALE>(market, &mut account, &root,position_id_4,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_4),601);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // opening_price = 900
            // price = 1100
            // change = |opening_price - price|/opening_price => |900-1100|/900 => 0.2222
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1100 * 1.5% => 1100 * 0.015 => 16.5
            // buy_price: real_price+(spread/2)=> 1100 + 16/2 => 1108
            // sell_price: real_price - (spread/2)=> 1100 - 16/2 => 1092 , Due to computational accuracy issues, the actual value may be 1091.75
            assert!(position::get_margin<SCALE>(&position) == 2000,602);
            assert!(position::get_size_value<SCALE>(&position) == 1,603);
            assert!(position::get_offset(&position) == 4,604);
            assert!(position::get_leverage(&position) == 5,605);
            assert!(position::get_margin_balance(&position) == 0,606);
            assert!(position::get_type(&position) == 2,607);
            assert!(position::get_status(&position) == 2,608);
            assert!(position::get_direction(&position) == 2,609);
            assert!(position::get_lot(&position) == 100000,610);
            assert!(position::get_open_price(&position) == 992,611);
            assert!(position::get_open_spread(&position) == 150000,612);
            assert!(position::get_open_real_price(&position) == 1000,613);
            assert!(position::get_close_price(&position) == 1091,614);
            assert!(position::get_close_spread(&position) == 165000,615);
            assert!(position::get_close_real_price(&position) == 1100,616);
            // pl = (open_real_price - buy_price) * size * (lot/DENOMINATOR128) => (1000 - 1108) * 1 * (100000/10000)=> -108 * 1 * 10 => -1080
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 1080,617);
            assert!(i64::is_negative(profit) == true,6117);
            assert!(position::get_stop_surplus_price(&position) == 0,618);
            assert!(position::get_stop_loss_price(&position) == 0,619);
            assert!(position::get_create_time(&position) == 0,620);
            assert!(position::get_close_time(&position) == 0,621);
            assert!(position::get_validity_time(&position) == 0,622);
            assert!(*position::get_open_operator(&position) == owner,623);
            assert!(*position::get_close_operator(&position) == owner,624);
            assert!(*position::get_market_id(&position) == market_id,625);
            assert!(*position::get_account_id(&position) == object::id(&account),626);
            // check account
            assert!(account::get_offset(&account) == 4,627);
            // balance = 6096
            // balance = balance + (margin + pl) => 6096 + (2000 - 1080) => 7016
            assert!(account::get_balance(&account) == 7016,628);
            // total_profit = total_profit + pl => 98 + -1080 => -982
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 982,629);
            assert!(i64::is_negative(p) == true,630);

            assert!(account::get_margin_total(&account) == 2050,631);
            assert!(account::get_margin_cross_total(&account) == 50,632);
            assert!(account::get_margin_used(&account) == 50,533);
            assert!(account::get_margin_isolated_total(&account) == 2000,634);
            assert!(account::get_margin_cross_buy_total(&account) == 0,635);
            assert!(account::get_margin_cross_sell_total(&account) == 50,636);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,637);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,638);
            assert!(!account::contains_isolated_position_id(&account,&position_id_4) == false ,639);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),640);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 10000,641);
            // fund_size = margin * leverage => 2000 * 5 => 10000
            // total = 10100 - 10000 => 100
            assert!(market::get_short_position_total(market) == 100,642);
            let pool = market::get_pool(market);
            // check pool
            // 99762 + 1080 - 80 = 100762
            // because the vault supply is 100000 , so profit_balance = 762 ,vault_balance = 100000
            assert!(pool::get_vault_balance(pool) == 100000,643);
            assert!(pool::get_profit_balance(pool) == 762,644);
            assert!(pool::get_insurance_balance(pool) == 2,645);
            // spread_profit = (lot/DENOMINATOR128) * size * (spread / market::get_denominator() / 2) = 10 * (165000 / 10000 / 2) = 80
            // total = 140 + 80 = 220
            assert!(pool::get_spread_profit(pool) == 220,646);

            test_scenario::return_to_sender(tx,position);
        };
        // falling prices
        test_scenario::next_tx(tx,owner);
        {
            oracle::update_price(&mut root,feed_id,900,11235569,test_scenario::ctx(tx));
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),700);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            market::set_opening_price_for_testing(market, 990);
            position::close_position<Tag,SCALE>(market, &mut account, &root,position_id_2,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_2),701);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // opening_price = 990
            // price = 900
            // change = |opening_price - price|/opening_price => |990-900|/990 => 0.090
            // spread_fee => because change < 10% so spread_fee is 9/1000 => 0.009
            // spread = 900 * 0.009 => 8.1
            // buy_price: real_price+(spread/2)=> 900 + 8/2 => 904
            // sell_price: real_price - (spread/2)=> 900*10000 - 40500/2 => 895
            assert!(position::get_margin<SCALE>(&position) == 2000,702);
            assert!(position::get_size_value<SCALE>(&position) == 1,703);
            assert!(position::get_offset(&position) == 2,704);
            assert!(position::get_leverage(&position) == 5,705);
            assert!(position::get_margin_balance(&position) == 0,706);
            assert!(position::get_type(&position) == 2,707);
            assert!(position::get_status(&position) == 2,708);
            assert!(position::get_direction(&position) == 1,709);
            assert!(position::get_lot(&position) == 100000,710);
            assert!(position::get_open_price(&position) == 1007,711);
            assert!(position::get_open_spread(&position) == 150000,712);
            assert!(position::get_open_real_price(&position) == 1000,713);
            assert!(position::get_close_price(&position) == 904,714);
            assert!(position::get_close_spread(&position) == 81000,715);
            assert!(position::get_close_real_price(&position) == 900,716);
            // pl = (shell_price - open_real_price) * size * (lot/DENOMINATOR128) => (895 - 1000) * 1 * (100000/10000) = -1050
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 1050,717);
            assert!(i64::is_negative(profit) == true,7117);
            assert!(position::get_stop_surplus_price(&position) == 0,718);
            assert!(position::get_stop_loss_price(&position) == 0,719);
            assert!(position::get_create_time(&position) == 0,720);
            assert!(position::get_close_time(&position) == 0,721);
            assert!(position::get_validity_time(&position) == 0,722);
            assert!(*position::get_open_operator(&position) == owner,723);
            assert!(*position::get_close_operator(&position) == owner,724);
            assert!(*position::get_market_id(&position) == market_id,725);
            assert!(*position::get_account_id(&position) == object::id(&account),726);
            // check account
            assert!(account::get_offset(&account) == 4,727);
            // balance = 7016
            // balance = balance + (margin + pl) => 7016 + (2000 - 1050) => 7976
            assert!(account::get_balance(&account) == 7966,728);
            // total_profit = total_profit + pl => -982 + -1050 => -2032
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 2032,729);
            assert!(i64::is_negative(p) == true,730);

            assert!(account::get_margin_total(&account) == 50,731);
            assert!(account::get_margin_cross_total(&account) == 50,732);
            assert!(account::get_margin_used(&account) == 50,733);
            assert!(account::get_margin_isolated_total(&account) == 0,734);
            assert!(account::get_margin_cross_buy_total(&account) == 0,735);
            assert!(account::get_margin_cross_sell_total(&account) == 50,736);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,737);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,738);
            assert!(account::contains_isolated_position_id(&account,&position_id_2) == false ,739);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),740);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,741);
            assert!(market::get_short_position_total(market) == 100,742);
            let pool = market::get_pool(market);
            // check pool
            // size = 1 * 100000 / 10000 = 10
            // spread_profit = size * (spread / market::get_denominator() / 2) = 10 * (81000 / 10000 / 2) = 40.5
            // profit_balance = 762 + 1050 - 40  = 1772
            assert!(pool::get_vault_balance(pool) == 100000,743);
            assert!(pool::get_profit_balance(pool) == 1772,744);
            assert!(pool::get_insurance_balance(pool) == 2,745);
            // total = 220 + 40 = 260
            assert!(pool::get_spread_profit(pool) == 260,746);

            test_scenario::return_to_sender(tx,position);
        };
        test_scenario::next_tx(tx,owner);
        {
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),800);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            position::close_position<Tag,SCALE>(market, &mut account, &root,position_id_3,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_3),801);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // debug::print(&position);
            // opening_price = 990
            // price = 900
            // change = |opening_price - price|/opening_price => |990-900|/990 => 0.090
            // spread_fee => because change < 10% so spread_fee is 9/1000 => 0.009
            // spread = 900 * 90 => 81000
            // buy_price: (real_price+(spread/2))/10000=> (900*10000 + 81000/2)/10000 => 904
            // sell_price: (real_price - (spread/2))/10000=> (900*10000 - 81000/2)/10000 => 895
            assert!(position::get_margin<SCALE>(&position) == 50,802);
            assert!(position::get_size_value<SCALE>(&position) == 1,803);
            assert!(position::get_offset(&position) == 3,804);
            assert!(position::get_leverage(&position) == 2,805);
            assert!(position::get_margin_balance(&position) == 0,806);
            assert!(position::get_type(&position) == 1,807);
            assert!(position::get_status(&position) == 2,808);
            assert!(position::get_direction(&position) == 2,809);
            assert!(position::get_lot(&position) == 1000,810);
            assert!(position::get_open_price(&position) == 992,811);
            assert!(position::get_open_spread(&position) == 150000,812);
            assert!(position::get_open_real_price(&position) == 1000,813);
            assert!(position::get_close_price(&position) == 895,814);
            assert!(position::get_close_spread(&position) == 81000,815);
            assert!(position::get_close_real_price(&position) == 900,816);
            // pl = (open_real_price - buy_price) * size * (lot/DENOMINATOR128) => (1000 - 904) * 1 * (1000/DENOMINATOR128) => 10
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 10,817);
            assert!(i64::is_negative(profit) == false,8117);
            assert!(position::get_stop_surplus_price(&position) == 0,818);
            assert!(position::get_stop_loss_price(&position) == 0,819);
            assert!(position::get_create_time(&position) == 0,820);
            assert!(position::get_close_time(&position) == 0,821);
            assert!(position::get_validity_time(&position) == 0,822);
            assert!(*position::get_open_operator(&position) == owner,823);
            assert!(*position::get_close_operator(&position) == owner,824);
            assert!(*position::get_market_id(&position) == market_id,825);
            assert!(*position::get_account_id(&position) == object::id(&account),826);
            // check account
            assert!(account::get_offset(&account) == 4,827);
            // balance = 7966
            // balance = balance + pl => 7966 + 10 => 7976
            assert!(account::get_balance(&account) == 7976,828);
            // total_profit = total_profit + pl => -2032 + 10 => -2022
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 2022,829);
            assert!(i64::is_negative(p) == true,830);

            assert!(account::get_margin_total(&account) == 0,831);
            assert!(account::get_margin_cross_total(&account) == 0,832);
            assert!(account::get_margin_used(&account) == 0,833);
            assert!(account::get_margin_isolated_total(&account) == 0,834);
            assert!(account::get_margin_cross_buy_total(&account) == 0,835);
            assert!(account::get_margin_cross_sell_total(&account) == 0,836);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,837);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,838);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(!account::contains_pfk(&account,&pfk) == true ,839);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),840);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,841);
            assert!(market::get_short_position_total(market) == 0,842);
            let pool = market::get_pool(market);
            // check pool
            // size = 1 * 1000 / 10000 = 0.1
            // spread_profit = size * (spread / market::get_denominator() / 2) = 0.1 * (81000 / 10000 / 2) = 0.405
            // profit_balance = 1772 - 10 - 0  = 1762
            assert!(pool::get_vault_balance(pool) == 100000,843);
            assert!(pool::get_profit_balance(pool) == 1762,844);
            assert!(pool::get_insurance_balance(pool) == 2,845);
            // total = 260 + 0 = 260
            assert!(pool::get_spread_profit(pool) == 260,846);

            test_scenario::return_to_sender(tx,position);
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
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            assert!(position::get_status(&position) == 3,100);
            test_scenario::return_to_sender(tx,position);
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
    #[expected_failure(abort_code = 610, location = position)]
    fun test_risk_assertion(){
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
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // pre_exposure = 0
            // exposure = 0
            // liquidity_total = 100000
            position::risk_assertion_for_testing(market,1000,1,0);
            market::set_long_position_total_for_testing(market,80000);
            market::set_short_position_total_for_testing(market,1000);
            // pre_exposure = 0
            // exposure = 80000 - 1000 = 79000
            position::risk_assertion_for_testing(market,1000,1,80000);
            position::risk_assertion_for_testing(market,1000,1,79001);
            position::risk_assertion_for_testing(market,1000,1,78999);
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
    #[expected_failure(abort_code = 612, location = position)]
    fun test_risk_assertion_fund_size(){
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
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // pre_exposure = 0
            // exposure = 0
            // liquidity_total = 100000
            position::risk_assertion_for_testing(market,1000,1,0);
            market::set_long_position_total_for_testing(market,80000);
            market::set_short_position_total_for_testing(market,1000);
            // pre_exposure = 0
            // exposure = 80000 - 1000 = 79000
            position::risk_assertion_for_testing(market,1000,1,80000);
            position::risk_assertion_for_testing(market,1000,1,90000);
            position::risk_assertion_for_testing(market,19999,1,90000);
            position::risk_assertion_for_testing(market,0,1,90000);
            position::risk_assertion_for_testing(market,20000,1,90000);
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
    #[expected_failure(abort_code = 613, location = position)]
    fun test_risk_assertion_direction(){
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
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // pre_exposure = 0
            // exposure = 0
            // liquidity_total = 100000
            market::set_long_position_total_for_testing(market,0);
            position::risk_assertion_for_testing(market,1000,1,80000);

            market::set_short_position_total_for_testing(market,100);
            position::risk_assertion_for_testing(market,1000,2,80000);

            market::set_long_position_total_for_testing(market,2000);
            position::risk_assertion_for_testing(market,1000,1,80000);

            market::set_short_position_total_for_testing(market,3000);
            position::risk_assertion_for_testing(market,1000,2,80000);

            market::set_long_position_total_for_testing(market,140000);
            market::set_short_position_total_for_testing(market,130000);
            position::risk_assertion_for_testing(market,1000,1,80000);
            position::risk_assertion_for_testing(market,1000,2,80000);

            market::set_long_position_total_for_testing(market,149999);
            position::risk_assertion_for_testing(market,1000,1,80000);

            market::set_short_position_total_for_testing(market,149999);
            position::risk_assertion_for_testing(market,1000,2,80000);

            market::set_long_position_total_for_testing(market,150000);
            position::risk_assertion_for_testing(market,1000,1,80000);

            market::set_short_position_total_for_testing(market,150000);
            position::risk_assertion_for_testing(market,1000,2,80000);
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
    fun test_check_margin(){
        
    }
    // Value overflow test
}