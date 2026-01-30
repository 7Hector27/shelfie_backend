// src/test-db.ts
import { pool } from "./db";

async function test() {
  try {
    const res = await pool.query("SELECT NOW()");
    console.log("DB connected at:", res.rows[0].now);
  } catch (err) {
    console.error("DB connection failed:", err);
  } finally {
    await pool.end();
  }
}

test();
