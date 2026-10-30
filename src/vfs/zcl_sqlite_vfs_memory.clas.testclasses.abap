CLASS ltcl_vfs_memory DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  INHERITING FROM zcl_sqlite_vfs_contract.

  PROTECTED SECTION.
    METHODS create_vfs REDEFINITION.

  PRIVATE SECTION.
    METHODS contract FOR TESTING.
ENDCLASS.


CLASS ltcl_vfs_memory IMPLEMENTATION.

  METHOD contract.
    run( ).
  ENDMETHOD.

  METHOD create_vfs.
    ro_vfs = NEW zcl_sqlite_vfs_memory( ).
  ENDMETHOD.

ENDCLASS.
