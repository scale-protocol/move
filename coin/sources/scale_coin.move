module sui_coin::scale {
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance, Supply};
    use sui::sui::SUI;

    const DECIMALS:u64 = 6;
    // Default One SUI for 100000 SCALE
    const SUBSCRIPTION_RATIO:u64 = 100;

    const EInsufficientBalanceOfSui:u64=1;

    const EInvalidAmount:u64=2;
    const EInvalidRatio:u64=3;
    // scale token like usdc usdt
    struct SCALE has drop{}
    // Used to store su token balance
    struct Reserve has key {
        id: UID,
        sui: Balance<SUI>,
        total_supply: Supply<SCALE>,
        subscription_ratio: u64,
        scale_decimals: u64,
    }
    struct AdminCap has key{
        id: UID,
    }
    fun init(witness: SCALE, ctx: &mut TxContext) {
        let total_supply = balance::create_supply<SCALE>(witness);
        transfer::share_object(Reserve {
            id: object::new(ctx),
            total_supply,
            sui: balance::zero<SUI>(),
            subscription_ratio: SUBSCRIPTION_RATIO,
            scale_decimals: DECIMALS,
        });
        transfer::transfer(AdminCap{id: object::new(ctx)}, tx_context::sender(ctx));
    }

    public fun get_subscription_ratio(reserve: &Reserve) : u64{
        reserve.subscription_ratio
    }
    public fun get_scale_decimals(reserve: &Reserve) : u64{
        reserve.scale_decimals
    }
    public fun get_sui_balance(reserve: &Reserve) : &Balance<SUI>{
        &reserve.sui
    }
    public fun get_total_supply(reserve: &Reserve) : &Supply<SCALE>{
        &reserve.total_supply
    }
    /// set subscription ratio
    public entry fun set_subscription_ratio(
        _admin_cap: &mut AdminCap,
        reserve: &mut Reserve,
        ratio: u64,
        _ctx: &mut TxContext
    ) {
        assert!(ratio > 0, EInvalidRatio);
        reserve.subscription_ratio = ratio;
    }
    /// Airdrop SCALE tokens. In order to prevent malicious operation of robots, 
    /// you need to use the sui token 1:10000 for exchange
    public entry fun airdrop(
        reserve: &mut Reserve,
        sui: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ){
        assert!(amount > 0, EInvalidAmount);
        let need_sui = amount / reserve.subscription_ratio;
        let sui_balance = coin::balance_mut(sui);
        assert!(balance::value(sui_balance) >= need_sui, EInsufficientBalanceOfSui);
        balance::join(&mut reserve.sui, balance::split(sui_balance, need_sui));
        
        let mint_balance = balance::increase_supply(&mut reserve.total_supply, amount);
        transfer::transfer(coin::from_balance(mint_balance, ctx),tx_context::sender(ctx));
    }
    /// Withdraw sui token
    public entry fun burn(
        reserve: &mut Reserve,
        scale: Coin<SCALE>,
        ctx: &mut TxContext
    ) {
        assert!(coin::value(&scale) > 0, EInvalidAmount);
        let num_scale = balance::decrease_supply(&mut reserve.total_supply, coin::into_balance(scale));
        let sui = coin::take(&mut reserve.sui, num_scale / reserve.subscription_ratio, ctx);
        transfer::transfer(sui, tx_context::sender(ctx));
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SCALE{},ctx);
    }
}
#[test_only]
module sui_coin::test_scale{
    use sui::coin::{Self,Coin};
     use sui::sui::SUI;
    use sui::balance;
    use sui_coin::scale::{Self , AdminCap};
    use sui::test_scenario;
    use std::debug;
    use sui::transfer;
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
            assert!(scale::get_subscription_ratio(&reserve) == 100, 1);
            assert!(scale::get_scale_decimals(&reserve) == 6, 2);
            assert!(balance::value(scale::get_sui_balance(&reserve)) == 0, 3);
            assert!(balance::supply_value(scale::get_total_supply(&reserve)) == 0, 4);
            test_scenario::return_shared(reserve);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            debug::print(&admin_cap);
            test_scenario::return_to_sender(scenario,admin_cap);
        };
        test_scenario::end(scenario_val);
    }
    #[test]
    fun test_set_subscription_ratio(){
        let owner = @0x1;
        let the_guy = @0x2;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, owner);
        {
            scale::init_for_testing(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            scale::set_subscription_ratio(&mut admin_cap, &mut reserve, 10000, test_scenario::ctx(scenario));
            assert!(scale::get_subscription_ratio(&reserve) == 10000, 1);
            test_scenario::return_shared(reserve);
            test_scenario::return_to_sender(scenario,admin_cap);
        };
        test_scenario::next_tx(scenario, the_guy);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            assert!(scale::get_subscription_ratio(&reserve) == 10000, 1);
            test_scenario::return_shared(reserve);
        };
        test_scenario::end(scenario_val);
    }
    #[test]
    fun test_airdrop_and_burn(){
        let owner = @0x1;
        let the_guy = @0x2;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        test_scenario::next_tx(scenario, owner);
        {
            scale::init_for_testing(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let sui = coin::mint_for_testing<SUI>(10_0000, test_scenario::ctx(scenario));

            scale::airdrop(&mut reserve, &mut sui, 10_0000, test_scenario::ctx(scenario));
            assert!(balance::value(scale::get_sui_balance(&reserve)) == 10_0000/100, 1);
            assert!(balance::supply_value(scale::get_total_supply(&reserve)) == 10_0000, 2);
            assert!(coin::value(&sui) == 10_0000 - 10_0000/100, 3);
            test_scenario::return_shared(reserve);
            test_scenario::return_to_sender(scenario,admin_cap);
            transfer::transfer(sui, the_guy);
        };
        test_scenario::next_tx(scenario, owner);
        {
            let reserve = test_scenario::take_shared<scale::Reserve>(scenario);
            let scale = test_scenario::take_from_sender<Coin<scale::SCALE>>(scenario);
            scale::burn(&mut reserve, scale, test_scenario::ctx(scenario));
            assert!(balance::value(scale::get_sui_balance(&reserve)) == 0, 1);
            assert!(balance::supply_value(scale::get_total_supply(&reserve)) == 0, 2);
            test_scenario::return_shared(reserve);
        };
        test_scenario::next_tx(scenario, owner);
        {
            let sui = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            debug::print(&sui);
            assert!(coin::value(&sui) == 10_0000/100, 3);
            transfer::transfer(sui, owner);
        };
        test_scenario::end(scenario_val);
    }
}