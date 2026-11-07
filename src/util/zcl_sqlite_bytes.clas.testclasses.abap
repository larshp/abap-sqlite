CLASS ltcl_bytes DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_case,
             value TYPE int8,
             hex   TYPE xstring,
           END OF ty_case.

    TYPES: BEGIN OF ty_float_bits,
             hex      TYPE xstring,
             sign     TYPE i,
             exponent TYPE i,
             mantissa TYPE int8,
           END OF ty_float_bits.

    TYPES: BEGIN OF ty_float_f,
             text TYPE string,
             hex  TYPE xstring,
           END OF ty_float_f.

    METHODS u8 FOR TESTING.
    METHODS u16 FOR TESTING.
    METHODS u24 FOR TESTING.
    METHODS u32 FOR TESTING.
    METHODS u48 FOR TESTING.
    METHODS i64 FOR TESTING.
    METHODS offset FOR TESTING.
    METHODS known_vectors FOR TESTING.
    METHODS read_out_of_bounds FOR TESTING.
    METHODS write_out_of_bounds FOR TESTING.
    METHODS unsigned_range FOR TESTING.
    METHODS varint_vectors FOR TESTING.
    METHODS varint_offset FOR TESTING.
    METHODS varint_non_canonical FOR TESTING.
    METHODS varint_truncated FOR TESTING.
    METHODS f64_bits FOR TESTING.
    METHODS f64_from_f FOR TESTING.
    METHODS f64_to_f FOR TESTING.
    METHODS f64_read_offset FOR TESTING.
    METHODS f64_invalid_bits FOR TESTING.
    METHODS f64_special_to_f FOR TESTING.
    METHODS f64_subnormal FOR TESTING.
ENDCLASS.


