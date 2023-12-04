#[test_only]
 module scale::position_process_fund_fee_tests{
    use scale::position_tests;
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::ID;
    // use std::debug;
    use sui_coin::scale::{SCALE};
    use std::string;
    #[test]
    fun test_process_fund_fee(){
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
        let ps_id_3:ID;
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
            ps_id_3 = position::open_position(
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
            position::process_fund_fee(        
                &mut list,
                &mut account,
                test_scenario::ctx(tx),
            );
            // total_liquidity = 1_000_000
            // long_position_total = 10000
            // short_position_total = 20000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 2  => 5000
            // let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_2),502);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_3),503);
            // let ps1: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_1);
            // fund_fee => 20000/1_000_000 = 0.02 =2% so fee = 3/10000
            // i64::new(max * market::get_fund_fee(market,total_liquidity) * fund_size / (DENOMINATOR * min),false)
            // buy < sell, so buy position fund fee is : 
            // => (short_position_total * fund_fee / long_position_tota)l * fund_size
            // => (20000 * 3/10000 / 10000) * 100000 = 6
            // sell position fund fee is :
            // ==> fund_size * fund_fee
            // ==> 10000 * 3/10000 = 3
            let ps2: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_2);
            let ps3: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_3);
            // debug::print(&account);
            // insurance_balance = 2 
            assert!(account::get_balance(&account)==10000+6-2,504);
            assert!(account::get_isolated_balance(&account)==20000-5000-5000-2-2,504);
            assert!(position::get_margin_balance(ps2)==5000-3,505);
            assert!(position::get_margin_balance(ps3)==5000-3,505);
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