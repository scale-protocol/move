// #[test_only]
// module scale::position_tests {
//     use scale::market::{Self, MarketList, Market};
//     use scale::account::{Self,Account};
//     use scale::position;
//     use scale::pool::{Self,Scale};
//     use sui::test_scenario::{Self,Scenario};
//     use sui::dynamic_object_field as dof;
//     use sui::object::{Self,ID};
//     use sui::coin::{Self,Coin};
//     use oracle::oracle;
//     use scale::i64;
//     use sui_coin::scale::{SCALE};

//     struct TestContext<phantom P, phantom T> {
//         owner: address,
//         scenario: Scenario,
//         market_id: ID,
//         position_id: ID,
//         feed_id: ID,
//         account: Account<SCALE>,
//         scale_coin: Coin<SCALE>,
//         list: MarketList<P,T>,
//         state: oracle::State,
//     }

//     public fun get_test_ctx<P,T>(): (address,Scenario,ID,ID,ID,Account<SCALE>,Coin<SCALE>,MarketList<P,T>,oracle::State) {
//         let owner = @0x1;
//         let test_tx = test_scenario::begin(owner);
//         let tx = &mut test_tx;
//         let market_id: ID;
//         let feed_id: ID;
//         let scale_coin: Coin<SCALE>;
//         scale_coin =  coin::mint_for_testing<SCALE>(100_0000,test_scenario::ctx(tx));
//         test_scenario::next_tx(tx,owner);
//         {
//             // market init
//             market::create_market_list(&scale_coin,test_scenario::ctx(tx));
//             oracle::init_for_testing(test_scenario::ctx(tx));
//         };
//         test_scenario::next_tx(tx,owner);
//         let state = test_scenario::take_shared<oracle::State>(tx);
//         let oracle_admin = test_scenario::take_from_sender<oracle::AdminCap>(tx);
//         let list = test_scenario::take_shared<MarketList<P,T>>(tx);
//         let ctx = test_scenario::ctx(tx);
//         feed_id = oracle::create_price_feed_for_testing(&mut oracle_admin,&mut state,b"BTC/USD",ctx);
//         oracle::update_price(&mut state,feed_id,1000,11234567,ctx);
//         let n = b"BTC/USD";
//         let d = b"BTC/USD testing";
//         let i = b"https://bin.bnbstatic.com/image/admin_mgs_image_upload/20201110/87496d50-2408-43e1-ad4c-78b47b448a6a.png";
//         market_id = market::create_market(&mut list,n,i,d,1u64,800u64,feed_id,ctx);
//         account::create_account(&scale_coin,ctx);

//         test_scenario::next_tx(tx,owner);
//         let account = test_scenario::take_shared<Account<SCALE>>(tx);
//         // deposit
//         account::deposit(&mut account,coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx)),0,test_scenario::ctx(tx));
//         // add liquidity
//         assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//         let market: &mut Market = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//         let lsp_coin = pool::add_liquidity_for_testing<P,T>(market::get_pool_mut_for_testing<P,T>(&mut list),coin::mint_for_testing<T>(100000,test_scenario::ctx(tx)),test_scenario::ctx(tx));
//         coin::burn_for_testing(lsp_coin);
//         test_scenario::return_to_sender(tx,oracle_admin);

//         (
//             owner,
//             test_tx,
//             market_id,
//             object::id_from_address(@0x1),
//             feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//         )
//     }

