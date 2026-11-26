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
    METHODS column_constraints FOR TESTING RAISING zcx_sqlite_error.
    METHODS unique_keys FOR TESTING RAISING zcx_sqlite_error.
    METHODS conflict_actions FOR TESTING RAISING zcx_sqlite_error.
    METHODS upsert_actions FOR TESTING RAISING zcx_sqlite_error.
    METHODS dml_returning FOR TESTING RAISING zcx_sqlite_error.
    METHODS autoincrement FOR TESTING RAISING zcx_sqlite_error.
    METHODS without_rowid_writes FOR TESTING RAISING zcx_sqlite_error.
    METHODS views FOR TESTING RAISING zcx_sqlite_error.
    METHODS compound_selects FOR TESTING RAISING zcx_sqlite_error.
    METHODS ctes FOR TESTING RAISING zcx_sqlite_error.

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

  METHOD column_constraints.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lv_name = 'test/m7_1_column_constraints.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute(
      'CREATE TABLE t (id INTEGER PRIMARY KEY,' &&
      ' code TEXT COLLATE NOCASE,' &&
      ' qty INTEGER CHECK (qty > 0),' &&
      ' amount INTEGER DEFAULT (1 + 2),' &&
      ' name TEXT DEFAULT (lower(''ABC'')),' &&
      ' CONSTRAINT amount_ok CHECK (amount >= 0))' ).

    lo_database->execute( 'INSERT INTO t (id, code, qty) VALUES (1, ''alpha'', 1)' ).
    lo_database->execute( 'INSERT INTO t (id, code, qty) VALUES (2, ''Beta'', 2)' ).
    lo_database->execute( 'INSERT INTO t (id, code, qty) VALUES (3, ''ALPHA'', 3)' ).

    rs_result = lo_database->query( 'SELECT amount, name FROM t WHERE id = 1' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'default expression (1 + 2)' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'abc'
      msg = 'default function lower(''ABC'')' ).

    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE code = ''ALPHA''' )
      exp = 2
      msg = 'column collation applies to comparisons' ).

    rs_result = lo_database->query( 'SELECT id FROM t ORDER BY code, id' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'column collation applies to ordering' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'column collation ordering tie' ).

    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT DISTINCT code FROM t' )
      exp = 2
      msg = 'column collation applies to distinct' ).

    rs_result = lo_database->query( 'SELECT code, count(*) AS n FROM t GROUP BY code ORDER BY code' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'column collation applies to grouping' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'case variants grouped together' ).

    TRY.
        lo_database->execute( 'INSERT INTO t (id, code, qty) VALUES (4, ''gamma'', 0)' ).
        cl_abap_unit_assert=>fail( 'column CHECK must be enforced on insert' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'column CHECK error code' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'CHECK constraint failed: qty > 0'
          msg = 'column CHECK error message' ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE t SET qty = 0 WHERE id = 1' ).
        cl_abap_unit_assert=>fail( 'column CHECK must be enforced on update' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'column CHECK update error code' ).
    ENDTRY.

    TRY.
        lo_database->execute( 'INSERT INTO t (id, code, qty, amount) VALUES (4, ''gamma'', 1, -1)' ).
        cl_abap_unit_assert=>fail( 'table CHECK must be enforced' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'CHECK constraint failed: amount_ok'
          msg = 'table CHECK error message' ).
    ENDTRY.

    lo_database->execute( 'INSERT INTO t (id, code) VALUES (4, ''delta'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 4' )
      exp = 1
      msg = 'NULL passes a CHECK constraint' ).

    lo_database->execute( 'CREATE TABLE named (v INTEGER CONSTRAINT positive CHECK (v > 0))' ).
    TRY.
        lo_database->execute( 'INSERT INTO named VALUES (0)' ).
        cl_abap_unit_assert=>fail( 'named column CHECK must be enforced' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'CHECK constraint failed: positive'
          msg = 'named column CHECK uses the constraint name' ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE stamp (created TEXT DEFAULT CURRENT_TIMESTAMP)' ).
    lo_database->execute( 'INSERT INTO stamp DEFAULT VALUES' ).
    rs_result = lo_database->query( 'SELECT typeof(created), length(created) FROM stamp' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'text'
      msg = 'CURRENT_TIMESTAMP default type' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 19
      msg = 'CURRENT_TIMESTAMP default format' ).

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE code = ''ALPHA''' )
      exp = 2
      msg = 'column collation survives reopen' ).

    TRY.
        lo_database->execute( 'INSERT INTO t (id, code, qty) VALUES (5, ''zeta'', 0)' ).
        cl_abap_unit_assert=>fail( 'reopened column CHECK must be enforced' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'CHECK constraint failed: qty > 0'
          msg = 'reopened column CHECK message' ).
    ENDTRY.

    lo_database->execute( 'INSERT INTO t (id, code) VALUES (5, ''zeta'')' ).
    rs_result = lo_database->query( 'SELECT amount, name FROM t WHERE id = 5' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'default expression survives reopen' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'abc'
      msg = 'default function survives reopen' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD unique_keys.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.

    lv_name = 'test/m7_2_unique_keys.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).

* a column UNIQUE constraint uses an autoindex
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE)' ).
    lo_database->execute( 'INSERT INTO t (id, code) VALUES (1, ''alpha'')' ).
    lo_database->execute( 'INSERT INTO t (id, code) VALUES (2, ''beta'')' ).

    TRY.
        lo_database->execute( 'INSERT INTO t (id, code) VALUES (3, ''alpha'')' ).
        cl_abap_unit_assert=>fail( 'duplicate UNIQUE value was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'duplicate UNIQUE error code' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.code'
          msg = 'duplicate UNIQUE error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 2
      msg = 'failed UNIQUE insert leaves no row behind' ).

