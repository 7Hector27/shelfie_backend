import { pool } from "../config/database";

export async function searchUsersForFriends(
  search: string,
  currentUserId: string,
) {
  const { rows } = await pool.query(
    `
    SELECT
      u.id,
      u.email,
      p.first_name,
      p.last_name,
      p.profile_image
    FROM users u
    JOIN profiles p
      ON p.user_id = u.id
    WHERE
      (
        p.first_name ILIKE '%' || $1 || '%'
        OR p.last_name ILIKE '%' || $1 || '%'
        OR u.email ILIKE '%' || $1 || '%'
      )
    AND u.id <> $2
    AND u.id NOT IN (
      SELECT friend_id FROM friendships WHERE user_id = $2
      UNION
      SELECT receiver_id FROM friend_requests WHERE sender_id = $2
      UNION
      SELECT sender_id FROM friend_requests WHERE receiver_id = $2
    )
    LIMIT 10
    `,
    [search, currentUserId],
  );

  return rows;
}
