* A parenthesized select used in FROM or as a compound operand.
CLASS zcl_sqlite_ast_subquery_ref DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_node
                iv_alias     TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_statement TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_alias     TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_subquery_ref IMPLEMENTATION.

  METHOD constructor.
    mo_statement = io_statement.
    mv_alias = iv_alias.
  ENDMETHOD.

  METHOD dump.
    rv_text = |(| && mo_statement->dump( ) && |)|.
    IF mv_alias IS NOT INITIAL.
      rv_text = rv_text && | AS | && mv_alias.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
