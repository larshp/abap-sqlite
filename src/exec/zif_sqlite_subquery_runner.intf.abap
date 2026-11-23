* Executes a SELECT that appears inside another SELECT.
INTERFACE zif_sqlite_subquery_runner
  PUBLIC.

  TYPES ty_column_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
  TYPES ty_row TYPE zcl_sqlite_record=>ty_values.
  TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.

  TYPES: BEGIN OF ty_result,
           columns TYPE ty_column_names,
           rows    TYPE ty_rows,
         END OF ty_result.

  METHODS run
    IMPORTING io_statement     TYPE REF TO zcl_sqlite_ast_node
              io_outer         TYPE REF TO zif_sqlite_eval_context OPTIONAL
    RETURNING VALUE(rs_result) TYPE ty_result
    RAISING   zcx_sqlite_error.

ENDINTERFACE.
