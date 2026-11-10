* Scenario programs for the sql.js compatibility verifier. The verifier runs
* these through the transpiled ABAP runtime, then reads the ZSQLITE_FILES rows
* from the transpiler's SQLite connection.
CLASS zcl_sqlite_scenario DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_create_table_database TYPE string VALUE 'compat/create-table.db'.
    CONSTANTS c_empty_database TYPE string VALUE 'compat/empty.db'.
    CONSTANTS c_freelist_database TYPE string VALUE 'compat/freelist.db'.
    CONSTANTS c_insert_database TYPE string VALUE 'compat/insert.db'.
    CONSTANTS c_insert_statements_database TYPE string VALUE 'compat/insert-statements.db'.
    CONSTANTS c_overflow_database TYPE string VALUE 'compat/overflow-write.db'.
    CONSTANTS c_split_database TYPE string VALUE 'compat/split.db'.

    CLASS-METHODS create_empty
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS create_table
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS freelist_cycle
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS insert_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS insert_statements
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS overflow_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS split_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    CLASS-METHODS make_freeblock
      IMPORTING io_pager         TYPE REF TO zcl_sqlite_pager
                iv_page          TYPE i
                iv_size          TYPE i
      RETURNING VALUE(rv_offset) TYPE i
      RAISING   zcx_sqlite_error.

    CLASS-METHODS set_u16
      IMPORTING iv_data        TYPE xstring
                iv_offset      TYPE i
                iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_scenario IMPLEMENTATION.

  METHOD create_table.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_create_table_database ).

    lo_database = zcl_sqlite_database=>create( c_create_table_database ).
    lo_database->execute( 'CREATE TABLE created (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)' ).
    lo_database->execute( 'CREATE TABLE IF NOT EXISTS created (id INTEGER)' ).
    lo_database->execute( 'CREATE TABLE notes (body TEXT)' ).
    rs_result = lo_database->query( 'SELECT id, name FROM created' ).
    IF lines( rs_result-columns ) <> 2 OR lines( rs_result-rows ) <> 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'created table did not reload into the catalog'.
    ENDIF.
    lo_database->close( ).

    rv_name = c_create_table_database.
  ENDMETHOD.

  METHOD create_empty.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_empty_database ).

    lo_database = zcl_sqlite_database=>create( c_empty_database ).
    lo_database->close( ).

    rv_name = c_empty_database.
  ENDMETHOD.

  METHOD insert_statements.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_insert_statements_database ).

    lo_database = zcl_sqlite_database=>create( c_insert_statements_database ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT ''anon'',' &&
      ' qty INTEGER DEFAULT 7, price REAL, note TEXT, bin BLOB)' ).
    lo_database->execute( 'INSERT INTO items (name, qty, price) VALUES (''alpha'', 2, 3.5)' ).
    lo_database->execute( 'INSERT INTO items (id, name, price) VALUES (10, ''beta'', 4)' ).
    lo_database->execute( 'INSERT INTO items DEFAULT VALUES' ).
    lo_database->execute(
      'INSERT INTO items VALUES (NULL, ''gamma'', ''8'', ''2.5'', ''x'', x''0102''), ' &&
      '(100, ''delta'', 9, 0, NULL, NULL)' ).

    lo_database->execute( 'CREATE TABLE source (id INTEGER PRIMARY KEY, label TEXT, amount NUMERIC)' ).
    lo_database->execute(
      'CREATE TABLE dest (id INTEGER PRIMARY KEY, label TEXT NOT NULL,' &&
      ' amount REAL DEFAULT 1.0, status TEXT DEFAULT ''new'')' ).
    lo_database->execute(
      'INSERT INTO source VALUES (1, ''one'', 10), (2, ''two'', 2.5), ' &&
      '(3, ''three'', ''4'')' ).
    lo_database->execute( 'INSERT INTO dest (label, amount) SELECT label, amount FROM source ORDER BY id' ).
    lo_database->execute( 'INSERT INTO dest (label) SELECT ''four''' ).
    lo_database->execute( 'INSERT INTO dest SELECT 100, ''five'', 5.5, ''old''' ).
    lo_database->execute(
      'INSERT INTO dest (label, amount, status) ' &&
      'SELECT label, amount, status FROM dest WHERE id = 100' ).
    lo_database->execute( 'INSERT INTO dest (label) VALUES (''six'')' ).
    lo_database->close( ).

    rv_name = c_insert_statements_database.
  ENDMETHOD.

  METHOD freelist_cycle.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_page     TYPE i.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_freelist_database ).

    lo_database = zcl_sqlite_database=>create( c_freelist_database ).
    lo_database->close( ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( c_freelist_database ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).

* pages 2..13 are appended, then four of them are freed
    DO 12 TIMES.
      lv_page = lo_pager->allocate_page( ).
    ENDDO.
    lo_pager->free_page( 2 ).
    lo_pager->free_page( 4 ).
    lo_pager->free_page( 6 ).
    lo_pager->free_page( 8 ).

* four allocations consume the freelist, then pages 14 and 15 are appended
    DO 6 TIMES.
      lv_page = lo_pager->allocate_page( ).
    ENDDO.

* free every data page, page 2 becomes the trunk with pages 3..15 as leaves
    lv_page = 2.
    WHILE lv_page <= 15.
      lo_pager->free_page( lv_page ).
      lv_page = lv_page + 1.
    ENDWHILE.
    lo_pager->commit( ).

    lo_file->close( ).
    rv_name = c_freelist_database.
  ENDMETHOD.

  METHOD insert_rows.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lv_fixture TYPE xstring.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_long_name TYPE string.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_insert_database ).
    TRY.
        lv_fixture = lo_vfs->export( 'fixtures/small.db' ).
      CATCH cx_sy_file_access_error.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'small.db fixture is missing'.
    ENDTRY.
    lo_vfs->import( iv_name = c_insert_database
                    iv_data = lv_fixture ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( c_insert_database ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).

* carve a freeblock out of the gap so the first insert reuses it
    make_freeblock( io_pager = lo_pager
                    iv_page  = 2
                    iv_size  = 100 ).

    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = lo_pager
      iv_root_page = 2 ).

    APPEND zcl_sqlite_value=>integer( 4 ) TO lt_values.
    APPEND zcl_sqlite_value=>text( 'delta' ) TO lt_values.
    APPEND zcl_sqlite_value=>real( '4.5' ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 4
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    CLEAR lt_values.
    APPEND zcl_sqlite_value=>integer( 0 ) TO lt_values.
    APPEND zcl_sqlite_value=>text( 'zero' ) TO lt_values.
    APPEND zcl_sqlite_value=>real( '0' ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 0
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    CLEAR lt_values.
    lv_long_name = repeat( val = 'x'
                           occ = 2000 ).
    APPEND zcl_sqlite_value=>integer( 7 ) TO lt_values.
    APPEND zcl_sqlite_value=>text( lv_long_name ) TO lt_values.
    APPEND zcl_sqlite_value=>real( '7.5' ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 7
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    CLEAR lt_values.
    APPEND zcl_sqlite_value=>integer( 5 ) TO lt_values.
    APPEND zcl_sqlite_value=>text( 'epsilon' ) TO lt_values.
    APPEND zcl_sqlite_value=>null( ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 5
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    CLEAR lt_values.
    APPEND zcl_sqlite_value=>integer( 10 ) TO lt_values.
    APPEND zcl_sqlite_value=>text( 'ten' ) TO lt_values.
    APPEND zcl_sqlite_value=>real( '-1.25' ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 10
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    lo_pager->commit( ).
    lo_file->close( ).
    rv_name = c_insert_database.
  ENDMETHOD.

  METHOD overflow_rows.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lv_fixture TYPE xstring.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_text TYPE string.
    DATA lv_blob TYPE xstring.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_overflow_database ).
    TRY.
        lv_fixture = lo_vfs->export( 'fixtures/overflow.db' ).
      CATCH cx_sy_file_access_error.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'overflow.db fixture is missing'.
    ENDTRY.
    lo_vfs->import( iv_name = c_overflow_database
                    iv_data = lv_fixture ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( c_overflow_database ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = lo_pager
      iv_root_page = 2 ).

    lv_text = repeat( val = 'Z'
                      occ = 10000 ).
    APPEND zcl_sqlite_value=>text( 'large_text' ) TO lt_values.
    APPEND zcl_sqlite_value=>text( lv_text ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 100
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    CLEAR lt_values.
    lv_blob = repeat( val = '00112233445566778899AABBCCDDEEFF'
                      occ = 750 ).
    APPEND zcl_sqlite_value=>text( 'large_blob' ) TO lt_values.
    APPEND zcl_sqlite_value=>blob( lv_blob ) TO lt_values.
    lo_writer->insert_row(
      iv_rowid   = 101
      iv_payload = zcl_sqlite_record=>encode( lt_values ) ).

    lo_pager->commit( ).
    lo_file->close( ).
    rv_name = c_overflow_database.
  ENDMETHOD.

  METHOD split_rows.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lv_fixture TYPE xstring.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_suffix TYPE string.
    DATA lv_name TYPE string.
    DATA lv_rowid TYPE int8.
    DATA lv_index TYPE i.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_split_database ).
    TRY.
        lv_fixture = lo_vfs->export( 'fixtures/small.db' ).
      CATCH cx_sy_file_access_error.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'small.db fixture is missing'.
    ENDTRY.
    lo_vfs->import( iv_name = c_split_database
                    iv_data = lv_fixture ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( c_split_database ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = lo_pager
      iv_root_page = 2 ).
    lv_suffix = repeat( val = 'x'
                        occ = 100 ).

* 10k ascending rowids
    DO 10000 TIMES.
      lv_index = sy-index.
      lv_rowid = 999 + lv_index.
      lv_name = |seq-{ lv_rowid }-{ lv_suffix }|.
      CLEAR lt_values.
      APPEND zcl_sqlite_value=>integer( lv_rowid ) TO lt_values.
      APPEND zcl_sqlite_value=>text( lv_name ) TO lt_values.
      APPEND zcl_sqlite_value=>real( '0.5' ) TO lt_values.
      lo_writer->insert_row(
        iv_rowid   = lv_rowid
        iv_payload = zcl_sqlite_record=>encode( lt_values ) ).
    ENDDO.

* 10k shuffled rowids, 7919 is coprime with 10000
    DO 10000 TIMES.
      lv_index = sy-index.
      lv_rowid = 100000 + ( lv_index * 7919 ) MOD 10000.
      lv_name = |rnd-{ lv_rowid }-{ lv_suffix }|.
      CLEAR lt_values.
      APPEND zcl_sqlite_value=>integer( lv_rowid ) TO lt_values.
      APPEND zcl_sqlite_value=>text( lv_name ) TO lt_values.
      APPEND zcl_sqlite_value=>real( '0.5' ) TO lt_values.
      lo_writer->insert_row(
        iv_rowid   = lv_rowid
        iv_payload = zcl_sqlite_record=>encode( lt_values ) ).
    ENDDO.

    lo_pager->commit( ).
    lo_file->close( ).
    rv_name = c_split_database.
  ENDMETHOD.

  METHOD make_freeblock.
    DATA ls_raw TYPE zcl_sqlite_pager=>ty_page.
    DATA ls_page TYPE zcl_sqlite_page=>ty_page.
    DATA lv_data TYPE xstring.

    ls_raw = io_pager->get_page( iv_page ).
    ls_page = zcl_sqlite_page=>parse(
      iv_data   = ls_raw-data
      iv_offset = ls_raw-btree_offset ).
    rv_offset = ls_page-cell_content_offset - iv_size.

    lv_data = ls_raw-data.
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = ls_page-cell_pointer_offset - 7
      iv_value  = CONV int8( rv_offset ) ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = ls_page-cell_pointer_offset - 3
      iv_value  = CONV int8( rv_offset ) ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = rv_offset
      iv_value  = 0 ).
    lv_data = set_u16(
      iv_data   = lv_data
      iv_offset = rv_offset + 2
      iv_value  = CONV int8( iv_size ) ).

    io_pager->put_page( iv_page = iv_page
                        iv_data = lv_data ).
  ENDMETHOD.

  METHOD set_u16.
    TRY.
        rv_data = zcl_sqlite_bytes=>write_u16(
          iv_data   = iv_data
          iv_offset = iv_offset
          iv_value  = iv_value ).
      CATCH cx_sy_range_out_of_bounds cx_sy_conversion_overflow.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_internal
            iv_message = 'scenario page could not be prepared'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
