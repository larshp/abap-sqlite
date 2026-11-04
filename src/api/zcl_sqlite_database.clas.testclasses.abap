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

ENDCLASS.
