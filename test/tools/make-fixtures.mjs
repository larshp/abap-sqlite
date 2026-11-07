import {mkdir, readFile, rm, writeFile} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import initSqlJs from "sql.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixturesDir = path.resolve(here, "..", "fixtures");
const fixturePrefix = "fixtures/";

const SQL = await initSqlJs();

function quoteIdentifier(name) {
  return `"${name.replaceAll("\"", "\"\"")}"`;
}

function jsonValue(value) {
  if (value instanceof Uint8Array) {
    return {$blob: Buffer.from(value).toString("hex").toUpperCase()};
  }
  return value;
}

function tableInfo(db, name) {
  const result = db.exec(`PRAGMA table_info(${quoteIdentifier(name)})`);
  if (result.length === 0) {
    return [];
  }
  return result[0].values.map(([cid, column, type, notnull, dflt, pk]) => ({
    cid,
    name: column,
    type,
    notnull: notnull === 1,
    default: dflt,
    primary_key: pk,
  }));
}

function tableRows(db, name) {
  const rows = [];
  const statement = db.prepare(`SELECT * FROM ${quoteIdentifier(name)}`);
  while (statement.step()) {
    rows.push(statement.get().map(jsonValue));
  }
  statement.free();
  return rows;
}

function indexColumns(db, name) {
  const result = db.exec(`PRAGMA index_xinfo(${quoteIdentifier(name)})`);
  if (result.length === 0) {
    return {columns: [], auxiliary: []};
  }

  const columns = [];
  const auxiliary = [];
  for (const [, , column, , , key] of result[0].values) {
    if (key === 1) {
      columns.push(column);
    } else if (column !== null) {
      auxiliary.push(column);
    }
  }
  return {columns, auxiliary};
}

function indexes(db) {
  const result = db.exec(`
    SELECT name, tbl_name, sql
    FROM sqlite_master
    WHERE type = 'index' AND sql IS NOT NULL
    ORDER BY name`);
  if (result.length === 0) {
    return [];
  }
  return result[0].values.map(([name, table, sql]) => {
    const {columns, auxiliary} = indexColumns(db, name);
    const entryColumns = auxiliary.length === 0
      ? [...columns, "rowid"]
      : [...columns, ...auxiliary];
    const order = entryColumns
      .map(quoteIdentifier)
      .join(", ");
    const entries = columns.length === 0
      ? []
      : db.exec(
        `SELECT ${order} FROM ${quoteIdentifier(table)} ORDER BY ${order}`,
      )[0]?.values.map((row) => row.map(jsonValue)) ?? [];

    return {
      name,
      table,
      sql,
      columns,
      entries,
    };
  });
}

function pragma(db, name) {
  return db.exec(`PRAGMA ${name}`)[0].values[0][0];
}

function rawSchema(db) {
  const result = db.exec(`
    SELECT type, name, tbl_name, rootpage, sql
    FROM sqlite_schema
    ORDER BY rowid`);
  if (result.length === 0) {
    return [];
  }
  return result[0].values.map(([type, name, tblName, rootpage, sql]) => ({
    type,
    name,
    tbl_name: tblName,
    rootpage,
    sql,
  }));
}

function expectedContents(db) {
  const tables = db.exec(`
    SELECT name, sql
    FROM sqlite_master
    WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
    ORDER BY name`);

  return {
    pragmas: {
      page_size: pragma(db, "page_size"),
      page_count: pragma(db, "page_count"),
      encoding: pragma(db, "encoding"),
      freelist_count: pragma(db, "freelist_count"),
      schema_version: pragma(db, "schema_version"),
      user_version: pragma(db, "user_version"),
      application_id: pragma(db, "application_id"),
      auto_vacuum: pragma(db, "auto_vacuum"),
      journal_mode: pragma(db, "journal_mode"),
    },
    tables: tables.length === 0
      ? []
      : tables[0].values.map(([name, sql]) => ({
        name,
        sql,
        columns: tableInfo(db, name),
        rows: tableRows(db, name),
      })),
    indexes: indexes(db),
    schema: rawSchema(db),
  };
}

function emptyDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 4096");
  db.run("CREATE TABLE scratch (value)");
  db.run("DROP TABLE scratch");
  db.run("VACUUM");
  return db;
}

function smallDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 4096");
  db.run(`
    CREATE TABLE items (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      price REAL
    )`);
  db.run(`
    INSERT INTO items (id, name, price) VALUES
      (1, 'alpha', 1.5),
      (2, 'beta', 2.25),
      (3, 'gamma', NULL)`);
  return db;
}

function threePagesDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 4096");
  db.run("CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT NOT NULL)");

  const insert = db.prepare("INSERT INTO items (id, value) VALUES (?, ?)");
  for (let id = 1; id <= 200; id++) {
    insert.run([id, `value-${String(id).padStart(3, "0")}-${"x".repeat(40)}`]);
  }
  insert.free();
  return db;
}

function indexedDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 4096");
  db.run("CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT NOT NULL)");
  db.run("CREATE INDEX items_value ON items(value)");

  const insert = db.prepare("INSERT INTO items (id, value) VALUES (?, ?)");
  for (let id = 1; id <= 100; id++) {
    insert.run([id, `value-${String(id).padStart(3, "0")}-${"x".repeat(40)}`]);
  }
  insert.free();
  return db;
}

function serialTypesDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 4096");
  db.run(`
    CREATE TABLE serial_types (
      c_null,
      c_int8,
      c_int16,
      c_int24,
      c_int32,
      c_int48,
      c_int64,
      c_real,
      c_zero,
      c_one,
      c_blob0,
      c_text0,
      c_blob3,
      c_text3,
      c_text
    )`);
  db.run(`
    INSERT INTO serial_types VALUES (
      NULL, -1, -129, -32769, -8388609, -2147483649, -140737488355329,
      1.5, 0, 1, x'', '', x'010203', 'abc', 'hello'
    )`);
  db.run(`
    INSERT INTO serial_types VALUES (
      NULL, 127, 32767, 8388607, 2147483647, 140737488355327, 140737488355328,
      -1.5, 0, 1, x'', '', x'040506', 'xyz', 'world'
    )`);
  return db;
}

function tenThousandDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run("CREATE TABLE items (value TEXT NOT NULL)");

  const insert = db.prepare("INSERT INTO items (value) VALUES (?)");
  db.run("BEGIN");
  for (let id = 1; id <= 10000; id++) {
    insert.run([`row-${String(id).padStart(5, "0")}`]);
  }
  insert.free();
  db.run("COMMIT");
  return db;
}

function pageSizeDatabase(pageSize) {
  const db = new SQL.Database();
  db.run(`PRAGMA page_size = ${pageSize}`);
  db.run("CREATE TABLE items (id INTEGER NOT NULL, value TEXT NOT NULL)");
  db.run("CREATE INDEX items_value ON items(value)");

  const insert = db.prepare("INSERT INTO items (id, value) VALUES (?, ?)");
  db.run("BEGIN");
  for (let id = 1; id <= 40; id++) {
    insert.run([
      id,
      `page-${String(pageSize).padStart(5, "0")}-${String(id).padStart(3, "0")}-${"x".repeat(20)}`,
    ]);
  }
  insert.free();
  db.run("COMMIT");
  return db;
}

function freelistDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run("CREATE TABLE keep (id INTEGER NOT NULL, value TEXT NOT NULL)");
  db.run("CREATE INDEX keep_value ON keep(value)");

  const keep = db.prepare("INSERT INTO keep (id, value) VALUES (?, ?)");
  db.run("BEGIN");
  for (let id = 1; id <= 20; id++) {
    keep.run([id, `keep-${String(id).padStart(3, "0")}`]);
  }
  keep.free();
  db.run("COMMIT");

  db.run("CREATE TABLE dropme (value TEXT)");
  const drop = db.prepare("INSERT INTO dropme (value) VALUES (?)");
  db.run("BEGIN");
  for (let id = 1; id <= 500; id++) {
    drop.run([`drop-${id}-${"y".repeat(20)}`]);
  }
  drop.free();
  db.run("COMMIT");
  db.run("DROP TABLE dropme");
  return db;
}

function autoVacuumDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run("PRAGMA auto_vacuum = FULL");
  db.run("CREATE TABLE keep (id INTEGER NOT NULL, value TEXT NOT NULL)");
  db.run("CREATE INDEX keep_value ON keep(value)");

  const keep = db.prepare("INSERT INTO keep (id, value) VALUES (?, ?)");
  db.run("BEGIN");
  for (let id = 1; id <= 20; id++) {
    keep.run([id, `auto-${String(id).padStart(3, "0")}`]);
  }
  keep.free();
  db.run("COMMIT");

  db.run("CREATE TABLE dropme (value TEXT)");
  const drop = db.prepare("INSERT INTO dropme (value) VALUES (?)");
  db.run("BEGIN");
  for (let id = 1; id <= 300; id++) {
    drop.run([`drop-${id}-${"y".repeat(20)}`]);
  }
  drop.free();
  db.run("COMMIT");
  db.run("DROP TABLE dropme");
  return db;
}

function withoutRowidDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run(`
    CREATE TABLE wr (
      k TEXT PRIMARY KEY,
      v TEXT,
      n INTEGER
    ) WITHOUT ROWID`);
  db.run("CREATE INDEX wr_v ON wr(v)");

  const insert = db.prepare("INSERT INTO wr (k, v, n) VALUES (?, ?, ?)");
  db.run("BEGIN");
  for (let id = 1; id <= 40; id++) {
    insert.run([
      `key-${String(id).padStart(3, "0")}`,
      `value-${String(id).padStart(3, "0")}`,
      id,
    ]);
  }
  insert.free();
  db.run("COMMIT");
  return db;
}

function nullsDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run(`
    CREATE TABLE nulls (
      id INTEGER NOT NULL,
      a TEXT,
      b INTEGER,
      c BLOB
    )`);
  db.run("CREATE INDEX nulls_a ON nulls(a)");
  db.run("CREATE INDEX nulls_ab ON nulls(a, b)");
  db.run(`
    INSERT INTO nulls (id, a, b, c) VALUES
      (1, 'a', 1, x'01'),
      (2, NULL, 2, NULL),
      (3, 'a', NULL, x''),
      (4, NULL, NULL, x'03'),
      (5, 'b', 2, NULL)`);
  return db;
}

function orderingDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run(`
    CREATE TABLE ordering (
      id INTEGER NOT NULL,
      grp TEXT,
      val,
      label TEXT
    )`);
  db.run(`
    INSERT INTO ordering (id, grp, val, label) VALUES
      (1, 'a', 2, 'Beta'),
      (2, 'a', NULL, 'alpha'),
      (3, 'a', 10, 'gamma'),
      (4, 'b', 1, 'Alpha'),
      (5, 'b', 1, 'beta'),
      (6, 'b', NULL, 'ALPHA'),
      (7, 'c', '2', 'delta'),
      (8, 'c', 2, 'Delta'),
      (9, NULL, 3, 'epsilon'),
      (10, 'c', 3.5, 'zeta'),
      (11, 'a', 2, 'alpha'),
      (12, 'd', 0, 'same'),
      (13, 'd', 0, 'same '),
      (14, 'b', NULL, 'omega')`);
  return db;
}

function aggregatesDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 1024");
  db.run(`
    CREATE TABLE agg (
      id INTEGER NOT NULL,
      grp TEXT,
      val,
      label TEXT
    )`);
  db.run(`
    INSERT INTO agg (id, grp, val, label) VALUES
      (1, 'a', 2, 'Beta'),
      (2, 'a', NULL, 'alpha'),
      (3, 'a', 10, 'gamma'),
      (4, 'b', 1, 'Alpha'),
      (5, 'b', 1, 'beta'),
      (6, 'b', NULL, 'ALPHA'),
      (7, 'c', '2', 'delta'),
      (8, 'c', 2, 'Delta'),
      (9, NULL, 3, 'epsilon'),
      (10, 'c', 3.5, 'zeta'),
      (11, 'a', 2, 'alpha'),
      (12, 'd', 0, 'same'),
      (13, 'd', 0, 'same '),
      (14, 'b', NULL, 'omega'),
      (15, 'e', 'abc', NULL),
      (16, 'e', 9223372036854775807, 'max'),
      (17, 'e', 1, 'one'),
      (18, 'f', NULL, NULL),
      (19, 'f', '', 'empty')`);
  return db;
}

function joinsDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 1024");
  db.run(`
    CREATE TABLE authors (
      id INTEGER NOT NULL,
      name TEXT
    )`);
  db.run(`
    INSERT INTO authors (id, name) VALUES
      (1, 'Ada'),
      (2, 'Grace'),
      (3, 'Linus'),
      (4, 'Nobody')`);
  db.run(`
    CREATE TABLE books (
      id INTEGER NOT NULL,
      author_id INTEGER,
      title TEXT,
      price
    )`);
  db.run(`
    INSERT INTO books (id, author_id, title, price) VALUES
      (1, 1, 'Alpha', 10),
      (2, 1, 'Beta', 20),
      (3, 2, 'Gamma', NULL),
      (4, NULL, 'Orphan', 5),
      (5, 99, 'Ghost', 7)`);
  db.run(`
    CREATE TABLE orders (
      order_id INTEGER NOT NULL,
      customer_id INTEGER,
      amount
    )`);
  db.run(`
    INSERT INTO orders (order_id, customer_id, amount) VALUES
      (1, 10, 100),
      (2, 10, 50),
      (3, 20, 75),
      (4, 30, 25)`);
  db.run(`
    CREATE TABLE shipments (
      order_id INTEGER NOT NULL,
      carrier TEXT
    )`);
  db.run(`
    INSERT INTO shipments (order_id, carrier) VALUES
      (1, 'UPS'),
      (2, 'DHL'),
      (5, 'FedEx')`);
  return db;
}

function manyIndexesDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 512");
  db.run(`
    CREATE TABLE m (
      id INTEGER NOT NULL,
      a TEXT NOT NULL,
      b INTEGER NOT NULL,
      c TEXT NOT NULL
    )`);
  db.run("CREATE INDEX m_a ON m(a)");
  db.run("CREATE INDEX m_ab ON m(a, b)");
  db.run("CREATE INDEX m_ba ON m(b, a)");
  db.run("CREATE INDEX m_b ON m(b)");
  db.run("CREATE INDEX m_c ON m(c)");
  db.run(`
    INSERT INTO m (id, a, b, c) VALUES
      (1, 'a', 1, 'c1'),
      (2, 'a', 2, 'c2'),
      (3, 'b', 1, 'c3'),
      (4, 'b', 2, 'c4'),
      (5, 'a', 1, 'c5'),
      (6, 'b', 2, 'c6')`);
  return db;
}

