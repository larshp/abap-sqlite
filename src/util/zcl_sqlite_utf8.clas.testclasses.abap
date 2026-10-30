CLASS ltcl_utf8 DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_case,
             hex  TYPE xstring,
             size TYPE i,
           END OF ty_case.

    METHODS roundtrip FOR TESTING.
    METHODS ascii FOR TESTING.
    METHODS empty FOR TESTING.
ENDCLASS.


CLASS ltcl_utf8 IMPLEMENTATION.

  METHOD roundtrip.
    DATA lt_cases TYPE STANDARD TABLE OF ty_case WITH DEFAULT KEY.
    DATA ls_case TYPE ty_case.
    DATA lv_text TYPE string.

    lt_cases = VALUE #(
      ( hex = '41'                       size = 1 )
      ( hex = '7F'                       size = 1 )
      ( hex = 'C280'                     size = 2 )
      ( hex = 'C3A4'                     size = 2 )
      ( hex = 'DFBF'                     size = 2 )
      ( hex = 'E0A080'                   size = 3 )
      ( hex = 'E282AC'                   size = 3 )
      ( hex = 'EFBFBF'                   size = 3 )
      ( hex = 'F0908080'                 size = 4 )
      ( hex = 'F09F9880'                 size = 4 )
      ( hex = 'F48FBFBF'                 size = 4 )
      ( hex = '48656C6C6F'               size = 5 )
      ( hex = '41C3A4E282ACF09F98805A'   size = 11 ) ).

    LOOP AT lt_cases INTO ls_case.
      lv_text = zcl_sqlite_utf8=>decode( ls_case-hex ).

      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_utf8=>encode( lv_text ) exp = ls_case-hex ).
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_utf8=>byte_length( lv_text ) exp = ls_case-size ).
      cl_abap_unit_assert=>assert_equals(
        act = xstrlen( zcl_sqlite_utf8=>encode( lv_text ) ) exp = ls_case-size ).
    ENDLOOP.
  ENDMETHOD.

  METHOD ascii.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_utf8=>encode( 'Hello' ) exp = '48656C6C6F' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_utf8=>decode( '48656C6C6F' ) exp = 'Hello' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_utf8=>byte_length( 'Hello' ) exp = 5 ).
  ENDMETHOD.

  METHOD empty.
    DATA lv_empty TYPE xstring.

    lv_empty = ''.

    cl_abap_unit_assert=>assert_equals(
      act = xstrlen( zcl_sqlite_utf8=>encode( '' ) ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_utf8=>decode( lv_empty ) exp = '' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_utf8=>byte_length( '' ) exp = 0 ).
  ENDMETHOD.

ENDCLASS.
