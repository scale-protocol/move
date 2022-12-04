module scale::pool {
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::tx_context::{TxContext};
    use sui::transfer;

    friend scale::nft;

    const EZeroAmount: u64 = 1;
    /// Original reserves of current pool funds
    struct LSP<phantom P, phantom T> has drop {}
    /// Liquidity fund pool
    struct Pool<phantom P, phantom T> has key {
        id: UID,
        /// The original supply of the liquidity pool represents 
        /// the liquidity funds obtained through the issuance of NFT bonds
        vault_supply: Supply<LSP<P,T>>,
        /// Token balance of basic current fund.
        base_balance: Balance<T>,
        /// Token balance of profit and loss fund
        profit_balance: Balance<T>,
        /// Insurance fund token balance
        insurance_balance: Balance<T>,
    }

    public fun create_pool<P ,T: drop>(_token: T,ctx: &mut TxContext):ID {
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        transfer::share_object(Pool {
            id: uid,
            vault_supply: balance::create_supply(LSP<P,T>{}),
            base_balance: balance::zero<T>(),
            profit_balance: balance::zero<T>(),
            insurance_balance: balance::zero<T>(),
        });
        id
    }

    public(friend) fun add_liquidity<P,T>(
        pool: &mut Pool<P, T>,
        token: Coin<T>,
        ctx: &mut TxContext
    ):Coin<LSP<P, T>>{
        assert!(coin::value(&token) > 0, EZeroAmount);
        let tok_balance = coin::into_balance(token);
        let minted = balance::value(&tok_balance);
        balance::join(&mut pool.base_balance, tok_balance);
        coin::from_balance(balance::increase_supply(&mut pool.vault_supply, minted), ctx)
    }

    public(friend) fun remove_liquidity<P, T>(
        pool: &mut Pool<P, T>,
        lsp_balance: Balance<LSP<P, T>>,
        ctx: &mut TxContext
    ): Coin<T> {
        let balance_value = balance::value(&lsp_balance);
        assert!(balance_value > 0, EZeroAmount);
        balance::decrease_supply(&mut pool.vault_supply, lsp_balance);
        coin::take(&mut pool.base_balance, balance_value, ctx)
    }

    public(friend) fun add(){}
}