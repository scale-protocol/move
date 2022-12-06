#[test_only]
module scale::admin_tests{
    use scale::admin;
    use sui::test_scenario;
    use std::debug;
    use sui::object::{Self,UID};
    use sui::transfer;
    use sui::tx_context;

    struct O has key {
        id: UID
    }
    #[test]
    fun test_create_scale_admin(){
        let owner = @0x1;
        let test_tx = test_scenario::begin(owner);
        let tx = &mut test_tx;

        test_scenario::next_tx(tx,owner);
        {
            admin::init_for_testing(test_scenario::ctx(tx));
            let uid = object::new(test_scenario::ctx(tx));
            let id = object::uid_to_inner(&uid);
            let o = O { id: uid };
            transfer::transfer(o,tx_context::sender(test_scenario::ctx(tx)));
            admin::create_scale_admin(test_scenario::ctx(tx), id);
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<admin::AdminCap>(tx);
            let o = test_scenario::take_from_sender<O>(tx);

            let scale_admin = test_scenario::take_shared<admin::ScaleAdminCap>(tx);
            debug::print(&admin_cap);
            assert!(admin::is_admin(&scale_admin,&owner,object::uid_to_inner(&o.id)),1);
            assert!(!admin::is_admin(&scale_admin,&(@0x2),object::uid_to_inner(&o.id)),2);

            test_scenario::return_shared(scale_admin);
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_to_sender(tx,o);
        };
        test_scenario::end(test_tx);
    }
    #[test]
    fun test_add_admin_member(){
        let owner=@0x1;
        let owner2=@0x2;

        let test_tx=test_scenario::begin(owner);
        let tx=&mut test_tx;
        test_scenario::next_tx(tx,owner);
        {
            admin::init_for_testing(test_scenario::ctx(tx));
            let uid = object::new(test_scenario::ctx(tx));
            let id = object::uid_to_inner(&uid);
            let o = O { id: uid };
            transfer::transfer(o,tx_context::sender(test_scenario::ctx(tx)));
            admin::create_scale_admin(test_scenario::ctx(tx), id);
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<admin::AdminCap>(tx);
            let o = test_scenario::take_from_sender<O>(tx);
            let scale_admin = test_scenario::take_shared<admin::ScaleAdminCap>(tx);

            admin::add_admin_member(&mut scale_admin,&owner);
            admin::add_admin_member(&mut scale_admin,&owner2);

            assert!(admin::is_admin(&scale_admin,&owner,object::uid_to_inner(&o.id)),1);
            assert!(admin::is_admin(&scale_admin,&owner2,object::uid_to_inner(&o.id)),2);

            assert!(admin::is_super_admin(&scale_admin,&tx_context::sender(test_scenario::ctx(tx)),object::uid_to_inner(&o.id)),3);
            assert!(admin::is_super_admin(&scale_admin,&owner,object::uid_to_inner(&o.id)),4);
            assert!(!admin::is_super_admin(&scale_admin,&owner2,object::uid_to_inner(&o.id)),5);

            assert!(!admin::is_admin_member(&scale_admin,&owner,object::uid_to_inner(&o.id)),6);
            assert!(admin::is_admin_member(&scale_admin,&owner2,object::uid_to_inner(&o.id)),7);

            assert!(admin::get_scale_admin_mum(&scale_admin)==1,1);
            admin::add_admin_member(&mut scale_admin,&(@0xA));
            admin::add_admin_member(&mut scale_admin,&(@0xF));
            admin::add_admin_member(&mut scale_admin,&(@0xB));
            admin::add_admin_member(&mut scale_admin,&(@0xC));
            assert!(admin::get_scale_admin_mum(&scale_admin) == 5,2);

            // admin::add_admin_member(&mut scale_admin,&(@0xD));
            debug::print(&admin::get_scale_admin_mum(&scale_admin));
            test_scenario::return_shared(scale_admin);
            test_scenario::return_to_sender(tx,admin_cap);
            test_scenario::return_to_sender(tx,o);
        };
        test_scenario::end(test_tx);
    }
}