* A subquery used as an expression.
CLASS zcl_sqlite_ast_subquery DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_statement TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_subquery IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mo_statement = io_statement.
  ENDMETHOD.

  METHOD dump.
    rv_text = |SUBQUERY(| && mo_statement->dump( ) && |)|.
  ENDMETHOD.

ENDCLASS.
