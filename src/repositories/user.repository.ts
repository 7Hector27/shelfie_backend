import { pool } from "../config/database";

type CreateUserInput = {
  email: string;
  password: string;
};

export const findByEmail = async (email: string) => {
  const result = await pool.query(
    "SELECT id, email FROM users WHERE email = $1",
    [email],
  );

  return result.rows[0] || null;
};

export const create = async (data: CreateUserInput) => {
  const result = await pool.query(
    `
    INSERT INTO users (email, password)
    VALUES ($1, $2)
    RETURNING id, email
    `,
    [data.email, data.password],
  );

  return result.rows[0];
};
