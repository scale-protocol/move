#[test_only]
module scale::pool_tests {
    use scale::pool;
    use sui_coin::scale::{SCALE};
    use sui::test_scenario;
    use sui::coin;
    // use sui::transfer;
    use sui::balance;

    struct P has drop{}
    struct MK<phantom P,phantom T> has key{
        pool: pool::Pool<P,T>,
    }
    #[test]
    fun test_create_pool(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let ctx = test_scenario::ctx(tx);
        let s_token =  coin::mint_for_testing<SCALE>(100,ctx);
        let pool = pool::create_pool(P{},&s_token);
        test_scenario::next_tx(tx,owner);
        {
            assert!(pool::get_vault_supply(&pool) == 0,1);
            assert!(pool::get_vault_balance(&pool) == 0,2);
            assert!(pool::get_profit_balance(&pool) == 0,3);
            assert!(pool::get_insurance_balance(&pool) == 0,4);
        };
        coin::destroy_for_testing(s_token);
        pool::destroy_for_testing(pool);
        test_scenario::end(test_tx);
    }
    #[test]
    fun test_add_remove_liquidity(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let token =  coin::mint_for_testing<SCALE>(1000_000_000,test_scenario::ctx(tx));
        let pool = pool::create_pool(P{},&token);
        let lsp_coin = pool::add_liquidity_for_testing(&mut pool,token,test_scenario::ctx(tx));

        test_scenario::next_tx(tx,owner);
        {
            assert!(pool::get_vault_supply(&pool) == 1000_000_000,1);
            assert!(coin::value(&lsp_coin) == 1000_000_000,2);
            // coin::destroy_for_testing(lsp_coin);
            // coin::destroy_for_testing(s_token);
        };
        test_scenario::next_tx(tx,owner);
        {
            let t_lsp_coin = coin::split(&mut lsp_coin,1000,test_scenario::ctx(tx));
            
            // let t_lsp_coin = coin::mint_for_testing<pool::LSP<P,SCALE>>(1000_000_001,test_scenario::ctx(tx));
            let s_token = pool::remove_liquidity_for_testing(&mut pool,coin::into_balance(t_lsp_coin),test_scenario::ctx(tx));
            assert!(pool::get_vault_supply(&pool) == 999_999_000,1);
            assert!(pool::get_vault_balance(&pool) == 999_999_000,2);
            assert!(pool::get_profit_balance(&pool) == 0,3);
            assert!(pool::get_insurance_balance(&pool) == 0,4);
            assert!(coin::value(&s_token) == 1000,5);
            coin::destroy_for_testing(s_token);
        };
        coin::destroy_for_testing(lsp_coin);
        pool::destroy_for_testing(pool);
        // coin::destroy_for_testing(token);
        test_scenario::end(test_tx);        
    }
    #[test]
    fun test_join_take_profit(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let s_token =  coin::mint_for_testing<SCALE>(3000_000_000,test_scenario::ctx(tx));
        let pool = pool::create_pool(P{},&s_token);
        test_scenario::next_tx(tx,owner);
        {
            let t_s_token = coin::split(&mut s_token,1000_000_000,test_scenario::ctx(tx));
            let lsp_coin = pool::add_liquidity_for_testing(&mut pool,t_s_token,test_scenario::ctx(tx));

            let t_s_token2 = coin::split(&mut s_token,5000,test_scenario::ctx(tx));
            let s_token_balance = coin::into_balance(t_s_token2);
            // test join
            pool::join_profit_balance_for_testing(&mut pool,s_token_balance);
            assert!(pool::get_vault_supply(&pool) == 1000_000_000,1);
            assert!(pool::get_vault_balance(&pool) == 1000_000_000,2);
            assert!(pool::get_profit_balance(&pool) == 5000,3);
            assert!(pool::get_insurance_balance(&pool) == 0,4);
            // test take
            let ts_token = pool::split_profit_balance_for_testing(&mut pool,4000);
            assert!(pool::get_vault_supply(&pool) == 1000_000_000,5);
            assert!(pool::get_vault_balance(&pool) == 1000_000_000,6);
            assert!(pool::get_profit_balance(&pool) == 1000,7);
            assert!(pool::get_insurance_balance(&pool) == 0,8);

            let tss_token = pool::split_profit_balance_for_testing(&mut pool,1000);
            assert!(pool::get_vault_supply(&pool) == 1000_000_000,9);
            assert!(pool::get_vault_balance(&pool) == 1000_000_000,10);
            assert!(pool::get_profit_balance(&pool) == 0,11);
            assert!(pool::get_insurance_balance(&pool) == 0,12);

            let tsss_token = pool::split_profit_balance_for_testing(&mut pool,1000);
            assert!(pool::get_vault_supply(&pool) == 1000_000_000,13);
            assert!(pool::get_vault_balance(&pool) == 999_999_000,14);
            assert!(pool::get_profit_balance(&pool) == 0,15);
            assert!(pool::get_insurance_balance(&pool) == 0,16);

            pool::join_profit_balance_for_testing(&mut pool,ts_token);
            pool::join_profit_balance_for_testing(&mut pool,tss_token);
            pool::join_profit_balance_for_testing(&mut pool,tsss_token);
            assert!(pool::get_vault_supply(&pool) == 1000_000_000,17);
            assert!(pool::get_vault_balance(&pool) == 1000_000_000,18);
            assert!(pool::get_profit_balance(&pool) == 5000,19);
            assert!(pool::get_insurance_balance(&pool) == 0,20);

            coin::destroy_for_testing(s_token);
            coin::destroy_for_testing(lsp_coin);
        };
        pool::destroy_for_testing(pool);
        test_scenario::end(test_tx);        
    }
    #[test]
    fun test_join_take_insurance(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let s_token =  coin::mint_for_testing<SCALE>(3000_000_000,test_scenario::ctx(tx));
        let pool = pool::create_pool(P{},&s_token);
        
        test_scenario::next_tx(tx,owner);
        {
            let s_token =  coin::mint_for_testing<SCALE>(3000_000_000,test_scenario::ctx(tx));
            let t_s_token = coin::split(&mut s_token,2000_000_000,test_scenario::ctx(tx));
            let lsp_coin = pool::add_liquidity_for_testing(&mut pool,t_s_token,test_scenario::ctx(tx));
            let t_s_token2 = coin::split(&mut s_token,5000,test_scenario::ctx(tx));
            pool::join_insurance_balance_for_testing(&mut pool,coin::into_balance(t_s_token2));
            assert!(pool::get_vault_supply(&pool) == 2000_000_000,1);
            assert!(pool::get_vault_balance(&pool) == 2000_000_000,2);
            assert!(pool::get_profit_balance(&pool) == 0,3);
            assert!(pool::get_insurance_balance(&pool) == 5000,4);

            let ts_token = pool::split_insurance_balance_for_testing(&mut pool,4000);
            assert!(pool::get_vault_supply(&pool) == 2000_000_000,5);
            assert!(pool::get_vault_balance(&pool) == 2000_000_000,6);
            assert!(pool::get_profit_balance(&pool) == 0,7);
            assert!(pool::get_insurance_balance(&pool) == 1000,8);
            assert!(balance::value(&ts_token) == 4000,9);

            coin::destroy_for_testing(s_token);
            coin::destroy_for_testing(coin::from_balance(ts_token,test_scenario::ctx(tx)));
            coin::destroy_for_testing(lsp_coin);
        };
        coin::destroy_for_testing(s_token);
        pool::destroy_for_testing(pool);
        test_scenario::end(test_tx);  
    }
}