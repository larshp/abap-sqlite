* A table reference in a FROM clause.
CLASS zcl_sqlite_ast_table_ref DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_name  TYPE string
                iv_alias TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

    METHODS get_name
      RETURNING VALUE(rv_name) TYPE string.

    METHODS get_alias
      RETURNING VALUE(rv_alias) TYPE string.

  PRIVATE SECTION.
    DATA mv_name  TYPE string.
    DATA mv_alias TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_table_ref IMPLEMENTATION.

  METHOD constructor.
    mv_name = iv_name.
    mv_alias = iv_alias.
  ENDMETHOD.

  METHOD dump.
    rv_text = mv_name.
    IF mv_alias IS NOT INITIAL.
      rv_text = rv_text && | AS | && mv_alias.
    ENDIF.
  ENDMETHOD.

  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.

  METHOD get_alias.
    rv_alias = mv_alias.
  ENDMETHOD.

ENDCLASS.
