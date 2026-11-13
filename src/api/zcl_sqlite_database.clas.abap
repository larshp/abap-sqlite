* Minimal read-only database API. It opens a database through the table VFS
* and executes SELECT statements with the TableScan, Join, Filter, Group and
* Project operators. Phase 6 replaces this with the polished public API.
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

* create an empty database with an empty sqlite_schema b-tree on page 1
    CLASS-METHODS create
      IMPORTING iv_name            TYPE string
      RETURNING VALUE(ro_database) TYPE REF TO zcl_sqlite_database
      RAISING   zcx_sqlite_error.

    METHODS close.

    METHODS query
      IMPORTING iv_sql           TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_sqlite_error.

* prepare one statement; parameters can be bound before step( )
    METHODS prepare
      IMPORTING iv_sql              TYPE string
      RETURNING VALUE(ro_statement) TYPE REF TO zif_sqlite_statement
      RAISING   zcx_sqlite_error.

* execute one non-query statement; outside a transaction it autocommits
    METHODS execute
      IMPORTING iv_sql TYPE string
      RAISING   zcx_sqlite_error.

* issue COMMIT WORK after every SQLite commit, instead of leaving the ABAP
* LUW open so the caller can commit or roll back the bytes
    METHODS set_auto_commit_work
      IMPORTING iv_auto_commit_work TYPE abap_bool.

    METHODS last_insert_rowid
      RETURNING VALUE(rv_rowid) TYPE int8.

    METHODS changes
      RETURNING VALUE(rv_changes) TYPE i.

    METHODS plan_dump
      IMPORTING iv_sql         TYPE string
      RETURNING VALUE(rv_plan) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS constructor
      IMPORTING io_file   TYPE REF TO zif_sqlite_file
                io_pager  TYPE REF TO zcl_sqlite_pager
                io_schema TYPE REF TO zcl_sqlite_schema.

  PRIVATE SECTION.
    TYPES ty_from_columns TYPE zcl_sqlite_join=>ty_columns.

    TYPES: BEGIN OF ty_order_result,
             columns TYPE zcl_sqlite_project=>ty_columns,
             terms   TYPE zcl_sqlite_sort=>ty_terms,
           END OF ty_order_result.

    TYPES: BEGIN OF ty_from_plan,
             operator TYPE REF TO zif_sqlite_operator,
             columns  TYPE ty_from_columns,
           END OF ty_from_plan.

    TYPES: BEGIN OF ty_insert_column,
             column       TYPE zcl_sqlite_schema=>ty_column,
             source_index TYPE i,
           END OF ty_insert_column,
           ty_insert_columns TYPE STANDARD TABLE OF ty_insert_column WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_insert_result,
             rowid     TYPE int8,
             max_rowid TYPE int8,
             have_max  TYPE abap_bool,
           END OF ty_insert_result.

    TYPES: BEGIN OF ty_update_target,
             column_index TYPE i,
             is_rowid     TYPE abap_bool,
           END OF ty_update_target.

    TYPES: BEGIN OF ty_update_row,
             old_rowid TYPE int8,
             new_rowid TYPE int8,
             payload   TYPE xstring,
           END OF ty_update_row,
           ty_update_rows TYPE STANDARD TABLE OF ty_update_row WITH DEFAULT KEY.

    TYPES ty_source_indexes TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
    TYPES ty_upper_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_statement,
             create_table   TYPE REF TO zcl_sqlite_ast_create_table,
             create_index   TYPE REF TO zcl_sqlite_ast_create_index,
             insert         TYPE REF TO zcl_sqlite_ast_insert,
             update         TYPE REF TO zcl_sqlite_ast_update,
             delete         TYPE REF TO zcl_sqlite_ast_delete,
             drop           TYPE REF TO zcl_sqlite_ast_drop,
             transaction    TYPE REF TO zcl_sqlite_ast_transaction,
             schema_changed TYPE abap_bool,
             index_created  TYPE abap_bool,
             inserted       TYPE abap_bool,
             updated        TYPE abap_bool,
           END OF ty_statement.

    CONSTANTS c_max_rowid TYPE int8 VALUE '9223372036854775807'.

    DATA mo_file   TYPE REF TO zif_sqlite_file.
    DATA mo_pager  TYPE REF TO zcl_sqlite_pager.
    DATA mo_schema TYPE REF TO zcl_sqlite_schema.
    DATA mv_last_insert_rowid TYPE int8.
    DATA mv_changes           TYPE i.
    DATA mv_in_transaction    TYPE abap_bool.
    DATA mv_auto_commit_work  TYPE abap_bool.

    CLASS-METHODS empty_page
      RETURNING VALUE(rv_page) TYPE xstring
      RAISING   zcx_sqlite_error.

    METHODS query_select
      IMPORTING io_select        TYPE REF TO zcl_sqlite_ast_select
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_sqlite_error.

    METHODS classify_statement
      IMPORTING io_statement        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rs_statement) TYPE ty_statement
      RAISING   zcx_sqlite_error.

    METHODS execute_statement
      IMPORTING is_statement TYPE ty_statement
                iv_sql       TYPE string
      RAISING   zcx_sqlite_error.

    METHODS execute_create_table
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_create_table
                iv_sql       TYPE string
      RAISING   zcx_sqlite_error.

    METHODS execute_transaction
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_transaction
      RAISING   zcx_sqlite_error.

    METHODS commit_work_if_requested.

    METHODS execute_create_index
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_create_index
                iv_sql       TYPE string
      RAISING   zcx_sqlite_error.

    METHODS execute_drop
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_drop
      RAISING   zcx_sqlite_error.

    METHODS execute_drop_table
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_drop
      RAISING   zcx_sqlite_error.

    METHODS execute_drop_index
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_drop
      RAISING   zcx_sqlite_error.

    METHODS drop_table_tree
      IMPORTING is_table TYPE zcl_sqlite_schema=>ty_table
      RAISING   zcx_sqlite_error.

    METHODS drop_index_tree
      IMPORTING is_index TYPE zcl_sqlite_schema=>ty_index
      RAISING   zcx_sqlite_error.

    METHODS strip_schema_name
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_name) TYPE string.

    METHODS create_autoindexes
      IMPORTING iv_table_name TYPE string
      RAISING   zcx_sqlite_error.

    METHODS build_index
      IMPORTING is_table TYPE zcl_sqlite_schema=>ty_table
                is_index TYPE zcl_sqlite_schema=>ty_index
      RAISING   zcx_sqlite_error.

    METHODS rebuild_table_indexes
      IMPORTING is_table TYPE zcl_sqlite_schema=>ty_table
      RAISING   zcx_sqlite_error.

    METHODS insert_index_entries
      IMPORTING is_table  TYPE zcl_sqlite_schema=>ty_table
                it_values TYPE zcl_sqlite_record=>ty_values
                iv_rowid  TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS index_key
      IMPORTING is_table         TYPE zcl_sqlite_schema=>ty_table
                is_index         TYPE zcl_sqlite_schema=>ty_index
                it_values        TYPE zcl_sqlite_record=>ty_values
                iv_rowid         TYPE int8
      RETURNING VALUE(rt_values) TYPE zcl_sqlite_record=>ty_values
      RAISING   zcx_sqlite_error.

    METHODS validate_index_statement
      IMPORTING is_table     TYPE zcl_sqlite_schema=>ty_table
                io_statement TYPE REF TO zcl_sqlite_ast_create_index
      RAISING   zcx_sqlite_error.

    METHODS execute_insert
      IMPORTING io_statement  TYPE REF TO zcl_sqlite_ast_insert
      EXPORTING ev_changes    TYPE i
                ev_last_rowid TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS execute_delete
      IMPORTING io_statement      TYPE REF TO zcl_sqlite_ast_delete
      RETURNING VALUE(rv_changes) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS execute_update
      IMPORTING io_statement      TYPE REF TO zcl_sqlite_ast_update
      RETURNING VALUE(rv_changes) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS resolve_update_target
      IMPORTING is_table         TYPE zcl_sqlite_schema=>ty_table
                iv_name          TYPE string
      RETURNING VALUE(rs_target) TYPE ty_update_target
      RAISING   zcx_sqlite_error.

    METHODS update_rowid
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
                iv_type         TYPE string
      RETURNING VALUE(rv_rowid) TYPE int8
      RAISING   zcx_sqlite_error.

    METHODS update_context
      IMPORTING is_table          TYPE zcl_sqlite_schema=>ty_table
                iv_table_name     TYPE string
                iv_rowid          TYPE int8
                it_values         TYPE zcl_sqlite_record=>ty_values
      RETURNING VALUE(ro_context) TYPE REF TO zcl_sqlite_row.

    METHODS update_row
      IMPORTING is_table       TYPE zcl_sqlite_schema=>ty_table
                it_assignments TYPE zcl_sqlite_ast_update=>ty_assignments
                io_context     TYPE REF TO zcl_sqlite_row
                it_old_values  TYPE zcl_sqlite_record=>ty_values
                iv_rowid       TYPE int8
      RETURNING VALUE(rs_row)  TYPE ty_update_row
      RAISING   zcx_sqlite_error.

    METHODS rowid_select_name
      IMPORTING is_table       TYPE zcl_sqlite_schema=>ty_table
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    METHODS build_insert_columns
      IMPORTING io_statement      TYPE REF TO zcl_sqlite_ast_insert
                it_table_columns  TYPE zcl_sqlite_schema=>ty_columns
      RETURNING VALUE(rt_columns) TYPE ty_insert_columns
      RAISING   zcx_sqlite_error.

    METHODS insert_one
      IMPORTING is_table         TYPE zcl_sqlite_schema=>ty_table
                it_columns       TYPE ty_insert_columns
                it_input         TYPE ty_row
                iv_max_rowid     TYPE int8
                iv_have_max      TYPE abap_bool
      RETURNING VALUE(rs_result) TYPE ty_insert_result
      RAISING   zcx_sqlite_error.

    METHODS max_rowid
      IMPORTING is_table     TYPE zcl_sqlite_schema=>ty_table
      EXPORTING ev_max_rowid TYPE int8
                ev_have_max  TYPE abap_bool
      RAISING   zcx_sqlite_error.

    CLASS-METHODS normalized_sql
      IMPORTING iv_sql        TYPE string
      RETURNING VALUE(rv_sql) TYPE string.

    METHODS build_from_list
      IMPORTING it_from        TYPE zcl_sqlite_ast_select=>ty_from
                io_planner     TYPE REF TO zcl_sqlite_planner
      RETURNING VALUE(rs_plan) TYPE ty_from_plan
      RAISING   zcx_sqlite_error.

    METHODS build_from
      IMPORTING io_item        TYPE REF TO zcl_sqlite_ast_node
                io_planner     TYPE REF TO zcl_sqlite_planner
      RETURNING VALUE(rs_plan) TYPE ty_from_plan
      RAISING   zcx_sqlite_error.

    METHODS build_table
      IMPORTING io_table_ref   TYPE REF TO zcl_sqlite_ast_table_ref
                io_planner     TYPE REF TO zcl_sqlite_planner
      RETURNING VALUE(rs_plan) TYPE ty_from_plan
      RAISING   zcx_sqlite_error.

    METHODS build_join
      IMPORTING io_join        TYPE REF TO zcl_sqlite_ast_join
                io_planner     TYPE REF TO zcl_sqlite_planner
      RETURNING VALUE(rs_plan) TYPE ty_from_plan
      RAISING   zcx_sqlite_error.

    METHODS combine_plans
      IMPORTING is_left        TYPE ty_from_plan
                is_right       TYPE ty_from_plan
                iv_join_type   TYPE string
                io_on          TYPE REF TO zcl_sqlite_ast_node OPTIONAL
                it_using       TYPE zcl_sqlite_join=>ty_names OPTIONAL
      RETURNING VALUE(rs_plan) TYPE ty_from_plan
      RAISING   zcx_sqlite_error.

    METHODS natural_columns
      IMPORTING is_left         TYPE ty_from_plan
                is_right        TYPE ty_from_plan
      RETURNING VALUE(rt_names) TYPE zcl_sqlite_join=>ty_names.

    METHODS validate_using
      IMPORTING is_left  TYPE ty_from_plan
                is_right TYPE ty_from_plan
                it_using TYPE zcl_sqlite_join=>ty_names
      RAISING   zcx_sqlite_error.

    METHODS project_columns
      IMPORTING it_result_columns TYPE zcl_sqlite_ast_select=>ty_columns
                it_table_columns  TYPE ty_from_columns OPTIONAL
      RETURNING VALUE(rt_columns) TYPE zcl_sqlite_project=>ty_columns
      RAISING   zcx_sqlite_error.

    METHODS star_qualifier
      IMPORTING io_expression       TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_qualifier) TYPE string.

    METHODS resolve_order_terms
      IMPORTING it_order_by        TYPE zcl_sqlite_ast_order_by=>ty_list
                it_project_columns TYPE zcl_sqlite_project=>ty_columns
                iv_visible_count   TYPE i
      RETURNING VALUE(rs_result)   TYPE ty_order_result
      RAISING   zcx_sqlite_error.

    METHODS resolve_group_by
      IMPORTING it_group_by           TYPE zcl_sqlite_ast_select=>ty_expressions
                it_project_columns    TYPE zcl_sqlite_project=>ty_columns
                iv_visible_count      TYPE i
      RETURNING VALUE(rt_expressions) TYPE zcl_sqlite_ast_select=>ty_expressions
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

  METHOD create.
    DATA lo_vfs  TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lv_page TYPE xstring.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    IF lo_vfs->exists( iv_name ) = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |database { iv_name } already exists|.
    ENDIF.

    lv_page = empty_page( ).
    lo_file = lo_vfs->open( iv_name ).
    TRY.
        lo_file->write( iv_offset = 0
                        iv_data   = lv_page ).
        lo_file->sync( ).
        lo_file->close( ).
      CATCH cx_sy_range_out_of_bounds.
        lo_file->close( ).
        lo_vfs->delete( iv_name ).
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_ioerr
            iv_message = |could not write new database { iv_name }|.
    ENDTRY.

    ro_database = open( iv_name ).
  ENDMETHOD.

  METHOD constructor.
    mo_file = io_file.
    mo_pager = io_pager.
    mo_schema = io_schema.
  ENDMETHOD.

  METHOD empty_page.
    DATA lv_tree  TYPE xstring.
    DATA lv_zeros TYPE xstring.

    lv_tree = '0000000000000000'.
    TRY.
        lv_tree = zcl_sqlite_bytes=>write_u8(
          iv_data   = lv_tree
          iv_offset = 0
          iv_value  = zcl_sqlite_page=>c_table_leaf ).
        lv_tree = zcl_sqlite_bytes=>write_u16(
          iv_data   = lv_tree
          iv_offset = 5
          iv_value  = CONV int8( zcl_sqlite_header=>c_default_page_size ) ).
      CATCH cx_sy_conversion_overflow cx_sy_range_out_of_bounds.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_internal
            iv_message = 'could not build an empty sqlite_schema page'.
    ENDTRY.

    lv_zeros = repeat(
      val = '00'
      occ = zcl_sqlite_header=>c_default_page_size
          - zcl_sqlite_header=>c_header_size
          - xstrlen( lv_tree ) ).
    rv_page = zcl_sqlite_header=>build( ) && lv_tree && lv_zeros.
  ENDMETHOD.

  METHOD close.
    IF mo_pager IS BOUND.
      mo_pager->rollback( ).
    ENDIF.
    IF mo_file IS BOUND.
      mo_file->close( ).
    ENDIF.
    CLEAR mo_file.
    CLEAR mo_pager.
    CLEAR mo_schema.
  ENDMETHOD.

  METHOD last_insert_rowid.
    rv_rowid = mv_last_insert_rowid.
  ENDMETHOD.

  METHOD changes.
    rv_changes = mv_changes.
  ENDMETHOD.

  METHOD set_auto_commit_work.
    mv_auto_commit_work = iv_auto_commit_work.
  ENDMETHOD.

  METHOD prepare.
    IF mo_pager IS NOT BOUND OR mo_schema IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'database is closed'.
    ENDIF.

    ro_statement = NEW zcl_sqlite_statement(
      io_database = me
      iv_sql      = iv_sql ).
  ENDMETHOD.

  METHOD query.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_select    TYPE REF TO zcl_sqlite_ast_select.

    lo_statement = zcl_sqlite_parser=>parse_statement( iv_sql ).
    IF lo_statement IS NOT INSTANCE OF zcl_sqlite_ast_select.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'only SELECT statements are supported'.
    ENDIF.
    lo_select ?= lo_statement.

    rs_result = query_select( lo_select ).
  ENDMETHOD.

  METHOD query_select.
    DATA lo_select          TYPE REF TO zcl_sqlite_ast_select.
    DATA lo_where           TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_having          TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_operator        TYPE REF TO zif_sqlite_operator.
    DATA lo_planner         TYPE REF TO zcl_sqlite_planner.
    DATA lo_row             TYPE REF TO zcl_sqlite_row.
    DATA lt_from            TYPE zcl_sqlite_ast_select=>ty_from.
    DATA lt_result_columns  TYPE zcl_sqlite_ast_select=>ty_columns.
    DATA lt_project_columns TYPE zcl_sqlite_project=>ty_columns.
    DATA lt_group_by        TYPE zcl_sqlite_ast_select=>ty_expressions.
    DATA lt_order_by        TYPE zcl_sqlite_ast_order_by=>ty_list.
    DATA ls_order_result    TYPE ty_order_result.
    DATA ls_project_column  TYPE zcl_sqlite_project=>ty_column.
    DATA ls_from_plan       TYPE ty_from_plan.
    DATA lt_order_terms     TYPE zcl_sqlite_sort=>ty_terms.
    DATA lt_result_row      TYPE ty_row.
    DATA lt_values          TYPE zcl_sqlite_record=>ty_values.
    DATA lo_cell_value      TYPE REF TO zcl_sqlite_value.
    DATA lv_visible_count   TYPE i.
    DATA lv_aggregate       TYPE abap_bool.

    lo_select = io_select.
    IF mo_pager IS NOT BOUND OR mo_schema IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'database is closed'.
    ENDIF.

    lo_where = lo_select->get_where( ).
    lt_from = lo_select->get_from( ).
    lo_planner = NEW zcl_sqlite_planner(
      io_schema = mo_schema
      it_from   = lt_from
      io_where  = lo_where ).
    IF lines( lt_from ) > 0.
      ls_from_plan = build_from_list(
        it_from    = lt_from
        io_planner = lo_planner ).
    ENDIF.

    lt_result_columns = lo_select->get_columns( ).
    IF lines( lt_result_columns ) = 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'SELECT statement has no result columns'.
    ENDIF.
    lt_project_columns = project_columns(
      it_result_columns = lt_result_columns
      it_table_columns  = ls_from_plan-columns ).
    lv_visible_count = lines( lt_project_columns ).
    lt_order_by = lo_select->get_order_by( ).
    ls_order_result = resolve_order_terms(
      it_order_by        = lt_order_by
      it_project_columns = lt_project_columns
      iv_visible_count   = lv_visible_count ).
    lt_project_columns = ls_order_result-columns.
    lt_order_terms = ls_order_result-terms.

    lt_group_by = resolve_group_by(
      it_group_by        = lo_select->get_group_by( )
      it_project_columns = lt_project_columns
      iv_visible_count   = lv_visible_count ).
    lo_having = lo_select->get_having( ).

    IF lines( lt_group_by ) > 0 OR lo_having IS BOUND.
      lv_aggregate = abap_true.
    ELSE.
      LOOP AT lt_project_columns INTO ls_project_column.
        IF zcl_sqlite_expr_eval=>contains_aggregate( ls_project_column-expression ) = abap_true.
          lv_aggregate = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF ls_from_plan-operator IS BOUND.
      lo_operator = ls_from_plan-operator.
      IF lo_where IS BOUND.
        lo_operator = NEW zcl_sqlite_filter(
          io_source = lo_operator
          io_where  = lo_where ).
      ENDIF.
    ENDIF.

    IF lv_aggregate = abap_true.
      lo_operator = NEW zcl_sqlite_group(
        io_source        = lo_operator
        it_group_by      = lt_group_by
        it_columns       = lt_project_columns
        iv_visible_count = lv_visible_count
        io_having        = lo_having ).
    ELSE.
      lo_operator = NEW zcl_sqlite_project(
        io_source  = lo_operator
        it_columns = lt_project_columns ).
    ENDIF.

    IF lo_select->get_distinct( ) = abap_true.
      lo_operator = NEW zcl_sqlite_distinct(
        io_source        = lo_operator
        iv_visible_count = lv_visible_count ).
    ENDIF.
    IF lines( lt_order_terms ) > 0.
      lo_operator = NEW zcl_sqlite_sort(
        io_source = lo_operator
        it_terms  = lt_order_terms ).
    ENDIF.
    IF lo_select->get_limit( ) IS BOUND OR lo_select->get_offset( ) IS BOUND.
      lo_operator = NEW zcl_sqlite_limit(
        io_source = lo_operator
        io_limit  = lo_select->get_limit( )
        io_offset = lo_select->get_offset( ) ).
    ENDIF.

    lo_operator->open( ).
    WHILE lo_operator->next( ) = abap_true.
      lo_row = lo_operator->row( ).
      lt_values = lo_row->values( ).
      CLEAR lt_result_row.
      LOOP AT lt_values INTO lo_cell_value FROM 1 TO lv_visible_count.
        APPEND lo_cell_value TO lt_result_row.
      ENDLOOP.
      APPEND lt_result_row TO rs_result-rows.
    ENDWHILE.

    LOOP AT lt_project_columns INTO ls_project_column FROM 1 TO lv_visible_count.
      APPEND ls_project_column-name TO rs_result-columns.
    ENDLOOP.
  ENDMETHOD.

  METHOD execute.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.
    DATA ls_statement TYPE ty_statement.

    IF mo_pager IS NOT BOUND OR mo_schema IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'database is closed'.
    ENDIF.

    lo_statement = zcl_sqlite_parser=>parse_statement( iv_sql ).
    ls_statement = classify_statement( lo_statement ).

    IF ls_statement-transaction IS BOUND.
      execute_transaction( ls_statement-transaction ).
      RETURN.
    ENDIF.

    execute_statement(
      is_statement = ls_statement
      iv_sql       = iv_sql ).
  ENDMETHOD.

  METHOD classify_statement.
    IF io_statement IS INSTANCE OF zcl_sqlite_ast_create_table.
      rs_statement-create_table ?= io_statement.
      rs_statement-schema_changed = abap_true.
    ELSEIF io_statement IS INSTANCE OF zcl_sqlite_ast_create_index.
      rs_statement-create_index ?= io_statement.
      rs_statement-index_created = abap_true.
    ELSEIF io_statement IS INSTANCE OF zcl_sqlite_ast_insert.
      rs_statement-insert ?= io_statement.
      rs_statement-inserted = abap_true.
    ELSEIF io_statement IS INSTANCE OF zcl_sqlite_ast_update.
      rs_statement-update ?= io_statement.
      rs_statement-updated = abap_true.
    ELSEIF io_statement IS INSTANCE OF zcl_sqlite_ast_delete.
      rs_statement-delete ?= io_statement.
    ELSEIF io_statement IS INSTANCE OF zcl_sqlite_ast_drop.
      rs_statement-drop ?= io_statement.
      rs_statement-schema_changed = abap_true.
    ELSEIF io_statement IS INSTANCE OF zcl_sqlite_ast_transaction.
      rs_statement-transaction ?= io_statement.
    ELSE.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_message = 'only CREATE TABLE/INDEX, DROP TABLE/INDEX, INSERT, UPDATE, DELETE'
                    && ' and transaction control are supported'.
    ENDIF.
  ENDMETHOD.

  METHOD execute_statement.
    DATA lv_changes TYPE i.
    DATA lv_last_rowid TYPE int8.

    TRY.
        IF mv_in_transaction = abap_true.
          mo_pager->begin_statement( ).
        ENDIF.

        IF is_statement-drop IS BOUND.
          execute_drop( is_statement-drop ).
        ELSEIF is_statement-schema_changed = abap_true.
          execute_create_table(
            io_statement = is_statement-create_table
            iv_sql       = iv_sql ).
        ELSEIF is_statement-index_created = abap_true.
          execute_create_index(
            io_statement = is_statement-create_index
            iv_sql       = iv_sql ).
        ELSEIF is_statement-inserted = abap_true.
          execute_insert(
            EXPORTING
              io_statement  = is_statement-insert
            IMPORTING
              ev_changes    = lv_changes
              ev_last_rowid = lv_last_rowid ).
        ELSEIF is_statement-updated = abap_true.
          lv_changes = execute_update( is_statement-update ).
        ELSE.
          lv_changes = execute_delete( is_statement-delete ).
        ENDIF.

        IF mv_in_transaction = abap_true.
          mo_pager->commit_statement( ).
        ELSE.
