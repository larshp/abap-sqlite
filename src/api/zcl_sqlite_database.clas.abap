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

    METHODS plan_dump
      IMPORTING iv_sql         TYPE string
      RETURNING VALUE(rv_plan) TYPE string
      RAISING   zcx_sqlite_error.

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

    DATA mo_file   TYPE REF TO zif_sqlite_file.
    DATA mo_pager  TYPE REF TO zcl_sqlite_pager.
    DATA mo_schema TYPE REF TO zcl_sqlite_schema.

    METHODS constructor
      IMPORTING io_file   TYPE REF TO zif_sqlite_file
                io_pager  TYPE REF TO zcl_sqlite_pager
                io_schema TYPE REF TO zcl_sqlite_schema.

    CLASS-METHODS empty_page
      RETURNING VALUE(rv_page) TYPE xstring
      RAISING   zcx_sqlite_error.

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
        lo_file->write( iv_offset = 0 iv_data = lv_page ).
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
          lo_value = zcl_sqlite_expr_eval=>evaluate( io_expression = lo_expression ).
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
        AND substring( val = lv_text off = lv_length - 2 len = 2 ) = '.*'.
      rv_qualifier = substring( val = lv_text off = 0 len = lv_length - 2 ).
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