//     public fun drop_test_ctx<P,T>(
//         scenario: Scenario,
//         account: Account<SCALE>,
//         scale_coin: Coin<SCALE>,
//         list: MarketList<P,T>,
//         state: oracle::State,
//     ) {
//         test_scenario::return_shared(list);
//         test_scenario::return_shared(account);
//         test_scenario::return_shared(state);
//         coin::burn_for_testing(scale_coin);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 610, location = position)]
//     fun test_risk_assertion(){
//         let (
//             owner,
//             scenario,
//             market_id,
//             _position_id,
//             _feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//          ) = get_test_ctx<Scale,SCALE>();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//             let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//             // pre_exposure = 0
//             // exposure = 0
//             // liquidity_total = 100000
//             position::risk_assertion_for_testing(&list,market,1000,1,0);
//             market::set_long_position_total_for_testing(market,80000);
//             market::set_short_position_total_for_testing(market,1000);
//             // pre_exposure = 0
//             // exposure = 80000 - 1000 = 79000
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);
//             position::risk_assertion_for_testing(&list,market,1000,1,79001);
//             position::risk_assertion_for_testing(&list,market,1000,1,78999);
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
//     #[test]
//     #[expected_failure(abort_code = 612, location = position)]
//     fun test_risk_assertion_fund_size(){
//         let (
//             owner,
//             scenario,
//             market_id,
//             _position_id,
//             _feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//         ) = get_test_ctx<Scale,SCALE>();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//             let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//             // pre_exposure = 0
//             // exposure = 0
//             // liquidity_total = 100000
//             position::risk_assertion_for_testing(&list,market,1000,1,0);
//             market::set_long_position_total_for_testing(market,80000);
//             market::set_short_position_total_for_testing(market,1000);
//             // pre_exposure = 0
//             // exposure = 80000 - 1000 = 79000
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);
//             position::risk_assertion_for_testing(&list,market,1000,1,90000);
//             position::risk_assertion_for_testing(&list,market,19999,1,90000);
//             position::risk_assertion_for_testing(&list,market,0,1,90000);
//             position::risk_assertion_for_testing(&list,market,20000,1,90000);
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
//     #[test]
//     #[expected_failure(abort_code = 613, location = position)]
//     fun test_risk_assertion_direction(){
//         let (
//             owner,
//             scenario,
//             market_id,
//             _position_id,
//             _feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//         ) = get_test_ctx<Scale,SCALE>();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//             let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//             // pre_exposure = 0
//             // exposure = 0
//             // liquidity_total = 100000
//             market::set_long_position_total_for_testing(market,0);
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);

//             market::set_short_position_total_for_testing(market,100);
//             position::risk_assertion_for_testing(&list,market,1000,2,80000);

//             market::set_long_position_total_for_testing(market,2000);
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);

//             market::set_short_position_total_for_testing(market,3000);
//             position::risk_assertion_for_testing(&list,market,1000,2,80000);

//             market::set_long_position_total_for_testing(market,140000);
//             market::set_short_position_total_for_testing(market,130000);
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);
//             position::risk_assertion_for_testing(&list,market,1000,2,80000);

//             market::set_long_position_total_for_testing(market,149999);
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);

//             market::set_short_position_total_for_testing(market,149999);
//             position::risk_assertion_for_testing(&list,market,1000,2,80000);

//             market::set_long_position_total_for_testing(market,150000);
//             position::risk_assertion_for_testing(&list,market,1000,1,80000);

//             market::set_short_position_total_for_testing(market,150000);
//             position::risk_assertion_for_testing(&list,market,1000,2,80000);
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
//     #[test]
//     fun test_equity(){
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
//          ) = get_test_ctx();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             test_scenario::next_tx(tx,owner);
//             {
//                 // balance = 210000
//                 account::deposit(&mut account,coin::mint_for_testing<SCALE>(200000,test_scenario::ctx(tx)),0,test_scenario::ctx(tx));
//             };
//             test_scenario::next_tx(tx,owner);
//             {
//                 assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//                 // let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//                 // let price = market::get_price_by_real(market,1500);
//                 // debug::print(&price);
//                 // pl = (shell_price - open_real_price ) * size = (1488 - 1000) * (1000/10000) * 1 = 48.8
//                 // fund_fee = 0
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,1000,2,1,1,test_scenario::ctx(tx));
//                 // pl = (shell_price - open_real_price ) * size = (1488 - 1000) * (100000/10000) * 1 = 4880
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,100000,5,2,1,test_scenario::ctx(tx));
//                 // pl = (open_real_price - buy_price ) * size = (1000 - 1511) * (1000/10000) * 1 = -51.1
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,1000,2,1,2,test_scenario::ctx(tx));
//                 // pl = (open_real_price - buy_price ) * size = (1000 - 1511) * (100000/10000) * 1 = -5110
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,100000,5,2,2,test_scenario::ctx(tx));
//                 oracle::update_price(&mut state,feed_id,1500,11241569,test_scenario::ctx(tx));
//                 // debug::print(&account);
//                 // equity = balance + cross position pl = 205998 + 48 - 51 = 203995
//                 let equity = position::get_equity<Scale,SCALE>(&list,&account,&state);
//                 // debug::print(&equity);
//                 assert!(i64::get_value(&equity) == 205995,2);
//                 assert!(i64::is_negative(&equity) == false,3);
//             };
//             test_scenario::next_tx(tx,owner);
//             {
//                 // oracle::update_price(&mut state,feed_id,1000,11251569,test_scenario::ctx(tx));
//                 assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//                 // let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//                 // let price = market::get_price(market,&state);
//                 // debug::print(&price);
//                 // reset price , price => price = fund_size / size => (0.1*1000+0.1*1500) / 0.2 => 1250
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,1000,2,1,1,test_scenario::ctx(tx));
//                 // reset price , price => price = fund_size / size => (0.2 * 1250 + 10 * 1500) / 10.2 => 1495.09
//                 // pl = (shell_price - open_real_price ) * size = (798 - 1495) * (102000/10000) * 1 = -7109.4
//                 // fund_fee = 1495 * 10.2 * 3/10000 = 4.52
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,100000,5,1,1,test_scenario::ctx(tx));

