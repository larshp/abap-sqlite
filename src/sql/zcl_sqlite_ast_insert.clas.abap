* An INSERT statement.
CLASS zcl_sqlite_ast_insert DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_upserts TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_upsert WITH DEFAULT KEY.
    TYPES ty_returning TYPE zcl_sqlite_ast_result_column=>ty_list.

    METHODS constructor
      IMPORTING iv_conflict       TYPE string OPTIONAL
                iv_table          TYPE string
                it_columns        TYPE zcl_sqlite_ast_node=>ty_names OPTIONAL
                io_values         TYPE REF TO zcl_sqlite_ast_values OPTIONAL
                io_select         TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_upserts        TYPE ty_upserts OPTIONAL
                it_returning      TYPE ty_returning OPTIONAL
                iv_default_values TYPE abap_bool DEFAULT abap_false.

    METHODS dump REDEFINITION.

    METHODS get_conflict
      RETURNING VALUE(rv_conflict) TYPE string.

    METHODS get_table
      RETURNING VALUE(rv_table) TYPE string.

    METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE zcl_sqlite_ast_node=>ty_names.

    METHODS get_values
      RETURNING VALUE(ro_values) TYPE REF TO zcl_sqlite_ast_values.

    METHODS get_select
      RETURNING VALUE(ro_select) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_upserts
      RETURNING VALUE(rt_upserts) TYPE ty_upserts.

    METHODS get_returning
      RETURNING VALUE(rt_returning) TYPE ty_returning.

    METHODS is_default_values
      RETURNING VALUE(rv_default_values) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mv_conflict       TYPE string.
    DATA mv_table          TYPE string.
    DATA mt_columns        TYPE zcl_sqlite_ast_node=>ty_names.
    DATA mo_values         TYPE REF TO zcl_sqlite_ast_values.
    DATA mo_select         TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_upserts        TYPE ty_upserts.
    DATA mt_returning      TYPE ty_returning.
    DATA mv_default_values TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_insert IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_conflict = iv_conflict.
    mv_table = iv_table.
    mt_columns = it_columns.
    mo_values = io_values.
    mo_select = io_select.
    mt_upserts = it_upserts.
    mt_returning = it_returning.
    mv_default_values = iv_default_values.
  ENDMETHOD.

  METHOD dump.
    rv_text = |INSERT |.
    IF mv_conflict IS NOT INITIAL.
      rv_text = rv_text && mv_conflict && | |.
    ENDIF.
    rv_text = rv_text && |INTO | && mv_table.
    IF lines( mt_columns ) > 0.
      rv_text = rv_text && | (| && join_names( mt_columns ) && |)|.
    ENDIF.

    IF mv_default_values = abap_true.
      rv_text = rv_text && | DEFAULT VALUES|.
    ELSEIF mo_values IS BOUND.
      rv_text = rv_text && | | && mo_values->dump( ).
    ELSEIF mo_select IS BOUND.
      rv_text = rv_text && | | && mo_select->dump( ).
    ENDIF.

    LOOP AT mt_upserts INTO DATA(lo_upsert).
      rv_text = rv_text && | | && lo_upsert->dump( ).
    ENDLOOP.

    IF lines( mt_returning ) > 0.
      rv_text = rv_text && | RETURNING |.
      LOOP AT mt_returning INTO DATA(lo_returning).
        IF sy-tabix > 1.
          rv_text = rv_text && |, |.
        ENDIF.
        rv_text = rv_text && lo_returning->dump( ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD get_conflict.
    rv_conflict = mv_conflict.
  ENDMETHOD.

  METHOD get_table.
    rv_table = mv_table.
  ENDMETHOD.

  METHOD get_columns.
    rt_columns = mt_columns.
  ENDMETHOD.

  METHOD get_values.
    ro_values = mo_values.
  ENDMETHOD.

  METHOD get_select.
    ro_select = mo_select.
  ENDMETHOD.

  METHOD get_upserts.
    rt_upserts = mt_upserts.
  ENDMETHOD.

  METHOD get_returning.
    rt_returning = mt_returning.
  ENDMETHOD.

  METHOD is_default_values.
    rv_default_values = mv_default_values.
  ENDMETHOD.

ENDCLASS.
