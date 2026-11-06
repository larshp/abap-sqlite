* Removes duplicate rows from a child operator. Only the first visible
* columns take part in the comparison; extra columns may carry ORDER BY keys.
CLASS zcl_sqlite_distinct DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    METHODS constructor
      IMPORTING io_source        TYPE REF TO zif_sqlite_operator
                iv_visible_count TYPE i.

  PRIVATE SECTION.
    DATA mo_source        TYPE REF TO zif_sqlite_operator.
    DATA mv_visible_count TYPE i.
    DATA mt_rows          TYPE STANDARD TABLE OF REF TO zcl_sqlite_row WITH DEFAULT KEY.
    DATA mv_index         TYPE i.
    DATA mo_row           TYPE REF TO zcl_sqlite_row.

    METHODS is_duplicate
      IMPORTING io_row              TYPE REF TO zcl_sqlite_row
      RETURNING VALUE(rv_duplicate) TYPE abap_bool
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_distinct IMPLEMENTATION.

  METHOD constructor.
    mo_source = io_source.
    mv_visible_count = iv_visible_count.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    DATA lo_row TYPE REF TO zcl_sqlite_row.

    mo_source->open( ).
    CLEAR mt_rows.
    WHILE mo_source->next( ) = abap_true.
      lo_row = mo_source->row( ).
      IF is_duplicate( lo_row ) = abap_false.
        APPEND lo_row TO mt_rows.
      ENDIF.
    ENDWHILE.

    mv_index = 1.
    CLEAR mo_row.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    IF mv_index > lines( mt_rows ).
      CLEAR mo_row.
      RETURN abap_false.
    ENDIF.

    READ TABLE mt_rows INTO mo_row INDEX mv_index.
    mv_index = mv_index + 1.
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD is_duplicate.
    DATA lo_existing TYPE REF TO zcl_sqlite_row.
    DATA lt_existing TYPE zcl_sqlite_row=>ty_values.
    DATA lt_current  TYPE zcl_sqlite_row=>ty_values.
    DATA lo_left     TYPE REF TO zcl_sqlite_value.
    DATA lo_right    TYPE REF TO zcl_sqlite_value.
    DATA lv_index    TYPE i.

    lt_current = io_row->values( ).
    LOOP AT mt_rows INTO lo_existing.
      lt_existing = lo_existing->values( ).
      rv_duplicate = abap_true.
      DO mv_visible_count TIMES.
        lv_index = sy-index.
        READ TABLE lt_existing INTO lo_left INDEX lv_index.
        READ TABLE lt_current INTO lo_right INDEX lv_index.

        IF lo_left->is_null( ) = abap_true AND lo_right->is_null( ) = abap_true.
          CONTINUE.
        ENDIF.
        IF lo_left->is_null( ) = abap_true OR lo_right->is_null( ) = abap_true.
          rv_duplicate = abap_false.
          EXIT.
        ENDIF.
        IF zcl_sqlite_expr_eval=>compare_values(
            io_left  = lo_left
            io_right = lo_right ) <> 0.
          rv_duplicate = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
      IF rv_duplicate = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_duplicate = abap_false.
  ENDMETHOD.

ENDCLASS.
