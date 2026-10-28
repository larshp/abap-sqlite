CLASS ltcl_bytes DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_case,
             value TYPE int8,
             hex   TYPE xstring,
           END OF ty_case.

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

ENDCLASS.
