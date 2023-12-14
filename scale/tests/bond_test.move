#[test_only]
module scale::bond_tests {
    use scale::market::{Self, List};
    use scale::bond::{Self,BondFactory,ScaleBond};
    use scale::pool;
    use scale::admin;
    use sui::test_scenario;
    // use sui::object::{ID};
    use sui::coin;
    // use std::debug;
    use sui_coin::scale::{SCALE};
    use sui::clock;
    use sui::test_utils;
    use sui::package;

    #[test]
    fun test_bond(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let s_token =  coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx));
        let publisher = package::test_claim(bond::create_bond_for_testing(),test_scenario::ctx(tx));
        bond::init_for_testing(test_scenario::ctx(tx));
        bond::create_display<SCALE>(&publisher,test_scenario::ctx(tx));
        market::create_list<SCALE>(test_scenario::ctx(tx));
        admin::init_for_testing(test_scenario::ctx(tx));
        test_scenario::next_tx(tx,owner);
        let c = clock::create_for_testing(test_scenario::ctx(tx));
        clock::set_for_testing(&mut c,123000);
        let list = test_scenario::take_shared<List<SCALE>>(tx);
        let factory = test_scenario::take_shared<BondFactory>(tx);
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<admin::AdminCap>(tx);
            bond::add_factory_mould(
                &mut admin_cap,
                &mut factory,
                b"hello",
                b"world",
                b"https://scale.exchange",
                test_scenario::ctx(tx),
            );
            bond::add_factory_mould(
                &mut admin_cap,
                &mut factory,
                b"freely",
                b"world",
                b"https://scale.exchange",
                test_scenario::ctx(tx),
            );
            bond::investment(
                s_token,
                b"hello",
                0,
                128000,
                &mut list,
                &mut factory,
                &c,
                test_scenario::ctx(tx)
            );
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::next_tx(tx,owner);
        {
            let pool = market::get_pool_mut_for_testing(&mut list);
            assert!(pool::get_vault_supply(pool) == 10000,101);
            assert!(pool::get_vault_balance(pool) == 10000,101);
            let nft = test_scenario::take_from_sender<ScaleBond<SCALE>>(tx);
            assert!(bond::get_bond_denomination(&nft) == 10000,101);
            test_scenario::return_to_sender(tx,nft);
        };
        test_scenario::next_tx(tx,owner);
        {
            let nft = test_scenario::take_from_sender<ScaleBond<SCALE>>(tx);
            bond::divestment(
                nft,
                &mut list,
                &mut factory,
                &c,
                test_scenario::ctx(tx)
            );
            let pool = market::get_pool_mut_for_testing(&mut list);
            assert!(pool::get_vault_supply(pool) == 0,101);
            assert!(pool::get_vault_balance(pool) == 0,101);
        };
        test_utils::destroy(publisher);
        test_utils::destroy(c);
        test_scenario::return_shared(list);
        test_scenario::return_shared(factory);
        test_scenario::end(test_tx);
    }
    #[test]
    fun test_bond_penalty(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let s_token =  coin::mint_for_testing<SCALE>(10000,test_scenario::ctx(tx));
        let publisher = package::test_claim(bond::create_bond_for_testing(),test_scenario::ctx(tx));
        bond::init_for_testing(test_scenario::ctx(tx));
        bond::create_display<SCALE>(&publisher,test_scenario::ctx(tx));
        market::create_list<SCALE>(test_scenario::ctx(tx));
        admin::init_for_testing(test_scenario::ctx(tx));
        test_scenario::next_tx(tx,owner);
        let c = clock::create_for_testing(test_scenario::ctx(tx));
        clock::set_for_testing(&mut c,123000);
        let list = test_scenario::take_shared<List<SCALE>>(tx);
        let factory = test_scenario::take_shared<BondFactory>(tx);
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<admin::AdminCap>(tx);
            bond::add_factory_mould(
                &mut admin_cap,
                &mut factory,
                b"hello",
                b"world",
                b"https://scale.exchange",
                test_scenario::ctx(tx),
            );
            bond::add_factory_mould(
                &mut admin_cap,
                &mut factory,
                b"freely",
                b"world",
                b"https://scale.exchange",
                test_scenario::ctx(tx),
            );
            bond::investment(
                s_token,
                b"hello",
                0,
                128000,
                &mut list,
                &mut factory,
                &c,
                test_scenario::ctx(tx)
            );
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::next_tx(tx,owner);
        {
            let pool = market::get_pool_mut_for_testing(&mut list);
            assert!(pool::get_vault_supply(pool) == 10000,101);
            assert!(pool::get_vault_balance(pool) == 10000,101);
            let nft = test_scenario::take_from_sender<ScaleBond<SCALE>>(tx);
            assert!(bond::get_bond_denomination(&nft) == 10000,101);
            test_scenario::return_to_sender(tx,nft);
        };
        // 251000
        clock::set_for_testing(&mut c,127000);
        test_scenario::next_tx(tx,owner);
        {
            let nft = test_scenario::take_from_sender<ScaleBond<SCALE>>(tx);
            bond::divestment(
                nft,
                &mut list,
                &mut factory,
                &c,
                test_scenario::ctx(tx)
            );
            let pool = market::get_pool_mut_for_testing(&mut list);
            assert!(pool::get_vault_supply(pool) == 0,101);
            assert!(pool::get_vault_balance(pool) == 0,101);
            // penalty = 10000 * 300/10000 = 300
            // because of the penalty and supply is 0, the profit balance is 300
            assert!(pool::get_profit_balance(pool) == 300,101);
        };
        test_utils::destroy(publisher);
        test_utils::destroy(c);
        test_scenario::return_shared(list);
        test_scenario::return_shared(factory);
        test_scenario::end(test_tx);
    }
    // todo award test
}