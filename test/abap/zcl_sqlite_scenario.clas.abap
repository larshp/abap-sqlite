* Scenario programs for the sql.js compatibility verifier. The verifier runs
* these through the transpiled ABAP runtime, then reads the ZSQLITE_FILES rows
* from the transpiler's SQLite connection.
CLASS zcl_sqlite_scenario DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_autoincrement_database TYPE string VALUE 'compat/autoincrement.db'.
    CONSTANTS c_conflict_database TYPE string VALUE 'compat/conflict.db'.
    CONSTANTS c_constraints_database TYPE string VALUE 'compat/constraints.db'.
    CONSTANTS c_create_table_database TYPE string VALUE 'compat/create-table.db'.
    CONSTANTS c_delete_database TYPE string VALUE 'compat/delete.db'.
    CONSTANTS c_drop_database TYPE string VALUE 'compat/drop.db'.
    CONSTANTS c_empty_database TYPE string VALUE 'compat/empty.db'.
    CONSTANTS c_freelist_database TYPE string VALUE 'compat/freelist.db'.
    CONSTANTS c_index_database TYPE string VALUE 'compat/index.db'.
    CONSTANTS c_insert_database TYPE string VALUE 'compat/insert.db'.
    CONSTANTS c_insert_statements_database TYPE string VALUE 'compat/insert-statements.db'.
    CONSTANTS c_overflow_database TYPE string VALUE 'compat/overflow-write.db'.
    CONSTANTS c_random_checkpoint TYPE i VALUE 2000.
    CONSTANTS c_random_database TYPE string VALUE 'compat/random.db'.
    CONSTANTS c_random_operations TYPE i VALUE 12000.
    CONSTANTS c_split_database TYPE string VALUE 'compat/split.db'.
    CONSTANTS c_update_database TYPE string VALUE 'compat/update.db'.
    CONSTANTS c_unique_database TYPE string VALUE 'compat/unique.db'.
    CONSTANTS c_without_rowid_database TYPE string VALUE 'compat/without-rowid.db'.

    CLASS-METHODS create_empty
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS create_table
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS column_constraints
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS conflict_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS autoincrement_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS delete_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS drop_objects
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS freelist_cycle
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS index_rows
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

    CLASS-METHODS random_workload
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS split_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS update_rows
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS unique_keys
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS without_rowid_writes
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    CLASS-METHODS expect_constraint_error
      IMPORTING io_database TYPE REF TO zcl_sqlite_database
                iv_sql      TYPE string
      RAISING   zcx_sqlite_error.

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

    lo_database = zcl_sqlite_database=>open( c_create_table_database ).
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

    lo_database = zcl_sqlite_database=>open( c_empty_database ).
    lo_database->close( ).

    rv_name = c_empty_database.
  ENDMETHOD.

  METHOD column_constraints.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_constraints_database ).

    lo_database = zcl_sqlite_database=>open( c_constraints_database ).
    lo_database->execute(
      'CREATE TABLE constrained (id INTEGER PRIMARY KEY,' &&
      ' code TEXT NOT NULL COLLATE NOCASE,' &&
      ' rcode TEXT COLLATE RTRIM,' &&
      ' qty INTEGER DEFAULT (1 + 2) CHECK (qty > 0),' &&
      ' label TEXT DEFAULT (lower(''MiXeD'')),' &&
      ' amount INTEGER,' &&
      ' CONSTRAINT amount_ok CHECK (amount >= 0))' ).
    lo_database->execute(
      'INSERT INTO constrained (id, code, rcode, qty, label, amount) ' &&
      'VALUES (1, ''alpha'', ''x '', 1, ''one'', 10)' ).
    lo_database->execute(
      'INSERT INTO constrained (id, code, rcode, qty, label, amount) ' &&
      'VALUES (2, ''Beta'', ''y  '', 2, ''two'', 0)' ).
    lo_database->execute(
      'INSERT INTO constrained (id, code, rcode, amount) ' &&
      'VALUES (3, ''ALPHA'', ''z'', 5)' ).
    lo_database->execute(
      'INSERT INTO constrained (id, code, rcode, qty, label, amount) ' &&
      'VALUES (4, ''aLpHa'', NULL, 4, ''last'', 7)' ).
    lo_database->execute( 'UPDATE constrained SET amount = amount + 1 WHERE id = 2' ).
    lo_database->close( ).

    rv_name = c_constraints_database.
  ENDMETHOD.

  METHOD conflict_rows.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_conflict_database ).

    lo_database = zcl_sqlite_database=>open( c_conflict_database ).
    lo_database->execute(
      'CREATE TABLE conflict_rows (id INTEGER PRIMARY KEY,' &&
      ' code TEXT UNIQUE, amount INTEGER)' ).

