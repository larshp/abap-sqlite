INTERFACE zif_sqlite_vfs
  PUBLIC.

* A store of named files. open creates the file when it does not exist.
* delete of a missing file is a no-op. rename raises
* cx_sy_file_access_error when the source is missing or the target exists.

  METHODS open
    IMPORTING iv_name        TYPE string
    RETURNING VALUE(ro_file) TYPE REF TO zif_sqlite_file.

  METHODS exists
    IMPORTING iv_name          TYPE string
    RETURNING VALUE(rv_exists) TYPE abap_bool.

  METHODS delete
    IMPORTING iv_name TYPE string.

  METHODS list
    RETURNING VALUE(rt_names) TYPE string_table.

  METHODS rename
    IMPORTING iv_name     TYPE string
              iv_new_name TYPE string
    RAISING   cx_sy_file_access_error.

ENDINTERFACE.
