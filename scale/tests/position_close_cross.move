#[test_only]
module scale::position_close_cross_tests {
    use scale::position_tests;
    use scale::market::{Self,Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Scale};
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
        let ps_id_1:ID;
        let ps_id_2:ID;
        test_scenario::next_tx(tx,owner);
        {
            position::open_position(
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
            ps_id_1 = position::open_position(
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
            position::open_position(
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
            clock::set_for_testing(&mut c,134000);
            oracle::update_price_for_testing(&mut state,sb,900,133,test_scenario::ctx(tx));
            ps_id_2 = position::open_position(
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
        };

        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,135000);
            oracle::update_price_for_testing(&mut state,sb,2000,134,test_scenario::ctx(tx));
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            market::set_opening_price_for_testing(market, 900);
            // let pool = market::get_pool(&list);
            // debug::print(pool);
            // debug::print(&account);
            // partial close
            let new_position_id = position::close_position(
                ps_id_1,
                20000,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            // opening_price = 900
            // price = 2000
            // change = |opening_price - price|/opening_price => |900-2000|/900 => 1.2222222222222223
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 2000 * 1.5% => 30
            // buy_price: real_price+(spread/2)=> 2000 + 30/2 => 2015
            // sell_price: real_price-(spread/2)=> 2000 - 30/2 => 1985
            // real_open_price = 1000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 20000/10000 / 4  => 500
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),new_position_id),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),new_position_id);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 500,403);
            assert!(position::get_size<SCALE>(position) == 1*20000,402);
            assert!(position::get_offset(position) == 1,404);
            assert!(position::get_leverage(position) == 4,405);
            assert!(position::get_margin_balance(position) == 0,406);
            assert!(position::get_type(position) == 1,407);
            assert!(position::get_status(position) == 5,408);
            assert!(position::get_direction(position) == 1,409);
            assert!(position::get_lot(position) == 20000,410);
            assert!(position::get_open_price(position) == 1007,411);
            assert!(position::get_open_spread(position) == 150000,412);
            assert!(position::get_open_real_price(position) == 1000,413);
            assert!(position::get_close_price(position) == 2015,414);
            assert!(position::get_close_spread(position) == 300000,415);
            assert!(position::get_close_real_price(position) == 2000,416);
            // pl = fund_size - old_fund_size
            // => (sell_price - open_real_price) * size * (lot/DENOMINATOR128) => (1985 - 1000) * 1 * (20000/10000) => 1970
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 1970,417);
            assert!(i64::is_negative(profit) == false,417);
            assert!(position::get_stop_surplus_price(position) == 0,418);
            assert!(position::get_stop_loss_price(position) == 0,419);
            assert!(position::get_create_time(position) == 123000,420);
            assert!(position::get_close_time(position) == 135000,421);
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == owner,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 2,327);
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse cross position so balance = 9999 - 1  => 9995
            // bealance = balance + pl => 9995 + 1970 => 11965
            // debug::print(&account);
            assert!(account::get_balance(&account) == 11965,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 1970,529);
            assert!(i64::is_negative(p) == false,530);
            assert!(account::get_margin_total(&account) == 4928-500,531);
            assert!(account::get_margin_cross_total(&account) == 4928-500,532);
            assert!(account::get_margin_used(&account) == 2250,533);
            assert!(account::get_margin_isolated_total(&account) == 0,534);
            assert!(account::get_margin_cross_buy_total(&account) == 2250,535);
            assert!(account::get_margin_cross_sell_total(&account) == 2178,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,539);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 11000 - (500 * 4),541);
            assert!(market::get_short_position_total(market) == 10890,542);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // spread_fee = spread / 2 * size / DENOMINATOR / DENOMINATOR
            // => 135000 / 2 * 10000 / 10000 / 10000 => 6.75
            assert!(pool::get_vault_balance(pool) == 997867,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 4+1,545);
            assert!(pool::get_spread_profit(pool) == 157+6,546);

        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,136000);
            oracle::update_price_for_testing(&mut state,sb,800,135,test_scenario::ctx(tx));
            position::close_position(
                ps_id_1,
                0,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            // opening_price = 900
            // price = 1000

            // change = |opening_price - price|/opening_price => |900-800|/900 => 0.1111111111111111
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 800 * 1.5% => 12
            // close_buy_price: real_price+(spread/2)=> 800 + 12/2 => 806
            // close_sell_price: real_price-(spread/2)=> 800 - 12/2 => 794
            // real_open_price = 1000
            // lot = 100000+10000-20000 = 90000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 90000/10000 / 4  => 2250
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_1);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 2250,403);
            assert!(position::get_size<SCALE>(position) == 1*90000,402);
            assert!(position::get_offset(position) == 1,404);
            assert!(position::get_leverage(position) == 4,405);
            assert!(position::get_margin_balance(position) == 0,406);
            assert!(position::get_type(position) == 1,407);
            assert!(position::get_status(position) == 2,408);
            assert!(position::get_direction(position) == 1,409);
            assert!(position::get_lot(position) == 90000,410);
            assert!(position::get_open_price(position) == 1007,411);
            assert!(position::get_open_spread(position) == 150000,412);
            assert!(position::get_open_real_price(position) == 1000,413);
            assert!(position::get_close_price(position) == 806,414);
            assert!(position::get_close_spread(position) == 120000,415);
            assert!(position::get_close_real_price(position) == 800,416);
            // pl = fund_size - old_fund_size
            // => (sell_price - open_real_price) * size * (lot/DENOMINATOR128) => (794 - 1000) * 1 * (90000/10000) => -1854
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 1854,417);
            assert!(i64::is_negative(profit) == true,417);
            assert!(position::get_stop_surplus_price(position) == 0,418);
            assert!(position::get_stop_loss_price(position) == 0,419);
            assert!(position::get_create_time(position) == 123000,420);
            assert!(position::get_close_time(position) == 136000,421);
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == owner,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 2,327);
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse cross position so balance = 9999 - 1  => 9995
            // bealance = balance + pl => 11965 - 1854 => 10111
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10111,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 1970-1854,529);
            assert!(i64::is_negative(p) == false,530);
            assert!(account::get_margin_total(&account) == 2178,531);
            assert!(account::get_margin_cross_total(&account) == 2178,532);
            assert!(account::get_margin_used(&account) == 2178,533);
            assert!(account::get_margin_isolated_total(&account) == 0,534);
            assert!(account::get_margin_cross_buy_total(&account) == 0,535);
            assert!(account::get_margin_cross_sell_total(&account) == 2178,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,539);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,541);
            assert!(market::get_short_position_total(market) == 10890,542);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            assert!(pool::get_vault_balance(pool) == 997867+1854,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 5,545);
            assert!(pool::get_spread_profit(pool) == 163,546);
        };
        test_scenario::next_tx(tx,owner);
        {
            let ps_new_2 = position::close_position(
                ps_id_2,
                40000,
                &state,
                &mut account,
                &mut list,
                &c,
                test_scenario::ctx(tx),
            );
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // opening_price = 900
            // open_price = fund_size / size => (10 * 1000 + 1 * 900) / 11 => 990
            // change = |opening_price - price|/opening_price => |800-990|/800 => 0.23
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 990 * 1.5% => 14.85
            // open_buy_price: real_price+(spread/2)=> 990 + 14/2 => 997
            // open_sell_price: real_price - (spread/2)=> 990 - 14/2 => 982
            // price = 800
            // change = |opening_price - price|/opening_price => |900-800|/900 => 0.1111111111111111
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 800 * 1.5% => 12
            // close_buy_price: real_price+(spread/2)=> 800 + 12/2 => 806
            // close_sell_price: real_price-(spread/2)=> 800 - 12/2 => 794
            // lot = 100000+10000-20000 = 90000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 990 * 1 * 40000/10000 / 5  => 792
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_new_2),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_new_2);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 792,403);
            assert!(position::get_size<SCALE>(position) == 1*40000,402);
            assert!(position::get_offset(position) == 2,404);
            assert!(position::get_leverage(position) == 5,405);
            assert!(position::get_margin_balance(position) == 0,406);
            assert!(position::get_type(position) == 1,407);
            assert!(position::get_status(position) == 5,408);
            assert!(position::get_direction(position) == 2,409);
            assert!(position::get_lot(position) == 40000,410);
            assert!(position::get_open_price(position) == 982,411);
            assert!(position::get_open_spread(position) == 148500,412);
            assert!(position::get_open_real_price(position) == 990,413);
            assert!(position::get_close_price(position) == 794,414);
            assert!(position::get_close_spread(position) == 120000,415);
            assert!(position::get_close_real_price(position) == 800,416);
            // pl = fund_size - old_fund_size
            // => (open_real_price - buy_price) * size * (lot/DENOMINATOR128) => (990 - 806) * 1 * (40000/10000) => 736
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 736,417);
            assert!(i64::is_negative(profit) == false,417);
            assert!(position::get_stop_surplus_price(position) == 0,418);
            assert!(position::get_stop_loss_price(position) == 0,419);
            assert!(position::get_create_time(position) == 123000,420);
            assert!(position::get_close_time(position) == 136000,421);
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == owner,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 2,327);
            // bealance = balance + pl => 10111 + 736 => 10847
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10847,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 116+736,529);
            assert!(i64::is_negative(p) == false,530);
            assert!(account::get_margin_total(&account) == 2178-792,531);
            assert!(account::get_margin_cross_total(&account) == 2178-792,532);
            assert!(account::get_margin_used(&account) == 2178-792,533);
            assert!(account::get_margin_isolated_total(&account) == 0,534);
            assert!(account::get_margin_cross_buy_total(&account) == 0,535);
            assert!(account::get_margin_cross_sell_total(&account) == 2178-792,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,539);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,541);
            assert!(market::get_short_position_total(market) == 10890 - (792*5),542);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            assert!(pool::get_vault_balance(pool) == 997867+1854-736,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 5,545);
            assert!(pool::get_spread_profit(pool) == 163,546);
        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,137000);
            oracle::update_price_for_testing(&mut state,sb,2000,137,test_scenario::ctx(tx));
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
            let market_id = object::id(market);
            // opening_price = 900
            // change = |opening_price - price|/opening_price => |900-2000|/900 => 1.2
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 2000 * 1.5% => 30
            // close_buy_price: real_price+(spread/2)=> 2000 + 30/2 => 2015
            // close_sell_price: real_price-(spread/2)=> 2000 - 30/2 => 1985
            // lot = 100000+10000-40000 = 70000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 990 * 1 * 70000/10000 / 5  => 1386
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_2),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_2);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 1386,403);
            assert!(position::get_size<SCALE>(position) == 1*70000,402);
            assert!(position::get_offset(position) == 2,404);
            assert!(position::get_leverage(position) == 5,405);
            assert!(position::get_margin_balance(position) == 0,406);
            assert!(position::get_type(position) == 1,407);
            assert!(position::get_status(position) == 2,408);
            assert!(position::get_direction(position) == 2,409);
            assert!(position::get_lot(position) == 70000,410);
            assert!(position::get_open_price(position) == 982,411);
            assert!(position::get_open_spread(position) == 148500,412);
            assert!(position::get_open_real_price(position) == 990,413);
            assert!(position::get_close_price(position) == 1985,414);
            assert!(position::get_close_spread(position) == 300000,415);
            assert!(position::get_close_real_price(position) == 2000,416);
            // pl = fund_size - old_fund_size
            // => (open_real_price - buy_price) * size * (lot/DENOMINATOR128) => (990 - 2015) * 1 * (70000/10000) => -7175
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 7175,417);
            assert!(i64::is_negative(profit) == true,417);
            assert!(position::get_stop_surplus_price(position) == 0,418);
            assert!(position::get_stop_loss_price(position) == 0,419);
            assert!(position::get_create_time(position) == 123000,420);
            assert!(position::get_close_time(position) == 137000,421);
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == owner,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 2,327);
            // debug::print(&account);
            assert!(account::get_balance(&account) == 10847-7175,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 6323,529);
            assert!(i64::is_negative(p) == true,530);
            assert!(account::get_margin_total(&account) == 0,531);
            assert!(account::get_margin_cross_total(&account) == 0,532);
            assert!(account::get_margin_used(&account) == 0,533);
            assert!(account::get_margin_isolated_total(&account) == 0,534);
            assert!(account::get_margin_cross_buy_total(&account) == 0,535);
            assert!(account::get_margin_cross_sell_total(&account) == 0,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == false ,539);
            // check market
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,541);
            assert!(market::get_short_position_total(market) == 0,542);
            let pool = market::get_pool(&list);
            // debug::print(pool);
            // vault_balance=997867+1854-736+7175=1006160
            assert!(pool::get_vault_balance(pool) == 1_000_000,543);
            assert!(pool::get_profit_balance(pool) == 6160,544);
            assert!(pool::get_insurance_balance(pool) == 5,545);
            assert!(pool::get_spread_profit(pool) == 163,546);
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
