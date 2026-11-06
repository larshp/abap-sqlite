* Evaluates expressions for one GROUP BY group. Column references resolve
* against the group's first row, while aggregate functions see all rows.
CLASS zcl_sqlite_group_context DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_eval_context.

    TYPES ty_rows TYPE STANDARD TABLE OF REF TO zcl_sqlite_row WITH DEFAULT KEY.
    TYPES ty_values TYPE STANDARD TABLE OF REF TO zcl_sqlite_value WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_alias,
             name  TYPE string,
             value TYPE REF TO zcl_sqlite_value,
           END OF ty_alias.
    TYPES ty_aliases TYPE STANDARD TABLE OF ty_alias WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING it_rows    TYPE ty_rows
                it_aliases TYPE ty_aliases OPTIONAL.

  PRIVATE SECTION.
    CONSTANTS c_max_integer TYPE int8 VALUE '9223372036854775807'.
    CONSTANTS c_min_integer TYPE int8 VALUE -9223372036854775808.

    DATA mt_rows    TYPE ty_rows.
    DATA mt_aliases TYPE ty_aliases.

    METHODS argument_values
      IMPORTING io_function      TYPE REF TO zcl_sqlite_ast_function
                iv_distinct      TYPE abap_bool
      RETURNING VALUE(rt_values) TYPE ty_values
      RAISING   zcx_sqlite_error.

    METHODS aggregate_count
      IMPORTING io_function     TYPE REF TO zcl_sqlite_ast_function
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    METHODS aggregate_numeric
      IMPORTING io_function     TYPE REF TO zcl_sqlite_ast_function
                iv_name         TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    METHODS aggregate_minmax
      IMPORTING io_function     TYPE REF TO zcl_sqlite_ast_function
                iv_name         TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    METHODS aggregate_concat
      IMPORTING io_function     TYPE REF TO zcl_sqlite_ast_function
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    METHODS require_arity
      IMPORTING io_function TYPE REF TO zcl_sqlite_ast_function
                iv_count    TYPE i
                iv_min      TYPE i
                iv_max      TYPE i
      RAISING   zcx_sqlite_error.

    METHODS is_seen
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
                it_seen        TYPE ty_values
                iv_collation   TYPE string
      RETURNING VALUE(rv_seen) TYPE abap_bool
      RAISING   zcx_sqlite_error.

    METHODS add_overflow
      IMPORTING iv_left            TYPE int8
                iv_right           TYPE int8
      RETURNING VALUE(rv_overflow) TYPE abap_bool.

ENDCLASS.


