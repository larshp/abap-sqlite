* Helpers for b-tree cell payloads, see
* https://www.sqlite.org/fileformat.html#b_tree_pages
CLASS zcl_sqlite_btree DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_min_usable_size TYPE int8 VALUE 480.
    CONSTANTS c_max_usable_size TYPE int8 VALUE 65536.

    CLASS-METHODS local_payload_size
      IMPORTING iv_payload_size      TYPE int8
                iv_usable_size       TYPE i
                iv_table_leaf        TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rv_local_size) TYPE int8
      RAISING   zcx_sqlite_error.

    CLASS-METHODS read_payload
      IMPORTING io_pager          TYPE REF TO zcl_sqlite_pager
                iv_page_data      TYPE xstring
                iv_payload_offset TYPE i
                iv_payload_size   TYPE int8
                iv_usable_size    TYPE i
                iv_table_leaf     TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rv_payload) TYPE xstring
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS fail
      IMPORTING iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_btree IMPLEMENTATION.

  METHOD local_payload_size.
    DATA lv_usable TYPE int8.
    DATA lv_max_local TYPE int8.
    DATA lv_min_local TYPE int8.
    DATA lv_k TYPE int8.

    IF iv_usable_size < c_min_usable_size
        OR iv_usable_size > c_max_usable_size.
      fail( 'usable page size is outside 480..65536' ).
    ENDIF.
    IF iv_payload_size < 0.
      fail( 'payload size is negative' ).
    ENDIF.

* the formulas are from the payload overflow section of the file format
    lv_usable = iv_usable_size.
    IF iv_table_leaf = abap_true.
      lv_max_local = lv_usable - 35.
    ELSE.
      lv_max_local = ( ( lv_usable - 12 ) * 64 ) DIV 255 - 23.
    ENDIF.
    lv_min_local = ( ( lv_usable - 12 ) * 32 ) DIV 255 - 23.

    IF iv_payload_size <= lv_max_local.
      rv_local_size = iv_payload_size.
      RETURN.
    ENDIF.

    lv_k = lv_min_local
         + ( ( iv_payload_size - lv_min_local ) MOD ( lv_usable - 4 ) ).
    IF lv_k <= lv_max_local.
      rv_local_size = lv_k.
    ELSE.
      rv_local_size = lv_min_local.
    ENDIF.
  ENDMETHOD.

  METHOD read_payload.
    DATA lv_local_size TYPE int8.
    DATA lv_local_length TYPE i.
    DATA lv_pointer_offset TYPE i.
    DATA lv_remaining TYPE int8.
    DATA lv_next_page_i8 TYPE int8.
    DATA lv_next_page TYPE i.
    DATA lv_page_count TYPE i.
    DATA lv_iterations TYPE i.
    DATA lv_max_chunk TYPE int8.
    DATA lv_chunk_size TYPE int8.
    DATA lv_chunk_length TYPE i.
    DATA lv_page TYPE zcl_sqlite_pager=>ty_page.
    DATA lv_chunk TYPE xstring.

    IF io_pager IS NOT BOUND.
      fail( 'payload reader needs a pager' ).
    ENDIF.
    IF iv_payload_offset < 0.
      fail( 'payload offset is negative' ).
    ENDIF.
    IF iv_payload_offset > xstrlen( iv_page_data ).
      fail( 'payload offset is outside the page' ).
    ENDIF.

    lv_local_size = local_payload_size(
      iv_payload_size = iv_payload_size
      iv_usable_size = iv_usable_size
      iv_table_leaf = iv_table_leaf ).
    lv_local_length = lv_local_size.

    IF iv_payload_offset + lv_local_length > xstrlen( iv_page_data ).
      fail( 'local payload is truncated' ).
    ENDIF.
    rv_payload = iv_page_data+iv_payload_offset(lv_local_length).

    IF iv_payload_size <= lv_local_size.
      RETURN.
    ENDIF.

    lv_pointer_offset = iv_payload_offset + lv_local_length.
    IF lv_pointer_offset + 4 > xstrlen( iv_page_data ).
      fail( 'overflow page pointer is truncated' ).
    ENDIF.
    TRY.
        lv_next_page_i8 = zcl_sqlite_bytes=>read_u32(
          iv_data = iv_page_data iv_offset = lv_pointer_offset ).
      CATCH cx_sy_range_out_of_bounds.
        fail( 'overflow page pointer is truncated' ).
    ENDTRY.

    lv_remaining = iv_payload_size - lv_local_size.
    lv_max_chunk = iv_usable_size - 4.
    lv_page_count = io_pager->page_count( ).

    WHILE lv_remaining > 0.
      lv_iterations = lv_iterations + 1.
      IF lv_iterations > lv_page_count.
        fail( 'overflow chain is too long' ).
      ENDIF.
      IF lv_next_page_i8 < 1 OR lv_next_page_i8 > lv_page_count.
        fail( 'overflow chain points outside the file' ).
      ENDIF.
      lv_next_page = lv_next_page_i8.

      lv_page = io_pager->get_page( lv_next_page ).
      IF xstrlen( lv_page-data ) < iv_usable_size.
        fail( 'overflow page is shorter than the usable page size' ).
      ENDIF.
      TRY.
          lv_next_page_i8 = zcl_sqlite_bytes=>read_u32(
            iv_data = lv_page-data iv_offset = 0 ).
        CATCH cx_sy_range_out_of_bounds.
          fail( 'overflow page pointer is truncated' ).
      ENDTRY.

      IF lv_remaining < lv_max_chunk.
        lv_chunk_size = lv_remaining.
      ELSE.
        lv_chunk_size = lv_max_chunk.
      ENDIF.
      lv_chunk_length = lv_chunk_size.
      lv_chunk = lv_page-data+4(lv_chunk_length).
      rv_payload = rv_payload && lv_chunk.
      lv_remaining = lv_remaining - lv_chunk_size.
    ENDWHILE.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = zcx_sqlite_error=>sqlite_corrupt
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
