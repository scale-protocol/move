module scale::user {
    use sui::balance::{Balance};
    use sui::object::{UID};
    
    struct User<phantom T> has key,store {
        id: UID,
        /// The position offset.
        /// like order id
        offset: u64,
        /// Balance of user account (maintain the deposit,
        /// and the balance here will be deducted when the deposit used in the full position mode is deducted)
        balance: Balance<T>,
        /// User settled profit
        profit: u64,
        /// Total amount of margin used.
        margin_total: Balance<T>,
        /// Total amount of used margin in full warehouse mode.
        margin_full_total: u64,
        /// Total amount of used margin in independent position mode.
        margin_independent_total: u64,
        margin_full_buy_total: u64,
        margin_full_sell_total: u64,
        margin_independent_buy_total: u64,
        margin_independent_sell_total: u64,
    }
}