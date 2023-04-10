module scale::event {
    use sui::event;
    use sui::object::ID;
    struct Created<phantom T> has copy, drop {
        id: ID,
    }
    struct Update<phantom T> has copy, drop {
        id: ID,
    }
    struct Delete<phantom T> has copy, drop {
        id: ID,
    }
    public fun create<T>(id: ID) {
        event::emit(Created<T> { id: id })
    }
    public fun update<T>(id: ID) {
        event::emit(Update<T> { id: id })
    }
    public fun delete<T>(id: ID) {
        event::emit(Delete<T> { id: id })
    }
}