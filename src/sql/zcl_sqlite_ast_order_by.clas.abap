* An ORDER BY term.
CLASS zcl_sqlite_ast_order_by DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_order_by WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                iv_direction  TYPE string OPTIONAL
                iv_nulls      TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_direction
      RETURNING VALUE(rv_direction) TYPE string.

    METHODS get_nulls
      RETURNING VALUE(rv_nulls) TYPE string.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_direction  TYPE string.
    DATA mv_nulls      TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_order_by IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mo_expression = io_expression.
    mv_direction = iv_direction.
    mv_nulls = iv_nulls.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

  METHOD get_direction.
    rv_direction = mv_direction.
  ENDMETHOD.

  METHOD get_nulls.
    rv_nulls = mv_nulls.
  ENDMETHOD.

  METHOD dump.
    rv_text = mo_expression->dump( ).
    IF mv_direction IS NOT INITIAL.
      rv_text = rv_text && | | && mv_direction.
    ENDIF.
    IF mv_nulls IS NOT INITIAL.
      rv_text = rv_text && | NULLS | && mv_nulls.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
