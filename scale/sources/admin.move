module scale::admin {
    use sui::object::{Self, UID, ID};
    use sui::vec_set::{Self, VecSet};
    use sui::tx_context::{Self,TxContext};
    use sui::transfer;
    /// Up to 5 administrators can be set
    const MAX_ADMIN_NUM:u8 = 5;

    const EAdminNumberOverflow:u64 = 101;
    const ENoPermission:u64 = 102;
    /// Management voucher, used to achieve certain management capabilities
    /// There is only one super administrator
    struct AdminCap has key {
        id: UID
    }
    /// scale administrator can set multiple
    struct ScaleAdminCap has key, store {
        id: UID,
        object_id: ID,
        /// The market administrator can set other market administrators 
        /// and issue them to the address where the market is created
        admin: address,
        member: VecSet<address>,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        },tx_context::sender(ctx));
    }

    /// Set the object administrator
    public fun create_scale_admin(object_id: ID, ctx: &mut TxContext){
        transfer::share_object(ScaleAdminCap{
            id: object::new(ctx),
            object_id,
            admin: tx_context::sender(ctx),
            member: vec_set::empty(),
        });
    }
    
    public fun get_scale_admin_mum(scale_admin_cap:&ScaleAdminCap):u64{
        vec_set::size(&scale_admin_cap.member)
    }

    public fun is_a_super(admin_cap: &ScaleAdminCap, addr: &address):bool{
        admin_cap.admin == *addr
    }

    public fun is_super_admin(admin_cap: &ScaleAdminCap, addr: &address,id: ID):bool{
        admin_cap.admin == *addr && admin_cap.object_id == id
    }

    public fun is_admin(admin_cap: &ScaleAdminCap, addr: &address,id: ID): bool {
        admin_cap.object_id == id && (admin_cap.admin == *addr || vec_set::contains(&admin_cap.member, addr))
    }

    public fun is_admin_member(admin_cap: &ScaleAdminCap, addr: &address,id: ID): bool {
        vec_set::contains(&admin_cap.member, addr) && admin_cap.object_id == id
    }

    public fun add_admin_member_(admin_cap:&mut ScaleAdminCap, addr: &address){
        if (*addr == admin_cap.admin) return;
        // if (vec_set::contains(&admin_cap.member, addr)) return;
        assert!(vec_set::size(&admin_cap.member) < (MAX_ADMIN_NUM as u64), EAdminNumberOverflow);
        vec_set::insert(&mut admin_cap.member, *addr);
    }

    public fun remove_admin_member_(admin_cap:&mut ScaleAdminCap, addr: &address){
        vec_set::remove(&mut admin_cap.member, addr);
    }

    public fun add_admin_member(admin_cap:&mut ScaleAdminCap, addr: address, ctx: &mut TxContext){
        assert!(is_a_super(admin_cap, &tx_context::sender(ctx)), ENoPermission);
        add_admin_member_(admin_cap, &addr);
    }
    
    public fun remove_admin_member(admin_cap:&mut ScaleAdminCap, addr: address, ctx: &mut TxContext){
        assert!(is_a_super(admin_cap, &tx_context::sender(ctx)), ENoPermission);
        remove_admin_member_(admin_cap, &addr);
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(ctx);
    }
}