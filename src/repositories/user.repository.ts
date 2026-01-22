import { pool } from "../config/database";

type CreateUserInput = {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  birthdate?: string;
  bio?: string;
  profile_image?: string;
};

export const findByEmail = async (email: string) => {
  const result = await pool.query(
    "SELECT id, email, password_hash FROM users WHERE email = $1",
    [email],
  );

  return result.rows[0] || null;
};

export const findById = async (id: string) => {
  const result = await pool.query(
    "SELECT user_id, first_name, last_name FROM profiles WHERE user_id = $1",
    [id],
  );
  return result.rows[0] || null;
};

export const create = async (data: CreateUserInput) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1. Create user
    const userResult = await client.query(
      `
      INSERT INTO users (email, password_hash)
      VALUES ($1, $2)
      RETURNING id, email
      `,
      [data.email, data.password],
    );

    const user = userResult.rows[0];

    // 2. Create profile tied to user
    await client.query(
      `
      INSERT INTO profiles (
        user_id,
        first_name,
        last_name,
        birthdate,
        bio,
        profile_image
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      `,
      [
        user.id,
        data.first_name,
        data.last_name,
        data.birthdate ?? null,
        data.bio ?? null,
        data.profile_image ?? null,
      ],
    );

    await client.query("COMMIT");

    return user;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
};
