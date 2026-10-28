* Shared contract for every ZIF_SQLITE_VFS implementation. Subclasses
* implement CREATE_VFS and call RUN from a test method.
CLASS zcl_sqlite_vfs_contract DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS run.

  PROTECTED SECTION.
    METHODS create_vfs
      RETURNING VALUE(ro_vfs) TYPE REF TO zif_sqlite_vfs.

    METHODS check_open.
    METHODS check_open_twice.
    METHODS check_delete.
    METHODS check_list.
    METHODS check_rename.
    METHODS check_read.
    METHODS check_write.
    METHODS check_large.
    METHODS check_truncate.
    METHODS check_locking.
    METHODS check_negative.

  PRIVATE SECTION.
    METHODS check_read_result
      IMPORTING io_file   TYPE REF TO zif_sqlite_file
                iv_offset TYPE i
                iv_amount TYPE i
                iv_data   TYPE xstring
                iv_short  TYPE abap_bool
                iv_msg    TYPE string.
ENDCLASS.


CLASS zcl_sqlite_vfs_contract IMPLEMENTATION.

  METHOD run.
    check_open( ).
    check_open_twice( ).
    check_delete( ).
    check_list( ).
    check_rename( ).
    check_read( ).
    check_write( ).
    check_large( ).
    check_truncate( ).
    check_locking( ).
    check_negative( ).
  ENDMETHOD.

  METHOD create_vfs.
    cl_abap_unit_assert=>fail( msg = 'create_vfs must be redefined' ).
  ENDMETHOD.

  METHOD check_open.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = create_vfs( ).
    cl_abap_unit_assert=>assert_false(
      act = lo_vfs->exists( 'db' ) msg = 'file exists before open' ).

    lo_file = lo_vfs->open( 'db' ).
    cl_abap_unit_assert=>assert_bound( act = lo_file msg = 'open returns a handle' ).
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'db' ) msg = 'file exists after open' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 0 msg = 'new file is empty' ).
  ENDMETHOD.

  METHOD check_open_twice.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_first TYPE REF TO zif_sqlite_file.
    DATA lo_second TYPE REF TO zif_sqlite_file.

    lo_vfs = create_vfs( ).
    lo_first = lo_vfs->open( 'shared' ).
    lo_second = lo_vfs->open( 'shared' ).

    lo_first->write( iv_offset = 0 iv_data = 'AABB' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_second->size( ) exp = 2 msg = 'second handle sees the size' ).
    check_read_result(
      io_file = lo_second iv_offset = 0 iv_amount = 2
      iv_data = 'AABB' iv_short = abap_false iv_msg = 'second handle sees the data' ).

    lo_second->write( iv_offset = 2 iv_data = 'CC' ).
    check_read_result(
      io_file = lo_first iv_offset = 0 iv_amount = 3
      iv_data = 'AABBCC' iv_short = abap_false iv_msg = 'first handle sees the data' ).
  ENDMETHOD.

  METHOD check_delete.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'gone' ).
    lo_file->write( iv_offset = 0 iv_data = 'AA' ).
    lo_vfs->open( 'kept' ).

    lo_vfs->delete( 'gone' ).
    cl_abap_unit_assert=>assert_false(
      act = lo_vfs->exists( 'gone' ) msg = 'deleted file is gone' ).
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'kept' ) msg = 'other files survive delete' ).

    lo_vfs->delete( 'never' ).
    cl_abap_unit_assert=>assert_false(
      act = lo_vfs->exists( 'never' ) msg = 'delete of a missing file is a no-op' ).

    lo_file = lo_vfs->open( 'gone' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 0 msg = 'reopened deleted file is empty' ).
  ENDMETHOD.

  METHOD check_list.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lt_names TYPE string_table.
    DATA lv_name TYPE string.

    lo_vfs = create_vfs( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lo_vfs->list( ) ) exp = 0 msg = 'empty list' ).

    lo_vfs->open( 'b' ).
    lo_vfs->open( 'a' ).
    lo_vfs->open( 'dir/c' ).

    lt_names = lo_vfs->list( ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_names ) exp = 3 msg = 'list has all files' ).

    READ TABLE lt_names INTO lv_name INDEX 1.
    cl_abap_unit_assert=>assert_equals( act = lv_name exp = 'a' msg = 'list is sorted, 1' ).
    READ TABLE lt_names INTO lv_name INDEX 2.
    cl_abap_unit_assert=>assert_equals( act = lv_name exp = 'b' msg = 'list is sorted, 2' ).
    READ TABLE lt_names INTO lv_name INDEX 3.
    cl_abap_unit_assert=>assert_equals( act = lv_name exp = 'dir/c' msg = 'list is sorted, 3' ).
  ENDMETHOD.

  METHOD check_rename.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'old' ).
    lo_file->write( iv_offset = 0 iv_data = '010203' ).

    lo_vfs->rename( iv_name = 'old' iv_new_name = 'new' ).
    cl_abap_unit_assert=>assert_false(
      act = lo_vfs->exists( 'old' ) msg = 'old name is gone' ).
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'new' ) msg = 'new name exists' ).

    lo_file = lo_vfs->open( 'new' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 3 msg = 'rename keeps the size' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 3
      iv_data = '010203' iv_short = abap_false iv_msg = 'rename keeps the data' ).

    TRY.
        lo_vfs->rename( iv_name = 'missing' iv_new_name = 'other' ).
        cl_abap_unit_assert=>fail( msg = 'rename of a missing file must fail' ).
      CATCH cx_sy_file_access_error.
