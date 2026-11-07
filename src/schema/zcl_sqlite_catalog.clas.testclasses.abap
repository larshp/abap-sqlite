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


CLASS ltcl_fixture_breadth DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_expected_value,
             kind    TYPE string,
             text    TYPE string,
             integer TYPE int8,
             real    TYPE f,
             blob    TYPE xstring,
           END OF ty_expected_value.
    TYPES: BEGIN OF ty_expected_row,
             c1    TYPE ty_expected_value,
             c2    TYPE ty_expected_value,
             c3    TYPE ty_expected_value,
             c4    TYPE ty_expected_value,
             count TYPE i,
           END OF ty_expected_row.
    TYPES ty_expected_rows TYPE STANDARD TABLE OF ty_expected_row WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_page_fixture,
             name      TYPE string,
             page_size TYPE i,
           END OF ty_page_fixture.
    TYPES ty_page_fixtures TYPE STANDARD TABLE OF ty_page_fixture WITH DEFAULT KEY.

    METHODS page_sizes FOR TESTING RAISING zcx_sqlite_error.
    METHODS small_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS three_pages_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS indexed_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS freelist_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS auto_vacuum_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS without_rowid_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS nulls_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS many_indexes_fixture FOR TESTING RAISING zcx_sqlite_error.

    METHODS open_pager
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager
      RAISING   zcx_sqlite_error.
    METHODS assert_table
      IMPORTING io_pager       TYPE REF TO zcl_sqlite_pager
                iv_name        TYPE string
                iv_root_page   TYPE i
                it_expected    TYPE ty_expected_rows
                iv_rowid_alias TYPE abap_bool DEFAULT abap_false
      RAISING   zcx_sqlite_error.
    METHODS assert_index
      IMPORTING io_pager     TYPE REF TO zcl_sqlite_pager
                iv_name      TYPE string
                iv_root_page TYPE i
                it_expected  TYPE ty_expected_rows
      RAISING   zcx_sqlite_error.
    METHODS assert_row
      IMPORTING io_values   TYPE zcl_sqlite_record=>ty_values
                is_expected TYPE ty_expected_row
                iv_context  TYPE string.
    METHODS assert_value
      IMPORTING io_value    TYPE REF TO zcl_sqlite_value
                is_expected TYPE ty_expected_value
                iv_context  TYPE string.
    METHODS text_value
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(rs_value) TYPE ty_expected_value.
    METHODS integer_value
      IMPORTING iv_integer      TYPE i
      RETURNING VALUE(rs_value) TYPE ty_expected_value.
    METHODS real_value
      IMPORTING iv_real         TYPE f
      RETURNING VALUE(rs_value) TYPE ty_expected_value.
    METHODS null_value
      RETURNING VALUE(rs_value) TYPE ty_expected_value.
    METHODS blob_value
      IMPORTING iv_blob         TYPE xstring
      RETURNING VALUE(rs_value) TYPE ty_expected_value.
    METHODS page_value
      IMPORTING iv_size         TYPE i
                iv_id           TYPE i
      RETURNING VALUE(rv_value) TYPE string.
    METHODS bulk_value
      IMPORTING iv_id           TYPE i
      RETURNING VALUE(rv_value) TYPE string.
    METHODS padding
      IMPORTING iv_value       TYPE i
                iv_width       TYPE i
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.


