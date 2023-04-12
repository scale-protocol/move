// #[test_only]
// module scale::burst_position_tests {
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
//             root,
//         ) = pt::get_test_ctx();
//         let tx = &mut scenario;
//         let position_id :ID;
//         test_scenario::next_tx(tx,owner);
//         {
//             let total_liquidity = pool::get_total_liquidity(market::get_pool(&list));
//             let market: &mut Market  = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//             let _price = market::get_price(market,&root);
//             // debug::print(&price);

//             let _fund_fee = market::get_fund_fee(market,total_liquidity);
//             // debug::print(&fund_fee);
            
//             let _price_new = market::get_price_by_real(market,780);
//             // debug::print(&price_new);

//             position_id = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
//             assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),1);
//             assert!(dof::exists_(oracle::get_uid(&root),feed_id),2);
//             oracle::update_price(&mut root,feed_id,780,112345678,test_scenario::ctx(tx));

//             // pl = (sell_price - open_real_price) * (lot / DENOMINATOR128) * size =>(778 - 1000) * 1000/10000 * 1 => -22.2
//             account::set_balance_for_testing(&mut account, 40, test_scenario::ctx(tx));
//             test_utils::print(b"print account info");
//             // debug::print(&account);
//             let _equity = position::get_equity<Scale,SCALE>(&list,&account,&root);
//             // debug::print(&equity);
//             assert!(account::get_balance(&account) == 40,3);
//             // balance = 40 - 0 = 0
//             // equity = balance + pl + fund => 40 - 22 + 0 = 18
//             // margin_used = 50
//             // equity / margin_used < 50% then close position => 18 / 50 < 0.5 => true
//             position::burst_position<Scale,SCALE>(&mut list, &mut account, &root,position_id,test_scenario::ctx(tx));
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
//             root,
//         );
//     }
// }