* expected
    ENDTRY.

    lo_vfs->open( 'target' ).
    TRY.
        lo_vfs->rename( iv_name = 'new' iv_new_name = 'target' ).
        cl_abap_unit_assert=>fail( msg = 'rename to an existing file must fail' ).
      CATCH cx_sy_file_access_error.
* expected
    ENDTRY.
    cl_abap_unit_assert=>assert_true(
      act = lo_vfs->exists( 'new' ) msg = 'failed rename keeps the source' ).
  ENDMETHOD.

  METHOD check_read.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lv_empty TYPE xstring.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'read' ).

    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 0
      iv_data = lv_empty iv_short = abap_false iv_msg = 'empty read' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 4
      iv_data = '00000000' iv_short = abap_true iv_msg = 'read from empty file' ).

    lo_file->write( iv_offset = 0 iv_data = '01020304' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 4
      iv_data = '01020304' iv_short = abap_false iv_msg = 'full read' ).
    check_read_result(
      io_file = lo_file iv_offset = 1 iv_amount = 2
      iv_data = '0203' iv_short = abap_false iv_msg = 'read inside the file' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 6
      iv_data = '010203040000' iv_short = abap_true iv_msg = 'read past the end' ).
    check_read_result(
      io_file = lo_file iv_offset = 4 iv_amount = 4
      iv_data = '00000000' iv_short = abap_true iv_msg = 'read at the end' ).
    check_read_result(
      io_file = lo_file iv_offset = 6 iv_amount = 2
      iv_data = '0000' iv_short = abap_true iv_msg = 'read after the end' ).
  ENDMETHOD.

  METHOD check_write.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lv_empty TYPE xstring.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'write' ).

    lo_file->write( iv_offset = 0 iv_data = '0102' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 2 msg = 'write at the start' ).

    lo_file->write( iv_offset = 1 iv_data = '03' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 2 msg = 'overwrite keeps the size' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 2
      iv_data = '0103' iv_short = abap_false iv_msg = 'overwrite replaced the byte' ).

    lo_file->write( iv_offset = 4 iv_data = '0405' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 6 msg = 'write past the end grows the file' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 6
      iv_data = '010300000405' iv_short = abap_false iv_msg = 'gap is zero filled' ).

    lo_file->write( iv_offset = 10 iv_data = lv_empty ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 6 msg = 'empty write does not grow the file' ).

    lo_file->write( iv_offset = 0 iv_data = 'AABBCCDDEEFF0011' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 8 msg = 'longer write grows the file' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 8
      iv_data = 'AABBCCDDEEFF0011' iv_short = abap_false iv_msg = 'longer write replaced the data' ).
  ENDMETHOD.

  METHOD check_large.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA lv_data TYPE xstring.
    DATA lv_zeros TYPE xstring.
    DATA lv_part TYPE xstring.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'large' ).

* 4112 bytes, exercises multi-block I/O and truncation at a large size
    lv_data = repeat( val = '00112233445566778899AABBCCDDEEFF' occ = 257 ).
    lo_file->write( iv_offset = 0 iv_data = lv_data ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 4112 msg = 'large write size' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 4112
      iv_data = lv_data iv_short = abap_false iv_msg = 'large write read back' ).