* INSERTS
    lo_database->execute( 'INSERT INTO conflict_rows VALUES (1, ''alpha'', 10), (2, ''beta'', 20)' ).
    lo_database->execute( 'INSERT OR IGNORE INTO conflict_rows VALUES (1, ''ignored'', 99)' ).
    lo_database->execute( 'INSERT OR REPLACE INTO conflict_rows VALUES (3, ''beta'', 30)' ).
    expect_constraint_error(
      io_database = lo_database
      iv_sql      = 'INSERT OR FAIL INTO conflict_rows VALUES (4, ''gamma'', 40), (3, ''delta'', 50)' ).
    expect_constraint_error(
      io_database = lo_database
      iv_sql      = 'INSERT INTO conflict_rows VALUES (5, ''epsilon'', 50), (3, ''zeta'', 60)' ).

* UPSERTS
    lo_database->execute(
      'INSERT INTO conflict_rows VALUES (6, ''alpha'', 5) ' &&
      'ON CONFLICT (code) DO UPDATE SET amount = amount + excluded.amount' ).
    lo_database->execute(
      'INSERT INTO conflict_rows VALUES (7, ''beta'', 7) ' &&
      'ON CONFLICT (code) DO NOTHING' ).
    lo_database->execute( 'INSERT INTO conflict_rows VALUES (8, ''eta'', 80)' ).

* UPDATE OR ACTIONS
    lo_database->execute( 'UPDATE OR IGNORE conflict_rows SET code = ''alpha'' WHERE id = 4' ).
    lo_database->execute( 'UPDATE OR REPLACE conflict_rows SET code = ''alpha'' WHERE id = 4' ).
    lo_database->execute( 'UPDATE conflict_rows SET amount = amount + 1 WHERE id = 4' ).

