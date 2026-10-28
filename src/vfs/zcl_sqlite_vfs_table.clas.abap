* A VFS that keeps every file in ZSQLITE_FILES. A file is a series of
* fixed size blocks; every block is full except possibly the last one.
CLASS zcl_sqlite_vfs_table DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_vfs.

* helpers for ZCL_SQLITE_FILE_TABLE, not part of the VFS contract
    METHODS read_file
      IMPORTING iv_name          TYPE string
                iv_offset        TYPE i
                iv_amount        TYPE i
      RETURNING VALUE(rs_result) TYPE zif_sqlite_file=>ty_read_result
      RAISING   cx_sy_range_out_of_bounds.

    METHODS write_file
      IMPORTING iv_name   TYPE string
                iv_offset TYPE i
                iv_data   TYPE xstring
      RAISING   cx_sy_range_out_of_bounds.

    METHODS truncate_file
      IMPORTING iv_name TYPE string
                iv_size TYPE i
      RAISING   cx_sy_range_out_of_bounds.

    METHODS file_size
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_size) TYPE i.

  PRIVATE SECTION.
    CONSTANTS c_block_size TYPE i VALUE zcl_sqlite_files=>c_default_block_size.

    TYPES: BEGIN OF ty_block,
             name    TYPE string,
             blockno TYPE i,
             data    TYPE xstring,
           END OF ty_block.
    TYPES ty_blocks TYPE HASHED TABLE OF ty_block WITH UNIQUE KEY name blockno.

    DATA mt_blocks TYPE ty_blocks.

    METHODS zero_bytes
      IMPORTING iv_count        TYPE i
      RETURNING VALUE(rv_zeros) TYPE xstring.

    METHODS get_block
      IMPORTING iv_name        TYPE string
                iv_blockno     TYPE i
      RETURNING VALUE(rv_data) TYPE xstring.

    METHODS put_block
      IMPORTING iv_name    TYPE string
                iv_blockno TYPE i
                iv_data    TYPE xstring.

    METHODS patch_block
      IMPORTING iv_block        TYPE xstring
                iv_pos          TYPE i
                iv_data         TYPE xstring
      RETURNING VALUE(rv_block) TYPE xstring.

    METHODS fit_block
      IMPORTING iv_block        TYPE xstring
                iv_size         TYPE i
      RETURNING VALUE(rv_block) TYPE xstring.

    METHODS delete_blocks
      IMPORTING iv_name TYPE string
                iv_from TYPE i.

    METHODS grow_file
      IMPORTING iv_name TYPE string
                iv_size TYPE i.

    METHODS ensure_file
      IMPORTING iv_name TYPE string.
ENDCLASS.


