CLASS ltcl_catalog DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_empty TYPE string VALUE 'fixtures/empty.db'.
    CONSTANTS c_small TYPE string VALUE 'fixtures/small.db'.
    CONSTANTS c_three_pages TYPE string VALUE 'fixtures/three_pages.db'.
    CONSTANTS c_indexed TYPE string VALUE 'fixtures/indexed.db'.
    CONSTANTS c_serial_types TYPE string VALUE 'fixtures/serial_types.db'.
    CONSTANTS c_ten_thousand TYPE string VALUE 'fixtures/ten_thousand.db'.
    CONSTANTS c_overflow TYPE string VALUE 'fixtures/overflow.db'.

    METHODS empty_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS small_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS three_pages_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS indexed_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS serial_types_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS ten_thousand_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS overflow_fixture FOR TESTING RAISING zcx_sqlite_error.

    METHODS open_pager
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager
      RAISING   zcx_sqlite_error.
    METHODS assert_fixture
      IMPORTING iv_name     TYPE string
                it_expected TYPE zcl_sqlite_catalog=>ty_entries
      RAISING   zcx_sqlite_error.
    METHODS join_lines
      IMPORTING it_lines       TYPE string_table
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.


CLASS ltcl_catalog IMPLEMENTATION.

  METHOD empty_fixture.
    assert_fixture(
      iv_name = c_empty
      it_expected = VALUE zcl_sqlite_catalog=>ty_entries( ) ).
  ENDMETHOD.

  METHOD small_fixture.
    assert_fixture(
      iv_name = c_small
      it_expected = VALUE #(
        ( type = 'table' name = 'items' tbl_name = 'items' rootpage = 2
          sql = join_lines( VALUE #(
            ( |CREATE TABLE items (| )
            ( |      id INTEGER PRIMARY KEY,| )
            ( |      name TEXT NOT NULL,| )
            ( |      price REAL| )
            ( |    )| ) ) ) ) ) ).
  ENDMETHOD.

  METHOD three_pages_fixture.
    assert_fixture(
      iv_name = c_three_pages
      it_expected = VALUE #(
        ( type = 'table' name = 'items' tbl_name = 'items' rootpage = 2
          sql = 'CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT NOT NULL)' ) ) ).
  ENDMETHOD.

  METHOD indexed_fixture.
    assert_fixture(
      iv_name = c_indexed
      it_expected = VALUE #(
        ( type = 'table' name = 'items' tbl_name = 'items' rootpage = 2
          sql = 'CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT NOT NULL)' )
        ( type = 'index' name = 'items_value' tbl_name = 'items' rootpage = 3
          sql = 'CREATE INDEX items_value ON items(value)' ) ) ).
  ENDMETHOD.

  METHOD serial_types_fixture.
    assert_fixture(
      iv_name = c_serial_types
      it_expected = VALUE #(
        ( type = 'table' name = 'serial_types' tbl_name = 'serial_types'
          rootpage = 2
          sql = join_lines( VALUE #(
            ( |CREATE TABLE serial_types (| )
            ( |      c_null,| )
            ( |      c_int8,| )
            ( |      c_int16,| )
            ( |      c_int24,| )
            ( |      c_int32,| )
            ( |      c_int48,| )
            ( |      c_int64,| )
            ( |      c_real,| )
            ( |      c_zero,| )
            ( |      c_one,| )
            ( |      c_blob0,| )
            ( |      c_text0,| )
            ( |      c_blob3,| )
            ( |      c_text3,| )
            ( |      c_text| )
            ( |    )| ) ) ) ) ) ).
  ENDMETHOD.

  METHOD ten_thousand_fixture.
    assert_fixture(
      iv_name = c_ten_thousand
      it_expected = VALUE #(
        ( type = 'table' name = 'items' tbl_name = 'items' rootpage = 2
          sql = 'CREATE TABLE items (value TEXT NOT NULL)' ) ) ).
  ENDMETHOD.

  METHOD overflow_fixture.
    assert_fixture(
      iv_name = c_overflow
      it_expected = VALUE #(
        ( type = 'table' name = 'payloads' tbl_name = 'payloads' rootpage = 2
          sql = 'CREATE TABLE payloads (name TEXT NOT NULL, value)' ) ) ).
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( iv_name ).
    ro_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
  ENDMETHOD.

  METHOD assert_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_actual TYPE zcl_sqlite_catalog=>ty_entries.
    DATA ls_actual TYPE zcl_sqlite_catalog=>ty_entry.
    DATA ls_expected TYPE zcl_sqlite_catalog=>ty_entry.

    lo_pager = open_pager( iv_name ).
    lt_actual = zcl_sqlite_catalog=>read( lo_pager ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_actual )
      exp = lines( it_expected )
      msg = |{ iv_name } schema row count| ).

    LOOP AT it_expected INTO ls_expected.
      READ TABLE lt_actual INTO ls_actual INDEX sy-tabix.
      cl_abap_unit_assert=>assert_equals(
        act = sy-subrc exp = 0
        msg = |{ iv_name } schema row { sy-tabix } is missing| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_actual-type exp = ls_expected-type
        msg = |{ iv_name } schema row { sy-tabix } type| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_actual-name exp = ls_expected-name
        msg = |{ iv_name } schema row { sy-tabix } name| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_actual-tbl_name exp = ls_expected-tbl_name
        msg = |{ iv_name } schema row { sy-tabix } tbl_name| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_actual-rootpage exp = ls_expected-rootpage
        msg = |{ iv_name } schema row { sy-tabix } rootpage| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_actual-sql_is_null exp = ls_expected-sql_is_null
        msg = |{ iv_name } schema row { sy-tabix } sql null flag| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_actual-sql exp = ls_expected-sql
        msg = |{ iv_name } schema row { sy-tabix } sql| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD join_lines.
    DATA lv_line TYPE string.

    LOOP AT it_lines INTO lv_line.
      IF sy-tabix > 1.
        rv_text = rv_text && cl_abap_char_utilities=>newline.
      ENDIF.
      rv_text = rv_text && lv_line.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
