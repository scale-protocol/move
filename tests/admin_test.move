#[test_only]
module scale::admin_tests{
    use scale::admin;
    use sui::test_scenario;
    use std::debug;
    #[test]
    fun test_create_scale_admin(){
        let owner=@0x1;
        let test_tx=test_scenario::begin(owner);
        let tx=&mut test_tx;
        test_scenario::next_tx(tx,owner);
        {
            admin::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<admin::AdminCap>(tx);
            let scale_admin = test_scenario::take_shared<admin::ScaleAdminCap>(tx);
            debug::print(&admin_cap);
            assert!(admin::is_admin(&scale_admin,&owner),1);
            assert!(!admin::is_admin(&scale_admin,&(@0x2)),2);

            test_scenario::return_shared(scale_admin);
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::end(test_tx);
    }
    #[test]
    fun test_add_admin_member(){
        let owner=@0x1;
        let owner2=@0x2;
        let owner3=@0x3;
        let owner4=@0x5;
        let owner5=@0x5;
        let owner6=@0x6;
        let owner7=@0x7;
        let test_tx=test_scenario::begin(owner);
        let tx=&mut test_tx;
        test_scenario::next_tx(tx,owner);
        {
            admin::init_for_testing(test_scenario::ctx(tx));
        };
        test_scenario::next_tx(tx,owner);
        {
            let admin_cap = test_scenario::take_from_sender<admin::AdminCap>(tx);
            let scale_admin = test_scenario::take_shared<admin::ScaleAdminCap>(tx);
            admin::add_admin_member(&mut scale_admin,&owner2);

            assert!(admin::is_admin(&scale_admin,&owner),1);
            assert!(admin::is_admin(&scale_admin,&owner2),2);

            admin::add_admin_member(&mut scale_admin,&owner);
            admin::add_admin_member(&mut scale_admin,&owner2);
            assert!(admin::get_scale_admin_mum(&scale_admin)==1,1);

            admin::add_admin_member(&mut scale_admin,&owner3);
            admin::add_admin_member(&mut scale_admin,&owner4);
            admin::add_admin_member(&mut scale_admin,&owner5);
            admin::add_admin_member(&mut scale_admin,&owner6);
            assert!(admin::get_scale_admin_mum(&scale_admin)==5,1);

            // admin::add_admin_member(&mut scale_admin,&owner7);
            test_scenario::return_shared(scale_admin);
            test_scenario::return_to_sender(tx,admin_cap);
        };
        test_scenario::end(test_tx);
    }
}