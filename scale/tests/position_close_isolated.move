#[test_only]
module scale::position_close_isolated_tests {
    use scale::position_tests;
    use scale::market::{Self,Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool;
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    // use sui::coin::{Self};
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
        ) = position_tests::get_test_ctx<SCALE>();
        let tx = &mut scenario;
        let sb=*string::bytes(&symbol);
        let ps_id_1:ID;
        let ps_id_2:ID;
        test_scenario::next_tx(tx,owner);
        {

            ps_id_1 = position::open_position(
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
            // margin = 2000
            ps_id_2 = position::open_position(
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
            // margin = 5000
            assert!(account::get_balance(&account)==10000,201);
            // isolated_balance = 20000 - 2000 - 5000 - 1 - 2 = 12997
            assert!(account::get_isolated_balance(&account)==12997,202);
            // spread / 2 * size / DENOMINATOR / DENOMINATOR
            // size * spread / 2 / DENOMINATOR / DENOMINATOR;
            // 100000 * 150000 / 2 / 10000 / 10000 = 75
        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,135000);
            oracle::update_price_for_testing(&mut state,sb,2000,134,test_scenario::ctx(tx));
            let ps_new_id = position::close_position(
                ps_id_1,
                20000,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_new_id),201);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_new_id);
            // change = |opening_price - price|/opening_price
            // => 800 - 2000 / 800 => 1.5
            // spread_fee
            // => because change > 10% so spread_fee is 1.5%
            // spread = 2000 * 1.5% => 30
            // buy_price: real_price+(spread/2)=> 2000 + 30/2 => 2015
            // sell_price: real_price - (spread/2)=> 22000 - 30/2 => 1958
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 20000/10000 / 5  => 400
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            assert!(position::get_margin<SCALE>(position) == 400,203);
            assert!(position::get_size<SCALE>(position) == 1*20000,2003);
            assert!(position::get_offset(position) == 1,204);
            assert!(position::get_leverage(position) == 5,205);
            assert!(position::get_margin_balance(position) == 0,206);
            assert!(position::get_type(position) == 2,207);
            assert!(position::get_status(position) == 5,208);
            assert!(position::get_direction(position) == 1,209);
            assert!(position::get_lot(position) == 20000,210);
            assert!(position::get_open_price(position) == 1007,211);
            assert!(position::get_open_spread(position) == 150000,212);
            assert!(position::get_open_real_price(position) == 1000,213);
            assert!(position::get_close_price(position) == 2015,214);
            assert!(position::get_close_spread(position) == 300000,215);
            assert!(position::get_close_real_price(position) == 2000,216);
            // pl = fund_size - old_fund_size
            // => (sell_price - open_real_price) * size * (lot/DENOMINATOR128) => (1985 - 1000) * 1 * (20000/10000) => 1970
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 1970,217);
            assert!(i64::is_negative(profit) == false,217);
            assert!(position::get_stop_surplus_price(position) == 0,218);
            assert!(position::get_stop_loss_price(position) == 0,219);
            assert!(position::get_create_time(position) == 123000,220);
            assert!(position::get_close_time(position) == 135000,221);
            assert!(*position::get_open_operator(position) == owner,223);
            assert!(*position::get_close_operator(position) == owner,224);
            assert!(*position::get_market_id(position) == market_id ,225);
            assert!(*position::get_account_id(position) == object::id(&account),226);
            // check account
            assert!(account::get_offset(&account) == 2,227);
            // balance = 10000
            assert!(account::get_balance(&account) == 10000,228);
            // 12997 + 400 + 1970 = 15367
            assert!(account::get_isolated_balance(&account) == 15367,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 1970,229);
            assert!(i64::is_negative(p) == false,230);
            assert!(account::get_margin_total(&account) == 2000+5000-400,231);
            assert!(account::get_margin_cross_total(&account) == 0,232);
            assert!(account::get_margin_used(&account) == 0,133);
            assert!(account::get_margin_isolated_total(&account) == 6600,234);
            assert!(account::get_margin_cross_buy_total(&account) == 0,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 1600,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 5000,238);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,239);
            assert!(account::contains_isolated_position_id(&account,&ps_id_1) == true ,240);
            assert!(account::contains_isolated_position_id(&account,&ps_new_id) == false ,2401);
            // check market
            assert!(market::get_long_position_total(market) == 1600*5,241);
            assert!(market::get_short_position_total(market) == 5000*2,242);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // 1_000_000 - 1970 - 75 - 75 = 997880
            assert!(pool::get_vault_balance(pool) == 997880 ,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 3,245);
            assert!(pool::get_spread_profit(pool) == 75+75,246);
        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,136000);
            oracle::update_price_for_testing(&mut state,sb,1050,135,test_scenario::ctx(tx));
            // debug::print(&account);
            let ps_new_id = position::close_position(
                ps_id_2,
                20000,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_new_id),201);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_new_id);
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 20000/10000 / 2  => 1000
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(position::get_margin<SCALE>(position) == 1000,203);
            assert!(position::get_size<SCALE>(position) == 1*20000,2003);
            assert!(position::get_offset(position) == 2,204);
            assert!(position::get_leverage(position) == 2,205);
            assert!(position::get_margin_balance(position) == 0,206);
            assert!(position::get_type(position) == 2,207);
            assert!(position::get_status(position) == 5,208);
            assert!(position::get_direction(position) == 2,209);
            assert!(position::get_lot(position) == 20000,210);
            assert!(position::get_open_price(position) == 992,211);
            assert!(position::get_open_spread(position) == 150000,212);
            assert!(position::get_open_real_price(position) == 1000,213);
            assert!(position::get_close_price(position) == 1042,214);
            assert!(position::get_close_spread(position) == 157500,215);
            assert!(position::get_close_real_price(position) == 1050,216);
            // pl = fund_size - old_fund_size
            // => ( open_real_price - sell_price) * size * (lot/DENOMINATOR128) => (1000 - 1057) * 1 * (20000/10000) => -114
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 114,217);
            assert!(i64::is_negative(profit) == true,217);
            assert!(position::get_stop_surplus_price(position) == 0,218);
            assert!(position::get_stop_loss_price(position) == 0,219);
            assert!(position::get_create_time(position) == 123000,220);
            assert!(position::get_close_time(position) == 136000,221);
            assert!(*position::get_open_operator(position) == owner,223);
            assert!(*position::get_close_operator(position) == owner,224);
            assert!(*position::get_market_id(position) == market_id ,225);
            assert!(*position::get_account_id(position) == object::id(&account),226);
            // check account
            assert!(account::get_offset(&account) == 2,227);
            // balance = 10000
            assert!(account::get_balance(&account) == 10000,228);
            // debug::print(&account);
            assert!(account::get_isolated_balance(&account) == 15367+(1000-114),228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 1970-114,229);
            assert!(i64::is_negative(p) == false,230);
            assert!(account::get_margin_total(&account) == 2000+5000-400-1000,231);
            assert!(account::get_margin_cross_total(&account) == 0,232);
            assert!(account::get_margin_used(&account) == 0,133);
            assert!(account::get_margin_isolated_total(&account) == 6600-1000,234);
            assert!(account::get_margin_cross_buy_total(&account) == 0,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 1600,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 5000-1000,238);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,239);
            assert!(account::contains_isolated_position_id(&account,&ps_id_1) == true ,240);
            assert!(account::contains_isolated_position_id(&account,&ps_new_id) == false ,2401);
            // check market
            assert!(market::get_long_position_total(market) == 1600*5,241);
            assert!(market::get_short_position_total(market) == 8000,242);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // 1_000_000 - 1970 - 75 - 75 = 997880
            assert!(pool::get_vault_balance(pool) == 997880+114 ,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 3,245);
            assert!(pool::get_spread_profit(pool) == 75+75,246);
        };
        test_scenario::next_tx(tx,owner);
        {
            position::close_position(
                ps_id_1,
                0,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            position::close_position(
                ps_id_2,
                0,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            assert!(market::get_long_position_total(market) == 0,941);
            assert!(market::get_short_position_total(market) == 0,942);
            assert!(account::get_margin_total(&account) == 0,931);
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
    #[test]
    fun test_auto_close_isolated(){
        let(
            owner,
            scenario,
            symbol,
            account,
            scale_coin,
            list,
            state,
            c,
        ) = position_tests::get_test_ctx<SCALE>();
        let tx = &mut scenario;
        let sb=*string::bytes(&symbol);
        let ps_id_1:ID;
        let ps_id_2:ID;
        test_scenario::next_tx(tx,owner);
        {
            ps_id_1 = position::open_position(
                sb,
                100000,
                5,
                1,
                2,
                0,
                1500,
                800,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx)
            );
            ps_id_2 = position::open_position(
                sb,
                100000,
                2,
                2,
                2,
                0,
                800,
                1500,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx)
            );
        };
        test_scenario::next_tx(tx,owner);
        {
            position::auto_close_position(
                ps_id_1,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,137000);
            oracle::update_price_for_testing(&mut state,sb,800,137,test_scenario::ctx(tx));
            position::auto_close_position(
                ps_id_2,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
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
