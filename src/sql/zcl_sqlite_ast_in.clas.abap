* An IN list expression, optionally negated.
CLASS zcl_sqlite_ast_in DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                it_values     TYPE zcl_sqlite_ast_node=>ty_nodes OPTIONAL
                iv_negated    TYPE abap_bool DEFAULT abap_false
                io_select     TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_values     TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA mv_negated    TYPE abap_bool.
    DATA mo_select     TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_in IMPLEMENTATION.

  METHOD constructor.
    mo_expression = io_expression.
    mt_values = it_values.
    mv_negated = iv_negated.
    mo_select = io_select.
  ENDMETHOD.

  METHOD dump.
    DATA lv_operator TYPE string.
    DATA lv_values TYPE string.

    IF mv_negated = abap_true.
      lv_operator = 'NOT_IN'.
    ELSE.
      lv_operator = 'IN'.
    ENDIF.

    IF mo_select IS BOUND.
      lv_values = mo_select->dump( ).
    ELSE.
      lv_values = dump_nodes( mt_values ).
    ENDIF.
    rv_text = |{ lv_operator }({ mo_expression->dump( ) }|.
    IF lv_values IS NOT INITIAL.
      " ANORMALY: character literals lose trailing blanks when concatenated
      rv_text = rv_text && |, | && lv_values.
    ENDIF.
    rv_text = rv_text && ')'.
  ENDMETHOD.

ENDCLASS.
