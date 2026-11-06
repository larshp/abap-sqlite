* Minimal read-only database API. It opens a database through the table VFS
* and executes SELECT statements with the TableScan, Filter, Group and
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

    METHODS close.

    METHODS query
      IMPORTING iv_sql           TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_order_result,
             columns TYPE zcl_sqlite_project=>ty_columns,
             terms   TYPE zcl_sqlite_sort=>ty_terms,
           END OF ty_order_result.

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
    DATA lo_having          TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_operator        TYPE REF TO zif_sqlite_operator.
    DATA lo_row             TYPE REF TO zcl_sqlite_row.
    DATA lt_from            TYPE zcl_sqlite_ast_select=>ty_from.
    DATA lt_result_columns  TYPE zcl_sqlite_ast_select=>ty_columns.
    DATA lt_project_columns TYPE zcl_sqlite_project=>ty_columns.
    DATA lt_group_by        TYPE zcl_sqlite_ast_select=>ty_expressions.
    DATA lt_order_by        TYPE zcl_sqlite_ast_order_by=>ty_list.
    DATA ls_order_result    TYPE ty_order_result.
    DATA ls_project_column  TYPE zcl_sqlite_project=>ty_column.
    DATA ls_table           TYPE zcl_sqlite_schema=>ty_table.
    DATA lt_order_terms     TYPE zcl_sqlite_sort=>ty_terms.
    DATA lt_result_row      TYPE ty_row.
    DATA lt_values          TYPE zcl_sqlite_record=>ty_values.
    DATA lo_cell_value      TYPE REF TO zcl_sqlite_value.
    DATA lv_has_table       TYPE abap_bool.
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
