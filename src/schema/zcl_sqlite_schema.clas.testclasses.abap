CLASS ltcl_schema DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_affinity_case,
        type_name TYPE string,
        affinity  TYPE string,
      END OF ty_affinity_case,
      ty_affinity_cases TYPE STANDARD TABLE OF ty_affinity_case
        WITH DEFAULT KEY.

    METHODS empty_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS small_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS indexed_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS without_rowid_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS many_indexes_fixture FOR TESTING RAISING zcx_sqlite_error.
    METHODS affinity_rules FOR TESTING.
    METHODS rowid_alias_rules FOR TESTING RAISING zcx_sqlite_error.
    METHODS unique_index_rules FOR TESTING RAISING zcx_sqlite_error.
    METHODS default_values FOR TESTING RAISING zcx_sqlite_error.
    METHODS strict_without_rowid_not_null
      FOR TESTING RAISING zcx_sqlite_error.

    METHODS open_pager
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(ro_pager) TYPE REF TO zcl_sqlite_pager
      RAISING   zcx_sqlite_error.

    METHODS schema_from_fixture
      IMPORTING iv_name          TYPE string
      RETURNING VALUE(ro_schema) TYPE REF TO zcl_sqlite_schema
      RAISING   zcx_sqlite_error.

    METHODS build_from_sql
      IMPORTING iv_sql           TYPE string
      RETURNING VALUE(ro_schema) TYPE REF TO zcl_sqlite_schema
      RAISING   zcx_sqlite_error.

    METHODS assert_column
      IMPORTING is_table        TYPE zcl_sqlite_schema=>ty_table
                iv_index        TYPE i
                iv_name         TYPE string
                iv_type         TYPE string
                iv_notnull      TYPE abap_bool
                iv_pk           TYPE i
                iv_affinity     TYPE string
                iv_rowid_alias  TYPE abap_bool
                iv_dflt_value   TYPE string
                iv_dflt_is_null TYPE abap_bool
                iv_context      TYPE string.

    METHODS assert_index
      IMPORTING is_index    TYPE zcl_sqlite_schema=>ty_index
                iv_name     TYPE string
                iv_tbl_name TYPE string
                iv_unique   TYPE abap_bool
                iv_origin   TYPE string
                iv_partial  TYPE abap_bool
                iv_columns  TYPE string
                iv_context  TYPE string.

    METHODS assert_index_names
      IMPORTING it_indexes TYPE zcl_sqlite_schema=>ty_indexes
                it_names   TYPE string_table
                iv_context TYPE string.

ENDCLASS.


