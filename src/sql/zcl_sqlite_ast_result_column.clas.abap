* A result column in a SELECT statement.
CLASS zcl_sqlite_ast_result_column DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_result_column WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
                iv_alias      TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_alias
      RETURNING VALUE(rv_alias) TYPE string.

  PRIVATE SECTION.
    DATA mo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_alias      TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_result_column IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mo_expression = io_expression.
    mv_alias = iv_alias.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

  METHOD get_alias.
    rv_alias = mv_alias.
  ENDMETHOD.

  METHOD dump.
    rv_text = mo_expression->dump( ).
    IF mv_alias IS NOT INITIAL.
      rv_text = rv_text && | AS | && mv_alias.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
