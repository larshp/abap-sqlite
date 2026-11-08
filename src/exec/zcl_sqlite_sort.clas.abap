* Sorts the rows of a child operator by one or more SQL ORDER BY terms.
* The sort is stable, so equal keys keep the child operator's row order.
CLASS zcl_sqlite_sort DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    TYPES: BEGIN OF ty_term,
             position  TYPE i,
             direction TYPE string,
             nulls     TYPE string,
             collation TYPE string,
           END OF ty_term.
    TYPES ty_terms TYPE STANDARD TABLE OF ty_term WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING io_source TYPE REF TO zif_sqlite_operator
                it_terms  TYPE ty_terms.

  PRIVATE SECTION.
    TYPES ty_values TYPE zcl_sqlite_row=>ty_values.

    TYPES: BEGIN OF ty_sort_row,
             row  TYPE REF TO zcl_sqlite_row,
             keys TYPE ty_values,
           END OF ty_sort_row.
    TYPES ty_sort_rows TYPE STANDARD TABLE OF ty_sort_row WITH DEFAULT KEY.

    DATA mo_source TYPE REF TO zif_sqlite_operator.
    DATA mt_terms  TYPE ty_terms.
    DATA mt_rows   TYPE ty_sort_rows.
    DATA mv_index  TYPE i.
    DATA mo_row    TYPE REF TO zcl_sqlite_row.

    METHODS load_rows
      RAISING zcx_sqlite_error.

    METHODS build_keys
      IMPORTING io_row        TYPE REF TO zcl_sqlite_row
      RETURNING VALUE(rs_row) TYPE ty_sort_row
      RAISING   zcx_sqlite_error.

    METHODS merge_sort
      IMPORTING it_input         TYPE ty_sort_rows
      RETURNING VALUE(rt_sorted) TYPE ty_sort_rows
      RAISING   zcx_sqlite_error.

    METHODS compare_rows
      IMPORTING is_left           TYPE ty_sort_row
                is_right          TYPE ty_sort_row
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_sort IMPLEMENTATION.

  METHOD constructor.
    mo_source = io_source.
    mt_terms = it_terms.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    mo_source->open( ).
    load_rows( ).
    mv_index = 1.
    CLEAR mo_row.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    DATA ls_row TYPE ty_sort_row.

    IF mv_index > lines( mt_rows ).
      CLEAR mo_row.
      RETURN abap_false.
    ENDIF.

    READ TABLE mt_rows INTO ls_row INDEX mv_index.
    mo_row = ls_row-row.
    mv_index = mv_index + 1.
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD load_rows.
    DATA ls_row TYPE ty_sort_row.

    CLEAR mt_rows.
    WHILE mo_source->next( ) = abap_true.
      ls_row = build_keys( mo_source->row( ) ).
      APPEND ls_row TO mt_rows.
    ENDWHILE.

    mt_rows = merge_sort( mt_rows ).
  ENDMETHOD.

  METHOD build_keys.
    DATA lt_values TYPE zcl_sqlite_row=>ty_values.
    DATA ls_term   TYPE ty_term.
    DATA lo_value  TYPE REF TO zcl_sqlite_value.

    lt_values = io_row->values( ).
    rs_row-row = io_row.
    LOOP AT mt_terms INTO ls_term.
      READ TABLE lt_values INTO lo_value INDEX ls_term-position.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = 'ORDER BY position is out of range'.
      ENDIF.
      APPEND lo_value TO rs_row-keys.
    ENDLOOP.
  ENDMETHOD.

  METHOD merge_sort.
    DATA lt_source TYPE ty_sort_rows.
    DATA lt_target TYPE ty_sort_rows.
    DATA lv_count  TYPE i.
    DATA lv_width  TYPE i VALUE 1.
    DATA lv_start  TYPE i.
    DATA lv_middle TYPE i.
    DATA lv_end    TYPE i.
    DATA lv_left   TYPE i.
    DATA lv_right  TYPE i.
    DATA ls_row    TYPE ty_sort_row.
    DATA ls_left   TYPE ty_sort_row.
    DATA ls_right  TYPE ty_sort_row.

    lt_source = it_input.
    lv_count = lines( lt_source ).
    IF lv_count < 2.
      rt_sorted = lt_source.
      RETURN.
    ENDIF.

    WHILE lv_width < lv_count.
      CLEAR lt_target.
      lv_start = 1.
      WHILE lv_start <= lv_count.
        lv_middle = lv_start + lv_width - 1.
        IF lv_middle > lv_count.
          lv_middle = lv_count.
        ENDIF.
        lv_end = lv_start + lv_width * 2 - 1.
        IF lv_end > lv_count.
          lv_end = lv_count.
        ENDIF.

        lv_left = lv_start.
        lv_right = lv_middle + 1.
        WHILE lv_left <= lv_middle OR lv_right <= lv_end.
          IF lv_left > lv_middle.
            READ TABLE lt_source INTO ls_row INDEX lv_right.
            APPEND ls_row TO lt_target.
            lv_right = lv_right + 1.
          ELSEIF lv_right > lv_end.
            READ TABLE lt_source INTO ls_row INDEX lv_left.
            APPEND ls_row TO lt_target.
            lv_left = lv_left + 1.
          ELSE.
            READ TABLE lt_source INTO ls_left INDEX lv_left.
            READ TABLE lt_source INTO ls_right INDEX lv_right.
            IF compare_rows( is_left  = ls_left
                             is_right = ls_right ) <= 0.
              APPEND ls_left TO lt_target.
              lv_left = lv_left + 1.
            ELSE.
              APPEND ls_right TO lt_target.
              lv_right = lv_right + 1.
            ENDIF.
          ENDIF.
        ENDWHILE.

        lv_start = lv_end + 1.
      ENDWHILE.

      lt_source = lt_target.
      lv_width = lv_width * 2.
    ENDWHILE.

    rt_sorted = lt_source.
  ENDMETHOD.

  METHOD compare_rows.
    DATA ls_term    TYPE ty_term.
    DATA lo_left    TYPE REF TO zcl_sqlite_value.
    DATA lo_right   TYPE REF TO zcl_sqlite_value.
    DATA lv_compare TYPE i.

    LOOP AT mt_terms INTO ls_term.
      READ TABLE is_left-keys INTO lo_left INDEX sy-tabix.
      READ TABLE is_right-keys INTO lo_right INDEX sy-tabix.

      IF lo_left->is_null( ) = abap_true AND lo_right->is_null( ) = abap_true.
        CONTINUE.
      ENDIF.

      IF lo_left->is_null( ) = abap_true.
        IF ls_term-nulls = 'FIRST'.
          rv_compare = -1.
        ELSE.
          rv_compare = 1.
        ENDIF.
        RETURN.
      ENDIF.

      IF lo_right->is_null( ) = abap_true.
        IF ls_term-nulls = 'FIRST'.
          rv_compare = 1.
        ELSE.
          rv_compare = -1.
        ENDIF.
        RETURN.
      ENDIF.

      lv_compare = zcl_sqlite_expr_eval=>compare_values(
        io_left      = lo_left
        io_right     = lo_right
        iv_collation = ls_term-collation ).
      IF lv_compare <> 0.
        IF ls_term-direction = 'DESC'.
          rv_compare = 0 - lv_compare.
        ELSE.
          rv_compare = lv_compare.
        ENDIF.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_compare = 0.
  ENDMETHOD.

ENDCLASS.
