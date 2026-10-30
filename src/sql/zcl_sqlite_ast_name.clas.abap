* A column reference, bind parameter or standalone star.
CLASS zcl_sqlite_ast_name DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    CONSTANTS:
      c_column    TYPE string VALUE 'COLUMN',
      c_parameter TYPE string VALUE 'PARAMETER',
      c_star      TYPE string VALUE 'STAR'.

    METHODS constructor
      IMPORTING iv_kind TYPE string
                iv_text TYPE string.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_kind TYPE string.
    DATA mv_text TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_name IMPLEMENTATION.

  METHOD constructor.
    mv_kind = iv_kind.
    mv_text = iv_text.
  ENDMETHOD.

  METHOD dump.
    CASE mv_kind.
      WHEN c_column.
        rv_text = |COLUMN({ mv_text })|.
      WHEN c_parameter.
        rv_text = |PARAM({ mv_text })|.
      WHEN c_star.
        rv_text = 'STAR'.
      WHEN OTHERS.
        rv_text = mv_text.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
