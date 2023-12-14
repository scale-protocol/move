#[lint_allow(self_transfer)]
#[allow(unused_function)]
module scale::bot {
    use sui::object::{Self,UID,ID};
    use scale::pool::{Self,Scale,Pool};
    use scale::market::{Self,List};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self,TxContext,};
    use sui::transfer;
    use scale::admin::AdminCap;
    use sui::vec_map::{Self,VecMap};
    use sui::dynamic_object_field as dof;

    const DENOMINATOR: u64 = 10000;

    const EInvalidPenaltyFee: u64 = 700;
    const EBotNotExists: u64 = 701;
    const EEpochNotMatch: u64 = 702;
    const EInvalidMarketID: u64 = 703;

    friend scale::enter;

    struct ScaleBot<phantom T> has key {
        id: UID,
        // k: epoch, v: score
        total_scores: VecMap<u64,u64>,
        latest_epoch: u64,
        list_id: ID,
        // Reward a portion of profits to the robot
        reward_ratio: u64, 
    }

    public fun create_bot<T>(ctx: &mut TxContext,list_id: ID) {
        transfer::share_object(ScaleBot<T>{
            id: object::new(ctx),
            total_scores: vec_map::empty<u64,u64>(),
            latest_epoch: tx_context::epoch(ctx),
            list_id: list_id,
            // default reward ratio is 5%
            reward_ratio: 500,
        })
    }

    struct Bot has key, store {
        id: UID,
        // k: epoch, v: score
        scores: VecMap<u64,u64>,
        latest_epoch: u64,
    }

    public fun get_uid<T>(scale_bot: &ScaleBot<T>): &UID {
        &scale_bot.id
    }

    public(friend) fun get_uid_mut<T>(scale_bot: &mut ScaleBot<T>): &mut UID {
        &mut scale_bot.id
    }

    public fun get_total_scores<T>(scale_bot: &ScaleBot<T> ,epoch: u64): u64 {
        if (vec_map::contains(&scale_bot.total_scores, &epoch)) {
            *vec_map::get(&scale_bot.total_scores, &epoch)
        } else {
            0
        }
    }

    public fun get_scale_bot_latest_epoch<T>(scale_bot: &ScaleBot<T>): u64 {
        scale_bot.latest_epoch
    }

    public fun get_reward_ratio<T>(scale_bot: &ScaleBot<T>): u64 {
        scale_bot.reward_ratio
    }

    public fun get_scores(bot: &Bot, epoch: u64): u64 {
        if (vec_map::contains(&bot.scores, &epoch)) {
            *vec_map::get(&bot.scores, &epoch)
        } else {
            0
        }
    }

    public fun get_bot_latest_epoch(bot: &Bot): u64 {
        bot.latest_epoch
    }

    public fun register_bot<T>(scale_bot: &mut ScaleBot<T>, ctx: &mut TxContext) {
        let k = tx_context::sender(ctx);
        if (!dof::exists_(&scale_bot.id,k)){
            dof::add(&mut scale_bot.id,k,Bot{
                id: object::new(ctx),
                scores: vec_map::empty<u64,u64>(),
                latest_epoch: tx_context::epoch(ctx),
            });
        }
    }

    fun update_scale_bot_scores<T>(scale_bot: &mut ScaleBot<T>, epoch: u64,score: u64) {
        add_epoch_score(&mut scale_bot.total_scores,epoch,score);
        scale_bot.latest_epoch = epoch;
    }

    fun update_bot_scores(bot: &mut Bot, epoch: u64,score: u64) {
        add_epoch_score(&mut bot.scores,epoch,score);
        bot.latest_epoch = epoch;
    }

    fun reset_epoch_score(vec_map: &mut VecMap<u64,u64>,epoch: u64) {
        if (vec_map::contains(vec_map, &epoch)) {
            let (_, _) = vec_map::remove(vec_map, &epoch);
            vec_map::insert(vec_map, epoch, 0);
        }else{
            vec_map::insert(vec_map, epoch, 0);
        };
    }

    fun add_epoch_score(vec_map: &mut VecMap<u64,u64>, epoch: u64,score: u64) {
        if (vec_map::contains(vec_map, &epoch)) {
            let (_, v) = vec_map::remove(vec_map, &epoch);
            vec_map::insert(vec_map, epoch, score + v);
        }else{
            vec_map::insert(vec_map, epoch, score);
        };
        if (vec_map::size(vec_map) > 90) {
            vec_map::remove_entry_by_idx(vec_map,0);
        }
    }

    public(friend) fun set_scores<T>(scale_bot: &mut ScaleBot<T>, score: u64,ctx: &mut TxContext) {
        let epoch = tx_context::epoch(ctx);
        update_scale_bot_scores(scale_bot,epoch,score);
        let sender = tx_context::sender(ctx);
        if (!dof::exists_(&scale_bot.id,sender)){
            register_bot(scale_bot,ctx);
            return
        };
        let bot: &mut Bot = dof::borrow_mut(&mut scale_bot.id,sender);
        update_bot_scores(bot,epoch,score);
    }

    public fun set_reward_ratio<T>(
        _admin_cap: &mut AdminCap,
        scale_bot: &mut ScaleBot<T>, 
        ratio: u64,
    ){
        assert!(ratio > 0 && ratio <= DENOMINATOR, EInvalidPenaltyFee);
        scale_bot.reward_ratio = ratio;
    }

    public fun receive_reward<T>(
        scale_bot: &mut ScaleBot<T>,
        list: &mut List<T>,
        ctx: &mut TxContext,
    ){
        assert!(scale_bot.list_id == object::id(list), EInvalidMarketID);
        let epoch = tx_context::epoch(ctx);
        assert!(scale_bot.latest_epoch == epoch, EEpochNotMatch);
        // get latest epoch
        epoch = epoch - 1;
        let sender = tx_context::sender(ctx);
        assert!(dof::exists_(&scale_bot.id,sender), EBotNotExists);
        let total_scores = get_total_scores(scale_bot,epoch);
        let bot: &mut Bot = dof::borrow_mut(&mut scale_bot.id,sender);
        let score = get_scores(bot,epoch);
        if (score > 0) {
            let p: &mut Pool<Scale,T> = market::get_pool_mut(list);
            let epoch_profit = pool::get_epoch_profit(p,epoch);
            // let total_reward = epoch_profit * scale_bot.reward_ratio / DENOMINATOR;
            // let reward = total_reward * score / total_scores;
            let reward = epoch_profit * scale_bot.reward_ratio * score / (total_scores * DENOMINATOR);
            if (reward > 0) {
                let c: Coin<T> = coin::from_balance(pool::take_profit_reward(p,reward),ctx);
                transfer::public_transfer(c,sender);
                reset_epoch_score(&mut bot.scores,epoch);
            }
        }
    }
}