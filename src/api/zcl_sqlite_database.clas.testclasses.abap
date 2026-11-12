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
    METHODS planner_access_paths FOR TESTING RAISING zcx_sqlite_error.
    METHODS planner_execution FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_empty_database FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_table FOR TESTING RAISING zcx_sqlite_error.
    METHODS insert_values FOR TESTING RAISING zcx_sqlite_error.
    METHODS insert_select FOR TESTING RAISING zcx_sqlite_error.
    METHODS delete_rows FOR TESTING RAISING zcx_sqlite_error.
    METHODS update_rows FOR TESTING RAISING zcx_sqlite_error.
    METHODS create_index FOR TESTING RAISING zcx_sqlite_error.
    METHODS index_maintenance FOR TESTING RAISING zcx_sqlite_error.
    METHODS index_delete_all FOR TESTING RAISING zcx_sqlite_error.

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
      act = lines( rs_result-rows )
      exp = 2
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'first id' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'first price plus one' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'second id' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'null price plus one' ).

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
      act = lines( rs_result-columns )
      exp = 3
      msg = 'column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'row count' ).

    READ TABLE rs_result-columns INTO lv_name INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'id'
      msg = 'first column name' ).
    READ TABLE rs_result-columns INTO lv_name INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'name'
      msg = 'second column name' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'beta'
      msg = 'name value' ).

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
      act = lines( rs_result-rows )
      exp = 1
      msg = 'row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'alpha'
      msg = 'aliased column' ).

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
      act = lines( rs_result-rows )
      exp = 1
      msg = 'row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'constant value' ).

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
      act = lines( rs_result-rows )
      exp = 2
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'key-039'
      msg = 'first key' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 39
      msg = 'first number' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'key-040'
      msg = 'second key' ).

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
      act = lines( rs_result-rows )
      exp = 3
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'a'
      msg = 'first group' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'first value' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'a'
      msg = 'second group' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'second value' ).

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
      act = lines( rs_result-rows )
      exp = 1
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 19
      msg = 'count star' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 15
      msg = 'count non-null' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'minimum value' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'abc'
      msg = 'maximum value' ).

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
      act = lines( rs_result-rows )
      exp = 2
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'a'
      msg = 'first group' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 4
      msg = 'first count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'b'
      msg = 'second group' ).

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
      act = lines( rs_result-rows )
      exp = 7
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Beta,alpha,gamma,alpha'
      msg = 'concatenated labels' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 3
      msg = 'distinct labels' ).

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
      |SELECT count(*), count(val), sum(val), total(val), avg(val), min(val), max(val), | &&
      |group_concat(label) FROM agg WHERE id > 99| ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'row count' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'count star' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'count non-null' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'sum' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_zero
      msg = 'total' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'average' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'minimum' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'maximum' ).
    READ TABLE ls_row INTO lo_value INDEX 8.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'group_concat' ).

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
      act = lines( rs_result-rows )
      exp = 3
      msg = 'inner row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Ada'
      msg = 'inner author' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Alpha'
      msg = 'inner title' ).

    rs_result = lo_database->query(
      'SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id ORDER BY a.id, b.id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 5
      msg = 'left row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 4.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'Linus'
      msg = 'left author' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'left null title' ).

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
      act = lines( rs_result-columns )
      exp = 4
      msg = 'using column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'using row count' ).
    READ TABLE rs_result-columns INTO lv_name INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'order_id'
      msg = 'using first column' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'UPS'
      msg = 'using carrier' ).

    rs_result = lo_database->query( 'SELECT * FROM orders NATURAL LEFT JOIN shipments ORDER BY order_id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 4
      msg = 'natural left row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'natural left null carrier' ).

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

  METHOD planner_access_paths.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lv_plan     TYPE string.

    lo_database = zcl_sqlite_database=>open( 'fixtures/many_indexes.db' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM m WHERE a = 'b' AND b = 2| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |INDEX SEEK m USING m_ba (b = 2 AND a = 'b')|
      msg = 'index equality prefix' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM m WHERE a = 'a' AND b > 1| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |INDEX RANGE m USING m_ab (a = 'a' AND b > 1)|
      msg = 'index equality and range' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM m WHERE b = 2| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |INDEX SEEK m USING m_b (b = 2)|
      msg = 'non-leading column index' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM m WHERE b BETWEEN 1 AND 2| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |INDEX RANGE m USING m_b (b >= 1 AND b <= 2)|
      msg = 'index between' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM m WHERE a = 'a' OR b = 2| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |SCAN m|
      msg = 'or is a full scan' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM m WHERE c = 'missing'| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |INDEX SEEK m USING m_c (c = 'missing')|
      msg = 'single column index' ).

    lo_database->close( ).

    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    lv_plan = lo_database->plan_dump( 'SELECT id FROM items WHERE id = 2' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |ROWID SEEK items (id = 2)|
      msg = 'rowid equality' ).

    lv_plan = lo_database->plan_dump( 'SELECT id FROM items WHERE id > 1 AND id <= 2' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |ROWID SEEK items (id > 1 AND id <= 2)|
      msg = 'rowid range' ).

    lv_plan = lo_database->plan_dump( |SELECT id FROM items WHERE name = 'beta'| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |SCAN items|
      msg = 'non-indexed predicate is a full scan' ).
    lo_database->close( ).

    lo_database = zcl_sqlite_database=>open( 'fixtures/joins.db' ).
    lv_plan = lo_database->plan_dump(
      |SELECT a.name FROM authors a JOIN books b ON a.id = b.author_id WHERE a.rowid = 1| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |ROWID SEEK authors a (rowid = 1)| &&
            cl_abap_char_utilities=>newline &&
            |SCAN books b|
      msg = 'join access paths' ).
    lo_database->close( ).

    lo_database = zcl_sqlite_database=>open( 'fixtures/without_rowid.db' ).
    lv_plan = lo_database->plan_dump( |SELECT k FROM wr WHERE k = 'key-001'| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_plan
      exp = |SCAN wr|
      msg = 'without rowid stays a full scan' ).
    lo_database->close( ).
  ENDMETHOD.

  METHOD planner_execution.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lo_database = zcl_sqlite_database=>open( 'fixtures/many_indexes.db' ).

    rs_result = lo_database->query( |SELECT id FROM m WHERE a = 'b' AND b = 2 ORDER BY id| ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'index equality row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 4
      msg = 'first index equality row' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6
      msg = 'second index equality row' ).

    rs_result = lo_database->query( |SELECT id FROM m WHERE a = 'a' AND b > 1 ORDER BY id| ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'index range row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'index range row' ).

    rs_result = lo_database->query( 'SELECT id FROM m WHERE b < 2 ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'upper bound row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'upper bound last row' ).

    lo_database->close( ).

    lo_database = zcl_sqlite_database=>open( 'fixtures/small.db' ).
    rs_result = lo_database->query( 'SELECT id FROM items WHERE id > 1 AND id <= 2 ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'rowid range row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'rowid range row' ).
    lo_database->close( ).
  ENDMETHOD.

  METHOD create_table.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_header   TYPE zcl_sqlite_header=>ty_header.
    DATA lt_entries  TYPE zcl_sqlite_catalog=>ty_entries.
    DATA ls_entry    TYPE zcl_sqlite_catalog=>ty_entry.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA lv_data     TYPE xstring.
    DATA lv_name     TYPE string.
    DATA lv_sql      TYPE string.

    lv_name = 'test/m5_7_create_table.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lv_sql = 'CREATE TABLE created (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)'.
    lo_database->execute( lv_sql ).

    rs_result = lo_database->query( 'SELECT id, name FROM created' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 2
      msg = 'created table column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 0
      msg = 'created table is empty' ).

    lo_database->execute( 'CREATE TABLE IF NOT EXISTS created (id INTEGER)' ).
    lo_database->execute( 'CREATE TABLE notes (body TEXT)' ).
    lo_database->close( ).

    lv_data = lo_vfs->export( lv_name ).
    ls_header = zcl_sqlite_header=>parse( lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = 3
      msg = 'created table page count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-freelist_pages
      exp = 0
      msg = 'created table freelist' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 3
      msg = 'schema cookie after two tables' ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lt_entries = zcl_sqlite_catalog=>read( lo_pager ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_entries )
      exp = 2
      msg = 'sqlite_schema row count' ).

    READ TABLE lt_entries INTO ls_entry INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-type
      exp = 'table' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-name
      exp = 'created' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-tbl_name
      exp = 'created' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-rootpage
      exp = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-sql
      exp = lv_sql ).

    READ TABLE lt_entries INTO ls_entry INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-name
      exp = 'notes' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_entry-rootpage
      exp = 3 ).
    lo_file->close( ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT id FROM created' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-columns )
      exp = 1
      msg = 'created table survives reopen' ).

    TRY.
        lo_database->execute( lv_sql ).
        cl_abap_unit_assert=>fail( 'duplicate table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE IF NOT EXISTS created (id INTEGER)' ).
    lo_database->close( ).

    lv_data = lo_vfs->export( lv_name ).
    ls_header = zcl_sqlite_header=>parse( lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 3
      msg = 'no-op create table must not bump the schema cookie' ).

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD insert_values.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lv_name = 'test/m5_8_insert.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT ''anon'',' &&
      ' qty INTEGER DEFAULT 7, price REAL, note TEXT, bin BLOB)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 0
      msg = 'create table changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 0
      msg = 'initial last_insert_rowid' ).

    lo_database->execute( 'INSERT INTO items (name, qty, price) VALUES (''alpha'', 2, 3.5)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'single insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 1
      msg = 'single insert rowid' ).

    rs_result = lo_database->query(
      'SELECT id, name, typeof(qty), qty, typeof(price), quote(price), ' &&
      'typeof(note), typeof(bin) FROM items' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'single insert row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'assigned rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'alpha'
      msg = 'inserted name' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'integer'
      msg = 'integer affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'inserted integer' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'real'
      msg = 'real affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '3.5'
      msg = 'real quote' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'missing column is null' ).
    READ TABLE ls_row INTO lo_value INDEX 8.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'missing blob is null' ).

    lo_database->execute( 'INSERT INTO items (id, name, price) VALUES (10, ''beta'', 4)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 10
      msg = 'explicit rowid alias' ).
    rs_result = lo_database->query(
      'SELECT qty, typeof(price), quote(price), typeof(note) FROM items WHERE id = 10' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'default applied' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'real'
      msg = 'integer to real affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '4.0'
      msg = 'integer stored as real' ).

    lo_database->execute( 'INSERT INTO items DEFAULT VALUES' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 11
      msg = 'default values rowid' ).
    rs_result = lo_database->query(
      'SELECT id, name, qty, typeof(price), quote(price) FROM items WHERE id = 11' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'anon'
      msg = 'default text' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'default integer' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'default null' ).

    lo_database->execute(
      'INSERT INTO items VALUES (NULL, ''gamma'', ''8'', ''2.5'', ''x'', x''0102''), ' &&
      '(100, ''delta'', 9, 0, NULL, NULL)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 2
      msg = 'multi-row insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 100
      msg = 'multi-row insert last rowid' ).
    rs_result = lo_database->query(
      'SELECT id, typeof(qty), qty, typeof(price), quote(price), note, typeof(bin) ' &&
      'FROM items WHERE id IN (12, 100) ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'multi-row insert row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 12
      msg = 'rowid after explicit maximum' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'integer'
      msg = 'numeric text affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 8
      msg = 'numeric text converted' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '2.5'
      msg = 'numeric text to real' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'x'
      msg = 'text value' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'blob'
      msg = 'blob value' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 100
      msg = 'explicit multi-row rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '0.0'
      msg = 'zero integer stored as real' ).
    READ TABLE ls_row INTO lo_value INDEX 6.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'explicit null' ).
    READ TABLE ls_row INTO lo_value INDEX 7.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'null'
      msg = 'null blob' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'inserted row count' ).

    TRY.
        lo_database->execute( 'INSERT INTO items (bogus) VALUES (1)' ).
        cl_abap_unit_assert=>fail( 'unknown column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.
    TRY.
        lo_database->execute( 'INSERT INTO items (name) VALUES (NULL)' ).
        cl_abap_unit_assert=>fail( 'not null violation was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 5
      msg = 'inserts survive reopen' ).
    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD insert_select.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.

    lv_name = 'test/m5_8_insert_select.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute( 'CREATE TABLE source (id INTEGER PRIMARY KEY, label TEXT, amount NUMERIC)' ).
    lo_database->execute(
      'CREATE TABLE dest (id INTEGER PRIMARY KEY, label TEXT NOT NULL,' &&
      ' amount REAL DEFAULT 1.0, status TEXT DEFAULT ''new'')' ).
    lo_database->execute(
      'INSERT INTO source VALUES (1, ''one'', 10), (2, ''two'', 2.5), ' &&
      '(3, ''three'', ''4'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 3
      msg = 'source insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'source insert last rowid' ).

    lo_database->execute( 'INSERT INTO dest (label, amount) SELECT label, amount FROM source ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 3
      msg = 'insert select changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'insert select last rowid' ).

    rs_result = lo_database->query(
      'SELECT id, label, typeof(amount), quote(amount), status FROM dest ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'insert select row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 1
      msg = 'insert select first id' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'one'
      msg = 'insert select first label' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'real'
      msg = 'insert select real affinity' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '10.0'
      msg = 'insert select real quote' ).
    READ TABLE ls_row INTO lo_value INDEX 5.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'new'
      msg = 'insert select default' ).

    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '4.0'
      msg = 'numeric source to real destination' ).

    lo_database->execute( 'INSERT INTO dest (label) SELECT ''four''' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 4
      msg = 'insert select default rowid' ).
    rs_result = lo_database->query( 'SELECT quote(amount), status FROM dest WHERE id = 4' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '1.0'
      msg = 'default real value' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'new'
      msg = 'default text value' ).

    lo_database->execute( 'INSERT INTO dest SELECT 100, ''five'', 5.5, ''old''' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 100
      msg = 'insert select explicit rowid' ).

    lo_database->execute(
      'INSERT INTO dest (label, amount, status) ' &&
      'SELECT label, amount, status FROM dest WHERE id = 100' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 101
      msg = 'insert select from same table' ).

    lo_database->execute( 'INSERT INTO dest (label) VALUES (''six'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 102
      msg = 'auto rowid after select inserts' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'last insert changes' ).

    rs_result = lo_database->query( 'SELECT id, label, quote(amount), status FROM dest ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 7
      msg = 'final destination row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 6.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 101
      msg = 'same-table select copy rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '5.5'
      msg = 'same-table select copy amount' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 7.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 102
      msg = 'final auto rowid' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = '1.0'
      msg = 'final default amount' ).

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD create_empty_database.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_header   TYPE zcl_sqlite_header=>ty_header.
    DATA ls_page     TYPE zcl_sqlite_page=>ty_page.
    DATA lt_entries  TYPE zcl_sqlite_catalog=>ty_entries.
    DATA lv_data     TYPE xstring.
    DATA lv_name     TYPE string.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.

    lv_name = 'test/m5_2_empty.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    rs_result = lo_database->query( 'SELECT 1 + 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 1
      msg = 'empty database is queryable' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 2
      msg = 'empty database constant' ).
    lo_database->close( ).

    lv_data = lo_vfs->export( lv_name ).
    cl_abap_unit_assert=>assert_equals(
      act = xstrlen( lv_data )
      exp = 4096
      msg = 'new database size' ).

    ls_header = zcl_sqlite_header=>parse( lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-page_size
      exp = 4096
      msg = 'new database page size' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-database_size
      exp = 1
      msg = 'new database page count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-change_counter
      exp = 1
      msg = 'new database change counter' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-schema_cookie
      exp = 1
      msg = 'new database schema cookie' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-text_encoding
      exp = zcl_sqlite_header=>c_encoding_utf8
      msg = 'new database text encoding' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-version_valid_for
      exp = 1
      msg = 'new database version valid for' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_header-sqlite_version
      exp = zcl_sqlite_header=>c_sqlite_version
      msg = 'new database SQLite version' ).

    ls_page = zcl_sqlite_page=>parse( iv_data   = lv_data
                                      iv_offset = 100 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-page_type
      exp = zcl_sqlite_page=>c_table_leaf
      msg = 'sqlite_schema page type' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_count
      exp = 0
      msg = 'sqlite_schema cell count' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_page-cell_content_offset
      exp = 4096
      msg = 'sqlite_schema content offset' ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lt_entries = zcl_sqlite_catalog=>read( lo_pager ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_entries )
      exp = 0
      msg = 'sqlite_schema is empty' ).
    lo_file->close( ).

    TRY.
        lo_database = zcl_sqlite_database=>create( lv_name ).
        cl_abap_unit_assert=>fail( 'creating an existing database must fail' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error
          msg = 'existing database error code' ).
    ENDTRY.

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD delete_rows.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_suffix   TYPE string.
    DATA lv_values   TYPE string.

    lv_name = 'test/m5_9_delete.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL,' &&
      ' tag TEXT, bin BLOB)' ).

    lv_suffix = repeat( val = 'x'
                        occ = 40 ).
    DO 200 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values && |({ sy-index }, 'row-{ sy-index }-{ lv_suffix }')|.
    ENDDO.
    lo_database->execute( |INSERT INTO items (id, name) VALUES { lv_values }| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 200
      msg = 'bulk insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'bulk insert last rowid' ).

    lo_database->execute( 'DELETE FROM items WHERE id % 3 = 0' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 66
      msg = 'modulo delete changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'delete keeps last_insert_rowid' ).

    lo_database->execute( 'DELETE FROM items WHERE id BETWEEN 50 AND 60' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 7
      msg = 'range delete changes' ).

    lo_database->execute( 'DELETE FROM items WHERE id IN (1, 2, 4, 5, 199, 200)' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 6
      msg = 'in-list delete changes' ).

    lo_database->execute( 'DELETE FROM items WHERE id = 9999' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 0
      msg = 'delete without matches changes' ).

    rs_result = lo_database->query( 'SELECT count(*), min(id), max(id) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 121
      msg = 'remaining row count' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'remaining minimum id' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 197
      msg = 'remaining maximum id' ).

    rs_result = lo_database->query(
      'SELECT id FROM items' &&
      ' WHERE id IN (1, 3, 6, 7, 50, 51, 52, 60, 61, 199, 200) ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 2
      msg = 'survivor count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 7
      msg = 'first survivor' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 61
      msg = 'second survivor' ).

    lo_database->execute( 'DELETE FROM items' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 121
      msg = 'delete all changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'delete all keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'empty table after delete all' ).

    lo_database->execute( 'INSERT INTO items (name) VALUES (''after'')' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 1
      msg = 'insert after empty table' ).
    lo_database->execute( 'DELETE FROM items AS x WHERE x.id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'aliased delete changes' ).

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'deletes survive reopen' ).

    TRY.
        lo_database->execute( 'DELETE FROM missing WHERE id = 1' ).
        cl_abap_unit_assert=>fail( 'delete from unknown table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD update_rows.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_suffix   TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_expected TYPE f.

    lv_name = 'test/m5_10_update.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute(
      'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL,' &&
      ' amount REAL, note TEXT, bin BLOB)' ).

    lv_suffix = repeat( val = 'x'
                        occ = 40 ).
    DO 200 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values && |({ sy-index }, 'row-{ sy-index }-{ lv_suffix }', { sy-index })|.
    ENDDO.
    lo_database->execute( |INSERT INTO items (id, name, amount) VALUES { lv_values }| ).

    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 200
      msg = 'insert changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'insert last rowid' ).

    lo_database->execute(
      'UPDATE items SET name = name || ''-u'', amount = amount * 2,' &&
      ' note = ''n-'' || id WHERE id % 3 = 0' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 66
      msg = 'modulo update changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'update keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT name, amount, note FROM items WHERE id = 3' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = |row-3-{ lv_suffix }-u|
      msg = 'updated name' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    lv_expected = '6'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'updated amount' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'n-3'
      msg = 'updated note' ).

    rs_result = lo_database->query( 'SELECT note FROM items WHERE id = 4' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->is_null( )
      exp = abap_true
      msg = 'unmatched note stays null' ).

    lo_database->execute( 'UPDATE items AS x SET amount = amount + x.id WHERE x.id BETWEEN 10 AND 12' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 3
      msg = 'aliased update changes' ).

    lo_database->execute( 'UPDATE items SET note = ''first'', note = ''last'' WHERE id = 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'duplicate assignment changes' ).

    lo_database->execute( 'UPDATE items SET id = id + 1000 WHERE id BETWEEN 1 AND 20' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 20
      msg = 'rowid alias update changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'rowid update keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 1 AND 20' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'old rowid aliases removed' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 1001 AND 1020' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 20
      msg = 'new rowid aliases present' ).

    lo_database->execute( 'UPDATE items SET rowid = rowid + 2000 WHERE id BETWEEN 50 AND 60' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 11
      msg = 'rowid update changes' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 2050 AND 2060' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 11
      msg = 'rowid update moved rows' ).

    lo_database->execute( 'UPDATE items SET oid = oid + 3000 WHERE id BETWEEN 70 AND 75' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 6
      msg = 'oid update changes' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 3070 AND 3075' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6
      msg = 'oid update moved rows' ).

    lo_database->execute( 'UPDATE items SET rowid = rowid WHERE id BETWEEN 100 AND 109' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 10
      msg = 'same rowid update changes' ).
    lo_database->execute( 'UPDATE items SET amount = amount WHERE id = 999999' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 0
      msg = 'update without matches changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'no-match update keeps last_insert_rowid' ).

    lo_database->execute( 'UPDATE items SET amount = amount + 1' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 200
      msg = 'update all changes' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 200
      msg = 'update all keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 200
      msg = 'row count after updates' ).

    rs_result = lo_database->query( 'SELECT amount FROM items WHERE id = 1010' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    lv_expected = '21'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'aliased update amount' ).

    rs_result = lo_database->query(
      'SELECT id, amount, name, note FROM items WHERE id IN (1001, 1002, 1003) ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'moved row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = |row-1-{ lv_suffix }|
      msg = 'moved row keeps name' ).
    READ TABLE ls_row INTO lo_value INDEX 4.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'last'
      msg = 'duplicate assignment last wins' ).
    READ TABLE ls_row INTO lo_value INDEX 2.
    lv_expected = '2'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'moved row amount' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 2.
    lv_expected = '7'.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_real( )
      exp = lv_expected
      msg = 'rowid update amount' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = |row-3-{ lv_suffix }-u|
      msg = 'rowid update name' ).

    TRY.
        lo_database->execute( 'UPDATE items SET name = NULL WHERE id = 1001' ).
        cl_abap_unit_assert=>fail( 'NOT NULL update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE items SET id = 1.5 WHERE id = 1001' ).
        cl_abap_unit_assert=>fail( 'non-integer rowid update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE items SET id = id + 1 WHERE id BETWEEN 110 AND 115' ).
        cl_abap_unit_assert=>fail( 'rowid collision update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    rs_result = lo_database->query( 'SELECT count(*) FROM items WHERE id BETWEEN 110 AND 115' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6
      msg = 'collision rollback restored rows' ).

    TRY.
        lo_database->execute( 'UPDATE items SET missing = 1 WHERE id = 1' ).
        cl_abap_unit_assert=>fail( 'unknown update column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE missing SET amount = 1' ).
        cl_abap_unit_assert=>fail( 'update of unknown table was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'UPDATE items SET amount = 1 FROM payloads WHERE items.id = payloads.id' ).
        cl_abap_unit_assert=>fail( 'UPDATE ... FROM was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE payloads (id INTEGER PRIMARY KEY, label TEXT, body TEXT)' ).
    lv_text = repeat( val = 'A'
                      occ = 100 ).
    lv_values = |(1, 'small', '{ lv_text }')|.
    lv_text = repeat( val = 'B'
                      occ = 8000 ).
    lv_values = lv_values && |, (2, 'large', '{ lv_text }')|.
    lv_text = repeat( val = 'C'
                      occ = 12000 ).
    lv_values = lv_values && |, (3, 'huge', '{ lv_text }')|.
    lo_database->execute( |INSERT INTO payloads VALUES { lv_values }| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'payload insert rowid' ).

    lv_text = repeat( val = 'D'
                      occ = 12000 ).
    lo_database->execute( |UPDATE payloads SET body = '{ lv_text }' WHERE id = 1| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->changes( )
      exp = 1
      msg = 'overflow growth changes' ).
    lo_database->execute( 'UPDATE payloads SET body = ''tiny'' WHERE id = 2' ).
    lv_text = repeat( val = 'E'
                      occ = 6000 ).
    lo_database->execute( |UPDATE payloads SET body = '{ lv_text }' WHERE id = 3| ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_database->last_insert_rowid( )
      exp = 3
      msg = 'overflow update keeps last_insert_rowid' ).

    rs_result = lo_database->query( 'SELECT id, length(body), substr(body, 1, 1) FROM payloads ORDER BY id' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( rs_result-rows )
      exp = 3
      msg = 'payload row count' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 12000
      msg = 'grown payload length' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 'D'
      msg = 'grown payload content' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 2.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 4
      msg = 'shrunk payload length' ).
    READ TABLE ls_row INTO lo_value INDEX 3.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_text( )
      exp = 't'
      msg = 'shrunk payload content' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 3.
    READ TABLE ls_row INTO lo_value INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 6000
      msg = 'overflow shrink length' ).

    lo_database->close( ).
    lo_database = zcl_sqlite_database=>open( lv_name ).
    rs_result = lo_database->query( 'SELECT count(*) FROM items' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 200
      msg = 'updates survive reopen' ).
    lo_database->close( ).

    lo_database = zcl_sqlite_database=>open( 'fixtures/without_rowid.db' ).
    TRY.
        lo_database->execute( |UPDATE wr SET n = 1 WHERE k = 'key-001'| ).
        cl_abap_unit_assert=>fail( 'WITHOUT ROWID update was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.
    lo_database->close( ).

    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD create_index.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_table    TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_index_column TYPE zcl_sqlite_schema=>ty_index_column.
    DATA lt_indexes  TYPE zcl_sqlite_schema=>ty_indexes.
    DATA lt_values   TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_count    TYPE i.
    DATA lv_current  TYPE string.
    DATA lv_previous_name TYPE string.

    lv_name = 'test/m5_11_create_index.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, tag TEXT)' ).
    DO 600 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', 'tag-{ sy-index }')|.
    ENDDO.
    lo_database->execute( |INSERT INTO items (id, name, tag) VALUES { lv_values }| ).

    lo_database->execute( 'CREATE INDEX idx_name ON items (name)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_tag ON items (tag)' ).
    lo_database->execute( 'CREATE INDEX IF NOT EXISTS idx_name ON items (name)' ).

    TRY.
        lo_database->execute( 'CREATE INDEX idx_name ON items (tag)' ).
        cl_abap_unit_assert=>fail( 'duplicate index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'CREATE INDEX idx_missing ON items (missing)' ).
        cl_abap_unit_assert=>fail( 'index on missing column was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'CREATE INDEX idx_desc ON items (name DESC)' ).
        cl_abap_unit_assert=>fail( 'descending index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    TRY.
        lo_database->execute( 'CREATE INDEX idx_nocase ON items (name COLLATE NOCASE)' ).
        cl_abap_unit_assert=>fail( 'NOCASE index was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_error ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE duplicates (value TEXT)' ).
    lo_database->execute( 'INSERT INTO duplicates VALUES (''same''), (''same'')' ).
    TRY.
        lo_database->execute( 'CREATE UNIQUE INDEX idx_duplicate ON duplicates (value)' ).
        cl_abap_unit_assert=>fail( 'unique index over duplicate values was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lo_database->execute( 'CREATE TABLE auto (a TEXT UNIQUE, b TEXT PRIMARY KEY)' ).
    lo_database->close( ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    ls_index = lo_schema->index( 'idx_name' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-tbl_name
      exp = 'items'
      msg = 'index table name' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-is_unique
      exp = abap_false
      msg = 'plain index is not unique' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_index-columns )
      exp = 1
      msg = 'index column count' ).
    READ TABLE ls_index-columns INTO ls_index_column INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_index_column-name
      exp = 'name'
      msg = 'index column name' ).

    ls_index = lo_schema->index( 'idx_tag' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-is_unique
      exp = abap_true
      msg = 'unique index flag' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-origin
      exp = 'c'
      msg = 'created index origin' ).

    ls_table = lo_schema->table( 'auto' ).
    lt_indexes = lo_schema->indexes_in_definition_order( 'auto' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_indexes )
      exp = 2
      msg = 'autoindex count' ).
    READ TABLE lt_indexes INTO ls_index INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-origin
      exp = 'u'
      msg = 'first autoindex origin' ).
    IF ls_index-rootpage <= 0.
      cl_abap_unit_assert=>fail( 'first autoindex root is missing' ).
    ENDIF.
    READ TABLE lt_indexes INTO ls_index INDEX 2.
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-origin
      exp = 'pk'
      msg = 'second autoindex origin' ).
    IF ls_index-rootpage <= 0.
      cl_abap_unit_assert=>fail( 'second autoindex root is missing' ).
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = ls_table-name
      exp = 'auto'
      msg = 'autoindex table' ).

    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_name' )-rootpage ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->first( )
      exp = abap_true
      msg = 'index has entries' ).
    DO.
      lt_values = lo_cursor->values( ).
      lv_count = lv_count + 1.
      READ TABLE lt_values INTO lo_value INDEX 1.
      lv_current = lo_value->as_text( ).
      IF lv_count = 1.
        cl_abap_unit_assert=>assert_equals(
          act = lv_current
          exp = 'name-1'
          msg = 'first index value' ).
      ELSEIF lv_current < lv_previous_name.
        cl_abap_unit_assert=>fail( 'index values are not ascending' ).
      ENDIF.
      lv_previous_name = lv_current.
      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 600
      msg = 'index entry count' ).
    lo_file->close( ).

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'CREATE INDEX IF NOT EXISTS idx_name ON items (name)' ).
    lo_database->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD index_maintenance.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA lt_values   TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_count    TYPE i.
    DATA lv_rowid    TYPE int8.
    DATA lv_found    TYPE abap_bool.

    lv_name = 'test/m5_11_maintenance.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute( 'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, qty INTEGER)' ).
    DO 120 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', { sy-index })|.
    ENDDO.
    lo_database->execute( |INSERT INTO items VALUES { lv_values }| ).
    lo_database->execute( 'CREATE INDEX idx_name ON items (name)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_qty ON items (qty)' ).

    lo_database->execute( 'UPDATE items SET name = ''changed'', qty = 500 WHERE id = 50' ).
    lo_database->execute( 'DELETE FROM items WHERE id <= 20' ).

    TRY.
        lo_database->execute( 'INSERT INTO items (id, name, qty) VALUES (200, ''dupe'', 500)' ).
        cl_abap_unit_assert=>fail( 'duplicate unique index value was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lv_text = repeat( val = 'L'
                      occ = 9000 ).
    lo_database->execute( |INSERT INTO items (id, name, qty) VALUES (201, '{ lv_text }', 201)| ).

    lo_database->close( ).
    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).

    ls_index = lo_schema->index( 'idx_name' ).
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( ls_index-rootpage ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cursor->first( )
      exp = abap_true
      msg = 'maintained index has entries' ).
    DO.
      lt_values = lo_cursor->values( ).
      lv_count = lv_count + 1.
      READ TABLE lt_values INTO lo_value INDEX 2.
      lv_rowid = lo_value->as_integer( ).
      READ TABLE lt_values INTO lo_value INDEX 1.
      CASE lv_rowid.
        WHEN 50.
          cl_abap_unit_assert=>assert_equals(
            act = lo_value->as_text( )
            exp = 'changed'
            msg = 'updated index value' ).
          lv_found = abap_true.
        WHEN 201.
          cl_abap_unit_assert=>assert_equals(
            act = strlen( lo_value->as_text( ) )
            exp = 9000
            msg = 'overflow index value' ).
          lv_found = abap_true.
      ENDCASE.
      IF lo_cursor->next( ) = abap_false.
        EXIT.
      ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 101
      msg = 'maintained index entry count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_found
      exp = abap_true
      msg = 'updated and overflow entries found' ).

    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_qty' )-rootpage ) ).
    lv_count = 0.
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 101
      msg = 'unique index entry count' ).
    lo_file->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
  ENDMETHOD.

  METHOD index_delete_all.
    DATA lo_vfs      TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_check_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file     TYPE REF TO zif_sqlite_file.
    DATA lo_database TYPE REF TO zcl_sqlite_database.
    DATA lo_pager    TYPE REF TO zcl_sqlite_pager.
    DATA lo_schema   TYPE REF TO zcl_sqlite_schema.
    DATA lo_cursor   TYPE REF TO zcl_sqlite_index_cursor.
    DATA lo_tcursor  TYPE REF TO zcl_sqlite_cursor.
    DATA lo_error    TYPE REF TO zcx_sqlite_error.
    DATA ls_index    TYPE zcl_sqlite_schema=>ty_index.
    DATA ls_table    TYPE zcl_sqlite_schema=>ty_table.
    DATA rs_result   TYPE zcl_sqlite_database=>ty_result.
    DATA ls_row      TYPE zcl_sqlite_record=>ty_values.
    DATA lo_value    TYPE REF TO zcl_sqlite_value.
    DATA lv_name     TYPE string.
    DATA lv_values   TYPE string.
    DATA lv_text     TYPE string.
    DATA lv_count    TYPE i.

    lv_name = 'test/m5_11_delete_all.db'.
    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).

    lo_database = zcl_sqlite_database=>create( lv_name ).
    lo_database->execute( 'CREATE TABLE delete_all_t (id INTEGER PRIMARY KEY, name TEXT, qty INTEGER)' ).
    DO 120 TIMES.
      IF sy-index > 1.
        lv_values = lv_values && ', '.
      ENDIF.
      lv_values = lv_values &&
        |({ sy-index }, 'name-{ sy-index }', { sy-index })|.
    ENDDO.
    lo_database->execute( |INSERT INTO delete_all_t VALUES { lv_values }| ).
    lo_database->execute( 'CREATE INDEX idx_name ON delete_all_t (name)' ).
    lo_database->execute( 'CREATE UNIQUE INDEX idx_qty ON delete_all_t (qty)' ).
    lo_database->execute( 'UPDATE delete_all_t SET name = ''changed'', qty = 500 WHERE id = 50' ).
    lo_database->execute( 'DELETE FROM delete_all_t WHERE id <= 20' ).

    TRY.
        lo_database->execute( 'INSERT INTO delete_all_t VALUES (200, ''dupe'', 500)' ).
        cl_abap_unit_assert=>fail( 'duplicate unique index value was accepted' ).
      CATCH zcx_sqlite_error INTO lo_error.
        cl_abap_unit_assert=>assert_equals(
          act = lo_error->code
          exp = zcx_sqlite_error=>sqlite_constraint ).
    ENDTRY.

    lv_text = repeat( val = 'L'
                      occ = 9000 ).
    lo_database->execute( |INSERT INTO delete_all_t VALUES (201, '{ lv_text }', 201)| ).
    lo_database->close( ).

    lo_file = lo_vfs->zif_sqlite_vfs~open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_name' )-rootpage ) ).
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 101
      msg = 'maintained index entry count' ).
    lo_file->close( ).
    lv_count = 0.

    lo_database = zcl_sqlite_database=>open( lv_name ).
    lo_database->execute( 'DELETE FROM delete_all_t' ).
    rs_result = lo_database->query( 'SELECT count(*) FROM delete_all_t' ).
    READ TABLE rs_result-rows INTO ls_row INDEX 1.
    READ TABLE ls_row INTO lo_value INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lo_value->as_integer( )
      exp = 0
      msg = 'delete all leaves table empty' ).
    lo_database->close( ).

