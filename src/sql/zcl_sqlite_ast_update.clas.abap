* An UPDATE statement.
CLASS zcl_sqlite_ast_update DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_assignments TYPE zcl_sqlite_ast_assignment=>ty_list.

    METHODS constructor
      IMPORTING iv_conflict    TYPE string OPTIONAL
                iv_table       TYPE string
                iv_alias       TYPE string OPTIONAL
                it_assignments TYPE ty_assignments
                it_from        TYPE zcl_sqlite_ast_node=>ty_nodes OPTIONAL
                io_where       TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_conflict
      RETURNING VALUE(rv_conflict) TYPE string.

    METHODS get_table
      RETURNING VALUE(rv_table) TYPE string.

    METHODS get_alias
      RETURNING VALUE(rv_alias) TYPE string.

    METHODS get_assignments
      RETURNING VALUE(rt_assignments) TYPE ty_assignments.

    METHODS get_from
      RETURNING VALUE(rt_from) TYPE zcl_sqlite_ast_node=>ty_nodes.

    METHODS get_where
      RETURNING VALUE(ro_where) TYPE REF TO zcl_sqlite_ast_node.

  PRIVATE SECTION.
    DATA mv_conflict    TYPE string.
    DATA mv_table       TYPE string.
    DATA mv_alias       TYPE string.
    DATA mt_assignments TYPE ty_assignments.
    DATA mt_from        TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA mo_where       TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump_assignments
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_update IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_conflict = iv_conflict.
    mv_table = iv_table.
    mv_alias = iv_alias.
    mt_assignments = it_assignments.
    mt_from = it_from.
    mo_where = io_where.
  ENDMETHOD.

  METHOD dump.
    rv_text = |UPDATE |.
    IF mv_conflict IS NOT INITIAL.
      rv_text = rv_text && mv_conflict && | |.
    ENDIF.
    rv_text = rv_text && mv_table.
    IF mv_alias IS NOT INITIAL.
      rv_text = rv_text && | AS | && mv_alias.
    ENDIF.
    rv_text = rv_text && | SET | && dump_assignments( ).

    IF lines( mt_from ) > 0.
      rv_text = rv_text && | FROM | && dump_nodes( mt_from ).
    ENDIF.
    IF mo_where IS BOUND.
      rv_text = rv_text && | WHERE | && mo_where->dump( ).
    ENDIF.
  ENDMETHOD.

  METHOD dump_assignments.
    DATA lo_assignment TYPE REF TO zcl_sqlite_ast_assignment.

    LOOP AT mt_assignments INTO lo_assignment.
      IF rv_text IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_assignment->dump( ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_conflict.
    rv_conflict = mv_conflict.
  ENDMETHOD.

  METHOD get_table.
    rv_table = mv_table.
  ENDMETHOD.

  METHOD get_alias.
    rv_alias = mv_alias.
  ENDMETHOD.

  METHOD get_assignments.
    rt_assignments = mt_assignments.
  ENDMETHOD.

  METHOD get_from.
    rt_from = mt_from.
  ENDMETHOD.

  METHOD get_where.
    ro_where = mo_where.
  ENDMETHOD.

ENDCLASS.
