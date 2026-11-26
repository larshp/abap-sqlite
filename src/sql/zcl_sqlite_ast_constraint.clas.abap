* A column or table constraint from a CREATE TABLE statement.
CLASS zcl_sqlite_ast_constraint DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_constraint WITH DEFAULT KEY.
    TYPES ty_indexed_columns TYPE zcl_sqlite_ast_indexed_column=>ty_list.

    TYPES: BEGIN OF ty_reference,
             table_name TYPE string,
             columns    TYPE zcl_sqlite_ast_node=>ty_names,
             on_delete  TYPE string,
             on_update  TYPE string,
             match_name TYPE string,
             deferrable TYPE string,
             initially  TYPE string,
           END OF ty_reference.

    METHODS constructor
      IMPORTING iv_kind            TYPE string
                iv_name            TYPE string OPTIONAL
                it_columns         TYPE zcl_sqlite_ast_node=>ty_names OPTIONAL
                it_indexed_columns TYPE ty_indexed_columns OPTIONAL
                io_expression      TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                iv_collation       TYPE string OPTIONAL
                iv_order           TYPE string OPTIONAL
                iv_conflict        TYPE string OPTIONAL
                iv_autoincrement   TYPE abap_bool DEFAULT abap_false
                iv_storage         TYPE string OPTIONAL
                is_reference       TYPE ty_reference OPTIONAL.

    METHODS get_kind
      RETURNING VALUE(rv_kind) TYPE string.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE zcl_sqlite_ast_node=>ty_names.

    METHODS get_indexed_columns
      RETURNING VALUE(rt_columns) TYPE ty_indexed_columns.

    METHODS get_expression
      RETURNING VALUE(ro_expression) TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_collation
      RETURNING VALUE(rv_collation) TYPE string.

    METHODS get_order
      RETURNING VALUE(rv_order) TYPE string.

    METHODS get_conflict
      RETURNING VALUE(rv_conflict) TYPE string.

    METHODS is_autoincrement
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS get_storage
      RETURNING VALUE(rv_storage) TYPE string.

    METHODS get_reference
      RETURNING VALUE(rs_reference) TYPE ty_reference.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_kind          TYPE string.
    DATA mv_name          TYPE string.
    DATA mt_columns       TYPE zcl_sqlite_ast_node=>ty_names.
    DATA mt_indexed_columns TYPE ty_indexed_columns.
    DATA mo_expression    TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_collation     TYPE string.
    DATA mv_order         TYPE string.
    DATA mv_conflict      TYPE string.
    DATA mv_autoincrement TYPE abap_bool.
    DATA mv_storage       TYPE string.
    DATA ms_reference     TYPE ty_reference.

    METHODS dump_indexed_columns
      RETURNING VALUE(rv_text) TYPE string.

    METHODS dump_reference
      RETURNING VALUE(rv_text) TYPE string.

    METHODS dump_reference_clauses
      RETURNING VALUE(rv_text) TYPE string.

    METHODS conflict_suffix
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_constraint IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_kind = iv_kind.
    mv_name = iv_name.
    mt_columns = it_columns.
    mt_indexed_columns = it_indexed_columns.
    mo_expression = io_expression.
    mv_collation = iv_collation.
    mv_order = iv_order.
    mv_conflict = iv_conflict.
    mv_autoincrement = iv_autoincrement.
    mv_storage = iv_storage.
    ms_reference = is_reference.
  ENDMETHOD.

  METHOD get_kind.
    rv_kind = mv_kind.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_columns.
    rt_columns = mt_columns.
  ENDMETHOD.

  METHOD get_indexed_columns.
    rt_columns = mt_indexed_columns.
  ENDMETHOD.

  METHOD get_expression.
    ro_expression = mo_expression.
  ENDMETHOD.

  METHOD get_collation.
    rv_collation = mv_collation.
  ENDMETHOD.

  METHOD get_order.
    rv_order = mv_order.
  ENDMETHOD.

  METHOD get_conflict.
    rv_conflict = mv_conflict.
  ENDMETHOD.

  METHOD is_autoincrement.
    rv_result = mv_autoincrement.
  ENDMETHOD.

  METHOD get_storage.
    rv_storage = mv_storage.
  ENDMETHOD.

  METHOD get_reference.
    rs_reference = ms_reference.
  ENDMETHOD.

  METHOD dump.
    DATA lv_body TYPE string.

    CASE mv_kind.
      WHEN 'PRIMARY KEY'.
        lv_body = 'PRIMARY KEY'.
        IF lines( mt_indexed_columns ) > 0.
          lv_body = lv_body && | (| && dump_indexed_columns( ) && |)|.
        ELSEIF mv_order IS NOT INITIAL.
          lv_body = lv_body && | | && mv_order.
        ENDIF.
        lv_body = lv_body && conflict_suffix( ).
        IF mv_autoincrement = abap_true.
          lv_body = lv_body && | AUTOINCREMENT|.
        ENDIF.
      WHEN 'NOT NULL'.
        lv_body = 'NOT NULL' && conflict_suffix( ).
      WHEN 'UNIQUE'.
        lv_body = 'UNIQUE'.
        IF lines( mt_indexed_columns ) > 0.
          lv_body = lv_body && | (| && dump_indexed_columns( ) && |)|.
        ENDIF.
        lv_body = lv_body && conflict_suffix( ).
      WHEN 'CHECK'.
        lv_body = |CHECK({ mo_expression->dump( ) })|.
      WHEN 'DEFAULT'.
        lv_body = |DEFAULT({ mo_expression->dump( ) })|.
      WHEN 'COLLATE'.
        lv_body = |COLLATE { mv_collation }|.
      WHEN 'REFERENCES'.
        lv_body = |REFERENCES { dump_reference( ) }{ dump_reference_clauses( ) }|.
      WHEN 'FOREIGN KEY'.
        lv_body = |FOREIGN KEY ({ join_names( mt_columns ) }) REFERENCES { dump_reference( ) }|.
        lv_body = lv_body && dump_reference_clauses( ).
      WHEN 'GENERATED'.
        lv_body = |GENERATED ALWAYS AS ({ mo_expression->dump( ) })|.
        IF mv_storage IS NOT INITIAL.
          lv_body = lv_body && | | && mv_storage.
        ENDIF.
      WHEN OTHERS.
        lv_body = mv_kind.
    ENDCASE.

    IF mv_name IS NOT INITIAL.
      rv_text = |CONSTRAINT { mv_name } { lv_body }|.
    ELSE.
      rv_text = lv_body.
    ENDIF.
  ENDMETHOD.

  METHOD dump_indexed_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.

    LOOP AT mt_indexed_columns INTO lo_column.
      IF rv_text IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_column->dump( ).
    ENDLOOP.
  ENDMETHOD.

  METHOD dump_reference.
    rv_text = ms_reference-table_name.
    IF lines( ms_reference-columns ) > 0.
      rv_text = rv_text && | (| && join_names( ms_reference-columns ) && |)|.
    ENDIF.
  ENDMETHOD.

  METHOD dump_reference_clauses.
    IF ms_reference-on_delete IS NOT INITIAL.
      rv_text = rv_text && | ON DELETE | && ms_reference-on_delete.
    ENDIF.
    IF ms_reference-on_update IS NOT INITIAL.
      rv_text = rv_text && | ON UPDATE | && ms_reference-on_update.
    ENDIF.
    IF ms_reference-match_name IS NOT INITIAL.
      rv_text = rv_text && | MATCH | && ms_reference-match_name.
    ENDIF.
    IF ms_reference-deferrable IS NOT INITIAL.
      rv_text = rv_text && | | && ms_reference-deferrable.
    ENDIF.
    IF ms_reference-initially IS NOT INITIAL.
      rv_text = rv_text && | INITIALLY | && ms_reference-initially.
    ENDIF.
  ENDMETHOD.

  METHOD conflict_suffix.
    IF mv_conflict IS NOT INITIAL.
      rv_text = | ON CONFLICT { mv_conflict }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
