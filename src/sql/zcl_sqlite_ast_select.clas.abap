* A SELECT statement.
CLASS zcl_sqlite_ast_select DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_columns TYPE zcl_sqlite_ast_result_column=>ty_list.
    TYPES ty_expressions TYPE zcl_sqlite_ast_node=>ty_nodes.
    TYPES ty_from TYPE zcl_sqlite_ast_node=>ty_nodes.
    TYPES ty_order_by TYPE zcl_sqlite_ast_order_by=>ty_list.

    METHODS constructor
      IMPORTING iv_distinct TYPE abap_bool DEFAULT abap_false
                it_columns  TYPE ty_columns OPTIONAL
                it_from     TYPE ty_from OPTIONAL
                io_where    TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_group_by TYPE ty_expressions OPTIONAL
                io_having   TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_order_by TYPE ty_order_by OPTIONAL
                io_limit    TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset   TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS get_distinct
      RETURNING VALUE(rv_distinct) TYPE abap_bool.

    METHODS get_from
      RETURNING VALUE(rt_from) TYPE ty_from.

    METHODS get_where
      RETURNING VALUE(ro_where) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_group_by
      RETURNING VALUE(rt_group_by) TYPE ty_expressions.

    METHODS get_having
      RETURNING VALUE(ro_having) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_order_by
      RETURNING VALUE(rt_order_by) TYPE ty_order_by.

    METHODS get_limit
      RETURNING VALUE(ro_limit) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_offset
      RETURNING VALUE(ro_offset) TYPE REF TO zcl_sqlite_ast_node.

    METHODS with_tail
      IMPORTING it_order_by      TYPE ty_order_by OPTIONAL
                io_limit         TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset        TYPE REF TO zcl_sqlite_ast_node OPTIONAL
      RETURNING VALUE(ro_select) TYPE REF TO zcl_sqlite_ast_select.

  PRIVATE SECTION.
    DATA mv_distinct TYPE abap_bool.
    DATA mt_columns  TYPE ty_columns.
    DATA mt_from     TYPE ty_from.
    DATA mo_where    TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_group_by TYPE ty_expressions.
    DATA mo_having   TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_order_by TYPE ty_order_by.
    DATA mo_limit    TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_offset   TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump_result_columns
      RETURNING VALUE(rv_text) TYPE string.

    METHODS dump_order_by
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_select IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_distinct = iv_distinct.
    mt_columns = it_columns.
    mt_from = it_from.
    mo_where = io_where.
    mt_group_by = it_group_by.
    mo_having = io_having.
    mt_order_by = it_order_by.
    mo_limit = io_limit.
    mo_offset = io_offset.
  ENDMETHOD.

  METHOD get_columns.
    rt_columns = mt_columns.
  ENDMETHOD.

  METHOD get_distinct.
    rv_distinct = mv_distinct.
  ENDMETHOD.

  METHOD get_from.
    rt_from = mt_from.
  ENDMETHOD.

  METHOD get_where.
    ro_where = mo_where.
  ENDMETHOD.

  METHOD get_group_by.
    rt_group_by = mt_group_by.
  ENDMETHOD.

  METHOD get_having.
    ro_having = mo_having.
  ENDMETHOD.

  METHOD get_order_by.
    rt_order_by = mt_order_by.
  ENDMETHOD.

  METHOD get_limit.
    ro_limit = mo_limit.
  ENDMETHOD.

  METHOD get_offset.
    ro_offset = mo_offset.
  ENDMETHOD.

  METHOD with_tail.
    ro_select = NEW zcl_sqlite_ast_select(
      iv_distinct = mv_distinct
      it_columns  = mt_columns
      it_from     = mt_from
      io_where    = mo_where
      it_group_by = mt_group_by
      io_having   = mo_having
      it_order_by = it_order_by
      io_limit    = io_limit
      io_offset   = io_offset ).
  ENDMETHOD.

  METHOD dump.
    rv_text = |SELECT |.
    IF mv_distinct = abap_true.
      rv_text = rv_text && |DISTINCT |.
    ENDIF.
    rv_text = rv_text && dump_result_columns( ).

    IF lines( mt_from ) > 0.
      rv_text = rv_text && | FROM | && dump_nodes( mt_from ).
    ENDIF.
    IF mo_where IS BOUND.
      rv_text = rv_text && | WHERE | && mo_where->dump( ).
    ENDIF.
    IF lines( mt_group_by ) > 0.
      rv_text = rv_text && | GROUP BY | && dump_nodes( mt_group_by ).
    ENDIF.
    IF mo_having IS BOUND.
      rv_text = rv_text && | HAVING | && mo_having->dump( ).
    ENDIF.
    IF lines( mt_order_by ) > 0.
      rv_text = rv_text && | ORDER BY | && dump_order_by( ).
    ENDIF.
    IF mo_limit IS BOUND.
      rv_text = rv_text && | LIMIT | && mo_limit->dump( ).
    ENDIF.
    IF mo_offset IS BOUND.
      rv_text = rv_text && | OFFSET | && mo_offset->dump( ).
    ENDIF.
  ENDMETHOD.

  METHOD dump_result_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_result_column.

    LOOP AT mt_columns INTO lo_column.
      IF rv_text IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_column->dump( ).
    ENDLOOP.
  ENDMETHOD.

  METHOD dump_order_by.
    DATA lo_order_by TYPE REF TO zcl_sqlite_ast_order_by.

    LOOP AT mt_order_by INTO lo_order_by.
      IF rv_text IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_order_by->dump( ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
