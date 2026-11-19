CLASS ltcl_fixture DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS empty FOR TESTING.
    METHODS small FOR TESTING.
    METHODS check
      IMPORTING iv_name TYPE string.
    METHODS raw_file
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_data) TYPE xstring.
ENDCLASS.


CLASS ltcl_fixture IMPLEMENTATION.

  METHOD empty.
    check( 'fixtures/empty.db' ).
  ENDMETHOD.

  METHOD small.
    check( 'fixtures/small.db' ).
  ENDMETHOD.

  METHOD check.
    DATA lo_vfs TYPE REF TO zcl_sqlite_vfs_table.
    DATA lv_export TYPE xstring.
    DATA lv_raw TYPE xstring.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lv_export = lo_vfs->export( iv_name ).
    lv_raw = raw_file( iv_name ).

    cl_abap_unit_assert=>assert_true(
      act = boolc( xstrlen( lv_export ) > 0 )
      msg = |{ iv_name } is not empty| ).
    cl_abap_unit_assert=>assert_equals(
      act = xstrlen( lv_export )
      exp = xstrlen( lv_raw )
      msg = |{ iv_name } size| ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_export
      exp = lv_raw
      msg = |{ iv_name } bytes| ).
  ENDMETHOD.

  METHOD raw_file.
    DATA lt_blocks TYPE STANDARD TABLE OF zsqlite_files-data WITH DEFAULT KEY.
    DATA lv_data TYPE zsqlite_files-data.
    DATA lv_name TYPE zsqlite_files-filename.

* setup.mjs checks that these blocks reassemble to the committed .db file
    lv_name = iv_name.
    SELECT data FROM zsqlite_files INTO TABLE @lt_blocks
      WHERE filename = @lv_name
      ORDER BY blockno.
    LOOP AT lt_blocks INTO lv_data.
      rv_data = rv_data && lv_data.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
