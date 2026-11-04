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

    METHODS get_operator
      RETURNING VALUE(rv_operator) TYPE string.

    METHODS get_left
      RETURNING VALUE(ro_left) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_right
      RETURNING VALUE(ro_right) TYPE REF TO zcl_sqlite_ast_node.

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

  METHOD get_operator.
    rv_operator = mv_operator.
  ENDMETHOD.

  METHOD get_left.
    ro_left = mo_left.
  ENDMETHOD.

  METHOD get_right.
    ro_right = mo_right.
  ENDMETHOD.

  METHOD dump.
    rv_text = |BINARY({ mv_operator }, { mo_left->dump( ) }, { mo_right->dump( ) })|.
  ENDMETHOD.

ENDCLASS.
