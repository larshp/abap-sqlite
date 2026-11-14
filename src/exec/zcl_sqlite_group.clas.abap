* Groups the rows of a child operator and evaluates the result columns once
* per group. HAVING is applied before a group row is emitted.
CLASS zcl_sqlite_group DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_sqlite_operator.

    TYPES ty_columns TYPE zcl_sqlite_project=>ty_columns.
    TYPES ty_expressions TYPE zcl_sqlite_ast_node=>ty_nodes.

    METHODS constructor
      IMPORTING io_source        TYPE REF TO zif_sqlite_operator OPTIONAL
                it_group_by      TYPE ty_expressions
                it_columns       TYPE ty_columns
                iv_visible_count TYPE i
                io_having        TYPE REF TO zcl_sqlite_ast_node OPTIONAL
      RAISING   zcx_sqlite_error.

  PRIVATE SECTION.
    TYPES ty_rows TYPE zcl_sqlite_group_context=>ty_rows.
    TYPES ty_values TYPE zcl_sqlite_group_context=>ty_values.

    TYPES: BEGIN OF ty_group,
             keys TYPE ty_values,
             rows TYPE ty_rows,
           END OF ty_group.
    TYPES ty_groups TYPE STANDARD TABLE OF ty_group WITH DEFAULT KEY.

    DATA mo_source      TYPE REF TO zif_sqlite_operator.
    DATA mt_group_by    TYPE ty_expressions.
    DATA mt_columns     TYPE ty_columns.
    DATA mv_visible_count TYPE i.
    DATA mo_having      TYPE REF TO zcl_sqlite_ast_node.
    DATA mt_collations  TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA mt_groups      TYPE ty_groups.
    DATA mv_index       TYPE i.
    DATA mo_row         TYPE REF TO zcl_sqlite_row.

    METHODS load_groups
      RAISING zcx_sqlite_error.

    METHODS group_keys
      IMPORTING io_context     TYPE REF TO zif_sqlite_eval_context
      RETURNING VALUE(rt_keys) TYPE ty_values
      RAISING   zcx_sqlite_error.

    METHODS find_group
      IMPORTING it_keys         TYPE ty_values
      RETURNING VALUE(rv_index) TYPE i
      RAISING   zcx_sqlite_error.

    METHODS build_row
      IMPORTING io_context      TYPE REF TO zif_sqlite_eval_context
                it_rows         TYPE zcl_sqlite_group_context=>ty_rows
      RETURNING VALUE(rv_found) TYPE abap_bool
      RAISING   zcx_sqlite_error.

ENDCLASS.


