module scale::market{
    use sui::object::{UID,ID};
    use std::string::{String};
    
    struct Market has key ,store {
        id: UID,
        /// Maximum allowable leverage ratio
        max_leverage: u8,
        /// insurance rate
        insurance_rate: u64,
        /// margin rate,Current constant positioning 100%
        margin_rate: u64,
        /// Market status:
        /// 1 Normal;
        /// 2. Lock the market, allow closing settlement and not open positions;
        /// 3 The market is frozen, and opening and closing positions are not allowed.
        status: u8,
        /// Total amount of long positions in the market
        long_position_total: u64,
        /// Total amount of short positions in the market
        short_position_total: u64,
        /// Transaction pair (token type, such as BTC, ETH)
        /// len: 4+20
        pair: String,
        /// market description
        description: String,
        /// Point difference (can be understood as slip point),
        /// deviation between the executed quotation and the actual quotation
        spread: u64,
        /// Market operator, 1 project party, other marks to be defined
        officer: bool,
        /// coin pool of the market
        pool: ID,
    }
}