import { pool } from "../config/database";
import { io } from "../index";
import Groq from "groq-sdk";
import { Response as ExpressResponse } from "express";

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

export const getUserConversations = async (userId: string) => {
  const { rows } = await pool.query(
    `
    SELECT
      c.id AS conversation_id,
      c.is_ai,
      c.book_title,
      c.book_author,

      u.id AS friend_id,
      p.first_name,
      p.last_name,
      p.profile_image,

      m.body AS last_message,
      m.created_at AS last_message_at,
      m.sender_id,

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

    LEFT JOIN conversation_members cm2
      ON cm2.conversation_id = c.id
      AND cm2.user_id != $1

    LEFT JOIN users u ON u.id = cm2.user_id
    LEFT JOIN profiles p ON p.user_id = u.id

    LEFT JOIN LATERAL (
      SELECT *
      FROM messages
      WHERE conversation_id = c.id
      ORDER BY created_at DESC
      LIMIT 1
    ) m ON true

WHERE cm.user_id = $1
AND (
  cm.deleted_at IS NULL
  OR m.created_at > cm.deleted_at   
)

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

    // 1️⃣ Verify membership + get deleted_at
    const membershipCheck = await client.query(
      `
      SELECT deleted_at
      FROM conversation_members
      WHERE conversation_id = $1
        AND user_id = $2
      `,
      [conversationId, userId],
    );

    if (membershipCheck.rows.length === 0) {
      throw new Error("Unauthorized");
    }

    const deletedAt = membershipCheck.rows[0].deleted_at;

    // 2️⃣ Check if AI conversation
    const convResult = await client.query(
      `
      SELECT is_ai, book_title, book_author
      FROM conversations
      WHERE id = $1
      `,
      [conversationId],
    );

    const conv = convResult.rows[0];

    // 3️⃣ Get messages — ✅ only after deleted_at if it exists
    const messagesResult = await client.query(
      `
      SELECT id, sender_id, body, created_at
      FROM messages
      WHERE conversation_id = $1
      ${deletedAt ? `AND created_at > $2` : ""}
      ORDER BY created_at ASC
      `,
      deletedAt ? [conversationId, deletedAt] : [conversationId],
    );

    await client.query("COMMIT");

    if (conv.is_ai) {
      return {
        is_ai: true,
        friend: null,
        friend_last_read_at: null,
        book_title: conv.book_title,
        book_author: conv.book_author,
        messages: messagesResult.rows,
      };
    }

    const friendResult = await client.query(
      `
      SELECT u.id, p.first_name, p.last_name, p.profile_image
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

    const friendReadResult = await client.query(
      `
      SELECT last_read_at
      FROM conversation_members
      WHERE conversation_id = $1 AND user_id = $2
      LIMIT 1
      `,
      [conversationId, friend.id],
    );

    const friend_last_read_at = friendReadResult.rows[0]?.last_read_at ?? null;

    return {
      is_ai: false,
      friend,
      friend_last_read_at,
      book_title: null,
      book_author: null,
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
  res?: ExpressResponse,
) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Verify membership
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

    // Check if AI conversation
    const convResult = await client.query(
      `
      SELECT is_ai, book_title, book_author, book_description
      FROM conversations
      WHERE id = $1
      `,
      [conversationId],
    );

    const conv = convResult.rows[0];

    // Store user message
    const userMessage = await client.query(
      `
      INSERT INTO messages (conversation_id, sender_id, body, created_at)
      VALUES ($1, $2, $3, NOW())
      RETURNING id, sender_id, body, created_at
      `,
      [conversationId, senderId, body],
    );

    // ✅ Restore conversation for recipient if they previously deleted it
    if (!conv.is_ai) {
      await client.query(
        `
        UPDATE conversation_members
        SET deleted_at = NULL
        WHERE conversation_id = $1
          AND user_id != $2
          AND deleted_at IS NOT NULL
        `,
        [conversationId, senderId],
      );
    }

    await client.query("COMMIT");

    // ── Normal conversation ──────────────────────────────
    if (!conv.is_ai) {
      const message = userMessage.rows[0];
      io.to(conversationId).emit("new_message", message);
      return message;
    }

    // ── AI conversation — fetch history + stream ─────────
    if (conv.is_ai && res) {
      const historyResult = await client.query(
        `
        SELECT sender_id, body
        FROM messages
        WHERE conversation_id = $1
        ORDER BY created_at ASC
        `,
        [conversationId],
      );

      const history = historyResult.rows.map((row) => ({
        role: (row.sender_id === senderId ? "user" : "assistant") as
          | "user"
          | "assistant",
        content: row.body as string,
      }));

      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache");
      res.setHeader("Connection", "keep-alive");

      const stream = await groq.chat.completions.create({
        model: "llama-3.3-70b-versatile",
        stream: true,
        max_tokens: 500,
        messages: [
          {
            role: "system",
            content: `You are a thoughtful literary companion helping a reader explore "${conv.book_title}" by ${conv.book_author}.
${conv.book_description ? `Here's a brief description: ${conv.book_description}` : ""}
Be conversational, insightful and engaging. Ask questions back to the user to spark discussion.
Keep responses concise — 2 to 4 sentences max unless the user asks for more detail.
Never spoil the ending unless the user explicitly asks.`,
          },
          ...history,
        ],
      });

      let aiResponse = "";

      for await (const chunk of stream) {
        const text = chunk.choices[0]?.delta?.content || "";
        if (text) {
          aiResponse += text;
          res.write(text);
        }
      }

      // Store AI response with null sender_id
      await pool.query(
        `
        INSERT INTO messages (conversation_id, sender_id, body, created_at)
        VALUES ($1, NULL, $2, NOW())
        `,
        [conversationId, aiResponse],
      );

      res.end();
      return;
    }
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

export const startAiConversation = async (
  userId: string,
  book: {
    title: string;
    author: string;
    description?: string | null;
  },
) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Check if AI conversation for this book already exists for this user
    const existing = await client.query(
      `
      SELECT c.id
      FROM conversations c
      JOIN conversation_members cm ON cm.conversation_id = c.id
      WHERE cm.user_id = $1
        AND c.is_ai = true
        AND c.book_title = $2
      LIMIT 1
      `,
      [userId, book.title],
    );

    if (existing.rows.length > 0) {
      await client.query("COMMIT");
      return { conversation_id: existing.rows[0].id };
    }

    // Create new AI conversation
    const result = await client.query(
      `
      INSERT INTO conversations (created_at, is_ai, book_title, book_author, book_description)
      VALUES (NOW(), true, $1, $2, $3)
      RETURNING id
      `,
      [book.title, book.author, book.description ?? null],
    );

    const newConversationId = result.rows[0].id;

    // Only insert the user as member — no AI participant needed
    await client.query(
      `
      INSERT INTO conversation_members (conversation_id, user_id, joined_at)
      VALUES ($1, $2, NOW())
      `,
      [newConversationId, userId],
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

export async function deleteConversationForUser(
  conversationId: string,
  userId: string,
) {
  const result = await pool.query(
    `
    UPDATE conversation_members
    SET deleted_at = NOW()
    WHERE conversation_id = $1
    AND user_id = $2
    RETURNING conversation_id
    `,
    [conversationId, userId],
  );

  return result.rowCount;
}
