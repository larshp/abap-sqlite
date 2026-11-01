* An INSERT statement.
CLASS zcl_sqlite_ast_insert DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_conflict       TYPE string OPTIONAL
                iv_table          TYPE string
                it_columns        TYPE zcl_sqlite_ast_node=>ty_names OPTIONAL
                io_values         TYPE REF TO zcl_sqlite_ast_values OPTIONAL
                io_select         TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                iv_default_values TYPE abap_bool DEFAULT abap_false.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_conflict       TYPE string.
    DATA mv_table          TYPE string.
    DATA mt_columns        TYPE zcl_sqlite_ast_node=>ty_names.
    DATA mo_values         TYPE REF TO zcl_sqlite_ast_values.
    DATA mo_select         TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_default_values TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_ast_insert IMPLEMENTATION.

  METHOD constructor.
    mv_conflict = iv_conflict.
    mv_table = iv_table.
    mt_columns = it_columns.
    mo_values = io_values.
    mo_select = io_select.
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
  ENDMETHOD.

ENDCLASS.
