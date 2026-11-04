* Filters the rows of a child operator with a WHERE expression.
CLASS zcl_sqlite_filter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    METHODS constructor
      IMPORTING io_source TYPE REF TO zif_sqlite_operator
                io_where  TYPE REF TO zcl_sqlite_ast_node OPTIONAL.

  PRIVATE SECTION.
    DATA mo_source TYPE REF TO zif_sqlite_operator.
    DATA mo_where  TYPE REF TO zcl_sqlite_ast_node.

ENDCLASS.


CLASS zcl_sqlite_filter IMPLEMENTATION.

  METHOD constructor.
    mo_source = io_source.
    mo_where = io_where.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    mo_source->open( ).
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    DATA lo_context TYPE REF TO zif_sqlite_eval_context.
    DATA lo_value   TYPE REF TO zcl_sqlite_value.

    IF mo_where IS NOT BOUND.
      RETURN mo_source->next( ).
    ENDIF.

    DO.
      IF mo_source->next( ) = abap_false.
        RETURN abap_false.
      ENDIF.
      lo_context = mo_source->row( ).
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = mo_where
        io_context    = lo_context ).
      IF zcl_sqlite_expr_eval=>is_true( lo_value ) = abap_true.
        RETURN abap_true.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_source->row( ).
  ENDMETHOD.

ENDCLASS.
