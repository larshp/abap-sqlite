* A CASE expression. A bound base expression means a simple CASE;
* otherwise the WHEN conditions are searched CASE conditions.
CLASS zcl_sqlite_ast_case DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_when,
             condition TYPE REF TO zcl_sqlite_ast_node,
             result    TYPE REF TO zcl_sqlite_ast_node,
           END OF ty_when.
    TYPES ty_whens TYPE STANDARD TABLE OF ty_when WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING it_whens TYPE ty_whens
                io_base  TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_else  TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_base
      RETURNING VALUE(ro_base) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_whens
      RETURNING VALUE(rt_whens) TYPE ty_whens.

    METHODS get_else
      RETURNING VALUE(ro_else) TYPE REF TO zcl_sqlite_ast_node.

  PRIVATE SECTION.
    DATA mo_base  TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_whens TYPE ty_whens.
    DATA mo_else  TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_case IMPLEMENTATION.

  METHOD constructor.
    mo_base = io_base.
    mt_whens = it_whens.
    mo_else = io_else.
  ENDMETHOD.

  METHOD get_base.
    ro_base = mo_base.
  ENDMETHOD.

  METHOD get_whens.
    rt_whens = mt_whens.
  ENDMETHOD.

  METHOD get_else.
    ro_else = mo_else.
  ENDMETHOD.

  METHOD dump.
    DATA ls_when TYPE ty_when.
    DATA lv_prefix TYPE string.

    rv_text = 'CASE('.
    IF mo_base IS BOUND.
      rv_text = rv_text && mo_base->dump( ).
      " ANORMALY: character literals lose trailing blanks when concatenated
      lv_prefix = |, |.
    ENDIF.

    LOOP AT mt_whens INTO ls_when.
      rv_text = rv_text && lv_prefix
        && |WHEN({ ls_when-condition->dump( ) }, { ls_when-result->dump( ) })|.
      " ANORMALY: character literals lose trailing blanks when concatenated
      lv_prefix = |, |.
    ENDLOOP.

    IF mo_else IS BOUND.
      rv_text = rv_text && ', ELSE(' && mo_else->dump( ) && ')'.
    ENDIF.
    rv_text = rv_text && ')'.
  ENDMETHOD.

ENDCLASS.
