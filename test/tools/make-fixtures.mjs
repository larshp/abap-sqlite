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
];

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

await writeQueries();
