* Pull-based query operator. open( ) prepares the operator, next( ) advances
* to the next row and row( ) exposes the current one.
INTERFACE zif_sqlite_operator
  PUBLIC.

  METHODS open
    RAISING zcx_sqlite_error.

  METHODS next
    RETURNING VALUE(rv_found) TYPE abap_bool
    RAISING   zcx_sqlite_error.

  METHODS row
    RETURNING VALUE(ro_row) TYPE REF TO zcl_sqlite_row.

ENDINTERFACE.
