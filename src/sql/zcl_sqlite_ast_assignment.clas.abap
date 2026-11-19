* A column assignment in an UPDATE statement.
CLASS zcl_sqlite_ast_assignment DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_assignment WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING iv_column     TYPE string
                io_expression TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

    METHODS get_column
      RETURNING VALUE(rv_column) TYPE string.

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

  PRIVATE SECTION.
    DATA mv_column     TYPE string.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_assignment IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_column = iv_column.
    mo_expression = io_expression.
  ENDMETHOD.

  METHOD dump.
    rv_text = mv_column && | = | && mo_expression->dump( ).
  ENDMETHOD.

  METHOD get_column.
    rv_column = mv_column.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

ENDCLASS.
