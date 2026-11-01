* An indexed column with an optional collation and sort order.
CLASS zcl_sqlite_ast_indexed_column DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  INHERITING FROM zcl_sqlite_ast_node.

  PUBLIC SECTION.
    TYPES ty_list TYPE STANDARD TABLE OF REF TO zcl_sqlite_ast_indexed_column WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING iv_name      TYPE string
                iv_collation TYPE string OPTIONAL
                iv_order     TYPE string OPTIONAL.

    METHODS dump REDEFINITION.

  PRIVATE SECTION.
    DATA mv_name      TYPE string.
    DATA mv_collation TYPE string.
    DATA mv_order     TYPE string.

ENDCLASS.


CLASS zcl_sqlite_ast_indexed_column IMPLEMENTATION.

  METHOD constructor.
    mv_name = iv_name.
    mv_collation = iv_collation.
    mv_order = iv_order.
  ENDMETHOD.

  METHOD dump.
    rv_text = mv_name.
    IF mv_collation IS NOT INITIAL.
      rv_text = rv_text && | COLLATE | && mv_collation.
    ENDIF.
    IF mv_order IS NOT INITIAL.
      rv_text = rv_text && | | && mv_order.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
