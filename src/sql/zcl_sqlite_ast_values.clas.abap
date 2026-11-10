* A VALUES statement.
CLASS zcl_sqlite_ast_values DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_rows TYPE zcl_sqlite_ast_values_row=>ty_list.
    TYPES ty_order_by TYPE zcl_sqlite_ast_order_by=>ty_list.

    METHODS constructor
      IMPORTING it_rows     TYPE ty_rows
                it_order_by TYPE ty_order_by OPTIONAL
                io_limit    TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset   TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS with_tail
      IMPORTING it_order_by      TYPE ty_order_by OPTIONAL
                io_limit         TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset        TYPE REF TO zcl_sqlite_ast_node OPTIONAL
      RETURNING VALUE(ro_values) TYPE REF TO zcl_sqlite_ast_values.

    METHODS get_rows
      RETURNING VALUE(rt_rows) TYPE ty_rows.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mt_rows     TYPE ty_rows.
    DATA mt_order_by TYPE ty_order_by.
    DATA mo_limit    TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_offset   TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump_order_by
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_values IMPLEMENTATION.

  METHOD constructor.
    mt_rows = it_rows.
    mt_order_by = it_order_by.
    mo_limit = io_limit.
    mo_offset = io_offset.
  ENDMETHOD.

  METHOD with_tail.
    ro_values = NEW zcl_sqlite_ast_values(
      it_rows     = mt_rows
      it_order_by = it_order_by
      io_limit    = io_limit
      io_offset   = io_offset ).
  ENDMETHOD.

  METHOD get_rows.
    rt_rows = mt_rows.
  ENDMETHOD.

  METHOD dump.
    DATA lo_row TYPE REF TO zcl_sqlite_ast_values_row.

    rv_text = |VALUES |.
    LOOP AT mt_rows INTO lo_row.
      IF rv_text <> |VALUES |.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_row->dump( ).
    ENDLOOP.

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
