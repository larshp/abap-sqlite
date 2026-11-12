* Table, column and index metadata built from the SQL in sqlite_schema.
*
* Column affinity follows the SQLite type-name rules. The catalog mirrors the
* information exposed by PRAGMA table_info, index_list and index_info, with a
* few extra fields used by the planner (type name, affinity and rowid alias).
CLASS zcl_sqlite_schema DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      c_affinity_integer TYPE string VALUE 'INTEGER',
      c_affinity_text    TYPE string VALUE 'TEXT',
      c_affinity_blob    TYPE string VALUE 'BLOB',
      c_affinity_real    TYPE string VALUE 'REAL',
      c_affinity_numeric TYPE string VALUE 'NUMERIC'.

    TYPES:
      BEGIN OF ty_column,
        cid                TYPE i,
        name               TYPE string,
        type               TYPE string,
        notnull            TYPE abap_bool,
        dflt_value         TYPE string,
        dflt_value_is_null TYPE abap_bool,
        pk                 TYPE i,
        affinity           TYPE string,
        rowid_alias        TYPE abap_bool,
      END OF ty_column,
      ty_columns TYPE STANDARD TABLE OF ty_column WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_index_column,
        seqno TYPE i,
        cid   TYPE i,
        name  TYPE string,
      END OF ty_index_column,
      ty_index_columns TYPE STANDARD TABLE OF ty_index_column WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_index,
        seq       TYPE i,
        name      TYPE string,
        tbl_name  TYPE string,
        rootpage  TYPE int8,
        is_unique TYPE abap_bool,
        origin    TYPE string,
        partial   TYPE abap_bool,
        columns   TYPE ty_index_columns,
      END OF ty_index,
      ty_indexes TYPE STANDARD TABLE OF ty_index WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_table,
        name          TYPE string,
        rootpage      TYPE int8,
        without_rowid TYPE abap_bool,
        strict        TYPE abap_bool,
        columns       TYPE ty_columns,
        indexes       TYPE ty_indexes,
      END OF ty_table,
      ty_tables TYPE STANDARD TABLE OF ty_table WITH DEFAULT KEY.

    CLASS-METHODS read
      IMPORTING io_pager         TYPE REF TO zcl_sqlite_pager
      RETURNING VALUE(ro_schema) TYPE REF TO zcl_sqlite_schema
      RAISING   zcx_sqlite_error.

    CLASS-METHODS build
      IMPORTING it_entries       TYPE zcl_sqlite_catalog=>ty_entries
      RETURNING VALUE(ro_schema) TYPE REF TO zcl_sqlite_schema
      RAISING   zcx_sqlite_error.

    CLASS-METHODS affinity_of
      IMPORTING iv_type_name       TYPE string
      RETURNING VALUE(rv_affinity) TYPE string.

    METHODS tables
      RETURNING VALUE(rt_tables) TYPE ty_tables.

    METHODS table
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rs_table) TYPE ty_table.

    METHODS indexes
      RETURNING VALUE(rt_indexes) TYPE ty_indexes.

    METHODS index
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rs_index) TYPE ty_index.

    METHODS indexes_for_table
      IMPORTING iv_name           TYPE string
      RETURNING VALUE(rt_indexes) TYPE ty_indexes.

    METHODS indexes_in_definition_order
      IMPORTING iv_name           TYPE string
      RETURNING VALUE(rt_indexes) TYPE ty_indexes.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_primary_key,
        found       TYPE abap_bool,
        from_column TYPE abap_bool,
        order       TYPE string,
        names       TYPE zcl_sqlite_ast_node=>ty_names,
      END OF ty_primary_key.

    DATA mt_tables  TYPE ty_tables.
    DATA mt_indexes TYPE ty_indexes.

    METHODS add_table
      IMPORTING is_entry     TYPE zcl_sqlite_catalog=>ty_entry
                io_statement TYPE REF TO zcl_sqlite_ast_create_table
                it_entries   TYPE zcl_sqlite_catalog=>ty_entries
      RAISING   zcx_sqlite_error.

    METHODS add_index
      IMPORTING is_entry     TYPE zcl_sqlite_catalog=>ty_entry
                io_statement TYPE REF TO zcl_sqlite_ast_create_index.

    METHODS finish.

    METHODS build_columns
      IMPORTING io_statement      TYPE REF TO zcl_sqlite_ast_create_table
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS find_primary_key
      IMPORTING io_statement TYPE REF TO zcl_sqlite_ast_create_table
      RETURNING VALUE(rs_pk) TYPE ty_primary_key.

    METHODS apply_primary_key
      IMPORTING is_pk             TYPE ty_primary_key
                it_pk_names       TYPE zcl_sqlite_ast_node=>ty_names
                it_columns        TYPE ty_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS rowid_alias_of
      IMPORTING is_pk                 TYPE ty_primary_key
                it_columns            TYPE ty_columns
                iv_without_rowid      TYPE abap_bool
      RETURNING VALUE(rv_rowid_alias) TYPE abap_bool.

    METHODS mark_rowid_alias
      IMPORTING it_pk_names       TYPE zcl_sqlite_ast_node=>ty_names
                it_columns        TYPE ty_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS apply_pk_not_null
      IMPORTING it_pk_names       TYPE zcl_sqlite_ast_node=>ty_names
                it_columns        TYPE ty_columns
      RETURNING VALUE(rt_columns) TYPE ty_columns.

    METHODS add_autoindexes
      IMPORTING io_statement     TYPE REF TO zcl_sqlite_ast_create_table
                iv_table_name    TYPE string
                it_table_columns TYPE ty_columns
                iv_rowid_alias   TYPE abap_bool
                it_entries       TYPE zcl_sqlite_catalog=>ty_entries.

    METHODS append_autoindex
      IMPORTING iv_counter        TYPE i
                iv_table_name     TYPE string
                it_table_columns  TYPE ty_columns
                it_names          TYPE zcl_sqlite_ast_node=>ty_names
                iv_origin         TYPE string
                it_entries        TYPE zcl_sqlite_catalog=>ty_entries
      RETURNING VALUE(rv_counter) TYPE i.

    METHODS indexed_column_names
      IMPORTING it_columns      TYPE zcl_sqlite_ast_constraint=>ty_indexed_columns
      RETURNING VALUE(rt_names) TYPE zcl_sqlite_ast_node=>ty_names.

    METHODS column_cid
      IMPORTING it_columns    TYPE ty_columns
                iv_name       TYPE string
      RETURNING VALUE(rv_cid) TYPE i.

    METHODS table_tabix
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rv_tabix) TYPE i.

    METHODS find_duplicate_index
      IMPORTING iv_table_name   TYPE string
                it_columns      TYPE ty_index_columns
      RETURNING VALUE(rv_tabix) TYPE i.

    METHODS index_signature
      IMPORTING it_columns          TYPE ty_index_columns
      RETURNING VALUE(rv_signature) TYPE string.

    METHODS rootpage_of
      IMPORTING it_entries         TYPE zcl_sqlite_catalog=>ty_entries
                iv_name            TYPE string
      RETURNING VALUE(rv_rootpage) TYPE int8.

    CLASS-METHODS is_sqlite_internal
      IMPORTING iv_name          TYPE string
      RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS default_text
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_text) TYPE string.

    METHODS expression_text
      IMPORTING io_expression  TYPE REF TO zcl_sqlite_ast_node
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_sqlite_schema IMPLEMENTATION.

  METHOD read.
    DATA lt_entries TYPE zcl_sqlite_catalog=>ty_entries.

    lt_entries = zcl_sqlite_catalog=>read( io_pager ).
    ro_schema = build( lt_entries ).
  ENDMETHOD.

  METHOD build.
    DATA ls_entry TYPE zcl_sqlite_catalog=>ty_entry.
    DATA lo_statement TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_create_table TYPE REF TO zcl_sqlite_ast_create_table.
    DATA lo_create_index TYPE REF TO zcl_sqlite_ast_create_index.

    ro_schema = NEW zcl_sqlite_schema( ).

    LOOP AT it_entries INTO ls_entry.
      CASE ls_entry-type.
        WHEN 'table'.
          IF ls_entry-sql_is_null = abap_false
              AND is_sqlite_internal( ls_entry-name ) = abap_false.
            lo_statement = zcl_sqlite_parser=>parse_statement( ls_entry-sql ).
            IF lo_statement IS INSTANCE OF zcl_sqlite_ast_create_table.
              lo_create_table ?= lo_statement.
              ro_schema->add_table(
                is_entry     = ls_entry
                io_statement = lo_create_table
                it_entries   = it_entries ).
            ENDIF.
          ENDIF.
        WHEN 'index'.
          IF ls_entry-sql_is_null = abap_false.
            lo_statement = zcl_sqlite_parser=>parse_statement( ls_entry-sql ).
            IF lo_statement IS INSTANCE OF zcl_sqlite_ast_create_index.
              lo_create_index ?= lo_statement.
              ro_schema->add_index(
                is_entry     = ls_entry
                io_statement = lo_create_index ).
            ENDIF.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    ro_schema->finish( ).
  ENDMETHOD.

  METHOD affinity_of.
    DATA lv_type TYPE string.
    DATA lv_count TYPE i.

    lv_type = to_upper( iv_type_name ).

    FIND 'INT' IN lv_type MATCH COUNT lv_count.
    IF lv_count > 0.
      rv_affinity = c_affinity_integer.
      RETURN.
    ENDIF.

    FIND 'CHAR' IN lv_type MATCH COUNT lv_count.
    IF lv_count = 0.
      FIND 'CLOB' IN lv_type MATCH COUNT lv_count.
    ENDIF.
    IF lv_count = 0.
      FIND 'TEXT' IN lv_type MATCH COUNT lv_count.
    ENDIF.
    IF lv_count > 0.
      rv_affinity = c_affinity_text.
      RETURN.
    ENDIF.

    IF lv_type IS INITIAL.
      rv_affinity = c_affinity_blob.
      RETURN.
    ENDIF.
    FIND 'BLOB' IN lv_type MATCH COUNT lv_count.
    IF lv_count > 0.
      rv_affinity = c_affinity_blob.
      RETURN.
    ENDIF.

    FIND 'REAL' IN lv_type MATCH COUNT lv_count.
    IF lv_count = 0.
      FIND 'FLOA' IN lv_type MATCH COUNT lv_count.
    ENDIF.
    IF lv_count = 0.
      FIND 'DOUB' IN lv_type MATCH COUNT lv_count.
    ENDIF.
    IF lv_count > 0.
      rv_affinity = c_affinity_real.
      RETURN.
    ENDIF.

    rv_affinity = c_affinity_numeric.
  ENDMETHOD.

  METHOD tables.
    rt_tables = mt_tables.
  ENDMETHOD.

  METHOD table.
    DATA lv_tabix TYPE i.

    lv_tabix = table_tabix( iv_name ).
    IF lv_tabix > 0.
      READ TABLE mt_tables INTO rs_table INDEX lv_tabix.
    ENDIF.
  ENDMETHOD.

  METHOD indexes.
    rt_indexes = mt_indexes.
  ENDMETHOD.

  METHOD index.
    DATA ls_index TYPE ty_index.

    LOOP AT mt_indexes INTO ls_index.
      IF to_upper( ls_index-name ) = to_upper( iv_name ).
        rs_index = ls_index.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD indexes_for_table.
    DATA ls_table TYPE ty_table.

    ls_table = table( iv_name ).
    rt_indexes = ls_table-indexes.
  ENDMETHOD.

  METHOD indexes_in_definition_order.
    DATA ls_index TYPE ty_index.

    LOOP AT mt_indexes INTO ls_index.
      IF to_upper( ls_index-tbl_name ) = to_upper( iv_name ).
        APPEND ls_index TO rt_indexes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_table.
    DATA ls_table TYPE ty_table.
    DATA ls_pk TYPE ty_primary_key.
    DATA lv_rowid_alias TYPE abap_bool.

    ls_table-name = is_entry-name.
    ls_table-rootpage = is_entry-rootpage.
    ls_table-without_rowid = io_statement->is_without_rowid( ).
    ls_table-strict = io_statement->is_strict( ).
    ls_table-columns = build_columns( io_statement ).

    ls_pk = find_primary_key( io_statement ).
    ls_table-columns = apply_primary_key(
      is_pk       = ls_pk
      it_pk_names = ls_pk-names
      it_columns  = ls_table-columns ).

    lv_rowid_alias = rowid_alias_of(
      is_pk            = ls_pk
      it_columns       = ls_table-columns
      iv_without_rowid = ls_table-without_rowid ).
    IF lv_rowid_alias = abap_true.
      ls_table-columns = mark_rowid_alias(
        it_pk_names = ls_pk-names
        it_columns  = ls_table-columns ).
    ENDIF.

    IF ls_table-without_rowid = abap_true OR ls_table-strict = abap_true.
      ls_table-columns = apply_pk_not_null(
        it_pk_names = ls_pk-names
        it_columns  = ls_table-columns ).
    ENDIF.

    add_autoindexes(
      io_statement     = io_statement
      iv_table_name    = ls_table-name
      it_table_columns = ls_table-columns
      iv_rowid_alias   = lv_rowid_alias
      it_entries       = it_entries ).

    APPEND ls_table TO mt_tables.
  ENDMETHOD.

  METHOD build_columns.
    DATA ls_column TYPE ty_column.
    DATA lt_columns TYPE zcl_sqlite_ast_create_table=>ty_columns.
    DATA lt_column_constraints TYPE zcl_sqlite_ast_column_def=>ty_constraints.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_column_def.
    DATA lo_constraint TYPE REF TO zcl_sqlite_ast_constraint.

    lt_columns = io_statement->get_columns( ).
    LOOP AT lt_columns INTO lo_column.
      CLEAR ls_column.
      ls_column-cid = sy-tabix - 1.
      ls_column-name = lo_column->get_name( ).
      ls_column-type = lo_column->get_type_name( ).
      ls_column-affinity = affinity_of( ls_column-type ).
      ls_column-dflt_value_is_null = abap_true.

      lt_column_constraints = lo_column->get_constraints( ).
      LOOP AT lt_column_constraints INTO lo_constraint.
        CASE lo_constraint->get_kind( ).
          WHEN 'NOT NULL'.
            ls_column-notnull = abap_true.
          WHEN 'DEFAULT'.
            ls_column-dflt_value_is_null = abap_false.
            ls_column-dflt_value = default_text( lo_constraint->get_expression( ) ).
        ENDCASE.
      ENDLOOP.

      APPEND ls_column TO rt_columns.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_primary_key.
    DATA lt_columns TYPE zcl_sqlite_ast_create_table=>ty_columns.
    DATA lt_constraints TYPE zcl_sqlite_ast_create_table=>ty_constraints.
    DATA lt_column_constraints TYPE zcl_sqlite_ast_column_def=>ty_constraints.
    DATA lt_indexed TYPE zcl_sqlite_ast_constraint=>ty_indexed_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_column_def.
    DATA lo_constraint TYPE REF TO zcl_sqlite_ast_constraint.
    DATA lo_indexed TYPE REF TO zcl_sqlite_ast_indexed_column.

    lt_columns = io_statement->get_columns( ).
    LOOP AT lt_columns INTO lo_column.
      lt_column_constraints = lo_column->get_constraints( ).
      LOOP AT lt_column_constraints INTO lo_constraint.
        IF lo_constraint->get_kind( ) = 'PRIMARY KEY'
            AND rs_pk-found = abap_false.
          rs_pk-found = abap_true.
          rs_pk-from_column = abap_true.
          rs_pk-order = lo_constraint->get_order( ).
          APPEND lo_column->get_name( ) TO rs_pk-names.
        ENDIF.
      ENDLOOP.
      IF rs_pk-found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF rs_pk-found = abap_false.
      lt_constraints = io_statement->get_constraints( ).
      LOOP AT lt_constraints INTO lo_constraint.
        IF lo_constraint->get_kind( ) = 'PRIMARY KEY'.
          rs_pk-found = abap_true.
          rs_pk-from_column = abap_false.
          lt_indexed = lo_constraint->get_indexed_columns( ).
          LOOP AT lt_indexed INTO lo_indexed.
            APPEND lo_indexed->get_name( ) TO rs_pk-names.
          ENDLOOP.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD apply_primary_key.
    DATA ls_column TYPE ty_column.
    DATA lv_pk_name TYPE string.
    DATA lv_pk_ordinal TYPE i.
    DATA lv_cid TYPE i.
    DATA lv_tabix TYPE i.

    rt_columns = it_columns.
    LOOP AT it_pk_names INTO lv_pk_name.
      lv_pk_ordinal = sy-tabix.
      lv_cid = column_cid(
        it_columns = rt_columns
        iv_name    = lv_pk_name ).
      IF lv_cid >= 0.
        lv_tabix = lv_cid + 1.
        READ TABLE rt_columns INTO ls_column INDEX lv_tabix.
        ls_column-pk = lv_pk_ordinal.
        MODIFY rt_columns FROM ls_column INDEX lv_tabix.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD rowid_alias_of.
    DATA ls_column TYPE ty_column.
    DATA lv_pk_name TYPE string.
    DATA lv_cid TYPE i.
    DATA lv_tabix TYPE i.

    IF is_pk-found = abap_false
        OR lines( is_pk-names ) <> 1
        OR iv_without_rowid = abap_true.
      RETURN.
    ENDIF.

    READ TABLE is_pk-names INTO lv_pk_name INDEX 1.
    lv_cid = column_cid(
      it_columns = it_columns
      iv_name    = lv_pk_name ).
    IF lv_cid < 0.
      RETURN.
    ENDIF.

    lv_tabix = lv_cid + 1.
    READ TABLE it_columns INTO ls_column INDEX lv_tabix.
    IF to_upper( ls_column-type ) <> 'INTEGER'.
      RETURN.
    ENDIF.

    IF is_pk-from_column = abap_true
        AND to_upper( is_pk-order ) = 'DESC'.
      RETURN.
    ENDIF.

    rv_rowid_alias = abap_true.
  ENDMETHOD.

  METHOD mark_rowid_alias.
    DATA ls_column TYPE ty_column.
    DATA lv_pk_name TYPE string.
    DATA lv_cid TYPE i.
    DATA lv_tabix TYPE i.

    rt_columns = it_columns.
    LOOP AT it_pk_names INTO lv_pk_name.
      lv_cid = column_cid(
        it_columns = rt_columns
        iv_name    = lv_pk_name ).
      IF lv_cid >= 0.
        lv_tabix = lv_cid + 1.
        READ TABLE rt_columns INTO ls_column INDEX lv_tabix.
        ls_column-rowid_alias = abap_true.
        MODIFY rt_columns FROM ls_column INDEX lv_tabix.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD apply_pk_not_null.
    DATA ls_column TYPE ty_column.
    DATA lv_pk_name TYPE string.
    DATA lv_cid TYPE i.
    DATA lv_tabix TYPE i.

    rt_columns = it_columns.
    LOOP AT it_pk_names INTO lv_pk_name.
      lv_cid = column_cid(
        it_columns = rt_columns
        iv_name    = lv_pk_name ).
      IF lv_cid >= 0.
        lv_tabix = lv_cid + 1.
        READ TABLE rt_columns INTO ls_column INDEX lv_tabix.
        ls_column-notnull = abap_true.
        MODIFY rt_columns FROM ls_column INDEX lv_tabix.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_autoindexes.
    DATA lt_columns TYPE zcl_sqlite_ast_create_table=>ty_columns.
    DATA lt_constraints TYPE zcl_sqlite_ast_create_table=>ty_constraints.
    DATA lt_column_constraints TYPE zcl_sqlite_ast_column_def=>ty_constraints.
    DATA lt_indexed TYPE zcl_sqlite_ast_constraint=>ty_indexed_columns.
    DATA lt_names TYPE zcl_sqlite_ast_node=>ty_names.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_column_def.
    DATA lo_constraint TYPE REF TO zcl_sqlite_ast_constraint.
    DATA lv_counter TYPE i.
    DATA lv_pk_index_created TYPE abap_bool.

    lt_columns = io_statement->get_columns( ).
    lv_counter = 0.

