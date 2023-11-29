#[test_only]
module scale::position_force_liquidation_tests {
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
    use std::debug;
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
        ) = position_tests::get_test_ctx<Scale,SCALE>();
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
            // ps_id_2 = position::open_position(
            //     sb,
            //     100000,
            //     2,
            //     2,
            //     2,
            //     0,
            //     0,
            //     0,
            //     &mut list,
            //     &mut account,
            //     &state,
            //     &c,
            //     test_scenario::ctx(tx)
            // );
        };
        test_scenario::next_tx(tx,owner);
        {
            clock::set_for_testing(&mut c,137000);
            oracle::update_price_for_testing(&mut state,sb,100,137,test_scenario::ctx(tx));
            account::set_balance_for_testing(&mut account,4000,test_scenario::ctx(tx));
            position::force_liquidation(        
                ps_id_1,
                &mut list,
                &mut account,
                &state,
                &c,
                test_scenario::ctx(tx),
            );
            // opening_price = 900
            // price = 100
            // change = |opening_price - price|/opening_price => |900-100|/900 => 11.11%
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007
            // sell_price: real_price-(spread/2)=> 1000 - 15/2 => 993
            // real_open_price = 1000
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 5  => 2000
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),symbol);
            let market_id = object::id(market);
            // let price = market::get_price(market,&state,&c);
            // debug::print(&price);
            assert!(dof::exists_(account::get_uid<SCALE>(&account),ps_id_1),501);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),ps_id_1);
            // debug::print(position);
            assert!(position::get_margin<SCALE>(position) == 2000,403);
            assert!(position::get_size<SCALE>(position) == 1*100000,402);
            assert!(position::get_offset(position) == 1,404);
            assert!(position::get_leverage(position) == 5,405);
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
            account::set_isolated_balance_for_testing(&mut account,100,test_scenario::ctx(tx));
            // clock::set_for_testing(&mut c,137000);
            // oracle::update_price_for_testing(&mut state,sb,800,137,test_scenario::ctx(tx));
            // position::burst_position(        
            //     ps_id_2,
            //     &mut list,
            //     &mut account,
            //     &state,
            //     &c,
            //     test_scenario::ctx(tx),
            // );
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
//     use scale::market::{Self, Market};
//     use scale::pool;
//     use scale::account::{Self};
//     use scale::position::{Self,Position};
//     use scale::pool::{Scale};
//     use sui::test_scenario::{Self};
//     use sui::dynamic_object_field as dof;
//     use sui::object::{ID};
//     // use std::debug;
//     use oracle::oracle;
//     use sui::test_utils;
//     use sui_coin::scale::{SCALE};
//     use scale::position_tests::{Self as pt};

//     #[test]
//     fun test_burst_position(){
//         let (
//             owner,
//             scenario,
//             market_id,
//             _position_id,
//             feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//         ) = pt::get_test_ctx();
//         let tx = &mut scenario;
//         let position_id :ID;
//         test_scenario::next_tx(tx,owner);
//         {
//             let total_liquidity = pool::get_total_liquidity(market::get_pool(&list));
//             let market: &mut Market  = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//             let _price = market::get_price(market,&state);
//             // debug::print(&price);

//             let _fund_fee = market::get_fund_fee(market,total_liquidity);
//             // debug::print(&fund_fee);
            
//             let _price_new = market::get_price_by_real(market,780);
//             // debug::print(&price_new);

//             position_id = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,1000,2,1,1,test_scenario::ctx(tx));
//             assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),1);
//             assert!(dof::exists_(oracle::get_uid(&state),feed_id),2);
//             oracle::update_price(&mut state,feed_id,780,112345678,test_scenario::ctx(tx));

//             // pl = (sell_price - open_real_price) * (lot / DENOMINATOR128) * size =>(778 - 1000) * 1000/10000 * 1 => -22.2
//             account::set_balance_for_testing(&mut account, 40, test_scenario::ctx(tx));
//             test_utils::print(b"print account info");
//             // debug::print(&account);
//             let _equity = position::get_equity<Scale,SCALE>(&list,&account,&state);
//             // debug::print(&equity);
//             assert!(account::get_balance(&account) == 40,3);
//             // balance = 40 - 0 = 0
//             // equity = balance + pl + fund => 40 - 22 + 0 = 18
//             // margin_used = 50
//             // equity / margin_used < 50% then close position => 18 / 50 < 0.5 => true
//             position::burst_position<Scale,SCALE>(&mut list, &mut account, &state,position_id,test_scenario::ctx(tx));
//         };
//         test_scenario::next_tx(tx,owner);
//         {
//             let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
//             assert!(position::get_status(&position) == 3,100);
//             test_scenario::return_to_sender(tx,position);
//         };
//         pt::drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
// }