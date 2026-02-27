import { pool } from "../db";

export async function buildUserFeed(userId: string, limit = 20) {
  // 1️⃣ Get friend IDs
  const friendResult = await pool.query(
    `
    SELECT friend_id
    FROM friendships
    WHERE user_id = $1
    `,
    [userId],
  );

  const friendIds = friendResult.rows.map((r) => r.friend_id);

  // Include yourself
  const actorIds = [...friendIds, userId];

  if (actorIds.length === 0) {
    return [];
  }

  // 2️⃣ Fetch activities
  const { rows } = await pool.query(
    `
    SELECT *
    FROM activities
    WHERE actor_id = ANY($1::uuid[])
    ORDER BY created_at DESC
    LIMIT $2
    `,
    [actorIds, limit],
  );

  return rows;
}
