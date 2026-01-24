import { pool } from "../config/database";

export async function searchUsersForFriends(
  search: string,
  currentUserId: string,
) {
  const parts = search.trim().split(/\s+/);

  const first = parts[0] ?? null;
  const second = parts[1] ?? null;

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

      OR (
        $3::text IS NOT NULL
        AND p.first_name ILIKE $1 || '%'
        AND p.last_name ILIKE $3 || '%'
      )

      OR (
        $3::text IS NOT NULL
        AND p.first_name ILIKE $3 || '%'
        AND p.last_name ILIKE $1 || '%'
      )
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
    [first, currentUserId, second],
  );

  return rows;
}

export async function sendFriendRequest(senderId: string, recieverId: string) {
  await pool.query(
    `
      INSERT INTO friend_requests (sender_id, receiver_id)
      VALUES ($1, $2)
      ON CONFLICT (sender_id, receiver_id) DO NOTHING;    `,
    [senderId, recieverId],
  );
}

export async function getIncomingFriendRequests(userId: string) {
  const { rows } = await pool.query(
    `
    SELECT
      fr.id,
      u.id AS user_id,
      p.first_name,
      p.last_name,
      p.profile_image
    FROM friend_requests fr
    JOIN users u ON u.id = fr.sender_id
    JOIN profiles p ON p.user_id = u.id
    WHERE fr.receiver_id = $1
      AND fr.status = 'pending'
    ORDER BY fr.created_at DESC
    `,
    [userId],
  );

  return rows;
}

export async function acceptFriendRequest(requestId: string, userId: string) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const { rows } = await client.query(
      `
      UPDATE friend_requests
      SET status = 'accepted'
      WHERE id = $1 AND receiver_id = $2
      RETURNING sender_id
      `,
      [requestId, userId],
    );

    if (!rows.length) {
      throw new Error("Request not found");
    }

    const senderId = rows[0].sender_id;

    await client.query(
      `
      INSERT INTO friendships (user_id, friend_id)
      VALUES ($1, $2), ($2, $1)
      `,
      [userId, senderId],
    );

    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

export async function declineFriendRequest(requestId: string, userId: string) {
  await pool.query(
    `
    UPDATE friend_requests
    SET status = 'rejected'
    WHERE id = $1 AND receiver_id = $2
    `,
    [requestId, userId],
  );
}
