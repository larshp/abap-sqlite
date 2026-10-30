CLASS ltcl_value DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS null_value FOR TESTING.
    METHODS integer_value FOR TESTING.
    METHODS real_value FOR TESTING.
    METHODS text_value FOR TESTING.
    METHODS blob_value FOR TESTING.
    METHODS empty_text_and_blob FOR TESTING.
ENDCLASS.


CLASS ltcl_value IMPLEMENTATION.

  METHOD null_value.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_value=>null( ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( ) exp = zcl_sqlite_value=>c_null ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true ).
  ENDMETHOD.

  METHOD integer_value.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_value=>integer( -42 ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( ) exp = zcl_sqlite_value=>c_integer ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = -42 ).
  ENDMETHOD.

  METHOD real_value.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_value=>real( '1.5' ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( ) exp = zcl_sqlite_value=>c_real ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( ) exp = '1.5' ).
  ENDMETHOD.

  METHOD text_value.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_value=>text( 'hello' ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( ) exp = zcl_sqlite_value=>c_text ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'hello' ).
  ENDMETHOD.

  METHOD blob_value.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_value=>blob( '010203' ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_value->value_type( ) exp = zcl_sqlite_value=>c_blob ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_blob( ) exp = '010203' ).
  ENDMETHOD.

  METHOD empty_text_and_blob.
    DATA lo_text TYPE REF TO zcl_sqlite_value.
    DATA lo_blob TYPE REF TO zcl_sqlite_value.
    DATA lv_empty_text TYPE string.
    DATA lv_empty_blob TYPE xstring.

    lo_text = zcl_sqlite_value=>text( lv_empty_text ).
    lo_blob = zcl_sqlite_value=>blob( lv_empty_blob ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_text->as_text( ) exp = '' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_blob->as_blob( ) exp = '' ).
  ENDMETHOD.

ENDCLASS.
