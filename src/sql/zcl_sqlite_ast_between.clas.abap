* A BETWEEN expression, optionally negated.
CLASS zcl_sqlite_ast_between DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                io_low        TYPE REF TO zcl_sqlite_ast_node
                io_high       TYPE REF TO zcl_sqlite_ast_node
                iv_negated    TYPE abap_bool DEFAULT abap_false.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_low        TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_high       TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_negated    TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_between IMPLEMENTATION.

  METHOD constructor.
    mo_expression = io_expression.
    mo_low = io_low.
    mo_high = io_high.
    mv_negated = iv_negated.
  ENDMETHOD.

  METHOD dump.
    DATA lv_operator TYPE string.

    IF mv_negated = abap_true.
      lv_operator = 'NOT_BETWEEN'.
    ELSE.
      lv_operator = 'BETWEEN'.
    ENDIF.

    rv_text = |{ lv_operator }({ mo_expression->dump( ) }, { mo_low->dump( ) }, { mo_high->dump( ) })|.
  ENDMETHOD.

ENDCLASS.
