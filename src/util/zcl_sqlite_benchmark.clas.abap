CLASS zcl_sqlite_benchmark DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
* baseline for Phase 8, see README.md
    CONSTANTS c_slices TYPE i VALUE 10000.
    CONSTANTS c_rows TYPE i VALUE 1000.
    CONSTANTS c_block_size TYPE i VALUE 512.
    CONSTANTS c_filename TYPE string VALUE 'benchmark/m0_7.db'.

    TYPES: BEGIN OF ty_result,
             slice_count TYPE i,
             slice_us    TYPE i,
             write_count TYPE i,
             write_us    TYPE i,
             read_count  TYPE i,
             read_us     TYPE i,
           END OF ty_result.

    CLASS-METHODS run
      RETURNING VALUE(rs_result) TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS build_block
      IMPORTING iv_size        TYPE i
      RETURNING VALUE(rv_data) TYPE xstring.

    CLASS-METHODS build_rows
      RETURNING VALUE(rt_rows) TYPE zcl_sqlite_files=>ty_blocks.
ENDCLASS.


CLASS zcl_sqlite_benchmark IMPLEMENTATION.

  METHOD run.
    DATA lv_start TYPE i.
    DATA lv_end TYPE i.
    DATA lv_data TYPE xstring.
    DATA lv_slice TYPE xstring.
    DATA lv_index TYPE i.
    DATA lv_length TYPE i.
    DATA lt_rows TYPE zcl_sqlite_files=>ty_blocks.
    DATA lt_read TYPE zcl_sqlite_files=>ty_blocks.

    lv_data = build_block( 16 ).

    GET RUN TIME FIELD lv_start.
    DO c_slices TIMES.
      lv_index = sy-index MOD 13.
      lv_slice = lv_data+lv_index(4).
      lv_length = lv_length + xstrlen( lv_slice ).
    ENDDO.
    GET RUN TIME FIELD lv_end.
    rs_result-slice_count = c_slices.
    rs_result-slice_us = lv_end - lv_start.

* start from a clean file
    DELETE FROM zsqlite_files WHERE filename = @c_filename.
    COMMIT WORK.

    lt_rows = build_rows( ).

    GET RUN TIME FIELD lv_start.
    MODIFY zsqlite_files FROM TABLE @lt_rows.
    GET RUN TIME FIELD lv_end.
    rs_result-write_count = sy-dbcnt.
    rs_result-write_us = lv_end - lv_start.

    COMMIT WORK.

    GET RUN TIME FIELD lv_start.
    SELECT mandt, filename, blockno, data FROM zsqlite_files INTO TABLE @lt_read
      WHERE mandt = @sy-mandt AND filename = @c_filename
      ORDER BY blockno.
    GET RUN TIME FIELD lv_end.
    rs_result-read_count = lines( lt_read ).
    rs_result-read_us = lv_end - lv_start.

    DELETE FROM zsqlite_files WHERE filename = @c_filename.
    COMMIT WORK.
  ENDMETHOD.

  METHOD build_block.
    CONSTANTS c_pattern TYPE xstring VALUE '00112233445566778899AABBCCDDEEFF'.
    rv_data = c_pattern.
    WHILE xstrlen( rv_data ) < iv_size.
      rv_data = rv_data && rv_data.
    ENDWHILE.
    rv_data = rv_data+0(iv_size).
  ENDMETHOD.

  METHOD build_rows.
    DATA ls_row TYPE zsqlite_files.
    DATA lv_data TYPE xstring.

    lv_data = build_block( c_block_size ).

    DO c_rows TIMES.
      ls_row-mandt = sy-mandt.
      ls_row-filename = c_filename.
      ls_row-blockno = sy-index - 1.
      ls_row-data = lv_data.
      APPEND ls_row TO rt_rows.
    ENDDO.
  ENDMETHOD.

ENDCLASS.
