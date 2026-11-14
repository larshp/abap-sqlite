CLASS zcl_sqlite_files DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
* the block size equals the page size, see PLAN.md D2
    CONSTANTS c_min_block_size TYPE i VALUE 512.
    CONSTANTS c_default_block_size TYPE i VALUE 4096.
    CONSTANTS c_max_block_size TYPE i VALUE 65536.

    TYPES ty_blocks TYPE STANDARD TABLE OF zsqlite_files WITH DEFAULT KEY.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_sqlite_files IMPLEMENTATION.
ENDCLASS.