* RETURNING
    rs_result = lo_database->query( 'INSERT INTO conflict_rows VALUES (9, ''theta'', 90) RETURNING id, amount' ).
    rs_result = lo_database->query(
      'UPDATE conflict_rows SET amount = amount + 2 WHERE id = 9 RETURNING amount' ).
    rs_result = lo_database->query( 'DELETE FROM conflict_rows WHERE id = 9 RETURNING id' ).

    lo_database->close( ).

    rv_name = c_conflict_database.
  ENDMETHOD.

  METHOD autoincrement_rows.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_autoincrement_database ).

    lo_database = zcl_sqlite_database=>open( c_autoincrement_database ).
    lo_database->execute( 'CREATE TABLE auto_basic (id INTEGER PRIMARY KEY AUTOINCREMENT,' && ' v TEXT UNIQUE)' ).
    lo_database->execute( 'INSERT INTO auto_basic (v) VALUES (''a'')' ).
    lo_database->execute( 'INSERT INTO auto_basic (v) VALUES (''b'')' ).
    lo_database->execute( 'DELETE FROM auto_basic WHERE id = 2' ).
    lo_database->execute( 'INSERT INTO auto_basic (v) VALUES (''c'')' ).
    lo_database->execute( 'INSERT INTO auto_basic (id, v) VALUES (10, ''d'')' ).
    lo_database->execute( 'INSERT INTO auto_basic (id, v) VALUES (5, ''e'')' ).
    lo_database->execute( 'INSERT OR IGNORE INTO auto_basic (id, v) VALUES (20, ''c'')' ).
    lo_database->execute( 'INSERT INTO auto_basic (v) VALUES (''c'') ON CONFLICT (v) DO NOTHING' ).
    lo_database->execute( 'INSERT INTO auto_basic (v) VALUES (''g'')' ).

    lo_database->execute( 'CREATE TABLE auto_second (id INTEGER PRIMARY KEY AUTOINCREMENT,' && ' v TEXT)' ).
    lo_database->execute( 'INSERT INTO auto_second (v) VALUES (''a'')' ).
    lo_database->execute( 'DROP TABLE auto_basic' ).
    lo_database->execute( 'INSERT INTO auto_second (v) VALUES (''b'')' ).

    lo_database->close( ).

    rv_name = c_autoincrement_database.
  ENDMETHOD.

  METHOD without_rowid_writes.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_without_rowid_database ).

    lo_database = zcl_sqlite_database=>open( c_without_rowid_database ).
    lo_database->execute(
      'CREATE TABLE wr (a TEXT, b TEXT, c INTEGER, d TEXT,' &&
      ' PRIMARY KEY (c, a)) WITHOUT ROWID' ).
    lo_database->execute( 'CREATE INDEX wr_b ON wr(b)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX wr_d ON wr(d)' ).
    lo_database->execute(
      'INSERT INTO wr VALUES' &&
      ' (''a2'', ''b2'', 2, ''d2''),' &&
      ' (''a1'', ''b1'', 1, ''d1''),' &&
      ' (''a3'', ''b3'', 3, ''d3'')' ).
    lo_database->execute( 'UPDATE wr SET b = ''B2'', d = ''D2''' && ' WHERE c = 2 AND a = ''a2''' ).
    lo_database->execute( 'UPDATE wr SET c = 4 WHERE c = 3 AND a = ''a3''' ).
    lo_database->execute( 'INSERT OR IGNORE INTO wr VALUES (''a1'', ''ignored'', 1, ''d9'')' ).
    lo_database->execute( 'INSERT OR REPLACE INTO wr VALUES (''a2'', ''b8'', 2, ''d8'')' ).
    lo_database->execute(
      'INSERT INTO wr VALUES (''a2'', ''b7'', 2, ''d7'')' &&
      ' ON CONFLICT (c, a) DO UPDATE SET b = excluded.b' ).
    lo_database->execute( 'INSERT INTO wr VALUES (''a4'', ''b4'', 4, ''d4'')' ).
    lo_database->execute( 'UPDATE wr SET d = ''D4'' WHERE c = 4 AND a = ''a4''' ).
    lo_database->execute( 'DELETE FROM wr WHERE c = 1 AND a = ''a1''' ).

    lo_database->execute(
      'CREATE TABLE wr_nocase (k TEXT COLLATE NOCASE PRIMARY KEY,' &&
      ' v TEXT) WITHOUT ROWID' ).
    lo_database->execute(
      'INSERT INTO wr_nocase VALUES' &&
      ' (''Beta'', ''b''), (''alpha'', ''a''), (''Gamma'', ''g'')' ).
    lo_database->execute( 'UPDATE wr_nocase SET v = ''A'' WHERE k = ''ALPHA''' ).

    lo_database->close( ).

    rv_name = c_without_rowid_database.
  ENDMETHOD.

  METHOD unique_keys.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_unique_database ).

    lo_database = zcl_sqlite_database=>open( c_unique_database ).
    lo_database->execute(
      'CREATE TABLE unique_basic (id INTEGER PRIMARY KEY,' &&
      ' code TEXT NOT NULL UNIQUE, part_a TEXT, part_b TEXT,' &&
      ' UNIQUE (part_a, part_b))' ).
    lo_database->execute(
      'INSERT INTO unique_basic VALUES' &&
      ' (1, ''alpha'', ''x'', ''y''),' &&
      ' (2, ''Beta'', ''x'', ''z''),' &&
      ' (3, ''gamma'', NULL, ''y''),' &&
      ' (4, ''delta'', NULL, ''y'')' ).
    expect_constraint_error(
      io_database = lo_database
      iv_sql      = 'INSERT INTO unique_basic VALUES (5, ''alpha'', ''n'', ''m'')' ).
    expect_constraint_error(
      io_database = lo_database
      iv_sql      = 'INSERT INTO unique_basic VALUES (6, ''epsilon'', ''x'', ''y'')' ).
    lo_database->execute( 'INSERT INTO unique_basic VALUES (7, ''zeta'', ''n'', ''m'')' ).

    lo_database->execute(
      'CREATE TABLE unique_nocase (id INTEGER PRIMARY KEY,' &&
      ' code TEXT COLLATE NOCASE UNIQUE, tag TEXT COLLATE RTRIM,' &&
      ' UNIQUE (tag, code))' ).
    lo_database->execute(
      'INSERT INTO unique_nocase VALUES' &&
      ' (1, ''Alpha'', ''x ''),' &&
      ' (2, ''Beta'', ''y''),' &&
      ' (3, ''Gamma'', NULL),' &&
      ' (4, ''Delta'', NULL)' ).
    expect_constraint_error(
      io_database = lo_database
      iv_sql      = 'INSERT INTO unique_nocase VALUES (5, ''alpha'', ''z'')' ).
    expect_constraint_error(
      io_database = lo_database
      iv_sql      = 'UPDATE unique_nocase SET code = ''ALPHA'' WHERE id = 3' ).

    lo_database->execute( 'UPDATE unique_basic SET code = ''eta'' WHERE id = 1' ).
    lo_database->execute( 'UPDATE unique_nocase SET tag = ''z'' WHERE id = 3' ).
    lo_database->close( ).

    rv_name = c_unique_database.
  ENDMETHOD.

  METHOD expect_constraint_error.
    DATA lo_error TYPE REF TO zcx_sqlite_error.

    TRY.
        io_database->execute( iv_sql ).
      CATCH zcx_sqlite_error INTO lo_error.
        IF lo_error->code = zcx_sqlite_error=>sqlite_constraint.
          RETURN.
        ENDIF.
        RAISE EXCEPTION lo_error.
    ENDTRY.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_constraint
        iv_message = |expected a constraint error from { iv_sql }|.
  ENDMETHOD.

  METHOD insert_statements.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_insert_statements_database ).

    lo_database = zcl_sqlite_database=>open( c_insert_statements_database ).
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

  METHOD delete_rows.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_suffix   TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_from     TYPE i.
    DATA lv_to       TYPE i.
    DATA lv_id       TYPE i.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_delete_database ).

    lo_database = zcl_sqlite_database=>open( c_delete_database ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, amount REAL)' ).

    lv_suffix = repeat( val = 'x'
                        occ = 40 ).
    lv_from = 1.
    WHILE lv_from <= 10000.
      lv_to = lv_from + 499.
      IF lv_to > 10000.
        lv_to = 10000.
      ENDIF.

      CLEAR lv_values.
      lv_id = lv_from.
      WHILE lv_id <= lv_to.
        IF lv_id > lv_from.
          lv_values = lv_values && ', '.
        ENDIF.
        lv_values = lv_values && |({ lv_id }, 'row-{ lv_id }-{ lv_suffix }', { lv_id })|.
        lv_id = lv_id + 1.
      ENDWHILE.

      lo_database->execute( |INSERT INTO items (id, name, amount) VALUES { lv_values }| ).
      lv_from = lv_to + 1.
    ENDWHILE.

    lo_database->execute( 'DELETE FROM items WHERE id % 7 = 0' ).
    lo_database->execute( 'DELETE FROM items WHERE id BETWEEN 2000 AND 2999' ).
    lo_database->execute( 'DELETE FROM items WHERE id % 11 = 0 AND id > 5000' ).
    lo_database->execute( 'DELETE FROM items WHERE id BETWEEN 7000 AND 8500 AND id % 3 <> 0' ).
    lo_database->execute( 'DELETE FROM items WHERE id IN (1, 2, 3, 9999, 10000)' ).
    lo_database->execute( 'DELETE FROM items WHERE id = 123456' ).

    IF lo_database->last_insert_rowid( ) <> 10000.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'DELETE changed last_insert_rowid'.
    ENDIF.
    IF lo_database->changes( ) <> 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'DELETE without matches changed changes'.
    ENDIF.

    lo_database->close( ).
    rv_name = c_delete_database.
  ENDMETHOD.

  METHOD freelist_cycle.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_page     TYPE i.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_freelist_database ).

    lo_database = zcl_sqlite_database=>open( c_freelist_database ).
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

  METHOD drop_objects.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_from     TYPE i.
    DATA lv_to       TYPE i.
    DATA lv_id       TYPE i.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_drop_database ).

    lo_database = zcl_sqlite_database=>open( c_drop_database ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, body TEXT)' ).

    lv_from = 1.
    WHILE lv_from <= 600.
      lv_to = lv_from + 199.
      IF lv_to > 600.
        lv_to = 600.
      ENDIF.

      CLEAR lv_values.
      lv_id = lv_from.
      WHILE lv_id <= lv_to.
        IF lv_id > lv_from.
          lv_values = lv_values && ', '.
        ENDIF.
        lv_values = lv_values &&
          |({ lv_id }, 'name-{ lv_id }', 'body-{ lv_id }')|.
        lv_id = lv_id + 1.
      ENDWHILE.

      lo_database->execute( |INSERT INTO items VALUES { lv_values }| ).
      lv_from = lv_to + 1.
    ENDWHILE.

    lv_text = repeat( val = 'L'
                      occ = 9000 ).
    lo_database->execute( |INSERT INTO items VALUES (601, 'long', '{ lv_text }')| ).
    lo_database->execute( 'CREATE INDEX idx_body ON items (body)' ).
    lo_database->execute( 'CREATE INDEX idx_name ON items (name)' ).

    lo_database->execute( 'CREATE TABLE temp (id INTEGER PRIMARY KEY, value TEXT)' ).
    CLEAR lv_values.
    lv_id = 1.
    WHILE lv_id <= 200.
      IF lv_id > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values && |({ lv_id }, 'temp-{ lv_id }')|.
      lv_id = lv_id + 1.
    ENDWHILE.
    lo_database->execute( |INSERT INTO temp VALUES { lv_values }| ).
    lo_database->execute( 'CREATE INDEX temp_idx ON temp (value)' ).

    lo_database->execute( 'DROP INDEX idx_body' ).
    lo_database->execute( 'DROP TABLE temp' ).

    lo_database->close( ).
    rv_name = c_drop_database.
  ENDMETHOD.

  METHOD index_rows.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_from     TYPE i.
    DATA lv_to       TYPE i.
    DATA lv_id       TYPE i.
    DATA lv_values   TYPE string.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_index_database ).

    lo_database = zcl_sqlite_database=>open( c_index_database ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE,' &&
      ' qty INTEGER, tag TEXT)' ).

    lv_from = 1.
    WHILE lv_from <= 400.
      lv_to = lv_from + 199.
      IF lv_to > 400.
        lv_to = 400.
      ENDIF.

      CLEAR lv_values.
      lv_id = lv_from.
      WHILE lv_id <= lv_to.
        IF lv_id > lv_from.
          lv_values = lv_values && ', '.
        ENDIF.
        lv_values = lv_values &&
          |({ lv_id }, 'name-{ lv_id }', { lv_id * 7 MOD 23 }, 'tag-{ lv_id }')|.
        lv_id = lv_id + 1.
      ENDWHILE.

      lo_database->execute( |INSERT INTO items (id, name, qty, tag) VALUES { lv_values }| ).
      lv_from = lv_to + 1.
    ENDWHILE.

    lo_database->execute( 'CREATE INDEX idx_qty ON items (qty)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_tag ON items (tag)' ).
    lo_database->execute(
      'UPDATE items SET name = name || ''-u'', qty = qty + 1,' &&
      ' tag = tag || ''-u'' WHERE id % 7 = 0' ).
    lo_database->execute( 'UPDATE items SET id = id + 1000 WHERE id BETWEEN 50 AND 99' ).
    lo_database->execute( 'DELETE FROM items WHERE id % 11 = 0' ).
    lo_database->execute( 'DELETE FROM items WHERE id BETWEEN 200 AND 249' ).
    lo_database->execute( 'UPDATE items SET tag = NULL WHERE id % 13 = 0' ).

    CLEAR lv_values.
    lv_id = 401.
    WHILE lv_id <= 600.
      IF lv_id > 401.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ lv_id }, 'name-{ lv_id }', { lv_id * 5 MOD 17 }, 'tag-{ lv_id }')|.
      lv_id = lv_id + 1.
    ENDWHILE.
    lo_database->execute( |INSERT INTO items (id, name, qty, tag) VALUES { lv_values }| ).
    lo_database->execute(
      'INSERT INTO items VALUES (601, ''null-1'', NULL, NULL),' &&
      ' (602, ''null-2'', NULL, NULL)' ).
    lo_database->execute( 'UPDATE items SET qty = NULL WHERE id % 19 = 0' ).
    lo_database->execute( 'DELETE FROM items WHERE id BETWEEN 300 AND 329' ).
    lo_database->execute(
      'INSERT INTO items VALUES (603, ''name-603'', 9, ''tag-603''),' &&
      ' (604, ''name-604'', 9, ''tag-604'')' ).

    lo_database->close( ).
    rv_name = c_index_database.
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

  METHOD random_workload.
    CONSTANTS c_rounds TYPE i VALUE 12.
    CONSTANTS c_round_ops TYPE i VALUE 1000.
    CONSTANTS c_inserts TYPE i VALUE 20.
    CONSTANTS c_updates TYPE i VALUE 490.
    CONSTANTS c_deletes TYPE i VALUE 490.

    DATA lo_vfs         TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_checkpoint  TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database    TYPE REF TO zcl_sqlite_database.
    DATA lo_random      TYPE REF TO zcl_sqlite_random.
    DATA lv_round       TYPE i.
    DATA lv_row         TYPE i.
    DATA lv_op          TYPE i.
    DATA lv_inserts     TYPE i.
    DATA lv_id          TYPE i.
    DATA lv_qty         TYPE i.
    DATA lv_tag         TYPE i.
    DATA lv_delta       TYPE i.
    DATA lv_values      TYPE string.
    DATA lv_ids         TYPE string.
    DATA lv_sql         TYPE string.
    DATA lv_body        TYPE string.
    DATA lv_large_body  TYPE string.
    DATA lv_medium_body TYPE string.
    DATA lv_large_blob  TYPE string.
    DATA lv_export      TYPE xstring.
    DATA lv_name        TYPE string.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( c_random_database ).

    lo_database = zcl_sqlite_database=>open( c_random_database ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE,' &&
      ' qty INTEGER, tag TEXT)' ).
    lo_database->execute( 'CREATE INDEX idx_qty ON items (qty)' ).
    lo_database->execute( 'CREATE INDEX idx_tag ON items (tag)' ).
    lo_database->execute( 'CREATE INDEX idx_qty_tag ON items (qty, tag)' ).
    lo_database->execute(
      'CREATE TABLE payloads (id INTEGER PRIMARY KEY, item_id INTEGER,' &&
      ' body TEXT, bin BLOB)' ).

    lo_random = NEW zcl_sqlite_random( ).
    lv_large_body = repeat( val = 'A'
                            occ = 12000 ).
    lv_medium_body = repeat( val = 'B'
                             occ = 6000 ).
    lv_large_blob = repeat( val = 'DEADBEEF'
                            occ = 512 ).

    lv_sql = |INSERT INTO payloads (id, item_id, body, bin) VALUES | &&
      |(1, 1, '{ lv_large_body }', x'{ lv_large_blob }'), | &&
      |(2, 2, '{ lv_medium_body }', NULL), | &&
      |(3, 3, '{ lv_large_body }', x'{ lv_large_blob }'), | &&
      |(4, 4, '{ lv_medium_body }', NULL)|.
    lo_database->execute( lv_sql ).

    lo_database->execute( 'BEGIN' ).
    DO c_rounds TIMES.
      lv_round = sy-index.
      lv_op = lv_round * c_round_ops.

