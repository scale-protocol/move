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
    use scale::event;
    use sui::pay;
    friend scale::position;
    friend scale::enter;
        
    const EInsufficientCoins: u64 = 1;
    const ENotOwner: u64 = 2;
    const EInsufficientEquity: u64 = 3;

    struct UserAccount has key {
        id: UID,
        owner: address,
        account_id: ID,
    }

    /// User transaction account
    struct Account<phantom T> has key {
        id: UID,
        owner: address,
        /// The position offset.
        /// like order id
        offset: u64,
        /// Balance of user account (maintain the deposit,
        /// and the balance here will be deducted when the deposit used in the cross position mode is deducted)
        balance: Balance<T>,
        isolated_balance: Balance<T>,
        /// User settled profit
        profit: I64,
        /// Total amount of margin used.
        margin_total: u64,
        /// Total amount of used margin in cross warehouse mode.
        margin_cross_total: u64,
        /// Total amount of used margin in isolated position mode.
        margin_isolated_total: u64,
        margin_cross_buy_total: u64,
        margin_cross_sell_total: u64,
        margin_isolated_buy_total: u64,
        margin_isolated_sell_total: u64,
        cross_position_idx: VecMap<PFK,ID>,
        isolated_position_idx: vector<ID>,
    }

    struct PFK has store,copy,drop {
        market_id: ID,
        account_id: ID,
        direction: u8,
    }

    public fun new_PFK(market_id: ID, account_id: ID, direction: u8):  PFK {
        PFK {
            market_id,
            account_id,
            direction,
        }
    }

    public fun get_uid<T>(account: &Account<T>): &UID {
        &account.id
    }

    public(friend) fun get_uid_mut<T>(account: &mut Account<T>): &mut UID {
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
    public fun get_isolated_balance<T>(account: &Account<T>): u64 {
        balance::value(&account.isolated_balance)
    }
    public fun get_profit<T>(account: &Account<T>): &I64 {
        &account.profit
    }

    public fun get_margin_total<T>(account: &Account<T>): u64 {
        account.margin_total
    }

    public fun get_margin_cross_total<T>(account: &Account<T>): u64 {
        account.margin_cross_total
    }

    public fun get_margin_used<T>(account: &Account<T>): u64 {
        math::max(account.margin_cross_buy_total, account.margin_cross_sell_total)
    }
    public fun get_margin_isolated_total<T>(account: &Account<T>): u64 {
        account.margin_isolated_total
    }
    public fun get_margin_cross_buy_total<T>(account: &Account<T>): u64 {
        account.margin_cross_buy_total
    }
    public fun get_margin_cross_sell_total<T>(account: &Account<T>): u64 {
        account.margin_cross_sell_total
    }
    public fun get_margin_isolated_buy_total<T>(account: &Account<T>): u64 {
        account.margin_isolated_buy_total
    }
    public fun get_margin_isolated_sell_total<T>(account: &Account<T>): u64 {
        account.margin_isolated_sell_total
    }
    public fun contains_pfk<T>(account: &Account<T>,pfk: &PFK): bool {
        vec_map::contains(&account.cross_position_idx, pfk)
    }
    public fun get_pfk_id<T>(account: &Account<T>,pfk: &PFK): ID {
        *vec_map::get(&account.cross_position_idx, pfk)
    }
    public(friend) fun add_pfk_id<T>(account: &mut Account<T>,pfk: PFK,id: ID) {
        vec_map::insert(&mut account.cross_position_idx, pfk, id);
    }
    public(friend) fun remove_pfk_id<T>(account: &mut Account<T>,pfk: &PFK) {
        if (!vec_map::contains(&account.cross_position_idx, pfk)) {
            return
        };
        vec_map::remove(&mut account.cross_position_idx, pfk);
    }

    public(friend) fun add_isolated_position_id<T>(account: &mut Account<T>,id: ID) {
        vector::push_back(&mut account.isolated_position_idx, id);
    }

    public(friend) fun remove_isolated_position_id<T>(account: &mut Account<T>,id: ID) {
        let i = 0;
        let n = vector::length(&account.isolated_position_idx);
        while (i < n) {
            let v = vector::borrow(&account.isolated_position_idx, i);
            if (*v == id) {
                vector::swap_remove(&mut account.isolated_position_idx, i);
                return
            };
            i = i + 1;
        };
    }

    public fun contains_isolated_position_id<T>(account: &Account<T>,id: &ID): bool {
        vector::contains(&account.isolated_position_idx, id)
    }

    public fun get_all_position_ids<T>(account: &Account<T>):vector<ID> {
        let idx = account.isolated_position_idx;
        let i = 0;
        let n = vec_map::size(&account.cross_position_idx);
        while (i < n) {
            let (_,v) = vec_map::get_entry_by_idx(&account.cross_position_idx, i);
            vector::push_back(&mut idx, *v);
            i = i + 1;
        };
        idx
    }
    public fun get_pfk_ids<T>(account: &Account<T>):vector<ID> {
        let i = 0;
        let n = vec_map::size(&account.cross_position_idx);
        let r = vector::empty<ID>();
        while (i < n) {
            let (_,v) = vec_map::get_entry_by_idx(&account.cross_position_idx, i);
            vector::push_back(&mut r, *v);
            i = i + 1;
        };
        r
    }
    public(friend) fun set_offset<T>(account: &mut Account<T>, offset: u64) {
        account.offset = offset;
    }
    public(friend) fun join_balance<T>(account: &mut Account<T>, type:u8, balance: Balance<T>) {
        if (type == 1){
            balance::join(&mut account.balance, balance);
        }else{
            balance::join(&mut account.isolated_balance, balance);
        }
    }
    public(friend) fun split_balance<T>(account: &mut Account<T>, type: u8, amount: u64): Balance<T> {
        if ( type == 1){
            balance::split(&mut account.balance, amount)
        }else{
            balance::split(&mut account.isolated_balance, amount)
        }
    }

    public(friend) fun isolated_deposit<T>(account: &mut Account<T>, coins: vector<Coin<T>>) {
        let token = vector::pop_back(&mut coins);
        pay::join_vec(&mut token, coins);
        balance::join(&mut account.isolated_balance, coin::into_balance(token));
    }
    #[test_only]
    public fun isolated_deposit_for_testing<T>(account: &mut Account<T>, coin: Coin<T>) {
        let v = vector::empty();
        vector::push_back(&mut v, coin);
        isolated_deposit(account, v);
    }

    public(friend) fun isolated_withdraw<T>(account: &mut Account<T>, receiver: address,ctx: &mut TxContext) {
        let balance = balance::value(&account.isolated_balance);
        let coin = coin::from_balance(balance::split(&mut account.isolated_balance, balance),ctx);
        transfer::public_transfer(coin, receiver);
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
    public(friend) fun inc_margin_cross_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_cross_total = account.margin_cross_total + margin;
    }
    public(friend) fun dec_margin_cross_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_cross_total = account.margin_cross_total - margin;
    }
    public(friend) fun inc_margin_isolated_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_isolated_total = account.margin_isolated_total + margin;
    }
    public(friend) fun dec_margin_isolated_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_isolated_total = account.margin_isolated_total - margin;
    }
    public(friend) fun inc_margin_cross_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_cross_buy_total = account.margin_cross_buy_total + margin;
    }
    #[test_only]
    public fun inc_margin_cross_buy_total_for_testing<T>(account: &mut Account<T>, margin: u64) {
        inc_margin_cross_buy_total(account, margin);
    }
    public(friend) fun dec_margin_cross_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_cross_buy_total = account.margin_cross_buy_total - margin;
    }
    public(friend) fun inc_margin_cross_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_cross_sell_total = account.margin_cross_sell_total + margin;
    }
    #[test_only]
    public fun inc_margin_cross_sell_total_for_testing<T>(account: &mut Account<T>, margin: u64) {
        inc_margin_cross_sell_total(account, margin);
    }
    public(friend) fun dec_margin_cross_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_cross_sell_total = account.margin_cross_sell_total - margin;
    }
    public(friend) fun inc_margin_isolated_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_isolated_buy_total = account.margin_isolated_buy_total + margin;
    }
    public(friend) fun dec_margin_isolated_buy_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_isolated_buy_total = account.margin_isolated_buy_total - margin;
    }
    public(friend) fun inc_margin_isolated_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_isolated_sell_total = account.margin_isolated_sell_total + margin;
    }
    public(friend) fun dec_margin_isolated_sell_total<T>(account: &mut Account<T>, margin: u64) {
        account.margin_isolated_sell_total = account.margin_isolated_sell_total - margin;
    }

    public fun create_account<T>(
        ctx: &mut TxContext
    ):ID {
        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);
        let account = Account {
            id: uid,
            owner: tx_context::sender(ctx),
            offset: 0,
            balance: balance::zero<T>(),
            isolated_balance: balance::zero<T>(),
            profit: i64::new(0,false),
            margin_total: 0,
            margin_cross_total: 0,
            margin_isolated_total: 0,
            margin_cross_buy_total: 0,
            margin_cross_sell_total: 0,
            margin_isolated_buy_total: 0,
            margin_isolated_sell_total: 0,
            cross_position_idx: vec_map::empty<PFK,ID>(),
            isolated_position_idx: vector::empty<ID>(),
        };
        transfer::transfer(UserAccount{
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            account_id: id,
        }, tx_context::sender(ctx));
        transfer::share_object(account);
        event::create<Account<T>>(id);
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
        transfer::public_transfer(token,tx_context::sender(ctx));
        event::update<Account<T>>(object::id(account));
    }

    public(friend) fun withdrawal<T>(
        equity: I64,
        account: &mut Account<T>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(account.owner == tx_context::sender(ctx), ENotOwner);
        i64::dec_u64(&mut equity, amount);
        assert!(!i64::is_negative(&equity), EInsufficientEquity);
        let margin_used = get_margin_used(account);
        // expect equity
        i64::dec_u64(&mut equity, amount);
        if (margin_used > 0) {
            assert!(i64::get_value(&equity) / margin_used >= 1, EInsufficientEquity);
        };
        let balance = balance::split(&mut account.balance, amount);
        let coin = coin::from_balance(balance,ctx);
        transfer::public_transfer(coin,tx_context::sender(ctx));
        event::update<Account<T>>(object::id(account));
    }
    #[test_only]
    public fun set_balance_for_testing<T>(account: &mut Account<T>,expected_balance:u64,ctx: &mut TxContext) {
        let balance_coin = coin::mint_for_testing<T>(expected_balance,ctx);
        // take all
        let v = balance::value(&account.balance);
        let c = coin::take(&mut account.balance, v ,ctx);
        // join all
        balance::join(&mut account.balance, coin::into_balance(balance_coin));
        coin::burn_for_testing(c);
    }
}