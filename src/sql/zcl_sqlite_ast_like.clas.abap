* A LIKE or GLOB expression, optionally negated and with ESCAPE.
CLASS zcl_sqlite_ast_like DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                io_pattern    TYPE REF TO zcl_sqlite_ast_node
                iv_operator   TYPE string
                iv_negated    TYPE abap_bool DEFAULT abap_false
                io_escape     TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_pattern    TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_escape     TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_operator   TYPE string.
    DATA mv_negated    TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_like IMPLEMENTATION.

  METHOD constructor.
    mo_expression = io_expression.
    mo_pattern = io_pattern.
    mo_escape = io_escape.
    mv_operator = iv_operator.
    mv_negated = iv_negated.
  ENDMETHOD.

  METHOD dump.
    DATA lv_operator TYPE string.

    IF mv_negated = abap_true.
      lv_operator = |NOT_{ mv_operator }|.
    ELSE.
      lv_operator = mv_operator.
    ENDIF.

    rv_text = |{ lv_operator }({ mo_expression->dump( ) }, { mo_pattern->dump( ) }|.
    IF mo_escape IS BOUND.
      rv_text = rv_text && |, ESCAPE({ mo_escape->dump( ) })|.
    ENDIF.
    rv_text = rv_text && ')'.
  ENDMETHOD.

ENDCLASS.
