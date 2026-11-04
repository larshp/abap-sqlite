* Minimal read-only database API. It opens a database through the table VFS
* and executes SELECT statements with the TableScan, Filter and Project
* operators. Phase 6 replaces this with the polished public API.
CLASS zcl_sqlite_database DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES ty_row TYPE zcl_sqlite_record=>ty_values.
    TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
    TYPES ty_column_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_result,
             columns TYPE ty_column_names,
             rows    TYPE ty_rows,
           END OF ty_result.

    CLASS-METHODS open
      IMPORTING iv_name            TYPE string
      RETURNING VALUE(ro_database) TYPE REF TO zcl_sqlite_database
      RAISING   zcx_sqlite_error.

    METHODS close.

    METHODS query
      IMPORTING iv_sql           TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    DATA mo_file   TYPE REF TO zif_sqlite_file.
    DATA mo_pager  TYPE REF TO zcl_sqlite_pager.
    DATA mo_schema TYPE REF TO zcl_sqlite_schema.

    METHODS constructor
      IMPORTING io_file   TYPE REF TO zif_sqlite_file
                io_pager  TYPE REF TO zcl_sqlite_pager
                io_schema TYPE REF TO zcl_sqlite_schema.

    METHODS project_columns
      IMPORTING it_result_columns TYPE zcl_sqlite_ast_select=>ty_columns
                it_table_columns  TYPE zcl_sqlite_schema=>ty_columns OPTIONAL
      RETURNING VALUE(rt_columns) TYPE zcl_sqlite_project=>ty_columns
      RAISING   zcx_sqlite_error.

    METHODS is_star
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_star) TYPE abap_bool.

    METHODS simple_column_name
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_name) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_database IMPLEMENTATION.

  METHOD open.
    DATA lo_vfs    TYPE REF TO zif_sqlite_vfs.
    DATA lo_file   TYPE REF TO zif_sqlite_file.
    DATA lo_pager  TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( iv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).

    ro_database = NEW zcl_sqlite_database(
      io_file   = lo_file
      io_pager  = lo_pager
      io_schema = lo_schema ).
  ENDMETHOD.

  METHOD constructor.
    mo_file = io_file.
    mo_pager = io_pager.
    mo_schema = io_schema.
  ENDMETHOD.

  METHOD close.
    IF mo_file IS BOUND.
      mo_file->close( ).
    ENDIF.
    CLEAR mo_file.
    CLEAR mo_pager.
    CLEAR mo_schema.
  ENDMETHOD.

  METHOD query.
    DATA lo_statement       TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_select          TYPE REF TO zcl_sqlite_ast_select.
    DATA lo_from            TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_table_ref       TYPE REF TO zcl_sqlite_ast_table_ref.
    DATA lo_where           TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_operator        TYPE REF TO zif_sqlite_operator.
    DATA lo_project         TYPE REF TO zif_sqlite_operator.
    DATA lo_row             TYPE REF TO zcl_sqlite_row.
    DATA lt_from            TYPE zcl_sqlite_ast_select=>ty_from.
    DATA lt_result_columns  TYPE zcl_sqlite_ast_select=>ty_columns.
    DATA lt_project_columns TYPE zcl_sqlite_project=>ty_columns.
    DATA ls_project_column  TYPE zcl_sqlite_project=>ty_column.
    DATA ls_table           TYPE zcl_sqlite_schema=>ty_table.
    DATA lv_has_table       TYPE abap_bool.

    IF mo_pager IS NOT BOUND OR mo_schema IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'database is closed'.
    ENDIF.

    lo_statement = zcl_sqlite_parser=>parse_statement( iv_sql ).
    IF lo_statement IS NOT INSTANCE OF zcl_sqlite_ast_select.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'only SELECT statements are supported'.
    ENDIF.
    lo_select ?= lo_statement.

    IF lo_select->get_distinct( ) = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'DISTINCT is not supported yet'.
    ENDIF.
    IF lines( lo_select->get_group_by( ) ) > 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'GROUP BY is not supported yet'.
    ENDIF.
    IF lo_select->get_having( ) IS BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'HAVING is not supported yet'.
    ENDIF.
    IF lines( lo_select->get_order_by( ) ) > 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'ORDER BY is not supported yet'.
    ENDIF.
    IF lo_select->get_limit( ) IS BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'LIMIT is not supported yet'.
    ENDIF.
    IF lo_select->get_offset( ) IS BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'OFFSET is not supported yet'.
    ENDIF.

    lt_from = lo_select->get_from( ).
    IF lines( lt_from ) > 1.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'joins are not supported yet'.
    ENDIF.
    IF lines( lt_from ) = 1.
      READ TABLE lt_from INTO lo_from INDEX 1.
      IF lo_from IS NOT INSTANCE OF zcl_sqlite_ast_table_ref.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = 'only simple table references are supported'.
      ENDIF.
      lo_table_ref ?= lo_from.
      ls_table = mo_schema->table( lo_table_ref->get_name( ) ).
      IF ls_table-name IS INITIAL.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = |no such table: { lo_table_ref->get_name( ) }|.
      ENDIF.
      lv_has_table = abap_true.
    ENDIF.

    lt_result_columns = lo_select->get_columns( ).
    IF lines( lt_result_columns ) = 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'SELECT statement has no result columns'.
    ENDIF.
    lt_project_columns = project_columns(
      it_result_columns = lt_result_columns
      it_table_columns  = ls_table-columns ).

    IF lv_has_table = abap_true.
      lo_operator = NEW zcl_sqlite_table_scan(
        io_pager  = mo_pager
        is_table  = ls_table
        iv_alias  = lo_table_ref->get_alias( ) ).
      lo_where = lo_select->get_where( ).
      IF lo_where IS BOUND.
        lo_operator = NEW zcl_sqlite_filter(
          io_source = lo_operator
          io_where  = lo_where ).
      ENDIF.
    ENDIF.

    lo_project = NEW zcl_sqlite_project(
      io_source  = lo_operator
      it_columns = lt_project_columns ).
    lo_project->open( ).
    WHILE lo_project->next( ) = abap_true.
      lo_row = lo_project->row( ).
      APPEND lo_row->values( ) TO rs_result-rows.
    ENDWHILE.

    LOOP AT lt_project_columns INTO ls_project_column.
      APPEND ls_project_column-name TO rs_result-columns.
    ENDLOOP.
  ENDMETHOD.

  METHOD project_columns.
    DATA lo_result_column TYPE REF TO zcl_sqlite_ast_result_column.
    DATA lo_name          TYPE REF TO zcl_sqlite_ast_name.
    DATA lo_expression    TYPE REF TO zcl_sqlite_ast_node.
    DATA ls_table_column  TYPE zcl_sqlite_schema=>ty_column.
    DATA ls_project_column TYPE zcl_sqlite_project=>ty_column.
    DATA lv_alias         TYPE string.

    LOOP AT it_result_columns INTO lo_result_column.
      lo_expression = lo_result_column->get_expression( ).
      IF is_star( lo_expression ) = abap_true.
        IF lines( it_table_columns ) = 0.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING iv_message = 'star requires a table'.
        ENDIF.
        LOOP AT it_table_columns INTO ls_table_column.
          ls_project_column-expression = NEW zcl_sqlite_ast_name(
            iv_kind = zcl_sqlite_ast_name=>c_column
            iv_text = ls_table_column-name ).
          ls_project_column-name = ls_table_column-name.
          APPEND ls_project_column TO rt_columns.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      ls_project_column-expression = lo_expression.
      lv_alias = lo_result_column->get_alias( ).
      IF lv_alias IS NOT INITIAL.
        ls_project_column-name = lv_alias.
      ELSEIF lo_expression IS INSTANCE OF zcl_sqlite_ast_name.
        lo_name ?= lo_expression.
        IF lo_name->get_kind( ) = zcl_sqlite_ast_name=>c_column.
          ls_project_column-name = simple_column_name( lo_name->get_text( ) ).
        ELSE.
          ls_project_column-name = lo_expression->dump( ).
        ENDIF.
      ELSE.
        ls_project_column-name = lo_expression->dump( ).
      ENDIF.
      APPEND ls_project_column TO rt_columns.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_star.
    DATA lo_name  TYPE REF TO zcl_sqlite_ast_name.
    DATA lv_text  TYPE string.
    DATA lv_length TYPE i.

    IF io_expression IS NOT INSTANCE OF zcl_sqlite_ast_name.
      RETURN.
    ENDIF.
    lo_name ?= io_expression.
    IF lo_name->get_kind( ) = zcl_sqlite_ast_name=>c_star.
      rv_star = abap_true.
      RETURN.
    ENDIF.
    IF lo_name->get_kind( ) = zcl_sqlite_ast_name=>c_column.
      lv_text = lo_name->get_text( ).
      lv_length = strlen( lv_text ).
      IF lv_length >= 2
          AND substring( val = lv_text off = lv_length - 2 len = 2 ) = '.*'.
        rv_star = abap_true.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD simple_column_name.
    DATA lv_index TYPE i.

    rv_name = iv_name.
    lv_index = strlen( iv_name ).
    WHILE lv_index > 0.
      lv_index = lv_index - 1.
      IF substring( val = iv_name off = lv_index len = 1 ) = '.'.
        rv_name = substring( val = iv_name off = lv_index + 1 ).
        RETURN.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