CLASS zcl_sqlite_vfs_table IMPLEMENTATION.

  METHOD zif_sqlite_vfs~open.
    ensure_file( iv_name ).

    ro_file = NEW zcl_sqlite_file_table( io_vfs = me iv_name = iv_name ).
  ENDMETHOD.

  METHOD zif_sqlite_vfs~exists.
    DATA lv_count TYPE i.
    DATA lv_name TYPE zsqlite_files-filename.

    lv_name = iv_name.
    SELECT COUNT(*) FROM zsqlite_files INTO @lv_count
      WHERE mandt = @sy-mandt AND filename = @lv_name.
    rv_exists = boolc( lv_count > 0 ).
  ENDMETHOD.

  METHOD zif_sqlite_vfs~delete.
    delete_blocks( iv_name = iv_name iv_from = 0 ).
  ENDMETHOD.

  METHOD zif_sqlite_vfs~list.
    DATA lt_names TYPE STANDARD TABLE OF zsqlite_files-filename WITH DEFAULT KEY.
    DATA lv_name TYPE zsqlite_files-filename.

    SELECT DISTINCT filename FROM zsqlite_files INTO TABLE @lt_names
      WHERE mandt = @sy-mandt
      ORDER BY filename.

    LOOP AT lt_names INTO lv_name.
      APPEND lv_name TO rt_names.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_sqlite_vfs~rename.
    DATA lv_new_name TYPE zsqlite_files-filename.
    DATA lv_old_name TYPE zsqlite_files-filename.

    IF zif_sqlite_vfs~exists( iv_name ) = abap_false.
      RAISE EXCEPTION TYPE cx_sy_file_access_error.
    ENDIF.
    IF zif_sqlite_vfs~exists( iv_new_name ) = abap_true.
      RAISE EXCEPTION TYPE cx_sy_file_access_error.
    ENDIF.

    lv_old_name = iv_name.
    lv_new_name = iv_new_name.
    UPDATE zsqlite_files SET filename = @lv_new_name
      WHERE mandt = @sy-mandt AND filename = @lv_old_name.

    DELETE mt_blocks WHERE name = iv_name.
    DELETE mt_blocks WHERE name = iv_new_name.
  ENDMETHOD.

  METHOD read_file.
    DATA lv_available TYPE i.
    DATA lv_block TYPE xstring.
    DATA lv_block_start TYPE i.
    DATA lv_blockno TYPE i.
    DATA lv_from TYPE i.
    DATA lv_length TYPE i.
    DATA lv_missing TYPE i.
    DATA lv_pos TYPE i.
    DATA lv_size TYPE i.
    DATA lv_to TYPE i.

    IF iv_offset < 0 OR iv_amount < 0.
      RAISE EXCEPTION TYPE cx_sy_range_out_of_bounds.
    ENDIF.
    IF iv_amount = 0.
      RETURN.
    ENDIF.

    lv_size = file_size( iv_name ).
    lv_available = lv_size - iv_offset.
    IF lv_available < 0.
      lv_available = 0.
    ELSEIF lv_available > iv_amount.
      lv_available = iv_amount.
    ENDIF.

    IF lv_available > 0.
      lv_blockno = iv_offset DIV c_block_size.
      WHILE lv_blockno * c_block_size < iv_offset + lv_available.
        lv_block_start = lv_blockno * c_block_size.
        lv_from = iv_offset.
        IF lv_from < lv_block_start.
          lv_from = lv_block_start.
        ENDIF.
        lv_to = iv_offset + lv_available.
        IF lv_to > lv_block_start + c_block_size.
          lv_to = lv_block_start + c_block_size.
        ENDIF.

        lv_pos = lv_from - lv_block_start.
        lv_length = lv_to - lv_from.
        lv_block = get_block( iv_name = iv_name iv_blockno = lv_blockno ).
        rs_result-data = rs_result-data && lv_block+lv_pos(lv_length).

        lv_blockno = lv_blockno + 1.
      ENDWHILE.
    ENDIF.

    lv_missing = iv_amount - lv_available.
    IF lv_missing > 0.
      rs_result-data = rs_result-data && zero_bytes( lv_missing ).
      rs_result-short = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD write_file.
    DATA lv_block TYPE xstring.
    DATA lv_block_length TYPE i.
    DATA lv_block_start TYPE i.
    DATA lv_blockno TYPE i.
    DATA lv_end TYPE i.
    DATA lv_from TYPE i.
    DATA lv_last_block TYPE i.
    DATA lv_length TYPE i.
    DATA lv_patch TYPE xstring.
    DATA lv_patch_length TYPE i.
    DATA lv_old_last_block TYPE i.
    DATA lv_patch_pos TYPE i.
    DATA lv_pos TYPE i.
    DATA lv_size TYPE i.
    DATA lv_to TYPE i.

    IF iv_offset < 0.
      RAISE EXCEPTION TYPE cx_sy_range_out_of_bounds.
    ENDIF.

    lv_length = xstrlen( iv_data ).
    IF lv_length = 0.
      RETURN.
    ENDIF.

    lv_size = file_size( iv_name ).
    lv_end = iv_offset + lv_length.
    lv_last_block = ( lv_end - 1 ) DIV c_block_size.

* when the write starts after the current last block, the old last block
* must become a full block so the gap reads as zeros
    IF lv_size = 0.
      lv_old_last_block = 0.
    ELSE.
      lv_old_last_block = ( lv_size - 1 ) DIV c_block_size.
    ENDIF.
    IF iv_offset >= ( lv_old_last_block + 1 ) * c_block_size.
      lv_block = get_block( iv_name = iv_name iv_blockno = lv_old_last_block ).
      lv_block = fit_block( iv_block = lv_block iv_size = c_block_size ).
      put_block( iv_name = iv_name iv_blockno = lv_old_last_block iv_data = lv_block ).
    ENDIF.

    lv_blockno = iv_offset DIV c_block_size.
    WHILE lv_blockno <= lv_last_block.
      lv_block_start = lv_blockno * c_block_size.
      lv_from = iv_offset.
      IF lv_from < lv_block_start.
        lv_from = lv_block_start.
      ENDIF.
      lv_to = lv_end.
      IF lv_to > lv_block_start + c_block_size.
        lv_to = lv_block_start + c_block_size.
      ENDIF.

      lv_pos = lv_from - lv_block_start.
      lv_patch_pos = lv_from - iv_offset.
      lv_patch_length = lv_to - lv_from.
      lv_block = get_block( iv_name = iv_name iv_blockno = lv_blockno ).
