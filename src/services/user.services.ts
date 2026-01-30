import { pool } from "../config/database";

export async function updateProfile(
  userId: string,
  data: {
    first_name: string;
    last_name: string;
    bio: string;
    birthdate: string;
  },
) {
  const { first_name, last_name, bio, birthdate } = data;

  await pool.query(
    `
    UPDATE profiles
    SET
      first_name = $1,
      last_name = $2,
      bio = $3,
      birthdate = $4
    WHERE user_id = $5
    `,
    [first_name, last_name, bio, birthdate, userId],
  );
}
