* Scenario programs for the sql.js compatibility verifier. The verifier runs
* these through the transpiled ABAP runtime, then reads the ZSQLITE_FILES rows
* from the transpiler's SQLite connection.
CLASS zcl_sqlite_scenario DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_empty_database TYPE string VALUE 'compat/empty.db'.

    CLASS-METHODS create_empty
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

ENDCLASS.