* Auto-indexes are numbered in the order the constraints appear in the SQL.
* Column constraints come first, then table constraints.
    LOOP AT lt_columns INTO lo_column.
      lt_column_constraints = lo_column->get_constraints( ).
      LOOP AT lt_column_constraints INTO lo_constraint.
        CASE lo_constraint->get_kind( ).
          WHEN 'UNIQUE'.
            CLEAR lt_names.
            APPEND lo_column->get_name( ) TO lt_names.
            lv_counter = append_autoindex(
              iv_counter       = lv_counter
              iv_table_name    = iv_table_name
              it_table_columns = it_table_columns
              it_names         = lt_names
              iv_origin        = 'u'
              it_entries       = it_entries ).
          WHEN 'PRIMARY KEY'.
            IF iv_rowid_alias = abap_false
                AND lv_pk_index_created = abap_false.
              CLEAR lt_names.
              APPEND lo_column->get_name( ) TO lt_names.
              lv_counter = append_autoindex(
                iv_counter       = lv_counter
                iv_table_name    = iv_table_name
                it_table_columns = it_table_columns
                it_names         = lt_names
                iv_origin        = 'pk'
                it_entries       = it_entries ).
              lv_pk_index_created = abap_true.
            ENDIF.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.

    lt_constraints = io_statement->get_constraints( ).
    LOOP AT lt_constraints INTO lo_constraint.
      CASE lo_constraint->get_kind( ).
        WHEN 'UNIQUE'.
          lt_indexed = lo_constraint->get_indexed_columns( ).
          lt_names = indexed_column_names( lt_indexed ).
          lv_counter = append_autoindex(
            iv_counter       = lv_counter
            iv_table_name    = iv_table_name
            it_table_columns = it_table_columns
            it_names         = lt_names
            iv_origin        = 'u'
            it_entries       = it_entries ).
        WHEN 'PRIMARY KEY'.
          IF iv_rowid_alias = abap_false
              AND lv_pk_index_created = abap_false.
            lt_indexed = lo_constraint->get_indexed_columns( ).
            lt_names = indexed_column_names( lt_indexed ).
            lv_counter = append_autoindex(
              iv_counter       = lv_counter
              iv_table_name    = iv_table_name
              it_table_columns = it_table_columns
              it_names         = lt_names
              iv_origin        = 'pk'
              it_entries       = it_entries ).
            lv_pk_index_created = abap_true.
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_index.
    DATA ls_table TYPE ty_table.
    DATA ls_index TYPE ty_index.
    DATA ls_column TYPE ty_column.
    DATA ls_index_column TYPE ty_index_column.
    DATA lt_columns TYPE zcl_sqlite_ast_create_index=>ty_columns.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.
    DATA lo_where TYPE REF TO zcl_sqlite_ast_node.
    DATA lv_cid TYPE i.
    DATA lv_name TYPE string.
    DATA lv_tabix TYPE i.
    DATA lv_seqno TYPE i.

    ls_index-name = is_entry-name.
    ls_index-tbl_name = is_entry-tbl_name.
    ls_index-rootpage = is_entry-rootpage.
    ls_index-is_unique = io_statement->is_unique( ).
    ls_index-origin = 'c'.
    lo_where = io_statement->get_where( ).
    IF lo_where IS BOUND.
      ls_index-partial = abap_true.
    ENDIF.

    lv_tabix = table_tabix( is_entry-tbl_name ).
    IF lv_tabix > 0.
      READ TABLE mt_tables INTO ls_table INDEX lv_tabix.
    ENDIF.

    lt_columns = io_statement->get_columns( ).
    LOOP AT lt_columns INTO lo_column.
      lv_seqno = sy-tabix - 1.
      lv_name = lo_column->get_name( ).
      lv_cid = column_cid(
        it_columns = ls_table-columns
        iv_name    = lv_name ).

      CLEAR ls_index_column.
      ls_index_column-seqno = lv_seqno.
      ls_index_column-cid = lv_cid.
      IF lv_cid >= 0.
        lv_tabix = lv_cid + 1.
        READ TABLE ls_table-columns INTO ls_column INDEX lv_tabix.
        ls_index_column-name = ls_column-name.
      ELSE.
        ls_index_column-name = lv_name.
      ENDIF.
      APPEND ls_index_column TO ls_index-columns.
    ENDLOOP.

    APPEND ls_index TO mt_indexes.
  ENDMETHOD.

  METHOD finish.
    DATA ls_table TYPE ty_table.
    DATA ls_index TYPE ty_index.
    DATA lt_tables TYPE ty_tables.
    DATA lt_reversed TYPE ty_indexes.
    DATA lv_seq TYPE i.

    LOOP AT mt_tables INTO ls_table.
      CLEAR lt_reversed.
      LOOP AT mt_indexes INTO ls_index.
        IF ls_index-tbl_name = ls_table-name.
          INSERT ls_index INTO lt_reversed INDEX 1.
        ENDIF.
      ENDLOOP.

      CLEAR ls_table-indexes.
      lv_seq = 0.
      LOOP AT lt_reversed INTO ls_index.
        ls_index-seq = lv_seq.
        APPEND ls_index TO ls_table-indexes.
        lv_seq = lv_seq + 1.
      ENDLOOP.

      APPEND ls_table TO lt_tables.
    ENDLOOP.

    mt_tables = lt_tables.
  ENDMETHOD.

  METHOD append_autoindex.
    DATA ls_index TYPE ty_index.
    DATA ls_index_column TYPE ty_index_column.
    DATA ls_column TYPE ty_column.
    DATA ls_existing TYPE ty_index.
    DATA lv_name TYPE string.
    DATA lv_cid TYPE i.
    DATA lv_tabix TYPE i.
    DATA lv_position TYPE i.
    DATA lv_duplicate TYPE i.
    DATA lv_rootpage TYPE int8.

    rv_counter = iv_counter.
    IF lines( it_names ) = 0.
      RETURN.
    ENDIF.

    lv_tabix = 0.
    LOOP AT it_names INTO lv_name.
      lv_tabix = lv_tabix + 1.
      lv_cid = column_cid(
        it_columns = it_table_columns
        iv_name    = lv_name ).

      CLEAR ls_index_column.
      ls_index_column-seqno = lv_tabix - 1.
      ls_index_column-cid = lv_cid.
      IF lv_cid >= 0.
        lv_position = lv_cid + 1.
        READ TABLE it_table_columns INTO ls_column INDEX lv_position.
        ls_index_column-name = ls_column-name.
      ELSE.
        ls_index_column-name = lv_name.
      ENDIF.
      APPEND ls_index_column TO ls_index-columns.
    ENDLOOP.

    lv_duplicate = find_duplicate_index(
      iv_table_name = iv_table_name
      it_columns    = ls_index-columns ).

    IF lv_duplicate > 0.
