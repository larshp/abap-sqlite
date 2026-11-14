CLASS ltcl_database DEFINITION FINAL FOR TESTING
  DURATION MEDIUM
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS create_empty_database FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_table FOR TESTING RAISING zcx_sqlite_error.
    METHODS insert_values FOR TESTING RAISING zcx_sqlite_error.
    METHODS insert_select FOR TESTING RAISING zcx_sqlite_error.
    METHODS delete_rows FOR TESTING RAISING zcx_sqlite_error.
    METHODS update_rows FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_index FOR TESTING RAISING zcx_sqlite_error.
    METHODS index_maintenance FOR TESTING RAISING zcx_sqlite_error.
    METHODS index_delete_all FOR TESTING RAISING zcx_sqlite_error.
    METHODS drop_table_and_index FOR TESTING RAISING zcx_sqlite_error.
    METHODS transactions FOR TESTING RAISING zcx_sqlite_error.
    METHODS abap_luw FOR TESTING RAISING zcx_sqlite_error.
    METHODS prepared_select FOR TESTING RAISING zcx_sqlite_error.
    METHODS prepared_dml FOR TESTING RAISING zcx_sqlite_error.
    METHODS prepared_named FOR TESTING RAISING zcx_sqlite_error.
    METHODS database_api FOR TESTING RAISING zcx_sqlite_error.
    METHODS exec_script FOR TESTING RAISING zcx_sqlite_error.
    METHODS database_error_codes FOR TESTING RAISING zcx_sqlite_error.
    METHODS abap_conveniences FOR TESTING RAISING zcx_sqlite_error.

    TYPES: BEGIN OF ty_abap_row,
             id      TYPE i,
             big     TYPE int8,
             small   TYPE int1,
             medium  TYPE int2,
             name    TYPE string,
             code    TYPE c LENGTH 10,
             num     TYPE n LENGTH 5,
             amount  TYPE p LENGTH 8 DECIMALS 2,
             ratio   TYPE f,
             created TYPE d,
             at      TYPE t,
             payload TYPE xstring,
             fixed   TYPE x LENGTH 4,
           END OF ty_abap_row,
           ty_abap_rows TYPE STANDARD TABLE OF ty_abap_row WITH DEFAULT KEY.

    METHODS count_rows
      IMPORTING io_database     TYPE REF TO zcl_sqlite_database
                iv_sql          TYPE string
      RETURNING VALUE(rv_count) TYPE i
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS ltcl_database IMPLEMENTATION.

  METHOD create_table.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_header   TYPE zcl_sqlite_header=>ty_header.
    DATA lt_entries  TYPE zcl_sqlite_catalog=>ty_entries.
    DATA ls_entry    TYPE zcl_sqlite_catalog=>ty_entry.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA lv_data     TYPE xstring.
    DATA lv_name     TYPE string.
    DATA lv_sql      TYPE string.

    lv_name = 'test/m5_7_create_table.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lv_sql = 'CREATE TABLE created (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)'.
    lo_database->execute( lv_sql ).

    rs_result = lo_database->query( 'SELECT id, name FROM created' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 2
      msg = 'created table column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 0
      msg = 'created table is empty' ).

    lo_database->execute( 'CREATE TABLE IF NOT EXISTS created (id INTEGER)' ).
    lo_database->execute( 'CREATE TABLE notes (body TEXT)' ).
    lo_database->close( ).

    lv_data = lo_vfs->export( lv_name ).
    ls_header = zcl_sqlite_header=>parse( lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = 3
      msg = 'created table page count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_pages
      exp = 0
      msg = 'created table freelist' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 3
      msg = 'schema cookie after two tables' ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lt_entries = zcl_sqlite_catalog=>read( lo_pager ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_entries )
      exp = 2
      msg = 'sqlite_schema row count' ).

    READ TABLE lt_entries INTO ls_entry INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-type
      exp = 'table' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-name
      exp = 'created' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-tbl_name
      exp = 'created' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-rootpage
      exp = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-sql
      exp = lv_sql ).

    READ TABLE lt_entries INTO ls_entry INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-name
      exp = 'notes' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-rootpage
      exp = 3 ).
    lo_file->close( ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT id FROM created' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 1
      msg = 'created table survives reopen' ).

    TRY.
        lo_database->execute( lv_sql ).
        cl_abap_unit_assert=>fail( 'duplicate table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE IF NOT EXISTS created (id INTEGER)' ).
    lo_database->close( ).

    lv_data = lo_vfs->export( lv_name ).
    ls_header = zcl_sqlite_header=>parse( lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 3
      msg = 'no-op create table must not bump the schema cookie' ).

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD insert_values.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lv_name = 'test/m5_8_insert.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT ''anon'',' &&
      ' qty INTEGER DEFAULT 7, price REAL, note TEXT, bin BLOB)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 0
      msg = 'create table changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 0
      msg = 'initial last_insert_rowid' ).

    lo_database->execute( 'INSERT INTO items (name, qty, price) VALUES (''alpha'', 2, 3.5)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'single insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 1
      msg = 'single insert rowid' ).

    rs_result = lo_database->query(
      'SELECT id, name, typeof(qty), qty, typeof(price), quote(price), ' &&
      'typeof(note), typeof(bin) FROM items' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'single insert row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'assigned rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'alpha'
      msg = 'inserted name' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'integer'
      msg = 'integer affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'inserted integer' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'real'
      msg = 'real affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '3.5'
      msg = 'real quote' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'missing column is null' ).
    READ TABLE ls_row INTO lo_value INDEX 8.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'missing blob is null' ).

    lo_database->execute( 'INSERT INTO items (id, name, price) VALUES (10, ''beta'', 4)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 10
      msg = 'explicit rowid alias' ).
    rs_result = lo_database->query(
      'SELECT qty, typeof(price), quote(price), typeof(note) FROM items WHERE id = 10' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'default applied' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'real'
      msg = 'integer to real affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '4.0'
      msg = 'integer stored as real' ).

    lo_database->execute( 'INSERT INTO items DEFAULT VALUES' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 11
      msg = 'default values rowid' ).
    rs_result = lo_database->query(
      'SELECT id, name, qty, typeof(price), quote(price) FROM items WHERE id = 11' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'anon'
      msg = 'default text' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'default integer' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'default null' ).

    lo_database->execute(
      'INSERT INTO items VALUES (NULL, ''gamma'', ''8'', ''2.5'', ''x'', x''0102''), ' &&
      '(100, ''delta'', 9, 0, NULL, NULL)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 2
      msg = 'multi-row insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 100
      msg = 'multi-row insert last rowid' ).
    rs_result = lo_database->query(
      'SELECT id, typeof(qty), qty, typeof(price), quote(price), note, typeof(bin) ' &&
      'FROM items WHERE id IN (12, 100) ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'multi-row insert row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 12
      msg = 'rowid after explicit maximum' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'integer'
      msg = 'numeric text affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 8
      msg = 'numeric text converted' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '2.5'
      msg = 'numeric text to real' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'x'
      msg = 'text value' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'blob'
      msg = 'blob value' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 100
      msg = 'explicit multi-row rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '0.0'
      msg = 'zero integer stored as real' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'explicit null' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'null blob' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'inserted row count' ).

    TRY.
        lo_database->execute( 'INSERT INTO items (bogus) VALUES (1)' ).
        cl_abap_unit_assert=>fail( 'unknown column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.
    TRY.
        lo_database->execute( 'INSERT INTO items (name) VALUES (NULL)' ).
        cl_abap_unit_assert=>fail( 'not null violation was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'inserts survive reopen' ).
    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD insert_select.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lv_name = 'test/m5_8_insert_select.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE source (id INTEGER PRIMARY KEY, label TEXT, amount NUMERIC)' ).
    lo_database->execute(
      'CREATE TABLE dest (id INTEGER PRIMARY KEY, label TEXT NOT NULL,' &&
      ' amount REAL DEFAULT 1.0, status TEXT DEFAULT ''new'')' ).
    lo_database->execute(
      'INSERT INTO source VALUES (1, ''one'', 10), (2, ''two'', 2.5), ' &&
      '(3, ''three'', ''4'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 3
      msg = 'source insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'source insert last rowid' ).

    lo_database->execute( 'INSERT INTO dest (label, amount) SELECT label, amount FROM source ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 3
      msg = 'insert select changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'insert select last rowid' ).

    rs_result = lo_database->query(
      'SELECT id, label, typeof(amount), quote(amount), status FROM dest ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'insert select row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'insert select first id' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'one'
      msg = 'insert select first label' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'real'
      msg = 'insert select real affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '10.0'
      msg = 'insert select real quote' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'new'
      msg = 'insert select default' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '4.0'
      msg = 'numeric source to real destination' ).

    lo_database->execute( 'INSERT INTO dest (label) SELECT ''four''' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 4
      msg = 'insert select default rowid' ).
    rs_result = lo_database->query( 'SELECT quote(amount), status FROM dest WHERE id = 4' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '1.0'
      msg = 'default real value' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'new'
      msg = 'default text value' ).

    lo_database->execute( 'INSERT INTO dest SELECT 100, ''five'', 5.5, ''old''' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 100
      msg = 'insert select explicit rowid' ).

    lo_database->execute(
      'INSERT INTO dest (label, amount, status) ' &&
      'SELECT label, amount, status FROM dest WHERE id = 100' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 101
      msg = 'insert select from same table' ).

    lo_database->execute( 'INSERT INTO dest (label) VALUES (''six'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 102
      msg = 'auto rowid after select inserts' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'last insert changes' ).

    rs_result = lo_database->query( 'SELECT id, label, quote(amount), status FROM dest ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 7
      msg = 'final destination row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 6.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 101
      msg = 'same-table select copy rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '5.5'
      msg = 'same-table select copy amount' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 7.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 102
      msg = 'final auto rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '1.0'
      msg = 'final default amount' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD create_empty_database.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_header   TYPE zcl_sqlite_header=>ty_header.
    DATA ls_page     TYPE zcl_sqlite_page=>ty_page.
    DATA lt_entries  TYPE zcl_sqlite_catalog=>ty_entries.
    DATA lv_data     TYPE xstring.
    DATA lv_name     TYPE string.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lv_name = 'test/m5_2_empty.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT 1 + 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'empty database is queryable' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'empty database constant' ).
    lo_database->close( ).

    lv_data = lo_vfs->export( lv_name ).
    cl_abap_unit_assert=>assert_equals(
      act = xstrlen( lv_data )
      exp = 4096
      msg = 'new database size' ).

    ls_header = zcl_sqlite_header=>parse( lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-page_size
      exp = 4096
      msg = 'new database page size' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = 1
      msg = 'new database page count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-change_counter
      exp = 1
      msg = 'new database change counter' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 1
      msg = 'new database schema cookie' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-text_encoding
      exp = zcl_sqlite_header=>c_encoding_utf8
      msg = 'new database text encoding' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-version_valid_for
      exp = 1
      msg = 'new database version valid for' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-sqlite_version
      exp = zcl_sqlite_header=>c_sqlite_version
      msg = 'new database SQLite version' ).

    ls_page = zcl_sqlite_page=>parse( iv_data   = lv_data
                                      iv_offset = 100 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-page_type
      exp = zcl_sqlite_page=>c_table_leaf
      msg = 'sqlite_schema page type' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_count
      exp = 0
      msg = 'sqlite_schema cell count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_content_offset
      exp = 4096
      msg = 'sqlite_schema content offset' ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lt_entries = zcl_sqlite_catalog=>read( lo_pager ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_entries )
      exp = 0
      msg = 'sqlite_schema is empty' ).
    lo_file->close( ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT 1' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'reopening an existing database keeps it usable' ).
    lo_database->close( ).

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
    TRY.
        lo_database = zcl_sqlite_database=>open(
          iv_name   = lv_name
          iv_create = abap_false ).
        cl_abap_unit_assert=>fail( 'missing database must not open without create' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_cantopen
          msg = 'missing database error code' ).
    ENDTRY.

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD delete_rows.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_suffix   TYPE string.
    DATA lv_values   TYPE string.

    lv_name = 'test/m5_9_delete.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL,' &&
      ' tag TEXT, bin BLOB)' ).

    lv_suffix = repeat( val = 'x'
                        occ = 40 ).
    DO 200 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values && |({ sy-index }, 'row-{ sy-index }-{ lv_suffix }')|.
    ENDDO.
    lo_database->execute( |INSERT INTO items (id, name) VALUES { lv_values }| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 200
      msg = 'bulk insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'bulk insert last rowid' ).

    lo_database->execute( 'DELETE FROM items WHERE id % 3 = 0' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 66
      msg = 'modulo delete changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'delete keeps last_insert_rowid' ).

    lo_database->execute( 'DELETE FROM items WHERE id BETWEEN 50 AND 60' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 7
      msg = 'range delete changes' ).

    lo_database->execute( 'DELETE FROM items WHERE id IN (1, 2, 4, 5, 199, 200)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 6
      msg = 'in-list delete changes' ).

    lo_database->execute( 'DELETE FROM items WHERE id = 9999' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 0
      msg = 'delete without matches changes' ).

    rs_result = lo_database->query( 'SELECT count(*), min(id), max(id) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 121
      msg = 'remaining row count' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'remaining minimum id' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 197
      msg = 'remaining maximum id' ).

    rs_result = lo_database->query(
      'SELECT id FROM items' &&
      ' WHERE id IN (1, 3, 6, 7, 50, 51, 52, 60, 61, 199, 200) ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'survivor count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'first survivor' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 61
      msg = 'second survivor' ).

    lo_database->execute( 'DELETE FROM items' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 121
      msg = 'delete all changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'delete all keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'empty table after delete all' ).

    lo_database->execute( 'INSERT INTO items (name) VALUES (''after'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 1
      msg = 'insert after empty table' ).
    lo_database->execute( 'DELETE FROM items AS x WHERE x.id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'aliased delete changes' ).

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'deletes survive reopen' ).

    TRY.
        lo_database->execute( 'DELETE FROM missing WHERE id = 1' ).
        cl_abap_unit_assert=>fail( 'delete from unknown table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD update_rows.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_suffix   TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_expected TYPE f.

    lv_name = 'test/m5_10_update.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL,' &&
      ' amount REAL, note TEXT, bin BLOB)' ).

    lv_suffix = repeat( val = 'x'
                        occ = 40 ).
    DO 200 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values && |({ sy-index }, 'row-{ sy-index }-{ lv_suffix }', { sy-index })|.
    ENDDO.
    lo_database->execute( |INSERT INTO items (id, name, amount) VALUES { lv_values }| ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 200
      msg = 'insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'insert last rowid' ).

    lo_database->execute(
      'UPDATE items SET name = name || ''-u'', amount = amount * 2,' &&
      ' note = ''n-'' || id WHERE id % 3 = 0' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 66
      msg = 'modulo update changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'update keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT name, amount, note FROM items WHERE id = 3' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = |row-3-{ lv_suffix }-u|
      msg = 'updated name' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    lv_expected = '6'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'updated amount' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'n-3'
      msg = 'updated note' ).

    rs_result = lo_database->query( 'SELECT note FROM items WHERE id = 4' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'unmatched note stays null' ).

    lo_database->execute( 'UPDATE items AS x SET amount = amount + x.id WHERE x.id BETWEEN 10 AND 12' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 3
      msg = 'aliased update changes' ).

    lo_database->execute( 'UPDATE items SET note = ''first'', note = ''last'' WHERE id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'duplicate assignment changes' ).

    lo_database->execute( 'UPDATE items SET id = id + 1000 WHERE id BETWEEN 1 AND 20' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 20
      msg = 'rowid alias update changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'rowid update keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 1 AND 20' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'old rowid aliases removed' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 1001 AND 1020' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 20
      msg = 'new rowid aliases present' ).

    lo_database->execute( 'UPDATE items SET rowid = rowid + 2000 WHERE id BETWEEN 50 AND 60' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 11
      msg = 'rowid update changes' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 2050 AND 2060' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 11
      msg = 'rowid update moved rows' ).

    lo_database->execute( 'UPDATE items SET oid = oid + 3000 WHERE id BETWEEN 70 AND 75' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 6
      msg = 'oid update changes' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 3070 AND 3075' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6
      msg = 'oid update moved rows' ).

    lo_database->execute( 'UPDATE items SET rowid = rowid WHERE id BETWEEN 100 AND 109' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 10
      msg = 'same rowid update changes' ).
    lo_database->execute( 'UPDATE items SET amount = amount WHERE id = 999999' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 0
      msg = 'update without matches changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'no-match update keeps last_insert_rowid' ).

    lo_database->execute( 'UPDATE items SET amount = amount + 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 200
      msg = 'update all changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'update all keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 200
      msg = 'row count after updates' ).

    rs_result = lo_database->query( 'SELECT amount FROM items WHERE id = 1010' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    lv_expected = '21'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'aliased update amount' ).

    rs_result = lo_database->query(
      'SELECT id, amount, name, note FROM items WHERE id IN (1001, 1002, 1003) ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'moved row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = |row-1-{ lv_suffix }|
      msg = 'moved row keeps name' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'last'
      msg = 'duplicate assignment last wins' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    lv_expected = '2'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'moved row amount' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 2.
    lv_expected = '7'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'rowid update amount' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = |row-3-{ lv_suffix }-u|
      msg = 'rowid update name' ).

    TRY.
        lo_database->execute( 'UPDATE items SET name = NULL WHERE id = 1001' ).
        cl_abap_unit_assert=>fail( 'NOT NULL update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE items SET id = 1.5 WHERE id = 1001' ).
        cl_abap_unit_assert=>fail( 'non-integer rowid update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_mismatch ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE items SET id = id + 1 WHERE id BETWEEN 110 AND 115' ).
        cl_abap_unit_assert=>fail( 'rowid collision update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 110 AND 115' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6
      msg = 'collision rollback restored rows' ).

    TRY.
        lo_database->execute( 'UPDATE items SET missing = 1 WHERE id = 1' ).
        cl_abap_unit_assert=>fail( 'unknown update column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE missing SET amount = 1' ).
        cl_abap_unit_assert=>fail( 'update of unknown table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE items SET amount = 1 FROM payloads WHERE items.id = payloads.id' ).
        cl_abap_unit_assert=>fail( 'UPDATE ... FROM was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE payloads (id INTEGER PRIMARY KEY, label TEXT, body TEXT)' ).
    lv_text = repeat( val = 'A'
                      occ = 100 ).
    lv_values = |(1, 'small', '{ lv_text }')|.
    lv_text = repeat( val = 'B'
                      occ = 8000 ).
    lv_values = lv_values && |, (2, 'large', '{ lv_text }')|.
    lv_text = repeat( val = 'C'
                      occ = 12000 ).
    lv_values = lv_values && |, (3, 'huge', '{ lv_text }')|.
    lo_database->execute( |INSERT INTO payloads VALUES { lv_values }| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'payload insert rowid' ).

    lv_text = repeat( val = 'D'
                      occ = 12000 ).
    lo_database->execute( |UPDATE payloads SET body = '{ lv_text }' WHERE id = 1| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'overflow growth changes' ).
    lo_database->execute( 'UPDATE payloads SET body = ''tiny'' WHERE id = 2' ).
    lv_text = repeat( val = 'E'
                      occ = 6000 ).
    lo_database->execute( |UPDATE payloads SET body = '{ lv_text }' WHERE id = 3| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'overflow update keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT id, length(body), substr(body, 1, 1) FROM payloads ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'payload row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 12000
      msg = 'grown payload length' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'D'
      msg = 'grown payload content' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 4
      msg = 'shrunk payload length' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 't'
      msg = 'shrunk payload content' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6000
      msg = 'overflow shrink length' ).

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 200
      msg = 'updates survive reopen' ).
    lo_database->close( ).

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD create_index.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_table    TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_index_column TYPE zcl_sqlite_schema=>ty_index_column.
    DATA lt_indexes  TYPE zcl_sqlite_schema=>ty_indexes.
    DATA lt_values   TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_count    TYPE i.
    DATA lv_current  TYPE string.
    DATA lv_previous_name TYPE string.

    lv_name = 'test/m5_11_create_index.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, tag TEXT)' ).
    DO 600 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', 'tag-{ sy-index }')|.
    ENDDO.
    lo_database->execute( |INSERT INTO items (id, name, tag) VALUES { lv_values }| ).

    lo_database->execute( 'CREATE INDEX idx_name ON items (name)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_tag ON items (tag)' ).
    lo_database->execute( 'CREATE INDEX IF NOT EXISTS idx_name ON items (name)' ).

    TRY.
        lo_database->execute( 'CREATE INDEX idx_name ON items (tag)' ).
        cl_abap_unit_assert=>fail( 'duplicate index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'CREATE INDEX idx_missing ON items (missing)' ).
        cl_abap_unit_assert=>fail( 'index on missing column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'CREATE INDEX idx_desc ON items (name DESC)' ).
        cl_abap_unit_assert=>fail( 'descending index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'CREATE INDEX idx_nocase ON items (name COLLATE NOCASE)' ).
        cl_abap_unit_assert=>fail( 'NOCASE index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE duplicates (value TEXT)' ).
    lo_database->execute( 'INSERT INTO duplicates VALUES (''same''), (''same'')' ).
    TRY.
        lo_database->execute( 'CREATE UNIQUE INDEX idx_duplicate ON duplicates (value)' ).
        cl_abap_unit_assert=>fail( 'unique index over duplicate values was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE auto (a TEXT UNIQUE, b TEXT PRIMARY KEY)' ).
    lo_database->close( ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    ls_index = lo_schema->index( 'idx_name' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-tbl_name
      exp = 'items'
      msg = 'index table name' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-is_unique
      exp = abap_false
      msg = 'plain index is not unique' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_index-columns )
      exp = 1
      msg = 'index column count' ).
    READ TABLE ls_index-columns INTO ls_index_column INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_index_column-name
      exp = 'name'
      msg = 'index column name' ).

    ls_index = lo_schema->index( 'idx_tag' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-is_unique
      exp = abap_true
      msg = 'unique index flag' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-origin
      exp = 'c'
      msg = 'created index origin' ).

    ls_table = lo_schema->table( 'auto' ).
    lt_indexes = lo_schema->indexes_in_definition_order( 'auto' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_indexes )
      exp = 2
      msg = 'autoindex count' ).
    READ TABLE lt_indexes INTO ls_index INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-origin
      exp = 'u'
      msg = 'first autoindex origin' ).
    IF ls_index-rootpage <= 0.
      cl_abap_unit_assert=>fail( 'first autoindex root is missing' ).
    ENDIF.
    READ TABLE lt_indexes INTO ls_index INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-origin
      exp = 'pk'
      msg = 'second autoindex origin' ).
    IF ls_index-rootpage <= 0.
      cl_abap_unit_assert=>fail( 'second autoindex root is missing' ).
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = ls_table-name
      exp = 'auto'
      msg = 'autoindex table' ).

    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_name' )-rootpage ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->first( )
      exp = abap_true
      msg = 'index has entries' ).
    DO.
      lt_values = lo_cursor->values( ).
      lv_count = lv_count + 1.
      READ TABLE lt_values INTO lo_value INDEX 1.
      lv_current = lo_value->as_text( ).
      IF lv_count = 1.
        cl_abap_unit_assert=>assert_equals(
          act = lv_current
          exp = 'name-1'
          msg = 'first index value' ).
      ELSEIF lv_current < lv_previous_name.
        cl_abap_unit_assert=>fail( 'index values are not ascending' ).
      ENDIF.
      lv_previous_name = lv_current.
      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 600
      msg = 'index entry count' ).
    lo_file->close( ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE INDEX IF NOT EXISTS idx_name ON items (name)' ).
    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD index_maintenance.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA lt_values   TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_count    TYPE i.
    DATA lv_rowid    TYPE int8.
    DATA lv_found    TYPE abap_bool.

    lv_name = 'test/m5_11_maintenance.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, qty INTEGER)' ).
    DO 120 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', { sy-index })|.
    ENDDO.
    lo_database->execute( |INSERT INTO items VALUES { lv_values }| ).
    lo_database->execute( 'CREATE INDEX idx_name ON items (name)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_qty ON items (qty)' ).

    lo_database->execute( 'UPDATE items SET name = ''changed'', qty = 500 WHERE id = 50' ).
    lo_database->execute( 'DELETE FROM items WHERE id <= 20' ).

    TRY.
        lo_database->execute( 'INSERT INTO items (id, name, qty) VALUES (200, ''dupe'', 500)' ).
        cl_abap_unit_assert=>fail( 'duplicate unique index value was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lv_text = repeat( val = 'L'
                      occ = 9000 ).
    lo_database->execute( |INSERT INTO items (id, name, qty) VALUES (201, '{ lv_text }', 201)| ).

    lo_database->close( ).
    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).

    ls_index = lo_schema->index( 'idx_name' ).
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( ls_index-rootpage ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->first( )
      exp = abap_true
      msg = 'maintained index has entries' ).
    DO.
      lt_values = lo_cursor->values( ).
      lv_count = lv_count + 1.
      READ TABLE lt_values INTO lo_value INDEX 2.
      lv_rowid = lo_value->as_integer( ).
      READ TABLE lt_values INTO lo_value INDEX 1.
      CASE lv_rowid.
        WHEN 50.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_text( )
            exp = 'changed'
            msg = 'updated index value' ).
          lv_found = abap_true.
        WHEN 201.
          cl_abap_unit_assert=>assert_equals(
            act = strlen( lo_value->as_text( ) )
            exp = 9000
            msg = 'overflow index value' ).
          lv_found = abap_true.
      ENDCASE.
      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 101
      msg = 'maintained index entry count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'updated and overflow entries found' ).

    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_qty' )-rootpage ) ).
    lv_count = 0.
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 101
      msg = 'unique index entry count' ).
    lo_file->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD index_delete_all.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_check_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA lo_tcursor  TYPE REF TO zcl_sqlite_cursor.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_table    TYPE zcl_sqlite_schema=>ty_table.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_count    TYPE i.

    lv_name = 'test/m5_11_delete_all.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE delete_all_t (id INTEGER PRIMARY KEY, name TEXT, qty INTEGER)' ).
    DO 120 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', { sy-index })|.
    ENDDO.
    lo_database->execute( |INSERT INTO delete_all_t VALUES { lv_values }| ).
    lo_database->execute( 'CREATE INDEX idx_name ON delete_all_t (name)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_qty ON delete_all_t (qty)' ).
    lo_database->execute( 'UPDATE delete_all_t SET name = ''changed'', qty = 500 WHERE id = 50' ).
    lo_database->execute( 'DELETE FROM delete_all_t WHERE id <= 20' ).

    TRY.
        lo_database->execute( 'INSERT INTO delete_all_t VALUES (200, ''dupe'', 500)' ).
        cl_abap_unit_assert=>fail( 'duplicate unique index value was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lv_text = repeat( val = 'L'
                      occ = 9000 ).
    lo_database->execute( |INSERT INTO delete_all_t VALUES (201, '{ lv_text }', 201)| ).
    lo_database->close( ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_name' )-rootpage ) ).
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 101
      msg = 'maintained index entry count' ).
    lo_file->close( ).
    lv_count = 0.

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'DELETE FROM delete_all_t' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM delete_all_t' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'delete all leaves table empty' ).
    lo_database->close( ).

