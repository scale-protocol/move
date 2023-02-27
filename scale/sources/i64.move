module scale::i64 {
    // + 9_223_372_036_854_775_807
    const MAX_POSITIVE: u64 = (1 << 63) - 1;
    // - -9_223_372_036_854_775_808
    const MAX_NEGATIVE: u64 = (1 << 63);

    // const MAX_U64_VALUE: u128 = 18446744073709551615;
    const ENumericOverflow: u64 = 1;
    const ENegative: u64 = 2;
    const EPositive: u64 = 3;
    #[test_only]
    public fun get_max_positive(): u64 {
        MAX_POSITIVE
    }
    #[test_only]
    public fun get_max_negative(): u64 {
        MAX_NEGATIVE
    }

    struct I64 has copy, drop, store {
        negative: bool,
        value: u64,
    }

    public fun is_negative(i: &I64): bool {
        i.negative
    }

    public fun get_value(i: &I64): u64 {
        i.value
    }

    public fun new(value: u64, negative: bool): I64 {
        let max_value = MAX_POSITIVE;
        if (negative) {
            max_value = MAX_NEGATIVE;
        };
        assert!(value <= max_value, ENumericOverflow);
        if (value == 0) {
            negative = false;
        };

        I64 {
            value,
            negative,
        }
    }
    // get + value
    public fun get_positive(i: &I64): u64 {
        assert!(!i.negative, EPositive);
        i.value
    }
    // get - value
    public fun get_negative(i: &I64): u64 {
        assert!(i.negative, ENegative);
        i.value
    }
    
    public fun u64_add(u: u64, u2:u64): I64 {
        new(u + u2,false)
    }

    public fun u64_sub(u: u64, u2:u64): I64{
        if (u < u2) {
            new(u2 - u,true)
        }else{
            new(u - u2,false)
        }
    }

    public fun i64_add(i: &I64, i2: &I64): I64 {
        if (i.negative && i2.negative) {
            new(i.value + i2.value,true)
        } else if (!(i.negative || i2.negative)){
            new(i.value + i2.value,false)
        }else{
            if (i.value > i2.value) {
                new(i.value - i2.value,i.negative)
            }else{
                new(i2.value - i.value,i2.negative)
            }
        }
    }

    public fun i64_sub(i: &I64, i2: &I64): I64 {
        let negative = if (i2.negative && true){
            false
        }else{
            true
        };
        let i3 = I64 {
            negative,
            value: i2.value,
        };
        i64_add(i,&i3)
    }
    
    public fun inc_u64(i: &mut I64, u: u64) {
        if (i.negative) {
            if (i.value > u) {
                i.value = i.value - u;
            }else{
                i.value = u - i.value;
                i.negative = false;
            }
        }else{
            i.value = i.value + u;
        };
        assert!(i.value <= MAX_POSITIVE, ENumericOverflow);
    }

    public fun dec_u64(i: &mut I64, u: u64) {
        if (i.negative) {
            i.value = i.value + u;
        }else{
            if (i.value > u) {
                i.value = i.value - u;
            }else{
                i.value = u - i.value;
                i.negative = true;
            }
        };
        assert!(i.value <= MAX_NEGATIVE, ENumericOverflow);
    }
}