//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,1000,2,1,2,test_scenario::ctx(tx));
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,30000,5,1,2,test_scenario::ctx(tx));
//                 // reset price , price = price = fund_size / size => (0.1 * 1000 + 7.1 * 1500) / 7.2  => 1493.05
//                 // pl = (open_real_price - buy_price ) * size = (1493 - 801) * 7.2 * 1 = 4982.4
//                 // fund_fee = 1493 * 7.2 * 3/10000 = -3.22
//                 position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,40000,5,1,2,test_scenario::ctx(tx));
//                 oracle::update_price(&mut state,feed_id,800,11261569,test_scenario::ctx(tx));
//             };
//             test_scenario::next_tx(tx,owner);
//             {
//                 assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//                 // let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//                 // let price = market::get_price_by_real(market,800);
//                 // equity = balance + cross position pl = 205997 - 7109 + 4 + 4982 - 3 = 203871
//                 let equity = position::get_equity<Scale,SCALE>(&list,&account,&state);
//                 // There is a calculation deviation, so the result is 203861,During actual use, the amount value is amplified to eliminate
//                 assert!(i64::get_value(&equity) == 203861,2);
//                 assert!(i64::is_negative(&equity) == false,3);
//             };
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
//     #[test]
//     #[expected_failure(abort_code = 616, location = position)]
//     fun test_check_margin_negative(){
//         let (
//             owner,
//             scenario,
//             _market_id,
//             _position_id,
//             _feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//          ) = get_test_ctx<Scale,SCALE>();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             let e = i64::new(100000,true);
//             position::check_margin<SCALE>(&account,&e);
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
//     #[test]
//     #[expected_failure(abort_code = 611, location = position)]
//     fun test_check_margin(){
//         let (
//             owner,
//             scenario,
//             _market_id,
//             _position_id,
//             _feed_id,
//             account,
//             scale_coin,
//             list,
//             state,
//          ) = get_test_ctx<Scale,SCALE>();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             let e = i64::new(100000,false);
//             account::inc_margin_cross_sell_total_for_testing(&mut account,1);
//             // balance = 10000
//             position::check_margin<SCALE>(&account,&e);

//             let e = i64::new(300,false);
//             account::inc_margin_cross_buy_total_for_testing(&mut account,500);
//             account::inc_margin_cross_sell_total_for_testing(&mut account,234);
//             position::check_margin<SCALE>(&account,&e);

//             let e = i64::new(250,false);
//             position::check_margin<SCALE>(&account,&e);

//             let e = i64::new(249,false);
//             position::check_margin<SCALE>(&account,&e);
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
//     // Value overflow test
//     #[test]
//     fun test_value_overflow(){
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
//          ) = get_test_ctx<Scale,SCALE>();
//         let tx = &mut scenario;
//         test_scenario::next_tx(tx,owner);
//         {
//             oracle::update_price(&mut state,feed_id,9_223_372_036_854_775_807/20000,222222222222,test_scenario::ctx(tx));
//             account::deposit(&mut account,coin::mint_for_testing<SCALE>((9_223_372_036_854_775_807 - 10000),test_scenario::ctx(tx)),0,test_scenario::ctx(tx));
//             // add liquidity
//             assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),1);
//             let market: &mut Market= dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
//             // 18446744073709551615
//             // 9223372036854775807
//             let lsp_coin = pool::add_liquidity_for_testing(market::get_pool_mut_for_testing(&mut list),coin::mint_for_testing<SCALE>((18446744073709551615 - 100000 -1 ),test_scenario::ctx(tx)),test_scenario::ctx(tx));
//             coin::burn_for_testing(lsp_coin);
//             let _position_id_new_2 = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &state,20000,5,1,2,test_scenario::ctx(tx));
//         };
//         drop_test_ctx(
//             scenario,
//             account,
//             scale_coin,
//             list,
//             state,
//         );
//     }
// }