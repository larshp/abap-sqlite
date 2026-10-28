CLASS ltcl_vfs_table DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  INHERITING FROM zcl_sqlite_vfs_contract.

  PROTECTED SECTION.
    METHODS create_vfs REDEFINITION.

  PRIVATE SECTION.
    METHODS contract FOR TESTING.
    METHODS teardown.
    METHODS cleanup.
ENDCLASS.


CLASS ltcl_vfs_table IMPLEMENTATION.

  METHOD contract.
    run( ).
  ENDMETHOD.

  METHOD create_vfs.
    cleanup( ).
    ro_vfs = NEW zcl_sqlite_vfs_table( ).
  ENDMETHOD.

  METHOD teardown.
    cleanup( ).
    COMMIT WORK.
  ENDMETHOD.

  METHOD cleanup.
    DELETE FROM zsqlite_files WHERE mandt = @sy-mandt.
  ENDMETHOD.

ENDCLASS.
