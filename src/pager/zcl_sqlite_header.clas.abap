* The first 100 bytes of an SQLite database file, see
* https://www.sqlite.org/fileformat.html#the_database_header
CLASS zcl_sqlite_header DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS c_header_size TYPE i VALUE 100.
    CONSTANTS c_magic TYPE xstring VALUE '53514C69746520666F726D6174203300'.

    CONSTANTS c_encoding_utf8 TYPE int8 VALUE 1.
    CONSTANTS c_encoding_utf16le TYPE int8 VALUE 2.
    CONSTANTS c_encoding_utf16be TYPE int8 VALUE 3.

    TYPES: BEGIN OF ty_header,
             page_size             TYPE int8,
             write_version         TYPE int8,
             read_version          TYPE int8,
             reserved_bytes        TYPE int8,
             max_payload_fraction  TYPE int8,
             min_payload_fraction  TYPE int8,
             leaf_payload_fraction TYPE int8,
             change_counter        TYPE int8,
             database_size         TYPE int8,
             freelist_trunk        TYPE int8,
             freelist_pages        TYPE int8,
             schema_cookie         TYPE int8,
             schema_format         TYPE int8,
             default_cache_size    TYPE int8,
             largest_root_page     TYPE int8,
             text_encoding         TYPE int8,
             user_version          TYPE int8,
             incremental_vacuum    TYPE int8,
             application_id        TYPE int8,
             version_valid_for     TYPE int8,
             sqlite_version        TYPE int8,
           END OF ty_header.

    CLASS-METHODS parse
      IMPORTING iv_data          TYPE xstring
      RETURNING VALUE(rs_header) TYPE ty_header
      RAISING   zcx_sqlite_error.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS fail
      IMPORTING iv_code    TYPE i
                iv_message TYPE string
      RAISING   zcx_sqlite_error.
ENDCLASS.


CLASS zcl_sqlite_header IMPLEMENTATION.

  METHOD parse.
    DATA lv_length TYPE i.
    DATA lv_page_size TYPE int8.
    DATA lv_power TYPE int8.

    lv_length = xstrlen( iv_data ).
    IF lv_length < c_header_size.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite header is shorter than 100 bytes' ).
    ENDIF.
    IF iv_data+0(16) <> c_magic.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite header magic is invalid' ).
    ENDIF.

    TRY.
        lv_page_size = zcl_sqlite_bytes=>read_u16( iv_data = iv_data iv_offset = 16 ).
        IF lv_page_size = 1.
          rs_header-page_size = 65536.
        ELSE.
          rs_header-page_size = lv_page_size.
        ENDIF.

        rs_header-write_version =
          zcl_sqlite_bytes=>read_u8( iv_data = iv_data iv_offset = 18 ).
        rs_header-read_version =
          zcl_sqlite_bytes=>read_u8( iv_data = iv_data iv_offset = 19 ).
        rs_header-reserved_bytes =
          zcl_sqlite_bytes=>read_u8( iv_data = iv_data iv_offset = 20 ).
        rs_header-max_payload_fraction =
          zcl_sqlite_bytes=>read_u8( iv_data = iv_data iv_offset = 21 ).
        rs_header-min_payload_fraction =
          zcl_sqlite_bytes=>read_u8( iv_data = iv_data iv_offset = 22 ).
        rs_header-leaf_payload_fraction =
          zcl_sqlite_bytes=>read_u8( iv_data = iv_data iv_offset = 23 ).
        rs_header-change_counter =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 24 ).
        rs_header-database_size =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 28 ).
        rs_header-freelist_trunk =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 32 ).
        rs_header-freelist_pages =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 36 ).
        rs_header-schema_cookie =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 40 ).
        rs_header-schema_format =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 44 ).
        rs_header-default_cache_size =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 48 ).
        rs_header-largest_root_page =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 52 ).
        rs_header-text_encoding =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 56 ).
        rs_header-user_version =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 60 ).
        rs_header-incremental_vacuum =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 64 ).
        rs_header-application_id =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 68 ).
        rs_header-version_valid_for =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 92 ).
        rs_header-sqlite_version =
          zcl_sqlite_bytes=>read_u32( iv_data = iv_data iv_offset = 96 ).
      CATCH cx_sy_range_out_of_bounds.
        fail( iv_code = zcx_sqlite_error=>sqlite_notadb
              iv_message = 'SQLite header is shorter than 100 bytes' ).
    ENDTRY.

    IF rs_header-page_size < 512 OR rs_header-page_size > 65536.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite page size is outside 512..65536' ).
    ENDIF.
    lv_power = 512.
    WHILE lv_power < rs_header-page_size.
      lv_power = lv_power * 2.
    ENDWHILE.
    IF lv_power <> rs_header-page_size.
      fail( iv_code = zcx_sqlite_error=>sqlite_notadb
            iv_message = 'SQLite page size is not a power of two' ).
    ENDIF.

    IF rs_header-write_version <> 1 AND rs_header-write_version <> 2.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite write version is invalid' ).
    ENDIF.
    IF rs_header-read_version <> 1 AND rs_header-read_version <> 2.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite read version is invalid' ).
    ENDIF.
    IF rs_header-max_payload_fraction <> 64
        OR rs_header-min_payload_fraction <> 32
        OR rs_header-leaf_payload_fraction <> 32.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite payload fractions are invalid' ).
    ENDIF.
    IF rs_header-schema_format > 4.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite schema format is invalid' ).
    ENDIF.
    IF rs_header-text_encoding > 3.
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite text encoding is invalid' ).
    ENDIF.
    IF ( rs_header-freelist_trunk = 0 AND rs_header-freelist_pages <> 0 )
        OR ( rs_header-freelist_trunk <> 0 AND rs_header-freelist_pages = 0 ).
      fail( iv_code = zcx_sqlite_error=>sqlite_corrupt
            iv_message = 'SQLite freelist header is inconsistent' ).
    ENDIF.
  ENDMETHOD.

  METHOD fail.
    RAISE EXCEPTION TYPE zcx_sqlite_error
      EXPORTING
        iv_code    = iv_code
        iv_message = iv_message.
  ENDMETHOD.

ENDCLASS.