CLASS ltcl_fixture_breadth IMPLEMENTATION.

  METHOD page_sizes.
    DATA lt_fixtures TYPE ty_page_fixtures.
    DATA ls_fixture TYPE ty_page_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.
    DATA lt_table TYPE ty_expected_rows.
    DATA lt_index TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_id TYPE i.
    DATA lv_value TYPE string.

    lt_fixtures = VALUE #(
      ( name = 'fixtures/page_512.db' page_size = 512 )
      ( name = 'fixtures/page_1024.db' page_size = 1024 )
      ( name = 'fixtures/page_2048.db' page_size = 2048 )
      ( name = 'fixtures/page_4096.db' page_size = 4096 )
      ( name = 'fixtures/page_8192.db' page_size = 8192 )
      ( name = 'fixtures/page_16384.db' page_size = 16384 )
      ( name = 'fixtures/page_32768.db' page_size = 32768 )
      ( name = 'fixtures/page_65536.db' page_size = 65536 ) ).

    LOOP AT lt_fixtures INTO ls_fixture.
      CLEAR lt_table.
      CLEAR lt_index.
      DO 40 TIMES.
        lv_id = sy-index.
        lv_value = page_value(
          iv_size = ls_fixture-page_size
          iv_id = lv_id ).
        ls_row = VALUE #(
          c1 = integer_value( lv_id )
          c2 = text_value( lv_value )
          count = 2 ).
        APPEND ls_row TO lt_table.
        ls_row = VALUE #(
          c1 = text_value( lv_value )
          c2 = integer_value( lv_id )
          count = 2 ).
        APPEND ls_row TO lt_index.
      ENDDO.

      lo_pager = open_pager( ls_fixture-name ).
      ls_header = lo_pager->header( ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_header-page_size exp = ls_fixture-page_size
        msg = |{ ls_fixture-name } page size| ).
      assert_table(
        io_pager = lo_pager
        iv_name = ls_fixture-name
        iv_root_page = 2
        it_expected = lt_table ).
      assert_index(
        io_pager = lo_pager
        iv_name = ls_fixture-name
        iv_root_page = 3
        it_expected = lt_index ).
    ENDLOOP.
  ENDMETHOD.

  METHOD small_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_expected TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.

    lo_pager = open_pager( 'fixtures/small.db' ).
* ANORMALY: nested inline table constructors are rejected by the parser,
* see ANORMALIES.md
    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = text_value( 'alpha' )
