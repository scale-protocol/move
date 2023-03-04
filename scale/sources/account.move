module scale::account {
    use sui::balance::{Self,Balance};
    use sui::object::{Self,UID,ID};
    use sui::tx_context::{Self,TxContext};
    use sui::coin::{Self,Coin};
    use sui::transfer;
    use sui::vec_map::{Self,VecMap};
    use std::vector;
    use scale::i64::{Self,I64};
    use sui::math;
    use sui::typed_id::{Self,TypedID};

    friend scale::position;
    friend scale::enter;
        
    const EInsufficientCoins: u64 = 1;
    const ENotOwner: u64 = 2;
    const EInsufficientEquity: u64 = 3;

    struct UserAccount<phantom T> has key {
        id: UID,
        owner: address,
        account_id: TypedID<Account<T>>
    }

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
        profit: I64,
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
        independent_position_idx: vector<ID>,
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

    public fun get_profit<T>(account: &Account<T>): &I64 {
        &account.profit
    }

    public fun get_margin_total<T>(account: &Account<T>): u64 {
        account.margin_total
    }

    public fun get_margin_full_total<T>(account: &Account<T>): u64 {
        account.margin_full_total
    }

    public fun get_margin_used<T>(account: &Account<T>): u64 {
        math::max(account.margin_full_buy_total, account.margin_full_sell_total)
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
    public(friend) fun add_pfk_id<T>(account: &mut Account<T>,pfk: PFK,id: ID) {
        vec_map::insert(&mut account.full_position_idx, pfk, id);
    }
    public(friend) fun remove_pfk_id<T>(account: &mut Account<T>,pfk: &PFK) {
        vec_map::remove(&mut account.full_position_idx, pfk);
    }
    public(friend) fun add_independent_position_id<T>(account: &mut Account<T>,id: ID) {
        vector::push_back(&mut account.independent_position_idx, id);
    }
    public(friend) fun remove_independent_position_id<T>(account: &mut Account<T>,id: ID) {
        let i = 0;
        let n = vector::length(&account.independent_position_idx);
        while (i < n) {
            let v = vector::borrow(&account.independent_position_idx, i);
            if (*v == id) {
                vector::swap_remove(&mut account.independent_position_idx, i);
                return
            };
            i = i + 1;
        };
    }
    public fun get_all_position_ids<T>(account: &Account<T>):vector<ID> {
        let idx = account.independent_position_idx;
        let i = 0;
        let n = vec_map::size(&account.full_position_idx);
        while (i < n) {
            let (_,v) = vec_map::get_entry_by_idx(&account.full_position_idx, i);
            vector::push_back(&mut idx, *v);
            i = i + 1;
        };
        idx
    }
    public fun get_pfk_ids<T>(account: &Account<T>):vector<ID> {
        let i = 0;
        let n = vec_map::size(&account.full_position_idx);
        let r = vector::empty<ID>();
        while (i < n) {
            let (_,v) = vec_map::get_entry_by_idx(&account.full_position_idx, i);
            vector::push_back(&mut r, *v);
            i = i + 1;
        };
        r
    }
    public(friend) fun set_offset<T>(account: &mut Account<T>, offset: u64) {
        account.offset = offset;
    }
    public(friend) fun join_balance<T>(account: &mut Account<T>, balance: Balance<T>) {
        balance::join(&mut account.balance, balance);
    }
    public(friend) fun split_balance<T>(account: &mut Account<T>, amount: u64): Balance<T> {
        balance::split(&mut account.balance, amount)
    }
    public(friend) fun inc_profit<T>(account: &mut Account<T>, profit: u64) {
        i64::inc_u64(&mut account.profit, profit);
    }
    public(friend) fun dec_profit<T>(account: &mut Account<T>, profit: u64) {
        i64::dec_u64(&mut account.profit, profit);
    }
    public(friend) fun inc_margin_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_total = account.margin_total + margin;
    }
    public(friend) fun dec_margin_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_total = account.margin_total - margin;
    }
    public(friend) fun inc_margin_full_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_full_total = account.margin_full_total + margin;
    }
    public(friend) fun dec_margin_full_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_full_total = account.margin_full_total - margin;
    }
    public(friend) fun inc_margin_independent_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_independent_total = account.margin_independent_total + margin;
    }
    public(friend) fun dec_margin_independent_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_independent_total = account.margin_independent_total - margin;
    }
    public(friend) fun inc_margin_full_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_full_buy_total = account.margin_full_buy_total + margin;
    }
    public(friend) fun dec_margin_full_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_full_buy_total = account.margin_full_buy_total - margin;
    }
    public(friend) fun inc_margin_full_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_full_sell_total = account.margin_full_sell_total + margin;
    }
    public(friend) fun dec_margin_full_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_full_sell_total = account.margin_full_sell_total - margin;
    }
    public(friend) fun inc_margin_independent_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_independent_buy_total = account.margin_independent_buy_total + margin;
    }
    public(friend) fun dec_margin_independent_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_independent_buy_total = account.margin_independent_buy_total - margin;
    }
    public(friend) fun inc_margin_independent_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_independent_sell_total = account.margin_independent_sell_total + margin;
    }
    public(friend) fun dec_margin_independent_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_independent_sell_total = account.margin_independent_sell_total - margin;
    }

    public fun create_account<T>(
        _token: &Coin<T>,
        ctx: &mut TxContext
    ):ID {
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        let account = Account {
            id: uid,
            owner: tx_context::sender(ctx),
            offset: 0,
            balance: balance::zero<T>(),
            profit: i64::new(0,false),
            margin_total: 0,
            margin_full_total: 0,
            margin_independent_total: 0,
            margin_full_buy_total: 0,
            margin_full_sell_total: 0,
            margin_independent_buy_total: 0,
            margin_independent_sell_total: 0,
            full_position_idx: vec_map::empty<PFK,ID>(),
            independent_position_idx: vector::empty<ID>(),
        };
        transfer::transfer(UserAccount{
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            account_id: typed_id::new(&account),
        }, tx_context::sender(ctx));
        transfer::share_object(account);
        id
    }
    /// If amount is 0, the whole coin will be consumed
    public fun deposit<T>(
        account: &mut Account<T>,
        token: Coin<T>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        if (amount == 0) {
            balance::join(&mut account.balance, coin::into_balance(token));
            return
        };
        assert!(amount <= coin::value(&token), EInsufficientCoins);
        balance::join(&mut account.balance, coin::into_balance(coin::split(&mut token, amount,ctx)));
        transfer::transfer(token,tx_context::sender(ctx))
    }

    public(friend) fun withdrawal<P,T>(
        equity: I64,
        account: &mut Account<T>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(account.owner == tx_context::sender(ctx), ENotOwner);
        i64::dec_u64(&mut equity, amount);
        assert!(!i64::is_negative(&equity), EInsufficientEquity);
        let margin_used = get_margin_used(account);
        // assert!(margin_used <= i64::get_value(&equity), EInsufficientEquity);
        if (margin_used > 0) {
            assert!(i64::get_value(&equity) * 10000 / margin_used > 10000, EInsufficientEquity);
        };
        let balance = balance::split(&mut account.balance, amount);
        let coin = coin::from_balance(balance,ctx);
        transfer::transfer(coin,tx_context::sender(ctx))
    }
}