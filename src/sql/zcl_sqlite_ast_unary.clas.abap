* A unary expression such as NOT x, -x, x ISNULL or x NOTNULL.
CLASS zcl_sqlite_ast_unary DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_operator TYPE string
                io_operand  TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_operator TYPE string.
    DATA mo_operand  TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_unary IMPLEMENTATION.

  METHOD constructor.
    mv_operator = iv_operator.
    mo_operand = io_operand.
  ENDMETHOD.

  METHOD dump.
    rv_text = |UNARY({ mv_operator }, { mo_operand->dump( ) })|.
  ENDMETHOD.

ENDCLASS.