* ANORMALY: numeric literals are rejected as method arguments
      c3 = real_value( '1.5' ) count = 3 ).
    APPEND ls_row TO lt_expected.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = text_value( 'beta' )
      c3 = real_value( '2.25' ) count = 3 ).
    APPEND ls_row TO lt_expected.
    ls_row = VALUE #(
      c1 = integer_value( 3 ) c2 = text_value( 'gamma' )
      c3 = null_value( ) count = 3 ).
    APPEND ls_row TO lt_expected.
    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/small.db'
      iv_root_page = 2
      it_expected = lt_expected
      iv_rowid_alias = abap_true ).
  ENDMETHOD.

  METHOD three_pages_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_expected TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_id TYPE i.

    lo_pager = open_pager( 'fixtures/three_pages.db' ).
    DO 200 TIMES.
      lv_id = sy-index.
      ls_row = VALUE #(
        c1 = integer_value( lv_id )
        c2 = text_value( bulk_value( lv_id ) )
        count = 2 ).
      APPEND ls_row TO lt_expected.
    ENDDO.
    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/three_pages.db'
      iv_root_page = 2
      it_expected = lt_expected
      iv_rowid_alias = abap_true ).
  ENDMETHOD.

  METHOD indexed_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_expected TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_id TYPE i.

    lo_pager = open_pager( 'fixtures/indexed.db' ).
    DO 100 TIMES.
      lv_id = sy-index.
      ls_row = VALUE #(
        c1 = integer_value( lv_id )
        c2 = text_value( bulk_value( lv_id ) )
        count = 2 ).
      APPEND ls_row TO lt_expected.
    ENDDO.
    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/indexed.db'
      iv_root_page = 2
      it_expected = lt_expected
      iv_rowid_alias = abap_true ).
  ENDMETHOD.

  METHOD freelist_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.
    DATA lt_table TYPE ty_expected_rows.
    DATA lt_index TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_id TYPE i.
    DATA lv_value TYPE string.
    DATA lv_has_trunk TYPE abap_bool.

    lo_pager = open_pager( 'fixtures/freelist.db' ).
    ls_header = lo_pager->header( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-page_size exp = 512
      msg = 'freelist page size' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_pages exp = 37
      msg = 'freelist page count' ).
    lv_has_trunk = boolc( ls_header-freelist_trunk > 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_has_trunk exp = abap_true
      msg = 'freelist trunk pointer' ).

    DO 20 TIMES.
      lv_id = sy-index.
      lv_value = |keep-{ padding( iv_value = lv_id iv_width = 3 ) }|.
      ls_row = VALUE #(
        c1 = integer_value( lv_id )
        c2 = text_value( lv_value )
        count = 2 ).
      APPEND ls_row TO lt_table.
      ls_row = VALUE #(
        c1 = text_value( lv_value )
        c2 = integer_value( lv_id )
        count = 2 ).
      APPEND ls_row TO lt_index.
    ENDDO.

    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/freelist.db'
      iv_root_page = 2
      it_expected = lt_table ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/freelist.db'
      iv_root_page = 3
      it_expected = lt_index ).
  ENDMETHOD.

  METHOD auto_vacuum_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA ls_header TYPE zcl_sqlite_header=>ty_header.
    DATA ls_page TYPE zcl_sqlite_pager=>ty_page.
    DATA lt_table TYPE ty_expected_rows.
    DATA lt_index TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_id TYPE i.
    DATA lv_value TYPE string.

    lo_pager = open_pager( 'fixtures/auto_vacuum.db' ).
    ls_header = lo_pager->header( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-page_size exp = 512
      msg = 'auto-vacuum page size' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-incremental_vacuum exp = 0
      msg = 'full auto-vacuum mode is not incremental' ).

    ls_page = lo_pager->get_page( 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_sqlite_bytes=>read_u8(
        iv_data = ls_page-data iv_offset = 0 )
      exp = 1
      msg = 'auto-vacuum pointer map page' ).

    DO 20 TIMES.
      lv_id = sy-index.
      lv_value = |auto-{ padding( iv_value = lv_id iv_width = 3 ) }|.
      ls_row = VALUE #(
        c1 = integer_value( lv_id )
        c2 = text_value( lv_value )
        count = 2 ).
      APPEND ls_row TO lt_table.
      ls_row = VALUE #(
        c1 = text_value( lv_value )
        c2 = integer_value( lv_id )
        count = 2 ).
      APPEND ls_row TO lt_index.
    ENDDO.

    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/auto_vacuum.db'
      iv_root_page = 3
      it_expected = lt_table ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/auto_vacuum.db'
      iv_root_page = 4
      it_expected = lt_index ).
  ENDMETHOD.

  METHOD without_rowid_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_table TYPE ty_expected_rows.
    DATA lt_index TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_id TYPE i.
    DATA lv_key TYPE string.
    DATA lv_value TYPE string.

    lo_pager = open_pager( 'fixtures/without_rowid.db' ).
    DO 40 TIMES.
      lv_id = sy-index.
      lv_key = |key-{ padding( iv_value = lv_id iv_width = 3 ) }|.
      lv_value = |value-{ padding( iv_value = lv_id iv_width = 3 ) }|.
      ls_row = VALUE #(
        c1 = text_value( lv_key )
        c2 = text_value( lv_value )
        c3 = integer_value( lv_id )
        count = 3 ).
      APPEND ls_row TO lt_table.
      ls_row = VALUE #(
        c1 = text_value( lv_value )
        c2 = text_value( lv_key )
        count = 2 ).
      APPEND ls_row TO lt_index.
    ENDDO.

    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/without_rowid.db table'
      iv_root_page = 2
      it_expected = lt_table ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/without_rowid.db index'
      iv_root_page = 3
      it_expected = lt_index ).
  ENDMETHOD.

  METHOD nulls_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_table TYPE ty_expected_rows.
    DATA lt_a TYPE ty_expected_rows.
    DATA lt_ab TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.
    DATA lv_empty_blob TYPE xstring.

    lo_pager = open_pager( 'fixtures/nulls.db' ).
    lv_empty_blob = ''.

    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = text_value( 'a' )
      c3 = integer_value( 1 )