* the pre-delete index scan cached pages in lo_vfs, so inspect with a fresh VFS
    lo_check_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_check_vfs->open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    ls_table = lo_schema->table( 'delete_all_t' ).
    lo_tcursor = NEW zcl_sqlite_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( ls_table-rootpage ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_tcursor->first( )
      exp = abap_false
      msg = 'table stays empty after delete all' ).

    ls_index = lo_schema->index( 'idx_name' ).
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( ls_index-rootpage ) ).
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 0
      msg = 'name index stays empty after delete all' ).

    lv_count = 0.
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_qty' )-rootpage ) ).
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 0
      msg = 'qty index stays empty after delete all' ).
    lo_file->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD drop_table_and_index.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA ls_table    TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_pages    TYPE i.
    DATA lv_free     TYPE i.

    lv_name = 'test/m5_12_drop.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, body TEXT)' ).
    DO 600 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', 'body-{ sy-index }')|.
    ENDDO.
    lo_database->execute( |INSERT INTO items VALUES { lv_values }| ).
    lv_text = repeat( val = 'L'
                      occ = 9000 ).
    lo_database->execute( |INSERT INTO items VALUES (601, 'long', '{ lv_text }')| ).
    lo_database->execute( 'CREATE INDEX idx_body ON items (body)' ).
    lo_database->execute( 'CREATE INDEX idx_name ON items (name)' ).
    lo_database->close( ).

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lv_pages = lo_pager->page_count( ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_pager->freelist_count( )
      exp = 0
      msg = 'new database has no free pages' ).
    lo_file->close( ).

