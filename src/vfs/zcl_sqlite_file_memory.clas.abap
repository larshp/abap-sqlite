* A handle for a file in ZCL_SQLITE_VFS_MEMORY. The bytes live in the VFS,
* so every handle for the same name sees the same data.
CLASS zcl_sqlite_file_memory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_file.

    METHODS constructor
      IMPORTING io_vfs  TYPE REF TO zcl_sqlite_vfs_memory
                iv_name TYPE string.

  PRIVATE SECTION.
    DATA mo_vfs TYPE REF TO zcl_sqlite_vfs_memory.
    DATA mv_name TYPE string.
ENDCLASS.


CLASS zcl_sqlite_file_memory IMPLEMENTATION.

  METHOD constructor.
    mo_vfs = io_vfs.
    mv_name = iv_name.
  ENDMETHOD.

  METHOD zif_sqlite_file~read.
    rs_result = mo_vfs->read_file(
      iv_name   = mv_name
      iv_offset = iv_offset
      iv_amount = iv_amount ).
  ENDMETHOD.

  METHOD zif_sqlite_file~write.
    mo_vfs->write_file(
      iv_name   = mv_name
      iv_offset = iv_offset
      iv_data   = iv_data ).
  ENDMETHOD.

  METHOD zif_sqlite_file~truncate.
    mo_vfs->truncate_file( iv_name = mv_name iv_size = iv_size ).
  ENDMETHOD.

  METHOD zif_sqlite_file~size.
    rv_size = mo_vfs->file_size( mv_name ).
  ENDMETHOD.

  METHOD zif_sqlite_file~sync.
  ENDMETHOD.

  METHOD zif_sqlite_file~lock.
  ENDMETHOD.

  METHOD zif_sqlite_file~unlock.
  ENDMETHOD.

  METHOD zif_sqlite_file~close.
  ENDMETHOD.

ENDCLASS.
