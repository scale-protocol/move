#[lint_allow(self_transfer)]
#[allow(unused_function)]
module scale::bot {
    use sui::object::{Self,UID,ID};
    use std::string::{Self,utf8, String};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self,Balance};
    use scale::pool::{Self,LSP,Scale};
    use scale::market::{Self,List};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self,TxContext,sender};
    use std::vector;
    use sui::transfer;
    use sui::table::{Self,Table};
    use scale::admin::AdminCap;
    use sui::dynamic_field as field;
    use scale::event;
    use sui::package::{Self, Publisher};
    use sui::display;
    use sui::vec_map::{Self,VecMap};
    use sui::dynamic_object_field as dof;

    const DENOMINATOR: u64 = 10000;

    struct ScaleBot<phantom T> has key, store {
        id: UID,
        // k: epoch, v: score
        total_scores: VecMap<u64,u64>,
        latest_epoch: u64,
        // Reward a portion of profits to the robot
        reward_ratio: u64, 
    }

    public fun create_bot<T>(ctx: &mut TxContext) {
        transfer::share_object(ScaleBot<T>{
            id: object::new(ctx),
            total_scores: vec_map::empty<u64,u64>(),
            latest_epoch: tx_context::epoch(ctx),
            // default reward ratio is 20%
            reward_ratio: 2000,
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

    public fun get_scores<T>(bot: &Bot, epoch: u64): u64 {
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
}