* 20 inserts, main table keeps only small cells
      CLEAR lv_values.
      lv_row = 1.
      WHILE lv_row <= c_inserts.
        lv_inserts = lv_inserts + 1.
        lv_id = 1 + ( lv_inserts * 7919 ) MOD 6000.
        lv_qty = lo_random->next( 1000 ).
        lv_tag = lo_random->next( 100 ).

        IF lv_row > 1.
          lv_values = lv_values && ', '.
        ENDIF.
        lv_values = lv_values &&
          |({ lv_id }, 'name-{ lv_id }', { lv_qty }, 'tag-{ lv_tag }')|.
        lv_row = lv_row + 1.
      ENDWHILE.
      lv_sql = |INSERT INTO items (id, name, qty, tag) VALUES { lv_values }|.
      lo_database->execute( lv_sql ).

* 490 updates, random row selection but one index rebuild per batch
      CLEAR lv_ids.
      lv_row = 1.
      WHILE lv_row <= c_updates.
        lv_id = 1 + lo_random->next( 6000 ).
        IF lv_row > 1.
          lv_ids = lv_ids && ', '.
        ENDIF.
        lv_ids = lv_ids && |{ lv_id }|.
        lv_row = lv_row + 1.
      ENDWHILE.
      lv_delta = lo_random->next( 1000 ) + 1.
      lv_tag = lo_random->next( 100 ).
      lv_sql = 'UPDATE items SET qty = qty + ' && |{ lv_delta }| &&
        ', tag = ''tag-' && |{ lv_tag }| &&
        ''', name = ''name-'' || id || ''-u' && |{ lv_round }| &&
        ''' WHERE id IN (' && lv_ids && ')'.
      lo_database->execute( lv_sql ).

