* Chooses table access paths for the query operators.
*
* Version 1 understands rowid equality/range predicates and equality/range
* predicates on a leading prefix of an index. Everything else stays a full
* table scan. The plan is deliberately simple and textual so tests can assert
* which access path was selected.
CLASS zcl_sqlite_planner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      c_scan  TYPE string VALUE 'SCAN',
      c_rowid TYPE string VALUE 'ROWID',
      c_index TYPE string VALUE 'INDEX',
      c_match TYPE i VALUE 1,
      c_skip  TYPE i VALUE 0,
      c_stop  TYPE i VALUE -1.

    TYPES:
      BEGIN OF ty_bound,
        value    TYPE REF TO zcl_sqlite_value,
        operator TYPE string,
      END OF ty_bound.

    TYPES:
      BEGIN OF ty_plan,
        kind           TYPE string,
        table_name     TYPE string,
        alias          TYPE string,
        access_column  TYPE string,
        index_name     TYPE string,
        index_rootpage TYPE int8,
        index_columns  TYPE zcl_sqlite_schema=>ty_index_columns,
        prefix_length  TYPE i,
        prefix_values  TYPE zcl_sqlite_record=>ty_values,
        range_position TYPE i,
        lower          TYPE ty_bound,
        upper          TYPE ty_bound,
        description    TYPE string,
      END OF ty_plan.

    METHODS constructor
      IMPORTING io_schema TYPE REF TO zcl_sqlite_schema
                it_from   TYPE zcl_sqlite_ast_select=>ty_from
                io_where  TYPE REF TO zcl_sqlite_ast_node OPTIONAL
      RAISING   zcx_sqlite_error.

    METHODS plan_for
      IMPORTING iv_table_name  TYPE string
                iv_alias       TYPE string
      RETURNING VALUE(rs_plan) TYPE ty_plan.

    METHODS dump
      RETURNING VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_table_info,
        name  TYPE string,
        alias TYPE string,
        table TYPE zcl_sqlite_schema=>ty_table,
      END OF ty_table_info,
      ty_table_infos TYPE STANDARD TABLE OF ty_table_info WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_constraint,
        table_index TYPE i,
        column      TYPE string,
        operator    TYPE string,
        value       TYPE REF TO zcl_sqlite_value,
      END OF ty_constraint,
      ty_constraints TYPE STANDARD TABLE OF ty_constraint WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_resolution,
        found       TYPE abap_bool,
        table_index TYPE i,
        column      TYPE string,
      END OF ty_resolution.

    TYPES:
      BEGIN OF ty_column_constraints,
        has_equal TYPE abap_bool,
        equal     TYPE ty_constraint,
        has_lower TYPE abap_bool,
        lower     TYPE ty_constraint,
        has_upper TYPE abap_bool,
        upper     TYPE ty_constraint,
      END OF ty_column_constraints.

    DATA mo_schema      TYPE REF TO zcl_sqlite_schema.
    DATA mt_tables      TYPE ty_table_infos.
    DATA mt_constraints TYPE ty_constraints.

    METHODS collect_tables
      IMPORTING io_item TYPE REF TO zcl_sqlite_ast_node.

    METHODS collect_constraints
      IMPORTING io_expression TYPE REF TO zcl_sqlite_ast_node
      RAISING   zcx_sqlite_error.

    METHODS add_comparison
      IMPORTING io_left     TYPE REF TO zcl_sqlite_ast_node
                io_right    TYPE REF TO zcl_sqlite_ast_node
                iv_operator TYPE string
      RAISING   zcx_sqlite_error.

    METHODS constant_value
      IMPORTING io_expression   TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    METHODS column_text
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_text) TYPE string.

    METHODS flip_operator
      IMPORTING iv_operator       TYPE string
      RETURNING VALUE(rv_flipped) TYPE string.

    METHODS normalize_operator
      IMPORTING iv_operator          TYPE string
      RETURNING VALUE(rv_normalized) TYPE string.

    METHODS resolve_column
      IMPORTING iv_text              TYPE string
      RETURNING VALUE(rs_resolution) TYPE ty_resolution.

    METHODS add_constraint
      IMPORTING iv_column   TYPE string
                iv_operator TYPE string
                io_value    TYPE REF TO zcl_sqlite_value.

    METHODS value_matches_column
      IMPORTING is_table        TYPE zcl_sqlite_schema=>ty_table
                iv_column       TYPE string
                io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_match) TYPE abap_bool.

    METHODS find_column
      IMPORTING is_table         TYPE zcl_sqlite_schema=>ty_table
                iv_name          TYPE string
      RETURNING VALUE(rs_column) TYPE zcl_sqlite_schema=>ty_column.

    METHODS is_rowid_column
      IMPORTING is_table        TYPE zcl_sqlite_schema=>ty_table
                iv_column       TYPE string
      RETURNING VALUE(rv_rowid) TYPE abap_bool.

    METHODS build_plan
      IMPORTING iv_table_index TYPE i
      RETURNING VALUE(rs_plan) TYPE ty_plan.

    METHODS build_rowid_plan
      IMPORTING is_info        TYPE ty_table_info
                it_constraints TYPE ty_constraints
      RETURNING VALUE(rs_plan) TYPE ty_plan.

    METHODS build_index_plan
      IMPORTING is_info        TYPE ty_table_info
                it_constraints TYPE ty_constraints
      RETURNING VALUE(rs_plan) TYPE ty_plan.

    METHODS index_is_usable
      IMPORTING is_index         TYPE zcl_sqlite_schema=>ty_index
                is_table         TYPE zcl_sqlite_schema=>ty_table
      RETURNING VALUE(rv_usable) TYPE abap_bool.

    METHODS constraints_for_column
      IMPORTING is_index_column  TYPE zcl_sqlite_schema=>ty_index_column
                it_constraints   TYPE ty_constraints
      RETURNING VALUE(rs_result) TYPE ty_column_constraints.

    METHODS make_description
      IMPORTING is_plan        TYPE ty_plan
      RETURNING VALUE(rv_text) TYPE string.

    METHODS table_label
      IMPORTING is_plan         TYPE ty_plan
      RETURNING VALUE(rv_label) TYPE string.

    METHODS append_condition
      IMPORTING iv_conditions        TYPE string
                iv_column            TYPE string
                iv_operator          TYPE string
                io_value             TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_conditions) TYPE string.

    METHODS value_text
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_text) TYPE string.

    METHODS quote_text
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_planner IMPLEMENTATION.

  METHOD constructor.
    DATA lo_item TYPE REF TO zcl_sqlite_ast_node.

    mo_schema = io_schema.
    LOOP AT it_from INTO lo_item.
      collect_tables( lo_item ).
    ENDLOOP.
    collect_constraints( io_where ).
  ENDMETHOD.

  METHOD plan_for.
    DATA ls_info        TYPE ty_table_info.
    DATA lv_alias       TYPE string.
    DATA lv_index       TYPE i.

    lv_alias = iv_alias.
    IF lv_alias IS INITIAL.
      lv_alias = iv_table_name.
    ENDIF.

    LOOP AT mt_tables INTO ls_info.
      lv_index = lv_index + 1.
      IF to_upper( ls_info-name ) = to_upper( iv_table_name )
          AND to_upper( ls_info-alias ) = to_upper( lv_alias ).
        rs_plan = build_plan( lv_index ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD dump.
    DATA ls_info  TYPE ty_table_info.
    DATA ls_plan  TYPE ty_plan.
    DATA lv_index TYPE i.

    LOOP AT mt_tables INTO ls_info.
      lv_index = lv_index + 1.
      ls_plan = build_plan( lv_index ).
      IF rv_text IS NOT INITIAL.
        rv_text = rv_text && cl_abap_char_utilities=>newline.
      ENDIF.
      rv_text = rv_text && ls_plan-description.
    ENDLOOP.

    IF rv_text IS INITIAL.
      rv_text = |SCAN CONSTANT|.
    ENDIF.
  ENDMETHOD.

  METHOD collect_tables.
    DATA lo_table_ref TYPE REF TO zcl_sqlite_ast_table_ref.
    DATA lo_join      TYPE REF TO zcl_sqlite_ast_join.
    DATA ls_info      TYPE ty_table_info.

    IF io_item IS NOT BOUND.
      RETURN.
    ENDIF.

    IF io_item IS INSTANCE OF zcl_sqlite_ast_table_ref.
      lo_table_ref ?= io_item.
      ls_info-name = lo_table_ref->get_name( ).
      ls_info-alias = lo_table_ref->get_alias( ).
      IF ls_info-alias IS INITIAL.
        ls_info-alias = ls_info-name.
      ENDIF.
      ls_info-table = mo_schema->table( ls_info-name ).
      APPEND ls_info TO mt_tables.
    ELSEIF io_item IS INSTANCE OF zcl_sqlite_ast_join.
      lo_join ?= io_item.
      collect_tables( lo_join->get_left( ) ).
      collect_tables( lo_join->get_right( ) ).
    ENDIF.
  ENDMETHOD.

  METHOD collect_constraints.
    DATA lo_binary  TYPE REF TO zcl_sqlite_ast_binary.
    DATA lo_between TYPE REF TO zcl_sqlite_ast_between.
    DATA lv_operator TYPE string.

    IF io_expression IS NOT BOUND.
      RETURN.
    ENDIF.

    IF io_expression IS INSTANCE OF zcl_sqlite_ast_binary.
      lo_binary ?= io_expression.
      lv_operator = to_upper( lo_binary->get_operator( ) ).
      CASE lv_operator.
        WHEN 'AND'.
          collect_constraints( lo_binary->get_left( ) ).
          collect_constraints( lo_binary->get_right( ) ).
        WHEN '=' OR '==' OR '>' OR '>=' OR '<' OR '<='.
          add_comparison(
            io_left     = lo_binary->get_left( )
            io_right    = lo_binary->get_right( )
            iv_operator = lv_operator ).
      ENDCASE.
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_between.
      lo_between ?= io_expression.
      IF lo_between->is_negated( ) = abap_false.
        add_comparison(
          io_left     = lo_between->get_expression( )
          io_right    = lo_between->get_low( )
          iv_operator = '>=' ).
        add_comparison(
          io_left     = lo_between->get_expression( )
          io_right    = lo_between->get_high( )
          iv_operator = '<=' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD add_comparison.
    DATA lv_left_column  TYPE string.
    DATA lv_right_column TYPE string.
    DATA lo_value        TYPE REF TO zcl_sqlite_value.

    lv_left_column = column_text( io_left ).
    lv_right_column = column_text( io_right ).

    IF lv_left_column IS NOT INITIAL AND lv_right_column IS INITIAL.
      lo_value = constant_value( io_right ).
      add_constraint(
        iv_column   = lv_left_column
        iv_operator = iv_operator
        io_value    = lo_value ).
    ELSEIF lv_left_column IS INITIAL AND lv_right_column IS NOT INITIAL.
      lo_value = constant_value( io_left ).
      add_constraint(
        iv_column   = lv_right_column
        iv_operator = flip_operator( iv_operator )
        io_value    = lo_value ).
    ENDIF.
  ENDMETHOD.

  METHOD constant_value.
    DATA lo_literal TYPE REF TO zcl_sqlite_ast_literal.
    DATA lo_unary   TYPE REF TO zcl_sqlite_ast_unary.
    DATA lo_operand TYPE REF TO zcl_sqlite_ast_node.

    IF io_expression IS INSTANCE OF zcl_sqlite_ast_literal.
      lo_literal ?= io_expression.
      ro_value = zcl_sqlite_expr_eval=>evaluate( lo_literal ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_unary.
      lo_unary ?= io_expression.
      IF lo_unary->get_operator( ) = '+' OR lo_unary->get_operator( ) = '-'.
        lo_operand = lo_unary->get_operand( ).
        IF lo_operand IS INSTANCE OF zcl_sqlite_ast_literal.
          lo_literal ?= lo_operand.
          IF lo_literal->get_kind( ) = 'INTEGER' OR lo_literal->get_kind( ) = 'REAL'.
            ro_value = zcl_sqlite_expr_eval=>evaluate( lo_unary ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD column_text.
    DATA lo_name TYPE REF TO zcl_sqlite_ast_name.

    IF io_expression IS NOT INSTANCE OF zcl_sqlite_ast_name.
      RETURN.
    ENDIF.
    lo_name ?= io_expression.
    IF lo_name->get_kind( ) = zcl_sqlite_ast_name=>c_column.
      rv_text = lo_name->get_text( ).
    ENDIF.
  ENDMETHOD.

  METHOD flip_operator.
    CASE to_upper( iv_operator ).
      WHEN '=' OR '=='.
        rv_flipped = '='.
      WHEN '>'.
        rv_flipped = '<'.
      WHEN '>='.
        rv_flipped = '<='.
      WHEN '<'.
        rv_flipped = '>'.
      WHEN '<='.
        rv_flipped = '>='.
      WHEN OTHERS.
        rv_flipped = iv_operator.
    ENDCASE.
  ENDMETHOD.

  METHOD normalize_operator.
    rv_normalized = iv_operator.
    IF rv_normalized = '=='.
      rv_normalized = '='.
    ENDIF.
  ENDMETHOD.

  METHOD resolve_column.
    DATA lv_text       TYPE string.
    DATA lv_qualifier  TYPE string.
    DATA lv_column     TYPE string.
    DATA lv_index      TYPE i.
    DATA lv_dot        TYPE i.
    DATA lv_count      TYPE i.
    DATA lv_table_no   TYPE i.
    DATA lv_found_no   TYPE i.
    DATA lv_found_name TYPE string.
    DATA lv_alias      TYPE string.
    DATA ls_info       TYPE ty_table_info.
    DATA ls_column     TYPE zcl_sqlite_schema=>ty_column.

    lv_text = iv_text.
    lv_index = strlen( lv_text ).
    WHILE lv_index > 0.
      lv_index = lv_index - 1.
      IF substring( val = lv_text
                    off = lv_index
                    len = 1 ) = '.'.
        lv_dot = lv_index.
        EXIT.
      ENDIF.
    ENDWHILE.

    IF lv_dot > 0.
      lv_qualifier = substring( val = lv_text
                                off = 0
                                len = lv_dot ).
      lv_column = substring( val = lv_text
                             off = lv_dot + 1 ).
    ELSE.
      lv_column = lv_text.
    ENDIF.

    IF lv_qualifier IS NOT INITIAL.
      LOOP AT mt_tables INTO ls_info.
        lv_table_no = lv_table_no + 1.
        lv_alias = ls_info-alias.
        IF to_upper( lv_alias ) = to_upper( lv_qualifier )
            OR to_upper( ls_info-name ) = to_upper( lv_qualifier ).
          ls_column = find_column(
            is_table = ls_info-table
            iv_name  = lv_column ).
          IF ls_column-name IS NOT INITIAL.
            rs_resolution-found = abap_true.
            rs_resolution-table_index = lv_table_no.
            rs_resolution-column = ls_column-name.
            RETURN.
          ENDIF.
          IF is_rowid_column(
              is_table  = ls_info-table
              iv_column = lv_column ) = abap_true.
            rs_resolution-found = abap_true.
            rs_resolution-table_index = lv_table_no.
            rs_resolution-column = lv_column.
            RETURN.
          ENDIF.
        ENDIF.
      ENDLOOP.
      RETURN.
    ENDIF.

    LOOP AT mt_tables INTO ls_info.
      lv_table_no = lv_table_no + 1.
      ls_column = find_column(
        is_table = ls_info-table
        iv_name  = lv_column ).
      IF ls_column-name IS NOT INITIAL.
        lv_count = lv_count + 1.
        lv_found_no = lv_table_no.
        lv_found_name = ls_column-name.
      ENDIF.
    ENDLOOP.

    IF lv_count = 1.
      rs_resolution-found = abap_true.
      rs_resolution-table_index = lv_found_no.
      rs_resolution-column = lv_found_name.
      RETURN.
    ELSEIF lv_count > 1.
      RETURN.
    ENDIF.

    CLEAR: lv_count, lv_found_no, lv_table_no.
    LOOP AT mt_tables INTO ls_info.
      lv_table_no = lv_table_no + 1.
      IF is_rowid_column(
          is_table  = ls_info-table
          iv_column = lv_column ) = abap_true.
        lv_count = lv_count + 1.
        lv_found_no = lv_table_no.
      ENDIF.
    ENDLOOP.
    IF lv_count = 1.
      rs_resolution-found = abap_true.
      rs_resolution-table_index = lv_found_no.
      rs_resolution-column = lv_column.
    ENDIF.
  ENDMETHOD.

  METHOD add_constraint.
    DATA ls_resolution TYPE ty_resolution.
    DATA ls_info       TYPE ty_table_info.
    DATA ls_constraint TYPE ty_constraint.

    IF io_value IS NOT BOUND OR io_value->is_null( ) = abap_true.
      RETURN.
    ENDIF.

    ls_resolution = resolve_column( iv_column ).
    IF ls_resolution-found = abap_false.
      RETURN.
    ENDIF.

    READ TABLE mt_tables INTO ls_info INDEX ls_resolution-table_index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    IF value_matches_column(
        is_table  = ls_info-table
        iv_column = ls_resolution-column
        io_value  = io_value ) = abap_false.
      RETURN.
    ENDIF.

    ls_constraint-table_index = ls_resolution-table_index.
    ls_constraint-column = ls_resolution-column.
    ls_constraint-operator = normalize_operator( iv_operator ).
    ls_constraint-value = io_value.
    APPEND ls_constraint TO mt_constraints.
  ENDMETHOD.

  METHOD value_matches_column.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.
    DATA lv_type   TYPE i.

    lv_type = io_value->value_type( ).
    ls_column = find_column(
      is_table = is_table
      iv_name  = iv_column ).

    IF ls_column-name IS INITIAL.
      IF is_rowid_column(
          is_table  = is_table
          iv_column = iv_column ) = abap_true.
        rv_match = boolc( lv_type = zcl_sqlite_value=>c_integer
                       OR lv_type = zcl_sqlite_value=>c_real ).
      ENDIF.
      RETURN.
    ENDIF.

    CASE ls_column-affinity.
      WHEN zcl_sqlite_schema=>c_affinity_text.
        rv_match = boolc( lv_type = zcl_sqlite_value=>c_text ).
      WHEN zcl_sqlite_schema=>c_affinity_integer
          OR zcl_sqlite_schema=>c_affinity_real
          OR zcl_sqlite_schema=>c_affinity_numeric.
        rv_match = boolc( lv_type = zcl_sqlite_value=>c_integer
                       OR lv_type = zcl_sqlite_value=>c_real ).
      WHEN OTHERS.
        rv_match = boolc( lv_type = zcl_sqlite_value=>c_integer
                       OR lv_type = zcl_sqlite_value=>c_real
                       OR lv_type = zcl_sqlite_value=>c_text
                       OR lv_type = zcl_sqlite_value=>c_blob ).
    ENDCASE.
  ENDMETHOD.

  METHOD find_column.
    LOOP AT is_table-columns INTO rs_column.
      IF to_upper( rs_column-name ) = to_upper( iv_name ).
        RETURN.
      ENDIF.
    ENDLOOP.
    CLEAR rs_column.
  ENDMETHOD.

  METHOD is_rowid_column.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.

    IF is_table-without_rowid = abap_true.
      RETURN.
    ENDIF.

    ls_column = find_column(
      is_table = is_table
      iv_name  = iv_column ).
    IF ls_column-name IS NOT INITIAL.
      rv_rowid = ls_column-rowid_alias.
      RETURN.
    ENDIF.

    CASE to_upper( iv_column ).
      WHEN 'ROWID' OR '_ROWID_' OR 'OID'.
        rv_rowid = abap_true.
    ENDCASE.
  ENDMETHOD.

  METHOD build_plan.
    DATA ls_info        TYPE ty_table_info.
    DATA lt_constraints TYPE ty_constraints.
    DATA ls_constraint  TYPE ty_constraint.

    IF iv_table_index < 1 OR iv_table_index > lines( mt_tables ).
      rs_plan-kind = c_scan.
      rs_plan-description = |SCAN|.
      RETURN.
    ENDIF.

    READ TABLE mt_tables INTO ls_info INDEX iv_table_index.
    rs_plan-kind = c_scan.
    rs_plan-table_name = ls_info-name.
    rs_plan-alias = ls_info-alias.
    rs_plan-range_position = -1.

    LOOP AT mt_constraints INTO ls_constraint.
      IF ls_constraint-table_index = iv_table_index.
        APPEND ls_constraint TO lt_constraints.
      ENDIF.
    ENDLOOP.

    IF ls_info-table-without_rowid = abap_false.
      rs_plan = build_rowid_plan(
        is_info        = ls_info
        it_constraints = lt_constraints ).
      IF rs_plan-kind = c_rowid.
        rs_plan-description = make_description( rs_plan ).
        RETURN.
      ENDIF.
    ENDIF.

    IF ls_info-table-without_rowid = abap_false.
      rs_plan = build_index_plan(
        is_info        = ls_info
        it_constraints = lt_constraints ).
      IF rs_plan-kind = c_index.
        rs_plan-description = make_description( rs_plan ).
        RETURN.
      ENDIF.
    ENDIF.

    CLEAR rs_plan.
    rs_plan-kind = c_scan.
    rs_plan-table_name = ls_info-name.
    rs_plan-alias = ls_info-alias.
    rs_plan-range_position = -1.
    rs_plan-description = make_description( rs_plan ).
  ENDMETHOD.

  METHOD build_rowid_plan.
    DATA ls_constraint TYPE ty_constraint.
    DATA ls_equality   TYPE ty_constraint.
    DATA ls_lower      TYPE ty_constraint.
    DATA ls_upper      TYPE ty_constraint.
    DATA lv_has_equal  TYPE abap_bool.
    DATA lv_has_lower  TYPE abap_bool.
    DATA lv_has_upper  TYPE abap_bool.

    rs_plan-kind = c_scan.
    rs_plan-table_name = is_info-name.
    rs_plan-alias = is_info-alias.
    rs_plan-range_position = -1.

    LOOP AT it_constraints INTO ls_constraint.
      IF is_rowid_column(
          is_table  = is_info-table
          iv_column = ls_constraint-column ) = abap_false.
        CONTINUE.
      ENDIF.

      CASE ls_constraint-operator.
        WHEN '='.
          IF lv_has_equal = abap_false.
            ls_equality = ls_constraint.
            lv_has_equal = abap_true.
          ENDIF.
        WHEN '>'.
          IF lv_has_lower = abap_false.
            ls_lower = ls_constraint.
            lv_has_lower = abap_true.
          ENDIF.
        WHEN '>='.
          IF lv_has_lower = abap_false.
            ls_lower = ls_constraint.
            lv_has_lower = abap_true.
          ENDIF.
        WHEN '<'.
          IF lv_has_upper = abap_false.
            ls_upper = ls_constraint.
            lv_has_upper = abap_true.
          ENDIF.
        WHEN '<='.
          IF lv_has_upper = abap_false.
            ls_upper = ls_constraint.
            lv_has_upper = abap_true.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    IF lv_has_equal = abap_true.
      rs_plan-kind = c_rowid.
      rs_plan-access_column = ls_equality-column.
      rs_plan-lower-value = ls_equality-value.
      rs_plan-lower-operator = '='.
      rs_plan-upper-value = ls_equality-value.
      rs_plan-upper-operator = '='.
    ELSEIF lv_has_lower = abap_true OR lv_has_upper = abap_true.
      rs_plan-kind = c_rowid.
      IF lv_has_lower = abap_true.
        rs_plan-access_column = ls_lower-column.
        rs_plan-lower-value = ls_lower-value.
        rs_plan-lower-operator = ls_lower-operator.
      ENDIF.
      IF lv_has_upper = abap_true.
        IF rs_plan-access_column IS INITIAL.
          rs_plan-access_column = ls_upper-column.
        ENDIF.
        rs_plan-upper-value = ls_upper-value.
        rs_plan-upper-operator = ls_upper-operator.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD build_index_plan.
    DATA ls_index          TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_index_column   TYPE zcl_sqlite_schema=>ty_index_column.
    DATA ls_column_result  TYPE ty_column_constraints.
    DATA lv_position       TYPE i.
    DATA lv_prefix_length  TYPE i.
    DATA lv_range_position TYPE i.
    DATA lv_usable         TYPE abap_bool.
    DATA lv_score          TYPE i.
    DATA lv_best_score     TYPE i.
    DATA lt_prefix         TYPE zcl_sqlite_record=>ty_values.
    DATA ls_candidate      TYPE ty_plan.
    DATA ls_best           TYPE ty_plan.

    LOOP AT is_info-table-indexes INTO ls_index.
      IF index_is_usable(
          is_index = ls_index
          is_table = is_info-table ) = abap_false.
        CONTINUE.
      ENDIF.

      CLEAR: lv_prefix_length, lt_prefix, lv_range_position, lv_usable.
      lv_range_position = -1.
      lv_position = 0.

      LOOP AT ls_index-columns INTO ls_index_column.
        ls_column_result = constraints_for_column(
          is_index_column = ls_index_column
          it_constraints  = it_constraints ).

        IF ls_column_result-has_equal = abap_true.
          APPEND ls_column_result-equal-value TO lt_prefix.
          lv_prefix_length = lv_prefix_length + 1.
          lv_position = lv_position + 1.
          CONTINUE.
        ELSEIF ls_column_result-has_lower = abap_true
            OR ls_column_result-has_upper = abap_true.
          lv_range_position = lv_position.
          lv_usable = abap_true.
          EXIT.
        ELSE.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_prefix_length > 0 AND lv_range_position < 0.
        lv_usable = abap_true.
      ENDIF.
      IF lv_usable = abap_false.
        CONTINUE.
      ENDIF.

      lv_score = lv_prefix_length * 1000.
      IF lv_range_position >= 0.
        lv_score = lv_score + 100.
      ENDIF.
      lv_score = lv_score + 100 - lines( ls_index-columns ).

      IF lv_score <= lv_best_score.
        CONTINUE.
      ENDIF.

      CLEAR ls_candidate.
      ls_candidate-kind = c_index.
      ls_candidate-table_name = is_info-name.
      ls_candidate-alias = is_info-alias.
      ls_candidate-index_name = ls_index-name.
      ls_candidate-index_rootpage = ls_index-rootpage.
      ls_candidate-index_columns = ls_index-columns.
      ls_candidate-prefix_length = lv_prefix_length.
      ls_candidate-prefix_values = lt_prefix.
      ls_candidate-range_position = lv_range_position.
      IF ls_column_result-has_lower = abap_true AND lv_range_position >= 0.
        ls_candidate-lower-value = ls_column_result-lower-value.
        ls_candidate-lower-operator = ls_column_result-lower-operator.
      ENDIF.
      IF ls_column_result-has_upper = abap_true AND lv_range_position >= 0.
        ls_candidate-upper-value = ls_column_result-upper-value.
        ls_candidate-upper-operator = ls_column_result-upper-operator.
      ENDIF.
      ls_best = ls_candidate.
      lv_best_score = lv_score.
    ENDLOOP.

    IF lv_best_score > 0.
      rs_plan = ls_best.
    ELSE.
      rs_plan-kind = c_scan.
      rs_plan-table_name = is_info-name.
      rs_plan-alias = is_info-alias.
      rs_plan-range_position = -1.
    ENDIF.
  ENDMETHOD.

  METHOD index_is_usable.
    DATA ls_index_column TYPE zcl_sqlite_schema=>ty_index_column.
    DATA ls_column       TYPE zcl_sqlite_schema=>ty_column.

    IF is_index-partial = abap_true
        OR is_index-rootpage <= 0
        OR lines( is_index-columns ) = 0.
      RETURN.
    ENDIF.

    LOOP AT is_index-columns INTO ls_index_column.
      IF ls_index_column-cid < 0 OR ls_index_column-name IS INITIAL.
        RETURN.
      ENDIF.
      ls_column = find_column(
        is_table = is_table
        iv_name  = ls_index_column-name ).
      IF ls_column-name IS INITIAL OR ls_column-rowid_alias = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_usable = abap_true.
  ENDMETHOD.

  METHOD constraints_for_column.
    DATA ls_constraint TYPE ty_constraint.

    LOOP AT it_constraints INTO ls_constraint.
      IF to_upper( ls_constraint-column ) <> to_upper( is_index_column-name ).
        CONTINUE.
      ENDIF.
      CASE ls_constraint-operator.
        WHEN '='.
          IF rs_result-has_equal = abap_false.
            rs_result-equal = ls_constraint.
            rs_result-has_equal = abap_true.
          ENDIF.
        WHEN '>' OR '>='.
          IF rs_result-has_lower = abap_false.
            rs_result-lower = ls_constraint.
            rs_result-has_lower = abap_true.
          ENDIF.
        WHEN '<' OR '<='.
          IF rs_result-has_upper = abap_false.
            rs_result-upper = ls_constraint.
            rs_result-has_upper = abap_true.
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD make_description.
    DATA lv_conditions TYPE string.
    DATA lv_kind       TYPE string.
    DATA ls_index_col  TYPE zcl_sqlite_schema=>ty_index_column.
    DATA lo_value      TYPE REF TO zcl_sqlite_value.
    DATA lv_position   TYPE i.

    CASE is_plan-kind.
      WHEN c_rowid.
        IF is_plan-lower-value IS BOUND.
          IF is_plan-upper-value IS BOUND
              AND is_plan-lower-operator = '='
              AND is_plan-upper-operator = '='.
            lv_conditions = append_condition(
              iv_conditions = lv_conditions
              iv_column     = is_plan-access_column
              iv_operator   = '='
              io_value      = is_plan-lower-value ).
          ELSE.
            lv_conditions = append_condition(
              iv_conditions = lv_conditions
              iv_column     = is_plan-access_column
              iv_operator   = is_plan-lower-operator
              io_value      = is_plan-lower-value ).
            IF is_plan-upper-value IS BOUND.
              lv_conditions = append_condition(
                iv_conditions = lv_conditions
                iv_column     = is_plan-access_column
                iv_operator   = is_plan-upper-operator
                io_value      = is_plan-upper-value ).
            ENDIF.
          ENDIF.
        ELSEIF is_plan-upper-value IS BOUND.
          lv_conditions = append_condition(
            iv_conditions = lv_conditions
            iv_column     = is_plan-access_column
            iv_operator   = is_plan-upper-operator
            io_value      = is_plan-upper-value ).
        ENDIF.
        rv_text = |ROWID SEEK { table_label( is_plan ) } ({ lv_conditions })|.
      WHEN c_index.
        LOOP AT is_plan-prefix_values INTO lo_value.
          lv_position = sy-tabix.
          READ TABLE is_plan-index_columns INTO ls_index_col INDEX lv_position.
          lv_conditions = append_condition(
            iv_conditions = lv_conditions
            iv_column     = ls_index_col-name
            iv_operator   = '='
            io_value      = lo_value ).
        ENDLOOP.

        IF is_plan-range_position >= 0.
          READ TABLE is_plan-index_columns INTO ls_index_col
            INDEX is_plan-range_position + 1.
          IF is_plan-lower-value IS BOUND.
            lv_conditions = append_condition(
              iv_conditions = lv_conditions
              iv_column     = ls_index_col-name
              iv_operator   = is_plan-lower-operator
              io_value      = is_plan-lower-value ).
          ENDIF.
          IF is_plan-upper-value IS BOUND.
            lv_conditions = append_condition(
              iv_conditions = lv_conditions
              iv_column     = ls_index_col-name
              iv_operator   = is_plan-upper-operator
              io_value      = is_plan-upper-value ).
          ENDIF.
          lv_kind = 'INDEX RANGE'.
        ELSE.
          lv_kind = 'INDEX SEEK'.
        ENDIF.

        rv_text = |{ lv_kind } { table_label( is_plan ) } USING { is_plan-index_name } ({ lv_conditions })|.
      WHEN OTHERS.
        rv_text = |SCAN { table_label( is_plan ) }|.
    ENDCASE.
  ENDMETHOD.

  METHOD table_label.
    IF is_plan-alias IS INITIAL OR to_upper( is_plan-alias ) = to_upper( is_plan-table_name ).
      rv_label = is_plan-table_name.
    ELSE.
      rv_label = |{ is_plan-table_name } { is_plan-alias }|.
    ENDIF.
  ENDMETHOD.

  METHOD append_condition.
    DATA lv_condition TYPE string.

    lv_condition = |{ iv_column } { iv_operator } { value_text( io_value ) }|.
    IF iv_conditions IS INITIAL.
      rv_conditions = lv_condition.
    ELSE.
      rv_conditions = iv_conditions && | AND | && lv_condition.
    ENDIF.
  ENDMETHOD.

  METHOD value_text.
    DATA lv_text TYPE string.

    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_null.
        rv_text = 'NULL'.
      WHEN zcl_sqlite_value=>c_integer.
        lv_text = io_value->as_integer( ).
        CONDENSE lv_text.
        rv_text = lv_text.
      WHEN zcl_sqlite_value=>c_real.
        lv_text = io_value->as_real( ).
        CONDENSE lv_text.
        rv_text = lv_text.
      WHEN zcl_sqlite_value=>c_text.
        rv_text = quote_text( io_value->as_text( ) ).
      WHEN zcl_sqlite_value=>c_blob.
        rv_text = 'BLOB'.
      WHEN OTHERS.
        rv_text = '?'.
    ENDCASE.
  ENDMETHOD.

  METHOD quote_text.
    DATA lv_index TYPE i.
    DATA lv_char  TYPE string.

    rv_text = |'|.
    lv_index = 0.
    WHILE lv_index < strlen( iv_text ).
      lv_char = substring( val = iv_text
                           off = lv_index
                           len = 1 ).
      IF lv_char = |'|.
        rv_text = rv_text && |''|.
      ELSE.
        rv_text = rv_text && lv_char.
      ENDIF.
      lv_index = lv_index + 1.
    ENDWHILE.
    rv_text = rv_text && |'|.
  ENDMETHOD.

ENDCLASS.
