// Compatibility gate: run transpiled ABAP scenarios, export the bytes their
// writes left in ZSQLITE_FILES, and verify the resulting databases with sql.js.
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

const client = abap.context.databaseConnections?.DEFAULT;
assert.ok(client, "transpiler SQLite connection is not available");
const mandt = abap.builtin.sy.get().mandt.get();

async function exportDatabase(fileName) {
  const selected = await client.select({
    select: `SELECT blockno, filename, data FROM zsqlite_files WHERE mandt = '${mandt}' ORDER BY filename, blockno`,
  });
  const blocks = selected.rows.filter((row) => String(row.filename).trimEnd() === fileName);
  assert.ok(blocks.length > 0, `no ZSQLITE_FILES blocks for ${fileName}`);
  blocks.forEach((row, index) => {
    assert.equal(Number(row.blockno), index, `missing block ${index} for ${fileName}`);
  });

  return {
    blocks: blocks.length,
    bytes: Buffer.concat(blocks.map((row) => blockBytes(row.data))),
  };
}

async function openExported(SQL, tempDir, fileName, localName) {
  const exported = await exportDatabase(fileName);
  const databasePath = path.join(tempDir, localName);
  await writeFile(databasePath, exported.bytes);
  const db = new SQL.Database(new Uint8Array(await readFile(databasePath)));
  return {...exported, db};
}

async function verifyEmpty(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.create_empty({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "empty.db");
  const reference = new SQL.Database(await readFile(path.join(fixturesDir, "empty.db")));

  try {
    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.deepEqual(snapshot(exported.db), snapshot(reference), "created database contents differ");
  } finally {
    exported.db.close();
    reference.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks)`,
  );
}

async function verifyInsert(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.insert_rows({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "insert.db");

  try {
    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.equal(scalar(exported.db, "PRAGMA page_count"), 2, "insert should not grow the file");
    assert.equal(scalar(exported.db, "PRAGMA freelist_count"), 0, "freelist_count mismatch");
    assert.deepEqual(
      rows(exported.db, "SELECT id, name, price FROM items ORDER BY id"),
      [
        [0, "zero", 0],
        [1, "alpha", 1.5],
        [2, "beta", 2.25],
        [3, "gamma", null],
        [4, "delta", 4.5],
        [5, "epsilon", null],
        [7, "x".repeat(2000), 7.5],
        [10, "ten", -1.25],
      ],
      "inserted rows differ",
    );
  } finally {
    exported.db.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, 5 rows inserted)`,
  );
}

async function verifyFreelist(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.freelist_cycle({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "freelist.db");

  try {
    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.equal(scalar(exported.db, "PRAGMA page_count"), 15, "page_count mismatch");
    assert.equal(scalar(exported.db, "PRAGMA freelist_count"), 14, "freelist_count mismatch");
  } finally {
    exported.db.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, freelist 14)`,
  );
}

async function verifyOverflow(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.overflow_rows({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "overflow-write.db");

  try {
    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.equal(
      scalar(exported.db, "SELECT rootpage FROM sqlite_schema WHERE name = 'payloads'"),
      2,
      "root page number changed",
    );
    assert.ok(scalar(exported.db, "PRAGMA page_count") > 11, "overflow rows should grow the file");
    assert.equal(scalar(exported.db, "PRAGMA freelist_count"), 0, "freelist_count mismatch");
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM payloads"), 6, "row count mismatch");
    assert.equal(
      scalar(
        exported.db,
        "SELECT COUNT(*) FROM payloads WHERE name IN ('text_near', 'blob_near', 'text_multi', 'blob_multi')",
      ),
      4,
      "existing overflow rows are missing",
    );
    assert.deepEqual(
      rows(
        exported.db,
        `SELECT rowid, name, typeof(value), length(value),
                hex(substr(value, 1, 8)), hex(substr(value, -8, 8))
         FROM payloads WHERE rowid IN (100, 101) ORDER BY rowid`,
      ),
      [
        [100, "large_text", "text", 10000, "5A5A5A5A5A5A5A5A", "5A5A5A5A5A5A5A5A"],
        [101, "large_blob", "blob", 12000, "0011223344556677", "8899AABBCCDDEEFF"],
      ],
      "overflow rows differ",
    );
  } finally {
    exported.db.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, overflow rows)`,
  );
}

async function verifySplit(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.split_rows({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "split.db");
  const suffix = "x".repeat(100);

  try {
    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.equal(
      scalar(exported.db, "SELECT rootpage FROM sqlite_schema WHERE name = 'items'"),
      2,
      "root page number changed",
    );
    assert.ok(scalar(exported.db, "PRAGMA page_count") > 100, "split tree should span many pages");
    assert.equal(scalar(exported.db, "PRAGMA freelist_count"), 0, "freelist_count mismatch");
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM items"), 20003, "row count mismatch");
    assert.equal(
      scalar(exported.db, "SELECT COUNT(*) FROM items WHERE id BETWEEN 1000 AND 10999"),
      10000,
      "sequential rows are missing",
    );
    assert.equal(
      scalar(exported.db, "SELECT COUNT(*) FROM items WHERE id BETWEEN 100000 AND 109999"),
      10000,
      "shuffled rows are missing",
    );
    assert.deepEqual(
      rows(exported.db, "SELECT id, name FROM items WHERE id IN (1000, 10999, 100000, 109999) ORDER BY id"),
      [
        [1000, `seq-1000-${suffix}`],
        [10999, `seq-10999-${suffix}`],
        [100000, `rnd-100000-${suffix}`],
        [109999, `rnd-109999-${suffix}`],
      ],
      "split rows differ",
    );
  } finally {
    exported.db.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, 20k rows)`,
  );
}

const SQL = await initSqlJs();
const tempDir = await mkdtemp(path.join(os.tmpdir(), "abap-sqlite-"));

try {
  await verifyEmpty(SQL, tempDir);
  await verifyInsert(SQL, tempDir);
  await verifyFreelist(SQL, tempDir);
  await verifyOverflow(SQL, tempDir);
  await verifySplit(SQL, tempDir);
} finally {
  await rm(tempDir, {recursive: true, force: true});
}
