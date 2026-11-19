* A WITH clause with one or more common table expressions.
CLASS zcl_sqlite_ast_with DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_ctes TYPE zcl_sqlite_ast_cte=>ty_list.

    METHODS constructor
      IMPORTING iv_recursive TYPE abap_bool DEFAULT abap_false
                it_ctes      TYPE ty_ctes
                io_statement TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_recursive TYPE abap_bool.
    DATA mt_ctes      TYPE ty_ctes.
    DATA mo_statement TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump_ctes
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_with IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_recursive = iv_recursive.
    mt_ctes = it_ctes.
    mo_statement = io_statement.
  ENDMETHOD.

  METHOD dump.
    rv_text = |WITH |.
    IF mv_recursive = abap_true.
      rv_text = rv_text && |RECURSIVE |.
    ENDIF.
    rv_text = rv_text && dump_ctes( ) && | | && mo_statement->dump( ).
  ENDMETHOD.

  METHOD dump_ctes.
    DATA lo_cte TYPE REF TO zcl_sqlite_ast_cte.

    LOOP AT mt_ctes INTO lo_cte.
      IF rv_text IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_cte->dump( ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