CLASS zcl_sqlite_group IMPLEMENTATION.

  METHOD constructor.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA lv_collation  TYPE string.

    mo_source = io_source.
    mt_group_by = it_group_by.
    mt_columns = it_columns.
    mv_visible_count = iv_visible_count.
    mo_having = io_having.

    LOOP AT mt_group_by INTO lo_expression.
      lv_collation = zcl_sqlite_expr_eval=>collation_of_expression( lo_expression ).
      IF lv_collation IS INITIAL.
        lv_collation = 'BINARY'.
      ENDIF.
      APPEND lv_collation TO mt_collations.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_sqlite_operator~open.
    IF mo_source IS BOUND.
      mo_source->open( ).
    ENDIF.

    load_groups( ).
    mv_index = 1.
    CLEAR mo_row.
  ENDMETHOD.

  METHOD zif_sqlite_operator~next.
    DATA ls_group TYPE ty_group.
    DATA lo_context TYPE REF TO zif_sqlite_eval_context.

    WHILE mv_index <= lines( mt_groups ).
      READ TABLE mt_groups INTO ls_group INDEX mv_index.
      mv_index = mv_index + 1.
      lo_context = NEW zcl_sqlite_group_context( it_rows = ls_group-rows ).
      IF build_row(
          io_context = lo_context
          it_rows    = ls_group-rows ) = abap_true.
        RETURN abap_true.
      ENDIF.
    ENDWHILE.

    CLEAR mo_row.
    RETURN abap_false.
  ENDMETHOD.

  METHOD zif_sqlite_operator~row.
    ro_row = mo_row.
  ENDMETHOD.

  METHOD load_groups.
    DATA lo_row       TYPE REF TO zcl_sqlite_row.
    DATA lo_context   TYPE REF TO zif_sqlite_eval_context.
    DATA lt_keys      TYPE ty_values.
    DATA lv_index     TYPE i.
    DATA ls_group     TYPE ty_group.
    FIELD-SYMBOLS <ls_group> TYPE ty_group.

    CLEAR mt_groups.

    IF mo_source IS BOUND.
      WHILE mo_source->next( ) = abap_true.
        lo_row = mo_source->row( ).
        lo_context = lo_row.
        lt_keys = group_keys( lo_context ).
        lv_index = find_group( lt_keys ).
        IF lv_index = 0.
          CLEAR ls_group.
          ls_group-keys = lt_keys.
          APPEND lo_row TO ls_group-rows.
          APPEND ls_group TO mt_groups.
        ELSE.
          READ TABLE mt_groups ASSIGNING <ls_group> INDEX lv_index.
          APPEND lo_row TO <ls_group>-rows.
        ENDIF.
      ENDWHILE.
    ELSE.
      lo_row = NEW zcl_sqlite_row( ).
      lo_context = lo_row.
      lt_keys = group_keys( lo_context ).
      ls_group-keys = lt_keys.
      APPEND lo_row TO ls_group-rows.
      APPEND ls_group TO mt_groups.
    ENDIF.

    IF lines( mt_group_by ) = 0 AND lines( mt_groups ) = 0.
      CLEAR ls_group.
      APPEND ls_group TO mt_groups.
    ENDIF.
  ENDMETHOD.

  METHOD group_keys.
    DATA lo_expression TYPE REF TO zcl_sqlite_ast_node.
    DATA lo_value      TYPE REF TO zcl_sqlite_value.

    LOOP AT mt_group_by INTO lo_expression.
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = lo_expression
        io_context    = io_context ).
      APPEND lo_value TO rt_keys.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_group.
    DATA ls_group   TYPE ty_group.
    DATA lo_left    TYPE REF TO zcl_sqlite_value.
    DATA lo_right   TYPE REF TO zcl_sqlite_value.
    DATA lv_collation TYPE string.
    DATA lv_duplicate TYPE abap_bool.
    DATA lv_position TYPE i.
    DATA lv_group_index TYPE i.

    LOOP AT mt_groups INTO ls_group.
      lv_group_index = sy-tabix.
      lv_duplicate = abap_true.
      DO lines( it_keys ) TIMES.
        lv_position = sy-index.
        READ TABLE ls_group-keys INTO lo_left INDEX lv_position.
        READ TABLE it_keys INTO lo_right INDEX lv_position.
        READ TABLE mt_collations INTO lv_collation INDEX lv_position.
        IF zcl_sqlite_expr_eval=>compare_values(
            io_left      = lo_left
            io_right     = lo_right
            iv_collation = lv_collation ) <> 0.
          lv_duplicate = abap_false.
          EXIT.
        ENDIF.
      ENDDO.
      IF lv_duplicate = abap_true.
        rv_index = lv_group_index.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_row.
    DATA lo_value          TYPE REF TO zcl_sqlite_value.
    DATA lo_row            TYPE REF TO zcl_sqlite_row.
    DATA lo_context        TYPE REF TO zif_sqlite_eval_context.
    DATA lo_alias_context  TYPE REF TO zcl_sqlite_group_context.
    DATA ls_column         TYPE zcl_sqlite_project=>ty_column.
    DATA ls_alias          TYPE zcl_sqlite_group_context=>ty_alias.
    DATA lt_aliases        TYPE zcl_sqlite_group_context=>ty_aliases.
    DATA lv_position       TYPE i.

    lo_context = io_context.

    IF mo_having IS BOUND.
      LOOP AT mt_columns INTO ls_column.
        lv_position = lv_position + 1.
        IF lv_position > mv_visible_count.
          EXIT.
        ENDIF.
        lo_value = zcl_sqlite_expr_eval=>evaluate(
          io_expression = ls_column-expression
          io_context    = io_context ).
        ls_alias-name = ls_column-name.
        ls_alias-value = lo_value.
        APPEND ls_alias TO lt_aliases.
      ENDLOOP.

      lo_alias_context = NEW zcl_sqlite_group_context(
        it_rows    = it_rows
        it_aliases = lt_aliases ).
      lo_context = lo_alias_context.

      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = mo_having
        io_context    = lo_context ).
      IF zcl_sqlite_expr_eval=>is_true( lo_value ) = abap_false.
        RETURN.
      ENDIF.
    ENDIF.

    lo_row = NEW zcl_sqlite_row( ).
    LOOP AT mt_columns INTO ls_column.
      lo_value = zcl_sqlite_expr_eval=>evaluate(
        io_expression = ls_column-expression
        io_context    = lo_context ).
      lo_row->add_cell(
        iv_name  = ls_column-name
        io_value = lo_value ).
    ENDLOOP.

    mo_row = lo_row.
    rv_found = abap_true.
  ENDMETHOD.

ENDCLASS.