* autocommit per statement: write the statement's pages to the file now
          mo_pager->commit( ).
        ENDIF.

        IF is_statement-schema_changed = abap_true
            OR is_statement-index_created = abap_true.
          mo_schema = zcl_sqlite_schema=>read( mo_pager ).
          mv_changes = 0.
        ELSE.
          mv_changes = lv_changes.
          IF is_statement-inserted = abap_true AND lv_changes > 0.
            mv_last_insert_rowid = lv_last_rowid.
          ENDIF.
        ENDIF.

        IF mv_in_transaction = abap_false.
          commit_work_if_requested( ).
        ENDIF.
      CATCH zcx_sqlite_error INTO DATA(lo_error).
        IF mv_in_transaction = abap_true.
* keep the earlier statements of the transaction, drop only this one
          mo_pager->rollback_statement( ).
        ELSE.
          mo_pager->rollback( ).
        ENDIF.
        RAISE EXCEPTION lo_error.
    ENDTRY.
  ENDMETHOD.

  METHOD execute_transaction.
    DATA lv_action TYPE string.

    lv_action = to_upper( io_statement->get_action( ) ).

    CASE lv_action.
      WHEN 'BEGIN'.
        IF mv_in_transaction = abap_true.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = 'cannot start a transaction within a transaction'.
        ENDIF.
        mv_in_transaction = abap_true.
      WHEN 'COMMIT' OR 'END'.
        IF mv_in_transaction = abap_false.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = 'cannot commit - no transaction is active'.
        ENDIF.
        mo_pager->commit( ).
        mv_in_transaction = abap_false.
        commit_work_if_requested( ).
      WHEN 'ROLLBACK'.
        IF io_statement->get_to( ) IS NOT INITIAL
            OR io_statement->is_savepoint( ) = abap_true.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = 'ROLLBACK TO SAVEPOINT is not supported'.
        ENDIF.
        IF mv_in_transaction = abap_false.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = 'cannot rollback - no transaction is active'.
        ENDIF.
        mo_pager->rollback( ).
        mv_in_transaction = abap_false.
        mo_schema = zcl_sqlite_schema=>read( mo_pager ).
        mv_changes = 0.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = 'unknown transaction control statement'.
    ENDCASE.
  ENDMETHOD.

  METHOD commit_work_if_requested.
    IF mv_auto_commit_work = abap_true.
      COMMIT WORK.
    ENDIF.
  ENDMETHOD.

  METHOD execute_create_table.
    DATA ls_existing TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_entry TYPE zcl_sqlite_catalog=>ty_entry.
    DATA lv_root_page TYPE i.
    DATA lv_name TYPE string.

    lv_name = io_statement->get_name( ).
    IF io_statement->is_temporary( ) = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'temporary tables are not supported'.
    ENDIF.
    IF io_statement->is_without_rowid( ) = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'WITHOUT ROWID tables are not supported yet'.
    ENDIF.

    ls_existing = mo_schema->table( lv_name ).
    IF ls_existing-name IS NOT INITIAL.
      IF io_statement->is_if_not_exists( ) = abap_true.
        RETURN.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |table { lv_name } already exists|.
    ENDIF.

    lv_root_page = mo_pager->allocate_page( ).
    mo_pager->put_page(
      iv_page = lv_root_page
      iv_data = zcl_sqlite_btree=>empty_table_leaf(
        mo_pager->page_size( ) ) ).

    ls_entry-type = 'table'.
    ls_entry-name = lv_name.
    ls_entry-tbl_name = lv_name.
    ls_entry-rootpage = lv_root_page.
    ls_entry-sql = normalized_sql( iv_sql ).
    ls_entry-sql_is_null = abap_false.
    zcl_sqlite_catalog=>append(
      io_pager = mo_pager
      is_entry = ls_entry ).

    create_autoindexes( lv_name ).

    mo_pager->bump_schema_cookie( ).
  ENDMETHOD.

  METHOD execute_create_index.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_existing TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_entry TYPE zcl_sqlite_catalog=>ty_entry.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA lv_table_name TYPE string.
    DATA lv_name TYPE string.
    DATA lv_root_page TYPE i.

    lv_name = io_statement->get_name( ).
    lv_table_name = io_statement->get_table_name( ).
    ls_table = mo_schema->table( lv_table_name ).
    IF ls_table-name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |no such table: { lv_table_name }|.
    ENDIF.
    IF ls_table-without_rowid = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'WITHOUT ROWID tables are not supported yet'.
    ENDIF.

    ls_existing = mo_schema->index( lv_name ).
    IF ls_existing-name IS NOT INITIAL.
      IF io_statement->is_if_not_exists( ) = abap_true.
        RETURN.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |index { lv_name } already exists|.
    ENDIF.

    validate_index_statement(
      is_table     = ls_table
      io_statement = io_statement ).

    lv_root_page = mo_pager->allocate_page( ).
    mo_pager->put_page(
      iv_page = lv_root_page
      iv_data = zcl_sqlite_btree=>empty_index_leaf(
        mo_pager->page_size( ) ) ).

    ls_entry-type = 'index'.
    ls_entry-name = lv_name.
    ls_entry-tbl_name = lv_table_name.
    ls_entry-rootpage = lv_root_page.
    ls_entry-sql = normalized_sql( iv_sql ).
    ls_entry-sql_is_null = abap_false.
    zcl_sqlite_catalog=>append(
      io_pager = mo_pager
      is_entry = ls_entry ).

    lo_schema = zcl_sqlite_schema=>read( mo_pager ).
    ls_index = lo_schema->index( lv_name ).
    ls_table = lo_schema->table( lv_table_name ).
    build_index(
      is_table = ls_table
      is_index = ls_index ).

    mo_pager->bump_schema_cookie( ).
  ENDMETHOD.

  METHOD execute_drop.
    DATA lv_object_type TYPE string.

    lv_object_type = to_upper( io_statement->get_object_type( ) ).
    CASE lv_object_type.
      WHEN 'TABLE'.
        execute_drop_table( io_statement ).
      WHEN 'INDEX'.
        execute_drop_index( io_statement ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = |unsupported DROP object: { io_statement->get_object_type( ) }|.
    ENDCASE.
  ENDMETHOD.

  METHOD execute_drop_table.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.
    DATA lt_names TYPE zcl_sqlite_catalog=>ty_names.
    DATA lv_name TYPE string.

    lv_name = strip_schema_name( io_statement->get_name( ) ).
    ls_table = mo_schema->table( lv_name ).
    IF ls_table-name IS INITIAL.
      IF io_statement->is_if_exists( ) = abap_true.
        RETURN.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |no such table: { lv_name }|.
    ENDIF.
    IF ls_table-without_rowid = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'WITHOUT ROWID tables are not supported yet'.
    ENDIF.

    APPEND ls_table-name TO lt_names.
    LOOP AT ls_table-indexes INTO ls_index.
      APPEND ls_index-name TO lt_names.
      IF ls_index-rootpage > 0.
        drop_index_tree( ls_index ).
      ENDIF.
    ENDLOOP.

    drop_table_tree( ls_table ).
    zcl_sqlite_catalog=>remove(
      io_pager = mo_pager
      it_names = lt_names ).
    mo_pager->bump_schema_cookie( ).
  ENDMETHOD.

  METHOD execute_drop_index.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.
    DATA lt_names TYPE zcl_sqlite_catalog=>ty_names.
    DATA lv_name TYPE string.

    lv_name = strip_schema_name( io_statement->get_name( ) ).
    ls_index = mo_schema->index( lv_name ).
    IF ls_index-name IS INITIAL.
      IF io_statement->is_if_exists( ) = abap_true.
        RETURN.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |no such index: { lv_name }|.
    ENDIF.

    IF ls_index-origin = 'u' OR ls_index-origin = 'pk'.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'index associated with UNIQUE or PRIMARY KEY constraint cannot be dropped'.
    ENDIF.

    IF ls_index-rootpage > 0.
      drop_index_tree( ls_index ).
    ENDIF.
    APPEND ls_index-name TO lt_names.
    zcl_sqlite_catalog=>remove(
      io_pager = mo_pager
      it_names = lt_names ).
    mo_pager->bump_schema_cookie( ).
  ENDMETHOD.

  METHOD drop_table_tree.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.

    IF is_table-rootpage <= 0.
      RETURN.
    ENDIF.
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = mo_pager
      iv_root_page = CONV i( is_table-rootpage ) ).
    lo_writer->free_tree( ).
  ENDMETHOD.

  METHOD drop_index_tree.
    DATA lo_writer TYPE REF TO zcl_sqlite_index_writer.

    IF is_index-rootpage <= 0.
      RETURN.
    ENDIF.
    lo_writer = NEW zcl_sqlite_index_writer(
      io_pager     = mo_pager
      iv_root_page = CONV i( is_index-rootpage ) ).
    lo_writer->free_tree( ).
  ENDMETHOD.

  METHOD strip_schema_name.
    rv_name = iv_name.
    IF strlen( iv_name ) > 5
        AND to_upper( iv_name(5) ) = 'MAIN.'.
      rv_name = iv_name+5.
    ENDIF.
  ENDMETHOD.

  METHOD create_autoindexes.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA lt_indexes TYPE zcl_sqlite_schema=>ty_indexes.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_entry TYPE zcl_sqlite_catalog=>ty_entry.
    DATA lv_root_page TYPE i.

    lo_schema = zcl_sqlite_schema=>read( mo_pager ).
    lt_indexes = lo_schema->indexes_in_definition_order( iv_table_name ).
    LOOP AT lt_indexes INTO ls_index.
      IF ls_index-rootpage > 0.
        CONTINUE.
      ENDIF.

      lv_root_page = mo_pager->allocate_page( ).
      mo_pager->put_page(
        iv_page = lv_root_page
        iv_data = zcl_sqlite_btree=>empty_index_leaf(
          mo_pager->page_size( ) ) ).

      CLEAR ls_entry.
      ls_entry-type = 'index'.
      ls_entry-name = ls_index-name.
      ls_entry-tbl_name = ls_index-tbl_name.
      ls_entry-rootpage = lv_root_page.
      ls_entry-sql_is_null = abap_true.
      zcl_sqlite_catalog=>append(
        io_pager = mo_pager
        is_entry = ls_entry ).
    ENDLOOP.
  ENDMETHOD.

  METHOD build_index.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lo_writer TYPE REF TO zcl_sqlite_index_writer.
    DATA lt_values TYPE zcl_sqlite_record=>ty_values.
    DATA lt_key TYPE zcl_sqlite_record=>ty_values.
    DATA lv_root_page TYPE i.

    lv_root_page = is_index-rootpage.
    lo_writer = NEW zcl_sqlite_index_writer(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).
    lo_writer->clear_tree( ).

    lv_root_page = is_table-rootpage.
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).
    IF lo_cursor->first( ) = abap_false.
      RETURN.
    ENDIF.

    DO.
      lt_values = lo_cursor->values( ).
      lt_key = index_key(
        is_table  = is_table
        is_index  = is_index
        it_values = lt_values
        iv_rowid  = lo_cursor->rowid( ) ).
      lo_writer->insert_entry(
        it_values        = lt_key
        iv_unique        = is_index-is_unique
        iv_prefix_length = lines( is_index-columns ) ).
      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD rebuild_table_indexes.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    LOOP AT is_table-indexes INTO ls_index.
      IF ls_index-rootpage <= 0.
        CONTINUE.
      ENDIF.
      build_index(
        is_table = is_table
        is_index = ls_index ).
    ENDLOOP.
  ENDMETHOD.

  METHOD insert_index_entries.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.
    DATA lo_writer TYPE REF TO zcl_sqlite_index_writer.
    DATA lt_key TYPE zcl_sqlite_record=>ty_values.
    DATA lv_root_page TYPE i.

    LOOP AT is_table-indexes INTO ls_index.
      IF ls_index-rootpage <= 0.
        CONTINUE.
      ENDIF.
      lv_root_page = ls_index-rootpage.
      lo_writer = NEW zcl_sqlite_index_writer(
        io_pager     = mo_pager
        iv_root_page = lv_root_page ).
      lt_key = index_key(
        is_table  = is_table
        is_index  = ls_index
        it_values = it_values
        iv_rowid  = iv_rowid ).
      lo_writer->insert_entry(
        it_values        = lt_key
        iv_unique        = ls_index-is_unique
        iv_prefix_length = lines( ls_index-columns ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD index_key.
    DATA ls_index_column TYPE zcl_sqlite_schema=>ty_index_column.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_found TYPE abap_bool.
    DATA lv_name TYPE string.

    LOOP AT is_index-columns INTO ls_index_column.
      CLEAR: lo_value, lv_found.
      lv_name = to_upper( ls_index_column-name ).

      LOOP AT is_table-columns INTO ls_column.
        IF to_upper( ls_column-name ) = lv_name.
          READ TABLE it_values INTO lo_value INDEX ls_column-cid + 1.
          IF sy-subrc <> 0.
            lo_value = zcl_sqlite_value=>null( ).
          ENDIF.
          IF ls_column-rowid_alias = abap_true.
            lo_value = zcl_sqlite_value=>integer( iv_rowid ).
          ENDIF.
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_found = abap_false.
        IF lv_name = 'ROWID' OR lv_name = '_ROWID_' OR lv_name = 'OID'.
          lo_value = zcl_sqlite_value=>integer( iv_rowid ).
        ELSE.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = |no such column: { ls_index_column-name }|.
        ENDIF.
      ENDIF.

      APPEND lo_value TO rt_values.
    ENDLOOP.

    APPEND zcl_sqlite_value=>integer( iv_rowid ) TO rt_values.
  ENDMETHOD.

  METHOD validate_index_statement.
    DATA lt_columns TYPE zcl_sqlite_ast_create_index=>ty_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lv_found TYPE abap_bool.
    DATA lv_name TYPE string.
    DATA lv_collation TYPE string.
    DATA lv_order TYPE string.

    IF io_statement->get_where( ) IS BOUND.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'partial indexes are not supported yet'.
    ENDIF.

    lt_columns = io_statement->get_columns( ).
    LOOP AT lt_columns INTO lo_column.
      lv_name = to_upper( lo_column->get_name( ) ).
      lv_collation = to_upper( lo_column->get_collation( ) ).
      lv_order = to_upper( lo_column->get_order( ) ).
      IF lv_collation IS NOT INITIAL AND lv_collation <> 'BINARY'.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = |collation { lo_column->get_collation( ) } is not supported yet|.
      ENDIF.
      IF lv_order = 'DESC'.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = 'descending indexes are not supported yet'.
      ENDIF.

      lv_found = abap_false.
      LOOP AT is_table-columns INTO ls_column.
        IF to_upper( ls_column-name ) = lv_name.
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false
          AND lv_name <> 'ROWID'
          AND lv_name <> '_ROWID_'
          AND lv_name <> 'OID'.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = |no such column: { lo_column->get_name( ) }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD execute_insert.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA lt_columns TYPE ty_insert_columns.
    DATA ls_insert_column TYPE ty_insert_column.
    DATA lt_input_rows TYPE ty_rows.
    DATA ls_input TYPE ty_row.
    DATA lo_values TYPE REF TO zcl_sqlite_ast_values.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_row TYPE REF TO zcl_sqlite_ast_values_row.
    DATA lo_select TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_ast_select TYPE REF TO zcl_sqlite_ast_select.
    DATA lt_expressions TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA rs_select TYPE ty_result.
    DATA lv_source_count TYPE i.
    DATA lv_max_rowid TYPE int8.
    DATA lv_have_max TYPE abap_bool.
    DATA ls_result TYPE ty_insert_result.
    DATA lv_changes TYPE i.
    DATA lv_last_rowid TYPE int8.

    IF io_statement->get_conflict( ) IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'conflict clauses are not supported yet'.
    ENDIF.

    ls_table = mo_schema->table( io_statement->get_table( ) ).
    IF ls_table-name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |no such table: { io_statement->get_table( ) }|.
    ENDIF.
    IF ls_table-without_rowid = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'WITHOUT ROWID tables are not supported yet'.
    ENDIF.

    lt_columns = build_insert_columns(
      io_statement     = io_statement
      it_table_columns = ls_table-columns ).

    IF io_statement->is_default_values( ) = abap_true.
      IF lines( io_statement->get_columns( ) ) > 0.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = 'DEFAULT VALUES cannot be used with a column list'.
      ENDIF.
      LOOP AT lt_columns INTO ls_insert_column.
        CLEAR ls_insert_column-source_index.
        MODIFY lt_columns FROM ls_insert_column INDEX sy-tabix.
      ENDLOOP.
      lv_source_count = 0.
      APPEND ls_input TO lt_input_rows.
    ELSE.
      lv_source_count = lines( io_statement->get_columns( ) ).
      IF lv_source_count = 0.
        lv_source_count = lines( ls_table-columns ).
      ENDIF.

      lo_values = io_statement->get_values( ).
      IF lo_values IS BOUND.
        LOOP AT lo_values->get_rows( ) INTO lo_row.
          CLEAR ls_input.
          lt_expressions = lo_row->get_values( ).
          IF lines( lt_expressions ) <> lv_source_count.
            RAISE EXCEPTION TYPE zcx_sqlite_error
              EXPORTING
                iv_code    = zcx_sqlite_error=>sqlite_error
                iv_message = |table { ls_table-name } has { lv_source_count } columns| &&
                             | but { lines( lt_expressions ) } values were supplied|.
          ENDIF.
          LOOP AT lt_expressions INTO lo_expression.
            lo_value = zcl_sqlite_expr_eval=>evaluate( lo_expression ).
            APPEND lo_value TO ls_input.
          ENDLOOP.
          APPEND ls_input TO lt_input_rows.
        ENDLOOP.
      ELSE.
        lo_select = io_statement->get_select( ).
        IF lo_select IS NOT INSTANCE OF zcl_sqlite_ast_select.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = 'unsupported INSERT source'.
        ENDIF.
        lo_ast_select ?= lo_select.
        rs_select = query_select( lo_ast_select ).
        IF lines( rs_select-columns ) <> lv_source_count.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = |table { ls_table-name } has { lv_source_count } columns| &&
                           | but { lines( rs_select-columns ) } values were supplied|.
        ENDIF.
        lt_input_rows = rs_select-rows.
      ENDIF.
    ENDIF.

    max_rowid(
      EXPORTING
        is_table     = ls_table
      IMPORTING
        ev_max_rowid = lv_max_rowid
        ev_have_max  = lv_have_max ).

    LOOP AT lt_input_rows INTO ls_input.
      ls_result = insert_one(
        is_table     = ls_table
        it_columns   = lt_columns
        it_input     = ls_input
        iv_max_rowid = lv_max_rowid
        iv_have_max  = lv_have_max ).
      lv_max_rowid = ls_result-max_rowid.
      lv_have_max = ls_result-have_max.
      lv_last_rowid = ls_result-rowid.
      lv_changes = lv_changes + 1.
    ENDLOOP.

    ev_changes = lv_changes.
    IF lv_changes > 0.
      ev_last_rowid = lv_last_rowid.
    ENDIF.
  ENDMETHOD.

  METHOD execute_delete.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA lt_columns TYPE zcl_sqlite_ast_select=>ty_columns.
    DATA lt_from TYPE zcl_sqlite_ast_select=>ty_from.
    DATA lo_result_column TYPE REF TO zcl_sqlite_ast_result_column.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_name.
    DATA lo_table_ref TYPE REF TO zcl_sqlite_ast_table_ref.
    DATA lo_select TYPE REF TO zcl_sqlite_ast_select.
    DATA rs_result TYPE ty_result.
    DATA ls_row TYPE ty_row.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lv_root_page TYPE i.
    DATA lv_rowid TYPE int8.
    DATA lv_changes TYPE i.

    ls_table = mo_schema->table( io_statement->get_table( ) ).
    IF ls_table-name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |no such table: { io_statement->get_table( ) }|.
    ENDIF.
    IF ls_table-without_rowid = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'WITHOUT ROWID tables are not supported yet'.
    ENDIF.
    lo_expression = NEW zcl_sqlite_ast_name(
      iv_kind = zcl_sqlite_ast_name=>c_column
      iv_text = rowid_select_name( ls_table ) ).
    lo_result_column = NEW zcl_sqlite_ast_result_column(
      io_expression = lo_expression ).
    APPEND lo_result_column TO lt_columns.

    lo_table_ref = NEW zcl_sqlite_ast_table_ref(
      iv_name  = io_statement->get_table( )
      iv_alias = io_statement->get_alias( ) ).
    APPEND lo_table_ref TO lt_from.

    lo_select = NEW zcl_sqlite_ast_select(
      it_columns = lt_columns
      it_from    = lt_from
      io_where   = io_statement->get_where( ) ).

    rs_result = query_select( lo_select ).

    lv_root_page = ls_table-rootpage.
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).

    LOOP AT rs_result-rows INTO ls_row.
      READ TABLE ls_row INTO lo_value INDEX 1.
      lv_rowid = lo_value->as_integer( ).
      lo_writer->delete_row( lv_rowid ).
      lv_changes = lv_changes + 1.
    ENDLOOP.

    rebuild_table_indexes( ls_table ).

    rv_changes = lv_changes.
  ENDMETHOD.

  METHOD execute_update.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA lt_assignments TYPE zcl_sqlite_ast_update=>ty_assignments.
    DATA lo_assignment TYPE REF TO zcl_sqlite_ast_assignment.
    DATA ls_target TYPE ty_update_target.
    DATA lo_where TYPE REF TO zcl_sqlite_ast_node.
    DATA lt_old_values TYPE zcl_sqlite_record=>ty_values.
    DATA lo_context TYPE REF TO zcl_sqlite_row.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lt_pending TYPE ty_update_rows.
    DATA ls_pending TYPE ty_update_row.
    DATA lv_rowid TYPE int8.
    DATA lv_table_name TYPE string.
    DATA lv_matches_where TYPE abap_bool.
    DATA lv_root_page TYPE i.

    IF io_statement->get_conflict( ) IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'conflict clauses are not supported yet'.
    ENDIF.

    ls_table = mo_schema->table( io_statement->get_table( ) ).
    IF ls_table-name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = |no such table: { io_statement->get_table( ) }|.
    ENDIF.
    IF ls_table-without_rowid = abap_true.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'WITHOUT ROWID tables are not supported yet'.
    ENDIF.
    IF lines( io_statement->get_from( ) ) > 0.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'UPDATE ... FROM is not supported yet'.
    ENDIF.

    lt_assignments = io_statement->get_assignments( ).
    LOOP AT lt_assignments INTO lo_assignment.
      ls_target = resolve_update_target(
        is_table = ls_table
        iv_name  = lo_assignment->get_column( ) ).
    ENDLOOP.

    lo_where = io_statement->get_where( ).
    lv_table_name = io_statement->get_alias( ).
    IF lv_table_name IS INITIAL.
      lv_table_name = ls_table-name.
    ENDIF.

    lv_root_page = ls_table-rootpage.
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).
    IF lo_cursor->first( ) = abap_false.
      RETURN.
    ENDIF.

    DO.
      lv_rowid = lo_cursor->rowid( ).
      lt_old_values = lo_cursor->values( ).
      lo_context = update_context(
        is_table      = ls_table
        iv_table_name = lv_table_name
        iv_rowid      = lv_rowid
        it_values     = lt_old_values ).

      lv_matches_where = abap_true.
      IF lo_where IS BOUND.
        lo_value = zcl_sqlite_expr_eval=>evaluate(
          io_expression = lo_where
          io_context    = lo_context ).
        lv_matches_where = zcl_sqlite_expr_eval=>is_true( lo_value ).
      ENDIF.

      IF lv_matches_where = abap_true.
        APPEND update_row(
          is_table       = ls_table
          it_assignments = lt_assignments
          io_context     = lo_context
          it_old_values  = lt_old_values
          iv_rowid       = lv_rowid ) TO lt_pending.
      ENDIF.

      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.

    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).
    LOOP AT lt_pending INTO ls_pending.
      lo_writer->delete_row( ls_pending-old_rowid ).
      lo_writer->insert_row(
        iv_rowid   = ls_pending-new_rowid
        iv_payload = ls_pending-payload ).
    ENDLOOP.

    rebuild_table_indexes( ls_table ).

    rv_changes = lines( lt_pending ).
  ENDMETHOD.

  METHOD resolve_update_target.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lv_name TYPE string.

    lv_name = to_upper( iv_name ).
    LOOP AT is_table-columns INTO ls_column.
      IF to_upper( ls_column-name ) = lv_name.
        rs_target-column_index = sy-tabix.
        rs_target-is_rowid = ls_column-rowid_alias.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lv_name = 'ROWID' OR lv_name = '_ROWID_' OR lv_name = 'OID'.
      rs_target-is_rowid = abap_true.
      RETURN.
    ENDIF.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_error
        iv_message = |no such column: { iv_name }|.
  ENDMETHOD.

  METHOD update_rowid.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    lo_value = zcl_sqlite_expr_eval=>apply_affinity(
      io_value = io_value
      iv_type  = iv_type ).
    IF lo_value->is_null( ) = abap_true
        OR lo_value->value_type( ) <> zcl_sqlite_value=>c_integer.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING
          iv_code    = zcx_sqlite_error=>sqlite_error
          iv_message = 'datatype mismatch'.
    ENDIF.
    rv_rowid = lo_value->as_integer( ).
  ENDMETHOD.

  METHOD update_context.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    ro_context = NEW zcl_sqlite_row( ).
    LOOP AT is_table-columns INTO ls_column.
      READ TABLE it_values INTO lo_value INDEX sy-tabix.
      IF sy-subrc <> 0.
        lo_value = zcl_sqlite_value=>null( ).
      ENDIF.
      IF ls_column-rowid_alias = abap_true
          AND lo_value->is_null( ) = abap_true.
        lo_value = zcl_sqlite_value=>integer( iv_rowid ).
      ENDIF.
      ro_context->add_cell(
        iv_name       = ls_column-name
        iv_table_name = iv_table_name
        io_value      = lo_value ).
    ENDLOOP.

    ro_context->add_cell(
      iv_name       = 'rowid'
      iv_table_name = iv_table_name
      io_value      = zcl_sqlite_value=>integer( iv_rowid ) ).
    ro_context->add_cell(
      iv_name       = '_rowid_'
      iv_table_name = iv_table_name
      io_value      = zcl_sqlite_value=>integer( iv_rowid ) ).
    ro_context->add_cell(
      iv_name       = 'oid'
      iv_table_name = iv_table_name
      io_value      = zcl_sqlite_value=>integer( iv_rowid ) ).
  ENDMETHOD.

  METHOD update_row.
    DATA lt_new_values TYPE zcl_sqlite_record=>ty_values.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lo_assignment TYPE REF TO zcl_sqlite_ast_assignment.
    DATA ls_target TYPE ty_update_target.
    DATA lv_new_rowid TYPE int8.
    DATA lv_type TYPE string.

    LOOP AT is_table-columns INTO ls_column.
      IF ls_column-rowid_alias = abap_true.
        APPEND zcl_sqlite_value=>null( ) TO lt_new_values.
      ELSE.
        READ TABLE it_old_values INTO lo_value INDEX sy-tabix.
        IF sy-subrc <> 0.
          lo_value = zcl_sqlite_value=>null( ).
        ENDIF.
        APPEND lo_value TO lt_new_values.
      ENDIF.
    ENDLOOP.

    lv_new_rowid = iv_rowid.
    LOOP AT it_assignments INTO lo_assignment.
      ls_target = resolve_update_target(
        is_table = is_table
        iv_name  = lo_assignment->get_column( ) ).
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = lo_assignment->get_expression( )
        io_context    = io_context ).

      IF ls_target-is_rowid = abap_true.
        IF ls_target-column_index > 0.
          READ TABLE is_table-columns INTO ls_column INDEX ls_target-column_index.
          lv_type = ls_column-type.
        ELSE.
          lv_type = 'INTEGER'.
        ENDIF.
        lv_new_rowid = update_rowid(
          io_value = lo_value
          iv_type  = lv_type ).
      ELSE.
        READ TABLE is_table-columns INTO ls_column INDEX ls_target-column_index.
        lo_value = zcl_sqlite_expr_eval=>apply_affinity(
          io_value = lo_value
          iv_type  = ls_column-type ).
        IF lo_value->is_null( ) = abap_true
            AND ls_column-notnull = abap_true.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = |NOT NULL constraint failed: { is_table-name }.{ ls_column-name }|.
        ENDIF.
        MODIFY lt_new_values FROM lo_value INDEX ls_target-column_index.
      ENDIF.
    ENDLOOP.

    rs_row-old_rowid = iv_rowid.
    rs_row-new_rowid = lv_new_rowid.
    rs_row-payload = zcl_sqlite_record=>encode( lt_new_values ).
  ENDMETHOD.

  METHOD rowid_select_name.
    DATA lt_candidates TYPE zcl_sqlite_ast_node=>ty_names.
    DATA lv_candidate TYPE string.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lv_found TYPE abap_bool.

    APPEND 'rowid' TO lt_candidates.
    APPEND '_rowid_' TO lt_candidates.
    APPEND 'oid' TO lt_candidates.

    LOOP AT lt_candidates INTO lv_candidate.
      lv_found = abap_false.
      LOOP AT is_table-columns INTO ls_column.
        IF to_upper( ls_column-name ) = to_upper( lv_candidate ).
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        rv_name = lv_candidate.
        RETURN.
      ENDIF.
    ENDLOOP.

    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_error
        iv_message = 'table has no unshadowed rowid alias'.
  ENDMETHOD.

  METHOD build_insert_columns.
    DATA lt_names TYPE zcl_sqlite_ast_node=>ty_names.
    DATA lt_source TYPE ty_source_indexes.
    DATA lt_seen TYPE ty_upper_names.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA ls_insert_column TYPE ty_insert_column.
    DATA lv_name TYPE string.
    DATA lv_upper TYPE string.
    DATA lv_table_index TYPE i.
    DATA lv_source TYPE i.
    DATA lv_name_index TYPE i.

    lt_names = io_statement->get_columns( ).
    IF lines( lt_names ) = 0.
      LOOP AT it_table_columns INTO ls_column.
        ls_insert_column-column = ls_column.
        ls_insert_column-source_index = sy-tabix.
        APPEND ls_insert_column TO rt_columns.
      ENDLOOP.
      RETURN.
    ENDIF.

    LOOP AT it_table_columns INTO ls_column.
      APPEND 0 TO lt_source.
    ENDLOOP.

    LOOP AT lt_names INTO lv_name.
      lv_name_index = sy-tabix.
      lv_upper = to_upper( lv_name ).
      READ TABLE lt_seen TRANSPORTING NO FIELDS
        WITH KEY table_line = lv_upper.
      IF sy-subrc = 0.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = |duplicate column name: { lv_name }|.
      ENDIF.
      APPEND lv_upper TO lt_seen.

      lv_table_index = 0.
      LOOP AT it_table_columns INTO ls_column.
        IF to_upper( ls_column-name ) = lv_upper.
          lv_table_index = sy-tabix.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_table_index = 0.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = |table { io_statement->get_table( ) } has no column named { lv_name }|.
      ENDIF.

      READ TABLE lt_source INTO lv_source INDEX lv_table_index.
      IF lv_source <> 0.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING
            iv_code    = zcx_sqlite_error=>sqlite_error
            iv_message = |duplicate column name: { lv_name }|.
      ENDIF.
      MODIFY lt_source FROM lv_name_index INDEX lv_table_index.
    ENDLOOP.

    LOOP AT it_table_columns INTO ls_column.
      READ TABLE lt_source INTO lv_source INDEX sy-tabix.
      ls_insert_column-column = ls_column.
      ls_insert_column-source_index = lv_source.
      APPEND ls_insert_column TO rt_columns.
    ENDLOOP.
  ENDMETHOD.

  METHOD insert_one.
    DATA ls_insert_column TYPE ty_insert_column.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lt_record_values TYPE zcl_sqlite_record=>ty_values.
    DATA lv_source_index TYPE i.
    DATA lv_rowid TYPE int8.
    DATA lv_rowid_set TYPE abap_bool.
    DATA lo_writer TYPE REF TO zcl_sqlite_btree_writer.
    DATA lv_root_page TYPE i.

    LOOP AT it_columns INTO ls_insert_column.
      ls_column = ls_insert_column-column.
      lv_source_index = ls_insert_column-source_index.

      IF lv_source_index > 0.
        READ TABLE it_input INTO lo_value INDEX lv_source_index.
        IF sy-subrc <> 0.
          lo_value = zcl_sqlite_value=>null( ).
        ENDIF.
      ELSE.
        lo_value = zcl_sqlite_value=>null( ).
        IF ls_column-rowid_alias = abap_false
            AND ls_column-dflt_value_is_null = abap_false.
          lo_value = zcl_sqlite_expr_eval=>evaluate_sql( |SELECT { ls_column-dflt_value }| ).
        ENDIF.
      ENDIF.

      IF ls_column-rowid_alias = abap_true.
        IF lo_value->is_null( ) = abap_false.
          lo_value = zcl_sqlite_expr_eval=>apply_affinity(
            io_value = lo_value
            iv_type  = ls_column-type ).
          IF lo_value->value_type( ) <> zcl_sqlite_value=>c_integer.
            RAISE EXCEPTION TYPE zcx_sqlite_error
              EXPORTING
                iv_code    = zcx_sqlite_error=>sqlite_error
                iv_message = 'datatype mismatch'.
          ENDIF.
          lv_rowid = lo_value->as_integer( ).
          lv_rowid_set = abap_true.
        ENDIF.
        APPEND zcl_sqlite_value=>null( ) TO lt_record_values.
      ELSE.
        lo_value = zcl_sqlite_expr_eval=>apply_affinity(
          io_value = lo_value
          iv_type  = ls_column-type ).
        IF lo_value->is_null( ) = abap_true
            AND ls_column-notnull = abap_true.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = |NOT NULL constraint failed: { is_table-name }.{ ls_column-name }|.
        ENDIF.
        APPEND lo_value TO lt_record_values.
      ENDIF.
    ENDLOOP.

    IF lv_rowid_set = abap_false.
      IF iv_have_max = abap_true.
        IF iv_max_rowid = c_max_rowid.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING
              iv_code    = zcx_sqlite_error=>sqlite_error
              iv_message = 'rowid overflow'.
        ENDIF.
        lv_rowid = iv_max_rowid + 1.
      ELSE.
        lv_rowid = 1.
      ENDIF.
    ENDIF.

    lv_root_page = is_table-rootpage.
    lo_writer = NEW zcl_sqlite_btree_writer(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).
    lo_writer->insert_row(
      iv_rowid   = lv_rowid
      iv_payload = zcl_sqlite_record=>encode( lt_record_values ) ).

    insert_index_entries(
      is_table  = is_table
      it_values = lt_record_values
      iv_rowid  = lv_rowid ).

    rs_result-rowid = lv_rowid.
    rs_result-max_rowid = iv_max_rowid.
    rs_result-have_max = iv_have_max.
    IF iv_have_max = abap_false OR lv_rowid > iv_max_rowid.
      rs_result-max_rowid = lv_rowid.
      rs_result-have_max = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD max_rowid.
    DATA lo_cursor TYPE REF TO zcl_sqlite_cursor.
    DATA lv_root_page TYPE i.

    lv_root_page = is_table-rootpage.
    lo_cursor = NEW zcl_sqlite_cursor(
      io_pager     = mo_pager
      iv_root_page = lv_root_page ).
    ev_have_max = lo_cursor->first( ).
    IF ev_have_max = abap_false.
      ev_max_rowid = 0.
      RETURN.
    ENDIF.

    DO.
      ev_max_rowid = lo_cursor->rowid( ).
      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD normalized_sql.
    DATA lv_length TYPE i.
    DATA lv_char TYPE string.

    rv_sql = iv_sql.
    lv_length = strlen( rv_sql ).
    WHILE lv_length > 0.
      lv_char = substring(
        val = rv_sql
        off = lv_length - 1
        len = 1 ).
      IF lv_char <> ';' AND lv_char <> ' '.
        EXIT.
      ENDIF.
      lv_length = lv_length - 1.
    ENDWHILE.

    IF lv_length < strlen( rv_sql ).
      rv_sql = substring(
        val = rv_sql
        off = 0
        len = lv_length ).
    ENDIF.
  ENDMETHOD.

  METHOD plan_dump.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_select    TYPE REF TO zcl_sqlite_ast_select.
    DATA lo_planner   TYPE REF TO zcl_sqlite_planner.

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

    lo_planner = NEW zcl_sqlite_planner(
      io_schema = mo_schema
      it_from   = lo_select->get_from( )
      io_where  = lo_select->get_where( ) ).
    rv_plan = lo_planner->dump( ).
  ENDMETHOD.

  METHOD resolve_order_terms.
    DATA lo_order_by      TYPE REF TO zcl_sqlite_ast_order_by.
    DATA lo_expression    TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_literal       TYPE REF TO zcl_sqlite_ast_literal.
    DATA lo_name          TYPE REF TO zcl_sqlite_ast_name.
    DATA lo_value         TYPE REF TO zcl_sqlite_value.
    DATA ls_term          TYPE zcl_sqlite_sort=>ty_term.
    DATA ls_project       TYPE zcl_sqlite_project=>ty_column.
    DATA lv_position      TYPE i.
    DATA lv_index         TYPE i.
    DATA lv_hidden        TYPE i.
    DATA lv_collation     TYPE string.
    DATA lv_literal_value TYPE int8.

    rs_result-columns = it_project_columns.
    LOOP AT it_order_by INTO lo_order_by.
      CLEAR ls_term.
      lo_expression = lo_order_by->get_expression( ).
      lv_position = 0.

      IF lo_expression IS INSTANCE OF zcl_sqlite_ast_literal.
        lo_literal ?= lo_expression.
        IF lo_literal->get_kind( ) = 'INTEGER'.
          lo_value = zcl_sqlite_expr_eval=>evaluate( lo_expression ).
          lv_literal_value = zcl_sqlite_expr_eval=>value_to_integer( lo_value ).
          IF lv_literal_value < 1 OR lv_literal_value > iv_visible_count.
            RAISE EXCEPTION TYPE zcx_sqlite_error
              EXPORTING iv_message = 'ORDER BY term out of range'.
          ENDIF.
          lv_position = lv_literal_value.
        ENDIF.
      ENDIF.

      IF lv_position = 0 AND lo_expression IS INSTANCE OF zcl_sqlite_ast_name.
        lo_name ?= lo_expression.
        IF lo_name->get_kind( ) = zcl_sqlite_ast_name=>c_column.
          lv_index = 1.
          LOOP AT rs_result-columns INTO ls_project.
            IF lv_index > iv_visible_count.
              EXIT.
            ENDIF.
            IF to_upper( ls_project-name ) = to_upper( lo_name->get_text( ) ).
              lv_position = lv_index.
              EXIT.
            ENDIF.
            lv_index = lv_index + 1.
          ENDLOOP.
        ENDIF.
      ENDIF.

      lv_collation = zcl_sqlite_expr_eval=>collation_of_expression( lo_expression ).
      IF lv_position = 0.
        lv_hidden = lv_hidden + 1.
        ls_project-expression = lo_expression.
        ls_project-name = |__order_{ lv_hidden }|.
        APPEND ls_project TO rs_result-columns.
        lv_position = lines( rs_result-columns ).
      ELSEIF lv_collation IS INITIAL.
        READ TABLE rs_result-columns INTO ls_project INDEX lv_position.
        IF sy-subrc = 0.
          lv_collation = zcl_sqlite_expr_eval=>collation_of_expression( ls_project-expression ).
        ENDIF.
      ENDIF.

      IF lv_collation IS INITIAL.
        lv_collation = 'BINARY'.
      ENDIF.
      ls_term-position = lv_position.
      ls_term-direction = lo_order_by->get_direction( ).
      IF ls_term-direction IS INITIAL.
        ls_term-direction = 'ASC'.
      ENDIF.
      ls_term-nulls = lo_order_by->get_nulls( ).
      IF ls_term-nulls IS INITIAL.
        IF ls_term-direction = 'DESC'.
          ls_term-nulls = 'LAST'.
        ELSE.
          ls_term-nulls = 'FIRST'.
        ENDIF.
      ENDIF.
      ls_term-collation = lv_collation.
      APPEND ls_term TO rs_result-terms.
    ENDLOOP.
  ENDMETHOD.

  METHOD resolve_group_by.
    DATA lo_expression    TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_literal       TYPE REF TO zcl_sqlite_ast_literal.
    DATA lo_name          TYPE REF TO zcl_sqlite_ast_name.
    DATA lo_value         TYPE REF TO zcl_sqlite_value.
    DATA ls_project       TYPE zcl_sqlite_project=>ty_column.
    DATA lv_position      TYPE i.
    DATA lv_index         TYPE i.
    DATA lv_literal_value TYPE int8.

    LOOP AT it_group_by INTO lo_expression.
      lv_position = 0.

      IF lo_expression IS INSTANCE OF zcl_sqlite_ast_literal.
        lo_literal ?= lo_expression.
        IF lo_literal->get_kind( ) = 'INTEGER'.
          lo_value = zcl_sqlite_expr_eval=>evaluate( lo_expression ).
          lv_literal_value = zcl_sqlite_expr_eval=>value_to_integer( lo_value ).
          IF lv_literal_value < 1 OR lv_literal_value > iv_visible_count.
            RAISE EXCEPTION TYPE zcx_sqlite_error
              EXPORTING iv_message = 'GROUP BY term out of range'.
          ENDIF.
          lv_position = lv_literal_value.
        ENDIF.
      ENDIF.

      IF lv_position = 0 AND lo_expression IS INSTANCE OF zcl_sqlite_ast_name.
        lo_name ?= lo_expression.
        IF lo_name->get_kind( ) = zcl_sqlite_ast_name=>c_column.
          lv_index = 1.
          LOOP AT it_project_columns INTO ls_project.
            IF lv_index > iv_visible_count.
              EXIT.
            ENDIF.
            IF to_upper( ls_project-name ) = to_upper( lo_name->get_text( ) ).
              lv_position = lv_index.
              EXIT.
            ENDIF.
            lv_index = lv_index + 1.
          ENDLOOP.
        ENDIF.
      ENDIF.

      IF lv_position > 0.
        READ TABLE it_project_columns INTO ls_project INDEX lv_position.
        APPEND ls_project-expression TO rt_expressions.
      ELSE.
        APPEND lo_expression TO rt_expressions.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_from_list.
    DATA lo_item    TYPE REF TO zcl_sqlite_ast_node.
    DATA ls_right   TYPE ty_from_plan.

    READ TABLE it_from INTO lo_item INDEX 1.
    IF sy-subrc = 0.
      rs_plan = build_from(
        io_item    = lo_item
        io_planner = io_planner ).
    ENDIF.

    LOOP AT it_from INTO lo_item FROM 2.
      ls_right = build_from(
        io_item    = lo_item
        io_planner = io_planner ).
      rs_plan = combine_plans(
        is_left      = rs_plan
        is_right     = ls_right
        iv_join_type = 'CROSS JOIN' ).
    ENDLOOP.
  ENDMETHOD.

  METHOD build_from.
    DATA lo_table_ref TYPE REF TO zcl_sqlite_ast_table_ref.
    DATA lo_join      TYPE REF TO zcl_sqlite_ast_join.

    IF io_item IS INSTANCE OF zcl_sqlite_ast_table_ref.
      lo_table_ref ?= io_item.
      rs_plan = build_table(
        io_table_ref = lo_table_ref
        io_planner   = io_planner ).
    ELSEIF io_item IS INSTANCE OF zcl_sqlite_ast_join.
      lo_join ?= io_item.
      rs_plan = build_join(
        io_join    = lo_join
        io_planner = io_planner ).
    ELSE.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = 'subqueries in FROM are not supported yet'.
    ENDIF.
  ENDMETHOD.

  METHOD build_table.
    DATA ls_table        TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_table_column TYPE zcl_sqlite_schema=>ty_column.
    DATA ls_from_column  TYPE zcl_sqlite_join=>ty_column.
    DATA ls_access       TYPE zcl_sqlite_planner=>ty_plan.
    DATA lv_table_name   TYPE string.

    ls_table = mo_schema->table( io_table_ref->get_name( ) ).
    IF ls_table-name IS INITIAL.
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = |no such table: { io_table_ref->get_name( ) }|.
    ENDIF.

    lv_table_name = io_table_ref->get_alias( ).
    IF lv_table_name IS INITIAL.
      lv_table_name = ls_table-name.
    ENDIF.

    ls_access = io_planner->plan_for(
      iv_table_name = ls_table-name
      iv_alias      = lv_table_name ).

    rs_plan-operator = NEW zcl_sqlite_table_scan(
      io_pager = mo_pager
      is_table = ls_table
      iv_alias = io_table_ref->get_alias( )
      is_plan  = ls_access ).

    LOOP AT ls_table-columns INTO ls_table_column.
      ls_from_column-name = ls_table_column-name.
      ls_from_column-table_name = lv_table_name.
      ls_from_column-hidden = abap_false.
      APPEND ls_from_column TO rs_plan-columns.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_join.
    DATA ls_left      TYPE ty_from_plan.
    DATA ls_right     TYPE ty_from_plan.
    DATA lt_using     TYPE zcl_sqlite_join=>ty_names.
    DATA lv_join_type TYPE string.

    ls_left = build_from(
      io_item    = io_join->get_left( )
      io_planner = io_planner ).
    ls_right = build_from(
      io_item    = io_join->get_right( )
      io_planner = io_planner ).
    lv_join_type = io_join->get_join_type( ).

    IF io_join->is_natural( ) = abap_true.
      lt_using = natural_columns(
        is_left  = ls_left
        is_right = ls_right ).
    ELSE.
      lt_using = io_join->get_using( ).
    ENDIF.

    rs_plan = combine_plans(
      is_left      = ls_left
      is_right     = ls_right
      iv_join_type = lv_join_type
      io_on        = io_join->get_on( )
      it_using     = lt_using ).
  ENDMETHOD.

  METHOD combine_plans.
    DATA lt_right_columns TYPE ty_from_columns.
    DATA lt_hidden_columns TYPE ty_from_columns.
    DATA ls_right_column  TYPE zcl_sqlite_join=>ty_column.
    DATA lv_name          TYPE string.
    DATA lv_hidden        TYPE abap_bool.

    lt_right_columns = is_right-columns.

    IF lines( it_using ) > 0.
      validate_using(
        is_left  = is_left
        is_right = is_right
        it_using = it_using ).
      LOOP AT lt_right_columns INTO ls_right_column.
        lv_hidden = ls_right_column-hidden.
        LOOP AT it_using INTO lv_name.
          IF to_upper( ls_right_column-name ) = to_upper( lv_name ).
            lv_hidden = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_hidden = abap_true.
          ls_right_column-hidden = abap_true.
        ENDIF.
        APPEND ls_right_column TO lt_hidden_columns.
      ENDLOOP.
      lt_right_columns = lt_hidden_columns.
    ENDIF.

    rs_plan-columns = is_left-columns.
    APPEND LINES OF lt_right_columns TO rs_plan-columns.

    rs_plan-operator = NEW zcl_sqlite_join(
      io_left          = is_left-operator
      io_right         = is_right-operator
      iv_join_type     = iv_join_type
      io_on            = io_on
      it_using         = it_using
      it_right_columns = lt_right_columns ).
  ENDMETHOD.

  METHOD natural_columns.
    DATA ls_left      TYPE zcl_sqlite_join=>ty_column.
    DATA ls_right     TYPE zcl_sqlite_join=>ty_column.
    DATA lv_existing  TYPE string.

    LOOP AT is_left-columns INTO ls_left.
      IF ls_left-hidden = abap_true.
        CONTINUE.
      ENDIF.
      LOOP AT is_right-columns INTO ls_right.
        IF ls_right-hidden = abap_true.
          CONTINUE.
        ENDIF.
        IF to_upper( ls_left-name ) <> to_upper( ls_right-name ).
          CONTINUE.
        ENDIF.
        LOOP AT rt_names INTO lv_existing.
          IF to_upper( lv_existing ) = to_upper( ls_left-name ).
            EXIT.
          ENDIF.
        ENDLOOP.
        IF sy-subrc <> 0.
          APPEND ls_left-name TO rt_names.
        ENDIF.
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_using.
    DATA ls_column TYPE zcl_sqlite_join=>ty_column.
    DATA lv_name   TYPE string.
    DATA lv_found  TYPE abap_bool.

    LOOP AT it_using INTO lv_name.
      CLEAR lv_found.
      LOOP AT is_left-columns INTO ls_column.
        IF to_upper( ls_column-name ) = to_upper( lv_name ).
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = |cannot join using column { lv_name } - column not present in both tables|.
      ENDIF.

      CLEAR lv_found.
      LOOP AT is_right-columns INTO ls_column.
        IF to_upper( ls_column-name ) = to_upper( lv_name ).
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = |cannot join using column { lv_name } - column not present in both tables|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD project_columns.
    DATA lo_result_column TYPE REF TO zcl_sqlite_ast_result_column.
    DATA lo_name          TYPE REF TO zcl_sqlite_ast_name.
    DATA lo_expression    TYPE REF TO zcl_sqlite_ast_node.
    DATA ls_from_column   TYPE zcl_sqlite_join=>ty_column.
    DATA ls_project_column TYPE zcl_sqlite_project=>ty_column.
    DATA lv_alias         TYPE string.
    DATA lv_qualifier     TYPE string.
    DATA lv_found         TYPE abap_bool.

    LOOP AT it_result_columns INTO lo_result_column.
      lo_expression = lo_result_column->get_expression( ).
      IF is_star( lo_expression ) = abap_true.
        IF lines( it_table_columns ) = 0.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING iv_message = 'star requires a table'.
        ENDIF.
        lv_qualifier = star_qualifier( lo_expression ).
        CLEAR lv_found.
        LOOP AT it_table_columns INTO ls_from_column.
          IF lv_qualifier IS INITIAL.
            IF ls_from_column-hidden = abap_true.
              CONTINUE.
            ENDIF.
          ELSEIF to_upper( ls_from_column-table_name ) <> to_upper( lv_qualifier ).
            CONTINUE.
          ENDIF.
          lv_found = abap_true.
          IF ls_from_column-table_name IS INITIAL.
            ls_project_column-expression = NEW zcl_sqlite_ast_name(
              iv_kind = zcl_sqlite_ast_name=>c_column
              iv_text = ls_from_column-name ).
          ELSE.
            ls_project_column-expression = NEW zcl_sqlite_ast_name(
              iv_kind = zcl_sqlite_ast_name=>c_column
              iv_text = |{ ls_from_column-table_name }.{ ls_from_column-name }| ).
          ENDIF.
          ls_project_column-name = ls_from_column-name.
          APPEND ls_project_column TO rt_columns.
        ENDLOOP.
        IF lv_qualifier IS NOT INITIAL AND lv_found = abap_false.
          RAISE EXCEPTION TYPE zcx_sqlite_error
            EXPORTING iv_message = |no such table: { lv_qualifier }|.
        ENDIF.
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

  METHOD star_qualifier.
    DATA lo_name   TYPE REF TO zcl_sqlite_ast_name.
    DATA lv_text   TYPE string.
    DATA lv_length TYPE i.

    IF io_expression IS NOT INSTANCE OF zcl_sqlite_ast_name.
      RETURN.
    ENDIF.
    lo_name ?= io_expression.
    IF lo_name->get_kind( ) <> zcl_sqlite_ast_name=>c_column.
      RETURN.
    ENDIF.
    lv_text = lo_name->get_text( ).
    lv_length = strlen( lv_text ).
    IF lv_length >= 2
        AND substring( val = lv_text
                       off = lv_length - 2
                       len = 2 ) = '.*'.
      rv_qualifier = substring( val = lv_text
                                off = 0
                                len = lv_length - 2 ).
    ENDIF.
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
          AND substring( val = lv_text
                         off = lv_length - 2
                         len = 2 ) = '.*'.
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
      IF substring( val = iv_name
                    off = lv_index
                    len = 1 ) = '.'.
        rv_name = substring( val = iv_name
                             off = lv_index + 1 ).
        RETURN.
      ENDIF.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.