CLASS ltcl_schema IMPLEMENTATION.

  METHOD empty_fixture.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.

    lo_schema = schema_from_fixture( 'fixtures/empty.db' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lo_schema->tables( ) ) exp = 0
      msg = 'empty.db tables' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lo_schema->indexes( ) ) exp = 0
      msg = 'empty.db indexes' ).
  ENDMETHOD.

  METHOD small_fixture.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.

    lo_schema = schema_from_fixture( 'fixtures/small.db' ).
    ls_table = lo_schema->table( 'items' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_table-name exp = 'items' msg = 'small.db table name' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_table-rootpage exp = 2 msg = 'small.db table rootpage' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_table-without_rowid exp = abap_false
      msg = 'small.db without rowid' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_table-strict exp = abap_false msg = 'small.db strict' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-columns ) exp = 3
      msg = 'small.db column count' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 0
      msg = 'small.db index count' ).

    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'id'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_false
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_true
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'small.db items.id' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 2
      iv_name         = 'name'
      iv_type         = 'TEXT'
      iv_notnull      = abap_true
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_text
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'small.db items.name' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 3
      iv_name         = 'price'
      iv_type         = 'REAL'
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_real
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'small.db items.price' ).
  ENDMETHOD.

  METHOD indexed_fixture.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    lo_schema = schema_from_fixture( 'fixtures/indexed.db' ).
    ls_table = lo_schema->table( 'items' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-columns ) exp = 2
      msg = 'indexed.db column count' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 2
      iv_name         = 'value'
      iv_type         = 'TEXT'
      iv_notnull      = abap_true
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_text
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'indexed.db items.value' ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'indexed.db index count' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'items_value'
      iv_tbl_name = 'items'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '1:value'
      iv_context  = 'indexed.db items_value' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-seq exp = 0 msg = 'indexed.db index seq' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-rootpage exp = 3
      msg = 'indexed.db index rootpage' ).
  ENDMETHOD.

  METHOD without_rowid_fixture.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    lo_schema = schema_from_fixture( 'fixtures/without_rowid.db' ).
    ls_table = lo_schema->table( 'wr' ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_table-without_rowid exp = abap_true
      msg = 'without_rowid.db table option' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-columns ) exp = 3
      msg = 'without_rowid.db column count' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'k'
      iv_type         = 'TEXT'
      iv_notnull      = abap_true
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_text
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'without_rowid.db wr.k' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 3
      iv_name         = 'n'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'without_rowid.db wr.n' ).

    assert_index_names(
      it_indexes = ls_table-indexes
      it_names   = VALUE string_table(
        ( |wr_v| )
        ( |sqlite_autoindex_wr_1| ) )
      iv_context = 'without_rowid.db index_list' ).

    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'wr_v'
      iv_tbl_name = 'wr'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '1:v'
      iv_context  = 'without_rowid.db wr_v' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-rootpage exp = 3
      msg = 'without_rowid.db wr_v rootpage' ).

    READ TABLE ls_table-indexes INTO ls_index INDEX 2.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_wr_1'
      iv_tbl_name = 'wr'
      iv_unique   = abap_true
      iv_origin   = 'pk'
      iv_partial  = abap_false
      iv_columns  = '0:k'
      iv_context  = 'without_rowid.db primary key' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_index-rootpage exp = 0
      msg = 'without_rowid.db primary key rootpage' ).
  ENDMETHOD.

  METHOD many_indexes_fixture.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    lo_schema = schema_from_fixture( 'fixtures/many_indexes.db' ).
    ls_table = lo_schema->table( 'm' ).

    assert_index_names(
      it_indexes = ls_table-indexes
      it_names   = VALUE string_table(
        ( |m_c| )
        ( |m_b| )
        ( |m_ba| )
        ( |m_ab| )
        ( |m_a| ) )
      iv_context = 'many_indexes.db index_list' ).

    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'm_c'
      iv_tbl_name = 'm'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '3:c'
      iv_context  = 'many_indexes.db m_c' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 2.
    assert_index(
      is_index    = ls_index
      iv_name     = 'm_b'
      iv_tbl_name = 'm'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '2:b'
      iv_context  = 'many_indexes.db m_b' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 3.
    assert_index(
      is_index    = ls_index
      iv_name     = 'm_ba'
      iv_tbl_name = 'm'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '2:b,1:a'
      iv_context  = 'many_indexes.db m_ba' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 4.
    assert_index(
      is_index    = ls_index
      iv_name     = 'm_ab'
      iv_tbl_name = 'm'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '1:a,2:b'
      iv_context  = 'many_indexes.db m_ab' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 5.
    assert_index(
      is_index    = ls_index
      iv_name     = 'm_a'
      iv_tbl_name = 'm'
      iv_unique   = abap_false
      iv_origin   = 'c'
      iv_partial  = abap_false
      iv_columns  = '1:a'
      iv_context  = 'many_indexes.db m_a' ).
  ENDMETHOD.

  METHOD affinity_rules.
    DATA lt_cases TYPE ty_affinity_cases.
    DATA ls_case TYPE ty_affinity_case.

    lt_cases = VALUE #(
      ( type_name = 'INTEGER' affinity = 'INTEGER' )
      ( type_name = 'INT' affinity = 'INTEGER' )
      ( type_name = 'TINYINT' affinity = 'INTEGER' )
      ( type_name = 'VARCHAR(10)' affinity = 'TEXT' )
      ( type_name = 'CHARACTER(20)' affinity = 'TEXT' )
      ( type_name = 'CLOB' affinity = 'TEXT' )
      ( type_name = 'TEXT' affinity = 'TEXT' )
      ( type_name = 'BLOB' affinity = 'BLOB' )
      ( type_name = '' affinity = 'BLOB' )
      ( type_name = 'REAL' affinity = 'REAL' )
      ( type_name = 'DOUBLE' affinity = 'REAL' )
      ( type_name = 'FLOAT' affinity = 'REAL' )
      ( type_name = 'NUMERIC' affinity = 'NUMERIC' )
      ( type_name = 'DECIMAL(10,5)' affinity = 'NUMERIC' )
      ( type_name = 'BOOLEAN' affinity = 'NUMERIC' )
      ( type_name = 'DATE' affinity = 'NUMERIC' )
      ( type_name = 'STRING' affinity = 'NUMERIC' ) ).

    LOOP AT lt_cases INTO ls_case.
      cl_abap_unit_assert=>assert_equals(
        act = zcl_sqlite_schema=>affinity_of( ls_case-type_name )
        exp = ls_case-affinity
        msg = |affinity of { ls_case-type_name }| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD rowid_alias_rules.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    lo_schema = build_from_sql( 'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)' ).
    ls_table = lo_schema->table( 't' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'id'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_false
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_true
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'rowid alias INTEGER PRIMARY KEY' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 0
      msg = 'rowid alias has no autoindex' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (id INT PRIMARY KEY, v TEXT)' ).
    ls_table = lo_schema->table( 't' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'id'
      iv_type         = 'INT'
      iv_notnull      = abap_false
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'INT PRIMARY KEY' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'INT PRIMARY KEY autoindex count' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'pk'
      iv_partial  = abap_false
      iv_columns  = '0:id'
      iv_context  = 'INT PRIMARY KEY autoindex' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (id INTEGER PRIMARY KEY DESC)' ).
    ls_table = lo_schema->table( 't' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'id'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_false
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'INTEGER PRIMARY KEY DESC' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'INTEGER PRIMARY KEY DESC autoindex count' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (id INTEGER, PRIMARY KEY(id DESC))' ).
    ls_table = lo_schema->table( 't' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'id'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_false
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_true
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'table-level INTEGER PRIMARY KEY DESC' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 0
      msg = 'table-level rowid alias has no autoindex' ).
  ENDMETHOD.

  METHOD unique_index_rules.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    lo_schema = build_from_sql( 'CREATE TABLE t (a TEXT UNIQUE, b TEXT PRIMARY KEY)' ).
    ls_table = lo_schema->table( 't' ).
    assert_index_names(
      it_indexes = ls_table-indexes
      it_names   = VALUE string_table(
        ( |sqlite_autoindex_t_2| )
        ( |sqlite_autoindex_t_1| ) )
      iv_context = 'unique before primary key' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_2'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'pk'
      iv_partial  = abap_false
      iv_columns  = '1:b'
      iv_context  = 'unique before primary key pk' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 2.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'u'
      iv_partial  = abap_false
      iv_columns  = '0:a'
      iv_context  = 'unique before primary key u' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (a TEXT, b TEXT, UNIQUE(a,b))' ).
    ls_table = lo_schema->table( 't' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'composite unique index count' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'u'
      iv_partial  = abap_false
      iv_columns  = '0:a,1:b'
      iv_context  = 'composite unique index' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (a INTEGER PRIMARY KEY, UNIQUE(a))' ).
    ls_table = lo_schema->table( 't' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'unique on rowid alias index count' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'u'
      iv_partial  = abap_false
      iv_columns  = '0:a'
      iv_context  = 'unique on rowid alias' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (a TEXT PRIMARY KEY, UNIQUE(a))' ).
    ls_table = lo_schema->table( 't' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'duplicate primary key index count' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'pk'
      iv_partial  = abap_false
      iv_columns  = '0:a'
      iv_context  = 'duplicate primary key index' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (a TEXT, UNIQUE(a), PRIMARY KEY(a))' ).
    ls_table = lo_schema->table( 't' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_table-indexes ) exp = 1
      msg = 'unique promoted to primary key index count' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'pk'
      iv_partial  = abap_false
      iv_columns  = '0:a'
      iv_context  = 'unique promoted to primary key index' ).
  ENDMETHOD.

  METHOD default_values.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.

    lo_schema = build_from_sql(
      |CREATE TABLE t (a TEXT DEFAULT 'x', b INTEGER DEFAULT -5, | &&
      |c DEFAULT NULL, d DEFAULT CURRENT_TIMESTAMP, e REAL DEFAULT 1.5, | &&
      |f BLOB DEFAULT X'AB')| ).
    ls_table = lo_schema->table( 't' ).

    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'a'
      iv_type         = 'TEXT'
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_text
      iv_rowid_alias  = abap_false
      iv_dflt_value   = '''x'''
      iv_dflt_is_null = abap_false
      iv_context      = 'default string' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 2
      iv_name         = 'b'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_false
      iv_dflt_value   = '-5'
      iv_dflt_is_null = abap_false
      iv_context      = 'default negative integer' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 3
      iv_name         = 'c'
      iv_type         = ''
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_blob
      iv_rowid_alias  = abap_false
      iv_dflt_value   = 'NULL'
      iv_dflt_is_null = abap_false
      iv_context      = 'default NULL' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 4
      iv_name         = 'd'
      iv_type         = ''
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_blob
      iv_rowid_alias  = abap_false
      iv_dflt_value   = 'CURRENT_TIMESTAMP'
      iv_dflt_is_null = abap_false
      iv_context      = 'default current timestamp' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 5
      iv_name         = 'e'
      iv_type         = 'REAL'
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_real
      iv_rowid_alias  = abap_false
      iv_dflt_value   = '1.5'
      iv_dflt_is_null = abap_false
      iv_context      = 'default real' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 6
      iv_name         = 'f'
      iv_type         = 'BLOB'
      iv_notnull      = abap_false
      iv_pk           = 0
      iv_affinity     = zcl_sqlite_schema=>c_affinity_blob
      iv_rowid_alias  = abap_false
      iv_dflt_value   = 'X''AB'''
      iv_dflt_is_null = abap_false
      iv_context      = 'default blob' ).
  ENDMETHOD.

  METHOD strict_without_rowid_not_null.
    DATA lo_schema TYPE REF TO zcl_sqlite_schema.
    DATA ls_table TYPE zcl_sqlite_schema=>ty_table.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.

    lo_schema = build_from_sql( 'CREATE TABLE t (a INTEGER PRIMARY KEY, b TEXT) STRICT' ).
    ls_table = lo_schema->table( 't' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'a'
      iv_type         = 'INTEGER'
      iv_notnull      = abap_true
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_integer
      iv_rowid_alias  = abap_true
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'strict primary key not null' ).

    lo_schema = build_from_sql( 'CREATE TABLE t (a TEXT, b TEXT, PRIMARY KEY(a)) WITHOUT ROWID' ).
    ls_table = lo_schema->table( 't' ).
    assert_column(
      is_table        = ls_table
      iv_index        = 1
      iv_name         = 'a'
      iv_type         = 'TEXT'
      iv_notnull      = abap_true
      iv_pk           = 1
      iv_affinity     = zcl_sqlite_schema=>c_affinity_text
      iv_rowid_alias  = abap_false
      iv_dflt_value   = ''
      iv_dflt_is_null = abap_true
      iv_context      = 'without rowid primary key not null' ).
    READ TABLE ls_table-indexes INTO ls_index INDEX 1.
    assert_index(
      is_index    = ls_index
      iv_name     = 'sqlite_autoindex_t_1'
      iv_tbl_name = 't'
      iv_unique   = abap_true
      iv_origin   = 'pk'
      iv_partial  = abap_false
      iv_columns  = '0:a'
      iv_context  = 'without rowid primary key index' ).
  ENDMETHOD.

  METHOD open_pager.
    DATA lo_vfs TYPE REF TO zif_sqlite_vfs.
    DATA lo_file TYPE REF TO zif_sqlite_file.

    lo_vfs = NEW zcl_sqlite_vfs_table( ).
    lo_file = lo_vfs->open( iv_name ).
    ro_pager = NEW zcl_sqlite_pager( io_file = lo_file ).
  ENDMETHOD.

  METHOD schema_from_fixture.
    DATA lo_pager TYPE REF TO zcl_sqlite_pager.

    lo_pager = open_pager( iv_name ).
    ro_schema = zcl_sqlite_schema=>read( lo_pager ).
  ENDMETHOD.

  METHOD build_from_sql.
    DATA lt_entries TYPE zcl_sqlite_catalog=>ty_entries.

    APPEND VALUE #(
      type        = 'table'
      name        = 't'
      tbl_name    = 't'
      rootpage    = 2
      sql         = iv_sql
      sql_is_null = abap_false ) TO lt_entries.

    ro_schema = zcl_sqlite_schema=>build( lt_entries ).
  ENDMETHOD.

  METHOD assert_column.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_column.

    READ TABLE is_table-columns INTO ls_column INDEX iv_index.
    cl_abap_unit_assert=>assert_equals(
      act = sy-subrc exp = 0
      msg = |{ iv_context } column { iv_index } is missing| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-cid exp = iv_index - 1
      msg = |{ iv_context } cid| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-name exp = iv_name
      msg = |{ iv_context } name| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-type exp = iv_type
      msg = |{ iv_context } type| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-notnull exp = iv_notnull
      msg = |{ iv_context } notnull| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-pk exp = iv_pk
      msg = |{ iv_context } pk| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-affinity exp = iv_affinity
      msg = |{ iv_context } affinity| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-rowid_alias exp = iv_rowid_alias
      msg = |{ iv_context } rowid alias| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-dflt_value exp = iv_dflt_value
      msg = |{ iv_context } default value| ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_column-dflt_value_is_null exp = iv_dflt_is_null
      msg = |{ iv_context } default null flag| ).
  ENDMETHOD.

  METHOD assert_index.
    DATA ls_column TYPE zcl_sqlite_schema=>ty_index_column.
    DATA lv_columns TYPE string.

    cl_abap_unit_assert=>assert_equals(
      act = is_index-name exp = iv_name
      msg = |{ iv_context } index name| ).
    cl_abap_unit_assert=>assert_equals(
      act = is_index-tbl_name exp = iv_tbl_name
      msg = |{ iv_context } index table| ).
    cl_abap_unit_assert=>assert_equals(
      act = is_index-is_unique exp = iv_unique
      msg = |{ iv_context } index unique| ).
    cl_abap_unit_assert=>assert_equals(
      act = is_index-origin exp = iv_origin
      msg = |{ iv_context } index origin| ).
    cl_abap_unit_assert=>assert_equals(
      act = is_index-partial exp = iv_partial
      msg = |{ iv_context } index partial| ).

    LOOP AT is_index-columns INTO ls_column.
      IF lv_columns IS NOT INITIAL.
        lv_columns = lv_columns && |,|.
      ENDIF.
      lv_columns = lv_columns && |{ ls_column-cid }:{ ls_column-name }|.
      cl_abap_unit_assert=>assert_equals(
        act = ls_column-seqno exp = sy-tabix - 1
        msg = |{ iv_context } index column seqno| ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals(
      act = lv_columns exp = iv_columns
      msg = |{ iv_context } index columns| ).
  ENDMETHOD.

  METHOD assert_index_names.
    DATA ls_index TYPE zcl_sqlite_schema=>ty_index.
    DATA lv_name TYPE string.

    cl_abap_unit_assert=>assert_equals(
      act = lines( it_indexes ) exp = lines( it_names )
      msg = |{ iv_context } index count| ).

    LOOP AT it_names INTO lv_name.
      READ TABLE it_indexes INTO ls_index INDEX sy-tabix.
      cl_abap_unit_assert=>assert_equals(
        act = ls_index-name exp = lv_name
        msg = |{ iv_context } index { sy-tabix } name| ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_index-seq exp = sy-tabix - 1
        msg = |{ iv_context } index { sy-tabix } seq| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
