* A VALUES statement.
CLASS zcl_sqlite_ast_values DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_rows TYPE zcl_sqlite_ast_values_row=>ty_list.

    METHODS constructor
      IMPORTING it_rows TYPE ty_rows.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mt_rows TYPE ty_rows.

ENDCLASS.


CLASS zcl_sqlite_ast_values IMPLEMENTATION.

  METHOD constructor.
    mt_rows = it_rows.
  ENDMETHOD.

  METHOD dump.
    DATA lo_row TYPE REF TO zcl_sqlite_ast_values_row.

    rv_text = |VALUES |.
    LOOP AT mt_rows INTO lo_row.
      IF rv_text <> |VALUES |.
        " ANORMALY: character literals lose trailing blanks when concatenated
        rv_text = rv_text && |, |.
      ENDIF.
      rv_text = rv_text && lo_row->dump( ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