function overflowDatabase() {
  const db = new SQL.Database();
  db.run("PRAGMA page_size = 4096");
  db.run("CREATE TABLE payloads (name TEXT NOT NULL, value)");

  const blobMulti = new Uint8Array(Buffer.from(
    "00112233445566778899AABBCCDDEEFF".repeat(750),
    "hex",
  ));

  const insert = db.prepare("INSERT INTO payloads (name, value) VALUES (?, ?)");
  insert.run(["text_near", "T".repeat(4100)]);
  insert.run(["blob_near", new Uint8Array(4100).fill(0xAB)]);
  insert.run(["text_multi", "0123456789".repeat(1200)]);
  insert.run(["blob_multi", blobMulti]);
  insert.free();
  return db;
}

const queryDefinitions = [
  {
    name: "small.select_all",
    database: "small.db",
    sql: "SELECT id, name, price FROM items",
  },
  {
    name: "small.arithmetic_filter",
    database: "small.db",
    sql: "SELECT id, price + 1 FROM items WHERE id > 1",
  },
  {
    name: "small.star_where_text",
    database: "small.db",
    sql: "SELECT * FROM items WHERE name = 'beta'",
  },
  {
    name: "small.qualified_star",
    database: "small.db",
    sql: "SELECT items.* FROM items WHERE id = 2",
  },
  {
    name: "small.table_alias",
    database: "small.db",
    sql: "SELECT i.name FROM items AS i WHERE i.id = 1",
  },
  {
    name: "small.rowid",
    database: "small.db",
    sql: "SELECT rowid AS rid, id FROM items WHERE id = 2",
  },
  {
    name: "small.real_compare",
    database: "small.db",
    sql: "SELECT id, name FROM items WHERE price > 2",
  },
  {
    name: "small.null_filter",
    database: "small.db",
    sql: "SELECT id FROM items WHERE price IS NULL",
  },
  {
    name: "small.not_filter",
    database: "small.db",
    sql: "SELECT id FROM items WHERE NOT (id = 1)",
  },
  {
    name: "small.or_filter",
    database: "small.db",
    sql: "SELECT id FROM items WHERE id = 1 OR name = 'gamma'",
  },
  {
    name: "small.between",
    database: "small.db",
    sql: "SELECT id FROM items WHERE id BETWEEN 2 AND 3",
  },
  {
    name: "small.in_list",
    database: "small.db",
    sql: "SELECT id FROM items WHERE name IN ('alpha', 'gamma')",
  },
  {
    name: "small.like",
    database: "small.db",
    sql: "SELECT id, name FROM items WHERE name LIKE 'a%'",
  },
  {
    name: "small.glob",
    database: "small.db",
    sql: "SELECT id, name FROM items WHERE name GLOB 'b*'",
  },
  {
    name: "small.glob_case_sensitive",
    database: "small.db",
    sql: "SELECT id FROM items WHERE name GLOB 'A*'",
  },
  {
    name: "small.nocase",
    database: "small.db",
    sql: "SELECT id FROM items WHERE name = 'ALPHA' COLLATE NOCASE",
  },
  {
    name: "small.rtrim",
    database: "small.db",
    sql: "SELECT id FROM items WHERE name = 'alpha  ' COLLATE RTRIM",
  },
  {
    name: "small.concat",
    database: "small.db",
    sql: "SELECT id, name || ':' || id FROM items WHERE id < 3",
  },
  {
    name: "small.unary",
    database: "small.db",
    sql: "SELECT id, -price FROM items WHERE price IS NOT NULL",
  },
  {
    name: "small.bitwise",
    database: "small.db",
    sql: "SELECT id, id << 2 FROM items WHERE id = 3",
  },
  {
    name: "small.case",
    database: "small.db",
    sql: "SELECT id, CASE WHEN price IS NULL THEN 'missing' ELSE name END FROM items",
  },
  {
    name: "small.cast_text",
    database: "small.db",
    sql: "SELECT id, CAST(price AS TEXT) FROM items WHERE id = 1",
  },
  {
    name: "small.empty",
    database: "small.db",
    sql: "SELECT id, name FROM items WHERE id > 99",
  },
  {
    name: "small.constant_integer",
    database: "small.db",
    sql: "SELECT 1 + 1",
  },
  {
    name: "small.constant_real",
    database: "small.db",
    sql: "SELECT 1.5 + 2.5",
  },
  {
    name: "small.constant_text",
    database: "small.db",
    sql: "SELECT 'abc' || 'def'",
  },
  {
    name: "small.constant_blob",
    database: "small.db",
    sql: "SELECT x'4142'",
  },
  {
    name: "small.constant_null",
    database: "small.db",
    sql: "SELECT NULL",
  },
  {
    name: "nulls.select_all",
    database: "nulls.db",
    sql: "SELECT id, a, b, c FROM nulls",
  },
  {
    name: "nulls.is_null",
    database: "nulls.db",
    sql: "SELECT id FROM nulls WHERE a IS NULL AND id = 2",
  },
  {
    name: "nulls.in_with_null",
    database: "nulls.db",
    sql: "SELECT id FROM nulls WHERE b IN (1, NULL)",
  },
  {
    name: "serial_types.mixed",
    database: "serial_types.db",
    sql: "SELECT c_int8, c_real, c_text3, c_blob3 FROM serial_types",
  },
  {
    name: "without_rowid.scan",
    database: "without_rowid.db",
    sql: "SELECT k, v, n FROM wr WHERE n > 38",
  },
  {
    name: "without_rowid.range",
    database: "without_rowid.db",
    sql: "SELECT k, v FROM wr WHERE v >= 'value-038'",
  },
  {
    name: "many_indexes.filter",
    database: "many_indexes.db",
    sql: "SELECT id, a, b FROM m WHERE a = 'b' AND b = 2",
  },
  {
    name: "functions.numeric",
    database: "small.db",
    sql: `SELECT
      abs(-3) AS a1,
      abs(-3.5) AS a2,
      abs('-4x') AS a3,
      abs(NULL) AS a4,
      round(2.5) AS a5,
      round(-2.5) AS a6,
      round(123.456, 2) AS a7,
      round(123.456, -1) AS a8,
      round(1, 2) AS a9,
      round(NULL, 2) AS a10,
      min(3, 1, 2) AS a11,
      max(3, 1, 2) AS a12,
      min('2', 10) AS a13,
      max('2', 10) AS a14,
      min(1, 1.0) AS a15,
      max(1, 1.0) AS a16,
      min(NULL, 1) AS a17,
      max('a', 'B', 'b') AS a18`,
  },
  {
    name: "functions.text",
    database: "small.db",
    sql: `SELECT
      length('abc') AS b1,
      length('') AS b2,
      length(12345) AS b3,
      length(1.0) AS b4,
      length(x'000102') AS b5,
      lower('AbC') AS b6,
      lower('ÄÖÜ') AS b7,
      lower(123) AS b8,
      upper('Abc') AS b9,
      upper('äöü') AS b10,
      substr('abcdef', 2) AS b11,
      substr('abcdef', 2, 3) AS b12,
      substr('abcdef', -2) AS b13,
      substr('abcdef', -2, 1) AS b14,
      substr('abcdef', 2, -1) AS b15,
      substr('abcdef', 0, 2) AS b16,
      substr('abcdef', 1, 0) AS b17,
      substr('abcdef', 1, 100) AS b18,
      substr('abcdef', 10, 2) AS b19,
      substr(NULL, 1) AS b20,
      substr(12345, 2, 2) AS b21`,
  },
  {
    name: "functions.conditional",
    database: "small.db",
    sql: `SELECT
      coalesce(NULL, NULL, 3) AS c1,
      coalesce(NULL, 'x') AS c2,
      ifnull(NULL, 2) AS c3,
      ifnull(1, 2) AS c4,
      nullif(1, 1) AS c5,
      nullif(1, 2) AS c6,
      nullif(NULL, NULL) AS c7,
      iif(1, 'yes', 'no') AS c8,
      iif(0, 'yes', 'no') AS c9,
      iif(NULL, 'yes', 'no') AS c10,
      iif('x', 1, 2) AS c11,
      typeof(NULL) AS c12,
      typeof(1) AS c13,
      typeof(1.5) AS c14,
      typeof('x') AS c15,
      typeof(x'00') AS c16,
      typeof(abs('3')) AS c17,
      typeof(random()) AS c18`,
  },
  {
    name: "functions.trim_replace",
    database: "small.db",
    sql: `SELECT
      trim('  abc  ') AS d1,
      trim('xxabcxx', 'x') AS d2,
      ltrim('xxabc', 'x') AS d3,
      rtrim('abcxx', 'x') AS d4,
      trim('abc', '') AS d5,
      trim(NULL, 'x') AS d6,
      trim(123, '2') AS d7,
      replace('abcabc', 'ab', 'X') AS d8,
      replace('abc', '', 'X') AS d9,
      replace(NULL, 'a', 'b') AS d10,
      replace('abc', NULL, 'b') AS d11,
      replace('abc', 'b', NULL) AS d12`,
  },
  {
    name: "functions.instr_hex_quote",
    database: "small.db",
    sql: `SELECT
      instr('abcdef', 'cd') AS e1,
      instr('abcdef', 'zz') AS e2,
      instr('abc', '') AS e3,
      instr('', '') AS e4,
      instr(NULL, 'a') AS e5,
      instr('abc', NULL) AS e6,
      instr(12345, 34) AS e7,
      hex('abc') AS e8,
      hex(x'0001AB') AS e9,
      hex(123) AS e10,
      hex(1.5) AS e11,
      hex(NULL) AS e12,
      quote(NULL) AS e13,
      quote(123) AS e14,
      quote(1.5) AS e15,
      quote('abc') AS e16,
      quote(x'00AB') AS e17,
      quote('a''b') AS e18`,
  },
  {
    name: "functions.blobs",
    database: "small.db",
    sql: `SELECT
      substr(x'00010203', 2, 2) AS f1,
      substr(x'00010203', -2) AS f2,
      length(x'00010203') AS f3,
      lower(x'4142') AS f4,
      upper(x'6162') AS f5,
      trim(x'20612020') AS f6,
      replace(x'616263', x'62', x'58') AS f7,
      instr(x'00010203', x'0102') AS f8,
      instr(x'00010203', x'') AS f9,
      hex(x'00AB') AS f10,
      quote(x'00AB') AS f11,
      typeof(x'00') AS f12`,
  },
  {
    name: "functions.unicode",
    database: "small.db",
    sql: `SELECT
      length('ä€😀') AS g1,
      substr('ä€😀', 1, 1) AS g2,
      substr('ä€😀', 2, 1) AS g3,
      substr('ä€😀', 3, 1) AS g4,
      length('😀') AS g5,
      lower('Ä') AS g6,
      upper('ä') AS g7,
      hex('ä') AS g8,
      instr('a😀b', 'b') AS g9`,
  },
  {
    name: "ordering.multi_key",
    database: "ordering.db",
    sql: "SELECT id, grp, val FROM ordering ORDER BY grp, val, id",
  },
  {
    name: "ordering.desc_default_nulls",
    database: "ordering.db",
    sql: "SELECT id, val FROM ordering ORDER BY val DESC, id",
  },
  {
    name: "ordering.nulls_last_asc",
    database: "ordering.db",
    sql: "SELECT id, val FROM ordering ORDER BY val ASC NULLS LAST, id",
  },
  {
    name: "ordering.nulls_first_desc",
    database: "ordering.db",
    sql: "SELECT id, val FROM ordering ORDER BY val DESC NULLS FIRST, id",
  },
  {
    name: "ordering.collation_nocase",
    database: "ordering.db",
    sql: "SELECT id, label FROM ordering ORDER BY label COLLATE NOCASE, id",
  },
  {
    name: "ordering.collation_rtrim",
    database: "ordering.db",
    sql: "SELECT id, label FROM ordering WHERE grp = 'd' ORDER BY label COLLATE RTRIM, id DESC",
  },
  {
    name: "ordering.ordinal",
    database: "ordering.db",
    sql: "SELECT id, label FROM ordering WHERE grp = 'a' ORDER BY 2, 1",
  },
  {
    name: "ordering.alias",
    database: "ordering.db",
    sql: "SELECT id, lower(label) AS l FROM ordering WHERE grp = 'b' ORDER BY l, id",
  },
  {
    name: "ordering.hidden_expr",
    database: "ordering.db",
    sql: "SELECT id, label FROM ordering WHERE grp = 'a' ORDER BY length(label), id",
  },
  {
    name: "ordering.qualified_hidden",
    database: "ordering.db",
    sql: "SELECT o.id FROM ordering AS o ORDER BY o.grp, o.id",
  },
  {
    name: "ordering.expression_key",
    database: "ordering.db",
    sql: "SELECT id, val FROM ordering WHERE grp = 'a' ORDER BY val IS NULL, val, id",
  },
  {
    name: "ordering.stable",
    database: "ordering.db",
    sql: "SELECT id, grp FROM ordering ORDER BY grp",
  },
  {
    name: "ordering.limit_offset",
    database: "ordering.db",
    sql: "SELECT id FROM ordering ORDER BY id LIMIT 4 OFFSET 2",
  },
  {
    name: "ordering.limit_comma",
    database: "ordering.db",
    sql: "SELECT id FROM ordering ORDER BY id LIMIT 2, 3",
  },
  {
    name: "ordering.limit_expr",
    database: "ordering.db",
    sql: "SELECT id FROM ordering WHERE grp = 'a' ORDER BY id LIMIT 2 + 1",
  },
  {
    name: "ordering.limit_text",
    database: "ordering.db",
    sql: "SELECT id FROM ordering WHERE grp = 'a' ORDER BY id LIMIT ' 2 '",
  },
  {
    name: "ordering.limit_real",
    database: "ordering.db",
    sql: "SELECT id FROM ordering WHERE grp = 'a' ORDER BY id LIMIT 2.0",
  },
  {
    name: "ordering.negative_limit",
    database: "ordering.db",
    sql: "SELECT id FROM ordering WHERE grp = 'a' ORDER BY id LIMIT -1 OFFSET 1",
  },
  {
    name: "ordering.negative_offset",
    database: "ordering.db",
    sql: "SELECT id FROM ordering WHERE grp = 'a' ORDER BY id LIMIT 2 OFFSET -1",
  },
  {
    name: "ordering.limit_zero",
    database: "ordering.db",
    sql: "SELECT id FROM ordering ORDER BY id LIMIT 0",
  },
  {
    name: "ordering.offset_beyond",
    database: "ordering.db",
    sql: "SELECT id FROM ordering ORDER BY id LIMIT 5 OFFSET 100",
  },
  {
    name: "ordering.distinct",
    database: "ordering.db",
    sql: "SELECT DISTINCT grp, val FROM ordering ORDER BY grp, val",
  },
  {
    name: "ordering.distinct_alias",
    database: "ordering.db",
    sql: "SELECT DISTINCT grp AS g, val FROM ordering ORDER BY g, val",
  },
  {
    name: "ordering.distinct_limit",
    database: "ordering.db",
    sql: "SELECT DISTINCT grp, val FROM ordering ORDER BY grp, val LIMIT 3 OFFSET 1",
  },
  {
    name: "aggregates.count_all",
    database: "aggregates.db",
    sql: "SELECT count(*), count(val), count(label) FROM agg",
  },
  {
    name: "aggregates.numeric",
    database: "aggregates.db",
    sql: "SELECT sum(val), total(val), avg(val), min(val), max(val) FROM agg",
  },
  {
    name: "aggregates.distinct_values",
    database: "aggregates.db",
    sql: "SELECT count(DISTINCT grp), count(DISTINCT val), count(DISTINCT label) FROM agg",
  },
  {
    name: "aggregates.numeric_distinct",
    database: "aggregates.db",
    sql: "SELECT sum(DISTINCT val), total(DISTINCT val), avg(DISTINCT val), min(DISTINCT val), max(DISTINCT val) FROM agg",
  },
  {
    name: "aggregates.empty_input",
    database: "aggregates.db",
    sql: "SELECT count(*), count(val), sum(val), total(val), avg(val), min(val), max(val), group_concat(label) FROM agg WHERE id > 99",
  },
  {
    name: "aggregates.group_summary",
    database: "aggregates.db",
    sql: "SELECT grp, count(*), count(val), sum(val), total(val), avg(val), min(val), max(val) FROM agg GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.group_concat",
    database: "aggregates.db",
    sql: "SELECT grp, group_concat(label), group_concat(DISTINCT label), group_concat(val, '|') FROM agg GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.group_concat_empty",
    database: "aggregates.db",
    sql: "SELECT group_concat(label), group_concat(label, '-') FROM agg WHERE grp = 'f'",
  },
  {
    name: "aggregates.having_aggregate",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) FROM agg GROUP BY grp HAVING count(*) > 3 ORDER BY grp",
  },
  {
    name: "aggregates.having_sum",
    database: "aggregates.db",
    sql: "SELECT grp, sum(val) FROM agg GROUP BY grp HAVING sum(val) > 3 ORDER BY grp",
  },
  {
    name: "aggregates.having_alias",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) AS c FROM agg GROUP BY grp HAVING c > 3 ORDER BY grp",
  },
  {
    name: "aggregates.having_no_group",
    database: "aggregates.db",
    sql: "SELECT count(*) FROM agg HAVING count(*) > 1",
  },
  {
    name: "aggregates.having_no_rows",
    database: "aggregates.db",
    sql: "SELECT count(*) FROM agg HAVING count(*) > 100",
  },
  {
    name: "aggregates.group_bare",
    database: "aggregates.db",
    sql: "SELECT grp, label FROM agg GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.group_expression",
    database: "aggregates.db",
    sql: "SELECT length(label), count(*) FROM agg WHERE label IS NOT NULL GROUP BY length(label) ORDER BY 1",
  },
  {
    name: "aggregates.group_ordinal",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) FROM agg GROUP BY 1 ORDER BY 1",
  },
  {
    name: "aggregates.group_alias",
    database: "aggregates.db",
    sql: "SELECT lower(grp) AS g, count(*) FROM agg GROUP BY g ORDER BY g",
  },
  {
    name: "aggregates.order_hidden",
    database: "aggregates.db",
    sql: "SELECT grp FROM agg GROUP BY grp ORDER BY count(*) DESC, grp",
  },
  {
    name: "aggregates.order_alias",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) AS c FROM agg GROUP BY grp ORDER BY c DESC, grp",
  },
  {
    name: "aggregates.order_ordinal",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) FROM agg GROUP BY grp ORDER BY 2 DESC, 1",
  },
  {
    name: "aggregates.limit",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) FROM agg GROUP BY grp ORDER BY 2 DESC, 1 LIMIT 3",
  },
  {
    name: "aggregates.sum_overflow",
    database: "aggregates.db",
    sql: "SELECT sum(val), total(val) FROM agg WHERE grp = 'e'",
  },
  {
    name: "aggregates.text_numeric",
    database: "aggregates.db",
    sql: "SELECT sum(val), total(val), avg(val) FROM agg WHERE grp = 'c'",
  },
  {
    name: "aggregates.minmax_text",
    database: "aggregates.db",
    sql: "SELECT grp, min(label), max(label) FROM agg GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.minmax_nocase",
    database: "aggregates.db",
    sql: "SELECT min(label COLLATE NOCASE), max(label COLLATE NOCASE) FROM agg WHERE grp = 'b'",
  },
  {
    name: "aggregates.concat_global_distinct",
    database: "aggregates.db",
    sql: "SELECT group_concat(DISTINCT grp) FROM agg",
  },
  {
    name: "aggregates.constant",
    database: "aggregates.db",
    sql: "SELECT count(*), count(1), sum(2), total(2), avg(2), min(3), max(4), group_concat('x')",
  },
  {
    name: "aggregates.group_filtered",
    database: "aggregates.db",
    sql: "SELECT grp, count(*) FROM agg WHERE val > 1 GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.having_unselected",
    database: "aggregates.db",
    sql: "SELECT grp FROM agg GROUP BY grp HAVING count(*) > 2 ORDER BY grp",
  },
  {
    name: "aggregates.expression",
    database: "aggregates.db",
    sql: "SELECT grp, sum(val) * 2 FROM agg GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.scalar_wrap",
    database: "aggregates.db",
    sql: "SELECT grp, abs(sum(val)) FROM agg GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.distinct_result",
    database: "aggregates.db",
    sql: "SELECT DISTINCT grp FROM agg WHERE grp IS NOT NULL GROUP BY grp ORDER BY grp",
  },
  {
    name: "aggregates.count_constant",
    database: "aggregates.db",
    sql: "SELECT count(1), count(NULL) FROM agg",
  },
  {
    name: "aggregates.total_empty",
    database: "aggregates.db",
    sql: "SELECT total(val), sum(val), avg(val) FROM agg WHERE id > 99",
  },
  {
    name: "joins.inner_on",
    database: "joins.db",
    sql: "SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id ORDER BY b.id",
  },
  {
    name: "joins.inner_qualified_star",
    database: "joins.db",
    sql: "SELECT a.*, b.title FROM authors a JOIN books b ON a.id = b.author_id ORDER BY b.id",
  },
  {
    name: "joins.inner_columns",
    database: "joins.db",
    sql: "SELECT a.id AS author_id, a.name AS author_name, b.id AS book_id, b.author_id AS book_author_id, b.title, b.price FROM authors a JOIN books b ON a.id = b.author_id ORDER BY b.id",
  },
  {
    name: "joins.left_on",
    database: "joins.db",
    sql: "SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id ORDER BY a.id, b.id",
  },
  {
    name: "joins.left_columns",
    database: "joins.db",
    sql: "SELECT a.id AS author_id, a.name AS author_name, b.id AS book_id, b.author_id AS book_author_id, b.title, b.price FROM authors a LEFT JOIN books b ON a.id = b.author_id ORDER BY a.id, b.id",
  },
  {
    name: "joins.cross",
    database: "joins.db",
    sql: "SELECT a.name, b.title FROM authors a CROSS JOIN books b WHERE a.id = 1 ORDER BY b.id",
  },
  {
    name: "joins.cross_star_unique",
    database: "joins.db",
    sql: "SELECT * FROM authors CROSS JOIN shipments WHERE authors.id = 1 ORDER BY shipments.order_id",
  },
  {
    name: "joins.left_star_unique",
    database: "joins.db",
    sql: "SELECT * FROM authors LEFT JOIN shipments ON authors.id = shipments.order_id ORDER BY authors.id",
  },
  {
    name: "joins.comma",
    database: "joins.db",
    sql: "SELECT a.name, b.title FROM authors a, books b WHERE a.id = b.author_id ORDER BY b.id",
  },
  {
    name: "joins.using_star",
    database: "joins.db",
    sql: "SELECT * FROM orders JOIN shipments USING (order_id) ORDER BY order_id",
  },
  {
    name: "joins.using_qualified",
    database: "joins.db",
    sql: "SELECT orders.order_id AS order_key, shipments.order_id AS shipment_key, orders.amount, shipments.carrier FROM orders JOIN shipments USING (order_id) ORDER BY orders.order_id",
  },
  {
    name: "joins.using_left",
    database: "joins.db",
    sql: "SELECT * FROM orders LEFT JOIN shipments USING (order_id) ORDER BY order_id",
  },
  {
    name: "joins.natural_star",
    database: "joins.db",
    sql: "SELECT * FROM orders NATURAL JOIN shipments ORDER BY order_id",
  },
  {
    name: "joins.natural_left",
    database: "joins.db",
    sql: "SELECT * FROM orders NATURAL LEFT JOIN shipments ORDER BY order_id",
  },
  {
    name: "joins.group",
    database: "joins.db",
    sql: "SELECT a.name, count(*), sum(b.price) FROM authors a JOIN books b ON a.id = b.author_id GROUP BY a.name ORDER BY a.name",
  },
  {
    name: "joins.aggregate_left",
    database: "joins.db",
    sql: "SELECT a.name, count(b.id), sum(b.price) FROM authors a LEFT JOIN books b ON a.id = b.author_id GROUP BY a.name ORDER BY a.name",
  },
  {
    name: "joins.distinct",
    database: "joins.db",
    sql: "SELECT DISTINCT a.name FROM authors a JOIN books b ON a.id = b.author_id ORDER BY a.name",
  },
  {
    name: "joins.order_hidden",
    database: "joins.db",
    sql: "SELECT a.name FROM authors a JOIN books b ON a.id = b.author_id ORDER BY b.id DESC LIMIT 2",
  },
  {
    name: "joins.where",
    database: "joins.db",
    sql: "SELECT b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE b.price > 15 ORDER BY b.id",
  },
  {
    name: "joins.self",
    database: "joins.db",
    sql: "SELECT e.name AS employee, m.name AS manager FROM authors e JOIN authors m ON e.id = m.id + 1 ORDER BY e.id",
  },
  {
    name: "joins.qualified_where",
    database: "joins.db",
    sql: "SELECT b.title FROM authors AS a INNER JOIN books AS b ON a.id = b.author_id WHERE a.name = 'Ada' ORDER BY b.id",
  },
  {
    name: "joins.cross_count",
    database: "joins.db",
    sql: "SELECT count(*) FROM authors CROSS JOIN books",
  },
  {
    name: "joins.left_where_is_null",
    database: "joins.db",
    sql: "SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id WHERE b.id IS NULL ORDER BY a.id",
  },
  {
    name: "joins.using_where",
    database: "joins.db",
    sql: "SELECT * FROM orders JOIN shipments USING (order_id) WHERE amount > 60 ORDER BY order_id",
  },
  {
    name: "joins.natural_qualified",
    database: "joins.db",
    sql: "SELECT shipments.carrier FROM orders NATURAL JOIN shipments ORDER BY order_id",
  },
];

