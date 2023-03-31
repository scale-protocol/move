#[test_only]
module scale::position_close_tests {
    use scale::market::{Self, Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Scale};
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    use scale::i64;
    use oracle::oracle;
    use sui_coin::scale::{SCALE};
    use scale::position_tests::{Self as pt};


    #[test]
    fun test_close_position(){
        let (
            owner,
            scenario,
            market_id,
            _position_id,
            feed_id,
            account,
            scale_coin,
            list,
            root,
         ) = pt::get_test_ctx();
        let tx = &mut scenario;
        let position_id_1: ID;
        let position_id_2: ID;
        let position_id_3: ID;
        let position_id_4: ID;
        test_scenario::next_tx(tx,owner);
        {
            position_id_1 = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            position_id_2 = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,1,test_scenario::ctx(tx));
            position_id_3 = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,2,test_scenario::ctx(tx));
            position_id_4 = position::open_position<Scale,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,2,test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            // price increases
            oracle::update_price(&mut root,feed_id,2000,11234569,test_scenario::ctx(tx));
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),500);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            market::set_opening_price_for_testing(market, 900);
            position::close_position<Scale,SCALE>(market, &mut account, &root,position_id_1,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_1),501);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // opening_price = 900
            // price = 2000
            // change = |opening_price - price|/opening_price => |900-2000|/900 => 1.2222222222222223
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 2000 * 1.5% => 30
            // buy_price: real_price+(spread/2)=> 2000 + 30/2 => 2015
            // sell_price: real_price - (spread/2)=> 2000 - 30/2 => 1985
            assert!(position::get_margin<SCALE>(&position) == 50,502);
            assert!(position::get_size_value<SCALE>(&position) == 1,503);
            assert!(position::get_offset(&position) == 1,504);
            assert!(position::get_leverage(&position) == 2,505);
            assert!(position::get_margin_balance(&position) == 0,506);
            assert!(position::get_type(&position) == 1,507);
            assert!(position::get_status(&position) == 2,508);
            assert!(position::get_direction(&position) == 1,509);
            assert!(position::get_lot(&position) == 1000,510);
            assert!(position::get_open_price(&position) == 1007,511);
            assert!(position::get_open_spread(&position) == 150000,512);
            assert!(position::get_open_real_price(&position) == 1000,513);
            assert!(position::get_close_price(&position) == 2015,514);
            assert!(position::get_close_spread(&position) == 300000,515);
            assert!(position::get_close_real_price(&position) == 2000,516);
            // pl = (sell_price - open_real_price) * size * (lot/DENOMINATOR128) => (1985 - 1000) * 1 * (1000/10000) => 98.5
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 98,517);
            assert!(i64::is_negative(profit) == false,517);
            assert!(position::get_stop_surplus_price(&position) == 0,518);
            assert!(position::get_stop_loss_price(&position) == 0,519);
            assert!(position::get_create_time(&position) == 0,520);
            assert!(position::get_close_time(&position) == 0,521);
            assert!(position::get_validity_time(&position) == 0,522);
            assert!(*position::get_open_operator(&position) == owner,523);
            assert!(*position::get_close_operator(&position) == owner,524);
            assert!(*position::get_market_id(&position) == market_id,525);
            assert!(*position::get_account_id(&position) == object::id(&account),526);
            // check account
            assert!(account::get_offset(&account) == 4,527);
            // balance = 5998
            // balance = balance + pl => 5998 + 98.5 => 6096
            assert!(account::get_balance(&account) == 6096,528);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 98,529);
            assert!(i64::is_negative(p) == false,530);

            assert!(account::get_margin_total(&account) == 4050,531);
            assert!(account::get_margin_cross_total(&account) == 50,532);
            assert!(account::get_margin_used(&account) == 50,533);
            assert!(account::get_margin_isolated_total(&account) == 4000,534);
            assert!(account::get_margin_cross_buy_total(&account) == 0,535);
            assert!(account::get_margin_cross_sell_total(&account) == 50,536);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,537);
            assert!(account::get_margin_isolated_sell_total(&account) == 2000,538);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(!account::contains_pfk(&account,&pfk) == true ,539);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),540);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 10000,541);
            assert!(market::get_short_position_total(market) == 10100,542);
            let pool = market::get_pool(market);
            // check pool
            // 99860 - 98 = 99762
            assert!(pool::get_vault_balance(pool) == 99762,543);
            assert!(pool::get_profit_balance(pool) == 0,544);
            assert!(pool::get_insurance_balance(pool) == 2,545);
            assert!(pool::get_spread_profit(pool) == 140,546);

            test_scenario::return_to_sender(tx,position);
        };
        test_scenario::next_tx(tx,owner);
        {
            oracle::update_price(&mut root,feed_id,1100,11234789,test_scenario::ctx(tx));
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),600);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);

            position::close_position<Scale,SCALE>(market, &mut account, &root,position_id_4,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_4),601);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // opening_price = 900
            // price = 1100
            // change = |opening_price - price|/opening_price => |900-1100|/900 => 0.2222
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1100 * 1.5% => 1100 * 0.015 => 16.5
            // buy_price: real_price+(spread/2)=> 1100 + 16/2 => 1108
            // sell_price: real_price - (spread/2)=> 1100 - 16/2 => 1092 , Due to computational accuracy issues, the actual value may be 1091.75
            assert!(position::get_margin<SCALE>(&position) == 2000,602);
            assert!(position::get_size_value<SCALE>(&position) == 1,603);
            assert!(position::get_offset(&position) == 4,604);
            assert!(position::get_leverage(&position) == 5,605);
            assert!(position::get_margin_balance(&position) == 0,606);
            assert!(position::get_type(&position) == 2,607);
            assert!(position::get_status(&position) == 2,608);
            assert!(position::get_direction(&position) == 2,609);
            assert!(position::get_lot(&position) == 100000,610);
            assert!(position::get_open_price(&position) == 992,611);
            assert!(position::get_open_spread(&position) == 150000,612);
            assert!(position::get_open_real_price(&position) == 1000,613);
            assert!(position::get_close_price(&position) == 1091,614);
            assert!(position::get_close_spread(&position) == 165000,615);
            assert!(position::get_close_real_price(&position) == 1100,616);
            // pl = (open_real_price - buy_price) * size * (lot/DENOMINATOR128) => (1000 - 1108) * 1 * (100000/10000)=> -108 * 1 * 10 => -1080
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 1080,617);
            assert!(i64::is_negative(profit) == true,6117);
            assert!(position::get_stop_surplus_price(&position) == 0,618);
            assert!(position::get_stop_loss_price(&position) == 0,619);
            assert!(position::get_create_time(&position) == 0,620);
            assert!(position::get_close_time(&position) == 0,621);
            assert!(position::get_validity_time(&position) == 0,622);
            assert!(*position::get_open_operator(&position) == owner,623);
            assert!(*position::get_close_operator(&position) == owner,624);
            assert!(*position::get_market_id(&position) == market_id,625);
            assert!(*position::get_account_id(&position) == object::id(&account),626);
            // check account
            assert!(account::get_offset(&account) == 4,627);
            // balance = 6096
            // balance = balance + (margin + pl) => 6096 + (2000 - 1080) => 7016
            assert!(account::get_balance(&account) == 7016,628);
            // total_profit = total_profit + pl => 98 + -1080 => -982
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 982,629);
            assert!(i64::is_negative(p) == true,630);

            assert!(account::get_margin_total(&account) == 2050,631);
            assert!(account::get_margin_cross_total(&account) == 50,632);
            assert!(account::get_margin_used(&account) == 50,533);
            assert!(account::get_margin_isolated_total(&account) == 2000,634);
            assert!(account::get_margin_cross_buy_total(&account) == 0,635);
            assert!(account::get_margin_cross_sell_total(&account) == 50,636);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,637);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,638);
            assert!(account::contains_isolated_position_id(&account,&position_id_4) == false ,639);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),640);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 10000,641);
            // fund_size = margin * leverage => 2000 * 5 => 10000
            // total = 10100 - 10000 => 100
            assert!(market::get_short_position_total(market) == 100,642);
            let pool = market::get_pool(market);
            // check pool
            // 99762 + 1080 - 80 = 100762
            // because the vault supply is 100000 , so profit_balance = 762 ,vault_balance = 100000
            assert!(pool::get_vault_balance(pool) == 100000,643);
            assert!(pool::get_profit_balance(pool) == 762,644);
            assert!(pool::get_insurance_balance(pool) == 2,645);
            // spread_profit = (lot/DENOMINATOR128) * size * (spread / market::get_denominator() / 2) = 10 * (165000 / 10000 / 2) = 80
            // total = 140 + 80 = 220
            assert!(pool::get_spread_profit(pool) == 220,646);

            test_scenario::return_to_sender(tx,position);
        };
        // falling prices
        test_scenario::next_tx(tx,owner);
        {
            oracle::update_price(&mut root,feed_id,900,11235569,test_scenario::ctx(tx));
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),700);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            market::set_opening_price_for_testing(market, 990);
            position::close_position<Scale,SCALE>(market, &mut account, &root,position_id_2,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_2),701);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // opening_price = 990
            // price = 900
            // change = |opening_price - price|/opening_price => |990-900|/990 => 0.090
            // spread_fee => because change < 10% so spread_fee is 9/1000 => 0.009
            // spread = 900 * 0.009 => 8.1
            // buy_price: real_price+(spread/2)=> 900 + 8/2 => 904
            // sell_price: real_price - (spread/2)=> 900*10000 - 40500/2 => 895
            assert!(position::get_margin<SCALE>(&position) == 2000,702);
            assert!(position::get_size_value<SCALE>(&position) == 1,703);
            assert!(position::get_offset(&position) == 2,704);
            assert!(position::get_leverage(&position) == 5,705);
            assert!(position::get_margin_balance(&position) == 0,706);
            assert!(position::get_type(&position) == 2,707);
            assert!(position::get_status(&position) == 2,708);
            assert!(position::get_direction(&position) == 1,709);
            assert!(position::get_lot(&position) == 100000,710);
            assert!(position::get_open_price(&position) == 1007,711);
            assert!(position::get_open_spread(&position) == 150000,712);
            assert!(position::get_open_real_price(&position) == 1000,713);
            assert!(position::get_close_price(&position) == 904,714);
            assert!(position::get_close_spread(&position) == 81000,715);
            assert!(position::get_close_real_price(&position) == 900,716);
            // pl = (shell_price - open_real_price) * size * (lot/DENOMINATOR128) => (895 - 1000) * 1 * (100000/10000) = -1050
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 1050,717);
            assert!(i64::is_negative(profit) == true,7117);
            assert!(position::get_stop_surplus_price(&position) == 0,718);
            assert!(position::get_stop_loss_price(&position) == 0,719);
            assert!(position::get_create_time(&position) == 0,720);
            assert!(position::get_close_time(&position) == 0,721);
            assert!(position::get_validity_time(&position) == 0,722);
            assert!(*position::get_open_operator(&position) == owner,723);
            assert!(*position::get_close_operator(&position) == owner,724);
            assert!(*position::get_market_id(&position) == market_id,725);
            assert!(*position::get_account_id(&position) == object::id(&account),726);
            // check account
            assert!(account::get_offset(&account) == 4,727);
            // balance = 7016
            // balance = balance + (margin + pl) => 7016 + (2000 - 1050) => 7976
            assert!(account::get_balance(&account) == 7966,728);
            // total_profit = total_profit + pl => -982 + -1050 => -2032
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 2032,729);
            assert!(i64::is_negative(p) == true,730);

            assert!(account::get_margin_total(&account) == 50,731);
            assert!(account::get_margin_cross_total(&account) == 50,732);
            assert!(account::get_margin_used(&account) == 50,733);
            assert!(account::get_margin_isolated_total(&account) == 0,734);
            assert!(account::get_margin_cross_buy_total(&account) == 0,735);
            assert!(account::get_margin_cross_sell_total(&account) == 50,736);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,737);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,738);
            assert!(account::contains_isolated_position_id(&account,&position_id_2) == false ,739);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),740);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,741);
            assert!(market::get_short_position_total(market) == 100,742);
            let pool = market::get_pool(market);
            // check pool
            // size = 1 * 100000 / 10000 = 10
            // spread_profit = size * (spread / market::get_denominator() / 2) = 10 * (81000 / 10000 / 2) = 40.5
            // profit_balance = 762 + 1050 - 40  = 1772
            assert!(pool::get_vault_balance(pool) == 100000,743);
            assert!(pool::get_profit_balance(pool) == 1772,744);
            assert!(pool::get_insurance_balance(pool) == 2,745);
            // total = 220 + 40 = 260
            assert!(pool::get_spread_profit(pool) == 260,746);

            test_scenario::return_to_sender(tx,position);
        };
        test_scenario::next_tx(tx,owner);
        {
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),800);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            position::close_position<Scale,SCALE>(market, &mut account, &root,position_id_3,test_scenario::ctx(tx));
            assert!(!dof::exists_(account::get_uid<SCALE>(&account),position_id_3),801);
        };
        test_scenario::next_tx(tx,owner);
        {
            let position = test_scenario::take_from_sender<Position<SCALE>>(tx);
            // debug::print(&position);
            // opening_price = 990
            // price = 900
            // change = |opening_price - price|/opening_price => |990-900|/990 => 0.090
            // spread_fee => because change < 10% so spread_fee is 9/1000 => 0.009
            // spread = 900 * 90 => 81000
            // buy_price: (real_price+(spread/2))/10000=> (900*10000 + 81000/2)/10000 => 904
            // sell_price: (real_price - (spread/2))/10000=> (900*10000 - 81000/2)/10000 => 895
            assert!(position::get_margin<SCALE>(&position) == 50,802);
            assert!(position::get_size_value<SCALE>(&position) == 1,803);
            assert!(position::get_offset(&position) == 3,804);
            assert!(position::get_leverage(&position) == 2,805);
            assert!(position::get_margin_balance(&position) == 0,806);
            assert!(position::get_type(&position) == 1,807);
            assert!(position::get_status(&position) == 2,808);
            assert!(position::get_direction(&position) == 2,809);
            assert!(position::get_lot(&position) == 1000,810);
            assert!(position::get_open_price(&position) == 992,811);
            assert!(position::get_open_spread(&position) == 150000,812);
            assert!(position::get_open_real_price(&position) == 1000,813);
            assert!(position::get_close_price(&position) == 895,814);
            assert!(position::get_close_spread(&position) == 81000,815);
            assert!(position::get_close_real_price(&position) == 900,816);
            // pl = (open_real_price - buy_price) * size * (lot/DENOMINATOR128) => (1000 - 904) * 1 * (1000/DENOMINATOR128) => 10
            let profit = position::get_profit(&position);
            assert!(i64::get_value(profit) == 10,817);
            assert!(i64::is_negative(profit) == false,8117);
            assert!(position::get_stop_surplus_price(&position) == 0,818);
            assert!(position::get_stop_loss_price(&position) == 0,819);
            assert!(position::get_create_time(&position) == 0,820);
            assert!(position::get_close_time(&position) == 0,821);
            assert!(position::get_validity_time(&position) == 0,822);
            assert!(*position::get_open_operator(&position) == owner,823);
            assert!(*position::get_close_operator(&position) == owner,824);
            assert!(*position::get_market_id(&position) == market_id,825);
            assert!(*position::get_account_id(&position) == object::id(&account),826);
            // check account
            assert!(account::get_offset(&account) == 4,827);
            // balance = 7966
            // balance = balance + pl => 7966 + 10 => 7976
            assert!(account::get_balance(&account) == 7976,828);
            // total_profit = total_profit + pl => -2032 + 10 => -2022
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 2022,829);
            assert!(i64::is_negative(p) == true,830);

            assert!(account::get_margin_total(&account) == 0,831);
            assert!(account::get_margin_cross_total(&account) == 0,832);
            assert!(account::get_margin_used(&account) == 0,833);
            assert!(account::get_margin_isolated_total(&account) == 0,834);
            assert!(account::get_margin_cross_buy_total(&account) == 0,835);
            assert!(account::get_margin_cross_sell_total(&account) == 0,836);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,837);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,838);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(!account::contains_pfk(&account,&pfk) == true ,839);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),840);
            let market: &mut Market<Scale,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 0,841);
            assert!(market::get_short_position_total(market) == 0,842);
            let pool = market::get_pool(market);
            // check pool
            // size = 1 * 1000 / 10000 = 0.1
            // spread_profit = size * (spread / market::get_denominator() / 2) = 0.1 * (81000 / 10000 / 2) = 0.405
            // profit_balance = 1772 - 10 - 0  = 1762
            assert!(pool::get_vault_balance(pool) == 100000,843);
            assert!(pool::get_profit_balance(pool) == 1762,844);
            assert!(pool::get_insurance_balance(pool) == 2,845);
            // total = 260 + 0 = 260
            assert!(pool::get_spread_profit(pool) == 260,846);

            test_scenario::return_to_sender(tx,position);
        };
        pt::drop_test_ctx(
            scenario,
            account,
            scale_coin,
            list,
            root,
        );
    }
}