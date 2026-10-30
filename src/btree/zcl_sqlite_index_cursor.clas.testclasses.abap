CLASS ltcl_index_cursor DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_indexed TYPE string VALUE 'fixtures/indexed.db'.
    CONSTANTS c_root_page TYPE i VALUE 3.

    METHODS scan_all FOR TESTING RAISING zcx_sqlite_error.
    METHODS seek_prefix FOR TESTING RAISING zcx_sqlite_error.

    METHODS open_cursor
      RETURNING VALUE(ro_cursor) TYPE REF TO zcl_sqlite_index_cursor.
    METHODS expected_key
      IMPORTING iv_number     TYPE i
      RETURNING VALUE(rv_key) TYPE string.
    METHODS prefix
      IMPORTING iv_text          TYPE string
      RETURNING VALUE(rt_prefix) TYPE zcl_sqlite_record=>ty_values.
    METHODS assert_entry
      IMPORTING io_cursor TYPE REF TO zcl_sqlite_index_cursor
                iv_rowid  TYPE int8
                iv_key    TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS ltcl_index_cursor IMPLEMENTATION.

  METHOD scan_all.
    DATA lo_cursor TYPE REF TO zcl_sqlite_index_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lv_count TYPE i.
    DATA lv_rowid TYPE int8.

    lo_cursor = open_cursor( ).
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      lv_rowid = lv_count.
      assert_entry(
        io_cursor = lo_cursor
        iv_rowid = lv_rowid
        iv_key = expected_key( lv_count ) ).

      IF lv_count > 100.
        cl_abap_unit_assert=>fail( msg = 'index cursor did not stop' ).
      ENDIF.
      lv_found = lo_cursor->next( ).
    ENDWHILE.

    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 100 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->is_valid( ) exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_false ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->first( ) exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 1
      iv_key = expected_key( 1 ) ).
  ENDMETHOD.

  METHOD seek_prefix.
    DATA lo_cursor TYPE REF TO zcl_sqlite_index_cursor.
    DATA lv_found TYPE abap_bool.

    lo_cursor = open_cursor( ).

    lv_found = lo_cursor->seek( prefix( 'value-050' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 50
      iv_key = expected_key( 50 ) ).

    lv_found = lo_cursor->seek( prefix( 'value-037' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 37
      iv_key = expected_key( 37 ) ).

    lv_found = lo_cursor->seek( prefix( 'value-037z' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 38
      iv_key = expected_key( 38 ) ).

    lv_found = lo_cursor->seek( prefix( 'value-000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 1
      iv_key = expected_key( 1 ) ).

    lv_found = lo_cursor->seek( prefix( 'aaaa' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 1
      iv_key = expected_key( 1 ) ).

    lv_found = lo_cursor->seek( prefix(
      |value-050-{ repeat( val = 'x' occ = 41 ) }| ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 51
      iv_key = expected_key( 51 ) ).

    lv_found = lo_cursor->seek( prefix( 'value-101' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_false ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->is_valid( ) exp = abap_false ).

    lv_found = lo_cursor->seek( prefix( 'zzzz' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_false ).

    lv_found = lo_cursor->seek( prefix( '' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 1
      iv_key = expected_key( 1 ) ).

    lv_found = lo_cursor->seek( prefix( expected_key( 1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_found exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 1
      iv_key = expected_key( 1 ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->next( ) exp = abap_true ).
    assert_entry(
      io_cursor = lo_cursor
      iv_rowid = 2
      iv_key = expected_key( 2 ) ).
  ENDMETHOD.

  METHOD open_cursor.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( c_indexed ).

    TRY.
        lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
        ro_cursor = NEW zcl_sqlite_index_cursor(
          io_pager = lo_pager
          iv_root_page = c_root_page ).
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        cl_abap_unit_assert=>fail( msg = |index cursor construction failed: { lo_error->message }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD expected_key.
    DATA lv_number TYPE string.

    lv_number = iv_number.
* ANORMALY: integer to string leaves a trailing blank in the transpiler,
* see ANORMALIES.md
    CONDENSE lv_number.
    WHILE strlen( lv_number ) < 3.
      lv_number = |0{ lv_number }|.
    ENDWHILE.
    rv_key = |value-{ lv_number }-{ repeat( val = 'x' occ = 40 ) }|.
  ENDMETHOD.

  METHOD prefix.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_value=>text( iv_text ).
    APPEND lo_value TO rt_prefix.
  ENDMETHOD.

  METHOD assert_entry.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_key TYPE REF TO zcl_sqlite_value.
    DATA lo_rowid TYPE REF TO zcl_sqlite_value.

    cl_abap_unit_assert=>assert_equals(
      act = io_cursor->is_valid( ) exp = abap_true ).

    lt_values = io_cursor->values( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_values ) exp = 2 ).

    READ TABLE lt_values INTO lo_key INDEX 1.
    READ TABLE lt_values INTO lo_rowid INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_key->value_type( ) exp = zcl_sqlite_value=>c_text ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_key->as_text( ) exp = iv_key ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_rowid->value_type( ) exp = zcl_sqlite_value=>c_integer ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_rowid->as_integer( ) exp = iv_rowid ).
  ENDMETHOD.

ENDCLASS.
