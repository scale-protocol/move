module oracle::oracle {
    use std::string::{Self,String};
    use sui::object::{Self,UID};
    use std::vector;
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;
    use sui::dynamic_object_field as dof;
    use sui::clock::{Self,Clock};

    const ENameRequired:u64 = 1;
    const ENameTooLong:u64 = 2;
    const EInvalidTimestamp:u64 = 3;
    const EPriceFeedNotExist:u64 = 4;

    friend oracle::pyth_network;

    struct AdminCap has key {
        id: UID
    }

    struct State has key {
        id: UID,
        total: u64,
        price_timeout_ms: u64,
    }

    struct PriceFeed has key,store {
        id: UID,
        symbol: String,
        price: u64,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        },tx_context::sender(ctx));
        transfer::share_object(State{
            id: object::new(ctx),
            total: 0,
            price_timeout_ms: 3000,
        });
    }

    fun new_price_feed(symbol: vector<u8>, ctx: &mut TxContext): PriceFeed {
        assert!(!vector::is_empty(&symbol), ENameRequired);
        assert!(vector::length(&symbol) < 20, ENameTooLong);
        PriceFeed{
            id: object::new(ctx),
            symbol: string::utf8(symbol),
            price: 0,
            timestamp: 0,
        }
    }

    public entry fun create_price_feed(
        _admin: &mut AdminCap,
        state: &mut State,
        symbol: vector<u8>,
        ctx: &mut TxContext,
    ){
        let price_feed = new_price_feed(symbol,ctx);
        dof::add(&mut state.id,symbol,price_feed);
    }
    #[test_only]
    public fun create_price_feed_for_testing(
        state: &mut State,
        symbol: vector<u8>,
        ctx: &mut TxContext,
    ){
        let price_feed = new_price_feed(symbol,ctx);
        dof::add(&mut state.id,symbol,price_feed);
    }
    public entry fun update_price_timeout(
        _admin: &mut AdminCap,
        state: &mut State,
        timeout_ms: u64,
        _ctx: &TxContext,
    ){
        state.price_timeout_ms = timeout_ms;
    }

    public(friend) fun update_price(
        state: &mut State,
        symbol: vector<u8>,
        price: u64,
        timestamp: u64,
        _ctx: &TxContext
    ){
        let feed: &mut PriceFeed = dof::borrow_mut(&mut state.id, symbol);
        assert!(timestamp > feed.timestamp, EInvalidTimestamp);
        feed.price = price;
        feed.timestamp = timestamp;
    }

    public fun get_price(state: &State, symbol: vector<u8>,c: &Clock): (u64, u64){
        assert!(dof::exists_(&state.id,symbol),EPriceFeedNotExist);
        let feed: &PriceFeed = dof::borrow(&state.id, symbol);
        let current_time_ms = clock::timestamp_ms(c);
        let feed_timestamp_ms = feed.timestamp * 1000;
        assert!(current_time_ms >= feed_timestamp_ms, EInvalidTimestamp);
        assert!(current_time_ms - feed_timestamp_ms <= state.price_timeout_ms, EInvalidTimestamp);
        (feed.price, feed_timestamp_ms)
    }
    
    #[test_only]
    public fun update_price_for_testing(
        state: &mut State,
        symbol: vector<u8>,
        price: u64,
        timestamp: u64,
        _ctx: &TxContext
    ){
        update_price(state,symbol,price,timestamp,_ctx);
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
    public fun get_uid(state: &State): &UID {
        &state.id
    }
}