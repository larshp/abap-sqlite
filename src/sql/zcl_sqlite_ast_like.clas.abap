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

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_pattern
      RETURNING VALUE(ro_pattern) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_escape
      RETURNING VALUE(ro_escape) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_operator
      RETURNING VALUE(rv_operator) TYPE string.

    METHODS is_negated
      RETURNING VALUE(rv_negated) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_pattern    TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_escape     TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_operator   TYPE string.
    DATA mv_negated    TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_like IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mo_expression = io_expression.
    mo_pattern = io_pattern.
    mo_escape = io_escape.
    mv_operator = iv_operator.
    mv_negated = iv_negated.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

  METHOD get_pattern.
    ro_pattern = mo_pattern.
  ENDMETHOD.

  METHOD get_escape.
    ro_escape = mo_escape.
  ENDMETHOD.

  METHOD get_operator.
    rv_operator = mv_operator.
  ENDMETHOD.

  METHOD is_negated.
    rv_negated = mv_negated.
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
