#[test_only]
module scale::account_tests {
    use sui::object::{Self,ID};
    use sui::vec_map;
    use std::debug;
    use sui::test_scenario;

    struct PFK has store,copy,drop {
        market_id: ID,
        account_id: ID,
        direction: u8,
    }
    #[test]
    fun test_vec_map(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;
        let muid = object::new(test_scenario::ctx(tx));
        let auid = object::new(test_scenario::ctx(tx));
        let id = object::uid_to_inner(&muid);
        debug::print(&muid);
        debug::print(&auid);
        debug::print(&id);
        let pfk = PFK {
            market_id: object::uid_to_inner(&muid),
            account_id: object::uid_to_inner(&auid),
            direction: 1,
        };
        let vmp = vec_map::empty<PFK,ID>();
        vec_map::insert(&mut vmp, pfk, id);
        let id1 = vec_map::get(&vmp, &pfk);
        assert!(id1 == &id,1);

        let pfk2 = PFK {
            market_id: object::uid_to_inner(&muid),
            account_id: object::uid_to_inner(&auid),
            direction: 1,
        };
        let id2 = vec_map::get(&vmp, &pfk2);
        assert!(id2 == &id,2);
        object::delete(muid);
        object::delete(auid);

        test_scenario::end(test_tx);
    }
}