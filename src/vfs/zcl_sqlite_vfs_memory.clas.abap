* A VFS that keeps every file in memory as fixed size blocks. Locking does
* nothing, it is meant for tests and temporary databases.
CLASS zcl_sqlite_vfs_memory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_vfs.

* helpers for ZCL_SQLITE_FILE_MEMORY, not part of the VFS contract
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
    CONSTANTS c_block_size TYPE i VALUE 4096.

    TYPES: BEGIN OF ty_file,
             name TYPE string,
             size TYPE i,
           END OF ty_file.
    TYPES ty_files TYPE HASHED TABLE OF ty_file WITH UNIQUE KEY name.

    TYPES: BEGIN OF ty_block,
             name    TYPE string,
             blockno TYPE i,
             data    TYPE xstring,
           END OF ty_block.
    TYPES ty_blocks TYPE HASHED TABLE OF ty_block WITH UNIQUE KEY name blockno.

    DATA mt_files TYPE ty_files.
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

    METHODS put_file
      IMPORTING iv_name TYPE string
                iv_size TYPE i.
ENDCLASS.


CLASS zcl_sqlite_vfs_memory IMPLEMENTATION.

  METHOD zif_sqlite_vfs~open.
    DATA ls_file TYPE ty_file.

    READ TABLE mt_files INTO ls_file WITH KEY name = iv_name.
    IF sy-subrc <> 0.
      ls_file-name = iv_name.
      INSERT ls_file INTO TABLE mt_files.
    ENDIF.

    ro_file = NEW zcl_sqlite_file_memory( io_vfs = me iv_name = iv_name ).
  ENDMETHOD.

  METHOD zif_sqlite_vfs~exists.
    READ TABLE mt_files TRANSPORTING NO FIELDS WITH KEY name = iv_name.
    rv_exists = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_sqlite_vfs~delete.
    DELETE mt_files WHERE name = iv_name.
    DELETE mt_blocks WHERE name = iv_name.
  ENDMETHOD.

  METHOD zif_sqlite_vfs~list.
    DATA ls_file TYPE ty_file.

    LOOP AT mt_files INTO ls_file.
      APPEND ls_file-name TO rt_names.
    ENDLOOP.
    SORT rt_names.
  ENDMETHOD.

  METHOD zif_sqlite_vfs~rename.
    DATA ls_file TYPE ty_file.
    DATA ls_block TYPE ty_block.
    DATA lt_blocks TYPE STANDARD TABLE OF ty_block WITH DEFAULT KEY.

    READ TABLE mt_files INTO ls_file WITH KEY name = iv_name.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_file_access_error.
    ENDIF.

    READ TABLE mt_files TRANSPORTING NO FIELDS WITH KEY name = iv_new_name.
    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE cx_sy_file_access_error.
    ENDIF.

    DELETE mt_files WHERE name = iv_name.
    ls_file-name = iv_new_name.
    INSERT ls_file INTO TABLE mt_files.

    LOOP AT mt_blocks INTO ls_block WHERE name = iv_name.
      ls_block-name = iv_new_name.
      APPEND ls_block TO lt_blocks.
    ENDLOOP.
    DELETE mt_blocks WHERE name = iv_name.
    LOOP AT lt_blocks INTO ls_block.
      INSERT ls_block INTO TABLE mt_blocks.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_file.
    DATA lv_size TYPE i.
    DATA lv_available TYPE i.
    DATA lv_missing TYPE i.
    DATA lv_blockno TYPE i.
    DATA lv_block_start TYPE i.
    DATA lv_from TYPE i.
    DATA lv_to TYPE i.
    DATA lv_pos TYPE i.
    DATA lv_length TYPE i.
    DATA lv_block TYPE xstring.

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
    DATA lv_size TYPE i.
    DATA lv_length TYPE i.
    DATA lv_end TYPE i.
    DATA lv_blockno TYPE i.
    DATA lv_block_start TYPE i.
    DATA lv_from TYPE i.
    DATA lv_to TYPE i.
    DATA lv_pos TYPE i.
    DATA lv_patch_pos TYPE i.
    DATA lv_patch_length TYPE i.
    DATA lv_block TYPE xstring.
    DATA lv_patch TYPE xstring.

    IF iv_offset < 0.
      RAISE EXCEPTION TYPE cx_sy_range_out_of_bounds.
    ENDIF.

    lv_length = xstrlen( iv_data ).
    IF lv_length = 0.
      RETURN.
    ENDIF.

    lv_size = file_size( iv_name ).
    lv_end = iv_offset + lv_length.

    lv_blockno = iv_offset DIV c_block_size.
    WHILE lv_blockno * c_block_size < lv_end.
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
      put_block( iv_name = iv_name iv_blockno = lv_blockno iv_data = lv_block ).

      lv_blockno = lv_blockno + 1.
    ENDWHILE.

    IF lv_end > lv_size.
      put_file( iv_name = iv_name iv_size = lv_end ).
    ENDIF.
  ENDMETHOD.

  METHOD truncate_file.
    DATA lv_size TYPE i.
    DATA lv_keep TYPE i.
    DATA lv_blockno TYPE i.
    DATA lv_block TYPE xstring.

    IF iv_size < 0.
      RAISE EXCEPTION TYPE cx_sy_range_out_of_bounds.
    ENDIF.

    lv_size = file_size( iv_name ).
    IF iv_size < lv_size.
      lv_blockno = iv_size DIV c_block_size.
      lv_keep = iv_size MOD c_block_size.
      IF lv_keep = 0.
        DELETE mt_blocks WHERE name = iv_name AND blockno >= lv_blockno.
      ELSE.
        lv_block = get_block( iv_name = iv_name iv_blockno = lv_blockno ).
        lv_block = lv_block+0(lv_keep) && zero_bytes( c_block_size - lv_keep ).
        put_block( iv_name = iv_name iv_blockno = lv_blockno iv_data = lv_block ).
        DELETE mt_blocks WHERE name = iv_name AND blockno > lv_blockno.
      ENDIF.
    ENDIF.

    put_file( iv_name = iv_name iv_size = iv_size ).
  ENDMETHOD.

  METHOD file_size.
    DATA ls_file TYPE ty_file.

    READ TABLE mt_files INTO ls_file WITH KEY name = iv_name.
    IF sy-subrc = 0.
      rv_size = ls_file-size.
    ENDIF.
  ENDMETHOD.

  METHOD zero_bytes.
    IF iv_count > 0.
      rv_zeros = repeat( val = '00' occ = iv_count ).
    ENDIF.
  ENDMETHOD.

  METHOD get_block.
    DATA ls_block TYPE ty_block.

    READ TABLE mt_blocks INTO ls_block WITH KEY name = iv_name blockno = iv_blockno.
    IF sy-subrc = 0.
      rv_data = ls_block-data.
    ELSE.
      rv_data = zero_bytes( c_block_size ).
    ENDIF.
  ENDMETHOD.

  METHOD put_block.
    DATA ls_block TYPE ty_block.

    ls_block-name = iv_name.
    ls_block-blockno = iv_blockno.
    ls_block-data = iv_data.

    READ TABLE mt_blocks TRANSPORTING NO FIELDS WITH KEY name = iv_name blockno = iv_blockno.
    IF sy-subrc = 0.
