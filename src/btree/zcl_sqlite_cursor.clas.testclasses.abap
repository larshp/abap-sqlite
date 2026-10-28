CLASS ltcl_cursor DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_empty TYPE string VALUE 'fixtures/empty.db'.
    CONSTANTS c_ten_thousand TYPE string VALUE 'fixtures/ten_thousand.db'.
    CONSTANTS c_ten_thousand_root TYPE i VALUE 2.

    METHODS scan_all FOR TESTING RAISING zcx_sqlite_error.
    METHODS seek_points FOR TESTING RAISING zcx_sqlite_error.
    METHODS empty_tree FOR TESTING RAISING zcx_sqlite_error.

    METHODS open_cursor
      IMPORTING iv_name          TYPE string
                iv_root_page     TYPE i
      RETURNING VALUE(ro_cursor) TYPE REF TO zcl_sqlite_cursor.
    METHODS expected_value
      IMPORTING iv_number       TYPE i
      RETURNING VALUE(rv_value) TYPE string.
ENDCLASS.


CLASS ltcl_cursor IMPLEMENTATION.

  METHOD scan_all.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lv_count TYPE i.
    DATA lv_rowid TYPE int8.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_cursor = open_cursor(
      iv_name = c_ten_thousand
      iv_root_page = c_ten_thousand_root ).

    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      lv_rowid = lv_count.

      cl_abap_unit_assert=>assert_equals(
        act = lo_cursor->rowid( ) exp = lv_rowid
        msg = |row { lv_count } rowid| ).
      cl_abap_unit_assert=>assert_equals(
        act = lo_cursor->is_valid( ) exp = abap_true
        msg = |row { lv_count } validity| ).

      lt_values = lo_cursor->values( ).
      cl_abap_unit_assert=>assert_equals(
        act = lines( lt_values ) exp = 1
        msg = |row { lv_count } value count| ).
      READ TABLE lt_values INTO lo_value INDEX 1.
      cl_abap_unit_assert=>assert_equals(
        act = sy-subrc exp = 0
        msg = |row { lv_count } value is missing| ).
      cl_abap_unit_assert=>assert_equals(
        act = lo_value->value_type( ) exp = zcl_sqlite_value=>c_text
        msg = |row { lv_count } value type| ).
      cl_abap_unit_assert=>assert_equals(
        act = lo_value->as_text( ) exp = expected_value( lv_count )
        msg = |row { lv_count } value| ).

      IF lv_count > 10000.
        cl_abap_unit_assert=>fail( msg = 'cursor did not stop at the end' ).
      ENDIF.

      lv_found = lo_cursor->next( ).
    ENDWHILE.

    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 10000 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->is_valid( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_false ).

    lv_found = lo_cursor->first( ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 1 ).
  ENDMETHOD.

  METHOD seek_points.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_cursor = open_cursor(
      iv_name = c_ten_thousand
      iv_root_page = c_ten_thousand_root ).

    lv_found = lo_cursor->seek( 5000 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 5000 ).
    lt_values = lo_cursor->values( ).
    READ TABLE lt_values INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'row-05000' ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 5001 ).

    lv_found = lo_cursor->seek( 0 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 1 ).

    lv_found = lo_cursor->seek( 10000 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 10000 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_false ).

    lv_found = lo_cursor->seek( 10001 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->is_valid( ) exp = abap_false ).

    lv_found = lo_cursor->seek( 9999 ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 9999 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lo_cursor->rowid( ) exp = 10000 ).
  ENDMETHOD.

  METHOD empty_tree.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.

    lo_cursor = open_cursor( iv_name = c_empty iv_root_page = 1 ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->first( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->is_valid( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->seek( 1 ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_false ).
  ENDMETHOD.

  METHOD open_cursor.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( iv_name ).

    TRY.
        lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
        ro_cursor = NEW zcl_sqlite_cursor(
          io_pager = lo_pager
          iv_root_page = iv_root_page ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |cursor construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD expected_value.
    DATA lv_number TYPE string.

    lv_number = iv_number.
* ANORMALY: integer to string leaves a trailing blank in the transpiler,
* see ANORMALIES.md
    CONDENSE lv_number.
    WHILE strlen( lv_number ) < 5.
      lv_number = |0{ lv_number }|.
    ENDWHILE.
    rv_value = |row-{ lv_number }|.
  ENDMETHOD.

ENDCLASS.
