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
  const actorIds = [...friendIds];

  if (!actorIds.length) {
    return [];
  }

  // 2️⃣ Fetch enriched feed
  const { rows } = await pool.query(
    `
  SELECT
    a.id,
    a.type,
    a.metadata,
    a.created_at,

    -- Actor
    u.id AS actor_id,
    p.first_name,
    p.last_name,
    p.profile_image,

    -- Book
    b.id AS book_id,
    b.title,
    b.author,
    b.cover_url

  FROM activities a

  JOIN users u
    ON u.id = a.actor_id

  JOIN profiles p
    ON p.user_id = u.id

  LEFT JOIN user_books ub
    ON a.object_type = 'user_book'
    AND ub.id::text = a.object_id

  LEFT JOIN books b
    ON b.id = ub.book_id

  WHERE a.actor_id = ANY($1::uuid[])
    AND a.type NOT IN ('book_added', 'dropped_book')

  ORDER BY a.created_at DESC
  LIMIT $2
  `,
    [actorIds, limit],
  );

  return rows;
}
