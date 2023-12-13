module scale::pool {
    use sui::coin::{Self,Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::tx_context::{TxContext};
    use sui::vec_map::{Self,VecMap};

    // use std::debug;
    friend scale::bond;
    friend scale::position;
    friend scale::market;
    #[test_only]
    friend scale::pool_tests;
    // friend scale::account;

    const EZeroAmount: u64 = 501;

    struct Scale has drop {}
    /// Original reserves of current pool funds
    /// liquidity supply pool
    struct LSP<phantom P, phantom T> has drop {}
    /// Liquidity fund pool
    struct Pool<phantom P, phantom T> has store {
        // The original supply of the liquidity pool represents 
        // the liquidity funds obtained through the issuance of NFT bonds
        vault_supply: Supply<LSP<P,T>>,
        // Token balance of basic current fund.
        vault_balance: Balance<T>,
        // Token balance of profit and loss fund
        profit_balance: Balance<T>,
        // Insurance fund token balance
        insurance_balance: Balance<T>,
        // Spread benefits, to prevent robot cheating and provide benefits to sponsors
        spread_profit: Balance<T>,
        // Final profit within a cycle
        epoch_profit: VecMap<u64,u64>,
    }

    public(friend) fun create_pool<P: drop ,T>(): Pool<P,T> {
        Pool {
            vault_supply: balance::create_supply(LSP<P,T>{}),
            vault_balance: balance::zero<T>(),
            profit_balance: balance::zero<T>(),
            insurance_balance: balance::zero<T>(),
            spread_profit: balance::zero<T>(),
            epoch_profit: vec_map::empty<u64,u64>(),
        }
    }

    public(friend) fun add_liquidity<P,T>(
        pool: &mut Pool<P, T>,
        token: Coin<T>,
        ctx: &mut TxContext
    ):Coin<LSP<P, T>>{
        assert!(coin::value(&token) > 0, EZeroAmount);
        let tok_balance = coin::into_balance(token);
        let minted = balance::value(&tok_balance);
        balance::join(&mut pool.vault_balance, tok_balance);
        coin::from_balance(balance::increase_supply(&mut pool.vault_supply, minted), ctx)
    }
    #[test_only]
    public fun add_liquidity_for_testing<P,T>(
        pool: &mut Pool<P, T>,
        token: Coin<T>,
        ctx: &mut TxContext
    ):Coin<LSP<P, T>>{
        add_liquidity(pool,token,ctx)
    }

    public(friend) fun remove_liquidity<P, T>(
        pool: &mut Pool<P, T>,
        lsp_balance: Balance<LSP<P, T>>,
        ctx: &mut TxContext
    ): Coin<T> {
        let balance_value = balance::value(&lsp_balance);
        assert!(balance_value > 0, EZeroAmount);
        balance::decrease_supply(&mut pool.vault_supply, lsp_balance);
        coin::take(&mut pool.vault_balance, balance_value, ctx)
    }
    #[test_only]
    public fun remove_liquidity_for_testing<P, T>(
        pool: &mut Pool<P, T>,
        lsp_balance: Balance<LSP<P, T>>,
        ctx: &mut TxContext
    ): Coin<T> {
        remove_liquidity(pool,lsp_balance,ctx)
    }

    public(friend) fun join_profit_balance<P,T>(pool: &mut Pool<P, T>, balance: Balance<T>,epoch: u64){
        let vault_supply_value = balance::supply_value(&pool.vault_supply);
        let base_amount = balance::join(&mut pool.vault_balance, balance);
        if (base_amount > vault_supply_value){
            balance::join(&mut pool.profit_balance, balance::split(&mut pool.vault_balance, base_amount - vault_supply_value));
        };
        update_epoch_profit(pool,epoch);
    }
    #[test_only]
    public fun join_profit_balance_for_testing<P,T>(pool: &mut Pool<P, T>, balance: Balance<T>,epoch: u64){
        join_profit_balance(pool,balance,epoch)
    }

    public(friend) fun split_profit_balance<P,T>(pool: &mut Pool<P, T>, amount: u64, epoch: u64):Balance<T>{
        let profit_balance_value = balance::value(&pool.profit_balance);
        if (profit_balance_value >= amount) {
            let b = balance::split(&mut pool.profit_balance, amount);
            update_epoch_profit(pool,epoch);
            return b
        };
        let b = balance::split(&mut pool.profit_balance, profit_balance_value);
        let s = amount - balance::value(&b);
        balance::join(&mut b, balance::split(&mut pool.vault_balance, s));
        update_epoch_profit(pool,epoch);
        b
    }

    fun update_epoch_profit<P,T>(pool: &mut Pool<P, T>, epoch: u64){
        if (vec_map::contains(&pool.epoch_profit, &epoch)) {
            vec_map::remove(&mut pool.epoch_profit, &epoch);
            vec_map::insert(&mut pool.epoch_profit, epoch, balance::value(&pool.profit_balance));
        }else{
            vec_map::insert(&mut pool.epoch_profit, epoch, balance::value(&pool.profit_balance));
        };
        if (vec_map::size(&pool.epoch_profit) > 90) {
            vec_map::remove_entry_by_idx(&mut pool.epoch_profit,0);
        }
    }

    #[test_only]
    public fun split_profit_balance_for_testing<P,T>(pool: &mut Pool<P, T>, amount: u64,epoch: u64):Balance<T>{
        split_profit_balance(pool,amount,epoch)
    }

    public(friend) fun join_insurance_balance<P,T>(pool: &mut Pool<P, T>, balance: Balance<T>){
        balance::join(&mut pool.insurance_balance, balance);
    }

    public(friend) fun join_spread_profit<P,T>(pool: &mut Pool<P, T>, balance: Balance<T>){
        balance::join(&mut pool.spread_profit, balance);
    }
    #[test_only]
    public fun join_spread_profit_for_testing<P,T>(pool: &mut Pool<P, T>, balance: Balance<T>){
        join_spread_profit(pool,balance)
    }

    #[test_only]
    public fun join_insurance_balance_for_testing<P,T>(pool: &mut Pool<P, T>, balance: Balance<T>){
        join_insurance_balance(pool,balance)
    }

    public(friend) fun split_insurance_balance<P,T>(pool: &mut Pool<P, T>, amount: u64):Balance<T>{
        balance::split(&mut pool.insurance_balance, amount)
    }
    #[test_only]
    public fun split_insurance_balance_for_testing<P,T>(pool: &mut Pool<P, T>, amount: u64):Balance<T>{
        split_insurance_balance(pool,amount)
    }

    public(friend) fun split_spread_profit<P,T>(pool: &mut Pool<P, T>, amount: u64):Balance<T>{
        balance::split(&mut pool.spread_profit, amount)
    }
    #[test_only]
    public fun split_spread_profit_for_testing<P,T>(pool: &mut Pool<P, T>, amount: u64):Balance<T>{
        split_spread_profit(pool,amount)
    }
    public fun get_vault_supply<P,T>(pool: &Pool<P, T>):u64 {
        balance::supply_value(&pool.vault_supply)
    }

    public fun get_vault_balance<P,T>(pool: &Pool<P, T>):u64 {
        balance::value(&pool.vault_balance)
    }

    public fun get_profit_balance<P,T>(pool: &Pool<P, T>):u64 {
        balance::value(&pool.profit_balance)
    }
    public fun get_epoch_profit<P,T>(pool: &Pool<P, T>, epoch: u64):u64 {
        if (!vec_map::contains(&pool.epoch_profit, &epoch)) {
            return 0
        };
        *vec_map::get(&pool.epoch_profit, &epoch)
    }
    public fun get_insurance_balance<P,T>(pool: &Pool<P, T>):u64 {
        balance::value(&pool.insurance_balance)
    }
    public fun get_spread_profit<P,T>(pool: &Pool<P, T>):u64 {
        balance::value(&pool.spread_profit)
    }
    public fun get_total_liquidity<P,T>(pool: &Pool<P,T>) :u64{
         balance::value(&pool.vault_balance) + balance::value(&pool.profit_balance)
    }
}