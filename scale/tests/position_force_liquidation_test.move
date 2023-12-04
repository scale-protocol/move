#[test_only]
module scale::position_force_liquidation_tests {
    use scale::position_tests;
    use scale::market::{Self,Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
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
    fun test_force_liquidation(){
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
                2,
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
        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,137000);
            oracle::update_price_for_testing(&mut state,sb,800,137,test_scenario::ctx(tx));
            account::set_balance_for_testing(&mut account,6000,test_scenario::ctx(tx));
            position::force_liquidation(        
                ps_id_1,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx),
            );
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 2  => 5000
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_1);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 5000,403);
            assert!(position::get_size<SCALE>(position) == 1*100000,402);
            assert!(position::get_offset(position) == 1,404);
            assert!(position::get_leverage(position) == 2,405);
            assert!(position::get_margin_balance(position) == 0,406);
            assert!(position::get_type(position) == 1,407);
            assert!(position::get_status(position) == 3,408);
            assert!(position::get_direction(position) == 1,409);
            assert!(position::get_lot(position) == 100000,410);
            assert!(position::get_open_price(position) == 1007,411);
            assert!(position::get_open_spread(position) == 150000,412);
            assert!(position::get_open_real_price(position) == 1000,413);
            assert!(position::get_close_price(position) == 801,414);
            assert!(position::get_close_spread(position) == 24000,415);
            assert!(position::get_close_real_price(position) == 800,416);
            // pl = fund_size - old_fund_size
            // => (sell_price - open_real_price) * size * (lot/DENOMINATOR128) => (798 - 1000) * 1 * (100000/10000) => -2020
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 2020,417);
            assert!(i64::is_negative(profit) == true,417);
            assert!(position::get_stop_surplus_price(position) == 0,418);
            assert!(position::get_stop_loss_price(position) == 0,419);
            assert!(position::get_create_time(position) == 123000,420);
            assert!(position::get_close_time(position) == 137000,421);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == owner,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 2,327);
            // bealance = balance + pl => 6000 - 2020 => 3980
            // debug::print(&account);
            assert!(account::get_balance(&account) == 3980,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 2020,529);
            assert!(i64::is_negative(p) == true,530);
        };
        test_scenario::next_tx(tx,owner);
        {
            account::set_isolated_balance_for_testing(&mut account,2000,test_scenario::ctx(tx));
            clock::set_for_testing(&mut c,138000);
            oracle::update_price_for_testing(&mut state,sb,2000,138,test_scenario::ctx(tx));
            // let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            // let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            position::force_liquidation(        
                ps_id_2,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx),
            );
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 2  => 5000
            // assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            // let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            // let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
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
