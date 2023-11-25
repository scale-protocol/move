#[test_only]
module scale::position_open_isolated_tests{
    use scale::position_tests;
    use scale::market::{Self,Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Scale};
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self};
    use std::vector;
    use sui::coin;
    use oracle::oracle;
    use scale::i64;
    // use std::debug;
    use sui_coin::scale::{SCALE};
    use std::string;
    use sui::clock;
    #[test]
    fun test_open_isolated_position(){
        let(
            owner,
            scenario,
            symbol,
            account,
            scale_coin,
            list,
            state,
            c,
        ) = position_tests::get_test_ctx<Scale,SCALE>();
        let tx = &mut scenario;
        let sb=*string::bytes(&symbol);
        test_scenario::next_tx(tx,owner);
        {
            let position_id = position::open_position(
                sb,
                100000,
                5,
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
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),201);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // change = |opening_price - price|/opening_price =>
            // => 800 - 1000 / 800 => 0.25
            // spread_fee
            // => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 5  => 2000
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 2000,203);
            assert!(position::get_size<SCALE>(position) == 1*100000,2003);
            assert!(position::get_offset(position) == 1,204);
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
            assert!(position::get_create_time(position) == 123000,220);
            assert!(position::get_close_time(position) == 0,221);
            assert!(*position::get_open_operator(position) == owner,223);
            assert!(*position::get_close_operator(position) == @0x0,224);
            assert!(*position::get_market_id(position) == market_id ,225);
            assert!(*position::get_account_id(position) == object::id(&account),226);
            // check account
            assert!(account::get_offset(&account) == 1,227);
            // balance = 10000
            // isolated_balance = 20000
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse isolated position so balance = isolated_balance - margin - insurance  => 20000 - 2000 - 1  => 17999
            // 20000 - 2000 - 1  => 17999
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10000,228);
            assert!(account::get_isolated_balance(&account) == 17999,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,229);
            assert!(i64::is_negative(p) == false,230);
            assert!(account::get_margin_total(&account) == 2000,231);
            assert!(account::get_margin_cross_total(&account) == 0,232);
            assert!(account::get_margin_used(&account) == 0,133);
            assert!(account::get_margin_isolated_total(&account) == 2000,234);
            assert!(account::get_margin_cross_buy_total(&account) == 0,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,238);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,239);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,240);
            // check market
            // debug::print(market);
            // // long_total = 2000 * 5 => 10000
            assert!(market::get_long_position_total(market) == 10000,241);
            assert!(market::get_short_position_total(market) == 0,242);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // // ==> 150000 / 2 * 100000 / 10000 / 10000 => 75
            // // 100000 - spread_fee
            // // => 100000 - 75 => 99925
            assert!(pool::get_vault_balance(pool) == 999925,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 1,245);
            assert!(pool::get_spread_profit(pool) == 75,246);
        };
        test_scenario::next_tx(tx,owner);
        {
           let position_id = position::open_position(
                sb,
                10000,
                4,
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
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),301);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(&price);
            // change = |opening_price - price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage 
            // => 1000 * 1 * 10000/10000 / 4  => 250
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 250,303);
            assert!(position::get_size<SCALE>(position) == 1*10000,302);
            assert!(position::get_offset(position) == 2,304);
            assert!(position::get_leverage(position) == 4,305);
            assert!(position::get_margin_balance(position) == 250,306);
            assert!(position::get_type(position) == 2,307);
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
            assert!(position::get_create_time(position) == 123000,320);
            assert!(position::get_close_time(position) == 0,321);
            assert!(*position::get_open_operator(position) == owner,323);
            assert!(*position::get_close_operator(position) == @0x0,324);
            assert!(*position::get_market_id(position) == market_id,325);
            assert!(*position::get_account_id(position) == object::id(&account),326);
            // check account
            assert!(account::get_offset(&account) == 2,327);
            // balance = 10000
            // isolated_balance = 17999
            // insurance = 250 * 5/10000 = 1250 * 5/10000 => 0.125 => 1
            // becouse isolated position so balance = isolated_balance - margin - insurance
            // => 17999 - 250 - 1  => 17748
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10000,328);
            assert!(account::get_isolated_balance(&account) == 17748,3280);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 2250,331);
            assert!(account::get_margin_cross_total(&account) == 0,332);
            assert!(account::get_margin_used(&account) == 0,333);
            assert!(account::get_margin_isolated_total(&account) == 2250,334);
            assert!(account::get_margin_cross_buy_total(&account) == 0,335);
            assert!(account::get_margin_cross_sell_total(&account) == 0,336);
            assert!(account::get_margin_isolated_buy_total(&account) == 2250,337);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,338);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,339);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,240);
            // check market
            // debug::print(market);
            // long_total = 2750 * 2 => 10000
            assert!(market::get_long_position_total(market) == 11000,341);
            assert!(market::get_short_position_total(market) == 0,342);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // => 150000 / 2 * 10000 / 10000 / 10000 => 7.5
            assert!(pool::get_vault_balance(pool) == 999925-7,343);
            assert!(pool::get_profit_balance(pool) == 0,344);
            assert!(pool::get_insurance_balance(pool) == 1+1,345);
            assert!(pool::get_spread_profit(pool) == 75+7,346);
        };
        test_scenario::next_tx(tx,owner);
        {
           let position_id = position::open_position(
                sb,
                100000,
                2,
                2,
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
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),401);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(&price);
            // debug::print(position);
            // change = |opening_price - price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 2  => 5000
            assert!(position::get_margin<SCALE>(position) == 5000,403);
            assert!(position::get_size<SCALE>(position) == 1*100000,402);
            assert!(position::get_offset(position) == 3,404);
            assert!(position::get_leverage(position) == 2,405);
            assert!(position::get_margin_balance(position) == 5000,406);
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
            assert!(position::get_create_time(position) == 123000,420);
            assert!(position::get_close_time(position) == 0,421);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == @0x0,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 3,427);
            // balance = 10000
            // isolated_balance = 17748
            // insurance = margin * 5/10000 = 5000 * 5/10000 => 2.5
            // becouse isolated position so balance = balance - margin - insurance
            // => 17748 - 5000 - 2  => 12746
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10000,428);
            assert!(account::get_isolated_balance(&account) == 12746,4280);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,429);
            assert!(i64::is_negative(p) == false,430);
            assert!(account::get_margin_total(&account) == 7250,431);
            assert!(account::get_margin_cross_total(&account) == 0,432);
            assert!(account::get_margin_used(&account) == 0,433);
            assert!(account::get_margin_isolated_total(&account) == 7250,434);
            assert!(account::get_margin_cross_buy_total(&account) == 0,435);
            assert!(account::get_margin_cross_sell_total(&account) == 0,436);
            assert!(account::get_margin_isolated_buy_total(&account) == 2250,437);
            assert!(account::get_margin_isolated_sell_total(&account) == 5000,438);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,439);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,240);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 11000,441);
            assert!(market::get_short_position_total(market) == 10000,442);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // => 150000 / 2 * 100000 / 10000 / 10000 => 75
            assert!(pool::get_vault_balance(pool) == 999918-75,443);
            assert!(pool::get_profit_balance(pool) == 0,444);
            assert!(pool::get_insurance_balance(pool) == 2+2,445);
            assert!(pool::get_spread_profit(pool) == 82+75,446);
        };
        test_scenario::next_tx(tx,owner);
        {
            let ctx = test_scenario::ctx(tx);
            clock::set_for_testing(&mut c,134000);
            oracle::update_price_for_testing(&mut state,sb,900,133,ctx);
            let position_id = position::open_position(
                sb,
                10000,
                5,
                2,
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
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(&price);
            // debug::print(position);
            // change = |opening_price - price|/opening_price => |800-900|/800 => 0.125
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 900 * 1.5% => 13.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 900 * 1 * 10000/10000 / 5  => 180
            assert!(position::get_margin<SCALE>(position) == 180,503);
            assert!(position::get_size<SCALE>(position) == 1*10000,502);
            assert!(position::get_offset(position) == 4,504);
            assert!(position::get_leverage(position) == 5,505);
            assert!(position::get_margin_balance(position) == 180,506);
            assert!(position::get_type(position) == 2,507);
            assert!(position::get_status(position) == 1,508);
            assert!(position::get_direction(position) == 2,509);
            assert!(position::get_lot(position) == 10000,510);
            assert!(position::get_open_price(position) == 893,511);
            assert!(position::get_open_spread(position) == 135000,512);
            assert!(position::get_open_real_price(position) == 900,513);
            assert!(position::get_close_price(position) == 0,514);
            assert!(position::get_close_spread(position) == 0,515);
            assert!(position::get_close_real_price(position) == 0,516);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,517);
            assert!(i64::is_negative(profit) == false,517);
            assert!(position::get_stop_surplus_price(position) == 0,518);
            assert!(position::get_stop_loss_price(position) == 0,519);
            assert!(position::get_create_time(position) == 134000,520);
            assert!(position::get_close_time(position) == 0,521);
            assert!(*position::get_open_operator(position) == owner,523);
            assert!(*position::get_close_operator(position) == @0x0,524);
            assert!(*position::get_market_id(position) == market_id,525);
            assert!(*position::get_account_id(position) == object::id(&account),526);
            // check account
            assert!(account::get_offset(&account) == 4,527);
            // balace = 10000
            // insurance = margin * 5/10000 = 180 * 5/10000 => 0.09 => 1
            // isolated_balance = 12746
            // becouse isolated position so balance = balance - margin - insurance
            // => 12746 - 180 - 1  => 12565
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10000,528);
            assert!(account::get_isolated_balance(&account) == 12565,5280);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,529);
            assert!(i64::is_negative(p) == false,530);
            assert!(account::get_margin_total(&account) == 7250+180,531);
            assert!(account::get_margin_cross_total(&account) == 0,532);
            assert!(account::get_margin_used(&account) == 0,533);
            assert!(account::get_margin_isolated_total(&account) == 7250 + 180,534);
            assert!(account::get_margin_cross_buy_total(&account) == 0,535);
            assert!(account::get_margin_cross_sell_total(&account) == 0,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 2250,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 5180,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,539);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,540);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 11000,541);
            assert!(market::get_short_position_total(market) == 10900,542);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // => 135000 / 2 * 10000 / 10000 / 10000 => 6.75
            assert!(pool::get_vault_balance(pool) == 999843-6,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 4+1,545);
            assert!(pool::get_spread_profit(pool) == 157+6,546);
        };
        test_scenario::next_tx(tx,owner);
        {
            // test isolated_deposit
            let ctx = test_scenario::ctx(tx);
            let ids = account::get_isolated_position_ids(&account);
            let position_id = vector::pop_back(&mut ids);
            let co = coin::split(&mut scale_coin, 345,ctx);
            position::isolated_deposit(
                position_id,
                co,
                0,
                &mut account,
                &mut list,
                ctx,
            );
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),601);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            assert!(position::get_margin<SCALE>(position) == 180+345,603);
            assert!(position::get_size<SCALE>(position) == 1*10000,602);
            assert!(position::get_offset(position) == 4,604);
            assert!(position::get_leverage(position) == 5,605);
            assert!(position::get_margin_balance(position) == 180+345,606);
            assert!(position::get_type(position) == 2,607);
            assert!(position::get_status(position) == 1,608);
            assert!(position::get_direction(position) == 2,609);
            assert!(position::get_lot(position) == 10000,610);
            assert!(position::get_open_price(position) == 893,611);
            assert!(position::get_open_spread(position) == 135000,612);
            assert!(position::get_open_real_price(position) == 900,613);
            assert!(position::get_close_price(position) == 0,614);
            assert!(position::get_close_spread(position) == 0,615);
            assert!(position::get_close_real_price(position) == 0,616);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,617);
            assert!(i64::is_negative(profit) == false,617);
            assert!(position::get_stop_surplus_price(position) == 0,618);
            assert!(position::get_stop_loss_price(position) == 0,619);
            assert!(position::get_create_time(position) == 134000,620);
            assert!(position::get_close_time(position) == 0,621);
            assert!(*position::get_open_operator(position) == owner,623);
            assert!(*position::get_close_operator(position) == @0x0,624);
            assert!(*position::get_market_id(position) == market_id,625);
            assert!(*position::get_account_id(position) == object::id(&account),626);
            // check market
            assert!(market::get_long_position_total(market) == 11000,641);
            assert!(market::get_short_position_total(market) == 10900,642);
            assert!(coin::value(&scale_coin)== 100_0000 - 345,657);
        };
        test_scenario::next_tx(tx,owner);
        {
            let ctx = test_scenario::ctx(tx);
            let ids = account::get_isolated_position_ids(&account);
            let position_id = vector::borrow(&ids,1);
            let co = coin::split(&mut scale_coin, 656,ctx);
            position::isolated_deposit(
                *position_id,
                co,
                233,
                &mut account,
                &mut list,
                ctx,
            );
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),*position_id),601);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),*position_id);
            assert!(position::get_margin<SCALE>(position) == 250+233,303);
            assert!(position::get_size<SCALE>(position) == 1*10000,302);
            assert!(position::get_offset(position) == 2,304);
            assert!(position::get_leverage(position) == 4,305);
            assert!(position::get_margin_balance(position) == 250+233,306);
            assert!(position::get_type(position) == 2,307);
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
            assert!(position::get_create_time(position) == 123000,320);
            assert!(position::get_close_time(position) == 0,321);
            assert!(*position::get_open_operator(position) == owner,323);
            assert!(*position::get_close_operator(position) == @0x0,324);
            assert!(*position::get_market_id(position) == market_id,325);
            assert!(*position::get_account_id(position) == object::id(&account),326);

            assert!(coin::value(&scale_coin)== 100_0000 - 345 - 656,657);
        };
        position_tests::drop_test_ctx(
            scenario,
            account,
            scale_coin,
            list,
            state,
            c,
        );
    }
}