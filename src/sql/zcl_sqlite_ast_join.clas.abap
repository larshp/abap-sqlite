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
                it_using     TYPE ty_using OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_join_type TYPE string.
    DATA mo_left      TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_right     TYPE REF TO zcl_sqlite_ast_node.
    DATA mo_on        TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_using     TYPE ty_using.

ENDCLASS.


CLASS zcl_sqlite_ast_join IMPLEMENTATION.

  METHOD constructor.
    mv_join_type = iv_join_type.
    mo_left = io_left.
    mo_right = io_right.
    mo_on = io_on.
    mt_using = it_using.
  ENDMETHOD.

  METHOD dump.
    rv_text = mo_left->dump( ) && | | && mv_join_type && | | && mo_right->dump( ).
    IF mo_on IS BOUND.
      rv_text = rv_text && | ON | && mo_on->dump( ).
    ELSEIF lines( mt_using ) > 0.
      rv_text = rv_text && | USING (| && join_names( mt_using ) && |)|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
