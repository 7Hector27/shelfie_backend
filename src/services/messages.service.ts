import { pool } from "../config/database";
import { io } from "../index";

export const getUserConversations = async (userId: string) => {
  const { rows } = await pool.query(
    `
    SELECT
      c.id AS conversation_id,

      -- Other user
      u.id AS friend_id,
      p.first_name,
      p.last_name,
      p.profile_image,

      -- Latest message
      m.body AS last_message,
      m.created_at AS last_message_at,
      m.sender_id,

      -- Unread count for THIS user
      (
        SELECT COUNT(*)
        FROM messages m2
        WHERE m2.conversation_id = c.id
          AND m2.sender_id != $1
          AND (
            cm.last_read_at IS NULL
            OR m2.created_at > cm.last_read_at
          )
      )::int AS unread_count

    FROM conversation_members cm
    JOIN conversations c ON c.id = cm.conversation_id

    -- Get the other participant in the conversation
    JOIN conversation_members cm2
      ON cm2.conversation_id = c.id
      AND cm2.user_id != $1

    JOIN users u ON u.id = cm2.user_id
    JOIN profiles p ON p.user_id = u.id

    -- Latest message per conversation
    LEFT JOIN LATERAL (
      SELECT *
      FROM messages
      WHERE conversation_id = c.id
      ORDER BY created_at DESC
      LIMIT 1
    ) m ON true

    WHERE cm.user_id = $1
    ORDER BY m.created_at DESC NULLS LAST
    `,
    [userId],
  );

  return rows;
};

export const startConversation = async (userId: string, friendId: string) => {
  if (userId === friendId) {
    throw new Error("Cannot start conversation with yourself");
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1️⃣ Check existing
    const existing = await client.query(
      `
      SELECT c.id
      FROM conversations c
      JOIN conversation_members cm1
        ON cm1.conversation_id = c.id
      JOIN conversation_members cm2
        ON cm2.conversation_id = c.id
      WHERE cm1.user_id = $1
        AND cm2.user_id = $2
      LIMIT 1
      `,
      [userId, friendId],
    );

    if (existing.rows.length > 0) {
      await client.query("COMMIT");
      return { conversation_id: existing.rows[0].id };
    }

    // 2️⃣ Create conversation
    const result = await client.query(
      `
      INSERT INTO conversations (created_at)
      VALUES (NOW())
      RETURNING id
      `,
    );

    const newConversationId = result.rows[0].id;

    // 3️⃣ Insert members
    await client.query(
      `
      INSERT INTO conversation_members (conversation_id, user_id, joined_at)
      VALUES
        ($1, $2, NOW()),
        ($1, $3, NOW())
      `,
      [newConversationId, userId, friendId],
    );

    await client.query("COMMIT");

    return { conversation_id: newConversationId };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

export const getConversationById = async (
  conversationId: string,
  userId: string,
) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1️⃣ Verify user is part of conversation
    const membershipCheck = await client.query(
      `
      SELECT 1
      FROM conversation_members
      WHERE conversation_id = $1
        AND user_id = $2
      `,
      [conversationId, userId],
    );

    if (membershipCheck.rows.length === 0) {
      throw new Error("Unauthorized");
    }

    // 2️⃣ Get other participant
    const friendResult = await client.query(
      `
      SELECT
        u.id,
        p.first_name,
        p.last_name,
        p.profile_image
      FROM conversation_members cm
      JOIN users u ON u.id = cm.user_id
      JOIN profiles p ON p.user_id = u.id
      WHERE cm.conversation_id = $1
        AND cm.user_id != $2
      LIMIT 1
      `,
      [conversationId, userId],
    );

    const friend = friendResult.rows[0];

    // ✅ 2.5 Get friend's last_read_at (for "Seen")
    const friendReadResult = await client.query(
      `
      SELECT last_read_at
      FROM conversation_members
      WHERE conversation_id = $1
        AND user_id = $2
      LIMIT 1
      `,
      [conversationId, friend.id],
    );

    const friend_last_read_at = friendReadResult.rows[0]?.last_read_at ?? null;

    // 3️⃣ Get messages
    const messagesResult = await client.query(
      `
      SELECT
        id,
        sender_id,
        body,
        created_at
      FROM messages
      WHERE conversation_id = $1
      ORDER BY created_at ASC
      `,
      [conversationId],
    );

    await client.query("COMMIT");

    return {
      friend,
      friend_last_read_at,
      messages: messagesResult.rows,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

export const sendMessage = async (
  conversationId: string,
  senderId: string,
  body: string,
) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // verify membership
    const membershipCheck = await client.query(
      `
      SELECT 1
      FROM conversation_members
      WHERE conversation_id = $1
        AND user_id = $2
      `,
      [conversationId, senderId],
    );

    if (membershipCheck.rows.length === 0) {
      throw new Error("Unauthorized");
    }

    // insert message
    const result = await client.query(
      `
      INSERT INTO messages (conversation_id, sender_id, body, created_at)
      VALUES ($1, $2, $3, NOW())
      RETURNING id, sender_id, body, created_at
      `,
      [conversationId, senderId, body],
    );

    const message = result.rows[0];

    await client.query("COMMIT");

    // 🔥 Emit to everyone in this conversation room
    io.to(conversationId).emit("new_message", message);

    return message;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};

export const markConversationAsRead = async (
  conversationId: string,
  userId: string,
) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Update last_read_at
    const result = await client.query(
      `
      UPDATE conversation_members
      SET last_read_at = NOW()
      WHERE conversation_id = $1
        AND user_id = $2
      RETURNING last_read_at
      `,
      [conversationId, userId],
    );

    if (result.rowCount === 0) {
      throw new Error("Conversation not found or unauthorized");
    }

    const lastReadAt = result.rows[0].last_read_at;

    await client.query("COMMIT");

    // 🔥 Emit read event to conversation room
    io.to(conversationId).emit("conversation_read", {
      userId,
      last_read_at: lastReadAt,
    });

    return { success: true };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
};
