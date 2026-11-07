* Reads one table with an access path chosen by the planner. Rowid tables use
* the table b-tree cursor; WITHOUT ROWID tables are stored as an index b-tree
* and use the index cursor. Index plans read the index and then fetch the row
* through the table b-tree by rowid.
CLASS zcl_sqlite_table_scan DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    METHODS constructor
      IMPORTING io_pager TYPE REF TO zcl_sqlite_pager
                is_table TYPE zcl_sqlite_schema=>ty_table
                iv_alias TYPE string OPTIONAL
                is_plan  TYPE zcl_sqlite_planner=>ty_plan OPTIONAL
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    DATA mo_pager          TYPE REF TO zcl_sqlite_pager.
    DATA ms_table          TYPE zcl_sqlite_schema=>ty_table.
    DATA ms_plan           TYPE zcl_sqlite_planner=>ty_plan.
    DATA mv_alias          TYPE string.
    DATA mo_table_cursor   TYPE REF TO zcl_sqlite_cursor.
    DATA mo_index_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA mv_started        TYPE abap_bool.
    DATA mo_row            TYPE REF TO zcl_sqlite_row.
    DATA mt_current_values TYPE zcl_sqlite_record=>ty_values.

    METHODS first_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS first_scan_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next_scan_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS first_rowid_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next_rowid_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS rowid_in_range
      RETURNING VALUE(rv_in_range) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS first_index_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next_index_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS scan_index_rows
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS check_index_entry
      IMPORTING it_values        TYPE zcl_sqlite_record=>ty_values
      RETURNING VALUE(rv_status) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS fetch_indexed_row
      IMPORTING it_values       TYPE zcl_sqlite_record=>ty_values
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS set_scan_values
      IMPORTING iv_found TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS cursor_values
      RETURNING VALUE(rt_values) TYPE zcl_sqlite_record=>ty_values
      RAISING   zcx_sqlite_error.

    METHODS cursor_rowid
      RETURNING VALUE(rv_rowid) TYPE int8.

    METHODS build_row
      IMPORTING it_values TYPE zcl_sqlite_record=>ty_values
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_table_scan IMPLEMENTATION.

  METHOD constructor.
    IF io_pager IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'table scan needs a pager'.
    ENDIF.
    IF is_table-name IS INITIAL OR is_table-rootpage <= 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'table scan needs a table with a root page'.
    ENDIF.

    mo_pager = io_pager.
    ms_table = is_table.
    mv_alias = iv_alias.
    IF is_plan IS SUPPLIED.
      ms_plan = is_plan.
    ENDIF.
    IF ms_plan-kind IS INITIAL.
      ms_plan-kind = zcl_sqlite_planner=>c_scan.
      ms_plan-table_name = is_table-name.
      ms_plan-alias = iv_alias.
      ms_plan-range_position = -1.
    ENDIF.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    DATA lv_root_page TYPE i.

    CLEAR mo_table_cursor.
    CLEAR mo_index_cursor.
    CLEAR mo_row.
    CLEAR mt_current_values.
    mv_started = abap_false.

    IF ms_plan-kind = zcl_sqlite_planner=>c_rowid.
      lv_root_page = ms_table-rootpage.
      mo_table_cursor = NEW zcl_sqlite_cursor(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
    ELSEIF ms_plan-kind = zcl_sqlite_planner=>c_index.
      lv_root_page = ms_plan-index_rootpage.
      mo_index_cursor = NEW zcl_sqlite_index_cursor(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
      lv_root_page = ms_table-rootpage.
      mo_table_cursor = NEW zcl_sqlite_cursor(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
    ELSEIF ms_table-without_rowid = abap_true.
      lv_root_page = ms_table-rootpage.
      mo_index_cursor = NEW zcl_sqlite_index_cursor(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
    ELSE.
      lv_root_page = ms_table-rootpage.
      mo_table_cursor = NEW zcl_sqlite_cursor(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    DATA lv_found TYPE abap_bool.

    IF mv_started = abap_false.
      mv_started = abap_true.
      lv_found = first_row( ).
    ELSE.
      lv_found = next_row( ).
    ENDIF.

    IF lv_found = abap_false.
      CLEAR mo_row.
      CLEAR mt_current_values.
      RETURN abap_false.
    ENDIF.

    build_row( mt_current_values ).
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD first_row.
    CASE ms_plan-kind.
      WHEN zcl_sqlite_planner=>c_rowid.
        rv_found = first_rowid_row( ).
      WHEN zcl_sqlite_planner=>c_index.
        rv_found = first_index_row( ).
      WHEN OTHERS.
        rv_found = first_scan_row( ).
    ENDCASE.
  ENDMETHOD.

  METHOD next_row.
    CASE ms_plan-kind.
      WHEN zcl_sqlite_planner=>c_rowid.
        rv_found = next_rowid_row( ).
      WHEN zcl_sqlite_planner=>c_index.
        rv_found = next_index_row( ).
      WHEN OTHERS.
        rv_found = next_scan_row( ).
    ENDCASE.
  ENDMETHOD.

  METHOD first_scan_row.
    IF mo_table_cursor IS BOUND.
      rv_found = mo_table_cursor->first( ).
    ELSEIF mo_index_cursor IS BOUND.
      rv_found = mo_index_cursor->first( ).
    ENDIF.
    set_scan_values( rv_found ).
  ENDMETHOD.

  METHOD next_scan_row.
    IF mo_table_cursor IS BOUND.
      rv_found = mo_table_cursor->next( ).
    ELSEIF mo_index_cursor IS BOUND.
      rv_found = mo_index_cursor->next( ).
    ENDIF.
    set_scan_values( rv_found ).
  ENDMETHOD.

  METHOD set_scan_values.
    CLEAR mt_current_values.
    IF iv_found = abap_true.
      mt_current_values = cursor_values( ).
    ENDIF.
  ENDMETHOD.

  METHOD first_rowid_row.
    DATA lv_rowid TYPE int8.

    IF ms_plan-lower-value IS BOUND.
      lv_rowid = zcl_sqlite_expr_eval=>value_to_integer( ms_plan-lower-value ).
      rv_found = mo_table_cursor->seek( lv_rowid ).
      IF rv_found = abap_true AND ms_plan-lower-operator = '>'.
        WHILE mo_table_cursor->rowid( ) = lv_rowid.
          rv_found = mo_table_cursor->next( ).
          IF rv_found = abap_false.
            EXIT.
          ENDIF.
        ENDWHILE.
      ENDIF.
    ELSE.
      rv_found = mo_table_cursor->first( ).
    ENDIF.

    IF rv_found = abap_true.
      rv_found = rowid_in_range( ).
    ENDIF.
    IF rv_found = abap_true.
      mt_current_values = mo_table_cursor->values( ).
    ENDIF.
  ENDMETHOD.

  METHOD next_rowid_row.
    rv_found = mo_table_cursor->next( ).
    IF rv_found = abap_true.
      rv_found = rowid_in_range( ).
    ENDIF.
    IF rv_found = abap_true.
      mt_current_values = mo_table_cursor->values( ).
    ENDIF.
  ENDMETHOD.

  METHOD rowid_in_range.
    DATA lv_rowid TYPE int8.
    DATA lv_bound TYPE int8.

    lv_rowid = mo_table_cursor->rowid( ).

    IF ms_plan-lower-value IS BOUND.
      lv_bound = zcl_sqlite_expr_eval=>value_to_integer( ms_plan-lower-value ).
      CASE ms_plan-lower-operator.
        WHEN '='.
          IF lv_rowid <> lv_bound.
            RETURN abap_false.
          ENDIF.
        WHEN '>'.
          IF lv_rowid <= lv_bound.
            RETURN abap_false.
          ENDIF.
        WHEN '>='.
          IF lv_rowid < lv_bound.
            RETURN abap_false.
          ENDIF.
      ENDCASE.
    ENDIF.

    IF ms_plan-upper-value IS BOUND.
      lv_bound = zcl_sqlite_expr_eval=>value_to_integer( ms_plan-upper-value ).
      CASE ms_plan-upper-operator.
        WHEN '='.
          IF lv_rowid <> lv_bound.
            RETURN abap_false.
          ENDIF.
        WHEN '<'.
          IF lv_rowid >= lv_bound.
            RETURN abap_false.
          ENDIF.
        WHEN '<='.
          IF lv_rowid > lv_bound.
            RETURN abap_false.
          ENDIF.
      ENDCASE.
    ENDIF.

    rv_in_range = abap_true.
  ENDMETHOD.

  METHOD first_index_row.
    DATA lt_seek TYPE zcl_sqlite_record=>ty_values.

    IF ms_plan-prefix_length > 0.
      lt_seek = ms_plan-prefix_values.
      IF ms_plan-range_position >= 0 AND ms_plan-lower-value IS BOUND.
        APPEND ms_plan-lower-value TO lt_seek.
      ENDIF.
      rv_found = mo_index_cursor->seek( lt_seek ).
    ELSEIF ms_plan-range_position >= 0 AND ms_plan-lower-value IS BOUND.
      APPEND ms_plan-lower-value TO lt_seek.
      rv_found = mo_index_cursor->seek( lt_seek ).
    ELSE.
      rv_found = mo_index_cursor->first( ).
    ENDIF.

    IF rv_found = abap_false.
      RETURN.
    ENDIF.
    rv_found = scan_index_rows( ).
  ENDMETHOD.

  METHOD next_index_row.
    IF mo_index_cursor->next( ) = abap_false.
      RETURN abap_false.
    ENDIF.
    rv_found = scan_index_rows( ).
  ENDMETHOD.

  METHOD scan_index_rows.
    DATA lv_status TYPE i.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.

    DO.
      lt_values = mo_index_cursor->values( ).
      lv_status = check_index_entry( lt_values ).
      CASE lv_status.
        WHEN zcl_sqlite_planner=>c_match.
          IF fetch_indexed_row( lt_values ) = abap_true.
            RETURN abap_true.
          ENDIF.
        WHEN zcl_sqlite_planner=>c_stop.
          RETURN abap_false.
      ENDCASE.

      IF mo_index_cursor->next( ) = abap_false.
        RETURN abap_false.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD check_index_entry.
    DATA lo_entry  TYPE REF TO zcl_sqlite_value.
    DATA lo_prefix TYPE REF TO zcl_sqlite_value.
    DATA lv_index  TYPE i.
    DATA lv_compare TYPE i.

    IF ms_plan-prefix_length > 0.
      lv_index = 1.
      LOOP AT ms_plan-prefix_values INTO lo_prefix.
        READ TABLE it_values INTO lo_entry INDEX lv_index.
        IF sy-subrc <> 0.
          RETURN zcl_sqlite_planner=>c_stop.
        ENDIF.
        lv_compare = zcl_sqlite_expr_eval=>compare_values(
          io_left  = lo_entry
          io_right = lo_prefix ).
        IF lv_compare < 0.
          RETURN zcl_sqlite_planner=>c_skip.
        ELSEIF lv_compare > 0.
          RETURN zcl_sqlite_planner=>c_stop.
        ENDIF.
        lv_index = lv_index + 1.
      ENDLOOP.
    ENDIF.

    IF ms_plan-range_position >= 0.
      lv_index = ms_plan-range_position + 1.
      READ TABLE it_values INTO lo_entry INDEX lv_index.
      IF sy-subrc <> 0.
        RETURN zcl_sqlite_planner=>c_stop.
      ENDIF.

      IF ms_plan-lower-value IS BOUND.
        lv_compare = zcl_sqlite_expr_eval=>compare_values(
          io_left  = lo_entry
          io_right = ms_plan-lower-value ).
        CASE ms_plan-lower-operator.
          WHEN '='.
            IF lv_compare < 0.
              RETURN zcl_sqlite_planner=>c_skip.
            ELSEIF lv_compare > 0.
              RETURN zcl_sqlite_planner=>c_stop.
            ENDIF.
          WHEN '>'.
            IF lv_compare <= 0.
              RETURN zcl_sqlite_planner=>c_skip.
            ENDIF.
          WHEN '>='.
            IF lv_compare < 0.
              RETURN zcl_sqlite_planner=>c_skip.
            ENDIF.
        ENDCASE.
      ENDIF.

      IF ms_plan-upper-value IS BOUND.
        lv_compare = zcl_sqlite_expr_eval=>compare_values(
          io_left  = lo_entry
          io_right = ms_plan-upper-value ).
        CASE ms_plan-upper-operator.
          WHEN '='.
            IF lv_compare > 0.
              RETURN zcl_sqlite_planner=>c_stop.
            ELSEIF lv_compare < 0.
              RETURN zcl_sqlite_planner=>c_skip.
            ENDIF.
          WHEN '<'.
            IF lv_compare >= 0.
              RETURN zcl_sqlite_planner=>c_stop.
            ENDIF.
          WHEN '<='.
            IF lv_compare > 0.
              RETURN zcl_sqlite_planner=>c_stop.
            ENDIF.
        ENDCASE.
      ENDIF.
    ENDIF.

    RETURN zcl_sqlite_planner=>c_match.
  ENDMETHOD.

  METHOD fetch_indexed_row.
    DATA lo_rowid TYPE REF TO zcl_sqlite_value.
    DATA lv_index TYPE i.
    DATA lv_rowid TYPE int8.

    lv_index = lines( it_values ).
    IF lv_index <= lines( ms_plan-index_columns ).
      RETURN abap_false.
    ENDIF.

    READ TABLE it_values INTO lo_rowid INDEX lv_index.
    IF sy-subrc <> 0
        OR lo_rowid->value_type( ) <> zcl_sqlite_value=>c_integer.
      RETURN abap_false.
    ENDIF.

    lv_rowid = lo_rowid->as_integer( ).
    IF mo_table_cursor->seek( lv_rowid ) = abap_false.
      RETURN abap_false.
    ENDIF.
    IF mo_table_cursor->rowid( ) <> lv_rowid.
      RETURN abap_false.
    ENDIF.

    mt_current_values = mo_table_cursor->values( ).
    rv_found = abap_true.
  ENDMETHOD.

  METHOD cursor_values.
    IF mo_table_cursor IS BOUND.
      rt_values = mo_table_cursor->values( ).
    ELSEIF mo_index_cursor IS BOUND.
      rt_values = mo_index_cursor->values( ).
    ENDIF.
  ENDMETHOD.

  METHOD cursor_rowid.
    IF mo_table_cursor IS BOUND.
      rv_rowid = mo_table_cursor->rowid( ).
    ENDIF.
  ENDMETHOD.

  METHOD build_row.
    DATA lo_row        TYPE REF TO zcl_sqlite_row.
    DATA ls_column     TYPE zcl_sqlite_schema=>ty_column.
    DATA lo_value      TYPE REF TO zcl_sqlite_value.
    DATA lv_rowid      TYPE int8.
    DATA lv_table_name TYPE string.

    lv_table_name = mv_alias.
    IF lv_table_name IS INITIAL.
      lv_table_name = ms_table-name.
    ENDIF.
    lv_rowid = cursor_rowid( ).
    lo_row = NEW zcl_sqlite_row( ).

    LOOP AT ms_table-columns INTO ls_column.
      READ TABLE it_values INTO lo_value INDEX sy-tabix.
      IF sy-subrc <> 0.
        lo_value = zcl_sqlite_value=>null( ).
      ENDIF.
      IF ls_column-rowid_alias = abap_true
          AND ms_table-without_rowid = abap_false
          AND lo_value->is_null( ) = abap_true.
        lo_value = zcl_sqlite_value=>integer( lv_rowid ).
      ENDIF.
      lo_row->add_cell(
        iv_name       = ls_column-name
        iv_table_name = lv_table_name
        io_value      = lo_value ).
    ENDLOOP.

    IF ms_table-without_rowid = abap_false.
      lo_row->add_cell(
        iv_name       = 'rowid'
        iv_table_name = lv_table_name
        io_value      = zcl_sqlite_value=>integer( lv_rowid ) ).
      lo_row->add_cell(
        iv_name       = '_rowid_'
        iv_table_name = lv_table_name
        io_value      = zcl_sqlite_value=>integer( lv_rowid ) ).
      lo_row->add_cell(
        iv_name       = 'oid'
        iv_table_name = lv_table_name
        io_value      = zcl_sqlite_value=>integer( lv_rowid ) ).
    ENDIF.

    mo_row = lo_row.
  ENDMETHOD.

ENDCLASS.
