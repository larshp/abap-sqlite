* SQLite SQL tokenizer, see https://www.sqlite.org/lang.html and
* https://www.sqlite.org/draft/tokenreq.html
*
* Token offsets, lengths, lines and columns are one-based character positions.
* Whitespace is skipped. Comments are returned as tokens so the parser can
* report errors in them and so the tokenizer corpus can verify them.
CLASS zcl_sqlite_tokenizer DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS:
      c_keyword    TYPE string VALUE 'KEYWORD',
      c_identifier TYPE string VALUE 'IDENTIFIER',
      c_string     TYPE string VALUE 'STRING',
      c_blob       TYPE string VALUE 'BLOB',
      c_integer    TYPE string VALUE 'INTEGER',
      c_float      TYPE string VALUE 'FLOAT',
      c_parameter  TYPE string VALUE 'PARAMETER',
      c_operator   TYPE string VALUE 'OPERATOR',
      c_semicolon  TYPE string VALUE 'SEMICOLON',
      c_lparen     TYPE string VALUE 'LPAREN',
      c_rparen     TYPE string VALUE 'RPAREN',
      c_comma      TYPE string VALUE 'COMMA',
      c_dot        TYPE string VALUE 'DOT',
      c_comment    TYPE string VALUE 'COMMENT',
      c_eof        TYPE string VALUE 'EOF',
      c_illegal    TYPE string VALUE 'ILLEGAL'.

    TYPES: BEGIN OF ty_token,
             kind   TYPE string,
             text   TYPE string,
             value  TYPE string,
             offset TYPE i,
             length TYPE i,
             line   TYPE i,
             column TYPE i,
           END OF ty_token.
    TYPES ty_tokens TYPE STANDARD TABLE OF ty_token WITH DEFAULT KEY.

    CLASS-METHODS tokenize
      IMPORTING iv_sql           TYPE string
      RETURNING VALUE(rt_tokens) TYPE ty_tokens.

    CLASS-METHODS is_keyword
      IMPORTING iv_word              TYPE string
      RETURNING VALUE(rv_is_keyword) TYPE abap_bool.

    CLASS-METHODS class_constructor.

  PRIVATE SECTION.
    TYPES ty_keywords TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    CLASS-DATA gt_keywords TYPE ty_keywords.

    DATA mv_sql TYPE string.
    DATA mv_length TYPE i.
    DATA mv_pos TYPE i.
    DATA mv_line TYPE i.
    DATA mv_column TYPE i.
    DATA mt_tokens TYPE ty_tokens.

    METHODS scan
      IMPORTING iv_sql TYPE string.
    METHODS scan_line_comment.
    METHODS scan_block_comment.
    METHODS scan_string.
    METHODS scan_quoted_identifier.
    METHODS scan_blob.
    METHODS scan_number.
    METHODS scan_question_parameter.
    METHODS scan_parameter.
    METHODS scan_word.
    METHODS scan_punctuation.
    METHODS scan_operator.
    METHODS emit_fixed
      IMPORTING iv_kind  TYPE string
                iv_text  TYPE string
                iv_value TYPE string.
    METHODS add_token
      IMPORTING iv_kind   TYPE string
                iv_text   TYPE string
                iv_value  TYPE string
                iv_offset TYPE i
                iv_line   TYPE i
                iv_column TYPE i.
    METHODS token_text
      IMPORTING iv_start       TYPE i
      RETURNING VALUE(rv_text) TYPE string.
    METHODS current
      RETURNING VALUE(rv_char) TYPE string.
    METHODS peek
      IMPORTING iv_ahead       TYPE i
      RETURNING VALUE(rv_char) TYPE string.
    METHODS char_at
      IMPORTING iv_position    TYPE i
      RETURNING VALUE(rv_char) TYPE string.
    METHODS advance.
    METHODS is_space
      IMPORTING iv_char         TYPE string
      RETURNING VALUE(rv_space) TYPE abap_bool.
    METHODS is_digit
      IMPORTING iv_char         TYPE string
      RETURNING VALUE(rv_digit) TYPE abap_bool.
    METHODS is_hex_digit
      IMPORTING iv_char             TYPE string
      RETURNING VALUE(rv_hex_digit) TYPE abap_bool.
    METHODS is_identifier_start
      IMPORTING iv_char              TYPE string
      RETURNING VALUE(rv_identifier) TYPE abap_bool.
    METHODS is_identifier_part
      IMPORTING iv_char              TYPE string
      RETURNING VALUE(rv_identifier) TYPE abap_bool.
    METHODS is_high_char
      IMPORTING iv_char        TYPE string
      RETURNING VALUE(rv_high) TYPE abap_bool.