* an INTEGER PRIMARY KEY is a rowid alias and reports a UNIQUE failure
    TRY.
        lo_database->execute( 'INSERT INTO t (id, code) VALUES (1, ''delta'')' ).
        cl_abap_unit_assert=>fail( 'duplicate primary key was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'duplicate primary key error code' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.id'
          msg = 'duplicate primary key error message' ).
    ENDTRY.

* NULLs are distinct for UNIQUE constraints
    lo_database->execute( 'CREATE TABLE nullable (id INTEGER PRIMARY KEY, value TEXT UNIQUE)' ).
    lo_database->execute( 'INSERT INTO nullable (id, value) VALUES (1, NULL)' ).
    lo_database->execute( 'INSERT INTO nullable (id, value) VALUES (2, NULL)' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM nullable' )
      exp = 2
      msg = 'multiple NULL values satisfy UNIQUE' ).

* composite table-level UNIQUE constraint
    lo_database->execute(
      'CREATE TABLE composite (id INTEGER PRIMARY KEY, a TEXT, b TEXT,' &&
      ' UNIQUE (a, b))' ).
    lo_database->execute( 'INSERT INTO composite VALUES (1, ''x'', ''y'')' ).
    lo_database->execute( 'INSERT INTO composite VALUES (2, ''x'', ''z'')' ).
    lo_database->execute( 'INSERT INTO composite VALUES (3, ''y'', ''y'')' ).

    TRY.
        lo_database->execute( 'INSERT INTO composite VALUES (4, ''x'', ''y'')' ).
        cl_abap_unit_assert=>fail( 'duplicate composite UNIQUE was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: composite.a, composite.b'
          msg = 'composite UNIQUE error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM composite' )
      exp = 3
      msg = 'failed composite UNIQUE insert leaves no row behind' ).

* a NULL in a composite UNIQUE key makes the rows distinct
    lo_database->execute( 'INSERT INTO composite VALUES (5, NULL, ''z'')' ).
    lo_database->execute( 'INSERT INTO composite VALUES (6, NULL, ''z'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM composite' )
      exp = 5
      msg = 'NULL composite UNIQUE values are distinct' ).

* composite PRIMARY KEY constraint
    lo_database->execute( 'CREATE TABLE cpk (a TEXT, b INTEGER, value TEXT, PRIMARY KEY (a, b))' ).
    lo_database->execute( 'INSERT INTO cpk VALUES (''x'', 1, ''one'')' ).
    lo_database->execute( 'INSERT INTO cpk VALUES (''x'', 2, ''two'')' ).
    lo_database->execute( 'INSERT INTO cpk VALUES (NULL, 1, ''null one'')' ).
    lo_database->execute( 'INSERT INTO cpk VALUES (NULL, 1, ''null two'')' ).

    TRY.
        lo_database->execute( 'INSERT INTO cpk VALUES (''x'', 1, ''again'')' ).
        cl_abap_unit_assert=>fail( 'duplicate composite primary key was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: cpk.a, cpk.b'
          msg = 'composite primary key error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT b FROM cpk' )
      exp = 4
      msg = 'composite primary key row count' ).

* a column collation participates in UNIQUE comparisons
    lo_database->execute( 'CREATE TABLE nocase (id INTEGER PRIMARY KEY, code TEXT COLLATE NOCASE UNIQUE)' ).
    lo_database->execute( 'INSERT INTO nocase VALUES (1, ''Alpha'')' ).
    lo_database->execute( 'INSERT INTO nocase VALUES (2, NULL)' ).
    lo_database->execute( 'INSERT INTO nocase VALUES (3, NULL)' ).

    TRY.
        lo_database->execute( 'INSERT INTO nocase VALUES (4, ''alpha'')' ).
        cl_abap_unit_assert=>fail( 'NOCASE duplicate was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: nocase.code'
          msg = 'NOCASE UNIQUE error message' ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE nocase SET code = ''ALPHA'' WHERE id = 2' ).
        cl_abap_unit_assert=>fail( 'NOCASE update duplicate was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: nocase.code'
          msg = 'NOCASE UNIQUE update error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM nocase WHERE code IS NULL' )
      exp = 2
      msg = 'failed UNIQUE update leaves the old values' ).

* manual unique indexes use the same error text
    lo_database->execute( 'CREATE TABLE manual (id INTEGER PRIMARY KEY, tag TEXT)' ).
    lo_database->execute( 'INSERT INTO manual VALUES (1, ''a'')' ).
    lo_database->execute( 'CREATE UNIQUE INDEX manual_tag ON manual (tag)' ).
    TRY.
        lo_database->execute( 'INSERT INTO manual VALUES (2, ''a'')' ).
        cl_abap_unit_assert=>fail( 'duplicate unique index value was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: manual.tag'
          msg = 'unique index error message' ).
    ENDTRY.

