#[test_only]
module scale::position_open_cross_tests{
    use scale::position_tests;
    use scale::market::{Self,Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Scale};
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self};
    // use sui::coin::{Self};
    use oracle::oracle;
    use scale::i64;
    // use std::debug;
    use sui_coin::scale::{SCALE};
    use std::string;
    use sui::clock;
    #[test]
    fun test_open_cross_position(){
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
            assert!(position::get_create_time(position) == 123000,220);
            assert!(position::get_close_time(position) == 0,221);
            assert!(position::get_validity_time(position) == 0,222);
            assert!(*position::get_open_operator(position) == owner,223);
            assert!(*position::get_close_operator(position) == @0x0,224);
            assert!(*position::get_market_id(position) == market_id ,225);
            assert!(*position::get_account_id(position) == object::id(&account),226);
            // check account
            assert!(account::get_offset(&account) == 1,227);
            // balance = 10000
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse cross position so balance = 10000 - 1  => 9999
            // debug::print(&account);
            assert!(account::get_balance(&account) == 9999,228);
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
            // debug::print(market);
            // long_total = 2000 * 5 => 10000
            assert!(market::get_long_position_total(market) == 10000,241);
            assert!(market::get_short_position_total(market) == 0,242);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // ==> 150000 / 2 * 100000 / 10000 / 10000 => 75
            // 100000 - spread_fee
            // => 100000 - 75 => 99925
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
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),301);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(&price);
            // price = fund_size / size => (10 * 1000 + 1 * 1000) / 11 => 1000
            // change = |opening_price - price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // lot = 10000 + 100000 => 110000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage 
            // => 1000 * 1 * 110000/10000 / 4  => 2750
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 2750,303);
            assert!(position::get_size<SCALE>(position) == 1*110000,302);
            assert!(position::get_offset(position) == 1,304);
            assert!(position::get_leverage(position) == 4,305);
            assert!(position::get_margin_balance(position) == 0,306);
            assert!(position::get_type(position) == 1,307);
            assert!(position::get_status(position) == 1,308);
            assert!(position::get_direction(position) == 1,309);
            assert!(position::get_lot(position) == 110000,310);
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
            assert!(position::get_validity_time(position) == 0,322);
            assert!(*position::get_open_operator(position) == owner,323);
            assert!(*position::get_close_operator(position) == @0x0,324);
            assert!(*position::get_market_id(position) == market_id,325);
            assert!(*position::get_account_id(position) == object::id(&account),326);
            // check account
            assert!(account::get_offset(&account) == 1,327);
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse cross position so balance = 9999 - 1  => 9998
            // debug::print(&account);
            assert!(account::get_balance(&account) == 9998,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 2750,331);
            assert!(account::get_margin_cross_total(&account) == 2750,332);
            assert!(account::get_margin_used(&account) == 2750,333);
            assert!(account::get_margin_isolated_total(&account) == 0,334);
            assert!(account::get_margin_cross_buy_total(&account) == 2750,335);
            assert!(account::get_margin_cross_sell_total(&account) == 0,336);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,337);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,338);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,339);
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
            assert!(position::get_offset(position) == 2,404);
            assert!(position::get_leverage(position) == 2,405);
            assert!(position::get_margin_balance(position) == 0,406);
            assert!(position::get_type(position) == 1,407);
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
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == @0x0,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 2,427);
            // balance = 9998
            // insurance = margin * 5/10000 = 5000 * 5/10000 => 2.5
            // becouse cross position so balance = 9998 - 2  => 9996
            // debug::print(&account);
            assert!(account::get_balance(&account) == 9996,428);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,429);
            assert!(i64::is_negative(p) == false,430);
            assert!(account::get_margin_total(&account) == 7750,431);
            assert!(account::get_margin_cross_total(&account) == 7750,432);
            assert!(account::get_margin_used(&account) == 5000,433);
            assert!(account::get_margin_isolated_total(&account) == 0,434);
            assert!(account::get_margin_cross_buy_total(&account) == 2750,435);
            assert!(account::get_margin_cross_sell_total(&account) == 5000,436);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,437);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,438);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,439);
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
            // spread_fee => because change < 10% so spread_fee is 0.75%
            // debug::print(position);
            // price = fund_size / size => (10 * 1000 + 1 * 900) / 11 => 990
            // change = |opening_price - price|/opening_price => |800-990|/800 => 0.23
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 990 * 1.5% => 14.85
            // buy_price: real_price+(spread/2)=> 990 + 14/2 => 997
            // sell_price: real_price - (spread/2)=> 990 - 14/2 => 982
            // lot = 10000 + 100000 => 110000
            // s_margin = real_price * size * (lot / DENOMINATOR128) / leverage => 900 * 1 * 10000/10000 / 5  => 180
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 990 * 1 * 110000/10000 / 5  => 2178
            assert!(position::get_margin<SCALE>(position) == 2178,503);
            assert!(position::get_size<SCALE>(position) == 1*110000,502);
            assert!(position::get_offset(position) == 2,504);
            assert!(position::get_leverage(position) == 5,505);
            assert!(position::get_margin_balance(position) == 0,506);
            assert!(position::get_type(position) == 1,507);
            assert!(position::get_status(position) == 1,508);
            assert!(position::get_direction(position) == 2,509);
            assert!(position::get_lot(position) == 110000,510);
            assert!(position::get_open_price(position) == 982,511);
            assert!(position::get_open_spread(position) == 148500,512);
            assert!(position::get_open_real_price(position) == 990,513);
            assert!(position::get_close_price(position) == 0,514);
            assert!(position::get_close_spread(position) == 0,515);
            assert!(position::get_close_real_price(position) == 0,516);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,517);
            assert!(i64::is_negative(profit) == false,517);
            assert!(position::get_stop_surplus_price(position) == 0,518);
            assert!(position::get_stop_loss_price(position) == 0,519);
            assert!(position::get_create_time(position) == 123000,520);
            assert!(position::get_close_time(position) == 0,521);
            assert!(position::get_validity_time(position) == 0,522);
            assert!(*position::get_open_operator(position) == owner,523);
            assert!(*position::get_close_operator(position) == @0x0,524);
            assert!(*position::get_market_id(position) == market_id,525);
            assert!(*position::get_account_id(position) == object::id(&account),526);
            // check account
            assert!(account::get_offset(&account) == 2,527);
            // balace = 9996
            // insurance = margin * 5/10000 = 180 * 5/10000 => 0.09 => 1
            // becouse cross position so balance = 9996 - 1  => 9995
            // debug::print(&account);
            assert!(account::get_balance(&account) == 9995,528);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,529);
            assert!(i64::is_negative(p) == false,530);
            // 2750 + 2178 = 4928
            assert!(account::get_margin_total(&account) == 4928,531);
            assert!(account::get_margin_cross_total(&account) == 4928,532);
            assert!(account::get_margin_used(&account) == 2750,533);
            assert!(account::get_margin_isolated_total(&account) == 0,534);
            assert!(account::get_margin_cross_buy_total(&account) == 2750,535);
            assert!(account::get_margin_cross_sell_total(&account) == 2178,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,539);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 11000,541);
            assert!(market::get_short_position_total(market) == 10890,542);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // => 135000 / 2 * 10000 / 10000 / 10000 => 6.75
            assert!(pool::get_vault_balance(pool) == 999843-6,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 4+1,545);
            assert!(pool::get_spread_profit(pool) == 157+6,546);
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