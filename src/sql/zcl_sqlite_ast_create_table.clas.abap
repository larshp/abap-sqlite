* A CREATE TABLE statement.
CLASS zcl_sqlite_ast_create_table DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_columns TYPE zcl_sqlite_ast_column_def=>ty_list.
    TYPES ty_constraints TYPE zcl_sqlite_ast_constraint=>ty_list.

    METHODS constructor
      IMPORTING iv_name          TYPE string
                iv_temporary     TYPE abap_bool DEFAULT abap_false
                iv_if_not_exists TYPE abap_bool DEFAULT abap_false
                it_columns       TYPE ty_columns OPTIONAL
                it_constraints   TYPE ty_constraints OPTIONAL
                iv_without_rowid TYPE abap_bool DEFAULT abap_false
                iv_strict        TYPE abap_bool DEFAULT abap_false.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS get_constraints
      RETURNING VALUE(rt_constraints) TYPE ty_constraints.

    METHODS is_if_not_exists
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_temporary
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_without_rowid
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_strict
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name          TYPE string.
    DATA mv_temporary     TYPE abap_bool.
    DATA mv_if_not_exists TYPE abap_bool.
    DATA mt_columns       TYPE ty_columns.
    DATA mt_constraints   TYPE ty_constraints.
    DATA mv_without_rowid TYPE abap_bool.
    DATA mv_strict        TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_create_table IMPLEMENTATION.

  METHOD constructor.
    mv_name = iv_name.
    mv_temporary = iv_temporary.
    mv_if_not_exists = iv_if_not_exists.
    mt_columns = it_columns.
    mt_constraints = it_constraints.
    mv_without_rowid = iv_without_rowid.
    mv_strict = iv_strict.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_columns.
    rt_columns = mt_columns.
  ENDMETHOD.

  METHOD get_constraints.
    rt_constraints = mt_constraints.
  ENDMETHOD.

  METHOD is_if_not_exists.
    rv_result = mv_if_not_exists.
  ENDMETHOD.

  METHOD is_temporary.
    rv_result = mv_temporary.
  ENDMETHOD.

  METHOD is_without_rowid.
    rv_result = mv_without_rowid.
  ENDMETHOD.

  METHOD is_strict.
    rv_result = mv_strict.
  ENDMETHOD.

  METHOD dump.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_column_def.
    DATA lo_constraint TYPE REF TO zcl_sqlite_ast_constraint.
    DATA lv_items TYPE string.
    DATA lv_options TYPE string.

    rv_text = |CREATE |.
    IF mv_temporary = abap_true.
      rv_text = rv_text && |TEMP |.
    ENDIF.
    rv_text = rv_text && |TABLE |.
    IF mv_if_not_exists = abap_true.
      rv_text = rv_text && |IF NOT EXISTS |.
    ENDIF.
    rv_text = rv_text && mv_name && | (|.

    LOOP AT mt_columns INTO lo_column.
      IF lv_items IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        lv_items = lv_items && |, |.
      ENDIF.
      lv_items = lv_items && lo_column->dump( ).
    ENDLOOP.
    LOOP AT mt_constraints INTO lo_constraint.
      IF lv_items IS NOT INITIAL.
        " ANORMALY: character literals lose trailing blanks when concatenated
        lv_items = lv_items && |, |.
      ENDIF.
      lv_items = lv_items && lo_constraint->dump( ).
    ENDLOOP.

    rv_text = rv_text && lv_items && |)|.

    IF mv_without_rowid = abap_true.
      lv_options = 'WITHOUT ROWID'.
    ENDIF.
    IF mv_strict = abap_true.
      IF lv_options IS INITIAL.
        lv_options = 'STRICT'.
      ELSE.
        lv_options = lv_options && |, | && 'STRICT'.
      ENDIF.
    ENDIF.
    IF lv_options IS NOT INITIAL.
      rv_text = rv_text && | | && lv_options.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
