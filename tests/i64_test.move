#[test_only]
module scale::i64_tests {
    use scale::i64;
    use std::debug;
    #[test]
    fun test_new() {
        let i = i64::new(0, false);
        debug::print(&i);
        assert!(i64::get_value(&i) == 0 && !i64::is_negative(&i), 1);
        let i = i64::new(9_223_372_036_854_775_807, false);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_807 && !i64::is_negative(&i), 2);
        let i = i64::new(9_223_372_036_854_775_808, true);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_808 && i64::is_negative(&i), 3);
    }
    #[test]
    #[expected_failure(abort_code = 1, location = i64)]
    fun test_positive_overflow() {
        let i = i64::new(9_223_372_036_854_775_809, false);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_808 && !i64::is_negative(&i), 2);
    }
    #[test]
    #[expected_failure(abort_code = 1, location = i64)]
    fun test_negative_overflow() {
        let i = i64::new(9_223_372_036_854_775_809, true);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_809 && !i64::is_negative(&i), 2);
    }
    #[test]
    fun test_u64_add(){
        let i = i64::u64_add(1,2);
        assert!(i64::get_value(&i) == 3 && !i64::is_negative(&i), 1);
        let i = i64::u64_add(0, 1);
        assert!(i64::get_value(&i) == 1 && !i64::is_negative(&i), 2);
    }
    #[test]
    fun test_u64_sub(){
        let i = i64::u64_sub(1,2);
        assert!(i64::get_value(&i) == 1 && i64::is_negative(&i), 1);
        let i = i64::u64_sub(0, 1);
        assert!(i64::get_value(&i) == 1 && i64::is_negative(&i), 2);
        let i = i64::u64_sub(1, 0);
        assert!(i64::get_value(&i) == 1 && !i64::is_negative(&i), 3);
        let i = i64::u64_sub(100, 1);
        assert!(i64::get_value(&i) == 99 && !i64::is_negative(&i), 4);
    }
    #[test]
    fun test_inc_u64(){
        let i = i64::new(0, false);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 1 && !i64::is_negative(&i), 1);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 2 && !i64::is_negative(&i), 2);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 3 && !i64::is_negative(&i), 3);
        let i = i64::new(100, true);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 99 && i64::is_negative(&i), 4);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 98 && i64::is_negative(&i), 5);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 97 && i64::is_negative(&i), 6);
        i64::inc_u64(&mut i, 9_223_372_036_854_775_808);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_711 && !i64::is_negative(&i), 7);
    }
    #[test]
    #[expected_failure(abort_code = 1, location = i64)]
    fun test_inc_u64_overflow(){
        let i = i64::new(9_223_372_036_854_775_807, false);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_808 && !i64::is_negative(&i), 1);
    }
    #[test]
    fun test_inc_u64_overflow1(){
        let i = i64::new(9_223_372_036_854_775_808, true);
        i64::inc_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_807 && i64::is_negative(&i), 2);
    }
    #[test]
    fun test_dec_u64(){
        let i = i64::new(0, false);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 1 && i64::is_negative(&i), 1);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 2 && i64::is_negative(&i), 2);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 3 && i64::is_negative(&i), 3);
        let i = i64::new(100, true);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 101 && i64::is_negative(&i), 4);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 102 && i64::is_negative(&i), 5);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 103 && i64::is_negative(&i), 6);
        i64::dec_u64(&mut i, 9_223_372_036_854_775_705);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_808 && i64::is_negative(&i), 7);
    }
    #[test]
    #[expected_failure(abort_code = 1, location = i64)]
    fun test_dec_u64_overflow(){
        let i = i64::new(9_223_372_036_854_775_808, true);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_809 && i64::is_negative(&i), 1);
    }
    #[test]
    #[expected_failure(abort_code = 1, location = i64)]
    fun test_dec_u64_overflow1(){
        let i = i64::new(9_223_372_036_854_775_808, false);
        i64::dec_u64(&mut i, 1);
        assert!(i64::get_value(&i) == 9_223_372_036_854_775_809 && !i64::is_negative(&i), 2);
    }
}