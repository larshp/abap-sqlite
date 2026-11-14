* A join between two FROM items.
CLASS zcl_sqlite_ast_join DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_using TYPE zcl_sqlite_ast_node=>ty_names.

    METHODS constructor
      IMPORTING iv_join_type TYPE string
                io_left      TYPE REF TO zcl_sqlite_ast_node
                io_right     TYPE REF TO zcl_sqlite_ast_node
                io_on        TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_using     TYPE ty_using OPTIONAL
                iv_natural   TYPE abap_bool DEFAULT abap_false.

    METHODS dump REDEFINITION.

    METHODS get_join_type
      RETURNING VALUE(rv_join_type) TYPE string.

    METHODS get_left
      RETURNING VALUE(ro_left) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_right
      RETURNING VALUE(ro_right) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_on
      RETURNING VALUE(ro_on) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_using
      RETURNING VALUE(rt_using) TYPE ty_using.

    METHODS is_natural
      RETURNING VALUE(rv_natural) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mv_join_type TYPE string.
    DATA mo_left      TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_right     TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_on        TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_using     TYPE ty_using.
    DATA mv_natural   TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_join IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_join_type = iv_join_type.
    mo_left = io_left.
    mo_right = io_right.
    mo_on = io_on.
    mt_using = it_using.
    mv_natural = iv_natural.
  ENDMETHOD.

  METHOD dump.
    rv_text = mo_left->dump( ) && | |.
    IF mv_natural = abap_true.
      rv_text = rv_text && |NATURAL |.
    ENDIF.
    rv_text = rv_text && mv_join_type && | | && mo_right->dump( ).
    IF mo_on IS BOUND.
      rv_text = rv_text && | ON | && mo_on->dump( ).
    ELSEIF lines( mt_using ) > 0.
      rv_text = rv_text && | USING (| && join_names( mt_using ) && |)|.
    ENDIF.
  ENDMETHOD.

  METHOD get_join_type.
    rv_join_type = mv_join_type.
  ENDMETHOD.

  METHOD get_left.
    ro_left = mo_left.
  ENDMETHOD.

  METHOD get_right.
    ro_right = mo_right.
  ENDMETHOD.

  METHOD get_on.
    ro_on = mo_on.
  ENDMETHOD.

  METHOD get_using.
    rt_using = mt_using.
  ENDMETHOD.

  METHOD is_natural.
    rv_natural = mv_natural.
  ENDMETHOD.

ENDCLASS.
