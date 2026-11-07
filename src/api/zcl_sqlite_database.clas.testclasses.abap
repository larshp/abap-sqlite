CLASS ltcl_database DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS select_rows FOR TESTING RAISING zcx_sqlite_error.
    METHODS star_and_alias FOR TESTING RAISING zcx_sqlite_error.
    METHODS table_alias FOR TESTING RAISING zcx_sqlite_error.
    METHODS constant_select FOR TESTING RAISING zcx_sqlite_error.
    METHODS without_rowid_scan FOR TESTING RAISING zcx_sqlite_error.
    METHODS unknown_column FOR TESTING RAISING zcx_sqlite_error.
    METHODS order_limit_distinct FOR TESTING RAISING zcx_sqlite_error.
    METHODS order_limit_errors FOR TESTING RAISING zcx_sqlite_error.
    METHODS aggregates_basic FOR TESTING RAISING zcx_sqlite_error.
    METHODS aggregates_group_having FOR TESTING RAISING zcx_sqlite_error.
    METHODS aggregates_group_concat FOR TESTING RAISING zcx_sqlite_error.
    METHODS aggregates_empty FOR TESTING RAISING zcx_sqlite_error.
    METHODS joins_inner_left FOR TESTING RAISING zcx_sqlite_error.
    METHODS joins_using_natural FOR TESTING RAISING zcx_sqlite_error.
    METHODS joins_ambiguous FOR TESTING RAISING zcx_sqlite_error.

ENDCLASS.