* 490 deletes, also one index rebuild per batch
      CLEAR lv_ids.
      lv_row = 1.
      WHILE lv_row <= c_deletes.
        lv_id = 1 + lo_random->next( 6000 ).
        IF lv_row > 1.
          lv_ids = lv_ids && ', '.
        ENDIF.
        lv_ids = lv_ids && |{ lv_id }|.
        lv_row = lv_row + 1.
      ENDWHILE.
      lv_sql = |DELETE FROM items WHERE id IN ({ lv_ids })|.
      lo_database->execute( lv_sql ).

* overflow payloads live in their own small table so large cells never
* accumulate next to many small cells on one leaf page
      lv_id = ( ( lv_round - 1 ) MOD 4 ) + 1.
      IF lv_round MOD 2 = 0.
        lv_body = lv_large_body.
      ELSE.
        lv_body = lv_medium_body.
      ENDIF.
      lv_sql = |UPDATE payloads SET body = '{ lv_body }', bin = x'{ lv_large_blob }' WHERE id = { lv_id }|.
      lo_database->execute( lv_sql ).

      IF lv_op MOD c_random_checkpoint = 0.
        lo_database->execute( 'COMMIT' ).
* a fresh VFS instance is required to read blocks written by the
* database's own VFS instance, otherwise the checkpoint is stale
        lo_checkpoint = NEW zcl_sqlite_vfs_table( ).
        lv_export = lo_checkpoint->export( c_random_database ).
        lv_name = |compat/random-{ lv_op }.db|.
        lo_checkpoint->import(
          iv_name = lv_name
          iv_data = lv_export ).
        IF lv_round < c_rounds.
          lo_database->execute( 'BEGIN' ).
        ENDIF.
      ENDIF.
    ENDDO.

    lo_database->close( ).
    rv_name = c_random_database.
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

  METHOD update_rows.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_suffix   TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_from     TYPE i.
    DATA lv_to       TYPE i.
    DATA lv_id       TYPE i.
    DATA lv_text     TYPE string.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_update_database ).

    lo_database = zcl_sqlite_database=>open( c_update_database ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL,' &&
      ' amount REAL, note TEXT, bin BLOB)' ).

    lv_suffix = repeat( val = 'x'
                        occ = 40 ).
    lv_from = 1.
    WHILE lv_from <= 2000.
      lv_to = lv_from + 499.
      IF lv_to > 2000.
        lv_to = 2000.
      ENDIF.

      CLEAR lv_values.
      lv_id = lv_from.
      WHILE lv_id <= lv_to.
        IF lv_id > lv_from.
          lv_values = lv_values && ', '.
        ENDIF.
        lv_values = lv_values && |({ lv_id }, 'row-{ lv_id }-{ lv_suffix }', { lv_id })|.
        lv_id = lv_id + 1.
      ENDWHILE.

      lo_database->execute( |INSERT INTO items (id, name, amount) VALUES { lv_values }| ).
      lv_from = lv_to + 1.
    ENDWHILE.

    IF lo_database->last_insert_rowid( ) <> 2000.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'UPDATE corpus insert changed last_insert_rowid'.
    ENDIF.

    lo_database->execute(
      'UPDATE items SET name = name || ''-u'', amount = amount * 2,' &&
      ' note = ''n-'' || id WHERE id % 5 = 0' ).
    lo_database->execute( 'UPDATE items AS x SET amount = amount + x.id WHERE x.id BETWEEN 100 AND 199' ).
    lo_database->execute( 'UPDATE items SET note = ''first'', note = ''last'' WHERE id = 7' ).
    lo_database->execute( 'UPDATE items SET id = id + 10000 WHERE id BETWEEN 1 AND 100' ).
    lo_database->execute( 'UPDATE items SET id = id - 5000 WHERE id BETWEEN 10001 AND 10100' ).
    lo_database->execute( 'UPDATE items SET rowid = rowid + 20000 WHERE id BETWEEN 500 AND 599' ).
    lo_database->execute( 'UPDATE items SET oid = oid + 30000 WHERE id BETWEEN 600 AND 699' ).
    lo_database->execute( 'UPDATE items SET rowid = rowid WHERE id BETWEEN 1000 AND 1099' ).
    lo_database->execute( 'UPDATE items SET amount = amount WHERE id = 123456' ).

    IF lo_database->changes( ) <> 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'UPDATE without matches changed changes'.
    ENDIF.
    IF lo_database->last_insert_rowid( ) <> 2000.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'UPDATE changed last_insert_rowid'.
    ENDIF.

    lo_database->execute( 'UPDATE items SET name = ''all-'' || id' ).
    IF lo_database->changes( ) <> 2000.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'full UPDATE changed the wrong number of rows'.
    ENDIF.
    lo_database->execute( 'UPDATE items SET bin = x''DEADBEEF'' WHERE id % 7 = 0' ).
    lo_database->execute( 'UPDATE items SET bin = NULL WHERE id % 11 = 0' ).
    lo_database->execute( 'UPDATE items SET amount = 42 WHERE id BETWEEN 700 AND 799' ).

    lo_database->execute( 'CREATE TABLE payloads (id INTEGER PRIMARY KEY, label TEXT, body TEXT)' ).
    lv_text = repeat( val = 'A'
                      occ = 100 ).
    lv_values = |(1, 'small', '{ lv_text }')|.
    lv_text = repeat( val = 'B'
                      occ = 6000 ).
    lv_values = lv_values && |, (2, 'large', '{ lv_text }')|.
    lv_text = repeat( val = 'C'
                      occ = 12000 ).
    lv_values = lv_values && |, (3, 'huge', '{ lv_text }')|.
    lv_text = repeat( val = 'D'
                      occ = 200 ).
    lv_values = lv_values && |, (4, 'medium', '{ lv_text }')|.
    lo_database->execute( |INSERT INTO payloads VALUES { lv_values }| ).

    IF lo_database->last_insert_rowid( ) <> 4.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'payload insert changed last_insert_rowid'.
    ENDIF.

    lv_text = repeat( val = 'E'
                      occ = 12000 ).
    lo_database->execute( |UPDATE payloads SET body = '{ lv_text }' WHERE id = 1| ).
    lo_database->execute( 'UPDATE payloads SET body = ''tiny'' WHERE id = 2' ).
    lv_text = repeat( val = 'F'
                      occ = 6000 ).
    lo_database->execute( |UPDATE payloads SET body = '{ lv_text }' WHERE id = 3| ).
    lo_database->execute( 'UPDATE payloads SET body = body || body WHERE id = 4' ).
    lo_database->execute( 'UPDATE payloads SET id = id + 10' ).
    lo_database->execute( 'UPDATE payloads SET label = label || ''-u'' WHERE id % 2 = 0' ).

    IF lo_database->last_insert_rowid( ) <> 4.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'payload UPDATE changed last_insert_rowid'.
    ENDIF.

    lo_database->close( ).
    rv_name = c_update_database.
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