* constraints survive close and reopen
    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    TRY.
        lo_database->execute( 'INSERT INTO t (id, code) VALUES (4, ''beta'')' ).
        cl_abap_unit_assert=>fail( 'reopened UNIQUE constraint was not enforced' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.code'
          msg = 'reopened UNIQUE error message' ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD conflict_actions.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.

    lv_name = 'test/m7_3_conflict_actions.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, k TEXT UNIQUE, v INTEGER)' ).
    lo_database->execute( 'INSERT INTO t VALUES (1, ''a'', 10)' ).

* INSERT OR IGNORE keeps the existing row
    lo_database->execute( 'INSERT OR IGNORE INTO t VALUES (1, ''b'', 20)' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 1
      msg = 'INSERT OR IGNORE row count' ).
    rs_result = lo_database->query( 'SELECT k, v FROM t WHERE id = 1' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'a'
      msg = 'INSERT OR IGNORE keeps the old value' ).

* INSERT OR REPLACE overwrites the conflicting row
    lo_database->execute( 'INSERT OR REPLACE INTO t VALUES (1, ''b'', 20)' ).
    rs_result = lo_database->query( 'SELECT k, v FROM t WHERE id = 1' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 20
      msg = 'INSERT OR REPLACE overwrites the row' ).

* REPLACE resolves a secondary unique conflict by deleting the old row
    lo_database->execute( 'INSERT OR REPLACE INTO t VALUES (2, ''b'', 30)' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 1
      msg = 'INSERT OR REPLACE deletes the conflicting row' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2 AND k = ''b''' )
      exp = 1
      msg = 'INSERT OR REPLACE inserts the new row' ).

* FAIL keeps the rows inserted earlier in the same statement
    TRY.
        lo_database->execute( 'INSERT OR FAIL INTO t VALUES (3, ''c'', 40), (2, ''d'', 50)' ).
        cl_abap_unit_assert=>fail( 'INSERT OR FAIL must report the conflict' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.id'
          msg = 'INSERT OR FAIL error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 3 AND k = ''c''' )
      exp = 1
      msg = 'INSERT OR FAIL keeps earlier rows' ).

* ABORT discards all rows of the failed statement
    TRY.
        lo_database->execute( 'INSERT INTO t VALUES (4, ''e'', 60), (2, ''f'', 70)' ).
        cl_abap_unit_assert=>fail( 'INSERT ABORT must report the conflict' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.id'
          msg = 'INSERT ABORT error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 4' )
      exp = 0
      msg = 'INSERT ABORT leaves no partial rows' ).

* ROLLBACK ends the transaction and discards its earlier work
    lo_database->begin( ).
    lo_database->execute( 'INSERT INTO t VALUES (5, ''g'', 80)' ).
    TRY.
        lo_database->execute( 'INSERT OR ROLLBACK INTO t VALUES (2, ''h'', 90)' ).
        cl_abap_unit_assert=>fail( 'INSERT OR ROLLBACK must report the conflict' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.id'
          msg = 'INSERT OR ROLLBACK error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 5' )
      exp = 0
      msg = 'INSERT OR ROLLBACK discards the transaction' ).
    lo_database->begin( ).
    lo_database->rollback( ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD upsert_actions.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.

    lv_name = 'test/m7_3_upsert_actions.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, k TEXT UNIQUE, v INTEGER)' ).
    lo_database->execute( 'INSERT INTO t VALUES (1, ''a'', 10)' ).
    lo_database->execute( 'INSERT INTO t VALUES (2, ''b'', 20)' ).

* DO NOTHING leaves the conflicting row untouched
    lo_database->execute( 'INSERT INTO t VALUES (9, ''b'', 99) ON CONFLICT (k) DO NOTHING' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2 AND v = 20' )
      exp = 1
      msg = 'DO NOTHING keeps the existing row' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t' )
      exp = 2
      msg = 'DO NOTHING does not insert a row' ).

* DO UPDATE can read the existing row and excluded values
    lo_database->execute( 'INSERT INTO t VALUES (9, ''b'', 5) ON CONFLICT (k) DO UPDATE SET v = v + excluded.v' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2 AND v = 25' )
      exp = 1
      msg = 'DO UPDATE uses existing and excluded values' ).

* a false DO UPDATE WHERE skips the update
    lo_database->execute(
      'INSERT INTO t VALUES (9, ''b'', 5) ON CONFLICT (k) DO UPDATE SET v = 0 WHERE v > 1000' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2 AND v = 25' )
      exp = 1
      msg = 'false DO UPDATE WHERE skips the update' ).

* a target WHERE restricts the matching conflict target
    lo_database->execute(
      'INSERT INTO t VALUES (9, ''b'', 5) ON CONFLICT (k) WHERE v = 25 DO UPDATE SET v = 30' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2 AND v = 30' )
      exp = 1
      msg = 'ON CONFLICT target WHERE matches' ).

    TRY.
        lo_database->execute(
          'INSERT INTO t VALUES (9, ''b'', 5) ON CONFLICT (k) WHERE v = 999 DO UPDATE SET v = 40' ).
        cl_abap_unit_assert=>fail( 'unmatched upsert target must report the conflict' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: t.k'
          msg = 'unmatched upsert target error message' ).
    ENDTRY.

* no conflict means a normal insert
    lo_database->execute( 'INSERT INTO t VALUES (3, ''c'', 40) ON CONFLICT (k) DO UPDATE SET v = 0' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 3 AND v = 40' )
      exp = 1
      msg = 'upsert inserts when there is no conflict' ).

