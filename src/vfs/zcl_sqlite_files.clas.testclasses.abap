CLASS ltcl_files DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_file TYPE string VALUE 'test/m0_4.db'.
    CONSTANTS c_rows TYPE i VALUE 100.

    METHODS setup.
    METHODS teardown.
    METHODS roundtrip FOR TESTING.
    METHODS block_sizes FOR TESTING.
    METHODS modify_from_table FOR TESTING.

    CLASS-METHODS build_block
      IMPORTING iv_size        TYPE i
      RETURNING VALUE(rv_data) TYPE xstring.
ENDCLASS.


CLASS ltcl_files IMPLEMENTATION.

  METHOD setup.
    DATA lv_file TYPE string.
    lv_file = c_file.
    DELETE FROM zsqlite_files WHERE filename = @lv_file.
  ENDMETHOD.

  METHOD teardown.
    DATA lv_file TYPE string.
    lv_file = c_file.
    DELETE FROM zsqlite_files WHERE filename = @lv_file.
  ENDMETHOD.

  METHOD roundtrip.
    DATA ls_file TYPE zsqlite_files.
    DATA lv_data TYPE xstring.

    ls_file-mandt = sy-mandt.
    ls_file-filename = c_file.
    ls_file-blockno = 0.
    ls_file-data = build_block( 512 ).

    INSERT zsqlite_files FROM @ls_file.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).

    SELECT SINGLE data FROM zsqlite_files INTO @lv_data
      WHERE mandt = @sy-mandt AND filename = @c_file AND blockno = 0.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = ls_file-data ).

    DELETE FROM zsqlite_files
      WHERE mandt = @sy-mandt AND filename = @c_file AND blockno = 0.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = 1 ).

    SELECT SINGLE data FROM zsqlite_files INTO @lv_data
      WHERE mandt = @sy-mandt AND filename = @c_file AND blockno = 0.
    cl_abap_unit_assert=>assert_subrc( exp = 4 ).
  ENDMETHOD.

  METHOD block_sizes.
    DATA lt_sizes TYPE STANDARD TABLE OF i WITH DEFAULT KEY.
    DATA lt_write TYPE zcl_sqlite_files=>ty_blocks.
    DATA lt_read TYPE zcl_sqlite_files=>ty_blocks.
    DATA ls_file TYPE zsqlite_files.
    DATA lv_blockno TYPE i.
    DATA lv_index TYPE i.
    DATA lv_size TYPE i.

    lt_sizes = VALUE #( ( 512 ) ( 1024 ) ( 2048 ) ( 4096 )
                        ( 8192 ) ( 16384 ) ( 32768 ) ( 65536 ) ).

    LOOP AT lt_sizes INTO lv_size.
      ls_file-mandt = sy-mandt.
      ls_file-filename = c_file.
      ls_file-blockno = lv_blockno.
      ls_file-data = build_block( lv_size ).
      APPEND ls_file TO lt_write.
      lv_blockno = lv_blockno + 1.
    ENDLOOP.

    MODIFY zsqlite_files FROM TABLE @lt_write.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = lines( lt_write ) ).

    SELECT mandt, filename, blockno, data FROM zsqlite_files INTO TABLE @lt_read
      WHERE mandt = @sy-mandt AND filename = @c_file
      ORDER BY blockno.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_read ) exp = lines( lt_write ) ).

    LOOP AT lt_read INTO ls_file.
      lv_index = sy-tabix.
      READ TABLE lt_sizes INTO lv_size INDEX lv_index.
      cl_abap_unit_assert=>assert_subrc( exp = 0 ).
      cl_abap_unit_assert=>assert_equals( act = xstrlen( ls_file-data ) exp = lv_size ).
      cl_abap_unit_assert=>assert_equals( act = ls_file-data exp = build_block( lv_size ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD modify_from_table.
    DATA lt_write TYPE zcl_sqlite_files=>ty_blocks.
    DATA ls_file TYPE zsqlite_files.
    DATA lv_index TYPE i.
    DATA lv_count TYPE i.
    DATA lv_data TYPE xstring.

    DO c_rows TIMES.
      lv_index = sy-index - 1.
      ls_file-mandt = sy-mandt.
      ls_file-filename = c_file.
      ls_file-blockno = lv_index.
      ls_file-data = build_block( 512 ).
      APPEND ls_file TO lt_write.
    ENDDO.

    MODIFY zsqlite_files FROM TABLE @lt_write.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = c_rows ).

* writing the same keys again must update the rows, not duplicate them
    LOOP AT lt_write ASSIGNING FIELD-SYMBOL(<ls_file>).
      <ls_file>-data = build_block( 1024 ).
    ENDLOOP.
    MODIFY zsqlite_files FROM TABLE @lt_write.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = c_rows ).

    SELECT COUNT(*) FROM zsqlite_files INTO @lv_count
      WHERE mandt = @sy-mandt AND filename = @c_file.
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = c_rows ).

    SELECT SINGLE data FROM zsqlite_files INTO @lv_data
      WHERE mandt = @sy-mandt AND filename = @c_file AND blockno = 0.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = xstrlen( lv_data ) exp = 1024 ).
  ENDMETHOD.

  METHOD build_block.
    CONSTANTS c_pattern TYPE xstring VALUE '00112233445566778899AABBCCDDEEFF'.
    rv_data = c_pattern.
    WHILE xstrlen( rv_data ) < iv_size.
      rv_data = rv_data && rv_data.
    ENDWHILE.
    rv_data = rv_data+0(iv_size).
  ENDMETHOD.

ENDCLASS.
