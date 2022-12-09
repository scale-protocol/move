module scale::position {
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::balance::{Balance};
    use scale::market::{Self,Market};
    use scale::account::{Self,Account};
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;
    
    const EInvalidSize:u64 = 1;
    const EInvalidLot:u64 = 2;
    const EInvalidLeverage:u64 = 3;
    const EInvalidPositionType:u64 = 4;
    const EInvalidDirection:u64 = 5;

    struct Position<phantom T> has key,store {
        id: UID,
        offset: u64,
        /// Initial position margin
        margin: u64,
        /// Current actual margin balance
        margin_balance: Balance<T>,
        /// leverage size
        leverage: u8,
        /// 1 full position mode, 2 independent position modes.
        position_type: u8,
        /// Position status: 1 normal, 2 normal closing, 3 Forced closing, 4 pending.
        position_status: u8,
        /// 1 buy long, 2 sell short.
        direction: u8,
        /// the position size
        size: u64,
        /// default is 1,Reserved in the future
        lot: u64,
        /// Opening quotation (expected opening price under the listing mode)
        open_price: u64,
        /// Point difference data on which the quotation is based
        open_spread: u64,
        // Actual quotation currently obtained
        open_real_price: u64,
        /// Closing quotation
        close_price: u64,
        /// Point difference data on which the quotation is based
        close_spread: u64,
        // Actual quotation currently obtained
        close_real_price: u64,
        // PL
        profit: u64,
        /// Automatic profit stop price
        stop_surplus_price: u64,
        /// Automatic stop loss price
        stop_loss_price: u64,
        /// Order creation time
        create_time: u64,
        open_time: u64,
        close_time: u64,
        /// The effective time of the order.
        /// If the position is not opened successfully after this time in the order listing mode,
        /// the order will be closed directly
        validity_time: u64,
        /// Opening operator (the user manually, or the clearing robot in the listing mode)
        open_operator: address,
        /// Account number of warehouse closing operator (user manual, or clearing robot Qiangping)
        close_operator: address,
        /// Market account number of the position
        market_account: ID,
        user_account: ID,
    }

    /// The value of lot field in encrypted transaction is 0 by default
    public entry fun open_position<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        token: &mut Coin<T>,
        size: u64,
        lot: u64,
        leverage: u8,
        position_type: u8,
        direction: u8,
        ctx: &mut TxContext
    ) {
        assert!(size > 0, EInvalidSize);
        assert!(lot > 0, EInvalidLot);
        assert!(leverage > 0 && leverage <= market::get_max_leverage(market), EInvalidLeverage);
        assert!(position_type == 1 || position_type == 2, EInvalidPositionType);
        assert!(direction == 1 || direction == 2, EInvalidDirection);
        let price = market::get_price(market);
        let offset = account::get_offset(account) + 1;
        // Calculate margin
        let margin = size * market::get_direction_price(&price,direction) * (leverage as u64) / market::get_margin_rate(market);
        let position = Position<T> {
            id: object::new(ctx),
            offset,
            margin,
            margin_balance: coin::into_balance(coin::split(token,margin,ctx)),
            leverage,
            position_type,
            position_status:1,
            direction,
            size,
            lot,
            open_price: market::get_direction_price(&price,direction),
            open_spread : market::get_spread(market),
            open_real_price: market::get_real_price(&price),
            close_price: 0,
            close_spread: 0,
            close_real_price: 0,
            profit: 0,
            stop_surplus_price: 0,
            stop_loss_price: 0,
            create_time: 0,
            open_time: 0,
            close_time: 0,
            validity_time:0 ,
            open_operator: tx_context::sender(ctx),
            close_operator: @0x0,
            market_account: object::uid_to_inner(market::get_uid(market)),
            user_account: object::uid_to_inner(account::get_uid(account)),
        };
        transfer::share_object(position);
    }
}