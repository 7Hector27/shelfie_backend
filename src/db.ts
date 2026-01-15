import { Pool } from "pg";

export const pool = new Pool({
  host: "127.0.0.1",
  port: 5432,
  user: "shelfie_user",
  password: "Anaheim@27",
  database: "shelfie_db",
});

export async function connectDB() {
  await pool.query("SELECT 1");
  console.log("Postgres connected");
}