CLASS ltcl_database IMPLEMENTATION.

  METHOD select_rows.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_expected TYPE f.

    lv_expected = '3.25'.
    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    rs_result = lo_database->query( 'SELECT id, price + 1 FROM items WHERE id > 1' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 2 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 2 msg = 'first id' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( ) exp = lv_expected msg = 'first price plus one' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 3 msg = 'second id' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'null price plus one' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD star_and_alias.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    rs_result = lo_database->query( |SELECT * FROM items WHERE name = 'beta'| ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns ) exp = 3 msg = 'column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 1 msg = 'row count' ).

    READ TABLE rs_result-columns INTO lv_name INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name exp = 'id' msg = 'first column name' ).
    READ TABLE rs_result-columns INTO lv_name INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name exp = 'name' msg = 'second column name' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'beta' msg = 'name value' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD table_alias.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    rs_result = lo_database->query( 'SELECT i.name FROM items AS i WHERE i.id = 1' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 1 msg = 'row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'alpha' msg = 'aliased column' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD constant_select.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    rs_result = lo_database->query( 'SELECT 1 + 1' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 1 msg = 'row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 2 msg = 'constant value' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD without_rowid_scan.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/without_rowid.db' ).
    rs_result = lo_database->query( 'SELECT k, n FROM wr WHERE n > 38' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 2 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'key-039' msg = 'first key' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 39 msg = 'first number' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'key-040' msg = 'second key' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD unknown_column.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.

    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    TRY.
        lo_database->query( 'SELECT nope FROM items' ).
        cl_abap_unit_assert=>fail( 'expected unknown column' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'no such column: nope'
          msg = 'error message' ).
    ENDTRY.
    lo_database->close( ).
  ENDMETHOD.

  METHOD order_limit_distinct.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/ordering.db' ).
    rs_result = lo_database->query( 'SELECT DISTINCT grp, val FROM ordering ORDER BY grp, val LIMIT 3 OFFSET 1' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 3 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'a' msg = 'first group' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'first value' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'a' msg = 'second group' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 2 msg = 'second value' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD order_limit_errors.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.

    lo_database = zcl_sqlite_database=>open( 'fixtures/ordering.db' ).

    TRY.
        lo_database->query( 'SELECT id FROM ordering LIMIT NULL' ).
        cl_abap_unit_assert=>fail( 'expected LIMIT NULL error' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'datatype mismatch'
          msg = 'LIMIT NULL' ).
    ENDTRY.

    TRY.
        lo_database->query( 'SELECT id FROM ordering LIMIT 2.5' ).
        cl_abap_unit_assert=>fail( 'expected fractional LIMIT error' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'datatype mismatch'
          msg = 'fractional LIMIT' ).
    ENDTRY.

    TRY.
        lo_database->query( 'SELECT id FROM ordering ORDER BY 99' ).
        cl_abap_unit_assert=>fail( 'expected ORDER BY range error' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'ORDER BY term out of range'
          msg = 'ORDER BY range' ).
    ENDTRY.

    lo_database->close( ).
  ENDMETHOD.

  METHOD aggregates_basic.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/aggregates.db' ).
    rs_result = lo_database->query( 'SELECT count(*), count(val), min(val), max(val) FROM agg' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 1 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 19 msg = 'count star' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 15 msg = 'count non-null' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 0 msg = 'minimum value' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'abc' msg = 'maximum value' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD aggregates_group_having.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/aggregates.db' ).
    rs_result = lo_database->query( 'SELECT grp, count(*) AS c FROM agg GROUP BY grp HAVING c > 3 ORDER BY grp' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 2 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'a' msg = 'first group' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 4 msg = 'first count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'b' msg = 'second group' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD aggregates_group_concat.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/aggregates.db' ).
    rs_result = lo_database->query(
      'SELECT grp, group_concat(label), count(DISTINCT label) FROM agg GROUP BY grp ORDER BY grp' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 7 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Beta,alpha,gamma,alpha'
      msg = 'concatenated labels' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 3 msg = 'distinct labels' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD aggregates_empty.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_zero     TYPE f.

    lo_database = zcl_sqlite_database=>open( 'fixtures/aggregates.db' ).
    rs_result = lo_database->query(
      'SELECT count(*), count(val), sum(val), total(val), avg(val), min(val), max(val), group_concat(label) FROM agg WHERE id > 99' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 1 msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 0 msg = 'count star' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( ) exp = 0 msg = 'count non-null' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'sum' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( ) exp = lv_zero msg = 'total' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'average' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'minimum' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'maximum' ).
    READ TABLE ls_row INTO lo_value INDEX 8.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'group_concat' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD joins_inner_left.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/joins.db' ).
    rs_result = lo_database->query(
      'SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id ORDER BY b.id' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 3 msg = 'inner row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'Ada' msg = 'inner author' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'Alpha' msg = 'inner title' ).

    rs_result = lo_database->query(
      'SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id ORDER BY a.id, b.id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 5 msg = 'left row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 4.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'Linus' msg = 'left author' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'left null title' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD joins_using_natural.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lo_database = zcl_sqlite_database=>open( 'fixtures/joins.db' ).
    rs_result = lo_database->query( 'SELECT * FROM orders JOIN shipments USING (order_id) ORDER BY order_id' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns ) exp = 4 msg = 'using column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 2 msg = 'using row count' ).
    READ TABLE rs_result-columns INTO lv_name INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name exp = 'order_id' msg = 'using first column' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( ) exp = 'UPS' msg = 'using carrier' ).

    rs_result = lo_database->query( 'SELECT * FROM orders NATURAL LEFT JOIN shipments ORDER BY order_id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows ) exp = 4 msg = 'natural left row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( ) exp = abap_true msg = 'natural left null carrier' ).

    lo_database->close( ).
  ENDMETHOD.

  METHOD joins_ambiguous.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.

    lo_database = zcl_sqlite_database=>open( 'fixtures/joins.db' ).

    TRY.
        lo_database->query( 'SELECT id FROM authors a JOIN books b ON a.id = b.author_id' ).
        cl_abap_unit_assert=>fail( 'expected ambiguous column error' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->message
          exp = 'ambiguous column name: id'
          msg = 'ambiguous column' ).
    ENDTRY.

    lo_database->close( ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_query_harness DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mv_failures TYPE string.

    METHODS differential_queries FOR TESTING RAISING zcx_sqlite_error.
    METHODS check_cell
      IMPORTING io_value TYPE REF TO zcl_sqlite_value
                iv_query TYPE string
                is_cell  TYPE zsqlite_queries.
    METHODS add_failure
      IMPORTING iv_query  TYPE string
                iv_row    TYPE i
                iv_col    TYPE i
                iv_detail TYPE string.
    METHODS value_type_name
      IMPORTING io_value       TYPE REF TO zcl_sqlite_value
      RETURNING VALUE(rv_name) TYPE string.
ENDCLASS.


CLASS ltcl_query_harness IMPLEMENTATION.

  METHOD differential_queries.
    DATA lt_queries     TYPE STANDARD TABLE OF zsqlite_queries WITH DEFAULT KEY.
    DATA ls_query       TYPE zsqlite_queries.
    DATA lt_cells       TYPE STANDARD TABLE OF zsqlite_queries WITH DEFAULT KEY.
    DATA ls_cell        TYPE zsqlite_queries.
    DATA lo_database    TYPE REF TO zcl_sqlite_database.
    DATA rs_result      TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row         TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value       TYPE REF TO zcl_sqlite_value.
    DATA lv_sql         TYPE string.
    DATA lv_database    TYPE string.
    DATA lv_query_name  TYPE string.
    DATA lv_row_count   TYPE i.
    DATA lv_column_count TYPE i.

    SELECT * FROM zsqlite_queries INTO TABLE @lt_queries
      WHERE mandt = @sy-mandt AND row_no = 0
      ORDER BY query_name.
    SELECT * FROM zsqlite_queries INTO TABLE @lt_cells
      WHERE mandt = @sy-mandt AND row_no > 0
      ORDER BY query_name, row_no, col_no.

    IF lines( lt_queries ) = 0.
      cl_abap_unit_assert=>fail( 'no differential queries loaded' ).
    ENDIF.

    LOOP AT lt_queries INTO ls_query.
      lv_query_name = ls_query-query_name.
      CONDENSE lv_query_name.
      lv_database = ls_query-database_name.
      CONDENSE lv_database.
      lv_sql = zcl_sqlite_utf8=>decode( ls_query-sql_text ).

      lo_database = zcl_sqlite_database=>open( lv_database ).
      rs_result = lo_database->query( lv_sql ).

      lv_row_count = lines( rs_result-rows ).
      IF lv_row_count <> ls_query-row_count.
        add_failure(
          iv_query  = lv_query_name
          iv_row    = 0
          iv_col    = 0
          iv_detail = |row count { lv_row_count }, expected { ls_query-row_count }| ).
      ENDIF.

      lv_column_count = lines( rs_result-columns ).
      IF lv_column_count <> ls_query-column_count.
        add_failure(
          iv_query  = lv_query_name
          iv_row    = 0
          iv_col    = 0
          iv_detail = |column count { lv_column_count }, expected { ls_query-column_count }| ).
      ENDIF.

      LOOP AT lt_cells INTO ls_cell.
        IF ls_cell-query_name <> ls_query-query_name.
          CONTINUE.
        ENDIF.

        READ TABLE rs_result-rows INTO ls_row INDEX ls_cell-row_no.
        IF sy-subrc <> 0.
          add_failure(
            iv_query  = lv_query_name
            iv_row    = ls_cell-row_no
            iv_col    = ls_cell-col_no
            iv_detail = 'missing result row' ).
          CONTINUE.
        ENDIF.

        READ TABLE ls_row INTO lo_value INDEX ls_cell-col_no.
        IF sy-subrc <> 0.
          add_failure(
            iv_query  = lv_query_name
            iv_row    = ls_cell-row_no
            iv_col    = ls_cell-col_no
            iv_detail = 'missing result column' ).
          CONTINUE.
        ENDIF.

        check_cell(
          io_value = lo_value
          iv_query = lv_query_name
          is_cell  = ls_cell ).
      ENDLOOP.

      lo_database->close( ).
    ENDLOOP.

    IF mv_failures IS NOT INITIAL.
      cl_abap_unit_assert=>fail( msg = mv_failures ).
    ENDIF.
  ENDMETHOD.

  METHOD check_cell.
    DATA lv_expected_type  TYPE string.
    DATA lv_actual_type    TYPE string.
    DATA lv_expected_text  TYPE string.
    DATA lv_actual_text    TYPE string.
    DATA lv_expected_int   TYPE int8.
    DATA lv_actual_int     TYPE int8.
    DATA lv_expected_real  TYPE f.
    DATA lv_actual_real    TYPE f.
    DATA lv_expected_blob  TYPE xstring.
    DATA lv_actual_blob    TYPE xstring.

    lv_expected_type = is_cell-value_type.
    CONDENSE lv_expected_type.
    lv_actual_type = value_type_name( io_value ).

    IF lv_expected_type <> lv_actual_type.
      add_failure(
        iv_query  = iv_query
        iv_row    = is_cell-row_no
        iv_col    = is_cell-col_no
        iv_detail = |type { lv_actual_type }, expected { lv_expected_type }| ).
      RETURN.
    ENDIF.

    IF lv_expected_type = 'null'.
      RETURN.
    ENDIF.

    CASE lv_expected_type.
      WHEN 'integer'.
        lv_expected_text = zcl_sqlite_utf8=>decode( is_cell-value_text ).
        lv_expected_int = lv_expected_text.
        lv_actual_int = io_value->as_integer( ).
        IF lv_actual_int <> lv_expected_int.
          add_failure(
            iv_query  = iv_query
            iv_row    = is_cell-row_no
            iv_col    = is_cell-col_no
            iv_detail = |integer mismatch, expected { lv_expected_text }| ).
        ENDIF.
      WHEN 'real'.
        lv_expected_text = zcl_sqlite_utf8=>decode( is_cell-value_text ).
        lv_expected_real = lv_expected_text.
        lv_actual_real = io_value->as_real( ).
        IF lv_actual_real <> lv_expected_real.
          add_failure(
            iv_query  = iv_query
            iv_row    = is_cell-row_no
            iv_col    = is_cell-col_no
            iv_detail = |real mismatch, expected { lv_expected_text }| ).
        ENDIF.
      WHEN 'text'.
        lv_expected_text = zcl_sqlite_utf8=>decode( is_cell-value_text ).
        lv_actual_text = io_value->as_text( ).
        IF lv_actual_text <> lv_expected_text.
          add_failure(
            iv_query  = iv_query
            iv_row    = is_cell-row_no
            iv_col    = is_cell-col_no
            iv_detail = |text mismatch, expected { lv_expected_text }| ).
        ENDIF.
      WHEN 'blob'.
        lv_expected_blob = is_cell-value_text.
        lv_actual_blob = io_value->as_blob( ).
        IF lv_actual_blob <> lv_expected_blob.
          add_failure(
            iv_query  = iv_query
            iv_row    = is_cell-row_no
            iv_col    = is_cell-col_no
            iv_detail = 'blob mismatch' ).
        ENDIF.
      WHEN OTHERS.
        add_failure(
          iv_query  = iv_query
          iv_row    = is_cell-row_no
          iv_col    = is_cell-col_no
          iv_detail = |unknown expected type { lv_expected_type }| ).
    ENDCASE.
  ENDMETHOD.

  METHOD add_failure.
    mv_failures = mv_failures &&
      |{ iv_query } [{ iv_row },{ iv_col }]: { iv_detail }; |.
  ENDMETHOD.

  METHOD value_type_name.
    CASE io_value->value_type( ).
      WHEN zcl_sqlite_value=>c_null.
        rv_name = 'null'.
      WHEN zcl_sqlite_value=>c_integer.
        rv_name = 'integer'.
      WHEN zcl_sqlite_value=>c_real.
        rv_name = 'real'.
      WHEN zcl_sqlite_value=>c_text.
        rv_name = 'text'.
      WHEN zcl_sqlite_value=>c_blob.
        rv_name = 'blob'.
      WHEN OTHERS.
        rv_name = 'unknown'.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
