* A CREATE VIEW statement.
CLASS zcl_sqlite_ast_create_view DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_columns TYPE zcl_sqlite_ast_node=>ty_names.

    METHODS constructor
      IMPORTING iv_name          TYPE string
                iv_temporary     TYPE abap_bool DEFAULT abap_false
                iv_if_not_exists TYPE abap_bool DEFAULT abap_false
                it_columns       TYPE ty_columns OPTIONAL
                io_statement     TYPE REF TO zcl_sqlite_ast_node.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS is_if_not_exists
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS is_temporary
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS get_statement
      RETURNING VALUE(ro_statement) TYPE REF TO zcl_sqlite_ast_node.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name          TYPE string.
    DATA mv_temporary     TYPE abap_bool.
    DATA mv_if_not_exists TYPE abap_bool.
    DATA mt_columns       TYPE ty_columns.
    DATA mo_statement     TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_ast_create_view IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_name = iv_name.
    mv_temporary = iv_temporary.
    mv_if_not_exists = iv_if_not_exists.
    mt_columns = it_columns.
    mo_statement = io_statement.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_columns.
    rt_columns = mt_columns.
  ENDMETHOD.

  METHOD is_if_not_exists.
    rv_result = mv_if_not_exists.
  ENDMETHOD.

  METHOD is_temporary.
    rv_result = mv_temporary.
  ENDMETHOD.

  METHOD get_statement.
    ro_statement = mo_statement.
  ENDMETHOD.

  METHOD dump.
    rv_text = |CREATE |.
    IF mv_temporary = abap_true.
      rv_text = rv_text && |TEMP |.
    ENDIF.
    rv_text = rv_text && |VIEW |.
    IF mv_if_not_exists = abap_true.
      rv_text = rv_text && |IF NOT EXISTS |.
    ENDIF.
    rv_text = rv_text && mv_name.
    IF lines( mt_columns ) > 0.
      rv_text = rv_text && | (| && join_names( mt_columns ) && |)|.
    ENDIF.
    rv_text = rv_text && | AS | && mo_statement->dump( ).
  ENDMETHOD.

ENDCLASS.