* the pre-delete index scan cached pages in lo_vfs, so inspect with a fresh VFS
    lo_check_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_check_vfs->open( lv_name ).
    lo_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
    lo_schema = zcl_sqlite_schema=>read( lo_pager ).
    ls_table = lo_schema->table( 'delete_all_t' ).
    lo_tcursor = NEW zcl_sqlite_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( ls_table-rootpage ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_tcursor->first( )
      exp = abap_false
      msg = 'table stays empty after delete all' ).

    ls_index = lo_schema->index( 'idx_name' ).
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( ls_index-rootpage ) ).
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 0
      msg = 'name index stays empty after delete all' ).

    lv_count = 0.
    lo_cursor = NEW zcl_sqlite_index_cursor(
      io_pager     = lo_pager
      iv_root_page = CONV i( lo_schema->index( 'idx_qty' )-rootpage ) ).
    IF lo_cursor->first( ) = abap_true.
      DO.
        lv_count = lv_count + 1.
        IF lo_cursor->next( ) = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
    ENDIF.
    cl_abap_unit_assert=>assert_equals(
      act = lv_count
      exp = 0
      msg = 'qty index stays empty after delete all' ).
    lo_file->close( ).
    lo_vfs->zif_sqlite_vfs~delete( lv_name ).
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
      cl_abap_unit_assert=>fail( mv_failures ).
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
