* A literal expression: NULL, integer, real, string, blob or CURRENT_*.
CLASS zcl_sqlite_ast_literal DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_kind  TYPE string
                iv_value TYPE string.

    METHODS get_kind
      RETURNING VALUE(rv_kind) TYPE string.

    METHODS get_value
      RETURNING VALUE(rv_value) TYPE string.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_kind TYPE string.
    DATA mv_value TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_literal IMPLEMENTATION.

  METHOD constructor.
    mv_kind = iv_kind.
    mv_value = iv_value.
  ENDMETHOD.

  METHOD get_kind.
    rv_kind = mv_kind.
  ENDMETHOD.

  METHOD get_value.
    rv_value = mv_value.
  ENDMETHOD.

  METHOD dump.
    CASE mv_kind.
      WHEN 'NULL'.
        rv_text = 'NULL'.
      WHEN 'INTEGER'.
        rv_text = |INTEGER({ mv_value })|.
      WHEN 'REAL'.
        rv_text = |REAL({ mv_value })|.
      WHEN 'STRING'.
        rv_text = |STRING({ quote_string( mv_value ) })|.
      WHEN 'BLOB'.
        rv_text = |BLOB(X'{ mv_value }')|.
      WHEN OTHERS.
        rv_text = mv_kind.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
