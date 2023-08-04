module oracle::pyth_network {
    // use wormhole::vaa::{Self, VAA};
    // use wormhole::state::{State as WmState};
    use pyth::state::{ State as PythState};
    use pyth::pyth;
    use pyth::price_info::PriceInfoObject;
    use sui::clock::Clock;
    use std::vector;
    // use sui::coin;
    // use pyth::hot_potato_vector;
    // use sui::sui::{SUI};
    // use sui::pay;
    // use sui::tx_context::{Self,TxContext};
    use sui::tx_context::TxContext;
    use sui::transfer;
    use sui::object::{Self,UID,ID};
    use sui::vec_map::{Self,VecMap};
    use oracle::oracle::{Self,AdminCap};
    use pyth::price::{Self,Price};
    use pyth::i64;

    const DECIMALS: u64 = 1000000;

    struct State has key{
        id : UID,
        symbol_price_mp: VecMap<ID,vector<u8>>,
    }

    fun init(ctx: &mut TxContext){
        transfer::share_object(State{
            id: object::new(ctx),
            symbol_price_mp: vec_map::empty<ID,vector<u8>>(),
        });
    }

    public entry fun update_symbol(
        symbol: vector<u8>,
        info: &PriceInfoObject,
        state: &mut State,
        _cap: &mut AdminCap,
        _ctx: &TxContext
    ){
        let id = object::id(info);
        if (vec_map::contains(&state.symbol_price_mp,&id)){
            vec_map::remove(&mut state.symbol_price_mp,&id);
        };
        vec_map::insert(&mut state.symbol_price_mp,id,symbol);
    }

    public entry fun async_pyth_price(
        price_info: &PriceInfoObject,
        pyth_state: &PythState,
        curr_state: &State,
        oracle_state: &mut oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ){
        let price = pyth::get_price(pyth_state, price_info, c);
        let symbol = vec_map::get(&curr_state.symbol_price_mp,&object::id(price_info));
        let p = get_price_value(&price);
        let t = price::get_timestamp(&price);
        oracle::update_price(oracle_state, *symbol,p , t,ctx);
    }

    public fun async_pyth_price_bat(
        price_info: vector<PriceInfoObject>,
        pyth_state: &PythState,
        curr_state: &State,
        oracle_state: &mut oracle::State,
        c: &Clock,
        ctx: &mut TxContext
    ): vector<PriceInfoObject> {
        let i = 0;
        while (i < vector::length(&price_info)) {
            let pi = vector::borrow_mut(&mut price_info,i);
            async_pyth_price(pi,pyth_state,curr_state,oracle_state,c,ctx);
            i = i + 1;
        };
        price_info
    }
    
    // public fun update_pyth_price_bat(
    //     coins: vector<Coin<SUI>>,
    //     vaa_data: vector<vector<u8>>,
    //     price_infos: vector<PriceInfoObject>,
    //     worm_state: &mut WmState,
    //     pyth_state: &mut PythState,
    //     curr_state: &mut State,
    //     oracle_state: &mut oracle::State,
    //     c: &Clock,
    //     ctx: &mut TxContext
    // ) :vector<PriceInfoObject> {
    //     let i = 0;
    //     let verified_vaas = vector::empty<VAA>();
    //     while (i < vector::length(&vaa_data)) {
    //         let v = vector::pop_back(&mut vaa_data);
    //         let vaa_vf = vaa::parse_and_verify(worm_state, v, c);
    //         vector::push_back(&mut verified_vaas, vaa_vf);
    //         i = i + 1;
    //     };
    //     let hot_potato = pyth::create_price_infos_hot_potato(pyth_state, verified_vaas,c);
    //     i=0;
    //     let token = vector::pop_back(&mut coins);
    //     pay::join_vec(&mut token, coins);
    //     let fee = state::get_base_update_fee(pyth_state) / 5;
    //     if (fee ==0 ){
    //         fee = 1;
    //      }
    //     while (i < vector::length(&price_infos)) {
    //         let pi = vector::borrow_mut(&mut price_infos,i);
    //         hot_potato = pyth::update_single_price_feed(pyth_state, hot_potato, pi, coin::split(&mut token,fee,ctx), c);
    //         let price = pyth::get_price(pyth_state, pi, c);
    //         let symbol = vec_map::get(&curr_state.symbol_price_mp,&object::id(pi));
    //         let p = get_price_value(&price);
    //         let t = price::get_timestamp(&price);
    //         oracle::update_price(oracle_state, *symbol,p , t,ctx);
    //         i = i + 1;
    //     };
    //     transfer::public_transfer(token,tx_context::sender(ctx));
    //     hot_potato_vector::destroy(hot_potato);
    //     price_infos
    // }

    fun get_price_value(p: &Price):u64{
        let pr = price::get_price(p);
        if (i64::get_is_negative(&pr)){
            return 0
        };
        let pow = i64::get_magnitude_if_negative(&price::get_expo(p));
        let i = 0;
        let val = 10;
        while (i < pow){
            val = val * 10;
            i = i + 1;
        };
        i64::get_magnitude_if_positive(&pr) * DECIMALS / val
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
}