ENDCLASS.


CLASS zcl_sqlite_tokenizer IMPLEMENTATION.

  METHOD class_constructor.
    gt_keywords = VALUE #(
      ( |ABORT| )
      ( |ACTION| )
      ( |ADD| )
      ( |AFTER| )
      ( |ALL| )
      ( |ALTER| )
      ( |ALWAYS| )
      ( |ANALYZE| )
      ( |AND| )
      ( |AS| )
      ( |ASC| )
      ( |ATTACH| )
      ( |AUTOINCREMENT| )
      ( |BEFORE| )
      ( |BEGIN| )
      ( |BETWEEN| )
      ( |BY| )
      ( |CASCADE| )
      ( |CASE| )
      ( |CAST| )
      ( |CHECK| )
      ( |COLLATE| )
      ( |COLUMN| )
      ( |COMMIT| )
      ( |CONFLICT| )
      ( |CONSTRAINT| )
      ( |CREATE| )
      ( |CROSS| )
      ( |CURRENT| )
      ( |CURRENT_DATE| )
      ( |CURRENT_TIME| )
      ( |CURRENT_TIMESTAMP| )
      ( |DATABASE| )
      ( |DEFAULT| )
      ( |DEFERRABLE| )
      ( |DEFERRED| )
      ( |DELETE| )
      ( |DESC| )
      ( |DETACH| )
      ( |DISTINCT| )
      ( |DO| )
      ( |DROP| )
      ( |EACH| )
      ( |ELSE| )
      ( |END| )
      ( |ESCAPE| )
      ( |EXCEPT| )
      ( |EXCLUDE| )
      ( |EXCLUSIVE| )
      ( |EXISTS| )
      ( |EXPLAIN| )
      ( |FAIL| )
      ( |FILTER| )
      ( |FIRST| )
      ( |FOLLOWING| )
      ( |FOR| )
      ( |FOREIGN| )
      ( |FROM| )
      ( |FULL| )
      ( |GENERATED| )
      ( |GLOB| )
      ( |GROUP| )
      ( |GROUPS| )
      ( |HAVING| )
      ( |IF| )
      ( |IGNORE| )
      ( |IMMEDIATE| )
      ( |IN| )
      ( |INDEX| )
      ( |INDEXED| )
      ( |INITIALLY| )
      ( |INNER| )
      ( |INSERT| )
      ( |INSTEAD| )
      ( |INTERSECT| )
      ( |INTO| )
      ( |IS| )
      ( |ISNULL| )
      ( |JOIN| )
      ( |KEY| )
      ( |LAST| )
      ( |LEFT| )
      ( |LIKE| )
      ( |LIMIT| )
      ( |MATCH| )
      ( |MATERIALIZED| )
      ( |NATURAL| )
      ( |NO| )
      ( |NOT| )
      ( |NOTHING| )
      ( |NOTNULL| )
      ( |NULL| )
      ( |NULLS| )
      ( |OF| )
      ( |OFFSET| )
      ( |ON| )
      ( |OR| )
      ( |ORDER| )
      ( |OTHERS| )
      ( |OUTER| )
      ( |OVER| )
      ( |PARTITION| )
      ( |PLAN| )
      ( |PRAGMA| )
      ( |PRECEDING| )
      ( |PRIMARY| )
      ( |QUERY| )
      ( |RAISE| )
      ( |RANGE| )
      ( |RECURSIVE| )
      ( |REFERENCES| )
      ( |REGEXP| )
      ( |REINDEX| )
      ( |RELEASE| )
      ( |RENAME| )
      ( |REPLACE| )
      ( |RESTRICT| )
      ( |RETURNING| )
      ( |RIGHT| )
      ( |ROLLBACK| )
      ( |ROW| )
      ( |ROWS| )
      ( |SAVEPOINT| )
      ( |SELECT| )
      ( |SET| )
      ( |TABLE| )
      ( |TEMP| )
      ( |TEMPORARY| )
      ( |THEN| )
      ( |TIES| )
      ( |TO| )
      ( |TRANSACTION| )
      ( |TRIGGER| )
      ( |UNBOUNDED| )
      ( |UNION| )
      ( |UNIQUE| )
      ( |UPDATE| )
      ( |USING| )
      ( |VACUUM| )
      ( |VALUES| )
      ( |VIEW| )
      ( |VIRTUAL| )
      ( |WHEN| )
      ( |WHERE| )
      ( |WINDOW| )
      ( |WITH| )
      ( |WITHOUT| ) ).
  ENDMETHOD.

  METHOD tokenize.
    DATA lo_tokenizer TYPE REF TO zcl_sqlite_tokenizer.

    lo_tokenizer = NEW #( ).
    lo_tokenizer->scan( iv_sql ).
    rt_tokens = lo_tokenizer->mt_tokens.
  ENDMETHOD.

  METHOD is_keyword.
    DATA lv_upper TYPE string.

    lv_upper = to_upper( iv_word ).
    READ TABLE gt_keywords TRANSPORTING NO FIELDS
      WITH KEY table_line = lv_upper.
    rv_is_keyword = boolc( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD scan.
    DATA lv_char TYPE string.

    mv_sql = iv_sql.
    mv_length = strlen( iv_sql ).
    mv_pos = 1.
    mv_line = 1.
    mv_column = 1.
    CLEAR mt_tokens.

    WHILE mv_pos <= mv_length.
      lv_char = current( ).

      IF is_space( lv_char ) = abap_true.
        advance( ).
      ELSEIF lv_char = '-' AND peek( 1 ) = '-'.
        scan_line_comment( ).
      ELSEIF lv_char = '/' AND peek( 1 ) = '*'.
        scan_block_comment( ).
      ELSEIF lv_char = ''''.
        scan_string( ).
      ELSEIF ( lv_char = 'x' OR lv_char = 'X' ) AND peek( 1 ) = ''''.
        scan_blob( ).
      ELSEIF lv_char = '"' OR lv_char = '`' OR lv_char = '['.
        scan_quoted_identifier( ).
      ELSEIF lv_char = '?'.
        scan_question_parameter( ).
      ELSEIF lv_char = ':' OR lv_char = '@' OR lv_char = '$'.
        scan_parameter( ).
      ELSEIF is_digit( lv_char ) = abap_true
          OR ( lv_char = '.' AND is_digit( peek( 1 ) ) = abap_true ).
        scan_number( ).
      ELSEIF is_identifier_start( lv_char ) = abap_true.
        scan_word( ).
      ELSEIF lv_char = ';' OR lv_char = '(' OR lv_char = ')'
          OR lv_char = ',' OR lv_char = '.'.
        scan_punctuation( ).
      ELSEIF lv_char = '-' OR lv_char = '=' OR lv_char = '!'
          OR lv_char = '<' OR lv_char = '>' OR lv_char = '|'
          OR lv_char = '+' OR lv_char = '*' OR lv_char = '/'
          OR lv_char = '%' OR lv_char = '&' OR lv_char = '~'.
        scan_operator( ).
      ELSE.
        emit_fixed( iv_kind = c_illegal iv_text = lv_char iv_value = lv_char ).
      ENDIF.
    ENDWHILE.

    add_token(
      iv_kind = c_eof
      iv_text = ''
      iv_value = ''
      iv_offset = mv_pos
      iv_line = mv_line
      iv_column = mv_column ).
  ENDMETHOD.

  METHOD scan_line_comment.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_text TYPE string.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    advance( ).
    advance( ).

    WHILE mv_pos <= mv_length AND current( ) <> cl_abap_char_utilities=>newline.
      advance( ).
    ENDWHILE.

    lv_text = token_text( lv_start ).
    add_token(
      iv_kind = c_comment
      iv_text = lv_text
      iv_value = lv_text
      iv_offset = lv_start
      iv_line = lv_line
      iv_column = lv_column ).
  ENDMETHOD.

  METHOD scan_block_comment.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_text TYPE string.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    advance( ).
    advance( ).

    WHILE mv_pos <= mv_length.
      IF current( ) = '*' AND peek( 1 ) = '/'.
        advance( ).
        advance( ).
        EXIT.
      ENDIF.
      advance( ).
    ENDWHILE.

    lv_text = token_text( lv_start ).
    add_token(
      iv_kind = c_comment
      iv_text = lv_text
      iv_value = lv_text
      iv_offset = lv_start
      iv_line = lv_line
      iv_column = lv_column ).
  ENDMETHOD.

  METHOD scan_string.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_value TYPE string.
    DATA lv_char TYPE string.
    DATA lv_text TYPE string.
    DATA lv_closed TYPE abap_bool.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    advance( ).

    WHILE mv_pos <= mv_length.
      lv_char = current( ).
      IF lv_char = ''''.
        IF peek( 1 ) = ''''.
          lv_value = lv_value && ''''.
          advance( ).
          advance( ).
        ELSE.
          advance( ).
          lv_closed = abap_true.
          EXIT.
        ENDIF.
      ELSE.
        lv_value = lv_value && lv_char.
        advance( ).
      ENDIF.
    ENDWHILE.

    lv_text = token_text( lv_start ).
    IF lv_closed = abap_true.
      add_token(
        iv_kind = c_string
        iv_text = lv_text
        iv_value = lv_value
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ELSE.
      add_token(
        iv_kind = c_illegal
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ENDIF.
  ENDMETHOD.

  METHOD scan_quoted_identifier.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_quote TYPE string.
    DATA lv_close TYPE string.
    DATA lv_value TYPE string.
    DATA lv_char TYPE string.
    DATA lv_text TYPE string.
    DATA lv_closed TYPE abap_bool.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    lv_quote = current( ).
    IF lv_quote = '['.
      lv_close = ']'.
    ELSE.
      lv_close = lv_quote.
    ENDIF.
    advance( ).

    WHILE mv_pos <= mv_length.
      lv_char = current( ).
      IF lv_char = lv_close.
        IF lv_quote <> '[' AND peek( 1 ) = lv_quote.
          lv_value = lv_value && lv_quote.
          advance( ).
          advance( ).
        ELSE.
          advance( ).
          lv_closed = abap_true.
          EXIT.
        ENDIF.
      ELSE.
        lv_value = lv_value && lv_char.
        advance( ).
      ENDIF.
    ENDWHILE.

    lv_text = token_text( lv_start ).
    IF lv_closed = abap_true.
      add_token(
        iv_kind = c_identifier
        iv_text = lv_text
        iv_value = lv_value
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ELSE.
      add_token(
        iv_kind = c_illegal
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ENDIF.
  ENDMETHOD.

  METHOD scan_blob.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_hex TYPE string.
    DATA lv_char TYPE string.
    DATA lv_text TYPE string.
    DATA lv_closed TYPE abap_bool.
    DATA lv_valid TYPE abap_bool VALUE abap_true.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    advance( ).
    advance( ).

    WHILE mv_pos <= mv_length.
      lv_char = current( ).
      IF lv_char = ''''.
        advance( ).
        lv_closed = abap_true.
        EXIT.
      ELSEIF is_hex_digit( lv_char ) = abap_true.
        lv_hex = lv_hex && to_upper( lv_char ).
        advance( ).
      ELSE.
        lv_valid = abap_false.
        advance( ).
      ENDIF.
    ENDWHILE.

    lv_text = token_text( lv_start ).
    IF lv_closed = abap_true
        AND lv_valid = abap_true
        AND strlen( lv_hex ) MOD 2 = 0.
      add_token(
        iv_kind = c_blob
        iv_text = lv_text
        iv_value = lv_hex
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ELSE.
      add_token(
        iv_kind = c_illegal
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ENDIF.
  ENDMETHOD.

  METHOD scan_number.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_text TYPE string.
    DATA lv_kind TYPE string.
    DATA lv_valid TYPE abap_bool VALUE abap_true.
    DATA lv_has_dot TYPE abap_bool.
    DATA lv_has_exponent TYPE abap_bool.
    DATA lv_hex_digits TYPE i.
    DATA lv_char TYPE string.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.

    IF current( ) = '0' AND ( peek( 1 ) = 'x' OR peek( 1 ) = 'X' ).
      advance( ).
      advance( ).
      WHILE mv_pos <= mv_length AND is_hex_digit( current( ) ) = abap_true.
        lv_hex_digits = lv_hex_digits + 1.
        advance( ).
      ENDWHILE.
      IF lv_hex_digits = 0.
        lv_valid = abap_false.
      ENDIF.
      WHILE mv_pos <= mv_length AND is_identifier_part( current( ) ) = abap_true.
        lv_valid = abap_false.
        advance( ).
      ENDWHILE.
      lv_kind = c_integer.
    ELSE.
      IF current( ) = '.'.
        lv_has_dot = abap_true.
        advance( ).
      ELSE.
        WHILE mv_pos <= mv_length AND is_digit( current( ) ) = abap_true.
          advance( ).
        ENDWHILE.
        IF mv_pos <= mv_length AND current( ) = '.'.
          lv_has_dot = abap_true.
          advance( ).
        ENDIF.
      ENDIF.

      WHILE mv_pos <= mv_length AND is_digit( current( ) ) = abap_true.
        advance( ).
      ENDWHILE.

      IF mv_pos <= mv_length AND ( current( ) = 'e' OR current( ) = 'E' ).
        lv_has_exponent = abap_true.
        advance( ).
        IF mv_pos <= mv_length AND ( current( ) = '+' OR current( ) = '-' ).
          advance( ).
        ENDIF.
        IF mv_pos <= mv_length AND is_digit( current( ) ) = abap_true.
          WHILE mv_pos <= mv_length AND is_digit( current( ) ) = abap_true.
            advance( ).
          ENDWHILE.
        ELSE.
          lv_valid = abap_false.
        ENDIF.
      ENDIF.

      lv_char = current( ).
      IF lv_char <> '' AND is_identifier_part( lv_char ) = abap_true.
        lv_valid = abap_false.
        WHILE mv_pos <= mv_length AND is_identifier_part( current( ) ) = abap_true.
          advance( ).
        ENDWHILE.
      ENDIF.

      IF lv_has_dot = abap_true OR lv_has_exponent = abap_true.
        lv_kind = c_float.
      ELSE.
        lv_kind = c_integer.
      ENDIF.
    ENDIF.

    lv_text = token_text( lv_start ).
    IF lv_valid = abap_false.
      add_token(
        iv_kind = c_illegal
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ELSE.
      add_token(
        iv_kind = lv_kind
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ENDIF.
  ENDMETHOD.

  METHOD scan_question_parameter.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_value TYPE string.
    DATA lv_text TYPE string.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    advance( ).
    WHILE mv_pos <= mv_length AND is_digit( current( ) ) = abap_true.
      lv_value = lv_value && current( ).
      advance( ).
    ENDWHILE.

    lv_text = token_text( lv_start ).
    add_token(
      iv_kind = c_parameter
      iv_text = lv_text
      iv_value = lv_value
      iv_offset = lv_start
      iv_line = lv_line
      iv_column = lv_column ).
  ENDMETHOD.

  METHOD scan_parameter.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_prefix TYPE string.
    DATA lv_value TYPE string.
    DATA lv_char TYPE string.
    DATA lv_text TYPE string.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    lv_prefix = current( ).
    advance( ).

    WHILE mv_pos <= mv_length AND is_identifier_part( current( ) ) = abap_true.
      lv_value = lv_value && current( ).
      advance( ).
    ENDWHILE.

    IF lv_prefix = '$'.
      WHILE mv_pos <= mv_length
          AND current( ) = ':'
          AND peek( 1 ) = ':'.
        lv_value = lv_value && '::'.
        advance( ).
        advance( ).
        WHILE mv_pos <= mv_length AND is_identifier_part( current( ) ) = abap_true.
          lv_value = lv_value && current( ).
          advance( ).
        ENDWHILE.
      ENDWHILE.

      IF mv_pos <= mv_length AND current( ) = '('.
        WHILE mv_pos <= mv_length.
          lv_char = current( ).
          lv_value = lv_value && lv_char.
          advance( ).
          IF lv_char = ')'.
            EXIT.
          ENDIF.
        ENDWHILE.
      ENDIF.
    ENDIF.

    lv_text = token_text( lv_start ).
    IF strlen( lv_value ) = 0.
      add_token(
        iv_kind = c_illegal
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ELSE.
      add_token(
        iv_kind = c_parameter
        iv_text = lv_text
        iv_value = lv_value
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ENDIF.
  ENDMETHOD.

  METHOD scan_word.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.
    DATA lv_text TYPE string.
    DATA lv_value TYPE string.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.

    WHILE mv_pos <= mv_length AND is_identifier_part( current( ) ) = abap_true.
      advance( ).
    ENDWHILE.

    lv_text = token_text( lv_start ).
    IF is_keyword( lv_text ) = abap_true.
      lv_value = to_upper( lv_text ).
      add_token(
        iv_kind = c_keyword
        iv_text = lv_text
        iv_value = lv_value
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ELSE.
      add_token(
        iv_kind = c_identifier
        iv_text = lv_text
        iv_value = lv_text
        iv_offset = lv_start
        iv_line = lv_line
        iv_column = lv_column ).
    ENDIF.
  ENDMETHOD.

  METHOD scan_punctuation.
    DATA lv_char TYPE string.

    lv_char = current( ).
    CASE lv_char.
      WHEN ';'.
        emit_fixed( iv_kind = c_semicolon iv_text = ';' iv_value = ';' ).
      WHEN '('.
        emit_fixed( iv_kind = c_lparen iv_text = '(' iv_value = '(' ).
      WHEN ')'.
        emit_fixed( iv_kind = c_rparen iv_text = ')' iv_value = ')' ).
      WHEN ','.
        emit_fixed( iv_kind = c_comma iv_text = ',' iv_value = ',' ).
      WHEN '.'.
        emit_fixed( iv_kind = c_dot iv_text = '.' iv_value = '.' ).
    ENDCASE.
  ENDMETHOD.

  METHOD scan_operator.
    DATA lv_char TYPE string.

    lv_char = current( ).
    IF lv_char = '-'.
      IF peek( 1 ) = '>'.
        IF peek( 2 ) = '>'.
          emit_fixed( iv_kind = c_operator iv_text = '->>' iv_value = '->>' ).
        ELSE.
          emit_fixed( iv_kind = c_operator iv_text = '->' iv_value = '->' ).
        ENDIF.
      ELSE.
        emit_fixed( iv_kind = c_operator iv_text = '-' iv_value = '-' ).
      ENDIF.
    ELSEIF lv_char = '=' AND peek( 1 ) = '='.
      emit_fixed( iv_kind = c_operator iv_text = '==' iv_value = '==' ).
    ELSEIF lv_char = '!' AND peek( 1 ) = '='.
      emit_fixed( iv_kind = c_operator iv_text = '!=' iv_value = '!=' ).
    ELSEIF lv_char = '<' AND peek( 1 ) = '='.
      emit_fixed( iv_kind = c_operator iv_text = '<=' iv_value = '<=' ).
    ELSEIF lv_char = '<' AND peek( 1 ) = '>'.
      emit_fixed( iv_kind = c_operator iv_text = '<>' iv_value = '<>' ).
    ELSEIF lv_char = '<' AND peek( 1 ) = '<'.
      emit_fixed( iv_kind = c_operator iv_text = '<<' iv_value = '<<' ).
    ELSEIF lv_char = '>' AND peek( 1 ) = '='.
      emit_fixed( iv_kind = c_operator iv_text = '>=' iv_value = '>=' ).
    ELSEIF lv_char = '>' AND peek( 1 ) = '>'.
      emit_fixed( iv_kind = c_operator iv_text = '>>' iv_value = '>>' ).
    ELSEIF lv_char = '|' AND peek( 1 ) = '|'.
      emit_fixed( iv_kind = c_operator iv_text = '||' iv_value = '||' ).
    ELSEIF lv_char = '!'.
      emit_fixed( iv_kind = c_illegal iv_text = '!' iv_value = '!' ).
    ELSE.
      emit_fixed( iv_kind = c_operator iv_text = lv_char iv_value = lv_char ).
    ENDIF.
  ENDMETHOD.

  METHOD emit_fixed.
    DATA lv_start TYPE i.
    DATA lv_line TYPE i.
    DATA lv_column TYPE i.

    lv_start = mv_pos.
    lv_line = mv_line.
    lv_column = mv_column.
    DO strlen( iv_text ) TIMES.
      advance( ).
    ENDDO.
    add_token(
      iv_kind = iv_kind
      iv_text = iv_text
      iv_value = iv_value
      iv_offset = lv_start
      iv_line = lv_line
      iv_column = lv_column ).
  ENDMETHOD.

  METHOD add_token.
    DATA ls_token TYPE ty_token.

    ls_token-kind = iv_kind.
    ls_token-text = iv_text.
    ls_token-value = iv_value.
    ls_token-offset = iv_offset.
    ls_token-length = strlen( iv_text ).
    ls_token-line = iv_line.
    ls_token-column = iv_column.
    APPEND ls_token TO mt_tokens.
  ENDMETHOD.

  METHOD token_text.
    DATA lv_length TYPE i.

    lv_length = mv_pos - iv_start.
    IF lv_length <= 0.
      RETURN.
    ENDIF.
    rv_text = substring(
      val = mv_sql
      off = iv_start - 1
      len = lv_length ).
  ENDMETHOD.

  METHOD current.
    rv_char = char_at( mv_pos ).
  ENDMETHOD.

  METHOD peek.
    rv_char = char_at( mv_pos + iv_ahead ).
  ENDMETHOD.

  METHOD char_at.
    IF iv_position < 1 OR iv_position > mv_length.
      RETURN.
    ENDIF.
    rv_char = substring(
      val = mv_sql
      off = iv_position - 1
      len = 1 ).
  ENDMETHOD.

  METHOD advance.
    DATA lv_char TYPE string.

    lv_char = current( ).
    IF lv_char = ''.
      RETURN.
    ENDIF.
    mv_pos = mv_pos + 1.
    IF lv_char = cl_abap_char_utilities=>newline.
      mv_line = mv_line + 1.
      mv_column = 1.
    ELSE.
      mv_column = mv_column + 1.
    ENDIF.
  ENDMETHOD.

  METHOD is_space.
* ANORMALY: comparing a string with a character literal trims trailing blanks,
* so a space must be written as a string literal here, see ANORMALIES.md
    IF iv_char = | |
        OR iv_char = cl_abap_char_utilities=>horizontal_tab
        OR iv_char = cl_abap_char_utilities=>newline
        OR iv_char = cl_abap_char_utilities=>vertical_tab
        OR iv_char = cl_abap_char_utilities=>form_feed
        OR iv_char = cl_abap_char_utilities=>cr_lf+0(1).
      rv_space = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD is_digit.
    IF iv_char >= '0' AND iv_char <= '9'.
      rv_digit = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD is_hex_digit.
    IF is_digit( iv_char ) = abap_true
        OR ( iv_char >= 'a' AND iv_char <= 'f' )
        OR ( iv_char >= 'A' AND iv_char <= 'F' ).
      rv_hex_digit = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD is_identifier_start.
    IF ( iv_char >= 'a' AND iv_char <= 'z' )
        OR ( iv_char >= 'A' AND iv_char <= 'Z' )
        OR iv_char = '_'
        OR is_high_char( iv_char ) = abap_true.
      rv_identifier = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD is_identifier_part.
    IF is_identifier_start( iv_char ) = abap_true
        OR is_digit( iv_char ) = abap_true
        OR iv_char = '$'.
      rv_identifier = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD is_high_char.
    DATA lv_data TYPE xstring.

    IF iv_char = ''.
      RETURN.
    ENDIF.

    TRY.
        lv_data = zcl_sqlite_utf8=>encode( iv_char ).
      CATCH cx_sy_conversion_codepage.
        RETURN.
    ENDTRY.

    IF xstrlen( lv_data ) > 0
        AND zcl_sqlite_bytes=>read_u8(
          iv_data = lv_data iv_offset = 0 ) >= 128.
      rv_high = abap_true.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
