* A compound SELECT statement such as SELECT ... UNION SELECT ....
CLASS zcl_sqlite_ast_compound DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_order_by TYPE zcl_sqlite_ast_order_by=>ty_list.

    METHODS constructor
      IMPORTING io_left     TYPE REF TO zcl_sqlite_ast_node
                iv_operator TYPE string
                iv_all      TYPE abap_bool DEFAULT abap_false
                io_right    TYPE REF TO zcl_sqlite_ast_node
                it_order_by TYPE ty_order_by OPTIONAL
                io_limit    TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset   TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS with_tail
      IMPORTING it_order_by        TYPE ty_order_by OPTIONAL
                io_limit           TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                io_offset          TYPE REF TO zcl_sqlite_ast_node OPTIONAL
      RETURNING VALUE(ro_compound) TYPE REF TO zcl_sqlite_ast_compound.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mo_left     TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_operator TYPE string.
    DATA mv_all      TYPE abap_bool.
    DATA mo_right    TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_order_by TYPE ty_order_by.
    DATA mo_limit    TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_offset   TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump_order_by
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_compound IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mo_left = io_left.
    mv_operator = iv_operator.
    mv_all = iv_all.
    mo_right = io_right.
    mt_order_by = it_order_by.
    mo_limit = io_limit.
    mo_offset = io_offset.
  ENDMETHOD.

  METHOD with_tail.
    ro_compound = NEW zcl_sqlite_ast_compound(
      io_left     = mo_left
      iv_operator = mv_operator
      iv_all      = mv_all
      io_right    = mo_right
      it_order_by = it_order_by
      io_limit    = io_limit
      io_offset   = io_offset ).
  ENDMETHOD.

  METHOD dump.
    rv_text = mo_left->dump( ) && | | && mv_operator.
    IF mv_all = abap_true.
      rv_text = rv_text && | ALL|.
    ENDIF.
    rv_text = rv_text && | | && mo_right->dump( ).
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