// Deterministic bulk cases keep the differential corpus broad enough to catch
// planner regressions across every fixture. ORDER BY makes the row order part
// of the expected result, rather than depending on the access path.
function addGeneratedQueries() {
  const add = (name, database, sql) => queryDefinitions.push({
    name: `generated.${name}`,
    database,
    sql,
  });

  const comparisonOperators = ["=", "<", ">"];

  for (const [operatorIndex, operator] of comparisonOperators.entries()) {
    for (const [valueIndex, value] of ["a", "b", "z"].entries()) {
      add(
        `many_a_${operatorIndex}_${valueIndex}`,
        "many_indexes.db",
        `SELECT id, a, b, c FROM m WHERE a ${operator} '${value}' ORDER BY id`,
      );
    }
  }
  for (const [operatorIndex, operator] of comparisonOperators.entries()) {
    for (const [valueIndex, value] of [1, 2, 3].entries()) {
      add(
        `many_b_${operatorIndex}_${valueIndex}`,
        "many_indexes.db",
        `SELECT id, a, b, c FROM m WHERE b ${operator} ${value} ORDER BY id`,
      );
    }
  }
  for (const [valueIndex, value] of ["c1", "c4", "z"].entries()) {
    add(
      `many_c_${valueIndex}`,
      "many_indexes.db",
      `SELECT id, a, c FROM m WHERE c = '${value}' ORDER BY id`,
    );
  }
  [
    "SELECT id FROM m WHERE a = 'a' AND b > 0 ORDER BY id",
    "SELECT id FROM m WHERE a = 'a' AND b >= 2 ORDER BY id",
    "SELECT id FROM m WHERE a = 'b' AND b < 3 ORDER BY id",
    "SELECT id FROM m WHERE a > 'a' AND b < 3 ORDER BY id",
    "SELECT id FROM m WHERE b = 2 AND a = 'b' ORDER BY id",
    "SELECT id FROM m WHERE a = 'a' OR b = 2 ORDER BY id",
    "SELECT rowid AS rid, id FROM m WHERE rowid = 3",
    "SELECT rowid AS rid, id FROM m WHERE rowid > 4 ORDER BY id",
    "SELECT rowid AS rid, id FROM m WHERE rowid BETWEEN 2 AND 5 ORDER BY id",
  ].forEach((sql, index) => add(`many_combo_${index}`, "many_indexes.db", sql));

  for (const [operatorIndex, operator] of ["=", "<", "<=", ">", ">="].entries()) {
    for (const [valueIndex, value] of [0, 1, 2, 3].entries()) {
      add(
        `small_id_${operatorIndex}_${valueIndex}`,
        "small.db",
        `SELECT id, name FROM items WHERE id ${operator} ${value} ORDER BY id`,
      );
    }
  }

  [
    "SELECT id, a, b FROM nulls WHERE a IS NULL ORDER BY id",
    "SELECT id, a, b FROM nulls WHERE a IS NOT NULL ORDER BY id",
    "SELECT id, a, b FROM nulls WHERE b IS NULL ORDER BY id",
    "SELECT id, a, b FROM nulls WHERE b IS NOT NULL ORDER BY id",
    "SELECT id, a, c FROM nulls WHERE c IS NULL ORDER BY id",
    "SELECT id, a, c FROM nulls WHERE c IS NOT NULL ORDER BY id",
    "SELECT id, a FROM nulls WHERE a = 'x' ORDER BY id",
    "SELECT id, a FROM nulls WHERE a = 'a' ORDER BY id",
    "SELECT id, a FROM nulls WHERE a < 'b' ORDER BY id",
    "SELECT id, a FROM nulls WHERE a >= 'b' ORDER BY id",
    "SELECT id, b FROM nulls WHERE b = 1 ORDER BY id",
    "SELECT id, b FROM nulls WHERE b < 2 ORDER BY id",
    "SELECT id, b FROM nulls WHERE b >= 2 ORDER BY id",
    "SELECT id FROM nulls WHERE a IS NULL AND id = 2",
    "SELECT id FROM nulls WHERE a IS NOT NULL AND b = 1 ORDER BY id",
    "SELECT id, a, b FROM nulls ORDER BY a, id",
    "SELECT id, b FROM nulls ORDER BY b DESC, id",
    "SELECT id, c FROM nulls ORDER BY c, id",
    "SELECT id FROM nulls ORDER BY id DESC LIMIT 3",
  ].forEach((sql, index) => add(`nulls_${index}`, "nulls.db", sql));

  [
    "SELECT id, grp FROM ordering WHERE grp = 'a' ORDER BY id",
    "SELECT id, grp FROM ordering WHERE grp = 'b' ORDER BY id",
    "SELECT id, grp FROM ordering WHERE grp = 'c' ORDER BY id",
    "SELECT id, grp FROM ordering WHERE grp = 'd' ORDER BY id",
    "SELECT id, grp FROM ordering WHERE grp = 'e' ORDER BY id",
    "SELECT id, val FROM ordering WHERE val IS NULL ORDER BY id",
    "SELECT id, val FROM ordering WHERE val IS NOT NULL ORDER BY id",
    "SELECT id, val FROM ordering WHERE val < 10 ORDER BY id",
    "SELECT id, val FROM ordering WHERE val >= 10 ORDER BY id",
    "SELECT id, val FROM ordering WHERE val BETWEEN 5 AND 15 ORDER BY id",
    "SELECT id, label FROM ordering WHERE label = 'Beta' ORDER BY id",
    "SELECT id, grp FROM ordering ORDER BY grp, id LIMIT 5",
    "SELECT id, val FROM ordering ORDER BY val DESC, id LIMIT 5",
    "SELECT id, label FROM ordering ORDER BY label, id LIMIT 5",
    "SELECT id FROM ordering ORDER BY id DESC LIMIT 3 OFFSET 2",
    "SELECT id FROM ordering WHERE grp = 'a' AND val IS NULL ORDER BY id",
    "SELECT id FROM ordering WHERE grp = 'a' OR grp = 'b' ORDER BY id",
    "SELECT id, val FROM ordering ORDER BY val IS NULL, val, id",
    "SELECT id, label FROM ordering ORDER BY label COLLATE NOCASE, id",
    "SELECT id, label FROM ordering ORDER BY label DESC, id",
  ].forEach((sql, index) => add(`ordering_${index}`, "ordering.db", sql));

  [
    "SELECT grp, count(*) AS n FROM agg GROUP BY grp ORDER BY grp",
    "SELECT grp, count(val) AS n FROM agg GROUP BY grp ORDER BY grp",
    "SELECT grp, sum(val) AS s FROM agg GROUP BY grp ORDER BY grp",
    "SELECT grp, avg(val) AS a FROM agg GROUP BY grp ORDER BY grp",
    "SELECT grp, min(val) AS mn, max(val) AS mx FROM agg GROUP BY grp ORDER BY grp",
    "SELECT count(*) AS n, count(val) AS c FROM agg",
    "SELECT grp, count(*) AS n FROM agg GROUP BY grp HAVING count(*) > 1 ORDER BY grp",
    "SELECT DISTINCT grp FROM agg ORDER BY grp",
    "SELECT count(*) AS n FROM agg WHERE grp = 'a'",
    "SELECT sum(val) AS s FROM agg WHERE val > 5",
    "SELECT min(val) AS mn, max(val) AS mx FROM agg WHERE val IS NOT NULL",
    "SELECT count(*) AS n FROM agg WHERE val IS NULL",
    "SELECT avg(val) AS a FROM agg WHERE val > 5",
    "SELECT grp, max(label) AS mx FROM agg GROUP BY grp ORDER BY grp",
  ].forEach((sql, index) => add(`aggregates_${index}`, "aggregates.db", sql));

  for (const [operatorIndex, operator] of ["=", "<", "<=", ">", ">="].entries()) {
    for (const [valueIndex, value] of ["key-001", "key-020"].entries()) {
      add(
        `without_k_${operatorIndex}_${valueIndex}`,
        "without_rowid.db",
        `SELECT k, v, n FROM wr WHERE k ${operator} '${value}' ORDER BY k`,
      );
    }
  }
  for (const [operatorIndex, operator] of ["=", "<", ">"].entries()) {
    for (const [valueIndex, value] of [1, 20, 40].entries()) {
      add(
        `without_n_${operatorIndex}_${valueIndex}`,
        "without_rowid.db",
        `SELECT k, n FROM wr WHERE n ${operator} ${value} ORDER BY k`,
      );
    }
  }
  [
    "SELECT k, v FROM wr WHERE v >= 'value-020' ORDER BY k",
    "SELECT k, n FROM wr ORDER BY k DESC LIMIT 5",
  ].forEach((sql, index) => add(`without_${index}`, "without_rowid.db", sql));

  [
    "SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE a.id = 1 ORDER BY b.id",
    "SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE b.price > 10 ORDER BY b.id",
    "SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE b.price IS NULL ORDER BY b.id",
    "SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id ORDER BY a.id, b.id",
    "SELECT a.name, b.title FROM authors a LEFT JOIN books b ON a.id = b.author_id WHERE b.id IS NULL ORDER BY a.id",
    "SELECT count(*) AS n FROM authors CROSS JOIN books",
    "SELECT orders.order_id AS oid, shipments.carrier FROM orders JOIN shipments USING (order_id) ORDER BY orders.order_id",
    "SELECT * FROM orders LEFT JOIN shipments USING (order_id) ORDER BY order_id",
    "SELECT * FROM orders NATURAL JOIN shipments ORDER BY order_id",
    "SELECT * FROM orders NATURAL LEFT JOIN shipments ORDER BY order_id",
    "SELECT a.name, b.title FROM authors a, books b WHERE a.id = b.author_id ORDER BY b.id",
    "SELECT e.name AS employee, m.name AS manager FROM authors e JOIN authors m ON e.id = m.id + 1 ORDER BY e.id",
    "SELECT a.name, count(*) AS n, sum(b.price) AS s FROM authors a JOIN books b ON a.id = b.author_id GROUP BY a.name ORDER BY a.name",
    "SELECT DISTINCT a.name FROM authors a JOIN books b ON a.id = b.author_id ORDER BY a.name",
    "SELECT a.name FROM authors a JOIN books b ON a.id = b.author_id ORDER BY b.id DESC LIMIT 2",
    "SELECT b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE a.name = 'Ada' ORDER BY b.id",
    "SELECT b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE a.id >= 2 AND b.price >= 20 ORDER BY b.id",
    "SELECT b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE b.author_id IS NULL ORDER BY b.id",
    "SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE a.rowid <= 2 ORDER BY a.id",
    "SELECT a.name, b.title FROM authors a JOIN books b ON a.id = b.author_id WHERE b.rowid = 3",
  ].forEach((sql, index) => add(`joins_${index}`, "joins.db", sql));

  for (const [valueIndex, value] of [1, 50, 100].entries()) {
    add(
      `indexed_id_eq_${valueIndex}`,
      "indexed.db",
      `SELECT id, value FROM items WHERE id = ${value} ORDER BY id`,
    );
  }
  [
    "SELECT id, value FROM items WHERE id < 50 ORDER BY id",
    "SELECT id, value FROM items WHERE id > 50 ORDER BY id",
    "SELECT id, value FROM items WHERE id BETWEEN 10 AND 20 ORDER BY id",
  ].forEach((sql, index) => add(`indexed_id_range_${index}`, "indexed.db", sql));
  for (const [valueIndex, value] of [1, 50, 100].entries()) {
    const text = `value-${String(value).padStart(3, "0")}-${"x".repeat(40)}`;
    add(
      `indexed_value_eq_${valueIndex}`,
      "indexed.db",
      `SELECT id, value FROM items WHERE value = '${text}' ORDER BY id`,
    );
  }
  const indexedBoundary = `value-050-${"x".repeat(40)}`;
  add(
    "indexed_value_range",
    "indexed.db",
    `SELECT id, value FROM items WHERE value >= '${indexedBoundary}' ORDER BY id`,
  );
  [
    "SELECT id, value FROM items ORDER BY id LIMIT 3",
    "SELECT id, value FROM items ORDER BY id LIMIT 3 OFFSET 5",
  ].forEach((sql, index) => add(`indexed_order_${index}`, "indexed.db", sql));

  for (const [valueIndex, value] of [1, 100, 200].entries()) {
    add(
      `three_pages_eq_${valueIndex}`,
      "three_pages.db",
      `SELECT id, value FROM items WHERE id = ${value} ORDER BY id`,
    );
  }
  [
    "SELECT id, value FROM items WHERE id BETWEEN 50 AND 60 ORDER BY id",
    "SELECT id, value FROM items WHERE id < 5 ORDER BY id",
    "SELECT id, value FROM items WHERE id > 195 ORDER BY id",
    "SELECT id, value FROM items ORDER BY id LIMIT 5",
    "SELECT id, value FROM items ORDER BY id DESC LIMIT 5",
  ].forEach((sql, index) => add(`three_pages_${index}`, "three_pages.db", sql));

  [
    "SELECT c_null, c_int8, c_real FROM serial_types WHERE c_int8 > 0",
    "SELECT c_int8, c_text3 FROM serial_types WHERE c_int8 IS NOT NULL ORDER BY c_int8",
    "SELECT c_null, c_text0, c_blob0 FROM serial_types",
    "SELECT c_int8, c_text3 FROM serial_types ORDER BY c_int8",
    "SELECT c_real, c_text FROM serial_types WHERE c_real IS NOT NULL",
  ].forEach((sql, index) => add(`serial_${index}`, "serial_types.db", sql));

  [
    "SELECT id, price FROM items WHERE price < 2 ORDER BY id",
    "SELECT id, price FROM items WHERE price >= 2 ORDER BY id",
    "SELECT id, name FROM items WHERE name > 'a' ORDER BY id",
    "SELECT id, name FROM items WHERE name <= 'beta' ORDER BY id",
  ].forEach((sql, index) => add(`small_extra_${index}`, "small.db", sql));
  [
    "SELECT id, val FROM ordering WHERE val = 2 ORDER BY id",
    "SELECT id, grp FROM ordering WHERE grp >= 'c' ORDER BY id",
  ].forEach((sql, index) => add(`ordering_extra_${index}`, "ordering.db", sql));
  [
    "SELECT k, n FROM wr WHERE n BETWEEN 10 AND 20 ORDER BY k",
    "SELECT id, value FROM items WHERE id >= 190 ORDER BY id",
  ].forEach((sql, index) => add(`extra_${index}`, index === 0 ? "without_rowid.db" : "three_pages.db", sql));
}