CLASS zcl_sqlite_group_context IMPLEMENTATION.

  METHOD constructor.
    mt_rows = it_rows.
    mt_aliases = it_aliases.
  ENDMETHOD.

  METHOD zif_sqlite_eval_context~value_of.
    DATA lo_context TYPE REF TO zif_sqlite_eval_context.
    DATA ls_alias   TYPE ty_alias.

    LOOP AT mt_aliases INTO ls_alias.
      IF to_upper( ls_alias-name ) = to_upper( iv_name ).
        ro_value = ls_alias-value.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lines( mt_rows ) = 0.
      ro_value = zcl_sqlite_value=>null( ).
      RETURN.
    ENDIF.

    lo_context = mt_rows[ 1 ].
    ro_value = lo_context->value_of( iv_name ).
  ENDMETHOD.

  METHOD zif_sqlite_eval_context~aggregate.
    DATA lv_name TYPE string.

    lv_name = to_upper( io_function->get_name( ) ).
    CASE lv_name.
      WHEN 'COUNT'.
        ro_value = aggregate_count( io_function ).
      WHEN 'SUM' OR 'TOTAL' OR 'AVG'.
        ro_value = aggregate_numeric(
          io_function = io_function
          iv_name     = lv_name ).
      WHEN 'MIN' OR 'MAX'.
        ro_value = aggregate_minmax(
          io_function = io_function
          iv_name     = lv_name ).
      WHEN 'GROUP_CONCAT'.
        ro_value = aggregate_concat( io_function ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = |function { io_function->get_name( ) } is not supported yet|.
    ENDCASE.
  ENDMETHOD.

  METHOD argument_values.
    DATA lt_arguments TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lv_argument  TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_row       TYPE REF TO zcl_sqlite_row.
    DATA lo_context   TYPE REF TO zif_sqlite_eval_context.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.
    DATA lv_collation TYPE string.

    lt_arguments = io_function->get_arguments( ).
    IF lines( lt_arguments ) = 0.
      RETURN.
    ENDIF.

    lv_argument = lt_arguments[ 1 ].
    lv_collation = zcl_sqlite_expr_eval=>collation_of_expression( lv_argument ).
    IF lv_collation IS INITIAL.
      lv_collation = 'BINARY'.
    ENDIF.

    LOOP AT mt_rows INTO lo_row.
      lo_context = lo_row.
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = lv_argument
        io_context    = lo_context ).
      IF lo_value->is_null( ) = abap_true.
        CONTINUE.
      ENDIF.
      IF iv_distinct = abap_true
          AND is_seen(
            io_value     = lo_value
            it_seen      = rt_values
            iv_collation = lv_collation ) = abap_true.
        CONTINUE.
      ENDIF.
      APPEND lo_value TO rt_values.
    ENDLOOP.
  ENDMETHOD.

  METHOD aggregate_count.
    DATA lv_count TYPE i.

    IF io_function->get_star( ) = abap_true.
      IF io_function->get_distinct( ) = abap_true.
        RAISE EXCEPTION TYPE zcx_sqlite_error
          EXPORTING iv_message = |wrong number of arguments to function count()|.
      ENDIF.
      ro_value = zcl_sqlite_value=>integer( lines( mt_rows ) ).
      RETURN.
    ENDIF.

    lv_count = lines( io_function->get_arguments( ) ).
    IF lv_count = 0.
      ro_value = zcl_sqlite_value=>integer( lines( mt_rows ) ).
      RETURN.
    ENDIF.
    require_arity(
      io_function = io_function
      iv_count    = lv_count
      iv_min      = 1
      iv_max      = 1 ).

    ro_value = zcl_sqlite_value=>integer( lines( argument_values(
      io_function = io_function
      iv_distinct = io_function->get_distinct( ) ) ) ).
  ENDMETHOD.

  METHOD aggregate_numeric.
    DATA lt_values    TYPE ty_values.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.
    DATA lo_number    TYPE REF TO zcl_sqlite_value.
    DATA lv_real_mode TYPE abap_bool.
    DATA lv_int_sum   TYPE int8.
    DATA lv_real_sum  TYPE f.
    DATA lv_int_value TYPE int8.
    DATA lv_real_value TYPE f.
    DATA lv_count     TYPE i.

    lv_count = lines( io_function->get_arguments( ) ).
    require_arity(
      io_function = io_function
      iv_count    = lv_count
      iv_min      = 1
      iv_max      = 1 ).

    lt_values = argument_values(
      io_function = io_function
      iv_distinct = io_function->get_distinct( ) ).

    LOOP AT lt_values INTO lo_value.
      lo_number = zcl_sqlite_expr_eval=>value_to_aggregate_number( lo_value ).
      IF lo_number->value_type( ) = zcl_sqlite_value=>c_integer.
        lv_int_value = lo_number->as_integer( ).
        " ANORMALY: mixed int8 and f arithmetic is calculated as int8
        IF lv_real_mode = abap_true.
          lv_real_sum = lv_real_sum + CONV f( lv_int_value ).
        ELSEIF add_overflow(
            iv_left  = lv_int_sum
            iv_right = lv_int_value ) = abap_true.
          lv_real_sum = CONV f( lv_int_sum ) + CONV f( lv_int_value ).
          lv_real_mode = abap_true.
        ELSE.
          lv_int_sum = lv_int_sum + lv_int_value.
        ENDIF.
      ELSE.
        lv_real_value = lo_number->as_real( ).
        IF lv_real_mode = abap_false.
          lv_real_sum = lv_int_sum.
          lv_real_mode = abap_true.
        ENDIF.
        lv_real_sum = lv_real_sum + lv_real_value.
      ENDIF.
    ENDLOOP.

    CASE iv_name.
      WHEN 'SUM'.
        IF lines( lt_values ) = 0.
          ro_value = zcl_sqlite_value=>null( ).
        ELSEIF lv_real_mode = abap_true.
          ro_value = zcl_sqlite_value=>real( lv_real_sum ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( lv_int_sum ).
        ENDIF.
      WHEN 'TOTAL'.
        IF lv_real_mode = abap_true.
          ro_value = zcl_sqlite_value=>real( lv_real_sum ).
        ELSE.
          ro_value = zcl_sqlite_value=>real( CONV f( lv_int_sum ) ).
        ENDIF.
      WHEN 'AVG'.
        IF lines( lt_values ) = 0.
          ro_value = zcl_sqlite_value=>null( ).
        ELSEIF lv_real_mode = abap_true.
          ro_value = zcl_sqlite_value=>real( lv_real_sum / lines( lt_values ) ).
        ELSE.
          " ANORMALY: mixed int8 and f arithmetic is calculated as int8
          ro_value = zcl_sqlite_value=>real( CONV f( lv_int_sum ) / lines( lt_values ) ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.

  METHOD aggregate_minmax.
    DATA lt_values    TYPE ty_values.
    DATA lt_arguments TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.
    DATA lo_result    TYPE REF TO zcl_sqlite_value.
    DATA lv_argument  TYPE REF TO zcl_sqlite_ast_node.
    DATA lv_collation TYPE string.
    DATA lv_compare   TYPE i.
    DATA lv_count     TYPE i.

    lv_count = lines( io_function->get_arguments( ) ).
    require_arity(
      io_function = io_function
      iv_count    = lv_count
      iv_min      = 1
      iv_max      = 1 ).

    lt_values = argument_values(
      io_function = io_function
      iv_distinct = io_function->get_distinct( ) ).
    IF lines( lt_values ) = 0.
      ro_value = zcl_sqlite_value=>null( ).
      RETURN.
    ENDIF.

    lt_arguments = io_function->get_arguments( ).
    lv_argument = lt_arguments[ 1 ].
    lv_collation = zcl_sqlite_expr_eval=>collation_of_expression( lv_argument ).
    IF lv_collation IS INITIAL.
      lv_collation = 'BINARY'.
    ENDIF.

    lo_result = lt_values[ 1 ].
    LOOP AT lt_values INTO lo_value FROM 2.
      lv_compare = zcl_sqlite_expr_eval=>compare_values(
        io_left      = lo_value
        io_right     = lo_result
        iv_collation = lv_collation ).
      IF ( iv_name = 'MIN' AND lv_compare < 0 )
          OR ( iv_name = 'MAX' AND lv_compare > 0 ).
        lo_result = lo_value.
      ENDIF.
    ENDLOOP.

    ro_value = lo_result.
  ENDMETHOD.

  METHOD aggregate_concat.
    DATA lt_arguments TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lv_argument  TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_row       TYPE REF TO zcl_sqlite_row.
    DATA lo_context   TYPE REF TO zif_sqlite_eval_context.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.
    DATA lo_text      TYPE REF TO zcl_sqlite_value.
    DATA lo_separator TYPE REF TO zcl_sqlite_value.
    DATA lt_seen      TYPE ty_values.
    DATA lv_collation TYPE string.
    DATA lv_text      TYPE string.
    DATA lv_separator TYPE string.
    DATA lv_count     TYPE i.
    DATA lv_first     TYPE abap_bool.
    DATA lv_any       TYPE abap_bool.

    lt_arguments = io_function->get_arguments( ).
    lv_count = lines( lt_arguments ).
    require_arity(
      io_function = io_function
      iv_count    = lv_count
      iv_min      = 1
      iv_max      = 2 ).

    lv_argument = lt_arguments[ 1 ].
    lv_collation = zcl_sqlite_expr_eval=>collation_of_expression( lv_argument ).
    IF lv_collation IS INITIAL.
      lv_collation = 'BINARY'.
    ENDIF.
    lv_first = abap_true.

    LOOP AT mt_rows INTO lo_row.
      lo_context = lo_row.
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = lv_argument
        io_context    = lo_context ).
      IF lo_value->is_null( ) = abap_true.
        CONTINUE.
      ENDIF.
      IF io_function->get_distinct( ) = abap_true.
        IF is_seen(
            io_value     = lo_value
            it_seen      = lt_seen
            iv_collation = lv_collation ) = abap_true.
          CONTINUE.
        ENDIF.
        APPEND lo_value TO lt_seen.
      ENDIF.

      lo_text = zcl_sqlite_expr_eval=>value_to_text( lo_value ).
      lv_any = abap_true.
      IF lv_first = abap_true.
        lv_text = lo_text->as_text( ).
        lv_first = abap_false.
        CONTINUE.
      ENDIF.

      IF lv_count = 2.
        lo_separator = zcl_sqlite_expr_eval=>evaluate(
          io_expression = lt_arguments[ 2 ]
          io_context    = lo_context ).
        IF lo_separator->is_null( ) = abap_true.
          lv_separator = ''.
        ELSE.
          lv_separator = zcl_sqlite_expr_eval=>value_to_text( lo_separator )->as_text( ).
        ENDIF.
      ELSE.
        lv_separator = ','.
      ENDIF.
      lv_text = lv_text && lv_separator && lo_text->as_text( ).
    ENDLOOP.

    IF lv_any = abap_false.
      ro_value = zcl_sqlite_value=>null( ).
    ELSE.
      ro_value = zcl_sqlite_value=>text( lv_text ).
    ENDIF.
  ENDMETHOD.

  METHOD require_arity.
    IF iv_count < iv_min
        OR ( iv_max >= 0 AND iv_count > iv_max ).
      RAISE EXCEPTION TYPE zcx_sqlite_error
        EXPORTING iv_message = |wrong number of arguments to function { io_function->get_name( ) }()|.
    ENDIF.
  ENDMETHOD.

  METHOD is_seen.
    DATA lo_value TYPE REF TO zcl_sqlite_value.

    LOOP AT it_seen INTO lo_value.
      IF zcl_sqlite_expr_eval=>compare_values(
          io_left      = io_value
          io_right     = lo_value
          iv_collation = iv_collation ) = 0.
        rv_seen = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_overflow.
    IF iv_right > 0.
      rv_overflow = boolc( iv_left > c_max_integer - iv_right ).
    ELSEIF iv_right < 0.
      rv_overflow = boolc( iv_left < c_min_integer - iv_right ).
    ELSE.
      rv_overflow = abap_false.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
