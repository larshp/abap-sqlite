* A column definition inside a CREATE TABLE statement.
CLASS zcl_sqlite_ast_column_def DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_column_def WITH DEFAULT KEY.
    TYPES ty_constraints TYPE zcl_sqlite_ast_constraint=>ty_list.

    METHODS constructor
      IMPORTING iv_name        TYPE string
                iv_type_name   TYPE string OPTIONAL
                it_constraints TYPE ty_constraints OPTIONAL.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_type_name
      RETURNING VALUE(rv_type_name) TYPE string.

    METHODS get_constraints
      RETURNING VALUE(rt_constraints) TYPE ty_constraints.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name        TYPE string.
    DATA mv_type_name   TYPE string.
    DATA mt_constraints TYPE ty_constraints.

ENDCLASS.


CLASS zcl_sqlite_ast_column_def IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_name = iv_name.
    mv_type_name = iv_type_name.
    mt_constraints = it_constraints.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_type_name.
    rv_type_name = mv_type_name.
  ENDMETHOD.

  METHOD get_constraints.
    rt_constraints = mt_constraints.
  ENDMETHOD.

  METHOD dump.
    DATA lo_constraint TYPE REF TO zcl_sqlite_ast_constraint.

    rv_text = mv_name.
    IF mv_type_name IS NOT INITIAL.
      rv_text = rv_text && | | && mv_type_name.
    ENDIF.
    LOOP AT mt_constraints INTO lo_constraint.
      rv_text = rv_text && | | && lo_constraint->dump( ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