* ANORMALY: hex literals are rejected as method arguments
      c4 = blob_value( '01' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = null_value( )
      c3 = integer_value( 2 ) c4 = null_value( ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 3 ) c2 = text_value( 'a' )
      c3 = null_value( ) c4 = blob_value( lv_empty_blob ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 4 ) c2 = null_value( )
      c3 = null_value( ) c4 = blob_value( '03' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 5 ) c2 = text_value( 'b' )
      c3 = integer_value( 2 ) c4 = null_value( ) count = 4 ).
    APPEND ls_row TO lt_table.

    ls_row = VALUE #(
      c1 = null_value( ) c2 = integer_value( 2 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = null_value( ) c2 = integer_value( 4 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 1 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 3 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 5 ) count = 2 ).
    APPEND ls_row TO lt_a.

    ls_row = VALUE #(
      c1 = null_value( ) c2 = null_value( )
      c3 = integer_value( 4 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = null_value( ) c2 = integer_value( 2 )
      c3 = integer_value( 2 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = null_value( )
      c3 = integer_value( 3 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 1 )
      c3 = integer_value( 1 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 2 )
      c3 = integer_value( 5 ) count = 3 ).
    APPEND ls_row TO lt_ab.

    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/nulls.db table'
      iv_root_page = 2
      it_expected = lt_table ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/nulls.db index a'
      iv_root_page = 3
      it_expected = lt_a ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/nulls.db index a,b'
      iv_root_page = 4
      it_expected = lt_ab ).
  ENDMETHOD.

  METHOD many_indexes_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lt_table TYPE ty_expected_rows.
    DATA lt_a TYPE ty_expected_rows.
    DATA lt_ab TYPE ty_expected_rows.
    DATA lt_ba TYPE ty_expected_rows.
    DATA lt_b TYPE ty_expected_rows.
    DATA lt_c TYPE ty_expected_rows.
    DATA ls_row TYPE ty_expected_row.

    lo_pager = open_pager( 'fixtures/many_indexes.db' ).

    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = text_value( 'a' )
      c3 = integer_value( 1 ) c4 = text_value( 'c1' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = text_value( 'a' )
      c3 = integer_value( 2 ) c4 = text_value( 'c2' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 3 ) c2 = text_value( 'b' )
      c3 = integer_value( 1 ) c4 = text_value( 'c3' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 4 ) c2 = text_value( 'b' )
      c3 = integer_value( 2 ) c4 = text_value( 'c4' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 5 ) c2 = text_value( 'a' )
      c3 = integer_value( 1 ) c4 = text_value( 'c5' ) count = 4 ).
    APPEND ls_row TO lt_table.
    ls_row = VALUE #(
      c1 = integer_value( 6 ) c2 = text_value( 'b' )
      c3 = integer_value( 2 ) c4 = text_value( 'c6' ) count = 4 ).
    APPEND ls_row TO lt_table.

    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 1 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 2 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 5 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 3 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 4 ) count = 2 ).
    APPEND ls_row TO lt_a.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 6 ) count = 2 ).
    APPEND ls_row TO lt_a.

    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 1 )
      c3 = integer_value( 1 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 1 )
      c3 = integer_value( 5 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'a' ) c2 = integer_value( 2 )
      c3 = integer_value( 2 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 1 )
      c3 = integer_value( 3 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 2 )
      c3 = integer_value( 4 ) count = 3 ).
    APPEND ls_row TO lt_ab.
    ls_row = VALUE #(
      c1 = text_value( 'b' ) c2 = integer_value( 2 )
      c3 = integer_value( 6 ) count = 3 ).
    APPEND ls_row TO lt_ab.

    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = text_value( 'a' )
      c3 = integer_value( 1 ) count = 3 ).
    APPEND ls_row TO lt_ba.
    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = text_value( 'a' )
      c3 = integer_value( 5 ) count = 3 ).
    APPEND ls_row TO lt_ba.
    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = text_value( 'b' )
      c3 = integer_value( 3 ) count = 3 ).
    APPEND ls_row TO lt_ba.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = text_value( 'a' )
      c3 = integer_value( 2 ) count = 3 ).
    APPEND ls_row TO lt_ba.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = text_value( 'b' )
      c3 = integer_value( 4 ) count = 3 ).
    APPEND ls_row TO lt_ba.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = text_value( 'b' )
      c3 = integer_value( 6 ) count = 3 ).
    APPEND ls_row TO lt_ba.

    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = integer_value( 1 ) count = 2 ).
    APPEND ls_row TO lt_b.
    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = integer_value( 3 ) count = 2 ).
    APPEND ls_row TO lt_b.
    ls_row = VALUE #(
      c1 = integer_value( 1 ) c2 = integer_value( 5 ) count = 2 ).
    APPEND ls_row TO lt_b.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = integer_value( 2 ) count = 2 ).
    APPEND ls_row TO lt_b.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = integer_value( 4 ) count = 2 ).
    APPEND ls_row TO lt_b.
    ls_row = VALUE #(
      c1 = integer_value( 2 ) c2 = integer_value( 6 ) count = 2 ).
    APPEND ls_row TO lt_b.

    ls_row = VALUE #(
      c1 = text_value( 'c1' ) c2 = integer_value( 1 ) count = 2 ).
    APPEND ls_row TO lt_c.
    ls_row = VALUE #(
      c1 = text_value( 'c2' ) c2 = integer_value( 2 ) count = 2 ).
    APPEND ls_row TO lt_c.
    ls_row = VALUE #(
      c1 = text_value( 'c3' ) c2 = integer_value( 3 ) count = 2 ).
    APPEND ls_row TO lt_c.
    ls_row = VALUE #(
      c1 = text_value( 'c4' ) c2 = integer_value( 4 ) count = 2 ).
    APPEND ls_row TO lt_c.
    ls_row = VALUE #(
      c1 = text_value( 'c5' ) c2 = integer_value( 5 ) count = 2 ).
    APPEND ls_row TO lt_c.
    ls_row = VALUE #(
      c1 = text_value( 'c6' ) c2 = integer_value( 6 ) count = 2 ).
    APPEND ls_row TO lt_c.

    assert_table(
      io_pager = lo_pager
      iv_name = 'fixtures/many_indexes.db table'
      iv_root_page = 2
      it_expected = lt_table ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/many_indexes.db index a'
      iv_root_page = 3
      it_expected = lt_a ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/many_indexes.db index a,b'
      iv_root_page = 4
      it_expected = lt_ab ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/many_indexes.db index b,a'
      iv_root_page = 5
      it_expected = lt_ba ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/many_indexes.db index b'
      iv_root_page = 6
      it_expected = lt_b ).
    assert_index(
      io_pager = lo_pager
      iv_name = 'fixtures/many_indexes.db index c'
      iv_root_page = 7
      it_expected = lt_c ).
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( iv_name ).
    ro_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
  ENDMETHOD.

  METHOD assert_table.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lv_count TYPE i.
    DATA ls_expected TYPE ty_expected_row.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lt_raw TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager = io_pager
      iv_root_page = iv_root_page ).
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      IF lv_count > lines( it_expected ).
        cl_abap_unit_assert=>fail( msg = |{ iv_name } returned too many table rows| ).
      ENDIF.
      READ TABLE it_expected INTO ls_expected INDEX lv_count.
      lt_raw = lo_cursor->values( ).
      CLEAR lt_values.
      IF iv_rowid_alias = abap_true.
        APPEND zcl_sqlite_value=>integer( lo_cursor->rowid( ) ) TO lt_values.
        LOOP AT lt_raw INTO lo_value.
          IF sy-tabix > 1.
            APPEND lo_value TO lt_values.
          ENDIF.
        ENDLOOP.
      ELSE.
        lt_values = lt_raw.
      ENDIF.
      assert_row(
        io_values = lt_values
        is_expected = ls_expected
        iv_context = |{ iv_name } table row { lv_count }| ).
      lv_found = lo_cursor->next( ).
    ENDWHILE.

    cl_abap_unit_assert=>assert_equals(
      act = lv_count exp = lines( it_expected )
      msg = |{ iv_name } table row count| ).
  ENDMETHOD.

  METHOD assert_index.
    DATA lo_cursor TYPE REF TO zcl_sqlite_index_cursor.
    DATA lv_found TYPE abap_bool.
    DATA lv_count TYPE i.
    DATA ls_expected TYPE ty_expected_row.

    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager = io_pager
      iv_root_page = iv_root_page ).
    lv_found = lo_cursor->first( ).
    WHILE lv_found = abap_true.
      lv_count = lv_count + 1.
      IF lv_count > lines( it_expected ).
        cl_abap_unit_assert=>fail( msg = |{ iv_name } returned too many index entries| ).
      ENDIF.
      READ TABLE it_expected INTO ls_expected INDEX lv_count.
      assert_row(
        io_values = lo_cursor->values( )
        is_expected = ls_expected
        iv_context = |{ iv_name } index entry { lv_count }| ).
      lv_found = lo_cursor->next( ).
    ENDWHILE.

    cl_abap_unit_assert=>assert_equals(
      act = lv_count exp = lines( it_expected )
      msg = |{ iv_name } index entry count| ).
  ENDMETHOD.

  METHOD assert_row.
    DATA lt_actual TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lt_actual = io_values.
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_actual ) exp = is_expected-count
      msg = |{ iv_context } value count| ).

    DO is_expected-count TIMES.
      READ TABLE lt_actual INTO lo_value INDEX sy-index.
      cl_abap_unit_assert=>assert_equals(
        act = sy-subrc exp = 0
        msg = |{ iv_context } value { sy-index } is missing| ).
      CASE sy-index.
        WHEN 1.
          assert_value(
            io_value = lo_value
            is_expected = is_expected-c1
            iv_context = |{ iv_context } value { sy-index }| ).
        WHEN 2.
          assert_value(
            io_value = lo_value
            is_expected = is_expected-c2
            iv_context = |{ iv_context } value { sy-index }| ).
        WHEN 3.
          assert_value(
            io_value = lo_value
            is_expected = is_expected-c3
            iv_context = |{ iv_context } value { sy-index }| ).
        WHEN 4.
          assert_value(
            io_value = lo_value
            is_expected = is_expected-c4
            iv_context = |{ iv_context } value { sy-index }| ).
      ENDCASE.
    ENDDO.
  ENDMETHOD.

  METHOD assert_value.
    CASE is_expected-kind.
      WHEN 'TEXT'.
        cl_abap_unit_assert=>assert_equals(
          act = io_value->value_type( ) exp = zcl_sqlite_value=>c_text
          msg = |{ iv_context } type| ).
        cl_abap_unit_assert=>assert_equals(
          act = io_value->as_text( ) exp = is_expected-text
          msg = |{ iv_context } text| ).
      WHEN 'INTEGER'.
        cl_abap_unit_assert=>assert_equals(
          act = io_value->value_type( ) exp = zcl_sqlite_value=>c_integer
          msg = |{ iv_context } type| ).
        cl_abap_unit_assert=>assert_equals(
          act = io_value->as_integer( ) exp = is_expected-integer
          msg = |{ iv_context } integer| ).
      WHEN 'REAL'.
        cl_abap_unit_assert=>assert_equals(
          act = io_value->value_type( ) exp = zcl_sqlite_value=>c_real
          msg = |{ iv_context } type| ).
        cl_abap_unit_assert=>assert_equals(
          act = io_value->as_real( ) exp = is_expected-real
          msg = |{ iv_context } real| ).
      WHEN 'BLOB'.
        cl_abap_unit_assert=>assert_equals(
          act = io_value->value_type( ) exp = zcl_sqlite_value=>c_blob
          msg = |{ iv_context } type| ).
        cl_abap_unit_assert=>assert_equals(
          act = io_value->as_blob( ) exp = is_expected-blob
          msg = |{ iv_context } blob| ).
      WHEN 'NULL'.
        cl_abap_unit_assert=>assert_equals(
          act = io_value->is_null( ) exp = abap_true
          msg = |{ iv_context } is null| ).
      WHEN OTHERS.
        cl_abap_unit_assert=>fail( msg = |{ iv_context } expectation kind is invalid| ).
    ENDCASE.
  ENDMETHOD.

  METHOD text_value.
    rs_value-kind = 'TEXT'.
    rs_value-text = iv_text.
  ENDMETHOD.

  METHOD integer_value.
    rs_value-kind = 'INTEGER'.
    rs_value-integer = iv_integer.
  ENDMETHOD.

  METHOD real_value.
    rs_value-kind = 'REAL'.
    rs_value-real = iv_real.
  ENDMETHOD.

  METHOD null_value.
    rs_value-kind = 'NULL'.
  ENDMETHOD.

  METHOD blob_value.
    rs_value-kind = 'BLOB'.
    rs_value-blob = iv_blob.
  ENDMETHOD.

  METHOD page_value.
    rv_value = |page-{ padding( iv_value = iv_size iv_width = 5 ) }-{ padding( iv_value = iv_id iv_width = 3 ) }-{ repeat( val = 'x' occ = 20 ) }|.
  ENDMETHOD.

  METHOD bulk_value.
    rv_value = |value-{ padding( iv_value = iv_id iv_width = 3 ) }-{ repeat( val = 'x' occ = 40 ) }|.
  ENDMETHOD.

  METHOD padding.
    DATA lv_value TYPE string.

    lv_value = iv_value.
* ANORMALY: integer to string leaves a trailing blank in the transpiler,
* see ANORMALIES.md
    CONDENSE lv_value.
    WHILE strlen( lv_value ) < iv_width.
      lv_value = |0{ lv_value }|.
    ENDWHILE.
    rv_text = lv_value.
  ENDMETHOD.

ENDCLASS.
