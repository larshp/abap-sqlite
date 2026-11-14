* A PRAGMA statement.
CLASS zcl_sqlite_ast_pragma DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_name      TYPE string
                iv_separator TYPE string OPTIONAL
                iv_value     TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name      TYPE string.
    DATA mv_separator TYPE string.
    DATA mv_value     TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_pragma IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    mv_name = iv_name.
    mv_separator = iv_separator.
    mv_value = iv_value.
  ENDMETHOD.

  METHOD dump.
    rv_text = |PRAGMA { mv_name }|.
    CASE mv_separator.
      WHEN '='.
        rv_text = rv_text && | = | && mv_value.
      WHEN '('.
        rv_text = rv_text && |(| && mv_value && |)|.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