* dropping one index releases its pages but keeps the table and other indexes
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'DROP INDEX main.idx_body' ).
    lo_database->execute( 'DROP INDEX IF EXISTS idx_body' ).
    lo_database->execute( 'DROP INDEX IF EXISTS missing' ).
    lo_database->execute( 'DROP TABLE IF EXISTS missing' ).

    TRY.
        lo_database->execute( 'DROP INDEX missing' ).
        cl_abap_unit_assert=>fail( 'dropping a missing index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'DROP TABLE missing' ).
        cl_abap_unit_assert=>fail( 'dropping a missing table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'DROP INDEX sqlite_autoindex_items_1' ).
        cl_abap_unit_assert=>fail( 'dropping a constraint index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.
    lo_database->close( ).

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    ls_index = lo_schema->index( 'idx_body' ).
    IF ls_index-name IS NOT INITIAL.
      cl_abap_unit_assert=>fail( 'dropped index stays absent' ).
    ENDIF.
    ls_index = lo_schema->index( 'idx_name' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-name
      exp = 'idx_name'
      msg = 'remaining index survives' ).
    lv_free = lo_pager->freelist_count( ).
    IF lv_free <= 0.
      cl_abap_unit_assert=>fail( 'dropped index pages were not freed' ).
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lo_pager->page_count( )
      exp = lv_pages
      msg = 'dropping an index does not shrink the file' ).
    lo_file->close( ).

* dropping the table frees its pages, its overflow chains and its indexes
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'DROP TABLE main.items' ).
    lo_database->execute( 'DROP TABLE IF EXISTS items' ).
    lo_database->close( ).

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lo_schema->tables( ) )
      exp = 0
      msg = 'dropped table stays absent' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lo_schema->indexes( ) )
      exp = 0
      msg = 'table indexes are dropped with the table' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_pager->page_count( )
      exp = lv_pages
      msg = 'dropping a table does not shrink the file' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_pager->freelist_count( )
      exp = lv_pages - 1
      msg = 'all pages except sqlite_schema are free' ).
    lo_file->close( ).

