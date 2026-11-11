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

function typedRows(db, tableName, columns) {
  const expressions = [
    "rowid",
    ...columns.flatMap((column) => [
      `typeof(${quoteIdentifier(column)})`,
      `quote(${quoteIdentifier(column)})`,
    ]),
  ];
  return rows(
    db,
    `SELECT ${expressions.join(", ")} FROM ${quoteIdentifier(tableName)} ORDER BY rowid`,
  );
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

async function verifyCreateTable(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.create_table({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "create-table.db");

  try {
    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.equal(scalar(exported.db, "PRAGMA schema_version"), 3, "schema cookie mismatch");
    assert.equal(scalar(exported.db, "PRAGMA page_count"), 3, "page_count mismatch");
    assert.equal(scalar(exported.db, "PRAGMA freelist_count"), 0, "freelist_count mismatch");
    assert.deepEqual(
      rows(exported.db, "SELECT type, name, tbl_name, rootpage, sql FROM sqlite_schema ORDER BY rowid"),
      [
        [
          "table",
          "created",
          "created",
          2,
          "CREATE TABLE created (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL)",
        ],
        ["table", "notes", "notes", 3, "CREATE TABLE notes (body TEXT)"],
      ],
      "sqlite_schema rows differ",
    );
    assert.deepEqual(
      rows(exported.db, "PRAGMA table_info(created)"),
      [
        [0, "id", "INTEGER", 0, null, 1],
        [1, "name", "TEXT", 1, null, 0],
        [2, "price", "REAL", 0, null, 0],
      ],
      "created table columns differ",
    );
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM created"), 0, "created table is not empty");
  } finally {
    exported.db.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, 2 tables created)`,
  );
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

async function verifyInsertStatements(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.insert_statements({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "insert-statements.db");
  const reference = new SQL.Database();
  const statements = [
    "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT 'anon', qty INTEGER DEFAULT 7, price REAL, note TEXT, bin BLOB)",
    "INSERT INTO items (name, qty, price) VALUES ('alpha', 2, 3.5)",
    "INSERT INTO items (id, name, price) VALUES (10, 'beta', 4)",
    "INSERT INTO items DEFAULT VALUES",
    "INSERT INTO items VALUES (NULL, 'gamma', '8', '2.5', 'x', x'0102'), (100, 'delta', 9, 0, NULL, NULL)",
    "CREATE TABLE source (id INTEGER PRIMARY KEY, label TEXT, amount NUMERIC)",
    "CREATE TABLE dest (id INTEGER PRIMARY KEY, label TEXT NOT NULL, amount REAL DEFAULT 1.0, status TEXT DEFAULT 'new')",
    "INSERT INTO source VALUES (1, 'one', 10), (2, 'two', 2.5), (3, 'three', '4')",
    "INSERT INTO dest (label, amount) SELECT label, amount FROM source ORDER BY id",
    "INSERT INTO dest (label) SELECT 'four'",
    "INSERT INTO dest SELECT 100, 'five', 5.5, 'old'",
    "INSERT INTO dest (label, amount, status) SELECT label, amount, status FROM dest WHERE id = 100",
    "INSERT INTO dest (label) VALUES ('six')",
  ];

  try {
    for (const sql of statements) {
      reference.run(sql);
    }

    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.deepEqual(
      rows(exported.db, "SELECT type, name, tbl_name, rootpage, sql FROM sqlite_schema ORDER BY rowid"),
      rows(reference, "SELECT type, name, tbl_name, rootpage, sql FROM sqlite_schema ORDER BY rowid"),
      "sqlite_schema rows differ",
    );
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM items"), 5, "items row count mismatch");
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM source"), 3, "source row count mismatch");
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM dest"), 7, "dest row count mismatch");
    assert.deepEqual(
      typedRows(exported.db, "items", ["id", "name", "qty", "price", "note", "bin"]),
      typedRows(reference, "items", ["id", "name", "qty", "price", "note", "bin"]),
      "items typed rows differ",
    );
    assert.deepEqual(
      typedRows(exported.db, "source", ["id", "label", "amount"]),
      typedRows(reference, "source", ["id", "label", "amount"]),
      "source typed rows differ",
    );
    assert.deepEqual(
      typedRows(exported.db, "dest", ["id", "label", "amount", "status"]),
      typedRows(reference, "dest", ["id", "label", "amount", "status"]),
      "dest typed rows differ",
    );
  } finally {
    exported.db.close();
    reference.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, typed DML rows)`,
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

async function verifyDelete(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.delete_rows({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "delete.db");
  const reference = new SQL.Database();
  const suffix = "x".repeat(40);
  const statements = [
    "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, amount REAL)",
  ];

  for (let from = 1; from <= 10000; from += 500) {
    const to = Math.min(from + 499, 10000);
    const values = [];
    for (let id = from; id <= to; id += 1) {
      values.push(`(${id}, 'row-${id}-${suffix}', ${id})`);
    }
    statements.push(`INSERT INTO items (id, name, amount) VALUES ${values.join(", ")}`);
  }

  statements.push(
    "DELETE FROM items WHERE id % 7 = 0",
    "DELETE FROM items WHERE id BETWEEN 2000 AND 2999",
    "DELETE FROM items WHERE id % 11 = 0 AND id > 5000",
    "DELETE FROM items WHERE id BETWEEN 7000 AND 8500 AND id % 3 <> 0",
    "DELETE FROM items WHERE id IN (1, 2, 3, 9999, 10000)",
    "DELETE FROM items WHERE id = 123456",
  );

  try {
    for (const sql of statements) {
      reference.run(sql);
    }

    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.equal(
      scalar(exported.db, "SELECT rootpage FROM sqlite_schema WHERE name = 'items'"),
      2,
      "root page number changed",
    );
    assert.ok(scalar(exported.db, "PRAGMA freelist_count") > 0, "deletes freed no pages");
    assert.deepEqual(
      rows(exported.db, "SELECT type, name, tbl_name, rootpage, sql FROM sqlite_schema ORDER BY rowid"),
      rows(reference, "SELECT type, name, tbl_name, rootpage, sql FROM sqlite_schema ORDER BY rowid"),
      "sqlite_schema rows differ",
    );
    assert.deepEqual(
      typedRows(exported.db, "items", ["id", "name", "amount"]),
      typedRows(reference, "items", ["id", "name", "amount"]),
      "delete rows differ",
    );
    assert.equal(
      scalar(exported.db, "SELECT COUNT(*) FROM items"),
      scalar(reference, "SELECT COUNT(*) FROM items"),
      "row count mismatch",
    );
    assert.ok(scalar(exported.db, "SELECT COUNT(*) FROM items") < 10000, "deletes removed no rows");
  } finally {
    exported.db.close();
    reference.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, random deletes)`,
  );
}

async function verifyUpdate(SQL, tempDir) {
  const fileName = (await zcl_sqlite_scenario.update_rows({rv_name: 1})).get();
  const exported = await openExported(SQL, tempDir, fileName, "update.db");
  const reference = new SQL.Database();
  const suffix = "x".repeat(40);
  const statements = [
    "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, amount REAL, note TEXT, bin BLOB)",
  ];

  for (let from = 1; from <= 2000; from += 500) {
    const to = Math.min(from + 499, 2000);
    const values = [];
    for (let id = from; id <= to; id += 1) {
      values.push(`(${id}, 'row-${id}-${suffix}', ${id})`);
    }
    statements.push(`INSERT INTO items (id, name, amount) VALUES ${values.join(", ")}`);
  }

  statements.push(
    "UPDATE items SET name = name || '-u', amount = amount * 2, note = 'n-' || id WHERE id % 5 = 0",
    "UPDATE items AS x SET amount = amount + x.id WHERE x.id BETWEEN 100 AND 199",
    "UPDATE items SET note = 'first', note = 'last' WHERE id = 7",
    "UPDATE items SET id = id + 10000 WHERE id BETWEEN 1 AND 100",
    "UPDATE items SET id = id - 5000 WHERE id BETWEEN 10001 AND 10100",
    "UPDATE items SET rowid = rowid + 20000 WHERE id BETWEEN 500 AND 599",
    "UPDATE items SET oid = oid + 30000 WHERE id BETWEEN 600 AND 699",
    "UPDATE items SET rowid = rowid WHERE id BETWEEN 1000 AND 1099",
    "UPDATE items SET amount = amount WHERE id = 123456",
    "UPDATE items SET name = 'all-' || id",
    "UPDATE items SET bin = x'DEADBEEF' WHERE id % 7 = 0",
    "UPDATE items SET bin = NULL WHERE id % 11 = 0",
    "UPDATE items SET amount = 42 WHERE id BETWEEN 700 AND 799",
    "CREATE TABLE payloads (id INTEGER PRIMARY KEY, label TEXT, body TEXT)",
    `INSERT INTO payloads VALUES (1, 'small', '${"A".repeat(100)}'), ` +
      `(2, 'large', '${"B".repeat(6000)}'), ` +
      `(3, 'huge', '${"C".repeat(12000)}'), ` +
      `(4, 'medium', '${"D".repeat(200)}')`,
    `UPDATE payloads SET body = '${"E".repeat(12000)}' WHERE id = 1`,
    "UPDATE payloads SET body = 'tiny' WHERE id = 2",
    `UPDATE payloads SET body = '${"F".repeat(6000)}' WHERE id = 3`,
    "UPDATE payloads SET body = body || body WHERE id = 4",
    "UPDATE payloads SET id = id + 10",
    "UPDATE payloads SET label = label || '-u' WHERE id % 2 = 0",
  );

  try {
    for (const sql of statements) {
      reference.run(sql);
    }

    assert.equal(scalar(exported.db, "PRAGMA integrity_check"), "ok", "integrity_check failed");
    assert.deepEqual(
      rows(exported.db, "SELECT type, name, tbl_name, sql FROM sqlite_schema ORDER BY rowid"),
      rows(reference, "SELECT type, name, tbl_name, sql FROM sqlite_schema ORDER BY rowid"),
      "sqlite_schema rows differ",
    );
    assert.ok(
      scalar(exported.db, "SELECT rootpage FROM sqlite_schema WHERE name = 'payloads'") > 0,
      "payloads root page is missing",
    );
    assert.equal(scalar(exported.db, "SELECT COUNT(*) FROM items"), 2000, "items row count mismatch");
    assert.deepEqual(
      typedRows(exported.db, "items", ["id", "name", "amount", "note", "bin"]),
      typedRows(reference, "items", ["id", "name", "amount", "note", "bin"]),
      "updated item rows differ",
    );
    assert.deepEqual(
      typedRows(exported.db, "payloads", ["id", "label", "body"]),
      typedRows(reference, "payloads", ["id", "label", "body"]),
      "updated payload rows differ",
    );
  } finally {
    exported.db.close();
    reference.close();
  }

  console.log(
    `export-and-verify: ${fileName} ok (${exported.bytes.length} bytes, ${exported.blocks} blocks, update corpus)`,
  );
}

const SQL = await initSqlJs();
const tempDir = await mkdtemp(path.join(os.tmpdir(), "abap-sqlite-"));

try {
  await verifyCreateTable(SQL, tempDir);
  await verifyEmpty(SQL, tempDir);
  await verifyInsert(SQL, tempDir);
  await verifyInsertStatements(SQL, tempDir);
  await verifyFreelist(SQL, tempDir);
  await verifyOverflow(SQL, tempDir);
  await verifySplit(SQL, tempDir);
  await verifyDelete(SQL, tempDir);
  await verifyUpdate(SQL, tempDir);
} finally {
  await rm(tempDir, {recursive: true, force: true});
}
