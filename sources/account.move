module scale::account {
    use sui::balance::{Self,Balance};
    use sui::object::{Self,UID,ID};
    use sui::tx_context::{Self,TxContext};
    use sui::coin::{Self,Coin};
    use sui::transfer;
    use sui::vec_map::{Self,VecMap};

    const EInsufficientCoins: u64 = 1;
    /// User transaction account
    struct Account<phantom T> has key {
        id: UID,
        owner: address,
        /// The position offset.
        /// like order id
        offset: u64,
        /// Balance of user account (maintain the deposit,
        /// and the balance here will be deducted when the deposit used in the full position mode is deducted)
        balance: Balance<T>,
        /// User settled profit
        profit: u64,
        /// Total amount of margin used.
        margin_total: u64,
        /// Total amount of used margin in full warehouse mode.
        margin_full_total: u64,
        /// Total amount of used margin in independent position mode.
        margin_independent_total: u64,
        margin_full_buy_total: u64,
        margin_full_sell_total: u64,
        margin_independent_buy_total: u64,
        margin_independent_sell_total: u64,
        full_position_idx: VecMap<PFK,ID>,
    }

    struct PFK has store,copy,drop {
        market_id: ID,
        account_id: ID,
        direction: u8,
    }

    public fun new_PFK<T>(market_id: ID,account_id: ID, direction: u8):  PFK {
        PFK {
            market_id,
            account_id,
            direction,
        }
    }
    public fun get_uid<T>(account: &Account<T>): &UID {
        &account.id
    }
    public fun get_uid_mut<T>(account: &mut Account<T>): &mut UID {
        &mut account.id
    }
    public fun get_owner<T>(account: &Account<T>): address {
        account.owner
    }
    public fun get_offset<T>(account: &Account<T>): u64 {
        account.offset
    }
    public fun get_balance<T>(account: &Account<T>): u64 {
        balance::value(&account.balance)
    }
    public fun get_profit<T>(account: &Account<T>): u64 {
        account.profit
    }
    public fun get_margin_total<T>(account: &Account<T>): u64 {
        account.margin_total
    }
    public fun get_margin_full_total<T>(account: &Account<T>): u64 {
        account.margin_full_total
    }
    public fun get_margin_independent_total<T>(account: &Account<T>): u64 {
        account.margin_independent_total
    }
    public fun get_margin_full_buy_total<T>(account: &Account<T>): u64 {
        account.margin_full_buy_total
    }
    public fun get_margin_full_sell_total<T>(account: &Account<T>): u64 {
        account.margin_full_sell_total
    }
    public fun get_margin_independent_buy_total<T>(account: &Account<T>): u64 {
        account.margin_independent_buy_total
    }
    public fun get_margin_independent_sell_total<T>(account: &Account<T>): u64 {
        account.margin_independent_sell_total
    }
    public fun contains_pfk<T>(account: &Account<T>,pfk: &PFK): bool {
        vec_map::contains(&account.full_position_idx, pfk)
    }
    public fun get_pfk_id<T>(account: &Account<T>,pfk: &PFK): ID {
        *vec_map::get(&account.full_position_idx, pfk)
    }
    public fun add_pfk_id<T>(account: &mut Account<T>,pfk: PFK,id: ID) {
        vec_map::insert(&mut account.full_position_idx, pfk, id);
    }
    public fun remove_pfk_id<T>(account: &mut Account<T>,pfk: &PFK) {
        vec_map::remove(&mut account.full_position_idx, pfk);
    }
    public fun set_offset<T>(account: &mut Account<T>, offset: u64) {
        account.offset = offset;
    }
    public fun join_balance<T>(account: &mut Account<T>, balance: Balance<T>) {
        balance::join(&mut account.balance, balance);
    }
    public fun split_balance<T>(account: &mut Account<T>, amount: u64): Balance<T> {
        balance::split(&mut account.balance, amount)
    }
    public fun set_profit<T>(account: &mut Account<T>, profit: u64) {
        account.profit = profit;
    }
    public fun set_margin_total<T>(account: &mut Account<T>, margin_total: u64) {
        account.margin_total = margin_total;
    }
    public fun set_margin_full_total<T>(account: &mut Account<T>, margin_full_total: u64) {
        account.margin_full_total = margin_full_total;
    }
    public fun set_margin_independent_total<T>(account: &mut Account<T>, margin_independent_total: u64) {
        account.margin_independent_total = margin_independent_total;
    }
    public fun set_margin_full_buy_total<T>(account: &mut Account<T>, margin_full_buy_total: u64) {
        account.margin_full_buy_total = margin_full_buy_total;
    }
    public fun set_margin_full_sell_total<T>(account: &mut Account<T>, margin_full_sell_total: u64) {
        account.margin_full_sell_total = margin_full_sell_total;
    }
    public fun set_margin_independent_buy_total<T>(account: &mut Account<T>, margin_independent_buy_total: u64) {
        account.margin_independent_buy_total = margin_independent_buy_total;
    }
    public fun set_margin_independent_sell_total<T>(account: &mut Account<T>, margin_independent_sell_total: u64) {
        account.margin_independent_sell_total = margin_independent_sell_total;
    }

    public entry fun create_account<T>(_token: &Coin<T>, ctx: &mut TxContext) {
        transfer::share_object(Account {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            offset: 0,
            balance: balance::zero<T>(),
            profit: 0,
            margin_total: 0,
            margin_full_total: 0,
            margin_independent_total: 0,
            margin_full_buy_total: 0,
            margin_full_sell_total: 0,
            margin_independent_buy_total: 0,
            margin_independent_sell_total: 0,
            full_position_idx: vec_map::empty<PFK,ID>(),
        });
    }
    /// If amount is 0, the whole coin will be consumed
    public entry fun deposit<T>(account: &mut Account<T> ,token: Coin<T>, amount: u64 ,ctx: &mut TxContext) {
        if (amount == 0) {
            balance::join(&mut account.balance, coin::into_balance(token));
            return
        };
        assert!(amount < coin::value(&token), EInsufficientCoins);
        balance::join(&mut account.balance, coin::into_balance(coin::split(&mut token, amount,ctx)));
        transfer::transfer(token,tx_context::sender(ctx))
    }

    public entry fun withdrawal<T>(account: &mut Account<T>, amount: u64, ctx: &mut TxContext) {
        // todo: check amount
        let balance = balance::split(&mut account.balance, amount);
        let coin = coin::from_balance(balance,ctx);
        transfer::transfer(coin,tx_context::sender(ctx))
    }
}