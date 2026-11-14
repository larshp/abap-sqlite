CLASS ltcl_record DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_expected,
             kind       TYPE i,
             int_value  TYPE int8,
             real_value TYPE f,
             text_value TYPE string,
             blob_value TYPE xstring,
           END OF ty_expected.
    TYPES ty_expected_values TYPE STANDARD TABLE OF ty_expected WITH DEFAULT KEY.

    METHODS encode_smallest_serial_types FOR TESTING RAISING zcx_sqlite_error.
    METHODS encode_integer_widths FOR TESTING RAISING zcx_sqlite_error.
    METHODS encode_text_and_blob FOR TESTING RAISING zcx_sqlite_error.
    METHODS encode_real FOR TESTING RAISING zcx_sqlite_error.
    METHODS encode_roundtrip FOR TESTING RAISING zcx_sqlite_error.
    METHODS encode_unicode FOR TESTING RAISING zcx_sqlite_error.
    METHODS encode_empty FOR TESTING RAISING zcx_sqlite_error.
    METHODS reserved_serial_type FOR TESTING.
    METHODS truncated_record FOR TESTING.
    METHODS bad_header FOR TESTING.

    METHODS assert_values
      IMPORTING it_values   TYPE zcl_sqlite_record=>ty_values
                it_expected TYPE ty_expected_values.
ENDCLASS.