* ANORMALY: MODIFY TABLE on a hashed table updates by full row content in the
* transpiler, not by the table key, so replace the row explicitly.
      DELETE mt_blocks WHERE name = iv_name AND blockno = iv_blockno.
    ENDIF.
    INSERT ls_block INTO TABLE mt_blocks.
  ENDMETHOD.

  METHOD put_file.
    DATA ls_file TYPE ty_file.
    DATA lv_found TYPE abap_bool.

    READ TABLE mt_files INTO ls_file WITH KEY name = iv_name.
    lv_found = boolc( sy-subrc = 0 ).
    ls_file-name = iv_name.
    ls_file-size = iv_size.
* ANORMALY: MODIFY TABLE on a hashed table updates by full row content in the
* transpiler, not by the table key, so replace the row explicitly.
    IF lv_found = abap_true.
      DELETE mt_files WHERE name = iv_name.
    ENDIF.
    INSERT ls_file INTO TABLE mt_files.
  ENDMETHOD.

  METHOD patch_block.
    DATA lv_after_pos TYPE i.
    DATA lv_after_length TYPE i.
    DATA lv_before TYPE xstring.
    DATA lv_after TYPE xstring.
    DATA lv_size TYPE i.

    lv_size = xstrlen( iv_block ).
    IF iv_pos > 0.
      lv_before = iv_block+0(iv_pos).
    ENDIF.

    lv_after_pos = iv_pos + xstrlen( iv_data ).
    IF lv_after_pos < lv_size.
      lv_after_length = lv_size - lv_after_pos.
      lv_after = iv_block+lv_after_pos(lv_after_length).
    ENDIF.

    rv_block = lv_before && iv_data && lv_after.
  ENDMETHOD.

ENDCLASS.
