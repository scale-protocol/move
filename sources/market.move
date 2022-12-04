module scale::market{
    use sui::object::{UID};
    struct Market has key ,store {
        id: UID,
    }
}