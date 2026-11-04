* Evaluates SQL expressions that do not refer to rows or bound parameters.
* The semantics follow SQLite: three-valued logic, dynamic typing, the
* integer-to-real overflow rule and SQLite's text/number coercions.
CLASS zcl_sqlite_expr_eval DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS evaluate
      IMPORTING io_expression   TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_sql
      IMPORTING iv_sql          TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_integer_parse,
             value    TYPE int8,
             overflow TYPE abap_bool,
           END OF ty_integer_parse.

    TYPES: BEGIN OF ty_glob_class,
             matched TYPE abap_bool,
             valid   TYPE abap_bool,
             next    TYPE i,
           END OF ty_glob_class.

    " ANORMALY: large int8 constant literals lose precision in the transpiler
    CONSTANTS c_max_integer TYPE int8 VALUE '9223372036854775807'.
    CONSTANTS c_min_integer TYPE int8 VALUE -9223372036854775808.
    CONSTANTS c_max_integer_text TYPE string VALUE '9223372036854775807'.
    CONSTANTS c_min_magnitude_text TYPE string VALUE '9223372036854775808'.
    CONSTANTS c_int_boundary TYPE f VALUE '9.223372036854775808E+18'.
    CONSTANTS c_int_min_boundary TYPE f VALUE '-9.223372036854775808E+18'.
    CONSTANTS c_max_real TYPE f VALUE '1.7976931348623157E+308'.
    CONSTANTS c_ten_pow_14 TYPE f VALUE '1.0E+14'.
    CONSTANTS c_half TYPE f VALUE '0.5'.
    CONSTANTS c_scaled_limit TYPE int8 VALUE 1000000000000000.
    CONSTANTS c_truth_null TYPE i VALUE -1.
    CONSTANTS c_truth_false TYPE i VALUE 0.
    CONSTANTS c_truth_true TYPE i VALUE 1.

    CLASS-METHODS evaluate_literal
      IMPORTING io_literal      TYPE REF TO zcl_sqlite_ast_literal
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_unary
      IMPORTING io_unary        TYPE REF TO zcl_sqlite_ast_unary
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_binary
      IMPORTING io_binary       TYPE REF TO zcl_sqlite_ast_binary
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_case
      IMPORTING io_case         TYPE REF TO zcl_sqlite_ast_case
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_cast
      IMPORTING io_cast         TYPE REF TO zcl_sqlite_ast_cast
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_between
      IMPORTING io_between      TYPE REF TO zcl_sqlite_ast_between
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_in
      IMPORTING io_in           TYPE REF TO zcl_sqlite_ast_in
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_collate
      IMPORTING io_collate      TYPE REF TO zcl_sqlite_ast_collate
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_name
      IMPORTING io_name         TYPE REF TO zcl_sqlite_ast_name
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_function
      IMPORTING io_function     TYPE REF TO zcl_sqlite_ast_function
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_like
      IMPORTING io_like         TYPE REF TO zcl_sqlite_ast_like
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS collation_of
      IMPORTING io_expression       TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_collation) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS effective_collation
      IMPORTING io_left             TYPE REF TO zcl_sqlite_ast_node
                io_right            TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_collation) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS supported_collation
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_name) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_logic
      IMPORTING iv_operator     TYPE string
                io_left         TYPE REF TO zcl_sqlite_ast_node
                io_right        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_comparison
      IMPORTING iv_operator     TYPE string
                io_left         TYPE REF TO zcl_sqlite_ast_node
                io_right        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_is
      IMPORTING iv_operator     TYPE string
                io_left         TYPE REF TO zcl_sqlite_ast_node
                io_right        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_arithmetic
      IMPORTING iv_operator     TYPE string
                io_left         TYPE REF TO zcl_sqlite_ast_node
                io_right        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS evaluate_bitwise
      IMPORTING iv_operator     TYPE string
                io_left         TYPE REF TO zcl_sqlite_ast_node
                io_right        TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS numeric_value
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS truth_value
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_truth) TYPE i
      RAISING   zcx_sqlite_error.

    CLASS-METHODS integer_of
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_value) TYPE int8
      RAISING   zcx_sqlite_error.

    CLASS-METHODS real_of
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_value) TYPE f.

    CLASS-METHODS compare_non_null
      IMPORTING io_left           TYPE REF TO zcl_sqlite_value
                io_right          TYPE REF TO zcl_sqlite_value
                iv_collation      TYPE string DEFAULT 'BINARY'
      RETURNING VALUE(rv_compare) TYPE i
      RAISING   zcx_sqlite_error.

    CLASS-METHODS collated_text
      IMPORTING iv_text        TYPE string
                iv_collation   TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS like_match
      IMPORTING iv_text         TYPE string
                iv_pattern      TYPE string
                iv_escape       TYPE string
      RETURNING VALUE(rv_match) TYPE abap_bool.

    CLASS-METHODS glob_match
      IMPORTING iv_text         TYPE string
                iv_pattern      TYPE string
      RETURNING VALUE(rv_match) TYPE abap_bool.

    CLASS-METHODS glob_class_matches
      IMPORTING iv_pattern       TYPE string
                iv_start         TYPE i
                iv_char          TYPE string
      RETURNING VALUE(rs_result) TYPE ty_glob_class.

    CLASS-METHODS compare_int_real
      IMPORTING iv_integer        TYPE int8
                iv_real           TYPE f
      RETURNING VALUE(rv_compare) TYPE i.

    CLASS-METHODS compare_bytes
      IMPORTING iv_left           TYPE xstring
                iv_right          TYPE xstring
      RETURNING VALUE(rv_compare) TYPE i.

    CLASS-METHODS value_rank
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_rank) TYPE i
      RAISING   zcx_sqlite_error.

    CLASS-METHODS cast_value
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
                iv_type         TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS cast_to_integer
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS cast_to_real
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS cast_to_text
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS cast_to_blob
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS cast_to_numeric
      IMPORTING io_value        TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value
      RAISING   zcx_sqlite_error.

    CLASS-METHODS text_to_arithmetic
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    CLASS-METHODS text_to_numeric
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(ro_value) TYPE REF TO zcl_sqlite_value.

    CLASS-METHODS text_to_integer
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS text_to_real
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(rv_value) TYPE f.

    CLASS-METHODS integer_from_text
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(rs_value) TYPE ty_integer_parse.

    CLASS-METHODS real_from_text
      IMPORTING iv_text         TYPE string
      RETURNING VALUE(rv_value) TYPE f.

    CLASS-METHODS numeric_prefix_end
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_end) TYPE i.

    CLASS-METHODS integer_prefix_end
      IMPORTING iv_text       TYPE string
      RETURNING VALUE(rv_end) TYPE i.

    CLASS-METHODS is_integer_text
      IMPORTING iv_text          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS is_space_char
      IMPORTING iv_char          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS ascii_lower_char
      IMPORTING iv_char        TYPE string
      RETURNING VALUE(rv_char) TYPE string.

    CLASS-METHODS ascii_lower
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS rtrim_spaces
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS bool_to_int
      IMPORTING iv_value        TYPE abap_bool
      RETURNING VALUE(rv_value) TYPE i.

    CLASS-METHODS blob_as_text
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_text) TYPE string
      RAISING   zcx_sqlite_error.

    CLASS-METHODS integer_to_text
      IMPORTING iv_value       TYPE int8
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS real_to_text
      IMPORTING iv_value       TYPE f
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS strip_trailing_zeros
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS format_real_scientific
      IMPORTING iv_digits      TYPE string
                iv_exp         TYPE i
                iv_sign        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS format_real_fixed
      IMPORTING iv_digits      TYPE string
                iv_exp         TYPE i
                iv_sign        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS zero_string
      IMPORTING iv_count       TYPE i
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS power_of_ten
      IMPORTING iv_exponent     TYPE i
      RETURNING VALUE(rv_value) TYPE f.

    CLASS-METHODS add_overflow
      IMPORTING iv_left            TYPE int8
                iv_right           TYPE int8
      RETURNING VALUE(rv_overflow) TYPE abap_bool.

    CLASS-METHODS sub_overflow
      IMPORTING iv_left            TYPE int8
                iv_right           TYPE int8
      RETURNING VALUE(rv_overflow) TYPE abap_bool.

    CLASS-METHODS mul_overflow
      IMPORTING iv_left            TYPE int8
                iv_right           TYPE int8
      RETURNING VALUE(rv_overflow) TYPE abap_bool.

    CLASS-METHODS real_to_integer
      IMPORTING iv_value        TYPE f
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS integer_divide
      IMPORTING iv_left         TYPE int8
                iv_right        TYPE int8
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS integer_modulo
      IMPORTING iv_left         TYPE int8
                iv_right        TYPE int8
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS truncate_real
      IMPORTING iv_value        TYPE f
      RETURNING VALUE(rv_value) TYPE f.

    CLASS-METHODS int8_to_bytes
      IMPORTING iv_value       TYPE int8
      RETURNING VALUE(rv_data) TYPE xstring.

    CLASS-METHODS bytes_to_int8
      IMPORTING iv_data         TYPE xstring
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS bitwise_not
      IMPORTING iv_value        TYPE int8
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS shift_left
      IMPORTING iv_value        TYPE int8
                iv_shift        TYPE int8
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS shift_right
      IMPORTING iv_value        TYPE int8
                iv_shift        TYPE int8
      RETURNING VALUE(rv_value) TYPE int8.

    CLASS-METHODS raise_error
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_expr_eval IMPLEMENTATION.

  METHOD evaluate.
    DATA lo_literal  TYPE REF TO zcl_sqlite_ast_literal.
    DATA lo_unary    TYPE REF TO zcl_sqlite_ast_unary.
    DATA lo_binary   TYPE REF TO zcl_sqlite_ast_binary.
    DATA lo_case     TYPE REF TO zcl_sqlite_ast_case.
    DATA lo_cast     TYPE REF TO zcl_sqlite_ast_cast.
    DATA lo_between  TYPE REF TO zcl_sqlite_ast_between.
    DATA lo_in       TYPE REF TO zcl_sqlite_ast_in.
    DATA lo_collate  TYPE REF TO zcl_sqlite_ast_collate.
    DATA lo_name     TYPE REF TO zcl_sqlite_ast_name.
    DATA lo_function TYPE REF TO zcl_sqlite_ast_function.
    DATA lo_like     TYPE REF TO zcl_sqlite_ast_like.

    IF io_expression IS NOT BOUND.
      raise_error( 'expression is not bound' ).
    ENDIF.

    IF io_expression IS INSTANCE OF zcl_sqlite_ast_literal.
      lo_literal ?= io_expression.
      ro_value = evaluate_literal( lo_literal ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_unary.
      lo_unary ?= io_expression.
      ro_value = evaluate_unary( lo_unary ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_binary.
      lo_binary ?= io_expression.
      ro_value = evaluate_binary( lo_binary ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_case.
      lo_case ?= io_expression.
      ro_value = evaluate_case( lo_case ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_cast.
      lo_cast ?= io_expression.
      ro_value = evaluate_cast( lo_cast ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_between.
      lo_between ?= io_expression.
      ro_value = evaluate_between( lo_between ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_in.
      lo_in ?= io_expression.
      ro_value = evaluate_in( lo_in ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_collate.
      lo_collate ?= io_expression.
      ro_value = evaluate_collate( lo_collate ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_name.
      lo_name ?= io_expression.
      ro_value = evaluate_name( lo_name ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_function.
      lo_function ?= io_expression.
      ro_value = evaluate_function( lo_function ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_like.
      lo_like ?= io_expression.
      ro_value = evaluate_like( lo_like ).
    ELSE.
      raise_error( 'unsupported expression' ).
    ENDIF.
  ENDMETHOD.

  METHOD evaluate_sql.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_select    TYPE REF TO zcl_sqlite_ast_select.
    DATA lt_columns   TYPE zcl_sqlite_ast_select=>ty_columns.
    DATA lo_column    TYPE REF TO zcl_sqlite_ast_result_column.

    lo_statement = zcl_sqlite_parser=>parse_statement( iv_sql ).
    IF lo_statement IS NOT INSTANCE OF zcl_sqlite_ast_select.
      raise_error( 'expression evaluation requires a SELECT statement' ).
    ENDIF.

    lo_select ?= lo_statement.
    lt_columns = lo_select->get_columns( ).
    IF lines( lt_columns ) = 0.
      raise_error( 'SELECT statement has no result columns' ).
    ENDIF.

    READ TABLE lt_columns INTO lo_column INDEX 1.
    IF sy-subrc <> 0.
      raise_error( 'SELECT statement has no result columns' ).
    ENDIF.
    ro_value = evaluate( lo_column->get_expression( ) ).
  ENDMETHOD.

  METHOD evaluate_literal.
    DATA lv_kind  TYPE string.
    DATA lv_text  TYPE string.
    DATA lv_hex   TYPE string.
    DATA lv_data  TYPE xstring.
    DATA lv_int   TYPE int8.
    DATA ls_parse TYPE ty_integer_parse.
    DATA lv_hour  TYPE string.

    lv_kind = io_literal->get_kind( ).
    lv_text = io_literal->get_value( ).

    CASE lv_kind.
      WHEN 'NULL'.
        ro_value = zcl_sqlite_value=>null( ).
      WHEN 'INTEGER'.
        IF strlen( lv_text ) >= 2
            AND ( substring( val = lv_text len = 2 ) = '0x'
               OR substring( val = lv_text len = 2 ) = '0X' ).
          lv_hex = substring( val = lv_text off = 2 ).
          IF strlen( lv_hex ) > 16.
            raise_error( |hex literal too big: { lv_text }| ).
          ENDIF.
          WHILE strlen( lv_hex ) < 16.
            lv_hex = '0' && lv_hex.
          ENDWHILE.
          lv_data = lv_hex.
          lv_int = lv_data.
          ro_value = zcl_sqlite_value=>integer( lv_int ).
        ELSE.
          ls_parse = integer_from_text( lv_text ).
          IF ls_parse-overflow = abap_true.
            ro_value = zcl_sqlite_value=>real( real_from_text( lv_text ) ).
          ELSE.
            ro_value = zcl_sqlite_value=>integer( ls_parse-value ).
          ENDIF.
        ENDIF.
      WHEN 'REAL'.
        ro_value = zcl_sqlite_value=>real( real_from_text( lv_text ) ).
      WHEN 'STRING'.
        ro_value = zcl_sqlite_value=>text( lv_text ).
      WHEN 'BLOB'.
        lv_data = lv_text.
        ro_value = zcl_sqlite_value=>blob( lv_data ).
      WHEN 'CURRENT_DATE'.
        lv_text = sy-datum.
        CONDENSE lv_text.
        ro_value = zcl_sqlite_value=>text(
          |{ substring( val = lv_text len = 4 ) }-{ substring( val = lv_text off = 4 len = 2 ) }-{ substring( val = lv_text off = 6 len = 2 ) }| ).
      WHEN 'CURRENT_TIME'.
        lv_text = sy-uzeit.
        CONDENSE lv_text.
        ro_value = zcl_sqlite_value=>text(
          |{ substring( val = lv_text len = 2 ) }:{ substring( val = lv_text off = 2 len = 2 ) }:{ substring( val = lv_text off = 4 len = 2 ) }| ).
      WHEN 'CURRENT_TIMESTAMP'.
        lv_text = sy-datum.
        CONDENSE lv_text.
        lv_hour = sy-uzeit.
        CONDENSE lv_hour.
        ro_value = zcl_sqlite_value=>text(
          |{ substring( val = lv_text len = 4 ) }-{ substring( val = lv_text off = 4 len = 2 ) }-{ substring( val = lv_text off = 6 len = 2 ) } { substring( val = lv_hour len = 2 ) }:{ substring( val = lv_hour off = 2 len = 2 ) }:{ substring( val = lv_hour off = 4 len = 2 ) }| ).
      WHEN OTHERS.
        raise_error( |unsupported literal { lv_kind }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD evaluate_unary.
    DATA lv_operator TYPE string.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lo_number   TYPE REF TO zcl_sqlite_value.
    DATA lo_literal  TYPE REF TO zcl_sqlite_ast_literal.
    DATA lv_text     TYPE string.
    DATA lv_truth    TYPE i.

    lv_operator = io_unary->get_operator( ).
    lo_value = evaluate( io_unary->get_operand( ) ).

    CASE lv_operator.
      WHEN '+'.
        ro_value = lo_value.
      WHEN '-'.
        IF io_unary->get_operand( ) IS INSTANCE OF zcl_sqlite_ast_literal.
          lo_literal ?= io_unary->get_operand( ).
          IF lo_literal->get_kind( ) = 'INTEGER'.
            lv_text = lo_literal->get_value( ).
            WHILE strlen( lv_text ) > 1
                AND substring( val = lv_text len = 1 ) = '0'.
              lv_text = substring( val = lv_text off = 1 ).
            ENDWHILE.
            IF lv_text = '9223372036854775808'.
              ro_value = zcl_sqlite_value=>integer( c_min_integer ).
              RETURN.
            ENDIF.
          ENDIF.
        ENDIF.
        IF lo_value->is_null( ) = abap_true.
          ro_value = zcl_sqlite_value=>null( ).
          RETURN.
        ENDIF.
        lo_number = numeric_value( lo_value ).
        IF lo_number->value_type( ) = zcl_sqlite_value=>c_integer.
          IF lo_number->as_integer( ) = c_min_integer.
            ro_value = zcl_sqlite_value=>real( 0 - real_of( lo_number ) ).
          ELSE.
            ro_value = zcl_sqlite_value=>integer( 0 - lo_number->as_integer( ) ).
          ENDIF.
        ELSE.
          ro_value = zcl_sqlite_value=>real( 0 - lo_number->as_real( ) ).
        ENDIF.
      WHEN '~'.
        IF lo_value->is_null( ) = abap_true.
          ro_value = zcl_sqlite_value=>null( ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( bitwise_not( integer_of( lo_value ) ) ).
        ENDIF.
      WHEN 'NOT'.
        lv_truth = truth_value( lo_value ).
        CASE lv_truth.
          WHEN c_truth_null.
            ro_value = zcl_sqlite_value=>null( ).
          WHEN c_truth_true.
            ro_value = zcl_sqlite_value=>integer( 0 ).
          WHEN OTHERS.
            ro_value = zcl_sqlite_value=>integer( 1 ).
        ENDCASE.
      WHEN 'ISNULL'.
        IF lo_value->is_null( ) = abap_true.
          ro_value = zcl_sqlite_value=>integer( 1 ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( 0 ).
        ENDIF.
      WHEN 'NOTNULL'.
        IF lo_value->is_null( ) = abap_true.
          ro_value = zcl_sqlite_value=>integer( 0 ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( 1 ).
        ENDIF.
      WHEN OTHERS.
        raise_error( |unsupported unary operator { lv_operator }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD evaluate_binary.
    DATA lv_operator TYPE string.

    lv_operator = io_binary->get_operator( ).

    CASE lv_operator.
      WHEN 'OR' OR 'AND'.
        ro_value = evaluate_logic(
          iv_operator = lv_operator
          io_left     = io_binary->get_left( )
          io_right    = io_binary->get_right( ) ).
      WHEN '=' OR '==' OR '!=' OR '<>' OR '<' OR '<=' OR '>' OR '>='.
        ro_value = evaluate_comparison(
          iv_operator = lv_operator
          io_left     = io_binary->get_left( )
          io_right    = io_binary->get_right( ) ).
      WHEN 'IS' OR 'IS NOT'.
        ro_value = evaluate_is(
          iv_operator = lv_operator
          io_left     = io_binary->get_left( )
          io_right    = io_binary->get_right( ) ).
      WHEN '||'.
        ro_value = evaluate_comparison(
          iv_operator = lv_operator
          io_left     = io_binary->get_left( )
          io_right    = io_binary->get_right( ) ).
      WHEN '+' OR '-' OR '*' OR '/' OR '%'.
        ro_value = evaluate_arithmetic(
          iv_operator = lv_operator
          io_left     = io_binary->get_left( )
          io_right    = io_binary->get_right( ) ).
      WHEN '&' OR '|' OR '<<' OR '>>'.
        ro_value = evaluate_bitwise(
          iv_operator = lv_operator
          io_left     = io_binary->get_left( )
          io_right    = io_binary->get_right( ) ).
      WHEN OTHERS.
        raise_error( |unsupported binary operator { lv_operator }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD evaluate_logic.
    DATA lo_left  TYPE REF TO zcl_sqlite_value.
    DATA lo_right TYPE REF TO zcl_sqlite_value.
    DATA lv_left  TYPE int8.
    DATA lv_right TYPE int8.

    lo_left = evaluate( io_left ).
    lv_left = truth_value( lo_left ).

    IF iv_operator = 'AND'.
      IF lv_left = c_truth_false.
        ro_value = zcl_sqlite_value=>integer( 0 ).
        RETURN.
      ENDIF.
      lo_right = evaluate( io_right ).
      lv_right = truth_value( lo_right ).
      IF lv_left = c_truth_true.
        IF lv_right = c_truth_null.
          ro_value = zcl_sqlite_value=>null( ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( lv_right ).
        ENDIF.
      ELSEIF lv_right = c_truth_false.
        ro_value = zcl_sqlite_value=>integer( 0 ).
      ELSE.
        ro_value = zcl_sqlite_value=>null( ).

      ENDIF.
      RETURN.
    ENDIF.

    IF lv_left = c_truth_true.
      ro_value = zcl_sqlite_value=>integer( 1 ).
      RETURN.
    ENDIF.
    lo_right = evaluate( io_right ).
    lv_right = truth_value( lo_right ).
    IF lv_left = c_truth_false.
      IF lv_right = c_truth_null.
        ro_value = zcl_sqlite_value=>null( ).
      ELSE.
        ro_value = zcl_sqlite_value=>integer( lv_right ).
      ENDIF.
    ELSEIF lv_right = c_truth_true.
      ro_value = zcl_sqlite_value=>integer( 1 ).
    ELSE.
      ro_value = zcl_sqlite_value=>null( ).

    ENDIF.
  ENDMETHOD.

  METHOD evaluate_comparison.
    DATA lo_left  TYPE REF TO zcl_sqlite_value.
    DATA lo_right TYPE REF TO zcl_sqlite_value.
    DATA lv_compare TYPE i.
    DATA lv_collation TYPE string.
    DATA lv_result TYPE int8.

    lo_left = evaluate( io_left ).
    lo_right = evaluate( io_right ).

    IF iv_operator = '=' OR iv_operator = '==' OR iv_operator = '!='
        OR iv_operator = '<>' OR iv_operator = '<' OR iv_operator = '<='
        OR iv_operator = '>' OR iv_operator = '>='.
      IF lo_left->is_null( ) = abap_true OR lo_right->is_null( ) = abap_true.
        ro_value = zcl_sqlite_value=>null( ).
        RETURN.
      ENDIF.
      lv_collation = effective_collation( io_left = io_left io_right = io_right ).
      lv_compare = compare_non_null(
        io_left = lo_left io_right = lo_right iv_collation = lv_collation ).
      CASE iv_operator.
        WHEN '=' OR '=='.
          lv_result = bool_to_int( boolc( lv_compare = 0 ) ).
        WHEN '!=' OR '<>'.
          lv_result = bool_to_int( boolc( lv_compare <> 0 ) ).
        WHEN '<'.
          lv_result = bool_to_int( boolc( lv_compare < 0 ) ).
        WHEN '<='.
          lv_result = bool_to_int( boolc( lv_compare <= 0 ) ).
        WHEN '>'.
          lv_result = bool_to_int( boolc( lv_compare > 0 ) ).
        WHEN '>='.
          lv_result = bool_to_int( boolc( lv_compare >= 0 ) ).
      ENDCASE.
      ro_value = zcl_sqlite_value=>integer( lv_result ).
      RETURN.
    ENDIF.

    IF iv_operator = '||'.
      IF lo_left->is_null( ) = abap_true OR lo_right->is_null( ) = abap_true.
        ro_value = zcl_sqlite_value=>null( ).
      ELSE.
        ro_value = zcl_sqlite_value=>text(
          cast_to_text( lo_left )->as_text( ) && cast_to_text( lo_right )->as_text( ) ).
      ENDIF.
      RETURN.
    ENDIF.

    raise_error( |unsupported comparison operator { iv_operator }| ).
  ENDMETHOD.

  METHOD evaluate_is.
    DATA lo_left  TYPE REF TO zcl_sqlite_value.
    DATA lo_right TYPE REF TO zcl_sqlite_value.
    DATA lv_collation TYPE string.
    DATA lv_result TYPE int8.

    lo_left = evaluate( io_left ).
    lo_right = evaluate( io_right ).

    IF lo_left->is_null( ) = abap_true AND lo_right->is_null( ) = abap_true.
      lv_result = 1.
    ELSEIF lo_left->is_null( ) = abap_true OR lo_right->is_null( ) = abap_true.
      lv_result = 0.
    ELSE.
      lv_collation = effective_collation( io_left = io_left io_right = io_right ).
      lv_result = bool_to_int( boolc( compare_non_null(
        io_left = lo_left io_right = lo_right iv_collation = lv_collation ) = 0 ) ).
    ENDIF.

    IF iv_operator = 'IS NOT'.
      lv_result = 1 - lv_result.
    ENDIF.
    ro_value = zcl_sqlite_value=>integer( lv_result ).
  ENDMETHOD.

  METHOD evaluate_arithmetic.
    DATA lo_left       TYPE REF TO zcl_sqlite_value.
    DATA lo_right      TYPE REF TO zcl_sqlite_value.
    DATA lo_left_num   TYPE REF TO zcl_sqlite_value.
    DATA lo_right_num  TYPE REF TO zcl_sqlite_value.
    DATA lv_left_int   TYPE int8.
    DATA lv_right_int  TYPE int8.
    DATA lv_left_real  TYPE f.
    DATA lv_right_real TYPE f.
    DATA lv_result     TYPE f.
    DATA lv_int_result TYPE int8.
    DATA lv_real_result TYPE abap_bool.

    lo_left = evaluate( io_left ).
    lo_right = evaluate( io_right ).
    IF lo_left->is_null( ) = abap_true OR lo_right->is_null( ) = abap_true.
      ro_value = zcl_sqlite_value=>null( ).
      RETURN.
    ENDIF.

    lo_left_num = numeric_value( lo_left ).
    lo_right_num = numeric_value( lo_right ).
    lv_real_result = boolc( lo_left_num->value_type( ) = zcl_sqlite_value=>c_real
                         OR lo_right_num->value_type( ) = zcl_sqlite_value=>c_real ).

    IF lv_real_result = abap_true.
      lv_left_real = real_of( lo_left_num ).
      lv_right_real = real_of( lo_right_num ).
      CASE iv_operator.
        WHEN '+'.
          lv_result = lv_left_real + lv_right_real.
        WHEN '-'.
          lv_result = lv_left_real - lv_right_real.
        WHEN '*'.
          lv_result = lv_left_real * lv_right_real.
        WHEN '/'.
          IF lv_right_real = 0.
            ro_value = zcl_sqlite_value=>null( ).
            RETURN.
          ENDIF.
          lv_result = lv_left_real / lv_right_real.
        WHEN '%'.
          lv_left_int = integer_of( lo_left_num ).
          lv_right_int = integer_of( lo_right_num ).
          IF lv_right_int = 0.
            ro_value = zcl_sqlite_value=>null( ).
            RETURN.
          ENDIF.
          IF lv_left_int = c_min_integer AND lv_right_int = -1.
            lv_int_result = 0.
          ELSE.
            lv_int_result = integer_modulo( iv_left = lv_left_int iv_right = lv_right_int ).
          ENDIF.
          ro_value = zcl_sqlite_value=>real( CONV f( lv_int_result ) ).
          RETURN.
        WHEN OTHERS.
          raise_error( |unsupported arithmetic operator { iv_operator }| ).
      ENDCASE.
      IF lv_result <> lv_result.
        ro_value = zcl_sqlite_value=>null( ).
      ELSE.
        ro_value = zcl_sqlite_value=>real( lv_result ).
      ENDIF.
      RETURN.
    ENDIF.

    lv_left_int = lo_left_num->as_integer( ).
    lv_right_int = lo_right_num->as_integer( ).

    CASE iv_operator.
      WHEN '+'.
        IF add_overflow( iv_left = lv_left_int iv_right = lv_right_int ) = abap_true.
          ro_value = zcl_sqlite_value=>real( real_of( lo_left_num ) + real_of( lo_right_num ) ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( lv_left_int + lv_right_int ).
        ENDIF.
      WHEN '-'.
        IF sub_overflow( iv_left = lv_left_int iv_right = lv_right_int ) = abap_true.
          ro_value = zcl_sqlite_value=>real( real_of( lo_left_num ) - real_of( lo_right_num ) ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( lv_left_int - lv_right_int ).
        ENDIF.
      WHEN '*'.
        IF mul_overflow( iv_left = lv_left_int iv_right = lv_right_int ) = abap_true.
          ro_value = zcl_sqlite_value=>real( real_of( lo_left_num ) * real_of( lo_right_num ) ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( lv_left_int * lv_right_int ).
        ENDIF.
      WHEN '/'.
        IF lv_right_int = 0.
          ro_value = zcl_sqlite_value=>null( ).
        ELSEIF lv_left_int = c_min_integer AND lv_right_int = -1.
          ro_value = zcl_sqlite_value=>real( real_of( lo_left_num ) / real_of( lo_right_num ) ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer(
            integer_divide( iv_left = lv_left_int iv_right = lv_right_int ) ).
        ENDIF.
      WHEN '%'.
        IF lv_right_int = 0.
          ro_value = zcl_sqlite_value=>null( ).
        ELSEIF lv_left_int = c_min_integer AND lv_right_int = -1.
          ro_value = zcl_sqlite_value=>integer( 0 ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer(
            integer_modulo( iv_left = lv_left_int iv_right = lv_right_int ) ).
        ENDIF.
      WHEN OTHERS.
        raise_error( |unsupported arithmetic operator { iv_operator }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD evaluate_bitwise.
    DATA lo_left  TYPE REF TO zcl_sqlite_value.
    DATA lo_right TYPE REF TO zcl_sqlite_value.
    DATA lv_left  TYPE int8.
    DATA lv_right TYPE int8.
    DATA lv_data  TYPE xstring.
    DATA lv_shift TYPE int8.

    lo_left = evaluate( io_left ).
    lo_right = evaluate( io_right ).
    IF lo_left->is_null( ) = abap_true OR lo_right->is_null( ) = abap_true.
      ro_value = zcl_sqlite_value=>null( ).
      RETURN.
    ENDIF.

    lv_left = integer_of( lo_left ).
    lv_right = integer_of( lo_right ).

    CASE iv_operator.
      WHEN '&'.
        lv_data = int8_to_bytes( lv_left ) BIT-AND int8_to_bytes( lv_right ).
        ro_value = zcl_sqlite_value=>integer( bytes_to_int8( lv_data ) ).
      WHEN '|'.
        lv_data = int8_to_bytes( lv_left ) BIT-OR int8_to_bytes( lv_right ).
        ro_value = zcl_sqlite_value=>integer( bytes_to_int8( lv_data ) ).
      WHEN '<<'.
        IF lv_right < 0.
          IF lv_right < -64.
            lv_shift = 64.
          ELSE.
            lv_shift = 0 - lv_right.
          ENDIF.
          ro_value = zcl_sqlite_value=>integer( shift_right( iv_value = lv_left iv_shift = lv_shift ) ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( shift_left( iv_value = lv_left iv_shift = lv_right ) ).
        ENDIF.
      WHEN '>>'.
        IF lv_right < 0.
          IF lv_right < -64.
            lv_shift = 64.
          ELSE.
            lv_shift = 0 - lv_right.
          ENDIF.
          ro_value = zcl_sqlite_value=>integer( shift_left( iv_value = lv_left iv_shift = lv_shift ) ).
        ELSE.
          ro_value = zcl_sqlite_value=>integer( shift_right( iv_value = lv_left iv_shift = lv_right ) ).
        ENDIF.
      WHEN OTHERS.
        raise_error( |unsupported bitwise operator { iv_operator }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD evaluate_between.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lo_low   TYPE REF TO zcl_sqlite_value.
    DATA lo_high  TYPE REF TO zcl_sqlite_value.
    DATA lv_collation TYPE string.
    DATA lv_first TYPE i.
    DATA lv_second TYPE i.
    DATA lv_result TYPE int8.

    lo_value = evaluate( io_between->get_expression( ) ).
    lo_low = evaluate( io_between->get_low( ) ).

    IF lo_value->is_null( ) = abap_true OR lo_low->is_null( ) = abap_true.
      lv_first = c_truth_null.
    ELSE.
      lv_collation = effective_collation(
        io_left = io_between->get_expression( )
        io_right = io_between->get_low( ) ).
      lv_first = bool_to_int( boolc( compare_non_null(
        io_left = lo_value io_right = lo_low iv_collation = lv_collation ) >= 0 ) ).
    ENDIF.

    CASE lv_first.
      WHEN c_truth_false.
        lv_result = 0.
      WHEN c_truth_null.
        lv_result = c_truth_null.
      WHEN OTHERS.
        lo_high = evaluate( io_between->get_high( ) ).
        IF lo_high->is_null( ) = abap_true.
          lv_second = c_truth_null.
        ELSE.
          lv_collation = effective_collation(
            io_left = io_between->get_expression( )
            io_right = io_between->get_high( ) ).
          lv_second = bool_to_int( boolc( compare_non_null(
            io_left = lo_value io_right = lo_high iv_collation = lv_collation ) <= 0 ) ).
        ENDIF.
        lv_result = lv_second.
    ENDCASE.

    IF io_between->is_negated( ) = abap_true AND lv_result <> c_truth_null.
      lv_result = 1 - lv_result.
    ENDIF.

    IF lv_result = c_truth_null.
      ro_value = zcl_sqlite_value=>null( ).
    ELSE.
      ro_value = zcl_sqlite_value=>integer( lv_result ).
    ENDIF.
  ENDMETHOD.

  METHOD evaluate_in.
    DATA lo_value     TYPE REF TO zcl_sqlite_value.
    DATA lo_candidate TYPE REF TO zcl_sqlite_value.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA lt_values    TYPE zcl_sqlite_ast_node=>ty_nodes.
    DATA lv_collation TYPE string.
    DATA lv_found     TYPE abap_bool.
    DATA lv_saw_null  TYPE abap_bool.
    DATA lv_result    TYPE int8.

    IF io_in->get_select( ) IS BOUND.
      raise_error( 'IN subquery is not supported in a constant expression' ).
    ENDIF.

    lo_value = evaluate( io_in->get_expression( ) ).
    lt_values = io_in->get_values( ).
    lv_collation = collation_of( io_in->get_expression( ) ).
    IF lv_collation IS INITIAL.
      lv_collation = 'BINARY'.
    ENDIF.

    IF lo_value->is_null( ) = abap_false.
      LOOP AT lt_values INTO lo_expression.
        lo_candidate = evaluate( lo_expression ).
        IF lo_candidate->is_null( ) = abap_true.
          lv_saw_null = abap_true.
          CONTINUE.
        ENDIF.
        IF compare_non_null(
            io_left = lo_value io_right = lo_candidate
            iv_collation = lv_collation ) = 0.
          lv_found = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
    ELSE.
      lv_saw_null = abap_true.
    ENDIF.

    IF lv_found = abap_true.
      lv_result = 1.
    ELSEIF lv_saw_null = abap_true.
      lv_result = c_truth_null.
    ELSE.
      lv_result = 0.
    ENDIF.

    IF io_in->is_negated( ) = abap_true AND lv_result <> c_truth_null.
      lv_result = 1 - lv_result.
    ENDIF.

    IF lv_result = c_truth_null.
      ro_value = zcl_sqlite_value=>null( ).
    ELSE.
      ro_value = zcl_sqlite_value=>integer( lv_result ).
    ENDIF.
  ENDMETHOD.

  METHOD evaluate_collate.
    supported_collation( io_collate->get_name( ) ).
    ro_value = evaluate( io_collate->get_expression( ) ).
  ENDMETHOD.

  METHOD evaluate_name.
    CASE io_name->get_kind( ).
      WHEN zcl_sqlite_ast_name=>c_column.
        raise_error( |no such column: { io_name->get_text( ) }| ).
      WHEN zcl_sqlite_ast_name=>c_parameter.
        raise_error( |no such parameter: { io_name->get_text( ) }| ).
      WHEN OTHERS.
        raise_error( 'star is not a constant expression' ).
    ENDCASE.
  ENDMETHOD.

  METHOD evaluate_function.
    raise_error( |function { io_function->get_name( ) } is not supported yet| ).
  ENDMETHOD.

  METHOD evaluate_like.
    DATA lo_value   TYPE REF TO zcl_sqlite_value.
    DATA lo_pattern TYPE REF TO zcl_sqlite_value.
    DATA lo_escape  TYPE REF TO zcl_sqlite_value.
    DATA lv_text    TYPE string.
    DATA lv_pattern TYPE string.
    DATA lv_escape  TYPE string.
    DATA lv_match   TYPE abap_bool.

    IF io_like->get_operator( ) = 'GLOB'
        AND io_like->get_escape( ) IS BOUND.
      raise_error( 'wrong number of arguments to function GLOB()' ).
    ENDIF.

    lo_value = evaluate( io_like->get_expression( ) ).
    lo_pattern = evaluate( io_like->get_pattern( ) ).

    IF io_like->get_escape( ) IS BOUND.
      lo_escape = evaluate( io_like->get_escape( ) ).
      IF lo_escape->is_null( ) = abap_true.
        ro_value = zcl_sqlite_value=>null( ).
        RETURN.
      ENDIF.
      lv_escape = cast_to_text( lo_escape )->as_text( ).
      IF strlen( lv_escape ) <> 1.
        raise_error( 'ESCAPE expression must be a single character' ).
      ENDIF.
    ENDIF.

    IF lo_value->is_null( ) = abap_true OR lo_pattern->is_null( ) = abap_true.
      ro_value = zcl_sqlite_value=>null( ).
      RETURN.
    ENDIF.

    lv_text = cast_to_text( lo_value )->as_text( ).
    lv_pattern = cast_to_text( lo_pattern )->as_text( ).

    CASE io_like->get_operator( ).
      WHEN 'LIKE'.
        lv_match = like_match(
          iv_text = lv_text iv_pattern = lv_pattern iv_escape = lv_escape ).
      WHEN 'GLOB'.
        lv_match = glob_match( iv_text = lv_text iv_pattern = lv_pattern ).
      WHEN OTHERS.
        raise_error( |unsupported pattern operator { io_like->get_operator( ) }| ).
    ENDCASE.

    IF io_like->is_negated( ) = abap_true.
      lv_match = boolc( lv_match = abap_false ).
    ENDIF.

    ro_value = zcl_sqlite_value=>integer( bool_to_int( lv_match ) ).
  ENDMETHOD.

  METHOD collation_of.
    DATA lo_binary  TYPE REF TO zcl_sqlite_ast_binary.
    DATA lo_unary   TYPE REF TO zcl_sqlite_ast_unary.
    DATA lo_cast    TYPE REF TO zcl_sqlite_ast_cast.
    DATA lo_case    TYPE REF TO zcl_sqlite_ast_case.
    DATA lo_collate TYPE REF TO zcl_sqlite_ast_collate.
    DATA lt_whens   TYPE zcl_sqlite_ast_case=>ty_whens.
    DATA ls_when    TYPE zcl_sqlite_ast_case=>ty_when.

    IF io_expression IS NOT BOUND.
      RETURN.
    ENDIF.

    IF io_expression IS INSTANCE OF zcl_sqlite_ast_collate.
      lo_collate ?= io_expression.
      rv_collation = supported_collation( lo_collate->get_name( ) ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_binary.
      lo_binary ?= io_expression.
      IF lo_binary->get_operator( ) = '||'.
        rv_collation = collation_of( lo_binary->get_left( ) ).
        IF rv_collation IS INITIAL.
          rv_collation = collation_of( lo_binary->get_right( ) ).
        ENDIF.
      ENDIF.
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_unary.
      lo_unary ?= io_expression.
      rv_collation = collation_of( lo_unary->get_operand( ) ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_cast.
      lo_cast ?= io_expression.
      rv_collation = collation_of( lo_cast->get_expression( ) ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_case.
      lo_case ?= io_expression.
      lt_whens = lo_case->get_whens( ).
      LOOP AT lt_whens INTO ls_when.
        rv_collation = collation_of( ls_when-result ).
        IF rv_collation IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDLOOP.
      rv_collation = collation_of( lo_case->get_else( ) ).
    ENDIF.
  ENDMETHOD.

  METHOD effective_collation.
    rv_collation = collation_of( io_left ).
    IF rv_collation IS INITIAL.
      rv_collation = collation_of( io_right ).
    ENDIF.
    IF rv_collation IS INITIAL.
      rv_collation = 'BINARY'.
    ENDIF.
  ENDMETHOD.

  METHOD supported_collation.
    CASE iv_name.
      WHEN 'BINARY' OR 'NOCASE' OR 'RTRIM'.
        rv_name = iv_name.
      WHEN OTHERS.
        raise_error( |no such collation sequence: { iv_name }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD collated_text.
    CASE iv_collation.
      WHEN 'NOCASE'.
        rv_text = ascii_lower( iv_text ).
      WHEN 'RTRIM'.
        rv_text = rtrim_spaces( iv_text ).
      WHEN OTHERS.
        rv_text = iv_text.
    ENDCASE.
  ENDMETHOD.

  METHOD like_match.
    DATA lv_text_length    TYPE i.
    DATA lv_pattern_length TYPE i.
    DATA lv_text_index     TYPE i VALUE 1.
    DATA lv_pattern_index  TYPE i VALUE 1.
    DATA lv_star_pattern   TYPE i VALUE 0.
    DATA lv_star_text      TYPE i VALUE 0.
    DATA lv_pattern_char   TYPE string.
    DATA lv_text_char      TYPE string.
    DATA lv_literal_char   TYPE string.

    lv_text_length = strlen( iv_text ).
    lv_pattern_length = strlen( iv_pattern ).

    WHILE lv_text_index <= lv_text_length.
      IF lv_pattern_index > lv_pattern_length.
        IF lv_star_pattern > 0.
          lv_pattern_index = lv_star_pattern.
          lv_star_text = lv_star_text + 1.
          lv_text_index = lv_star_text.
          CONTINUE.
        ELSE.
          rv_match = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      lv_pattern_char = substring(
        val = iv_pattern off = lv_pattern_index - 1 len = 1 ).

      IF iv_escape IS NOT INITIAL AND lv_pattern_char = iv_escape.
        IF lv_pattern_index < lv_pattern_length.
          lv_literal_char = substring(
            val = iv_pattern off = lv_pattern_index len = 1 ).
          lv_text_char = substring(
            val = iv_text off = lv_text_index - 1 len = 1 ).
          IF ascii_lower_char( lv_literal_char )
              = ascii_lower_char( lv_text_char ).
            lv_pattern_index = lv_pattern_index + 2.
            lv_text_index = lv_text_index + 1.
            CONTINUE.
          ENDIF.
        ENDIF.
        IF lv_star_pattern > 0.
          lv_pattern_index = lv_star_pattern.
          lv_star_text = lv_star_text + 1.
          lv_text_index = lv_star_text.
          CONTINUE.
        ELSE.
          rv_match = abap_false.
          RETURN.
        ENDIF.
      ELSEIF lv_pattern_char = '%'.
        lv_star_pattern = lv_pattern_index + 1.
        lv_star_text = lv_text_index.
        lv_pattern_index = lv_pattern_index + 1.
        CONTINUE.
      ELSEIF lv_pattern_char = '_'.
        lv_pattern_index = lv_pattern_index + 1.
        lv_text_index = lv_text_index + 1.
        CONTINUE.
      ELSE.
        lv_text_char = substring(
          val = iv_text off = lv_text_index - 1 len = 1 ).
        IF ascii_lower_char( lv_pattern_char )
            = ascii_lower_char( lv_text_char ).
          lv_pattern_index = lv_pattern_index + 1.
          lv_text_index = lv_text_index + 1.
          CONTINUE.
        ENDIF.
        IF lv_star_pattern > 0.
          lv_pattern_index = lv_star_pattern.
          lv_star_text = lv_star_text + 1.
          lv_text_index = lv_star_text.
          CONTINUE.
        ELSE.
          rv_match = abap_false.
          RETURN.
        ENDIF.
      ENDIF.
    ENDWHILE.

    WHILE lv_pattern_index <= lv_pattern_length.
      lv_pattern_char = substring(
        val = iv_pattern off = lv_pattern_index - 1 len = 1 ).
      IF lv_pattern_char = '%'
          AND ( iv_escape IS INITIAL OR lv_pattern_char <> iv_escape ).
        lv_pattern_index = lv_pattern_index + 1.
      ELSE.
        rv_match = abap_false.
        RETURN.
      ENDIF.
    ENDWHILE.

    rv_match = abap_true.
  ENDMETHOD.

  METHOD glob_match.
    DATA lv_text_length    TYPE i.
    DATA lv_pattern_length TYPE i.
    DATA lv_text_index     TYPE i VALUE 1.
    DATA lv_pattern_index  TYPE i VALUE 1.
    DATA lv_star_pattern   TYPE i VALUE 0.
    DATA lv_star_text      TYPE i VALUE 0.
    DATA lv_pattern_char   TYPE string.
    DATA lv_text_char      TYPE string.
    DATA ls_class          TYPE ty_glob_class.

    lv_text_length = strlen( iv_text ).
    lv_pattern_length = strlen( iv_pattern ).

    WHILE lv_text_index <= lv_text_length.
      IF lv_pattern_index > lv_pattern_length.
        IF lv_star_pattern > 0.
          lv_pattern_index = lv_star_pattern.
          lv_star_text = lv_star_text + 1.
          lv_text_index = lv_star_text.
          CONTINUE.
        ELSE.
          rv_match = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      lv_pattern_char = substring(
        val = iv_pattern off = lv_pattern_index - 1 len = 1 ).

      CASE lv_pattern_char.
        WHEN '*'.
          lv_star_pattern = lv_pattern_index + 1.
          lv_star_text = lv_text_index.
          lv_pattern_index = lv_pattern_index + 1.
        WHEN '?'.
          lv_pattern_index = lv_pattern_index + 1.
          lv_text_index = lv_text_index + 1.
        WHEN '['.
          lv_text_char = substring(
            val = iv_text off = lv_text_index - 1 len = 1 ).
          ls_class = glob_class_matches(
            iv_pattern = iv_pattern
            iv_start = lv_pattern_index
            iv_char = lv_text_char ).
          IF ls_class-valid = abap_true AND ls_class-matched = abap_true.
            lv_pattern_index = ls_class-next.
            lv_text_index = lv_text_index + 1.
          ELSEIF lv_star_pattern > 0.
            lv_pattern_index = lv_star_pattern.
            lv_star_text = lv_star_text + 1.
            lv_text_index = lv_star_text.
          ELSE.
            rv_match = abap_false.
            RETURN.
          ENDIF.
        WHEN OTHERS.
          lv_text_char = substring(
            val = iv_text off = lv_text_index - 1 len = 1 ).
          IF lv_pattern_char = lv_text_char.
            lv_pattern_index = lv_pattern_index + 1.
            lv_text_index = lv_text_index + 1.
          ELSEIF lv_star_pattern > 0.
            lv_pattern_index = lv_star_pattern.
            lv_star_text = lv_star_text + 1.
            lv_text_index = lv_star_text.
          ELSE.
            rv_match = abap_false.
            RETURN.
          ENDIF.
      ENDCASE.
    ENDWHILE.

    WHILE lv_pattern_index <= lv_pattern_length.
      lv_pattern_char = substring(
        val = iv_pattern off = lv_pattern_index - 1 len = 1 ).
      IF lv_pattern_char = '*'.
        lv_pattern_index = lv_pattern_index + 1.
      ELSE.
        rv_match = abap_false.
        RETURN.
      ENDIF.
    ENDWHILE.

    rv_match = abap_true.
  ENDMETHOD.

  METHOD glob_class_matches.
    DATA lv_length      TYPE i.
    DATA lv_index       TYPE i.
    DATA lv_char        TYPE string.
    DATA lv_start_char  TYPE string.
    DATA lv_end_char    TYPE string.
    DATA lv_negated     TYPE abap_bool.
    DATA lv_first       TYPE abap_bool.
    DATA lv_matched     TYPE abap_bool.

    rs_result-valid = abap_false.
    rs_result-matched = abap_false.
    rs_result-next = 0.

    lv_length = strlen( iv_pattern ).
    lv_index = iv_start + 1.
    IF lv_index > lv_length.
      RETURN.
    ENDIF.

    lv_char = substring( val = iv_pattern off = lv_index - 1 len = 1 ).
    IF lv_char = '^'.
      lv_negated = abap_true.
      lv_index = lv_index + 1.
    ENDIF.

    lv_first = abap_true.
    WHILE lv_index <= lv_length.
      lv_char = substring( val = iv_pattern off = lv_index - 1 len = 1 ).

      IF lv_char = ']' AND lv_first = abap_false.
        rs_result-valid = abap_true.
        rs_result-next = lv_index + 1.
        rs_result-matched = boolc( lv_matched <> lv_negated ).
        RETURN.
      ENDIF.

      IF lv_char = ']' AND lv_first = abap_true.
        IF iv_char = lv_char.
          lv_matched = abap_true.
        ENDIF.
        lv_first = abap_false.
        lv_index = lv_index + 1.
        CONTINUE.
      ENDIF.

      IF lv_index + 2 <= lv_length
          AND substring( val = iv_pattern off = lv_index len = 1 ) = '-'
          AND substring( val = iv_pattern off = lv_index + 1 len = 1 ) <> ']'.
        lv_start_char = lv_char.
        lv_end_char = substring( val = iv_pattern off = lv_index + 1 len = 1 ).
        IF iv_char >= lv_start_char AND iv_char <= lv_end_char.
          lv_matched = abap_true.
        ENDIF.
        lv_index = lv_index + 3.
      ELSE.
        IF iv_char = lv_char.
          lv_matched = abap_true.
        ENDIF.
        lv_index = lv_index + 1.
      ENDIF.
      lv_first = abap_false.
    ENDWHILE.
  ENDMETHOD.

  METHOD ascii_lower_char.
    IF iv_char >= |A| AND iv_char <= |Z|.
      rv_char = to_lower( iv_char ).
    ELSE.
      rv_char = iv_char.
    ENDIF.
  ENDMETHOD.

  METHOD ascii_lower.
    DATA lv_length TYPE i.
    DATA lv_index  TYPE i.
    DATA lv_char   TYPE string.

    lv_length = strlen( iv_text ).
    DO lv_length TIMES.
      lv_index = sy-index - 1.
      lv_char = substring( val = iv_text off = lv_index len = 1 ).
      rv_text = rv_text && ascii_lower_char( lv_char ).
    ENDDO.
  ENDMETHOD.

  METHOD rtrim_spaces.
    DATA lv_length TYPE i.

    rv_text = iv_text.
    lv_length = strlen( rv_text ).
    WHILE lv_length > 0.
      " ANORMALY: a string does not compare equal to the character literal ' '
      IF substring( val = rv_text off = lv_length - 1 len = 1 ) <> | |.
        EXIT.
      ENDIF.
      lv_length = lv_length - 1.
    ENDWHILE.
    IF lv_length < strlen( rv_text ).
      rv_text = substring( val = rv_text len = lv_length ).
    ENDIF.
  ENDMETHOD.

  METHOD evaluate_case.
    DATA lo_base TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_base_value TYPE REF TO zcl_sqlite_value.
    DATA lo_condition TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_result TYPE REF TO zcl_sqlite_value.
    DATA lt_whens TYPE zcl_sqlite_ast_case=>ty_whens.
    DATA ls_when TYPE zcl_sqlite_ast_case=>ty_when.
    DATA lv_collation TYPE string.

    lt_whens = io_case->get_whens( ).
    lo_base = io_case->get_base( ).

    IF lo_base IS BOUND.
      lo_base_value = evaluate( lo_base ).
      IF lo_base_value->is_null( ) = abap_false.
        LOOP AT lt_whens INTO ls_when.
          lo_result = evaluate( ls_when-condition ).
          IF lo_result->is_null( ) = abap_true.
            CONTINUE.
          ENDIF.
          lv_collation = effective_collation(
            io_left = lo_base io_right = ls_when-condition ).
          IF compare_non_null(
              io_left = lo_base_value io_right = lo_result
              iv_collation = lv_collation ) = 0.
            ro_value = evaluate( ls_when-result ).
            RETURN.
          ENDIF.
        ENDLOOP.
      ENDIF.
    ELSE.
      LOOP AT lt_whens INTO ls_when.
        lo_result = evaluate( ls_when-condition ).
        IF truth_value( lo_result ) = c_truth_true.
          ro_value = evaluate( ls_when-result ).
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF io_case->get_else( ) IS BOUND.
      ro_value = evaluate( io_case->get_else( ) ).
    ELSE.
      ro_value = zcl_sqlite_value=>null( ).
    ENDIF.
  ENDMETHOD.

  METHOD evaluate_cast.
    DATA lo_value TYPE REF TO zcl_sqlite_value.
    DATA lv_affinity TYPE string.

    lo_value = evaluate( io_cast->get_expression( ) ).
    IF lo_value->is_null( ) = abap_true.
      ro_value = zcl_sqlite_value=>null( ).
      RETURN.
    ENDIF.

    lv_affinity = zcl_sqlite_schema=>affinity_of( io_cast->get_type( ) ).
    CASE lv_affinity.
      WHEN zcl_sqlite_schema=>c_affinity_integer.
        ro_value = cast_to_integer( lo_value ).
      WHEN zcl_sqlite_schema=>c_affinity_text.
        ro_value = cast_to_text( lo_value ).
      WHEN zcl_sqlite_schema=>c_affinity_blob.
        ro_value = cast_to_blob( lo_value ).
      WHEN zcl_sqlite_schema=>c_affinity_real.
        ro_value = cast_to_real( lo_value ).
      WHEN OTHERS.
        ro_value = cast_to_numeric( lo_value ).
    ENDCASE.
  ENDMETHOD.

  METHOD numeric_value.
    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_null.
        ro_value = zcl_sqlite_value=>null( ).
      WHEN zcl_sqlite_value=>c_integer OR zcl_sqlite_value=>c_real.
        ro_value = io_value.
      WHEN zcl_sqlite_value=>c_text.
        ro_value = text_to_arithmetic( io_value->as_text( ) ).
      WHEN zcl_sqlite_value=>c_blob.
        ro_value = text_to_arithmetic( blob_as_text( io_value ) ).
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD truth_value.
    DATA lo_number TYPE REF TO zcl_sqlite_value.
    DATA lv_integer TYPE int8.
    DATA lv_real TYPE f.

    IF io_value->is_null( ) = abap_true.
      rv_truth = c_truth_null.
      RETURN.
    ENDIF.

    lo_number = numeric_value( io_value ).
    IF lo_number->value_type( ) = zcl_sqlite_value=>c_integer.
      lv_integer = lo_number->as_integer( ).
      rv_truth = bool_to_int( boolc( lv_integer <> 0 ) ).
    ELSE.
      lv_real = lo_number->as_real( ).
      rv_truth = bool_to_int( boolc( lv_real <> 0 ) ).
    ENDIF.
  ENDMETHOD.

  METHOD integer_of.
    DATA lo_integer TYPE REF TO zcl_sqlite_value.

    IF io_value->is_null( ) = abap_true.
      rv_value = 0.
      RETURN.
    ENDIF.

    lo_integer = cast_to_integer( io_value ).
    rv_value = lo_integer->as_integer( ).
  ENDMETHOD.

  METHOD real_of.
    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_integer.
        rv_value = io_value->as_integer( ).
      WHEN zcl_sqlite_value=>c_real.
        rv_value = io_value->as_real( ).
      WHEN OTHERS.
        rv_value = 0.
    ENDCASE.
  ENDMETHOD.

  METHOD compare_non_null.
    DATA lv_left_rank TYPE i.
    DATA lv_right_rank TYPE i.
    DATA lv_left_integer TYPE int8.
    DATA lv_right_integer TYPE int8.
    DATA lv_left_real TYPE f.
    DATA lv_right_real TYPE f.
    DATA lv_left_bytes TYPE xstring.
    DATA lv_right_bytes TYPE xstring.
    DATA lv_left_text TYPE string.
    DATA lv_right_text TYPE string.

    lv_left_rank = value_rank( io_left ).
    lv_right_rank = value_rank( io_right ).
    IF lv_left_rank < lv_right_rank.
      rv_compare = -1.
      RETURN.
    ELSEIF lv_left_rank > lv_right_rank.
      rv_compare = 1.
      RETURN.
    ENDIF.

    CASE lv_left_rank.
      WHEN 0.
        rv_compare = 0.
      WHEN 1.
        IF io_left->value_type( ) = zcl_sqlite_value=>c_integer
            AND io_right->value_type( ) = zcl_sqlite_value=>c_integer.
          lv_left_integer = io_left->as_integer( ).
          lv_right_integer = io_right->as_integer( ).
          IF lv_left_integer < lv_right_integer.
            rv_compare = -1.
          ELSEIF lv_left_integer > lv_right_integer.
            rv_compare = 1.
          ELSE.
            rv_compare = 0.
          ENDIF.
        ELSEIF io_left->value_type( ) = zcl_sqlite_value=>c_integer.
          rv_compare = compare_int_real(
            iv_integer = io_left->as_integer( )
            iv_real    = io_right->as_real( ) ).
        ELSEIF io_right->value_type( ) = zcl_sqlite_value=>c_integer.
          rv_compare = 0 - compare_int_real(
            iv_integer = io_right->as_integer( )
            iv_real    = io_left->as_real( ) ).
        ELSE.
          lv_left_real = io_left->as_real( ).
          lv_right_real = io_right->as_real( ).
          IF lv_left_real < lv_right_real.
            rv_compare = -1.
          ELSEIF lv_left_real > lv_right_real.
            rv_compare = 1.
          ELSE.
            rv_compare = 0.
          ENDIF.
        ENDIF.
      WHEN 2.
        lv_left_text = collated_text(
          iv_text = io_left->as_text( ) iv_collation = iv_collation ).
        lv_right_text = collated_text(
          iv_text = io_right->as_text( ) iv_collation = iv_collation ).
        TRY.
            lv_left_bytes = zcl_sqlite_utf8=>encode( lv_left_text ).
            lv_right_bytes = zcl_sqlite_utf8=>encode( lv_right_text ).
          CATCH cx_sy_conversion_codepage.
            raise_error( 'text is not valid UTF-8' ).
        ENDTRY.
        rv_compare = compare_bytes( iv_left = lv_left_bytes iv_right = lv_right_bytes ).
      WHEN 3.
        rv_compare = compare_bytes(
          iv_left = io_left->as_blob( )
          iv_right = io_right->as_blob( ) ).
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD compare_int_real.
    DATA lv_floor_real TYPE f.
    DATA lv_floor_integer TYPE int8.

    IF iv_real <> iv_real.
      rv_compare = 1.
      RETURN.
    ENDIF.
    IF iv_real >= c_int_boundary.
      rv_compare = -1.
      RETURN.
    ENDIF.
    IF iv_real < c_int_min_boundary.
      rv_compare = 1.
      RETURN.
    ENDIF.

    lv_floor_real = floor( val = iv_real ).
    lv_floor_integer = lv_floor_real.
    IF iv_real = lv_floor_real.
      IF iv_integer < lv_floor_integer.
        rv_compare = -1.
      ELSEIF iv_integer > lv_floor_integer.
        rv_compare = 1.
      ELSE.
        rv_compare = 0.
      ENDIF.
    ELSEIF iv_integer <= lv_floor_integer.
      rv_compare = -1.
    ELSE.
      rv_compare = 1.
    ENDIF.
  ENDMETHOD.

  METHOD compare_bytes.
    DATA lv_length TYPE i.
    DATA lv_offset TYPE i.
    DATA lv_left_byte TYPE int8.
    DATA lv_right_byte TYPE int8.

    IF xstrlen( iv_left ) < xstrlen( iv_right ).
      lv_length = xstrlen( iv_left ).
    ELSE.
      lv_length = xstrlen( iv_right ).
    ENDIF.

    DO lv_length TIMES.
      lv_offset = sy-index - 1.
      lv_left_byte = zcl_sqlite_bytes=>read_u8(
        iv_data = iv_left iv_offset = lv_offset ).
      lv_right_byte = zcl_sqlite_bytes=>read_u8(
        iv_data = iv_right iv_offset = lv_offset ).
      IF lv_left_byte < lv_right_byte.
        rv_compare = -1.
        RETURN.
      ELSEIF lv_left_byte > lv_right_byte.
        rv_compare = 1.
        RETURN.
      ENDIF.
    ENDDO.

    IF xstrlen( iv_left ) < xstrlen( iv_right ).
      rv_compare = -1.
    ELSEIF xstrlen( iv_left ) > xstrlen( iv_right ).
      rv_compare = 1.
    ELSE.
      rv_compare = 0.
    ENDIF.
  ENDMETHOD.

  METHOD value_rank.
    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_null.
        rv_rank = 0.
      WHEN zcl_sqlite_value=>c_integer OR zcl_sqlite_value=>c_real.
        rv_rank = 1.
      WHEN zcl_sqlite_value=>c_text.
        rv_rank = 2.
      WHEN zcl_sqlite_value=>c_blob.
        rv_rank = 3.
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD cast_value.
    CASE zcl_sqlite_schema=>affinity_of( iv_type ).
      WHEN zcl_sqlite_schema=>c_affinity_integer.
        ro_value = cast_to_integer( io_value ).
      WHEN zcl_sqlite_schema=>c_affinity_text.
        ro_value = cast_to_text( io_value ).
      WHEN zcl_sqlite_schema=>c_affinity_blob.
        ro_value = cast_to_blob( io_value ).
      WHEN zcl_sqlite_schema=>c_affinity_real.
        ro_value = cast_to_real( io_value ).
      WHEN OTHERS.
        ro_value = cast_to_numeric( io_value ).
    ENDCASE.
  ENDMETHOD.

  METHOD cast_to_integer.
    DATA lv_integer TYPE int8.
    DATA lv_text TYPE string.

    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_integer.
        ro_value = io_value.
      WHEN zcl_sqlite_value=>c_real.
        ro_value = zcl_sqlite_value=>integer( real_to_integer( io_value->as_real( ) ) ).
      WHEN zcl_sqlite_value=>c_text.
        ro_value = zcl_sqlite_value=>integer( text_to_integer( io_value->as_text( ) ) ).
      WHEN zcl_sqlite_value=>c_blob.
        TRY.
            lv_text = zcl_sqlite_utf8=>decode( io_value->as_blob( ) ).
          CATCH cx_sy_conversion_codepage.
            lv_text = ''.
        ENDTRY.
        lv_integer = text_to_integer( lv_text ).
        ro_value = zcl_sqlite_value=>integer( lv_integer ).
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD cast_to_real.
    DATA lv_text TYPE string.

    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_integer.
        ro_value = zcl_sqlite_value=>real( io_value->as_integer( ) ).
      WHEN zcl_sqlite_value=>c_real.
        ro_value = io_value.
      WHEN zcl_sqlite_value=>c_text.
        ro_value = zcl_sqlite_value=>real( text_to_real( io_value->as_text( ) ) ).
      WHEN zcl_sqlite_value=>c_blob.
        TRY.
            lv_text = zcl_sqlite_utf8=>decode( io_value->as_blob( ) ).
          CATCH cx_sy_conversion_codepage.
            lv_text = ''.
        ENDTRY.
        ro_value = zcl_sqlite_value=>real( text_to_real( lv_text ) ).
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD cast_to_text.
    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_integer.
        ro_value = zcl_sqlite_value=>text( integer_to_text( io_value->as_integer( ) ) ).
      WHEN zcl_sqlite_value=>c_real.
        ro_value = zcl_sqlite_value=>text( real_to_text( io_value->as_real( ) ) ).
      WHEN zcl_sqlite_value=>c_text.
        ro_value = io_value.
      WHEN zcl_sqlite_value=>c_blob.
        ro_value = zcl_sqlite_value=>text( blob_as_text( io_value ) ).
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD cast_to_blob.
    DATA lv_text TYPE string.

    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_blob.
        ro_value = io_value.
      WHEN zcl_sqlite_value=>c_text.
        TRY.
            ro_value = zcl_sqlite_value=>blob( zcl_sqlite_utf8=>encode( io_value->as_text( ) ) ).
          CATCH cx_sy_conversion_codepage.
            raise_error( 'text is not valid UTF-8' ).
        ENDTRY.
      WHEN zcl_sqlite_value=>c_integer.
        lv_text = integer_to_text( io_value->as_integer( ) ).
        TRY.
            ro_value = zcl_sqlite_value=>blob( zcl_sqlite_utf8=>encode( lv_text ) ).
          CATCH cx_sy_conversion_codepage.
            raise_error( 'text is not valid UTF-8' ).
        ENDTRY.
      WHEN zcl_sqlite_value=>c_real.
        lv_text = real_to_text( io_value->as_real( ) ).
        TRY.
            ro_value = zcl_sqlite_value=>blob( zcl_sqlite_utf8=>encode( lv_text ) ).
          CATCH cx_sy_conversion_codepage.
            raise_error( 'text is not valid UTF-8' ).
        ENDTRY.
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD cast_to_numeric.
    DATA lv_text TYPE string.

    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_integer OR zcl_sqlite_value=>c_real.
        ro_value = io_value.
      WHEN zcl_sqlite_value=>c_text.
        ro_value = text_to_numeric( io_value->as_text( ) ).
      WHEN zcl_sqlite_value=>c_blob.
        TRY.
            lv_text = zcl_sqlite_utf8=>decode( io_value->as_blob( ) ).
          CATCH cx_sy_conversion_codepage.
            lv_text = ''.
        ENDTRY.
        ro_value = text_to_numeric( lv_text ).
      WHEN OTHERS.
        raise_error( 'unknown value type' ).
    ENDCASE.
  ENDMETHOD.

  METHOD text_to_arithmetic.
    DATA lv_end TYPE i.
    DATA lv_prefix TYPE string.
    DATA ls_parse TYPE ty_integer_parse.

    lv_end = numeric_prefix_end( iv_text ).
    IF lv_end = 0.
      ro_value = zcl_sqlite_value=>integer( 0 ).
      RETURN.
    ENDIF.
    lv_prefix = substring( val = iv_text len = lv_end ).

    IF is_integer_text( lv_prefix ) = abap_true.
      ls_parse = integer_from_text( lv_prefix ).
      IF ls_parse-overflow = abap_false.
        ro_value = zcl_sqlite_value=>integer( ls_parse-value ).
        RETURN.
      ENDIF.
    ENDIF.

    ro_value = zcl_sqlite_value=>real( real_from_text( lv_prefix ) ).
  ENDMETHOD.

  METHOD text_to_numeric.
    DATA lv_end TYPE i.
    DATA lv_prefix TYPE string.
    DATA lv_real TYPE f.
    DATA lv_trunc TYPE f.
    DATA lv_integer TYPE int8.
    DATA ls_parse TYPE ty_integer_parse.

    lv_end = numeric_prefix_end( iv_text ).
    IF lv_end = 0.
      ro_value = zcl_sqlite_value=>integer( 0 ).
      RETURN.
    ENDIF.
    lv_prefix = substring( val = iv_text len = lv_end ).

    IF is_integer_text( lv_prefix ) = abap_true.
      ls_parse = integer_from_text( lv_prefix ).
      IF ls_parse-overflow = abap_false.
        ro_value = zcl_sqlite_value=>integer( ls_parse-value ).
        RETURN.
      ENDIF.
      ro_value = zcl_sqlite_value=>real( real_from_text( lv_prefix ) ).
      RETURN.
    ENDIF.

    lv_real = real_from_text( lv_prefix ).
    IF lv_real >= c_int_min_boundary AND lv_real < c_int_boundary
        AND lv_real = lv_real.
      lv_trunc = truncate_real( lv_real ).
      IF lv_real = lv_trunc.
        lv_integer = lv_trunc.
        ro_value = zcl_sqlite_value=>integer( lv_integer ).
        RETURN.
      ENDIF.
    ENDIF.
    ro_value = zcl_sqlite_value=>real( lv_real ).
  ENDMETHOD.

  METHOD text_to_integer.
    DATA lv_end TYPE i.
    DATA lv_prefix TYPE string.
    DATA ls_parse TYPE ty_integer_parse.

    lv_end = integer_prefix_end( iv_text ).
    IF lv_end = 0.
      rv_value = 0.
      RETURN.
    ENDIF.
    lv_prefix = substring( val = iv_text len = lv_end ).
    ls_parse = integer_from_text( lv_prefix ).
    IF ls_parse-overflow = abap_true.
      IF lv_prefix CA '-'.
        rv_value = c_min_integer.
      ELSE.
        rv_value = c_max_integer.
      ENDIF.
    ELSE.
      rv_value = ls_parse-value.
    ENDIF.
  ENDMETHOD.

  METHOD text_to_real.
    DATA lv_end TYPE i.
    DATA lv_prefix TYPE string.

    lv_end = numeric_prefix_end( iv_text ).
    IF lv_end = 0.
      rv_value = 0.
      RETURN.
    ENDIF.
    lv_prefix = substring( val = iv_text len = lv_end ).
    rv_value = real_from_text( lv_prefix ).
  ENDMETHOD.

  METHOD integer_from_text.
    DATA lv_text TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_length TYPE i.
    DATA lv_char TYPE string.
    DATA lv_digits TYPE string.
    DATA lv_negative TYPE abap_bool.
    DATA lv_signed TYPE string.

    lv_text = iv_text.
    lv_length = strlen( lv_text ).
    lv_pos = 1.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        EXIT.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      CASE lv_char.
        WHEN '-'.
          lv_negative = abap_true.
          lv_pos = lv_pos + 1.
        WHEN '+'.
          lv_pos = lv_pos + 1.
      ENDCASE.
    ENDIF.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char < '0' OR lv_char > '9'.
        EXIT.
      ENDIF.
      lv_digits = lv_digits && lv_char.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_digits IS INITIAL.
      lv_digits = '0'.
    ENDIF.
    WHILE strlen( lv_digits ) > 1
        AND substring( val = lv_digits len = 1 ) = '0'.
      lv_digits = substring( val = lv_digits off = 1 ).
    ENDWHILE.

    IF lv_negative = abap_true.
      IF strlen( lv_digits ) > 19
          OR ( strlen( lv_digits ) = 19 AND lv_digits > c_min_magnitude_text ).
        rs_value-overflow = abap_true.
        RETURN.
      ENDIF.
      lv_signed = '-' && lv_digits.
    ELSE.
      IF strlen( lv_digits ) > 19
          OR ( strlen( lv_digits ) = 19 AND lv_digits > c_max_integer_text ).
        rs_value-overflow = abap_true.
        RETURN.
      ENDIF.
      lv_signed = lv_digits.
    ENDIF.

    rs_value-value = lv_signed.
  ENDMETHOD.

  METHOD real_from_text.
    TRY.
        rv_value = iv_text.
      CATCH cx_sy_conversion_no_number.
        rv_value = 0.
      CATCH cx_sy_conversion_overflow.
        rv_value = c_max_real.
    ENDTRY.
  ENDMETHOD.

  METHOD numeric_prefix_end.
    DATA lv_text TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_length TYPE i.
    DATA lv_char TYPE string.
    DATA lv_digits TYPE i.
    DATA lv_exponent_start TYPE i.
    DATA lv_exponent_digits TYPE i.

    lv_text = iv_text.
    lv_length = strlen( lv_text ).
    lv_pos = 1.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        EXIT.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char = '-' OR lv_char = '+'.
        lv_pos = lv_pos + 1.
      ENDIF.
    ENDIF.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char < '0' OR lv_char > '9'.
        EXIT.
      ENDIF.
      lv_digits = lv_digits + 1.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char = '.'.
        lv_pos = lv_pos + 1.
        WHILE lv_pos <= lv_length.
          lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
          IF lv_char < '0' OR lv_char > '9'.
            EXIT.
          ENDIF.
          lv_digits = lv_digits + 1.
          lv_pos = lv_pos + 1.
        ENDWHILE.
      ENDIF.
    ENDIF.

    IF lv_digits = 0.
      rv_end = 0.
      RETURN.
    ENDIF.

    lv_exponent_start = lv_pos.
    IF lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char = 'e' OR lv_char = 'E'.
        lv_pos = lv_pos + 1.
        IF lv_pos <= lv_length.
          lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
          IF lv_char = '-' OR lv_char = '+'.
            lv_pos = lv_pos + 1.
          ENDIF.
        ENDIF.
        WHILE lv_pos <= lv_length.
          lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
          IF lv_char < '0' OR lv_char > '9'.
            EXIT.
          ENDIF.
          lv_exponent_digits = lv_exponent_digits + 1.
          lv_pos = lv_pos + 1.
        ENDWHILE.
        IF lv_exponent_digits = 0.
          lv_pos = lv_exponent_start.
        ENDIF.
      ENDIF.
    ENDIF.

    rv_end = lv_pos - 1.
  ENDMETHOD.

  METHOD integer_prefix_end.
    DATA lv_text TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_length TYPE i.
    DATA lv_char TYPE string.
    DATA lv_digits TYPE i.

    lv_text = iv_text.
    lv_length = strlen( lv_text ).
    lv_pos = 1.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        EXIT.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char = '-' OR lv_char = '+'.
        lv_pos = lv_pos + 1.
      ENDIF.
    ENDIF.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char < '0' OR lv_char > '9'.
        EXIT.
      ENDIF.
      lv_digits = lv_digits + 1.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_digits = 0.
      rv_end = 0.
    ELSE.
      rv_end = lv_pos - 1.
    ENDIF.
  ENDMETHOD.

  METHOD is_integer_text.
    DATA lv_text TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_length TYPE i.
    DATA lv_char TYPE string.

    lv_text = iv_text.
    lv_length = strlen( lv_text ).
    lv_pos = 1.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        EXIT.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char = '-' OR lv_char = '+'.
        lv_pos = lv_pos + 1.
      ENDIF.
    ENDIF.

    IF lv_pos > lv_length.
      rv_result = abap_false.
      RETURN.
    ENDIF.
    lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
    IF lv_char < '0' OR lv_char > '9'.
      rv_result = abap_false.
      RETURN.
    ENDIF.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF lv_char >= '0' AND lv_char <= '9'.
        lv_pos = lv_pos + 1.
        CONTINUE.
      ENDIF.
      EXIT.
    ENDWHILE.

    WHILE lv_pos <= lv_length.
      lv_char = substring( val = lv_text off = lv_pos - 1 len = 1 ).
      IF is_space_char( lv_char ) = abap_false.
        rv_result = abap_false.
        RETURN.
      ENDIF.
      lv_pos = lv_pos + 1.
    ENDWHILE.

    rv_result = abap_true.
  ENDMETHOD.

  METHOD is_space_char.
    rv_result = boolc(
      iv_char = | |
      OR iv_char = cl_abap_char_utilities=>horizontal_tab
      OR iv_char = cl_abap_char_utilities=>vertical_tab
      OR iv_char = cl_abap_char_utilities=>newline
      OR iv_char = cl_abap_char_utilities=>form_feed
      OR iv_char = substring( val = cl_abap_char_utilities=>cr_lf len = 1 ) ).
  ENDMETHOD.

  METHOD bool_to_int.
    IF iv_value = abap_true.
      rv_value = 1.
    ELSE.
      rv_value = 0.
    ENDIF.
  ENDMETHOD.

  METHOD blob_as_text.
    TRY.
        rv_text = zcl_sqlite_utf8=>decode( io_value->as_blob( ) ).
      CATCH cx_sy_conversion_codepage.
        raise_error( 'blob is not valid UTF-8 text' ).
    ENDTRY.
  ENDMETHOD.

  METHOD integer_to_text.
    rv_text = iv_value.
    CONDENSE rv_text.
  ENDMETHOD.

  METHOD real_to_text.
    DATA lv_negative TYPE abap_bool.
    DATA lv_abs TYPE f.
    DATA lv_work TYPE f.
    DATA lv_exp TYPE i.
    DATA lv_scale_exp TYPE i.
    DATA lv_scaled_real TYPE f.
    DATA lv_scaled TYPE int8.
    DATA lv_digits TYPE string.
    DATA lv_sign TYPE string.

    IF iv_value <> iv_value.
      rv_text = 'NULL'.
      RETURN.
    ENDIF.
    IF iv_value = 0.
      rv_text = '0.0'.
      RETURN.
    ENDIF.

    IF iv_value < 0.
      lv_negative = abap_true.
      lv_abs = 0 - iv_value.
    ELSE.
      lv_abs = iv_value.
    ENDIF.

    IF lv_abs > c_max_real.
      IF lv_negative = abap_true.
        rv_text = '-Inf'.
      ELSE.
        rv_text = 'Inf'.
      ENDIF.
      RETURN.
    ENDIF.

    lv_work = lv_abs.
    lv_exp = 0.
    WHILE lv_work >= 10.
      lv_work = lv_work / 10.
      lv_exp = lv_exp + 1.
    ENDWHILE.
    WHILE lv_work < 1.
      lv_work = lv_work * 10.
      lv_exp = lv_exp - 1.
    ENDWHILE.

    lv_scale_exp = 14 - lv_exp.
    IF lv_scale_exp >= -300 AND lv_scale_exp <= 300.
      lv_scaled_real = lv_abs * power_of_ten( lv_scale_exp ).
    ELSE.
      lv_scaled_real = lv_work * c_ten_pow_14.
    ENDIF.

    lv_scaled = floor( val = lv_scaled_real + c_half ).
    IF lv_scaled >= c_scaled_limit.
      lv_scaled = lv_scaled DIV 10.
      lv_exp = lv_exp + 1.
    ENDIF.

    lv_digits = integer_to_text( lv_scaled ).
    WHILE strlen( lv_digits ) < 15.
      lv_digits = '0' && lv_digits.
    ENDWHILE.

    IF lv_negative = abap_true.
      lv_sign = '-'.
    ENDIF.

    IF lv_exp < -4 OR lv_exp >= 15.
      rv_text = format_real_scientific(
        iv_digits = lv_digits iv_exp = lv_exp iv_sign = lv_sign ).
    ELSE.
      rv_text = format_real_fixed(
        iv_digits = lv_digits iv_exp = lv_exp iv_sign = lv_sign ).
    ENDIF.
  ENDMETHOD.

  METHOD strip_trailing_zeros.
    DATA lv_length TYPE i.
    DATA lv_last TYPE string.

    lv_length = strlen( iv_text ).
    WHILE lv_length > 0.
      lv_last = substring( val = iv_text off = lv_length - 1 len = 1 ).
      IF lv_last <> '0'.
        EXIT.
      ENDIF.
      lv_length = lv_length - 1.
    ENDWHILE.
    rv_text = substring( val = iv_text len = lv_length ).
  ENDMETHOD.

  METHOD format_real_scientific.
    DATA lv_fraction TYPE string.
    DATA lv_exp_text TYPE string.
    DATA lv_exp_abs TYPE int8.
    DATA lv_exp_sign TYPE string.

    lv_fraction = strip_trailing_zeros( substring( val = iv_digits off = 1 ) ).
    IF lv_fraction IS INITIAL.
      lv_fraction = '0'.
    ENDIF.

    lv_exp_abs = iv_exp.
    IF lv_exp_abs < 0.
      lv_exp_abs = 0 - lv_exp_abs.
      lv_exp_sign = '-'.
    ELSE.
      lv_exp_sign = '+'.
    ENDIF.
    lv_exp_text = integer_to_text( lv_exp_abs ).
    WHILE strlen( lv_exp_text ) < 2.
      lv_exp_text = '0' && lv_exp_text.
    ENDWHILE.

    rv_text = |{ iv_sign }{ substring( val = iv_digits len = 1 ) }.{ lv_fraction }e{ lv_exp_sign }{ lv_exp_text }|.
  ENDMETHOD.

  METHOD format_real_fixed.
    DATA lv_fraction TYPE string.
    DATA lv_integer_part TYPE string.
    DATA lv_pos TYPE i.
    DATA lv_zeros TYPE i.

    IF iv_exp >= 0.
      lv_pos = iv_exp + 1.
      lv_integer_part = substring( val = iv_digits len = lv_pos ).
      IF lv_pos < 15.
        lv_fraction = strip_trailing_zeros( substring( val = iv_digits off = lv_pos ) ).
        IF lv_fraction IS NOT INITIAL.
          rv_text = iv_sign && lv_integer_part && '.' && lv_fraction.
          RETURN.
        ENDIF.
      ENDIF.
      rv_text = iv_sign && lv_integer_part && '.0'.
      RETURN.
    ENDIF.

    lv_zeros = 0 - iv_exp - 1.
    lv_fraction = strip_trailing_zeros( zero_string( lv_zeros ) && iv_digits ).
    IF lv_fraction IS INITIAL.
      lv_fraction = '0'.
    ENDIF.
    rv_text = iv_sign && '0.' && lv_fraction.
  ENDMETHOD.

  METHOD zero_string.
    DO iv_count TIMES.
      rv_text = rv_text && '0'.
    ENDDO.
  ENDMETHOD.

  METHOD power_of_ten.
    DATA lv_count TYPE i.

    rv_value = 1.
    IF iv_exponent >= 0.
      DO iv_exponent TIMES.
        rv_value = rv_value * 10.
      ENDDO.
    ELSE.
      lv_count = 0 - iv_exponent.
      DO lv_count TIMES.
        rv_value = rv_value / 10.
      ENDDO.
    ENDIF.
  ENDMETHOD.

  METHOD add_overflow.
    IF iv_left > 0 AND iv_right > 0
        AND iv_left > c_max_integer - iv_right.
      rv_overflow = abap_true.
    ELSEIF iv_left < 0 AND iv_right < 0
        AND iv_left < c_min_integer - iv_right.
      rv_overflow = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD sub_overflow.
    IF iv_right > 0 AND iv_left < c_min_integer + iv_right.
      rv_overflow = abap_true.
    ELSEIF iv_right < 0 AND iv_left > c_max_integer + iv_right.
      rv_overflow = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD mul_overflow.
    IF iv_left = 0 OR iv_right = 0.
      RETURN.
    ENDIF.
    IF iv_right = -1.
      rv_overflow = boolc( iv_left = c_min_integer ).
      RETURN.
    ENDIF.
    IF iv_right > 0.
      IF iv_left > integer_divide( iv_left = c_max_integer iv_right = iv_right )
          OR iv_left < integer_divide( iv_left = c_min_integer iv_right = iv_right ).
        rv_overflow = abap_true.
      ENDIF.
    ELSEIF iv_left > integer_divide( iv_left = c_min_integer iv_right = iv_right )
          OR iv_left < integer_divide( iv_left = c_max_integer iv_right = iv_right ).
      rv_overflow = abap_true.

    ENDIF.
  ENDMETHOD.

  METHOD real_to_integer.
    IF iv_value <> iv_value.
      rv_value = 0.
    ELSEIF iv_value >= c_int_boundary.
      rv_value = c_max_integer.
    ELSEIF iv_value < c_int_min_boundary.
      rv_value = c_min_integer.
    ELSE.
      rv_value = truncate_real( iv_value ).
    ENDIF.
  ENDMETHOD.

  METHOD integer_divide.
    DATA lv_remainder TYPE int8.

    IF iv_left = 0.
      rv_value = 0.
      RETURN.
    ENDIF.

    rv_value = iv_left DIV iv_right.
    lv_remainder = iv_left MOD iv_right.
    IF lv_remainder <> 0 AND iv_left < 0.
      IF iv_right > 0.
        rv_value = rv_value + 1.
      ELSE.
        rv_value = rv_value - 1.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD integer_modulo.
    rv_value = iv_left MOD iv_right.
    IF iv_left < 0 AND rv_value <> 0.
      IF iv_right < 0.
        rv_value = rv_value + iv_right.
      ELSE.
        rv_value = rv_value - iv_right.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD truncate_real.
    IF iv_value >= 0.
      rv_value = floor( val = iv_value ).
    ELSE.
      rv_value = 0 - floor( val = 0 - iv_value ).
    ENDIF.
  ENDMETHOD.

  METHOD int8_to_bytes.
    DATA lv_field TYPE x LENGTH 8.

    lv_field = iv_value.
    rv_data = lv_field.
  ENDMETHOD.

  METHOD bytes_to_int8.
    rv_value = iv_data.
  ENDMETHOD.

  METHOD bitwise_not.
    DATA lv_data TYPE xstring.

    lv_data = int8_to_bytes( iv_value ).
    lv_data = BIT-NOT lv_data.
    rv_value = bytes_to_int8( lv_data ).
  ENDMETHOD.

  METHOD shift_left.
    DATA lv_data TYPE xstring.
    DATA lv_out TYPE xstring.
    DATA lv_index TYPE i.
    DATA lv_byte TYPE int8.
    DATA lv_next TYPE int8.
    DATA lv_carry TYPE int8.

    IF iv_shift <= 0.
      rv_value = iv_value.
      RETURN.
    ENDIF.
    IF iv_shift >= 64.
      rv_value = 0.
      RETURN.
    ENDIF.

    lv_data = int8_to_bytes( iv_value ).
    DO iv_shift TIMES.
      lv_out = '0000000000000000'.
      lv_carry = 0.
      DO 8 TIMES.
        lv_index = 8 - sy-index.
        lv_byte = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = lv_index ).
        lv_next = lv_byte * 2 + lv_carry.
        lv_carry = lv_next DIV 256.
        lv_next = lv_next MOD 256.
        lv_out = zcl_sqlite_bytes=>write_u8(
          iv_data = lv_out iv_offset = lv_index iv_value = lv_next ).
      ENDDO.
      lv_data = lv_out.
    ENDDO.
    rv_value = bytes_to_int8( lv_data ).
  ENDMETHOD.

  METHOD shift_right.
    DATA lv_data TYPE xstring.
    DATA lv_out TYPE xstring.
    DATA lv_index TYPE i.
    DATA lv_byte TYPE int8.
    DATA lv_next TYPE int8.
    DATA lv_carry TYPE int8.
    DATA lv_sign TYPE int8.

    IF iv_shift <= 0.
      rv_value = iv_value.
      RETURN.
    ENDIF.
    IF iv_shift >= 64.
      IF iv_value < 0.
        rv_value = -1.
      ELSE.
        rv_value = 0.
      ENDIF.
      RETURN.
    ENDIF.

    lv_data = int8_to_bytes( iv_value ).
    lv_byte = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = 0 ).
    IF lv_byte >= 128.
      lv_sign = 1.
    ENDIF.

    DO iv_shift TIMES.
      lv_out = '0000000000000000'.
      lv_carry = lv_sign.
      DO 8 TIMES.
        lv_index = sy-index - 1.
        lv_byte = zcl_sqlite_bytes=>read_u8( iv_data = lv_data iv_offset = lv_index ).
        lv_next = lv_byte DIV 2 + lv_carry * 128.
        lv_carry = lv_byte MOD 2.
        lv_out = zcl_sqlite_bytes=>write_u8(
          iv_data = lv_out iv_offset = lv_index iv_value = lv_next ).
      ENDDO.
      lv_data = lv_out.
    ENDDO.
    rv_value = bytes_to_int8( lv_data ).
  ENDMETHOD.

  METHOD raise_error.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_error
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