* UPDATE OR IGNORE and UPDATE OR REPLACE
    lo_database->execute( 'CREATE TABLE u (id INTEGER PRIMARY KEY, k TEXT UNIQUE)' ).
    lo_database->execute( 'INSERT INTO u VALUES (1, ''a''), (2, ''b'')' ).
    lo_database->execute( 'UPDATE OR IGNORE u SET k = ''b'' WHERE id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM u WHERE id = 1 AND k = ''a''' )
      exp = 1
      msg = 'UPDATE OR IGNORE keeps the old value' ).

    lo_database->execute( 'UPDATE OR REPLACE u SET k = ''b'' WHERE id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM u WHERE id = 1 AND k = ''b''' )
      exp = 1
      msg = 'UPDATE OR REPLACE keeps the updated row' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM u' )
      exp = 1
      msg = 'UPDATE OR REPLACE removes the conflicting row' ).

* UPDATE OR FAIL keeps changes made earlier in the statement
    lo_database->execute( 'CREATE TABLE f (id INTEGER PRIMARY KEY, k TEXT UNIQUE)' ).
    lo_database->execute( 'INSERT INTO f VALUES (1, ''x''), (2, ''y''), (3, ''z'')' ).
    TRY.
        lo_database->execute( 'UPDATE OR FAIL f SET k = CASE id WHEN 2 THEN ''q'' WHEN 3 THEN ''x'' ELSE k END' ).
        cl_abap_unit_assert=>fail( 'UPDATE OR FAIL must report the conflict' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: f.k'
          msg = 'UPDATE OR FAIL error message' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM f WHERE id = 2 AND k = ''q''' )
      exp = 1
      msg = 'UPDATE OR FAIL keeps earlier changes' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD dml_returning.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_name     TYPE string.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.

    lv_name = 'test/m7_3_returning.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE t (id INTEGER PRIMARY KEY, k TEXT, v INTEGER)' ).

    rs_result = lo_database->query( 'INSERT INTO t VALUES (1, ''a'', 10) RETURNING id, v' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 2
      msg = 'INSERT RETURNING column count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 10
      msg = 'INSERT RETURNING value' ).

    rs_result = lo_database->query( 'UPDATE t SET v = v + 5 WHERE id = 1 RETURNING v' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 15
      msg = 'UPDATE RETURNING value' ).

    rs_result = lo_database->query(
      'INSERT INTO t VALUES (1, ''b'', 99) ON CONFLICT (id) DO UPDATE SET k = excluded.k, v = 99 RETURNING v' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 99
      msg = 'upsert RETURNING value' ).

    rs_result = lo_database->query( 'INSERT OR IGNORE INTO t VALUES (1, ''c'', 100) RETURNING v' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 0
      msg = 'ignored INSERT RETURNING row count' ).

    rs_result = lo_database->query( 'DELETE FROM t WHERE id = 1 RETURNING id, k' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'DELETE RETURNING row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'b'
      msg = 'DELETE RETURNING value' ).

    lo_database->execute( 'INSERT INTO t VALUES (2, ''d'', 20) RETURNING id' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM t WHERE id = 2' )
      exp = 1
      msg = 'execute accepts RETURNING' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD autoincrement.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_name     TYPE string.

    lv_name = 'test/m7_4_autoincrement.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE auto (id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT UNIQUE)' ).

    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT name FROM sqlite_sequence' )
      exp = 0
      msg = 'sqlite_sequence starts empty' ).

    lo_database->execute( 'INSERT INTO auto (v) VALUES (''a'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM auto WHERE id = 1' )
      exp = 1
      msg = 'AUTOINCREMENT starts at one' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT seq FROM sqlite_sequence WHERE name = ''auto'' AND seq = 1' )
      exp = 1
      msg = 'sqlite_sequence records the first insert' ).

    lo_database->execute( 'INSERT INTO auto (id, v) VALUES (10, ''b'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT seq FROM sqlite_sequence WHERE name = ''auto'' AND seq = 10' )
      exp = 1
      msg = 'explicit rowid advances sqlite_sequence' ).

    lo_database->execute( 'DELETE FROM auto' ).
    lo_database->execute( 'INSERT INTO auto (v) VALUES (''c'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM auto WHERE id = 11' )
      exp = 1
      msg = 'deleted AUTOINCREMENT rowids are not reused' ).

    lo_database->execute( 'INSERT OR IGNORE INTO auto (id, v) VALUES (50, ''c'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT seq FROM sqlite_sequence WHERE name = ''auto'' AND seq = 50' )
      exp = 1
      msg = 'ignored row still advances sqlite_sequence' ).
    lo_database->execute( 'INSERT INTO auto (v) VALUES (''d'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM auto WHERE id = 51' )
      exp = 1
      msg = 'insert after ignored row uses the sequence' ).

    lo_database->execute( 'INSERT INTO auto (v) VALUES (''d'') ON CONFLICT (v) DO NOTHING' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT seq FROM sqlite_sequence WHERE name = ''auto'' AND seq = 52' )
      exp = 1
      msg = 'DO NOTHING advances sqlite_sequence' ).
    lo_database->execute( 'INSERT INTO auto (v) VALUES (''e'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM auto WHERE id = 53' )
      exp = 1
      msg = 'insert after DO NOTHING uses the sequence' ).

    lo_database->execute( 'DROP TABLE auto' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT name FROM sqlite_sequence' )
      exp = 0
      msg = 'DROP TABLE removes the sequence row' ).

* the sequence is persisted across reopen
    lo_database->execute( 'CREATE TABLE auto2 (id INTEGER PRIMARY KEY AUTOINCREMENT, v TEXT)' ).
    lo_database->execute( 'INSERT INTO auto2 (v) VALUES (''a'')' ).
    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'DELETE FROM auto2' ).
    lo_database->execute( 'INSERT INTO auto2 (v) VALUES (''b'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM auto2 WHERE id = 2' )
      exp = 1
      msg = 'sqlite_sequence is persisted' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
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

  METHOD without_rowid_writes.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lv_name = 'test/m7_5_without_rowid.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    TRY.
        lo_database->execute( 'CREATE TABLE bad (a TEXT) WITHOUT ROWID' ).
        cl_abap_unit_assert=>fail( 'WITHOUT ROWID without primary key must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'PRIMARY KEY missing on table bad'
          msg = 'WITHOUT ROWID primary key error' ).
    ENDTRY.
    TRY.
        lo_database->query( 'SELECT a FROM bad' ).
        cl_abap_unit_assert=>fail( 'failed WITHOUT ROWID create must not leave a table' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'no such table: bad'
          msg = 'failed WITHOUT ROWID create rollback' ).
    ENDTRY.
    TRY.
        lo_database->execute( 'CREATE TABLE bad_auto (a INTEGER PRIMARY KEY AUTOINCREMENT) WITHOUT ROWID' ).
        cl_abap_unit_assert=>fail( 'WITHOUT ROWID AUTOINCREMENT must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'AUTOINCREMENT not allowed on WITHOUT ROWID tables'
          msg = 'WITHOUT ROWID autoincrement error' ).
    ENDTRY.

    lo_database->execute(
      'CREATE TABLE wr (a TEXT, b TEXT, c INTEGER, d TEXT, PRIMARY KEY (c, a)) WITHOUT ROWID' ).
    lo_database->execute( 'CREATE INDEX wr_b ON wr(b)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX wr_d ON wr(d)' ).
    lo_database->execute( 'INSERT INTO wr VALUES (''a2'', ''b2'', 2, ''d2'')' ).
    lo_database->execute( 'INSERT INTO wr VALUES (''a1'', ''b1'', 1, ''d1'')' ).
    lo_database->execute( 'INSERT INTO wr VALUES (''a3'', ''b3'', 3, ''d3'')' ).

    rs_result = lo_database->query( 'SELECT a, b, c, d FROM wr ORDER BY c, a' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'without rowid insert row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'a1'
      msg = 'without rowid stored primary key order' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'd1'
      msg = 'without rowid stored non-key order' ).

    lo_database->execute( 'UPDATE wr SET b = ''B2'', d = ''D2'' WHERE c = 2 AND a = ''a2''' ).
    rs_result = lo_database->query( 'SELECT b, d FROM wr WHERE c = 2 AND a = ''a2''' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'B2'
      msg = 'without rowid update value' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'D2'
      msg = 'without rowid update indexed value' ).

    TRY.
        lo_database->execute( 'INSERT INTO wr VALUES (''a2'', ''b9'', 2, ''d9'')' ).
        cl_abap_unit_assert=>fail( 'without rowid duplicate primary key must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint
          msg = 'without rowid duplicate primary key code' ).
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: wr.c, wr.a'
          msg = 'without rowid duplicate primary key text' ).
    ENDTRY.

    TRY.
        lo_database->execute( 'INSERT INTO wr VALUES (''a4'', ''b4'', 4, ''D2'')' ).
        cl_abap_unit_assert=>fail( 'without rowid duplicate unique index must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'UNIQUE constraint failed: wr.d'
          msg = 'without rowid duplicate unique index text' ).
    ENDTRY.

    lo_database->execute( 'INSERT OR IGNORE INTO wr VALUES (''a2'', ''b9'', 2, ''d9'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT a FROM wr' )
      exp = 3
      msg = 'without rowid insert or ignore' ).

    lo_database->execute( 'INSERT OR REPLACE INTO wr VALUES (''a2'', ''b8'', 2, ''d8'')' ).
    rs_result = lo_database->query( 'SELECT b, d FROM wr WHERE c = 2 AND a = ''a2''' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'b8'
      msg = 'without rowid insert or replace' ).

    lo_database->execute(
      'INSERT INTO wr VALUES (''a2'', ''b7'', 2, ''d7'') ' &&
      'ON CONFLICT (c, a) DO UPDATE SET b = excluded.b' ).
    rs_result = lo_database->query( 'SELECT b, d FROM wr WHERE c = 2 AND a = ''a2''' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'b7'
      msg = 'without rowid upsert update' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'd8'
      msg = 'without rowid upsert keeps unassigned column' ).

    rs_result = lo_database->query( 'UPDATE wr SET b = ''b1x'' WHERE c = 1 AND a = ''a1'' RETURNING a, b' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'without rowid update returning count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'b1x'
      msg = 'without rowid update returning value' ).

    rs_result = lo_database->query( 'DELETE FROM wr WHERE c = 2 AND a = ''a2'' RETURNING a' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'without rowid delete returning count' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT a FROM wr' )
      exp = 2
      msg = 'without rowid delete row count' ).

    lo_database->execute( 'DROP TABLE wr' ).
    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD views.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA lv_name     TYPE string.
    DATA lv_column   TYPE string.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lv_name = 'test/m7_7_views.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT)' ).
    lo_database->execute( 'CREATE TABLE books (id INTEGER PRIMARY KEY, author_id INTEGER, title TEXT, price)' ).
    lo_database->execute( 'INSERT INTO authors VALUES (1, ''Ada''), (2, ''Grace'')' ).
    lo_database->execute(
      'INSERT INTO books VALUES (1, 1, ''Alpha'', 10), (2, 1, ''Beta'', 20), (3, 2, ''Gamma'', NULL)' ).

    lo_database->execute(
      'CREATE VIEW book_view AS' &&
      ' SELECT a.id AS author_id, a.name AS author_name, b.id AS book_id, b.title' &&
      ' FROM authors a JOIN books b ON a.id = b.author_id' ).

    rs_result = lo_database->query( 'SELECT * FROM book_view ORDER BY book_id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 4
      msg = 'view column count' ).
    READ TABLE rs_result-columns INTO lv_column INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lv_column
      exp = 'book_id'
      msg = 'view column name' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'view row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Ada'
      msg = 'view projected value' ).

    lo_database->execute( 'CREATE VIEW book_names(book_id, title) AS SELECT id, title FROM books' ).
    rs_result = lo_database->query( 'SELECT * FROM book_names ORDER BY book_id' ).
    READ TABLE rs_result-columns INTO lv_column INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_column
      exp = 'book_id'
      msg = 'explicit view column name' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Gamma'
      msg = 'explicit view column value' ).

    lo_database->execute( 'CREATE VIEW pricey_books AS SELECT book_id, title FROM book_view WHERE book_id > 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT book_id FROM pricey_books' )
      exp = 2
      msg = 'nested view row count' ).

    lo_database->execute( 'CREATE VIEW IF NOT EXISTS book_view AS SELECT 1' ).
    lo_database->execute( 'CREATE TABLE IF NOT EXISTS book_view (x INTEGER)' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT book_id FROM book_view' )
      exp = 3
      msg = 'IF NOT EXISTS keeps view definition' ).

    TRY.
        lo_database->execute( 'CREATE VIEW book_view AS SELECT 1' ).
        cl_abap_unit_assert=>fail( 'duplicate view was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'view book_view already exists'
          msg = 'duplicate view error' ).
    ENDTRY.
    TRY.
        lo_database->execute( 'CREATE VIEW books AS SELECT 1' ).
        cl_abap_unit_assert=>fail( 'view over existing table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'table books already exists'
          msg = 'view table name conflict' ).
    ENDTRY.
    TRY.
        lo_database->execute( 'CREATE TABLE book_view (x INTEGER)' ).
        cl_abap_unit_assert=>fail( 'table over existing view was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'view book_view already exists'
          msg = 'table view name conflict' ).
    ENDTRY.
    TRY.
        lo_database->execute( 'DROP TABLE book_view' ).
        cl_abap_unit_assert=>fail( 'DROP TABLE accepted a view' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'use DROP VIEW to delete view book_view'
          msg = 'DROP TABLE view error' ).
    ENDTRY.
    TRY.
        lo_database->execute( 'DROP VIEW books' ).
        cl_abap_unit_assert=>fail( 'DROP VIEW accepted a table' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'use DROP TABLE to delete table books'
          msg = 'DROP VIEW table error' ).
    ENDTRY.
    TRY.
        lo_database->execute( 'CREATE TEMP VIEW temp_view AS SELECT 1' ).
        cl_abap_unit_assert=>fail( 'temporary view was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'temporary views are not supported'
          msg = 'temporary view error' ).
    ENDTRY.

    lo_database->execute( 'CREATE VIEW too_many(a, b) AS SELECT id FROM books' ).
    TRY.
        lo_database->query( 'SELECT * FROM too_many' ).
        cl_abap_unit_assert=>fail( 'view with mismatched columns was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'expected 2 columns for ''too_many'' but got 1'
          msg = 'view column count error' ).
    ENDTRY.

    lo_database->execute( 'CREATE VIEW loop AS SELECT * FROM loop' ).
    TRY.
        lo_database->query( 'SELECT * FROM loop' ).
        cl_abap_unit_assert=>fail( 'circular view was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'view loop is circularly defined'
          msg = 'circular view error' ).
    ENDTRY.

    lo_database->execute( 'DROP VIEW pricey_books' ).
    TRY.
        lo_database->query( 'SELECT * FROM pricey_books' ).
        cl_abap_unit_assert=>fail( 'dropped view is still visible' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'no such table: pricey_books'
          msg = 'dropped view error' ).
    ENDTRY.
    lo_database->execute( 'DROP VIEW IF EXISTS pricey_books' ).
    TRY.
        lo_database->execute( 'DROP VIEW pricey_books' ).
        cl_abap_unit_assert=>fail( 'missing view drop was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'no such view: pricey_books'
          msg = 'missing view drop error' ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD compound_selects.
    DATA lo_vfs       TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database  TYPE REF TO zcl_sqlite_database.
    DATA lo_statement TYPE REF TO zif_sqlite_statement.
    DATA lo_error     TYPE REF TO zcx_sqlite_error.
    DATA lv_name      TYPE string.
    DATA lv_column    TYPE string.
    DATA lv_found     TYPE abap_bool.
    DATA rs_result    TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row       TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.

    lv_name = 'test/m7_8_compound.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE left_t (id INTEGER, label TEXT)' ).
    lo_database->execute( 'CREATE TABLE right_t (id INTEGER, label TEXT)' ).
    lo_database->execute( 'INSERT INTO left_t VALUES (1, ''a''), (2, ''b''), (2, ''b''), (3, NULL)' ).
    lo_database->execute( 'INSERT INTO right_t VALUES (2, ''b''), (3, ''c''), (4, ''d''), (4, ''d'')' ).

    rs_result = lo_database->query( 'SELECT id FROM left_t UNION SELECT id FROM right_t ORDER BY 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 4
      msg = 'UNION removes duplicates' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 4.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 4
      msg = 'UNION is sorted' ).

    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM left_t UNION ALL SELECT id FROM right_t' )
      exp = 8
      msg = 'UNION ALL keeps duplicates' ).

    rs_result = lo_database->query( 'SELECT id FROM left_t INTERSECT SELECT id FROM right_t ORDER BY 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'INTERSECT row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'INTERSECT keeps common rows' ).

    rs_result = lo_database->query( 'SELECT id FROM left_t EXCEPT SELECT id FROM right_t ORDER BY 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'EXCEPT row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'EXCEPT keeps only left rows' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM right_t EXCEPT SELECT id FROM left_t' )
      exp = 1
      msg = 'EXCEPT is not symmetric' ).

    rs_result = lo_database->query( 'SELECT NULL AS n UNION SELECT NULL' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'UNION treats NULLs as equal' ).

    rs_result = lo_database->query( 'SELECT 1 AS n UNION SELECT 2 INTERSECT SELECT 2 ORDER BY 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'compound operators are left associative' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'left associative compound value' ).

    rs_result = lo_database->query( 'VALUES (1, ''a''), (2, ''b'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 2
      msg = 'VALUES column count' ).
    READ TABLE rs_result-columns INTO lv_column INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_column
      exp = 'column1'
      msg = 'VALUES column name' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'VALUES row count' ).

    lo_database->execute( 'CREATE VIEW combined AS SELECT id FROM left_t UNION SELECT id FROM right_t' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM combined' )
      exp = 4
      msg = 'compound view row count' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM (SELECT id FROM left_t' &&
                                      ' UNION SELECT id FROM right_t)' )
      exp = 4
      msg = 'compound FROM subquery' ).
    rs_result = lo_database->query( 'SELECT (SELECT 3 AS n UNION SELECT 1 ORDER BY 1) AS n' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'compound scalar subquery' ).

    lo_database->execute( 'CREATE TABLE target (id INTEGER)' ).
    lo_database->execute( 'INSERT INTO target SELECT id FROM left_t UNION ALL SELECT id FROM right_t' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT id FROM target' )
      exp = 8
      msg = 'INSERT SELECT compound row count' ).

    lo_statement = lo_database->prepare( 'SELECT id FROM left_t UNION SELECT id FROM right_t ORDER BY 1' ).
    lv_found = lo_statement->step( ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'prepared compound returns rows' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_statement->column_count( )
      exp = 1
      msg = 'prepared compound column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_statement->column_value( 1 )->as_integer( )
      exp = 1
      msg = 'prepared compound first row' ).

    TRY.
        lo_database->query( 'SELECT 1 UNION SELECT 1, 2' ).
        cl_abap_unit_assert=>fail( 'compound with mismatched columns was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'SELECTs to the left and right of UNION do not have the same number of result columns'
          msg = 'compound column mismatch error' ).
    ENDTRY.
    TRY.
        lo_database->query( 'SELECT 1 AS n UNION SELECT 2 ORDER BY 2' ).
        cl_abap_unit_assert=>fail( 'compound ORDER BY out of range was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = '1st ORDER BY term out of range - should be between 1 and 1'
          msg = 'compound ORDER BY range error' ).
    ENDTRY.
    TRY.
        lo_database->query( 'SELECT 1 AS n UNION SELECT 2 ORDER BY missing' ).
        cl_abap_unit_assert=>fail( 'compound ORDER BY unknown column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = '1st ORDER BY term does not match any column in the result set'
          msg = 'compound ORDER BY column error' ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD ctes.
    DATA lo_vfs       TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database  TYPE REF TO zcl_sqlite_database.
    DATA lo_statement TYPE REF TO zif_sqlite_statement.
    DATA lo_error     TYPE REF TO zcx_sqlite_error.
    DATA lv_name      TYPE string.
    DATA rs_result    TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row       TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.

    lv_name = 'test/m7_9_ctes.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER, label TEXT)' ).
    lo_database->execute( 'INSERT INTO items VALUES (1, ''a''), (2, ''b''), (3, ''c'')' ).

    rs_result = lo_database->query(
      'WITH c AS (SELECT id, label FROM items WHERE id < 3)' &&
      ' SELECT * FROM c ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'basic CTE row count' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-columns[ 1 ]
      exp = 'id'
      msg = 'basic CTE column name' ).

    rs_result = lo_database->query(
      'WITH c(x, y) AS (SELECT id, label FROM items)' &&
      ' SELECT * FROM c ORDER BY x' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-columns[ 1 ]
      exp = 'x'
      msg = 'CTE explicit column name' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'c'
      msg = 'CTE explicit column row' ).

    rs_result = lo_database->query( 'WITH c AS (SELECT * FROM d), d AS (SELECT 1 AS x) SELECT * FROM c' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'CTE forward reference' ).

    rs_result = lo_database->query(
      'WITH c AS (SELECT id FROM items), d AS (SELECT id + 10 AS id FROM c)' &&
      ' SELECT * FROM d ORDER BY id' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 11
      msg = 'CTE references earlier CTE' ).

    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'WITH c AS (SELECT * FROM missing) SELECT 1' )
      exp = 1
      msg = 'unused CTE is not evaluated' ).

    lo_database->execute( 'CREATE TABLE target (id INTEGER, label TEXT)' ).
    lo_database->execute(
      'WITH c AS (SELECT id, label FROM items WHERE id > 1)' &&
      ' INSERT INTO target SELECT * FROM c' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database iv_sql = 'SELECT * FROM target' )
      exp = 2
      msg = 'CTE INSERT SELECT row count' ).

    lo_database->execute(
      'WITH c AS (SELECT 9 AS id) UPDATE target SET id = (SELECT id FROM c) WHERE label = ''b''' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database
                        iv_sql      = 'SELECT * FROM target WHERE id = 9' )
      exp = 1
      msg = 'CTE UPDATE' ).

    lo_database->execute( 'WITH c AS (SELECT 9 AS id) DELETE FROM target WHERE id = (SELECT id FROM c)' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database iv_sql = 'SELECT * FROM target' )
      exp = 1
      msg = 'CTE DELETE row count' ).

    rs_result = lo_database->query( 'WITH c AS (SELECT 2 AS x) SELECT (SELECT x FROM c) AS y' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'CTE in scalar subquery' ).

    rs_result = lo_database->query(
      'WITH c AS (SELECT 1 AS x) SELECT * FROM (WITH d AS' &&
      ' (SELECT x + 1 AS x FROM c) SELECT * FROM d)' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'nested WITH reads outer CTE' ).

    lo_database->execute(
      'CREATE VIEW cte_view AS WITH c AS (SELECT id FROM items WHERE id > 1)' &&
      ' SELECT * FROM c' ).
    cl_abap_unit_assert=>assert_equals(
      act = count_rows( io_database = lo_database iv_sql = 'SELECT * FROM cte_view' )
      exp = 2
      msg = 'CTE in view' ).

    rs_result = lo_database->query( 'WITH items AS (SELECT 5 AS id) SELECT * FROM items' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'CTE shadows table' ).

    rs_result = lo_database->query(
      'WITH RECURSIVE cnt(x) AS (VALUES(1) UNION ALL' &&
      ' SELECT x + 1 FROM cnt WHERE x < 5) SELECT * FROM cnt' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 5
      msg = 'recursive CTE row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 5.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'recursive CTE last row' ).

    rs_result = lo_database->query(
      'WITH RECURSIVE c(x) AS (VALUES(3), (2) UNION SELECT 1)' &&
      ' SELECT * FROM c' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'recursive UNION distinct row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'recursive UNION distinct is sorted' ).

    rs_result = lo_database->query(
      'WITH RECURSIVE c(x) AS (VALUES(3), (2) UNION ALL SELECT 1)' &&
      ' SELECT * FROM c' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'recursive UNION ALL keeps generation order' ).

    rs_result = lo_database->query(
      'WITH RECURSIVE cnt(x) AS (SELECT 1 UNION ALL' &&
      ' SELECT x + 1 FROM cnt WHERE x < 10 LIMIT 3) SELECT * FROM cnt' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'recursive CTE LIMIT' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'recursive CTE LIMIT last row' ).

    lo_statement = lo_database->prepare( 'WITH c AS (SELECT id FROM items) SELECT * FROM c ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_statement->step( )
      exp = abap_true
      msg = 'prepared CTE returns rows' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_statement->column_value( 1 )->as_integer( )
      exp = 1
      msg = 'prepared CTE first row' ).

    TRY.
        lo_database->query( 'WITH c AS (SELECT 1), c AS (SELECT 2) SELECT * FROM c' ).
        cl_abap_unit_assert=>fail( 'duplicate CTE name was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'duplicate WITH table name: c'
          msg = 'duplicate CTE name error' ).
    ENDTRY.
    TRY.
        lo_database->query( 'WITH c(x) AS (SELECT id, label FROM items) SELECT * FROM c' ).
        cl_abap_unit_assert=>fail( 'CTE column count mismatch was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'table c has 2 values for 1 columns'
          msg = 'CTE column count error' ).
    ENDTRY.
    TRY.
        lo_database->query( 'WITH c AS (SELECT * FROM c) SELECT * FROM c' ).
        cl_abap_unit_assert=>fail( 'circular CTE was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'circular reference: c'
          msg = 'circular CTE error' ).
    ENDTRY.
    TRY.
        lo_database->query( 'WITH RECURSIVE c(x) AS (SELECT * FROM c) SELECT * FROM c' ).
        cl_abap_unit_assert=>fail( 'recursive CTE without UNION was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'circular reference: c'
          msg = 'recursive CTE shape error' ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

ENDCLASS.