* ANORMALY: an xstring slice is rejected as a method argument, copy it first
      lv_patch = iv_data+lv_patch_pos(lv_patch_length).
      lv_block = patch_block(
        iv_block = lv_block
        iv_pos   = lv_pos
        iv_data  = lv_patch ).

      IF lv_blockno < lv_last_block.
        lv_block_length = c_block_size.
      ELSEIF lv_end > lv_size.
        lv_block_length = lv_end - lv_block_start.
      ELSE.
        lv_block_length = xstrlen( lv_block ).
      ENDIF.
      lv_block = fit_block( iv_block = lv_block iv_size = lv_block_length ).
      put_block( iv_name = iv_name iv_blockno = lv_blockno iv_data = lv_block ).

      lv_blockno = lv_blockno + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD truncate_file.
    DATA lv_block TYPE xstring.
    DATA lv_keep TYPE i.
    DATA lv_last_block TYPE i.
    DATA lv_size TYPE i.

    IF iv_size < 0.
      RAISE EXCEPTION TYPE cx_sy_range_out_of_bounds.
    ENDIF.

    lv_size = file_size( iv_name ).
    IF iv_size = lv_size.
      RETURN.
    ELSEIF iv_size > lv_size.
      grow_file( iv_name = iv_name iv_size = iv_size ).
      RETURN.
    ENDIF.

    IF iv_size = 0.
      delete_blocks( iv_name = iv_name iv_from = 0 ).
      put_block( iv_name = iv_name iv_blockno = 0 iv_data = zero_bytes( 0 ) ).
      RETURN.
    ENDIF.

    lv_last_block = iv_size DIV c_block_size.
    lv_keep = iv_size MOD c_block_size.
    IF lv_keep = 0.
      lv_last_block = lv_last_block - 1.
      lv_keep = c_block_size.
    ENDIF.

    lv_block = get_block( iv_name = iv_name iv_blockno = lv_last_block ).
    lv_block = fit_block( iv_block = lv_block iv_size = lv_keep ).
    put_block( iv_name = iv_name iv_blockno = lv_last_block iv_data = lv_block ).
    delete_blocks( iv_name = iv_name iv_from = lv_last_block + 1 ).
  ENDMETHOD.

  METHOD file_size.
    DATA lv_blockno TYPE zsqlite_files-blockno.
    DATA lv_data TYPE zsqlite_files-data.
    DATA lv_name TYPE zsqlite_files-filename.

    lv_name = iv_name.
    SELECT MAX( blockno ) FROM zsqlite_files INTO @lv_blockno
      WHERE mandt = @sy-mandt AND filename = @lv_name.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE data FROM zsqlite_files INTO @lv_data
      WHERE mandt = @sy-mandt AND filename = @lv_name AND blockno = @lv_blockno.
    rv_size = lv_blockno * c_block_size + xstrlen( lv_data ).
  ENDMETHOD.

  METHOD zero_bytes.
    IF iv_count > 0.
      rv_zeros = repeat( val = '00' occ = iv_count ).
    ENDIF.
  ENDMETHOD.

  METHOD get_block.
    DATA ls_block TYPE ty_block.
    DATA lv_data TYPE xstring.
    DATA lv_name TYPE zsqlite_files-filename.

    READ TABLE mt_blocks INTO ls_block WITH KEY name = iv_name blockno = iv_blockno.
    IF sy-subrc = 0.
      rv_data = ls_block-data.
      RETURN.
    ENDIF.

    lv_name = iv_name.
    SELECT SINGLE data FROM zsqlite_files INTO @lv_data
      WHERE mandt = @sy-mandt AND filename = @lv_name AND blockno = @iv_blockno.
    IF sy-subrc = 0.
      rv_data = lv_data.
    ELSE.
      rv_data = zero_bytes( c_block_size ).
    ENDIF.

    ls_block-name = iv_name.
    ls_block-blockno = iv_blockno.
    ls_block-data = rv_data.
    INSERT ls_block INTO TABLE mt_blocks.
  ENDMETHOD.

  METHOD put_block.
    DATA ls_block TYPE zsqlite_files.
    DATA ls_cache TYPE ty_block.
    DATA lv_name TYPE zsqlite_files-filename.

    lv_name = iv_name.
    ls_block-mandt = sy-mandt.
    ls_block-filename = lv_name.
    ls_block-blockno = iv_blockno.
    ls_block-data = iv_data.
    MODIFY zsqlite_files FROM @ls_block.

    ls_cache-name = iv_name.
    ls_cache-blockno = iv_blockno.
    ls_cache-data = iv_data.

