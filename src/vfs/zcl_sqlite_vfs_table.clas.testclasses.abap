CLASS ltcl_vfs_table DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  INHERITING FROM zcl_sqlite_vfs_contract.

  PROTECTED SECTION.
    METHODS create_vfs REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_prefix TYPE string VALUE 'test/contract/'.

    METHODS contract FOR TESTING.
    METHODS import_export FOR TESTING.
    METHODS teardown.
    METHODS cleanup.
ENDCLASS.


CLASS ltcl_vfs_table IMPLEMENTATION.

  METHOD contract.
    run( ).
  ENDMETHOD.

  METHOD import_export.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lo_table TYPE REF TO zcl_sqlite_vfs_table.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lt_names TYPE string_table.
    DATA lv_data TYPE xstring.
    DATA lv_empty TYPE xstring.
    DATA lv_export TYPE xstring.
    DATA lv_name TYPE string.

    cleanup( ).
    lo_table = NEW zcl_sqlite_vfs_table( iv_prefix = c_prefix ).
    lo_vfs = lo_table.

    lv_data = repeat( val = '00112233445566778899AABBCCDDEEFF' occ = 300 ).
    lo_table->import( iv_name = 'imported.db' iv_data = lv_data ).
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'imported.db' ) msg = 'import creates the file' ).

    lt_names = lo_vfs->list( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_names ) exp = 1 msg = 'imported file is listed' ).
    READ TABLE lt_names INTO lv_name INDEX 1.
    cl_abap_unit_assert=>assert_equals(
      act = lv_name exp = 'imported.db' msg = 'listed file name' ).

    lv_export = lo_table->export( 'imported.db' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_export exp = lv_data msg = 'export is byte identical' ).

    lo_vfs->rename( iv_name = 'imported.db' iv_new_name = 'renamed.db' ).
    cl_abap_unit_assert=>assert_false(
      act = lo_vfs->exists( 'imported.db' ) msg = 'renamed file is gone' ).
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'renamed.db' ) msg = 'renamed file exists' ).
    lv_export = lo_table->export( 'renamed.db' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_export exp = lv_data msg = 'rename keeps the bytes' ).

    lo_vfs->delete( 'renamed.db' ).
    cl_abap_unit_assert=>assert_false(
      act = lo_vfs->exists( 'renamed.db' ) msg = 'deleted file is gone' ).

* importing a shorter file must not leave blocks from the old content
    lv_data = repeat( val = '00112233445566778899AABBCCDDEEFF' occ = 300 ).
    lo_table->import( iv_name = 'replace.db' iv_data = lv_data ).
    lv_data = repeat( val = '00112233445566778899AABBCCDDEEFF' occ = 10 ).
    lo_table->import( iv_name = 'replace.db' iv_data = lv_data ).
    lo_file = lo_vfs->open( 'replace.db' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 160 msg = 'reimport replaces the size' ).
    lv_export = lo_table->export( 'replace.db' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_export exp = lv_data msg = 'reimport replaces the bytes' ).
    lo_vfs->delete( 'replace.db' ).

* an empty file is still a file
    lo_table->import( iv_name = 'empty.db' iv_data = lv_empty ).
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'empty.db' ) msg = 'empty import creates the file' ).
    lo_file = lo_vfs->open( 'empty.db' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 0 msg = 'empty import has size zero' ).
    lv_export = lo_table->export( 'empty.db' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_export exp = lv_empty msg = 'empty export is empty' ).
    lo_vfs->delete( 'empty.db' ).

    TRY.
        lv_export = lo_table->export( 'missing.db' ).
        cl_abap_unit_assert=>fail( msg = 'export of a missing file must fail' ).
      CATCH cx_sy_file_access_error.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD create_vfs.
    cleanup( ).
    ro_vfs = NEW zcl_sqlite_vfs_table( iv_prefix = c_prefix ).
  ENDMETHOD.

  METHOD teardown.
    cleanup( ).
    COMMIT WORK.
  ENDMETHOD.

  METHOD cleanup.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lt_names TYPE string_table.
    DATA lv_name TYPE string.

* only this test namespace is touched, so fixtures loaded for other
* tests are not removed
    lo_vfs = NEW zcl_sqlite_vfs_table( iv_prefix = c_prefix ).
    lt_names = lo_vfs->list( ).
    LOOP AT lt_names INTO lv_name.
      lo_vfs->delete( lv_name ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
