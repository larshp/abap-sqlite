INTERFACE zif_sqlite_file
  PUBLIC.

* A file handle. Offsets and sizes are in bytes and use TYPE i, so a file is
* limited to 2 GB. That matches XSTRLEN( ) and the INT4 block number in
* ZSQLITE_FILES.
*
* read returns exactly iv_amount bytes. Bytes past the end of the file are
* zero, and short is true when the file did not contain all of them.
*
* write zero-fills a gap when the offset is beyond the current end.
* truncate extends the file with zeros when the new size is larger.

  TYPES: BEGIN OF ty_read_result,
           data  TYPE xstring,
           short TYPE abap_bool,
         END OF ty_read_result.

* SQLite lock levels, ordered like the SQLite ones
  CONSTANTS c_lock_none TYPE i VALUE 0.
  CONSTANTS c_lock_shared TYPE i VALUE 1.
  CONSTANTS c_lock_reserved TYPE i VALUE 2.
  CONSTANTS c_lock_pending TYPE i VALUE 3.
  CONSTANTS c_lock_exclusive TYPE i VALUE 4.

  METHODS read
    IMPORTING iv_offset        TYPE i
              iv_amount        TYPE i
    RETURNING VALUE(rs_result) TYPE ty_read_result
    RAISING   cx_sy_range_out_of_bounds.

  METHODS write
    IMPORTING iv_offset TYPE i
              iv_data   TYPE xstring
    RAISING   cx_sy_range_out_of_bounds.

  METHODS truncate
    IMPORTING iv_size TYPE i
    RAISING   cx_sy_range_out_of_bounds.

  METHODS size
    RETURNING VALUE(rv_size) TYPE i.

  METHODS sync.

  METHODS lock
    IMPORTING iv_level TYPE i.

  METHODS unlock
    IMPORTING iv_level TYPE i.

  METHODS close.

ENDINTERFACE.