CLASS ltcl_bytes IMPLEMENTATION.

  METHOD u8.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_data TYPE xstring.

    lt_cases = VALUE #(
      ( value = 0   hex = '00' )
      ( value = 1   hex = '01' )
      ( value = 127 hex = '7F' )
      ( value = 128 hex = '80' )
      ( value = 255 hex = 'FF' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_data = '00'.
      lv_data = zcl_sqlite_bytes=>write_u8( iv_data = lv_data iv_offset = 0 iv_value = ls_case-value ).
      cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD u16.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_data TYPE xstring.

    lt_cases = VALUE #(
      ( value = 0     hex = '0000' )
      ( value = 1     hex = '0001' )
      ( value = 255   hex = '00FF' )
      ( value = 256   hex = '0100' )
      ( value = 32767 hex = '7FFF' )
      ( value = 32768 hex = '8000' )
      ( value = 65535 hex = 'FFFF' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_data = '0000'.
      lv_data = zcl_sqlite_bytes=>write_u16( iv_data = lv_data iv_offset = 0 iv_value = ls_case-value ).
      cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_u16( iv_data = lv_data iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD u24.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_data TYPE xstring.

    lt_cases = VALUE #(
      ( value = 0        hex = '000000' )
      ( value = 1        hex = '000001' )
      ( value = 65535    hex = '00FFFF' )
      ( value = 65536    hex = '010000' )
      ( value = 16777215 hex = 'FFFFFF' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_data = '000000'.
      lv_data = zcl_sqlite_bytes=>write_u24( iv_data = lv_data iv_offset = 0 iv_value = ls_case-value ).
      cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_u24( iv_data = lv_data iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD u32.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_data TYPE xstring.

    lt_cases = VALUE #(
      ( value = 0          hex = '00000000' )
      ( value = 1          hex = '00000001' )
      ( value = 65535      hex = '0000FFFF' )
      ( value = 65536      hex = '00010000' )
      ( value = 2147483647 hex = '7FFFFFFF' )
      ( value = 2147483648 hex = '80000000' )
      ( value = 4294967295 hex = 'FFFFFFFF' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_data = '00000000'.
      lv_data = zcl_sqlite_bytes=>write_u32( iv_data = lv_data iv_offset = 0 iv_value = ls_case-value ).
      cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_u32( iv_data = lv_data iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD u48.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_data TYPE xstring.

    lt_cases = VALUE #(
      ( value = 0               hex = '000000000000' )
      ( value = 1               hex = '000000000001' )
      ( value = 4294967295      hex = '0000FFFFFFFF' )
      ( value = 4294967296      hex = '000100000000' )
      ( value = 281474976710655 hex = 'FFFFFFFFFFFF' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_data = '000000000000'.
      lv_data = zcl_sqlite_bytes=>write_u48( iv_data = lv_data iv_offset = 0 iv_value = ls_case-value ).
      cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_u48( iv_data = lv_data iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD i64.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_data TYPE xstring.

    lt_cases = VALUE #(
      ( value = 0                     hex = '0000000000000000' )
      ( value = 1                     hex = '0000000000000001' )
      ( value = -1                    hex = 'FFFFFFFFFFFFFFFF' )
      ( value = -2                    hex = 'FFFFFFFFFFFFFFFE' )
      ( value = 4294967296            hex = '0000000100000000' )
      ( value = 9223372036854775807   hex = '7FFFFFFFFFFFFFFF' )
      ( value = -9223372036854775808  hex = '8000000000000000' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_data = '0000000000000000'.
      lv_data = zcl_sqlite_bytes=>write_i64( iv_data = lv_data iv_offset = 0 iv_value = ls_case-value ).
      cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_i64( iv_data = lv_data iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD offset.
    DATA lv_data TYPE xstring.

    lv_data = 'AABBCCDDEE'.
    lv_data = zcl_sqlite_bytes=>write_u16( iv_data = lv_data iv_offset = 2 iv_value = 4386 ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = 'AABB1122EE' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u16( iv_data = lv_data iv_offset = 2 ) exp = 4386 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 ) exp = 170 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 4 ) exp = 238 ).

    lv_data = '00000000000000000000'.
    lv_data = zcl_sqlite_bytes=>write_i64( iv_data = lv_data iv_offset = 1 iv_value = -1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = '00FFFFFFFFFFFFFFFF00' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_i64( iv_data = lv_data iv_offset = 1 ) exp = -1 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 9 ) exp = 0 ).
  ENDMETHOD.

  METHOD known_vectors.
    DATA lv_data TYPE xstring.

    lv_data = 'FF'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 ) exp = 255 ).

    lv_data = '0102'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u16( iv_data = lv_data iv_offset = 0 ) exp = 258 ).

    lv_data = '010203'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u24( iv_data = lv_data iv_offset = 0 ) exp = 66051 ).

    lv_data = '01020304'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u32( iv_data = lv_data iv_offset = 0 ) exp = 16909060 ).

    lv_data = '010203040506'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u48( iv_data = lv_data iv_offset = 0 ) exp = 1108152157446 ).

    lv_data = '7FFFFFFFFFFFFFFF'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_i64( iv_data = lv_data iv_offset = 0 )
      exp = 9223372036854775807 ).

    lv_data = '8000000000000000'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_i64( iv_data = lv_data iv_offset = 0 )
      exp = -9223372036854775808 ).

    lv_data = 'FFFFFFFFFFFFFFFF'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_i64( iv_data = lv_data iv_offset = 0 ) exp = -1 ).
  ENDMETHOD.

  METHOD read_out_of_bounds.
    DATA lv_data TYPE xstring.

    lv_data = '0011'.

    TRY.
        zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 2 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>read_u16( iv_data = lv_data iv_offset = 1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>read_i64( iv_data = lv_data iv_offset = -1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD write_out_of_bounds.
    DATA lv_data TYPE xstring.

    lv_data = '0011'.

    TRY.
        zcl_sqlite_bytes=>write_u32( iv_data = lv_data iv_offset = 0 iv_value = 1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>write_u8( iv_data = lv_data iv_offset = 2 iv_value = 1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>write_u16( iv_data = lv_data iv_offset = -1 iv_value = 1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD unsigned_range.
    DATA lv_data TYPE xstring.

    lv_data = '00'.

    TRY.
        zcl_sqlite_bytes=>write_u8( iv_data = lv_data iv_offset = 0 iv_value = 256 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>write_u8( iv_data = lv_data iv_offset = 0 iv_value = -1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    lv_data = '0000'.

    TRY.
        zcl_sqlite_bytes=>write_u16( iv_data = lv_data iv_offset = 0 iv_value = 65536 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    lv_data = '000000'.

    TRY.
        zcl_sqlite_bytes=>write_u24( iv_data = lv_data iv_offset = 0 iv_value = 16777216 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    lv_data = '00000000'.

    TRY.
        zcl_sqlite_bytes=>write_u32( iv_data = lv_data iv_offset = 0 iv_value = 4294967296 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>write_u32( iv_data = lv_data iv_offset = 0 iv_value = -1 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    lv_data = '000000000000'.

    TRY.
        zcl_sqlite_bytes=>write_u48( iv_data = lv_data iv_offset = 0 iv_value = 281474976710656 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD varint_vectors.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.

    lt_cases = VALUE #(
      ( value = 0                     hex = '00' )
      ( value = 1                     hex = '01' )
      ( value = 127                   hex = '7F' )
      ( value = 128                   hex = '8100' )
      ( value = 129                   hex = '8101' )
      ( value = 16383                 hex = 'FF7F' )
      ( value = 16384                 hex = '818000' )
      ( value = 2097151               hex = 'FFFF7F' )
      ( value = 2097152               hex = '81808000' )
      ( value = 268435455             hex = 'FFFFFF7F' )
      ( value = 268435456             hex = '8180808000' )
      ( value = 34359738367           hex = 'FFFFFFFF7F' )
      ( value = 34359738368           hex = '818080808000' )
      ( value = 4398046511103         hex = 'FFFFFFFFFF7F' )
      ( value = 4398046511104         hex = '81808080808000' )
      ( value = 562949953421311       hex = 'FFFFFFFFFFFF7F' )
      ( value = 562949953421312       hex = '8180808080808000' )
      ( value = 72057594037927935     hex = 'FFFFFFFFFFFFFF7F' )
      ( value = 72057594037927936     hex = '80C080808080808000' )
      ( value = 9223372036854775807   hex = 'BFFFFFFFFFFFFFFFFF' )
      ( value = -9223372036854775808  hex = 'C08080808080808000' )
      ( value = -1                    hex = 'FFFFFFFFFFFFFFFFFF' )
      ( value = -2                    hex = 'FFFFFFFFFFFFFFFFFE' ) ).

    LOOP AT lt_cases INTO ls_case.
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>write_varint( ls_case-value )
        exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>varint_length( iv_data = ls_case-hex iv_offset = 0 )
        exp = xstrlen( ls_case-hex ) ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>read_varint( iv_data = ls_case-hex iv_offset = 0 )
        exp = ls_case-value ).
    ENDLOOP.
  ENDMETHOD.

  METHOD varint_offset.
    DATA lv_varint TYPE xstring.
    DATA lv_data TYPE xstring.

    lv_varint = zcl_sqlite_bytes=>write_varint( 128 ).
    lv_data = 'AABB' && lv_varint && 'CCDD'.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_varint( iv_data = lv_data iv_offset = 2 ) exp = 128 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>varint_length( iv_data = lv_data iv_offset = 2 ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 ) exp = 170 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 4 ) exp = 204 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 5 ) exp = 221 ).
  ENDMETHOD.

  METHOD varint_non_canonical.
    DATA lv_data TYPE xstring.

    lv_data = '8000'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_varint( iv_data = lv_data iv_offset = 0 ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>varint_length( iv_data = lv_data iv_offset = 0 ) exp = 2 ).

    lv_data = '808000'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_varint( iv_data = lv_data iv_offset = 0 ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>varint_length( iv_data = lv_data iv_offset = 0 ) exp = 3 ).
  ENDMETHOD.

  METHOD varint_truncated.
    DATA lv_data TYPE xstring.

    lv_data = 'FFFFFFFFFFFFFFFF'.

    TRY.
        zcl_sqlite_bytes=>read_varint( iv_data = lv_data iv_offset = 0 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        zcl_sqlite_bytes=>varint_length( iv_data = lv_data iv_offset = 0 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    lv_data = ''.

    TRY.
        zcl_sqlite_bytes=>read_varint( iv_data = lv_data iv_offset = 0 ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_range_out_of_bounds' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD f64_bits.
    DATA lt_cases TYPE STANDARD TABLE OF ty_float_bits WITH DEFAULT KEY.
    DATA ls_case TYPE ty_float_bits.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.

    lt_cases = VALUE #(
      ( hex = '0000000000000000' sign = 0 exponent = 0    mantissa = 0 )
      ( hex = '8000000000000000' sign = 1 exponent = 0    mantissa = 0 )
      ( hex = '3FF0000000000000' sign = 0 exponent = 1023 mantissa = 0 )
      ( hex = 'BFF0000000000000' sign = 1 exponent = 1023 mantissa = 0 )
      ( hex = '3FF8000000000000' sign = 0 exponent = 1023 mantissa = 2251799813685248 )
      ( hex = '4000000000000000' sign = 0 exponent = 1024 mantissa = 0 )
      ( hex = '3FB999999999999A' sign = 0 exponent = 1019 mantissa = 2702159776422298 )
      ( hex = '7FEFFFFFFFFFFFFF' sign = 0 exponent = 2046 mantissa = 4503599627370495 )
      ( hex = '0010000000000000' sign = 0 exponent = 1    mantissa = 0 )
      ( hex = '0000000000000001' sign = 0 exponent = 0    mantissa = 1 )
      ( hex = '000FFFFFFFFFFFFF' sign = 0 exponent = 0    mantissa = 4503599627370495 )
      ( hex = '0000000000000002' sign = 0 exponent = 0    mantissa = 2 )
      ( hex = '7FF0000000000000' sign = 0 exponent = 2047 mantissa = 0 )
      ( hex = 'FFF0000000000000' sign = 1 exponent = 2047 mantissa = 0 )
      ( hex = '7FF8000000000000' sign = 0 exponent = 2047 mantissa = 2251799813685248 )
      ( hex = '7FF8000000000001' sign = 0 exponent = 2047 mantissa = 2251799813685249 )
      ( hex = '7FF0000000000001' sign = 0 exponent = 2047 mantissa = 1 ) ).

    LOOP AT lt_cases INTO ls_case.
      ls_bits = zcl_sqlite_bytes=>read_f64( iv_data = ls_case-hex iv_offset = 0 ).
      cl_abap_unit_assert=>assert_equals( act = ls_bits-sign exp = ls_case-sign ).
      cl_abap_unit_assert=>assert_equals( act = ls_bits-exponent exp = ls_case-exponent ).
      cl_abap_unit_assert=>assert_equals( act = ls_bits-mantissa exp = ls_case-mantissa ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>write_f64( ls_bits ) exp = ls_case-hex ).
    ENDLOOP.
  ENDMETHOD.

  METHOD f64_from_f.
    DATA lt_cases TYPE STANDARD TABLE OF ty_float_f WITH DEFAULT KEY.
    DATA ls_case TYPE ty_float_f.
    DATA lv_value TYPE f.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.

    lt_cases = VALUE #(
      ( text = '0.0E+00'                  hex = '0000000000000000' )
      ( text = '1.0E+00'                  hex = '3FF0000000000000' )
      ( text = '-1.0E+00'                 hex = 'BFF0000000000000' )
      ( text = '1.5E+00'                  hex = '3FF8000000000000' )
      ( text = '1.0E-01'                  hex = '3FB999999999999A' )
      ( text = '-1.0E-01'                 hex = 'BFB999999999999A' )
      ( text = '2.0E+00'                  hex = '4000000000000000' )
      ( text = '3.141592653589793E+00'    hex = '400921FB54442D18' )
      ( text = '1.0E+300'                 hex = '7E37E43C8800759C' )
      ( text = '1.0E-300'                 hex = '01A56E1FC2F8F359' )
      ( text = '1.7976931348623157E+308'  hex = '7FEFFFFFFFFFFFFF' )
      ( text = '2.2250738585072014E-308'  hex = '0010000000000000' ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_value = ls_case-text.
      ls_bits = zcl_sqlite_bytes=>f64_from_f( lv_value ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>write_f64( ls_bits ) exp = ls_case-hex ).
    ENDLOOP.
  ENDMETHOD.

  METHOD f64_to_f.
    DATA lt_hex TYPE STANDARD TABLE OF xstring WITH DEFAULT KEY.
    DATA lv_hex TYPE xstring.
    DATA lv_value TYPE f.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.

    lt_hex = VALUE #(
      ( '0000000000000000' )
      ( '3FF0000000000000' )
      ( 'BFF0000000000000' )
      ( '3FF8000000000000' )
      ( '4000000000000000' )
      ( '3FB999999999999A' )
      ( '7FEFFFFFFFFFFFFF' )
      ( '0010000000000000' )
      ( '7E37E43C8800759C' )
      ( '01A56E1FC2F8F359' ) ).

    LOOP AT lt_hex INTO lv_hex.
      ls_bits = zcl_sqlite_bytes=>read_f64( iv_data = lv_hex iv_offset = 0 ).
      lv_value = zcl_sqlite_bytes=>f64_to_f( ls_bits ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_bytes=>write_f64( zcl_sqlite_bytes=>f64_from_f( lv_value ) )
        exp = lv_hex ).
    ENDLOOP.
  ENDMETHOD.

  METHOD f64_read_offset.
    DATA lv_data TYPE xstring.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.

    lv_data = 'AABB3FF0000000000000CC'.
    ls_bits = zcl_sqlite_bytes=>read_f64( iv_data = lv_data iv_offset = 2 ).

    cl_abap_unit_assert=>assert_equals( act = ls_bits-sign exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_bits-exponent exp = 1023 ).
    cl_abap_unit_assert=>assert_equals( act = ls_bits-mantissa exp = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 ) exp = 170 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 10 ) exp = 204 ).
  ENDMETHOD.

  METHOD f64_invalid_bits.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.

    ls_bits-sign = 2.
    TRY.
        zcl_sqlite_bytes=>write_f64( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    ls_bits-sign = 0.
    ls_bits-exponent = 2048.
    TRY.
        zcl_sqlite_bytes=>write_f64( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    ls_bits-exponent = -1.
    TRY.
        zcl_sqlite_bytes=>write_f64( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    ls_bits-exponent = 0.
    ls_bits-mantissa = -1.
    TRY.
        zcl_sqlite_bytes=>write_f64( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    ls_bits-mantissa = 4503599627370496.
    TRY.
        zcl_sqlite_bytes=>write_f64( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD f64_special_to_f.
    DATA lv_value TYPE f.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.

    ls_bits = zcl_sqlite_bytes=>read_f64( iv_data = '7FF0000000000000' iv_offset = 0 ).
    TRY.
        lv_value = zcl_sqlite_bytes=>f64_to_f( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.

    ls_bits = zcl_sqlite_bytes=>read_f64( iv_data = '7FF8000000000000' iv_offset = 0 ).
    TRY.
        lv_value = zcl_sqlite_bytes=>f64_to_f( ls_bits ).
        cl_abap_unit_assert=>fail( msg = 'expected cx_sy_conversion_overflow' ).
      CATCH cx_sy_conversion_overflow.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD f64_subnormal.
    DATA lt_hex TYPE STANDARD TABLE OF xstring WITH DEFAULT KEY.
    DATA lv_hex TYPE xstring.
    DATA ls_bits TYPE zcl_sqlite_bytes=>ty_float64.
    DATA lv_value TYPE f.

    lt_hex = VALUE #(
      ( '0000000000000001' )
      ( '000FFFFFFFFFFFFF' ) ).

    LOOP AT lt_hex INTO lv_hex.
      ls_bits = zcl_sqlite_bytes=>read_f64( iv_data = lv_hex iv_offset = 0 ).

      TRY.
          lv_value = zcl_sqlite_bytes=>f64_to_f( ls_bits ).
        CATCH cx_sy_arithmetic_overflow.
* the platform does not represent subnormals
          RETURN.
      ENDTRY.

      IF lv_value > 0.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_sqlite_bytes=>write_f64( zcl_sqlite_bytes=>f64_from_f( lv_value ) )
          exp = lv_hex ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
