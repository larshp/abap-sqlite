import {mkdir, rm, writeFile} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import initSqlJs from "sql.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixturesDir = path.resolve(here, "..", "fixtures");

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
    const info = db.exec(`PRAGMA index_info(${quoteIdentifier(name)})`);
    const columns = info.length === 0
      ? []
      : info[0].values.map(([, , column]) => column);
    const order = [...columns, "rowid"]
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
