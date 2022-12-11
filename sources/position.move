module scale::position {
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::balance::{Balance};
    use scale::market::{Self,Market,Price};
    use scale::account::{Self,Account,PFK};
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;
    use sui::dynamic_object_field as dof;
    use std::option::{Self,Option};
    // use sui::dynamic_field as df;/

    const EInvalidLot:u64 = 2;
    const EInvalidLeverage:u64 = 3;
    const EInvalidPositionType:u64 = 4;
    const EInvalidDirection:u64 = 5;
    const ENoPermission:u64 = 6;
    const EInvalidPositionStatus:u64 = 7;

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
        /// lot size
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
        market_id: ID,
        account_id: ID,
    }
    public fun get_fund_size<P,T>(position: &Position<T>) :u64 {
        position.size * position.lot * position.open_price
    }
    fun create_position_inner<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        margin: u64,
        token: &mut Coin<T>,
        leverage: u8,
        position_type: u8,
        direction: u8,
        lot: u64,
        price: &Price,
        ctx: &mut TxContext
    ) :Position<T> {
        let offset = account::get_offset(account) + 1;
        Position<T> {
            id: object::new(ctx),
            offset,
            margin,
            margin_balance: coin::into_balance(coin::split(token,margin,ctx)),
            leverage,
            position_type,
            position_status:1,
            direction,
            size: market::get_size(market),
            lot,
            open_price: market::get_direction_price(price,direction),
            open_spread : market::get_spread(market),
            open_real_price: market::get_real_price(price),
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
            market_id: object::id(market),
            account_id: object::id(account),
        }
    }

    public fun merge_position<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        pfk: &PFK,
        size: u64,
        leverage: u8,
        direction: u8,
        lot: u64,
        price: &mut Price,
        ctx: &mut TxContext
    ) {
        // Check if the full position already exists
        if ( account::contains_pfk(account,pfk) ){
            let id = account::get_pfk_id(account,pfk);
            let position: &mut Position<T> = dof::borrow_mut(account::get_uid_mut(account),id);
            assert!(position.position_status == 1,EInvalidPositionStatus);

            let fund_size = get_fund_size<P,T>(position) + size * lot * market::get_direction_price(price,direction);
            // Reset average price
            market::set_direction_price(price,direction, fund_size / (size * lot + position.size * position.lot));
            position.open_price = market::get_direction_price(price,direction);
            position.open_spread = market::get_spread(market);
            position.open_real_price = market::get_real_price(price);
            position.lot = position.lot + lot;
            position.leverage = leverage;
            position.open_time = 0;
        };
    }
    /// The value of lot field in encrypted transaction is 0 by default
    public entry fun open_position<P,T>(
        market: &mut Market<P,T>,
        account: &mut Account<T>,
        token: &mut Coin<T>,
        lot: u64,
        leverage: u8,
        position_type: u8,
        direction: u8,
        ctx: &mut TxContext
    ) {
        assert!(lot > 0, EInvalidLot);
        assert!(leverage > 0 && leverage <= market::get_max_leverage(market), EInvalidLeverage);
        assert!(position_type == 1 || position_type == 2, EInvalidPositionType);
        assert!(direction == 1 || direction == 2, EInvalidDirection);
        assert!(tx_context::sender(ctx) == account::get_owner(account), ENoPermission);

        let price = market::get_price(market);
        let size = market::get_size(market);
        let pfk = account::new_PFK<T>(object::id(market),object::id(account),direction);
        if (position_type == 1){

        };
        
        // Calculate margin
        let margin = size * market::get_direction_price(&price,direction) * (leverage as u64) / market::get_margin_rate(market);
        let position = create_position_inner(
            market,
            account,
            margin,
            token,
            leverage,
            position_type,
            direction,
            lot,
            &price,
            ctx);
        transfer::share_object(position);
    }
}