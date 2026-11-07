* A function call, optionally with DISTINCT or a star argument.
CLASS zcl_sqlite_ast_function DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_name      TYPE string
                iv_distinct  TYPE abap_bool DEFAULT abap_false
                iv_star      TYPE abap_bool DEFAULT abap_false
                it_arguments TYPE zcl_sqlite_ast_node=>ty_nodes OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_distinct
      RETURNING VALUE(rv_distinct) TYPE abap_bool.

    METHODS get_star
      RETURNING VALUE(rv_star) TYPE abap_bool.

    METHODS get_arguments
      RETURNING VALUE(rt_arguments) TYPE zcl_sqlite_ast_node=>ty_nodes.

  PRIVATE SECTION.
    DATA mv_name      TYPE string.
    DATA mv_distinct  TYPE abap_bool.
    DATA mv_star      TYPE abap_bool.
    DATA mt_arguments TYPE zcl_sqlite_ast_node=>ty_nodes.

ENDCLASS.


CLASS zcl_sqlite_ast_function IMPLEMENTATION.

  METHOD constructor.
    mv_name = iv_name.
    mv_distinct = iv_distinct.
    mv_star = iv_star.
    mt_arguments = it_arguments.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_distinct.
    rv_distinct = mv_distinct.
  ENDMETHOD.

  METHOD get_star.
    rv_star = mv_star.
  ENDMETHOD.

  METHOD get_arguments.
    rt_arguments = mt_arguments.
  ENDMETHOD.

  METHOD dump.
    rv_text = |FUNCTION({ mv_name }|.
    IF mv_distinct = abap_true.
      rv_text = rv_text && ', DISTINCT'.
    ENDIF.
    IF mv_star = abap_true.
      rv_text = rv_text && ', STAR'.
    ELSEIF lines( mt_arguments ) > 0.
      " ANORMALY: character literals lose trailing blanks when concatenated
      rv_text = rv_text && |, | && dump_nodes( mt_arguments ).
    ENDIF.
    rv_text = rv_text && ')'.
  ENDMETHOD.

ENDCLASS.