addGeneratedQueries();

function querySql(sql) {
  return sql.trim().replace(/;+\s*$/, "");
}

function queryValue(value, type) {
  if (type === "null") {
    return {type};
  }
  if (type === "blob") {
    if (!(value instanceof Uint8Array)) {
      throw new Error(`expected a blob value, got ${typeof value}`);
    }
    return {
      type,
      value: Buffer.from(value).toString("hex").toUpperCase(),
    };
  }
  return {type, value: String(value)};
}

function queryResult(db, definition) {
  const sql = querySql(definition.sql);
  const statement = db.prepare(sql);
  const columns = statement.getColumnNames();
  if (new Set(columns).size !== columns.length) {
    throw new Error(
      `${definition.name}: duplicate result column names are not supported`,
    );
  }
  const values = [];
  while (statement.step()) {
    values.push(statement.get(null, {useBigInt: true}));
  }
  statement.free();

  const typeColumns = columns
    .map(column => `typeof(${quoteIdentifier(column)})`)
    .join(", ");
  const typed = db.exec(`SELECT ${typeColumns}, * FROM (${sql})`);
  const typedRows = typed.length === 0 ? [] : typed[0].values;
  if (typedRows.length !== values.length) {
    throw new Error(
      `${definition.name}: ${values.length} rows but ${typedRows.length} type rows`,
    );
  }

  return {
    columns,
    rows: values.map((row, rowIndex) => row.map((value, columnIndex) =>
      queryValue(value, typedRows[rowIndex][columnIndex]))),
  };
}

