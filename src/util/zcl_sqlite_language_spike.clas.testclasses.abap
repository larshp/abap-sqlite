CLASS ltcl_language DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS int8_boundaries FOR TESTING.
    METHODS int8_overflow FOR TESTING.
    METHODS xstring_slice FOR TESTING.
    METHODS xstring_concat FOR TESTING.
    METHODS bit_expressions FOR TESTING.
    METHODS shift_equivalents FOR TESTING.
    METHODS hex_to_int8 FOR TESTING.
    METHODS int8_to_hex FOR TESTING.
    METHODS utf8 FOR TESTING.
ENDCLASS.


CLASS ltcl_language IMPLEMENTATION.

  METHOD int8_boundaries.
    DATA lv_max TYPE int8.
    DATA lv_min TYPE int8.
    DATA lv_big TYPE int8.

    lv_max = 9223372036854775807.
    cl_abap_unit_assert=>assert_equals( act = lv_max exp = 9223372036854775807 ).

    lv_min = -9223372036854775808.
    cl_abap_unit_assert=>assert_equals( act = lv_min exp = -9223372036854775808 ).

* above 2^53, so a JavaScript number would lose precision here
    lv_big = 9007199254740993.
    cl_abap_unit_assert=>assert_equals( act = lv_big exp = 9007199254740993 ).
  ENDMETHOD.

  METHOD int8_overflow.
    DATA lv_one TYPE int8 VALUE 1.
    DATA lv_value TYPE int8.
    DATA lv_result TYPE int8.

    lv_value = 9223372036854775807.
    TRY.
        lv_result = lv_value + lv_one.
* ANORMALY: the transpiler does not check int8 overflow, it returns 2^63,
* see ANORMALIES.md
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = 9223372036854775808 ).
      CATCH cx_sy_arithmetic_overflow.
* a real system raises here
    ENDTRY.

    lv_value = -9223372036854775808.
    TRY.
        lv_result = lv_value - lv_one.
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = -9223372036854775809 ).
      CATCH cx_sy_arithmetic_overflow.
* a real system raises here
    ENDTRY.
  ENDMETHOD.

  METHOD xstring_slice.
    DATA lv_data TYPE xstring.
    DATA lv_slice TYPE xstring.

    lv_data = '00112233445566778899AABBCCDDEEFF'.

    lv_slice = lv_data+2(4).
    cl_abap_unit_assert=>assert_equals( act = lv_slice exp = '22334455' ).

    lv_slice = lv_data+0(1).
    cl_abap_unit_assert=>assert_equals( act = lv_slice exp = '00' ).

    lv_slice = lv_data+15(1).
    cl_abap_unit_assert=>assert_equals( act = lv_slice exp = 'FF' ).

    lv_slice = lv_data+4(0).
    cl_abap_unit_assert=>assert_equals( act = xstrlen( lv_slice ) exp = 0 ).
  ENDMETHOD.

  METHOD xstring_concat.
    DATA lv_left TYPE xstring.
    DATA lv_right TYPE xstring.
    DATA lv_result TYPE xstring.

    lv_left = '0102'.
    lv_right = '030405'.

    CONCATENATE lv_left lv_right INTO lv_result IN BYTE MODE.
    cl_abap_unit_assert=>assert_equals( act = lv_result exp = '0102030405' ).
  ENDMETHOD.

  METHOD bit_expressions.
    DATA lv_a TYPE xstring.
    DATA lv_b TYPE xstring.
    DATA lv_result TYPE xstring.

    lv_a = 'F0F0'.
    lv_b = '0F0F'.

    lv_result = lv_a BIT-AND lv_b.
    cl_abap_unit_assert=>assert_equals( act = lv_result exp = '0000' ).

    lv_result = lv_a BIT-OR lv_b.
    cl_abap_unit_assert=>assert_equals( act = lv_result exp = 'FFFF' ).

    lv_result = lv_a BIT-XOR lv_b.
    cl_abap_unit_assert=>assert_equals( act = lv_result exp = 'FFFF' ).

    lv_result = BIT-NOT lv_a.
    cl_abap_unit_assert=>assert_equals( act = lv_result exp = '0F0F' ).
  ENDMETHOD.

  METHOD shift_equivalents.