* the freed pages can be allocated again
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE reuse (id INTEGER PRIMARY KEY, value TEXT)' ).
    lo_database->execute( 'INSERT INTO reuse VALUES (1, ''a''), (2, ''b''), (3, ''c'')' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM reuse' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'reused pages hold the new table' ).
    lo_database->close( ).

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    ls_table = lo_schema->table( 'reuse' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_table-name
      exp = 'reuse'
      msg = 'new table is in the catalog' ).
    lo_file->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD prepared_select.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_insert   TYPE REF TO zif_sqlite_statement.
    DATA lo_select   TYPE REF TO zif_sqlite_statement.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_found    TYPE abap_bool.
    DATA lv_sql      TYPE string.

    lv_name = 'test/m6_1_prepared_select.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lv_sql = 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT, qty INTEGER)'.
    lo_database->execute( lv_sql ).

    lv_sql = 'INSERT INTO items (id, name, qty) VALUES (?, ?, ?)'.
    lo_insert = lo_database->prepare( lv_sql ).
    lo_insert->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 1 ) ).
    lo_insert->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>text( 'one' ) ).
    lo_insert->bind(
      iv_index = 3
      io_value = zcl_sqlite_value=>integer( 10 ) ).
    lv_found = lo_insert->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'INSERT returns no result row' ).

    lo_insert->reset( ).
    lo_insert->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 2 ) ).
    lo_insert->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>text( 'two' ) ).
    lo_insert->bind(
      iv_index = 3
      io_value = zcl_sqlite_value=>integer( 20 ) ).
    lv_found = lo_insert->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'second INSERT returns no result row' ).

    lv_sql = 'SELECT id, name, qty FROM items WHERE qty >= ? ORDER BY id'.
    lo_select = lo_database->prepare( lv_sql ).
    lo_select->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 20 ) ).

    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'prepared SELECT has a row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_count( )
      exp = 3
      msg = 'prepared SELECT column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_name( 1 )
      exp = 'id'
      msg = 'first column name' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_name( 2 )
      exp = 'name'
      msg = 'second column name' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_type( 1 )
      exp = zcl_sqlite_value=>c_integer
      msg = 'first column type' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_type( 2 )
      exp = zcl_sqlite_value=>c_text
      msg = 'second column type' ).

    lo_value = lo_select->column_value( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'first row id' ).
    lo_value = lo_select->column_value( 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'two'
      msg = 'first row name' ).

    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'prepared SELECT reaches end' ).

    lo_select->reset( ).
    lo_select->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 30 ) ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'rebound prepared SELECT has no row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_count( )
      exp = 3
      msg = 'empty result keeps column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_name( 1 )
      exp = 'id'
      msg = 'empty result keeps column name' ).
    TRY.
        lv_found = boolc( lo_select->column_type( 1 ) >= 0 ).
        cl_abap_unit_assert=>fail( 'column type needs a current row' ).
      CATCH zcx_sqlite_error.
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD prepared_dml.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_update   TYPE REF TO zif_sqlite_statement.
    DATA lo_delete   TYPE REF TO zif_sqlite_statement.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.
    DATA lv_found    TYPE abap_bool.
    DATA lv_sql      TYPE string.

    lv_name = 'test/m6_1_prepared_dml.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lv_sql = 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT, qty INTEGER)'.
    lo_database->execute( lv_sql ).
    lo_database->execute( 'INSERT INTO items VALUES (1, ''one'', 10)' ).

    lv_sql = 'UPDATE items SET qty = qty + ? WHERE id = ?'.
    lo_update = lo_database->prepare( lv_sql ).
    lo_update->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 5 ) ).
    lo_update->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>integer( 1 ) ).
    lv_found = lo_update->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'prepared UPDATE returns no result row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'prepared UPDATE changes one row' ).

    lo_update->reset( ).
    lo_update->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 7 ) ).
    lo_update->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>integer( 1 ) ).
    lv_found = lo_update->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'rebound UPDATE returns no result row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'rebound UPDATE changes one row' ).

    lo_delete = lo_database->prepare( 'DELETE FROM items WHERE id = ?' ).
    lo_delete->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>integer( 1 ) ).
    lv_found = lo_delete->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_false
      msg = 'prepared DELETE returns no result row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'prepared DELETE changes one row' ).

    TRY.
        lo_delete->bind(
          iv_name  = 'missing'
          io_value = zcl_sqlite_value=>integer( 1 ) ).
        cl_abap_unit_assert=>fail( 'unknown parameter name must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_range
          msg = 'unknown parameter error code' ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD prepared_named.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_select   TYPE REF TO zif_sqlite_statement.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_found    TYPE abap_bool.
    DATA lv_sql      TYPE string.

    lv_name = 'test/m6_1_prepared_named.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lv_sql = 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)'.
    lo_database->execute( lv_sql ).
    lo_database->execute( 'INSERT INTO items VALUES (1, ''one''), (2, ''two'')' ).

    lv_sql = 'SELECT name FROM items WHERE id = :id'.
    lo_select = lo_database->prepare( lv_sql ).
    lo_select->bind(
      iv_name  = 'ID'
      io_value = zcl_sqlite_value=>integer( 2 ) ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'named parameter SELECT has a row' ).
    lo_value = lo_select->column_value( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'two'
      msg = 'named parameter value' ).

    lv_sql = 'SELECT :value AS a, :value + 1 AS b'.
    lo_select = lo_database->prepare( lv_sql ).
    lo_select->bind(
      iv_name  = 'value'
      io_value = zcl_sqlite_value=>integer( 5 ) ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'constant named parameter SELECT has a row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_count( )
      exp = 2
      msg = 'constant named parameter column count' ).
    lo_value = lo_select->column_value( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'constant named parameter first value' ).
    lo_value = lo_select->column_value( 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6
      msg = 'constant named parameter second value' ).

    lv_sql = 'SELECT ? AS v, ? AS w'.
    lo_select = lo_database->prepare( lv_sql ).
    lo_select->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>text( 'O''Reilly' ) ).
    lo_select->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>blob( 'DEADBEEF' ) ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'text and blob SELECT has a row' ).
    lo_value = lo_select->column_value( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'O''Reilly'
      msg = 'quoted text parameter' ).
    lo_value = lo_select->column_value( 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_blob( )
      exp = 'DEADBEEF'
      msg = 'blob parameter' ).

    lv_sql = 'SELECT ? AS v'.
    lo_select = lo_database->prepare( lv_sql ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'unbound parameter SELECT has a row' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_select->column_type( 1 )
      exp = zcl_sqlite_value=>c_null
      msg = 'unbound parameter is NULL' ).

    lv_sql = 'SELECT ?2 AS v, ?1 AS w'.
    lo_select = lo_database->prepare( lv_sql ).
    lo_select->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>text( 'first' ) ).
    lo_select->bind(
      iv_index = 2
      io_value = zcl_sqlite_value=>text( 'second' ) ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'explicit parameter indexes have a row' ).
    lo_value = lo_select->column_value( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'second'
      msg = 'first explicit parameter index' ).
    lo_value = lo_select->column_value( 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'first'
      msg = 'second explicit parameter index' ).

    lv_sql = 'SELECT ? AS v'.
    lo_select = lo_database->prepare( lv_sql ).
    lo_select->bind(
      iv_index = 1
      io_value = zcl_sqlite_value=>real( '1.5' ) ).
    lv_found = lo_select->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'real parameter SELECT has a row' ).
    lo_value = lo_select->column_value( 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = '1.5'
      msg = 'real parameter value' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD database_api.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_memory.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.

    lo_vfs = NEW zcl_sqlite_vfs_memory( ).

    TRY.
        lo_database = zcl_sqlite_database=>open(
          iv_name   = 'missing.db'
          io_vfs    = lo_vfs
          iv_create = abap_false ).
        cl_abap_unit_assert=>fail( 'missing database must not open without create' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_cantopen
          msg = 'missing database error code' ).
    ENDTRY.

    lo_database = zcl_sqlite_database=>open(
      iv_name = 'api.db'
      io_vfs  = lo_vfs ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)' ).
    lo_database->execute( 'INSERT INTO t VALUES (1, ''one'')' ).
    lo_database->close( ).
    lo_database->close( ).

    lo_database = zcl_sqlite_database=>open(
      iv_name   = 'api.db'
      io_vfs    = lo_vfs
      iv_create = abap_false ).
    rs_result = lo_database->query( 'SELECT v FROM t WHERE id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'reopened database keeps rows' ).
    lo_database->close( ).

    TRY.
        lo_database->query( 'SELECT 1' ).
        cl_abap_unit_assert=>fail( 'query on a closed database must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_misuse
          msg = 'closed database query error code' ).
    ENDTRY.

    TRY.
        lo_database->begin( ).
        cl_abap_unit_assert=>fail( 'begin on a closed database must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_misuse
          msg = 'closed database transaction error code' ).
    ENDTRY.
  ENDMETHOD.

  METHOD exec_script.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_name     TYPE string.

    lv_name = 'test/m6_2_exec.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->exec(
      'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);' &&
      '/* a semicolon ; in a comment */' &&
      'INSERT INTO t VALUES (1, ''one'');' &&
      'INSERT INTO t VALUES (2, ''two'');' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 2
      msg = 'exec runs all statements' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'exec keeps the last statement changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 2
      msg = 'exec keeps the last inserted rowid' ).

* result rows are discarded, and empty statements are ignored
    lo_database->exec( 'SELECT id FROM t ORDER BY id;' ).
    lo_database->exec( ' ; ; ' ).

* transaction control inside a script
    lo_database->exec( 'BEGIN; INSERT INTO t VALUES (3, ''three''); END;' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 3
      msg = 'exec transaction is committed' ).

* a trailing statement without a semicolon still runs
    lo_database->exec( 'INSERT INTO t VALUES (4, ''four'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 4
      msg = 'exec runs a trailing statement' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 4
      msg = 'exec trailing statement rowid' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD database_error_codes.
    DATA lo_vfs       TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database  TYPE REF TO zcl_sqlite_database.
    DATA lo_statement TYPE REF TO zif_sqlite_statement.
    DATA lo_error     TYPE REF TO zcx_sqlite_error.
    DATA lv_name      TYPE string.

    lv_name = 'test/m6_2_errors.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT NOT NULL)' ).

    TRY.
        lo_database->execute( 'INSERT INTO t (id) VALUES (1)' ).
        cl_abap_unit_assert=>fail( 'NOT NULL violation must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'NOT NULL error code' ).
    ENDTRY.

    lo_database->execute( 'INSERT INTO t VALUES (1, ''one'')' ).
    TRY.
        lo_database->execute( 'UPDATE t SET id = ''not an integer'' WHERE id = 1' ).
        cl_abap_unit_assert=>fail( 'rowid datatype mismatch must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_mismatch
          msg = 'datatype mismatch error code' ).
    ENDTRY.

    TRY.
        lo_database->query( 'SELECT id FROM missing' ).
        cl_abap_unit_assert=>fail( 'missing table must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'missing table error code' ).
    ENDTRY.

    lo_statement = lo_database->prepare( 'SELECT 1' ).
    TRY.
        lo_statement->bind(
          iv_index = 2
          io_value = zcl_sqlite_value=>null( ) ).
        cl_abap_unit_assert=>fail( 'parameter index out of range must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_range
          msg = 'parameter range error code' ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD abap_conveniences.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA ls_row      TYPE ty_abap_row.
    DATA lt_rows     TYPE ty_abap_rows.
    DATA lt_result   TYPE ty_abap_rows.
    DATA lv_name     TYPE string.
    DATA lv_amount   TYPE p LENGTH 8 DECIMALS 2.
    DATA lv_ratio    TYPE f.
    DATA lv_date     TYPE d.
    DATA lv_time     TYPE t.
    DATA lv_blob     TYPE xstring.
    DATA lv_fixed    TYPE x LENGTH 4.

    lv_name = 'test/m6_3_abap_types.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute(
      'CREATE TABLE abap_types (name TEXT, id INTEGER PRIMARY KEY,' &&
      ' big INTEGER, small INTEGER, medium INTEGER,' &&
      ' code TEXT, num TEXT, amount REAL, ratio REAL,' &&
      ' created TEXT, at TEXT, payload BLOB, fixed BLOB)' ).

    ls_row-id = 1.
    ls_row-big = '1234567890123'.
    ls_row-small = 42.
    ls_row-medium = 1234.
    ls_row-name = 'hello'.
    ls_row-code = 'ABAP'.
    ls_row-num = '00042'.
    ls_row-amount = '1234.56'.
    ls_row-ratio = '1.25'.
    ls_row-created = '20240131'.
    ls_row-at = '235959'.
    ls_row-payload = '00AB'.
    ls_row-fixed = '0A0B0C0D'.
    APPEND ls_row TO lt_rows.

    ls_row-id = 2.
    ls_row-big = '-1234567890123'.
    ls_row-small = 255.
    ls_row-medium = -1234.
    ls_row-name = 'world'.
    ls_row-code = 'SQL'.
    ls_row-num = '00007'.
    ls_row-amount = '-12.30'.
    ls_row-ratio = '-0.5'.
    ls_row-created = '19991231'.
    ls_row-at = '000001'.
    ls_row-payload = 'FF'.
    ls_row-fixed = 'FFFFFFFF'.
    APPEND ls_row TO lt_rows.

    lo_database->insert_table(
      iv_table_name = 'abap_types'
      it_data       = lt_rows ).

    lo_database->select_into(
      EXPORTING
        iv_sql   = 'SELECT id, big, small, medium, name, code, num,' &&
                   ' amount, ratio, created, at, payload, fixed' &&
                   ' FROM abap_types ORDER BY id'
      CHANGING
        ct_table = lt_result ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_result )
      exp = 2
      msg = 'select_into row count' ).

    READ TABLE lt_result INTO ls_row INDEX 1.
    lv_amount = '1234.56'.
    lv_ratio = '1.25'.
    lv_date = '20240131'.
    lv_time = '235959'.
    lv_blob = '00AB'.
    lv_fixed = '0A0B0C0D'.
    cl_abap_unit_assert=>assert_true( boolc( ls_row-id = 1 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-big = '1234567890123' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-small = 42 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-medium = 1234 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-name = 'hello' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-code = 'ABAP' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-num = '00042' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-amount = lv_amount ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-ratio = lv_ratio ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-created = lv_date ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-at = lv_time ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-payload = lv_blob ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-fixed = lv_fixed ) ).

    READ TABLE lt_result INTO ls_row INDEX 2.
    lv_amount = '-12.30'.
    lv_ratio = '-0.5'.
    lv_date = '19991231'.
    lv_time = '000001'.
    lv_blob = 'FF'.
    lv_fixed = 'FFFFFFFF'.
    cl_abap_unit_assert=>assert_true( boolc( ls_row-id = 2 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-big = '-1234567890123' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-small = 255 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-medium = -1234 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-name = 'world' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-code = 'SQL' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-num = '00007' ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-amount = lv_amount ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-ratio = lv_ratio ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-created = lv_date ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-at = lv_time ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-payload = lv_blob ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-fixed = lv_fixed ) ).

    lo_database->execute( 'INSERT INTO abap_types (id, name) VALUES (3, NULL)' ).
    lo_database->select_into(
      EXPORTING
        iv_sql   = 'SELECT id, name, amount, payload FROM abap_types WHERE id = 3'
      CHANGING
        ct_table = lt_result ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_result )
      exp = 1
      msg = 'select_into clears the result table' ).
    READ TABLE lt_result INTO ls_row INDEX 1.
    cl_abap_unit_assert=>assert_true( boolc( ls_row-id = 3 ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-name IS INITIAL ) ).
    cl_abap_unit_assert=>assert_true( boolc( ls_row-amount = 0 ) ).
    cl_abap_unit_assert=>assert_true( boolc( xstrlen( ls_row-payload ) = 0 ) ).

    CLEAR lt_rows.
    lo_database->insert_table(
      iv_table_name = 'abap_types'
      it_data       = lt_rows ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM abap_types' )
      exp = 3
      msg = 'insert_table ignores an empty table' ).

    CLEAR ls_row.
    ls_row-id = 4.
    ls_row-name = 'rolled back'.
    APPEND ls_row TO lt_rows.
    lo_database->begin( ).
    lo_database->insert_table(
      iv_table_name = 'abap_types'
      it_data       = lt_rows ).
    lo_database->rollback( ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM abap_types' )
      exp = 3
      msg = 'insert_table uses the caller transaction' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD count_rows.
    rv_count = lines( io_database->query( iv_sql )-rows ).
  ENDMETHOD.

  METHOD transactions.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.

    lv_name = 'test/m5_13_transactions.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)' ).
    lo_database->execute( 'INSERT INTO t VALUES (1, ''one'')' ).

* an explicit transaction is invisible until it commits
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (2, ''two'')' ).
    lo_database->execute( 'INSERT INTO t VALUES (3, ''three'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id >= 2' )
      exp = 2
      msg = 'rows are visible inside the transaction' ).

    TRY.
        lo_database->begin( ).
        cl_abap_unit_assert=>fail( 'nested BEGIN must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'nested BEGIN error code' ).
    ENDTRY.

    lo_database->rollback( ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id >= 2' )
      exp = 0
      msg = 'ROLLBACK discards the transaction' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 1' )
      exp = 1
      msg = 'rows from before the transaction survive' ).

* COMMIT makes the transaction durable in the SQLite file
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (4, ''four'')' ).
    lo_database->commit( ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 4' )
      exp = 1
      msg = 'COMMIT keeps the transaction' ).

    TRY.
        lo_database->commit( ).
        cl_abap_unit_assert=>fail( 'COMMIT without a transaction must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'COMMIT error code' ).
    ENDTRY.
    TRY.
        lo_database->rollback( ).
        cl_abap_unit_assert=>fail( 'ROLLBACK without a transaction must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'ROLLBACK error code' ).
    ENDTRY.

* a failed statement rolls back only itself, not the whole transaction
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (10, ''ten'')' ).
    TRY.
        lo_database->execute( 'INSERT INTO t VALUES (10, ''duplicate'')' ).
        cl_abap_unit_assert=>fail( 'duplicate primary key must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'duplicate key error code' ).
    ENDTRY.
    lo_database->execute( 'INSERT INTO t VALUES (11, ''eleven'')' ).
    lo_database->commit( ).

    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 10' )
      exp = 1
      msg = 'statement before the failure survives' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 11' )
      exp = 1
      msg = 'statement after the failure survives' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE v = ''duplicate''' )
      exp = 0
      msg = 'failed statement leaves no row behind' ).

* a committed transaction survives the next statement
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (12, ''twelve'')' ).
    lo_database->commit( ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 12' )
      exp = 1
      msg = 'END commits' ).

* DDL inside a transaction is rolled back with it
    lo_database->begin( ).
    lo_database->execute( 'CREATE TABLE temp (id INTEGER)' ).
    lo_database->execute( 'INSERT INTO temp VALUES (1)' ).
    lo_database->rollback( ).
    TRY.
        lo_database->query( 'SELECT id FROM temp' ).
        cl_abap_unit_assert=>fail( 'rolled back table must not exist' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'rolled back table error code' ).
    ENDTRY.

    lo_database->begin( ).
    TRY.
        lo_database->exec( 'ROLLBACK TO SAVEPOINT s' ).
        cl_abap_unit_assert=>fail( 'savepoints must be rejected' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'savepoint error code' ).
    ENDTRY.
    lo_database->rollback( ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD abap_luw.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_name     TYPE string.

    lv_name = 'test/m5_13_luw.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
    COMMIT WORK.

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY)' ).
    lo_database->close( ).
    COMMIT WORK.

* by default a SQLite COMMIT only writes the bytes, it does not end the ABAP
* LUW. A later ROLLBACK WORK must undo the write.
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (1)' ).
    lo_database->commit( ).
    lo_database->close( ).
    ROLLBACK WORK.

    lo_database = zcl_sqlite_database=>open( lv_name ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 0
      msg = 'caller-owned LUW is rolled back' ).
    lo_database->close( ).

* auto_commit_work turns the SQLite commit into an ABAP LUW commit
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->set_auto_commit_work( abap_true ).
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (2)' ).
    lo_database->commit( ).
    lo_database->close( ).
    ROLLBACK WORK.

    lo_database = zcl_sqlite_database=>open( lv_name ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2' )
      exp = 1
      msg = 'auto_commit_work survives ROLLBACK WORK' ).
    lo_database->close( ).

* autocommit statements also use auto_commit_work
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->set_auto_commit_work( abap_true ).
    lo_database->execute( 'INSERT INTO t VALUES (3)' ).
    lo_database->close( ).
    ROLLBACK WORK.

    lo_database = zcl_sqlite_database=>open( lv_name ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 2
      msg = 'autocommit statement is durable' ).
    lo_database->close( ).

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
