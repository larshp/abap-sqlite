* A prepared SQLite statement. Parameters are bound by one-based index or by
* name, then step( ) executes the statement or advances to the next result row.
INTERFACE zif_sqlite_statement
  PUBLIC.

  METHODS bind
    IMPORTING iv_index TYPE i OPTIONAL
              iv_name  TYPE string OPTIONAL
              io_value TYPE REF TO zcl_sqlite_value
    RAISING   zcx_sqlite_error.

  METHODS step
    RETURNING VALUE(rv_found) TYPE abap_bool
    RAISING   zcx_sqlite_error.

  METHODS column_count
    RETURNING VALUE(rv_count) TYPE i.

  METHODS column_name
    IMPORTING iv_index       TYPE i
    RETURNING VALUE(rv_name) TYPE string
    RAISING   zcx_sqlite_error.

  METHODS column_type
    IMPORTING iv_index       TYPE i
    RETURNING VALUE(rv_type) TYPE i
    RAISING   zcx_sqlite_error.

  METHODS column_value
    IMPORTING iv_index        TYPE i
    RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
    RAISING   zcx_sqlite_error.

  METHODS reset.

ENDINTERFACE.
