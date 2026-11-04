* Full scan of one table. Rowid tables use the table b-tree cursor; WITHOUT
* ROWID tables are stored as an index b-tree and use the index cursor.
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
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    DATA mo_pager        TYPE REF TO zcl_sqlite_pager.
    DATA ms_table        TYPE zcl_sqlite_schema=>ty_table.
    DATA mv_alias        TYPE string.
    DATA mo_table_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA mo_index_cursor TYPE REF TO zcl_sqlite_index_cursor.
    DATA mv_started      TYPE abap_bool.
    DATA mo_row          TYPE REF TO zcl_sqlite_row.

    METHODS first_row
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS next_row
      RETURNING VALUE(rv_found) TYPE abap_bool
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
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    DATA lv_root_page TYPE i.

    lv_root_page = ms_table-rootpage.
    CLEAR mo_table_cursor.
    CLEAR mo_index_cursor.
    CLEAR mo_row.
    mv_started = abap_false.

    IF ms_table-without_rowid = abap_true.
      mo_index_cursor = NEW zcl_sqlite_index_cursor(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
    ELSE.
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
      RETURN abap_false.
    ENDIF.

    build_row( cursor_values( ) ).
    RETURN abap_true.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD first_row.
    IF mo_table_cursor IS BOUND.
      rv_found = mo_table_cursor->first( ).
    ELSEIF mo_index_cursor IS BOUND.
      rv_found = mo_index_cursor->first( ).
    ENDIF.
  ENDMETHOD.

  METHOD next_row.
    IF mo_table_cursor IS BOUND.
      rv_found = mo_table_cursor->next( ).
    ELSEIF mo_index_cursor IS BOUND.
      rv_found = mo_index_cursor->next( ).
    ENDIF.
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
    DATA lo_row       TYPE REF TO zcl_sqlite_row.
    DATA ls_column    TYPE zcl_sqlite_schema=>ty_column.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.
    DATA lv_rowid     TYPE int8.
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
