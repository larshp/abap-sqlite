// Compatibility gate: run transpiled ABAP scenarios, export the bytes their
// writes left in ZSQLITE_FILES, and verify the resulting database with sql.js.
import assert from "node:assert/strict";
import {mkdtemp, readFile, rm, writeFile} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {fileURLToPath} from "node:url";
import initSqlJs from "sql.js";

import "../../output/init.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixturesDir = path.resolve(here, "..", "fixtures");

const {zcl_sqlite_scenario} = await import("../../output/project/zcl_sqlite_scenario.clas.mjs");

function quoteIdentifier(name) {
  return `"${String(name).replaceAll("\"", "\"\"")}"`;
}

function scalar(db, sql) {
  const result = db.exec(sql);
  assert.ok(result.length > 0 && result[0].values.length > 0, `no result for ${sql}`);
  return result[0].values[0][0];
}

function rows(db, sql) {
  const result = db.exec(sql);
  return result.length === 0 ? [] : result[0].values;
}

function tableNames(db) {
  return rows(
    db,
    "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  ).map(([name]) => name);
}

function snapshot(db) {
  return {
    pageSize: scalar(db, "PRAGMA page_size"),
    pageCount: scalar(db, "PRAGMA page_count"),
    freelistCount: scalar(db, "PRAGMA freelist_count"),
    schemaVersion: scalar(db, "PRAGMA schema_version"),
    userVersion: scalar(db, "PRAGMA user_version"),
    applicationId: scalar(db, "PRAGMA application_id"),
    encoding: scalar(db, "PRAGMA encoding"),
    schema: rows(db, "SELECT type, name, tbl_name, rootpage, sql FROM sqlite_schema ORDER BY rowid"),
    tables: tableNames(db).map((name) => ({
      name,
      rows: rows(db, `SELECT * FROM ${quoteIdentifier(name)}`),
    })),
  };
}

function blockBytes(value) {
  if (typeof value === "string") {
    assert.match(value, /^[0-9a-f]*$/i, "ZSQLITE_FILES block is not hex text");
    return Buffer.from(value, "hex");
  }
  if (value instanceof Uint8Array) {
    return Buffer.from(value);
  }
  throw new Error(`unexpected ZSQLITE_FILES data type: ${typeof value}`);
}

const fileName = (await zcl_sqlite_scenario.create_empty({rv_name: 1})).get();
const client = abap.context.databaseConnections?.DEFAULT;
assert.ok(client, "transpiler SQLite connection is not available");

const mandt = abap.builtin.sy.get().mandt.get();
const selected = await client.select({
  select: `SELECT blockno, filename, data FROM zsqlite_files WHERE mandt = '${mandt}' ORDER BY filename, blockno`,
});
const blocks = selected.rows.filter((row) => String(row.filename).trimEnd() === fileName);
assert.ok(blocks.length > 0, `no ZSQLITE_FILES blocks for ${fileName}`);
blocks.forEach((row, index) => {
  assert.equal(Number(row.blockno), index, `missing block ${index} for ${fileName}`);
});

const databaseBytes = Buffer.concat(blocks.map((row) => blockBytes(row.data)));
const tempDir = await mkdtemp(path.join(os.tmpdir(), "abap-sqlite-"));
const databasePath = path.join(tempDir, "created.db");
await writeFile(databasePath, databaseBytes);

try {
  const SQL = await initSqlJs();
  const created = new SQL.Database(new Uint8Array(await readFile(databasePath)));
  const reference = new SQL.Database(await readFile(path.join(fixturesDir, "empty.db")));

  try {
    assert.equal(scalar(created, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.deepEqual(snapshot(created), snapshot(reference), "created database contents differ");
  } finally {
    created.close();
    reference.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${databaseBytes.length} bytes, ${blocks.length} blocks)`,
  );
} finally {
  await rm(tempDir, {recursive: true, force: true});
}
