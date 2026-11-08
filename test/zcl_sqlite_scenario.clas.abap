* Scenario programs for the sql.js compatibility verifier. The verifier runs
* these through the transpiled ABAP runtime, then reads the ZSQLITE_FILES rows
* from the transpiler's SQLite connection.
CLASS zcl_sqlite_scenario DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_empty_database TYPE string VALUE 'compat/empty.db'.
    CONSTANTS c_freelist_database TYPE string VALUE 'compat/freelist.db'.

    CLASS-METHODS create_empty
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS freelist_cycle
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_scenario IMPLEMENTATION.

  METHOD create_empty.
    DATA lo_vfs      TYPE REF TO zif_sqlite_vfs.
    DATA lo_database TYPE REF TO zcl_sqlite_database.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->delete( c_empty_database ).

    lo_database = zcl_sqlite_database=>create( c_empty_database ).
    lo_database->close( ).

    rv_name = c_empty_database.
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

ENDCLASS.