async function writeQueries() {
  const databases = new Map();
  const queries = [];

  for (const definition of queryDefinitions) {
    let db = databases.get(definition.database);
    if (db === undefined) {
      const bytes = await readFile(path.join(fixturesDir, definition.database));
      db = new SQL.Database(bytes);
      databases.set(definition.database, db);
    }

    const result = queryResult(db, definition);
    queries.push({
      name: definition.name,
      database: `${fixturePrefix}${definition.database}`,
      sql: querySql(definition.sql),
      columns: result.columns,
      rows: result.rows,
    });
  }

  for (const db of databases.values()) {
    db.close();
  }

  await writeFile(
    path.join(fixturesDir, "queries.json"),
    `${JSON.stringify({queries}, null, 2)}\n`,
  );
  console.log(`queries.json: ${queries.length} queries`);
}

async function writeFixture(name, db) {
  const bytes = db.export();
  db.close();

  // ANORMALY: sql.js export resets the schema version, inspect the exported
  // file so the expectations match the on-disk header
  const reopened = new SQL.Database(bytes);
  const contents = expectedContents(reopened);
  reopened.close();

  await writeFile(path.join(fixturesDir, `${name}.db`), bytes);
  await writeFile(
    path.join(fixturesDir, `${name}.json`),
    `${JSON.stringify(contents, null, 2)}\n`,
  );

  console.log(`${name}.db: ${bytes.length} bytes, ${contents.pragmas.page_count} pages, ${contents.tables.length} table(s)`);
}

await rm(fixturesDir, {recursive: true, force: true});
await mkdir(fixturesDir, {recursive: true});

await writeFixture("empty", emptyDatabase());
await writeFixture("small", smallDatabase());
await writeFixture("three_pages", threePagesDatabase());
await writeFixture("indexed", indexedDatabase());
await writeFixture("serial_types", serialTypesDatabase());
await writeFixture("ten_thousand", tenThousandDatabase());
await writeFixture("overflow", overflowDatabase());
for (const pageSize of [512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]) {
  await writeFixture(`page_${pageSize}`, pageSizeDatabase(pageSize));
}
await writeFixture("freelist", freelistDatabase());
await writeFixture("auto_vacuum", autoVacuumDatabase());
await writeFixture("without_rowid", withoutRowidDatabase());
await writeFixture("nulls", nullsDatabase());
await writeFixture("many_indexes", manyIndexesDatabase());
await writeFixture("ordering", orderingDatabase());
await writeFixture("aggregates", aggregatesDatabase());
await writeFixture("joins", joinsDatabase());

await writeQueries();
