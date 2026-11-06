* Resolves column references while an expression is evaluated for one row.
INTERFACE zif_sqlite_eval_context
  PUBLIC.

  METHODS value_of
    IMPORTING iv_name         TYPE string
    RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
    RAISING   zcx_sqlite_error.

  METHODS aggregate
    IMPORTING io_function     TYPE REF TO zcl_sqlite_ast_function
    RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
    RAISING   zcx_sqlite_error.

ENDINTERFACE.