CLASS ltcl_record IMPLEMENTATION.

  METHOD encode_smallest_serial_types.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_data TYPE xstring.

    APPEND zcl_sqlite_value=>null( ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 0 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 1 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -1 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 127 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 128 ) TO lt_values.

    lv_data = zcl_sqlite_record=>encode( lt_values ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_data
      exp = '07000809010102FF7F0080' ).
  ENDMETHOD.

  METHOD encode_integer_widths.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_data TYPE xstring.
    DATA lv_header TYPE xstring.

    APPEND zcl_sqlite_value=>integer( -32769 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -32768 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 32767 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 32768 ) TO lt_values.
    lv_data = zcl_sqlite_record=>encode( lt_values ).
    lv_header = lv_data+0(5).
    cl_abap_unit_assert=>assert_equals(
      act = lv_header
      exp = '0503020203' ).
    CLEAR lt_values.

    APPEND zcl_sqlite_value=>integer( -8388609 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -8388608 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 8388607 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 8388608 ) TO lt_values.
    lv_data = zcl_sqlite_record=>encode( lt_values ).
    lv_header = lv_data+0(5).
    cl_abap_unit_assert=>assert_equals(
      act = lv_header
      exp = '0504030304' ).
    CLEAR lt_values.

    APPEND zcl_sqlite_value=>integer( -2147483649 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -2147483648 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 2147483647 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 2147483648 ) TO lt_values.
    lv_data = zcl_sqlite_record=>encode( lt_values ).
    lv_header = lv_data+0(5).
    cl_abap_unit_assert=>assert_equals(
      act = lv_header
      exp = '0505040405' ).
    CLEAR lt_values.

    APPEND zcl_sqlite_value=>integer( -140737488355329 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -140737488355328 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 140737488355327 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 140737488355328 ) TO lt_values.
    lv_data = zcl_sqlite_record=>encode( lt_values ).
    lv_header = lv_data+0(5).
    cl_abap_unit_assert=>assert_equals(
      act = lv_header
      exp = '0506050506' ).
  ENDMETHOD.

  METHOD encode_text_and_blob.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_data TYPE xstring.
    DATA lv_empty_blob TYPE xstring.

    APPEND zcl_sqlite_value=>text( 'abc' ) TO lt_values.
    APPEND zcl_sqlite_value=>text( '' ) TO lt_values.
    APPEND zcl_sqlite_value=>blob( '0102' ) TO lt_values.
    APPEND zcl_sqlite_value=>blob( lv_empty_blob ) TO lt_values.

    lv_data = zcl_sqlite_record=>encode( lt_values ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_data
      exp = '05130D100C6162630102' ).
  ENDMETHOD.

  METHOD encode_real.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_data TYPE xstring.

    APPEND zcl_sqlite_value=>real( '1.5' ) TO lt_values.
    lv_data = zcl_sqlite_record=>encode( lt_values ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_data
      exp = '02073FF8000000000000' ).
  ENDMETHOD.

  METHOD encode_roundtrip.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lt_expected TYPE ty_expected_values.
    DATA lt_decoded TYPE zcl_sqlite_record=>ty_values.
    DATA lv_data TYPE xstring.
    DATA lv_empty_blob TYPE xstring.

    APPEND zcl_sqlite_value=>null( ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 0 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 1 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -1 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 128 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -129 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 32768 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -32769 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 8388608 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -8388609 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 2147483648 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -2147483649 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( 140737488355328 ) TO lt_values.
    APPEND zcl_sqlite_value=>integer( -140737488355329 ) TO lt_values.
    APPEND zcl_sqlite_value=>real( '1.5' ) TO lt_values.
    APPEND zcl_sqlite_value=>text( '' ) TO lt_values.
    APPEND zcl_sqlite_value=>text( 'abc' ) TO lt_values.
    APPEND zcl_sqlite_value=>blob( lv_empty_blob ) TO lt_values.
    APPEND zcl_sqlite_value=>blob( '010203' ) TO lt_values.

    lv_data = zcl_sqlite_record=>encode( lt_values ).
    lt_decoded = zcl_sqlite_record=>decode( lv_data ).

    lt_expected = VALUE #(
      ( kind = zcl_sqlite_value=>c_null )
      ( kind = zcl_sqlite_value=>c_integer int_value = 0 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 1 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -1 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 128 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -129 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 32768 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -32769 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 8388608 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -8388609 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 2147483648 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -2147483649 )
      ( kind = zcl_sqlite_value=>c_integer int_value = 140737488355328 )
      ( kind = zcl_sqlite_value=>c_integer int_value = -140737488355329 )
      ( kind = zcl_sqlite_value=>c_real real_value = '1.5' )
      ( kind = zcl_sqlite_value=>c_text text_value = '' )
      ( kind = zcl_sqlite_value=>c_text text_value = 'abc' )
      ( kind = zcl_sqlite_value=>c_blob blob_value = '' )
      ( kind = zcl_sqlite_value=>c_blob blob_value = '010203' ) ).
    assert_values( it_values   = lt_decoded
                   it_expected = lt_expected ).
  ENDMETHOD.

  METHOD encode_unicode.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_text TYPE string.
    DATA lv_data TYPE xstring.

    lv_text = zcl_sqlite_utf8=>decode( '41C3A4E282ACF09F98805A' ).
    APPEND zcl_sqlite_value=>text( lv_text ) TO lt_values.

    lv_data = zcl_sqlite_record=>encode( lt_values ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_data
      exp = '022341C3A4E282ACF09F98805A' ).
  ENDMETHOD.

  METHOD encode_empty.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lt_decoded TYPE zcl_sqlite_record=>ty_values.
    DATA lv_data TYPE xstring.

    lv_data = zcl_sqlite_record=>encode( lt_values ).
    lt_decoded = zcl_sqlite_record=>decode( lv_data ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_data
      exp = '01' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_decoded )
      exp = 0 ).
  ENDMETHOD.

  METHOD reserved_serial_type.
    TRY.
        zcl_sqlite_record=>decode( '020A' ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD truncated_record.
    TRY.
        zcl_sqlite_record=>decode( '0201' ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD bad_header.
    TRY.
        zcl_sqlite_record=>decode( '05' ).
        cl_abap_unit_assert=>fail( 'expected zcx_sqlite_error' ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_corrupt ).
    ENDTRY.
  ENDMETHOD.

  METHOD assert_values.
    DATA ls_expected TYPE ty_expected.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_index TYPE i.

    cl_abap_unit_assert=>assert_equals(
      act = lines( it_values )
      exp = lines( it_expected ) ).

    LOOP AT it_expected INTO ls_expected.
      lv_index = lv_index + 1.
      READ TABLE it_values INTO lo_value INDEX lv_index.
      cl_abap_unit_assert=>assert_equals(
        act = sy-subrc
        exp = 0
        msg = |value { lv_index } is missing| ).
      cl_abap_unit_assert=>assert_equals(
        act = lo_value->value_type( )
        exp = ls_expected-kind
        msg = |value { lv_index } type| ).

      CASE ls_expected-kind.
        WHEN zcl_sqlite_value=>c_null.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->is_null( )
            exp = abap_true
            msg = |value { lv_index } null| ).
        WHEN zcl_sqlite_value=>c_integer.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_integer( )
            exp = ls_expected-int_value
            msg = |value { lv_index } integer| ).
        WHEN zcl_sqlite_value=>c_real.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_real( )
            exp = ls_expected-real_value
            msg = |value { lv_index } real| ).
        WHEN zcl_sqlite_value=>c_text.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_text( )
            exp = ls_expected-text_value
            msg = |value { lv_index } text| ).
        WHEN zcl_sqlite_value=>c_blob.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_blob( )
            exp = ls_expected-blob_value
            msg = |value { lv_index } blob| ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