* ANORMALY: an xstring slice is rejected as a method argument, copy it first
    lv_part = lv_data+4048(64).
    check_read_result(
      io_file = lo_file iv_offset = 4048 iv_amount = 64
      iv_data = lv_part iv_short = abap_false iv_msg = 'read across a block boundary' ).

    lo_file->truncate( iv_size = 4100 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 4100 msg = 'large truncate size' ).
    lv_zeros = repeat( val = '00' occ = 12 ).
    lv_part = lv_data+4096(4) && lv_zeros.
    check_read_result(
      io_file = lo_file iv_offset = 4096 iv_amount = 16
      iv_data = lv_part
      iv_short = abap_true iv_msg = 'truncate inside the second block' ).

    lo_file->truncate( iv_size = 4112 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 4112 msg = 'large grow size' ).
    check_read_result(
      io_file = lo_file iv_offset = 4100 iv_amount = 12
      iv_data = lv_zeros iv_short = abap_false iv_msg = 'regrown area is zero' ).
  ENDMETHOD.

  METHOD check_truncate.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'truncate' ).
    lo_file->write( iv_offset = 0 iv_data = '010203040506' ).

    lo_file->truncate( iv_size = 3 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 3 msg = 'shrink size' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 4
      iv_data = '01020300' iv_short = abap_true iv_msg = 'shrink keeps the prefix' ).

    lo_file->truncate( iv_size = 5 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 5 msg = 'grow size' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 5
      iv_data = '0102030000' iv_short = abap_false iv_msg = 'grow zero fills' ).

    lo_file->truncate( iv_size = 0 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 0 msg = 'truncate to empty' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 2
      iv_data = '0000' iv_short = abap_true iv_msg = 'truncated file reads as zeros' ).

    lo_file->truncate( iv_size = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 2 msg = 'grow an empty file' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 2
      iv_data = '0000' iv_short = abap_false iv_msg = 'grown empty file is zero' ).
  ENDMETHOD.

  METHOD check_locking.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'locked' ).
    lo_file->write( iv_offset = 0 iv_data = 'CAFE' ).
    lo_file->sync( ).

    lo_file->lock( zif_sqlite_file=>c_lock_shared ).
    lo_file->lock( zif_sqlite_file=>c_lock_reserved ).
    lo_file->lock( zif_sqlite_file=>c_lock_exclusive ).
    lo_file->unlock( zif_sqlite_file=>c_lock_shared ).
    lo_file->unlock( zif_sqlite_file=>c_lock_none ).

    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 2
      iv_data = 'CAFE' iv_short = abap_false iv_msg = 'data survives locking' ).

    lo_file->close( ).
    lo_file = lo_vfs->open( 'locked' ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_file->size( ) exp = 2 msg = 'data survives close' ).
    check_read_result(
      io_file = lo_file iv_offset = 0 iv_amount = 2
      iv_data = 'CAFE' iv_short = abap_false iv_msg = 'reopen after close' ).
  ENDMETHOD.

  METHOD check_negative.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.
    DATA ls_result TYPE zif_sqlite_file=>ty_read_result.

    lo_vfs = create_vfs( ).
    lo_file = lo_vfs->open( 'negative' ).

    TRY.
        ls_result = lo_file->read( iv_offset = -1 iv_amount = 1 ).
        cl_abap_unit_assert=>fail( msg = 'negative read offset must fail' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        ls_result = lo_file->read( iv_offset = 0 iv_amount = -1 ).
        cl_abap_unit_assert=>fail( msg = 'negative read amount must fail' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        lo_file->write( iv_offset = -1 iv_data = '00' ).
        cl_abap_unit_assert=>fail( msg = 'negative write offset must fail' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.

    TRY.
        lo_file->truncate( iv_size = -1 ).
        cl_abap_unit_assert=>fail( msg = 'negative truncate size must fail' ).
      CATCH cx_sy_range_out_of_bounds.
* expected
    ENDTRY.
  ENDMETHOD.

  METHOD check_read_result.
    DATA ls_result TYPE zif_sqlite_file=>ty_read_result.

    ls_result = io_file->read( iv_offset = iv_offset iv_amount = iv_amount ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-data exp = iv_data msg = iv_msg ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-short exp = iv_short msg = iv_msg ).
  ENDMETHOD.

ENDCLASS.