* A primary key shares its index with an earlier UNIQUE constraint.
      IF iv_origin = 'pk'.
        READ TABLE mt_indexes INTO ls_existing INDEX lv_duplicate.
        IF ls_existing-origin = 'u'.
          ls_existing-origin = 'pk'.
          MODIFY mt_indexes FROM ls_existing INDEX lv_duplicate.
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    rv_counter = rv_counter + 1.
    ls_index-name = |sqlite_autoindex_{ iv_table_name }_{ rv_counter }|.
    ls_index-tbl_name = iv_table_name.
    ls_index-is_unique = abap_true.
    ls_index-origin = iv_origin.

    lv_rootpage = rootpage_of(
      it_entries = it_entries
      iv_name    = ls_index-name ).
    ls_index-rootpage = lv_rootpage.

    APPEND ls_index TO mt_indexes.
  ENDMETHOD.

  METHOD indexed_column_names.
    DATA lo_column TYPE REF TO zcl_sqlite_ast_indexed_column.

    LOOP AT it_columns INTO lo_column.
      APPEND lo_column->get_name( ) TO rt_names.
    ENDLOOP.
  ENDMETHOD.

  METHOD column_cid.
    DATA ls_column TYPE ty_column.

    rv_cid = -1.
    LOOP AT it_columns INTO ls_column.
      IF to_upper( ls_column-name ) = to_upper( iv_name ).
        rv_cid = ls_column-cid.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD table_tabix.
    DATA ls_table TYPE ty_table.

    LOOP AT mt_tables INTO ls_table.
      IF to_upper( ls_table-name ) = to_upper( iv_name ).
        rv_tabix = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_duplicate_index.
    DATA ls_index TYPE ty_index.
    DATA lv_signature TYPE string.

    lv_signature = index_signature( it_columns ).
    LOOP AT mt_indexes INTO ls_index.
      IF ls_index-tbl_name = iv_table_name
          AND index_signature( ls_index-columns ) = lv_signature.
        rv_tabix = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD index_signature.
    DATA ls_column TYPE ty_index_column.

    LOOP AT it_columns INTO ls_column.
      rv_signature = rv_signature && |{ ls_column-cid },|.
    ENDLOOP.
  ENDMETHOD.

  METHOD rootpage_of.
    DATA ls_entry TYPE zcl_sqlite_catalog=>ty_entry.

    LOOP AT it_entries INTO ls_entry.
      IF ls_entry-name = iv_name.
        rv_rootpage = ls_entry-rootpage.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD is_sqlite_internal.
    IF strlen( iv_name ) >= 7
        AND to_lower( substring( val = iv_name
                                 len = 7 ) ) = 'sqlite_'.
      rv_result = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD default_text.
    rv_text = expression_text( io_expression ).
  ENDMETHOD.

  METHOD expression_text.
    DATA lo_literal TYPE REF TO zcl_sqlite_ast_literal.
    DATA lo_unary TYPE REF TO zcl_sqlite_ast_unary.
    DATA lo_binary TYPE REF TO zcl_sqlite_ast_binary.
    DATA lv_operator TYPE string.

    IF io_expression IS NOT BOUND.
      RETURN.
    ENDIF.

    IF io_expression IS INSTANCE OF zcl_sqlite_ast_literal.
      lo_literal ?= io_expression.
      CASE lo_literal->get_kind( ).
        WHEN 'NULL'.
          rv_text = 'NULL'.
        WHEN 'INTEGER' OR 'REAL'.
          rv_text = lo_literal->get_value( ).
        WHEN 'STRING'.
          rv_text = lo_literal->get_value( ).
          REPLACE ALL OCCURRENCES OF '''' IN rv_text WITH ''''''.
          rv_text = |'{ rv_text }'|.
        WHEN 'BLOB'.
          rv_text = |X'{ lo_literal->get_value( ) }'|.
        WHEN OTHERS.
          rv_text = lo_literal->get_kind( ).
      ENDCASE.
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_unary.
      lo_unary ?= io_expression.
      lv_operator = lo_unary->get_operator( ).
      rv_text = lv_operator.
      IF lv_operator = 'NOT'.
        rv_text = rv_text && | |.
      ENDIF.
      rv_text = rv_text && expression_text( lo_unary->get_operand( ) ).
    ELSEIF io_expression IS INSTANCE OF zcl_sqlite_ast_binary.
      lo_binary ?= io_expression.
      rv_text = |{ expression_text( lo_binary->get_left( ) ) } |.
      rv_text = rv_text && lo_binary->get_operator( ).
      rv_text = rv_text && | { expression_text( lo_binary->get_right( ) ) }|.
    ELSE.
      rv_text = io_expression->dump( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
