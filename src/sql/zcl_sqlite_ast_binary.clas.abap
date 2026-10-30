* A binary expression. Operators are normalized to upper case keywords or
* their original operator spelling.
CLASS zcl_sqlite_ast_binary DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_operator TYPE string
                io_left     TYPE REF TO zcl_sqlite_ast_node
                io_right    TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_operator TYPE string.
    DATA mo_left     TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_right    TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_binary IMPLEMENTATION.

  METHOD constructor.
    mv_operator = iv_operator.
    mo_left = io_left.
    mo_right = io_right.
  ENDMETHOD.

  METHOD dump.
    rv_text = |BINARY({ mv_operator }, { mo_left->dump( ) }, { mo_right->dump( ) })|.
  ENDMETHOD.

ENDCLASS.