* ABAP has no BIT-SHIFT operator, shifting is arithmetic
    DATA lv_value TYPE int8.

    lv_value = 1.
    lv_value = lv_value * 2.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 2 ).

    lv_value = lv_value * 1024.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 2048 ).

    lv_value = lv_value DIV 1024.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 2 ).

    lv_value = 5 MOD 2.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 1 ).
  ENDMETHOD.

  METHOD hex_to_int8.
    DATA lv_data TYPE xstring.
    DATA lv_value TYPE int8.

    lv_data = '0000000000000001'.
    lv_value = lv_data.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 1 ).

    lv_data = '00000000000000FF'.
    lv_value = lv_data.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 255 ).

    lv_data = '7FFFFFFFFFFFFFFF'.
    lv_value = lv_data.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = 9223372036854775807 ).

    lv_data = '8000000000000000'.
    lv_value = lv_data.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = -9223372036854775808 ).

    lv_data = 'FFFFFFFFFFFFFFFF'.
    lv_value = lv_data.
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = -1 ).

* a slice of a longer xstring works the same way
    lv_data = '0011223344556677FFFFFFFFFFFFFFFF'.
    lv_value = lv_data+8(8).
    cl_abap_unit_assert=>assert_equals( act = lv_value exp = -1 ).
  ENDMETHOD.

  METHOD int8_to_hex.
* ANORMALY: direct int8 to xstring assignment crashes in the transpiler, see
* ANORMALIES.md. Going through a type x field of 8 bytes yields the fixed
* 8-byte big endian representation the record format needs.
    DATA lv_value TYPE int8.
    DATA lv_field TYPE x LENGTH 8.
    DATA lv_data TYPE xstring.

    lv_value = 255.
    lv_field = lv_value.
    lv_data = lv_field.
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = '00000000000000FF' ).

    lv_value = -1.
    lv_field = lv_value.
    lv_data = lv_field.
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = 'FFFFFFFFFFFFFFFF' ).

    lv_value = 0.
    lv_field = lv_value.
    lv_data = lv_field.
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = '0000000000000000' ).
  ENDMETHOD.

  METHOD utf8.
    DATA lo_out TYPE REF TO if_abap_conv_out.
    DATA lo_in TYPE REF TO if_abap_conv_in.
    DATA lv_bytes TYPE xstring.
    DATA lv_text TYPE string.

    TRY.
        lo_out = cl_abap_conv_codepage=>create_out( codepage = 'UTF-8' ).
        lo_in = cl_abap_conv_codepage=>create_in( codepage = 'UTF-8' ).

        lv_bytes = lo_out->convert( 'Hello' ).
        cl_abap_unit_assert=>assert_equals( act = lv_bytes exp = '48656C6C6F' ).
        lv_text = lo_in->convert( lv_bytes ).
        cl_abap_unit_assert=>assert_equals( act = lv_text exp = 'Hello' ).

* two bytes
        lv_text = lo_in->convert( 'C3A4' ).
        lv_bytes = lo_out->convert( lv_text ).
        cl_abap_unit_assert=>assert_equals( act = lv_bytes exp = 'C3A4' ).

* three bytes
        lv_text = lo_in->convert( 'E282AC' ).
        lv_bytes = lo_out->convert( lv_text ).
        cl_abap_unit_assert=>assert_equals( act = lv_bytes exp = 'E282AC' ).

* four bytes
        lv_text = lo_in->convert( 'F09F9880' ).
        lv_bytes = lo_out->convert( lv_text ).
        cl_abap_unit_assert=>assert_equals( act = lv_bytes exp = 'F09F9880' ).
        cl_abap_unit_assert=>assert_equals( act = xstrlen( lv_bytes ) exp = 4 ).

* empty input
        lv_bytes = lo_out->convert( '' ).
        cl_abap_unit_assert=>assert_equals( act = xstrlen( lv_bytes ) exp = 0 ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
