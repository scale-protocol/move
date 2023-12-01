#[lint_allow(self_transfer)]
module sui_coin::scale {
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Supply};
    use std::option;
    use std::vector;
    use sui::pay;
    use sui::url;

    const DECIMALS:u8 = 6;
    const AIRDROP_MAX_LIMIT: u64 = 10000_000000;

    const EInvalidAmount:u64=2;
    const EInvalidStatus:u64=3;
    const EAirdropStop:u64=4;
    const EOverflowLimit:u64=5;
    // scale token like usdc usdt
    struct SCALE has drop{}
    // Used to store su token balance
    struct Reserve has key {
        id: UID,
        status: u8,// 1: normal, 2: frozen
        total_supply: Supply<SCALE>,
        scale_decimals: u8,
    }

    struct AdminCap has key{
        id: UID,
    }

    fun init(witness: SCALE, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness, 
            DECIMALS,
            b"SCALE",
            b"Scale",
            b"The Scale token is a test token used for development network and test network. see https://scale.exchange",
            // icon url
            option::some(url::new_unsafe_from_bytes(b"https://bafybeibzo7s6gmeqybbecqhr2qaedjwxeprumg5kft5rvwicg2lpqzmo7y.ipfs.w3s.link/scale.png")),
            ctx
        );
        transfer::public_freeze_object(metadata);
        let total_supply = coin::treasury_into_supply(treasury);
        transfer::share_object(Reserve {
            id: object::new(ctx),
            status: 1,
            total_supply,
            scale_decimals: DECIMALS,
        });
        transfer::transfer(AdminCap{id: object::new(ctx)}, tx_context::sender(ctx));
    }
    public fun get_status(reserve: &Reserve) : u8{
        reserve.status
    }
    public fun get_scale_decimals(reserve: &Reserve) : u8{
        reserve.scale_decimals
    }

    public fun get_total_supply(reserve: &Reserve) : &Supply<SCALE>{
        &reserve.total_supply
    }

    /// Airdrop SCALE tokens. In order to prevent malicious operation of robots, the number of SCALE tokens that can be airdropped at a time is limited.
    public entry fun airdrop(
        reserve: &mut Reserve,
        amount: u64,
        ctx: &mut TxContext
    ){
        assert!(amount > 0, EInvalidAmount);
        assert!(amount <= AIRDROP_MAX_LIMIT, EOverflowLimit);
        assert!(reserve.status == 1, EAirdropStop);
        mint_to(reserve,amount,ctx)
    }

    public entry fun mint(
        _cap: &mut AdminCap,
        reserve: &mut Reserve,
        amount: u64,
        ctx: &mut TxContext
    ){
        assert!(amount > 0, EInvalidAmount);
        mint_to(reserve,amount,ctx)
    }
    fun mint_to(reserve: &mut Reserve, amount: u64,ctx: &mut TxContext){
        transfer::public_transfer(coin::from_balance(balance::increase_supply(&mut reserve.total_supply, amount), ctx),tx_context::sender(ctx));
    }
    public entry fun set_staatus(
        _cap: &mut AdminCap,
        reserve: &mut Reserve,
        status: u8,
        _ctx: &mut TxContext
    ){
        assert!(status == 1 || status == 2, EInvalidStatus);
        reserve.status = status;
    }
    /// Withdraw sui token
    public entry fun burn(
        reserve: &mut Reserve,
        scales: vector<Coin<SCALE>>,
        _ctx: &mut TxContext
    ) {
        let scale = vector::pop_back(&mut scales);
        pay::join_vec(&mut scale, scales);
        assert!(coin::value(&scale) > 0, EInvalidAmount);
        let _num_scale = balance::decrease_supply(&mut reserve.total_supply, coin::into_balance(scale));
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SCALE{},ctx);
    }
}
#[test_only]
module sui_coin::test_scale{
    use sui::coin::{Coin};
    use sui::balance;
    use sui_coin::scale::{Self , AdminCap};
    use sui::test_scenario;
    use std::debug;
    use std::vector;
    #[test]
    fun test_init(){
        let owner = @0x1;
        // let the_guy = @0x2;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, owner);
        {
            scale::init_for_testing(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            assert!(scale::get_scale_decimals(&reserve) == 6, 2);
            assert!(balance::supply_value(scale::get_total_supply(&reserve)) == 0, 4);
            test_scenario::return_shared(reserve);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            debug::print(&admin_cap);
            test_scenario::return_to_sender(scenario,admin_cap);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
     #[expected_failure(abort_code = 4, location = scale)]
    fun test_airdrop_and_burn(){
        let owner = @0x1;
        // let the_guy = @0x2;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, owner);
        {
            scale::init_for_testing(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            scale::airdrop(&mut reserve, 10_0000, test_scenario::ctx(scenario));
            assert!(balance::supply_value(scale::get_total_supply(&reserve)) == 10_0000, 2);
            test_scenario::return_shared(reserve);
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            let scale = test_scenario::take_from_sender<Coin<scale::SCALE>>(scenario);
            let scales = vector::empty<Coin<scale::SCALE>>();
            vector::push_back(&mut scales,scale);
            scale::burn(&mut reserve, scales, test_scenario::ctx(scenario));
            assert!(balance::supply_value(scale::get_total_supply(&reserve)) == 0, 4);
            test_scenario::return_shared(reserve);
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            scale::set_staatus(&mut admin_cap, &mut reserve, 2, test_scenario::ctx(scenario));
            assert!(scale::get_status(&reserve) == 2, 6);
            test_scenario::return_shared(reserve);
            test_scenario::return_to_sender(scenario,admin_cap);
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            scale::airdrop(&mut reserve, 10_0000, test_scenario::ctx(scenario));
            test_scenario::return_shared(reserve);
        };
        test_scenario::end(scenario_val);
    }
}