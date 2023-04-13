module scale::event {
    use sui::event;
    use sui::object::ID;

    friend scale::position;
    friend scale::bond;
    friend scale::account;
    friend scale::market;

    struct Created<phantom T> has copy, drop {
        id: ID,
    }
    struct Update<phantom T> has copy, drop {
        id: ID,
    }
    struct Delete<phantom T> has copy, drop {
        id: ID,
    }
    public(friend) fun create<T>(id: ID) {
        event::emit(Created<T> { id: id })
    }
    public(friend) fun update<T>(id: ID) {
        event::emit(Update<T> { id: id })
    }
    public(friend) fun delete<T>(id: ID) {
        event::emit(Delete<T> { id: id })
    }
}