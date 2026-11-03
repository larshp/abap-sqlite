* An EXPLAIN or EXPLAIN QUERY PLAN statement.
CLASS zcl_sqlite_ast_explain DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_query_plan TYPE abap_bool DEFAULT abap_false
                io_statement  TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_query_plan TYPE abap_bool.
    DATA mo_statement  TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_explain IMPLEMENTATION.

  METHOD constructor.
    mv_query_plan = iv_query_plan.
    mo_statement = io_statement.
  ENDMETHOD.

  METHOD dump.
    rv_text = |EXPLAIN |.
    IF mv_query_plan = abap_true.
      rv_text = rv_text && |QUERY PLAN |.
    ENDIF.
    rv_text = rv_text && mo_statement->dump( ).
  ENDMETHOD.

ENDCLASS.
