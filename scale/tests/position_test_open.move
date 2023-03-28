#[test_only]
module scale::position_test_open_tests {
    use scale::market::{Self, Market};
    use scale::account::{Self};
    use scale::position::{Self,Position};
    use scale::pool::{Self,Tag};
    use sui::test_scenario::{Self};
    use sui::dynamic_object_field as dof;
    use sui::object::{Self,ID};
    use scale::i64;
    use scale::position_tests::{Self as pt};
    use sui_coin::scale::{SCALE};
    use std::debug;

    #[test]
    fun test_open_position(){
        let (
            owner,
            scenario,
            market_id,
            _position_id,
            _feed_id,
            account,
            scale_coin,
            list,
            root,
        ) = pt::get_test_ctx();
        let tx = &mut scenario;
        let position_id :ID;
        // test open cross position
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,1,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),1);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 1000/10000 / 2 => 50
            assert!(position::get_margin<SCALE>(position) == 50,103);
            assert!(position::get_size_value<SCALE>(position) == 1,1003);
            assert!(position::get_offset(position) == 1,104);
            assert!(position::get_leverage(position) == 2,105);
            assert!(position::get_margin_balance(position) == 0,106);
            assert!(position::get_type(position) == 1,107);
            assert!(position::get_status(position) == 1,108);
            assert!(position::get_direction(position) == 1,109);
            assert!(position::get_lot(position) == 1000,110);
            assert!(position::get_open_price(position) == 1007,111);
            assert!(position::get_open_spread(position) == 150000,112);
            assert!(position::get_open_real_price(position) == 1000,113);
            assert!(position::get_close_price(position) == 0,114);
            assert!(position::get_close_spread(position) == 0,115);
            assert!(position::get_close_real_price(position) == 0,116);
            let profit = position::get_profit(position);
            assert!(i64::get_value(profit) == 0,117);
            assert!(i64::is_negative(profit) == false,117);
            assert!(position::get_stop_surplus_price(position) == 0,118);
            assert!(position::get_stop_loss_price(position) == 0,119);
            assert!(position::get_create_time(position) == 0,120);
            assert!(position::get_close_time(position) == 0,121);
            assert!(position::get_validity_time(position) == 0,122);
            assert!(*position::get_open_operator(position) == owner,123);
            assert!(*position::get_close_operator(position) == @0x0,124);
            assert!(*position::get_market_id(position) == market_id,125);
            assert!(*position::get_account_id(position) == object::id(&account),126);
            // check account
            assert!(account::get_offset(&account) == 1,127);
            // deposit 1000 scale coin , balance = 10000
            // becouse  cross position so balance = 10000
            assert!(account::get_balance(&account) == 10000,128);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,129);
            assert!(i64::is_negative(p) == false,130);
            assert!(account::get_margin_total(&account) == 50,131);
            assert!(account::get_margin_cross_total(&account) == 50,132);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 0,134);
            assert!(account::get_margin_cross_buy_total(&account) == 50,135);
            assert!(account::get_margin_cross_sell_total(&account) == 0,136);
            assert!(account::get_margin_isolated_buy_total(&account) == 0,137);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,138);
            let pfk = account::new_PFK(market_id,object::id(&account),1);
            assert!(account::contains_pfk(&account,&pfk) == true ,139);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),140);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = buy_price * size * (lot / DENOMINATOR128) => 1007.5 * 1 * 1000/10000 => 100.75
            assert!(market::get_long_position_total(market) == 100,141);
            assert!(market::get_short_position_total(market) == 0,142);
            let pool = market::get_pool(market);
            assert!(pool::get_vault_balance(pool) == 100000,143);
            assert!(pool::get_profit_balance(pool) == 0,144);
            // insurance = position_fund_total * 5/10000 = 1007.5 * 1 * 1000/10000 * 5 / 10000 => 0.050375
            assert!(pool::get_insurance_balance(pool) == 0,145);
            assert!(pool::get_spread_profit(pool) == 0,146);
        };
        // test open isolated position
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,1,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),2);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(position);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * 100000/10000 / 5  => 2000
            assert!(position::get_margin<SCALE>(position) == 2000,203);
            assert!(position::get_size_value<SCALE>(position) == 1,2003);
            assert!(position::get_offset(position) == 2,204);
            assert!(position::get_leverage(position) == 5,205);
            assert!(position::get_margin_balance(position) == 2000,206);
            assert!(position::get_type(position) == 2,207);
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
            assert!(position::get_create_time(position) == 0,220);
            assert!(position::get_close_time(position) == 0,221);
            assert!(position::get_validity_time(position) == 0,222);
            assert!(*position::get_open_operator(position) == owner,223);
            assert!(*position::get_close_operator(position) == @0x0,224);
            assert!(*position::get_market_id(position) == market_id,225);
            assert!(*position::get_account_id(position) == object::id(&account),226);
            // check account
            assert!(account::get_offset(&account) == 2,227);
            // deposit 10000 scale coin , balance = 10000
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse isolated position so balance = 10000 - 2000 - 1  => 7999
            assert!(account::get_balance(&account) == 7999,228);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,229);
            assert!(i64::is_negative(p) == false,230);
            // total = 50 + 2000 => 2050
            assert!(account::get_margin_total(&account) == 2050,231);
            assert!(account::get_margin_cross_total(&account) == 50,232);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 2000,234);
            assert!(account::get_margin_cross_buy_total(&account) == 50,235);
            assert!(account::get_margin_cross_sell_total(&account) == 0,236);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,237);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,238);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,239);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),240);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = 50 * 2 + 2000 * 5 => 10100
            assert!(market::get_long_position_total(market) == 10100,241);
            assert!(market::get_short_position_total(market) == 0,242);
            let pool = market::get_pool(market);
            // debug::print(pool);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (100000/10000 * 1 * (15/2))
            // 100000 - spread_fee => 100000 - 70 => 99930
            assert!(pool::get_vault_balance(pool) == 99930,243);
            assert!(pool::get_profit_balance(pool) == 0,244);
            assert!(pool::get_insurance_balance(pool) == 1,245);
            assert!(pool::get_spread_profit(pool) == 70,246);
        };
        // test open cross position sell
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,1000,2,1,2,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),301);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * (1000/10000) / 2 => 50
            assert!(position::get_margin<SCALE>(position) == 50,303);
            assert!(position::get_size_value<SCALE>(position) == 1,3003);
            assert!(position::get_offset(position) == 3,304);
            assert!(position::get_leverage(position) == 2,305);
            assert!(position::get_margin_balance(position) == 0,306);
            assert!(position::get_type(position) == 1,307);
            assert!(position::get_status(position) == 1,308);
            assert!(position::get_direction(position) == 2,309);
            assert!(position::get_lot(position) == 1000,110);
            assert!(position::get_open_price(position) == 992,311);
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
            assert!(position::get_create_time(position) == 0,320);
            assert!(position::get_close_time(position) == 0,321);
            assert!(position::get_validity_time(position) == 0,322);
            assert!(*position::get_open_operator(position) == owner,323);
            assert!(*position::get_close_operator(position) == @0x0,324);
            assert!(*position::get_market_id(position) == market_id,325);
            assert!(*position::get_account_id(position) == object::id(&account),326);
            // check account
            assert!(account::get_offset(&account) == 3,327);
            // deposit 1000 scale coin , balance = 7999
            // becouse  cross position so balance = 7999
            assert!(account::get_balance(&account) == 7999,328);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,329);
            assert!(i64::is_negative(p) == false,330);
            assert!(account::get_margin_total(&account) == 2100,331);
            assert!(account::get_margin_cross_total(&account) == 100,332);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 2000,334);
            assert!(account::get_margin_cross_buy_total(&account) == 50,335);
            assert!(account::get_margin_cross_sell_total(&account) == 50,336);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,337);
            assert!(account::get_margin_isolated_sell_total(&account) == 0,338);
            let pfk = account::new_PFK(market_id,object::id(&account),2);
            assert!(account::contains_pfk(&account,&pfk) == true ,339);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),340);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            assert!(market::get_long_position_total(market) == 10100,341);
            assert!(market::get_short_position_total(market) == 100,342);
            let pool = market::get_pool(market);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (1000/10000 * 1 * 15/2) => 0.75
            // 99930 - spread_fee => 99930 - 0 => 99930
            assert!(pool::get_vault_balance(pool) == 99930,343);
            assert!(pool::get_profit_balance(pool) == 0,344);
            // insurance = position_fund_total * 5/10000 = real_price * size * (lot / DENOMINATOR128) * 5/10000 => 1000 * 1 * (1000/10000) * 5/10000 => 0.05
            assert!(pool::get_insurance_balance(pool) == 1,345);
            assert!(pool::get_spread_profit(pool) == 70,346);
        };
        // test open isolated position sell
        test_scenario::next_tx(tx,owner);
        {
            position_id = position::open_position<Tag,SCALE>(&mut list, market_id, &mut account, &root,100000,5,2,2,test_scenario::ctx(tx));
            debug::print_stack_trace();
            assert!(dof::exists_(account::get_uid<SCALE>(&account),position_id),401);
            let position: &Position<SCALE> = dof::borrow(account::get_uid<SCALE>(&account),position_id);
            // debug::print(position);
            // change = |opening_price-price|/opening_price => |800-1000|/800 => 0.25
            // spread_fee => because change > 10% so spread_fee is 1.5%
            // spread = 1000 * 1.5% => 15
            // buy_price: real_price+(spread/2)=> 1000 + 15/2 => 1007.5
            // sell_price: real_price - (spread/2)=> 1000 - 15/2 => 992.5
            // margin = real_price * size * (lot / DENOMINATOR128) / leverage => 1000 * 1 * (100000/10000) / 5 => 2000
            assert!(position::get_margin<SCALE>(position) == 2000,402);
            assert!(position::get_size_value<SCALE>(position) == 1,403);
            assert!(position::get_offset(position) == 4,404);
            assert!(position::get_leverage(position) == 5,405);
            assert!(position::get_margin_balance(position) == 2000,406);
            assert!(position::get_type(position) == 2,407);
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
            assert!(position::get_create_time(position) == 0,420);
            assert!(position::get_close_time(position) == 0,421);
            assert!(position::get_validity_time(position) == 0,422);
            assert!(*position::get_open_operator(position) == owner,423);
            assert!(*position::get_close_operator(position) == @0x0,424);
            assert!(*position::get_market_id(position) == market_id,425);
            assert!(*position::get_account_id(position) == object::id(&account),426);
            // check account
            assert!(account::get_offset(&account) == 4,427);
            // deposit 10000 scale coin , balance = 7999
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            // becouse isolated position so balance = 7999 - 2000 - 1  => 5998
            assert!(account::get_balance(&account) == 5998,428);
            let p = account::get_profit(&account);
            assert!(i64::get_value(p) == 0,429);
            assert!(i64::is_negative(p) == false,430);
            // total = 2100 + 2000 => 4100
            assert!(account::get_margin_total(&account) == 4100,431);
            assert!(account::get_margin_cross_total(&account) == 100,432);
            assert!(account::get_margin_used(&account) == 50,133);
            assert!(account::get_margin_isolated_total(&account) == 4000,434);
            assert!(account::get_margin_cross_buy_total(&account) == 50,435);
            assert!(account::get_margin_cross_sell_total(&account) == 50,436);
            assert!(account::get_margin_isolated_buy_total(&account) == 2000,437);
            assert!(account::get_margin_isolated_sell_total(&account) == 2000,438);
            assert!(account::contains_isolated_position_id(&account,&position_id) == true ,439);
            // check market
            assert!(dof::exists_(market::get_list_uid_mut(&mut list),market_id),440);
            let market: &mut Market<Tag,SCALE> = dof::borrow_mut(market::get_list_uid_mut(&mut list),market_id);
            // debug::print(market);
            // long_total = 50 * 2 + 2000 * 5 => 10100
            assert!(market::get_long_position_total(market) == 10100,441);
            // long_total = 50 * 2 + 2000 * 5 => 10100
            assert!(market::get_short_position_total(market) == 10100,442);
            let pool = market::get_pool(market);
            // debug::print(pool);
            // spread_fee = (lot/DENOMINATOR128 * size * 15/2) => (100000/10000 * 1 * (15/2)) = 70
            // 100000 - spread_fee => 99930 - 70 => 99930
            assert!(pool::get_vault_balance(pool) == 99860,443);
            assert!(pool::get_profit_balance(pool) == 0,444);
            // insurance = margin * 5/10000 = 2000 * 5/10000 => 1
            assert!(pool::get_insurance_balance(pool) == 2,445);
            assert!(pool::get_spread_profit(pool) == 140,446);
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