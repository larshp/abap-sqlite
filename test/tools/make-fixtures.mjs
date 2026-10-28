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
    return {
      name,
      table,
      sql,
      columns: info.length === 0
        ? []
        : info[0].values.map(([, , column]) => column),
    };
  });
}

function pragma(db, name) {
  return db.exec(`PRAGMA ${name}`)[0].values[0][0];
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
