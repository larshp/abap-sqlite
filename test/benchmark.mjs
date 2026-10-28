/**
 * Runs the performance baseline from M0.7 and prints the numbers.
 *
 * `npm run benchmark` transpiles first, so the numbers always come from the
 * current sources. The ABAP side is `zcl_sqlite_benchmark`.
 */
await import("../output/init.mjs");

const { zcl_sqlite_benchmark } = await import("../output/project/zcl_sqlite_benchmark.clas.mjs");

const result = await zcl_sqlite_benchmark.run();
const fields = result.get();
const value = (name) => Number(fields[name].get());

const measurements = [
  {
    name: "xstring slice, 4 bytes",
    count: value("slice_count"),
    total_us: value("slice_us"),
  },
  {
    name: "table row write, 512 bytes",
    count: value("write_count"),
    total_us: value("write_us"),
  },
  {
    name: "table row read, 512 bytes",
    count: value("read_count"),
    total_us: value("read_us"),
  },
];

console.log(`Node ${process.version} on ${process.platform} ${process.arch}`);
console.log("");
console.log("operation                      count      total ms    per op us");
for (const measurement of measurements) {
  const total_ms = measurement.total_us / 1000;
  const per_op_us = measurement.total_us / measurement.count;
  console.log(
    measurement.name.padEnd(30),
    String(measurement.count).padStart(6),
    total_ms.toFixed(2).padStart(12),
    per_op_us.toFixed(2).padStart(11),
  );
}