* ANORMALY: MODIFY TABLE on a hashed table updates by full row content in the
* transpiler, not by the table key, so replace the row explicitly.
    DELETE mt_blocks WHERE name = iv_name AND blockno = iv_blockno.
    INSERT ls_cache INTO TABLE mt_blocks.
  ENDMETHOD.

  METHOD patch_block.
    DATA lv_after TYPE xstring.
    DATA lv_after_length TYPE i.
    DATA lv_after_pos TYPE i.
    DATA lv_before TYPE xstring.
    DATA lv_size TYPE i.

    lv_size = xstrlen( iv_block ).
    IF iv_pos > lv_size.
      lv_before = iv_block && zero_bytes( iv_pos - lv_size ).
    ELSEIF iv_pos > 0.
      lv_before = iv_block+0(iv_pos).
    ENDIF.

    lv_after_pos = iv_pos + xstrlen( iv_data ).
    IF lv_after_pos < lv_size.
      lv_after_length = lv_size - lv_after_pos.
      lv_after = iv_block+lv_after_pos(lv_after_length).
    ENDIF.

    rv_block = lv_before && iv_data && lv_after.
  ENDMETHOD.

  METHOD fit_block.
    DATA lv_size TYPE i.

    lv_size = xstrlen( iv_block ).
    IF iv_size <= 0.
      RETURN.
    ELSEIF lv_size = iv_size.
      rv_block = iv_block.
    ELSEIF lv_size > iv_size.
      rv_block = iv_block+0(iv_size).
    ELSE.
      rv_block = iv_block && zero_bytes( iv_size - lv_size ).
    ENDIF.
  ENDMETHOD.

  METHOD delete_blocks.
    DATA lv_name TYPE zsqlite_files-filename.

    lv_name = iv_name.
    DELETE FROM zsqlite_files
      WHERE mandt = @sy-mandt AND filename = @lv_name AND blockno >= @iv_from.
    DELETE mt_blocks WHERE name = iv_name AND blockno >= iv_from.
  ENDMETHOD.

  METHOD grow_file.
    DATA lv_block TYPE xstring.
    DATA lv_block_length TYPE i.
    DATA lv_block_start TYPE i.
    DATA lv_blockno TYPE i.
    DATA lv_last_block TYPE i.
    DATA lv_size TYPE i.

    lv_size = file_size( iv_name ).
    IF iv_size <= lv_size.
      RETURN.
    ENDIF.

    IF lv_size = 0.
      lv_blockno = 0.
    ELSE.
      lv_blockno = lv_size DIV c_block_size.
    ENDIF.
    lv_block_start = lv_blockno * c_block_size.
    lv_block = get_block( iv_name = iv_name iv_blockno = lv_blockno ).

    IF iv_size <= lv_block_start + c_block_size.
      lv_block = fit_block( iv_block = lv_block iv_size = iv_size - lv_block_start ).
      put_block( iv_name = iv_name iv_blockno = lv_blockno iv_data = lv_block ).
      RETURN.
    ENDIF.

    lv_block = fit_block( iv_block = lv_block iv_size = c_block_size ).
    put_block( iv_name = iv_name iv_blockno = lv_blockno iv_data = lv_block ).

    lv_blockno = lv_blockno + 1.
    lv_last_block = ( iv_size - 1 ) DIV c_block_size.
    WHILE lv_blockno <= lv_last_block.
      lv_block_start = lv_blockno * c_block_size.
      IF lv_blockno = lv_last_block.
        lv_block_length = iv_size - lv_block_start.
      ELSE.
        lv_block_length = c_block_size.
      ENDIF.
      put_block(
        iv_name    = iv_name
        iv_blockno = lv_blockno
        iv_data    = zero_bytes( lv_block_length ) ).
      lv_blockno = lv_blockno + 1.
    ENDWHILE.
  ENDMETHOD.

  METHOD ensure_file.
    IF zif_sqlite_vfs~exists( iv_name ) = abap_false.
      put_block( iv_name = iv_name iv_blockno = 0 iv_data = zero_bytes( 0 ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
