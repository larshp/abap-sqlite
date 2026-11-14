* A common table expression in a WITH clause.
CLASS zcl_sqlite_ast_cte DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_cte WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING iv_name         TYPE string
                it_columns      TYPE zcl_sqlite_ast_node=>ty_names OPTIONAL
                io_statement    TYPE REF TO zcl_sqlite_ast_node
                iv_materialized TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name         TYPE string.
    DATA mt_columns      TYPE zcl_sqlite_ast_node=>ty_names.
    DATA mo_statement    TYPE REF TO zcl_sqlite_ast_node.
    DATA mv_materialized TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_cte IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_name = iv_name.
    mt_columns = it_columns.
    mo_statement = io_statement.
    mv_materialized = iv_materialized.
  ENDMETHOD.

  METHOD dump.
    rv_text = mv_name.
    IF lines( mt_columns ) > 0.
      rv_text = rv_text && | (| && join_names( mt_columns ) && |)|.
    ENDIF.
    rv_text = rv_text && | AS |.
    IF mv_materialized IS NOT INITIAL.
      rv_text = rv_text && mv_materialized && | |.
    ENDIF.
    rv_text = rv_text && |(| && mo_statement->dump( ) && |)|.
  ENDMETHOD.

ENDCLASS.
