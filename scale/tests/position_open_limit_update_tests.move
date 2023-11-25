#[test_only]
module scale::position_open_limit_update_tests{
    use scale::position_tests;
    use scale::market::{Self,Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Scale};
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    use scale::i64;
    use sui_coin::scale::{SCALE};
    use std::string;

    #[test]
    fun test_update_limit_position(){
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
        let position_id:ID;
        test_scenario::next_tx(tx,owner);
        {
            // clock::set_for_testing(&mut c,134000);
            // oracle::update_price_for_testing(&mut state,sb,900,133,ctx);
            position_id = position::open_position(
                sb,
                100000,
                5,
                1,
                2,
                1000,
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
            assert!(position::get_status(position) == 4,208);
            assert!(position::get_direction(position) == 1,209);
            assert!(position::get_lot(position) == 100000,210);
            assert!(position::get_open_price(position) == 1007,211);
            assert!(position::get_open_spread(position) == 150000,212);
            assert!(position::get_open_real_price(position) == 1000,213);
            assert!(position::get_close_price(position) == 0,214);
            assert!(position::get_close_spread(position) == 0,215);
            assert!(position::get_close_real_price(position) == 0,216);
            assert!(position::get_auto_open_price(position) == 1000,2160);
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
            // becouse isolated position so balance = isolated_balance - margin  => 20000 - 2000 - 1  => 17999
            // 20000 - 2000  => 18000
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10000,228);
            assert!(account::get_isolated_balance(&account) == 18000,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,229);
            assert!(i64::is_negative(p) == false,230);
            assert!(account::get_margin_total(&account) == 0,231);
            assert!(account::get_margin_cross_total(&account) == 0,232);
            assert!(account::get_margin_used(&account) == 0,133);
            assert!(account::get_margin_isolated_total(&account) == 0,234);
            assert!(account::get_margin_cross_buy_total(&account) == 0,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,238);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,239);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,240);
            assert!(market::get_long_position_total(market) == 0,241);
            assert!(market::get_short_position_total(market) == 0,242);
            let pool = market::get_pool(&list);
            assert!(pool::get_vault_balance(pool) == 100_0000,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 0,245);
            assert!(pool::get_spread_profit(pool) == 0,246);
        };
        test_scenario::next_tx(tx,owner);
        {
            let ctx = test_scenario::ctx(tx);
            position::update_limit_position(
                position_id,
                10000,
                4,
                100000,
                &mut list,
                &mut account,
                ctx,
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
            assert!(position::get_offset(position) == 1,304);
            assert!(position::get_leverage(position) == 4,305);
            assert!(position::get_margin_balance(position) == 250,306);
            assert!(position::get_type(position) == 2,307);
            assert!(position::get_status(position) == 4,308);
            assert!(position::get_direction(position) == 1,309);
            assert!(position::get_lot(position) == 10000,310);
            assert!(position::get_open_price(position) == 1007,311);
            assert!(position::get_auto_open_price(position) == 100000,3110);
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
            assert!(account::get_offset(&account) == 1,327);
            // balance = 10000
            // isolated_balance = 18000
            // margin = 250
            // old_margin = 2000
            // diff = old_margin - margin = 2000 - 250 => 1750
            // isolated_balance = isolated_balance + diff => 18000 + 1750 => 19750
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10000,328);

            assert!(account::get_isolated_balance(&account) == 19750,3280);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 0,331);
            assert!(account::get_margin_cross_total(&account) == 0,332);
            assert!(account::get_margin_used(&account) == 0,333);
            assert!(account::get_margin_isolated_total(&account) == 0,334);
            assert!(account::get_margin_cross_buy_total(&account) == 0,335);
            assert!(account::get_margin_cross_sell_total(&account) == 0,336);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,337);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,338);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,339);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,240);
            assert!(market::get_long_position_total(market) == 0,341);
            assert!(market::get_short_position_total(market) == 0,342);
            let pool = market::get_pool(&list);
            assert!(pool::get_vault_balance(pool) == 100_0000,343);
            assert!(pool::get_profit_balance(pool) == 0,344);
            assert!(pool::get_insurance_balance(pool) == 0,345);
            assert!(pool::get_spread_profit(pool) == 0,346);
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