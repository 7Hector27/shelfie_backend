import { Request, Response } from "express";
import { pool } from "../db";
import { createActivity } from "../services/activity.services";

export async function addUserBook(req: Request, res: Response) {
  const userId = req.user?.id;

  const {
    book_id,
    title,
    author,
    description,
    cover_url,
    author_id,
    external_source,
    status,
  } = req.body;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  if (!book_id || !external_source) {
    return res.status(400).json({ error: "Missing book info" });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1️⃣ Check if user_book already exists
    const prevResult = await client.query(
      `SELECT * FROM user_books WHERE user_id = $1 AND book_id = $2`,
      [userId, book_id],
    );

    const prev = prevResult.rows[0] || null;

    // 2️⃣ Ensure book exists
    const existingBook = await client.query(
      `SELECT id FROM books WHERE id = $1`,
      [book_id],
    );

    if (existingBook.rows.length === 0) {
      await client.query(
        `
        INSERT INTO books (id, title, author, description, cover_url, author_id)
        VALUES ($1, $2, $3, $4, $5, $6)
        `,
        [book_id, title, author, description, cover_url, author_id],
      );
    }

    // 3️⃣ Insert or update
    const { rows } = await client.query(
      `
      INSERT INTO user_books (
        user_id,
        book_id,
        external_source,
        status,
        created_at,
        updated_at,
        favorite
      )
      VALUES ($1, $2, $3, $4, NOW(), NOW(), false)
      ON CONFLICT (user_id, book_id)
      DO UPDATE SET
        status = EXCLUDED.status,
        updated_at = NOW()
      RETURNING *;
      `,
      [userId, book_id, external_source, status ?? "want_to_read"],
    );

    const userBook = rows[0];

    // 4️⃣ Activity Logic

    if (!prev) {
      // Book was newly added
      await createActivity(client, {
        actorId: userId,
        type: "book_added",
        objectType: "user_book",
        objectId: userBook.id,
        targetType: "book",
        targetId: book_id,
        metadata: { status: userBook.status },
      });
    } else if (prev.status !== userBook.status) {
      // Status changed
      if (userBook.status === "reading") {
        await createActivity(client, {
          actorId: userId,
          type: "started_reading",
          objectType: "user_book",
          objectId: userBook.id,
          targetType: "book",
          targetId: book_id,
        });
      }

      if (userBook.status === "completed") {
        await createActivity(client, {
          actorId: userId,
          type: "finished_reading",
          objectType: "user_book",
          objectId: userBook.id,
          targetType: "book",
          targetId: book_id,
        });
      }

      if (userBook.status === "dropped") {
        await createActivity(client, {
          actorId: userId,
          type: "dropped_book",
          objectType: "user_book",
          objectId: userBook.id,
          targetType: "book",
          targetId: book_id,
        });
      }
    }

    await client.query("COMMIT");

    res.status(201).json(userBook);
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to add book" });
  } finally {
    client.release();
  }
}

export async function getUserBooks(req: Request, res: Response) {
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).send({ error: "Unauthorized" });
  }
  try {
    const { rows } = await pool.query(
      `
      SELECT * FROM user_books WHERE user_id = $1 Order by created_at DESC;
      `,
      [userId],
    );
    return res.status(200).json(rows);
  } catch (error) {
    console.error(error);
    return res.status(500).send({ error: "Error fetching user books" });
  }
}

export async function getBookById(req: Request, res: Response) {
  const userId = req.user?.id;
  const bookId = req.params.id as string;
  if (!userId) {
    return res.status(401).send({ error: "Unauthorized" });
  }
  if (!bookId) {
    return res.status(400).send({ error: "Book ID is required" });
  }
  try {
    const { rows } = await pool.query(
      `
      SELECT * FROM user_books WHERE user_id = $1 AND book_id = $2;
      `,
      [userId, bookId],
    );
    if (rows.length === 0) {
      return res.status(404).send({ error: "Book not found" });
    }
    return res.status(200).json(rows[0]);
  } catch (error) {
    console.error(error);
    return res.status(500).send({ error: "Error fetching book" });
  }
}

export async function removeUserBook(req: Request, res: Response) {
  const userId = req.user?.id;
  const { externalBookId } = req.params;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  try {
    const { rowCount } = await pool.query(
      `
      DELETE FROM user_books
      WHERE user_id = $1
        AND book_id = $2;
      `,
      [userId, externalBookId],
    );
    const removed = (rowCount ?? 0) > 0;

    return res.status(200).json({ removed });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to remove book" });
  }
}

export async function updateUserBook(req: Request, res: Response) {
  const userId = req.user?.id;
  const { bookId } = req.params;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { status, rating, review, date_started, date_finished, favorite } =
    req.body;

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const prevRes = await client.query(
      `SELECT * FROM user_books WHERE user_id = $1 AND id = $2`,
      [userId, bookId],
    );

    if (!prevRes.rows.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "User book not found" });
    }

    const prev = prevRes.rows[0];
    console.log("Prev status:", prev.status);
    console.log("Incoming status:", status);
    console.log("Status in body:", "status" in req.body);
    const fields: string[] = [];
    const values: any[] = [];
    let index = 1;

    if ("status" in req.body) {
      fields.push(`status = $${index++}`);
      values.push(status);
    }

    if ("rating" in req.body) {
      fields.push(`rating = $${index++}`);
      values.push(rating);
    }

    if ("review" in req.body) {
      fields.push(`review = $${index++}`);
      values.push(review);
    }

    if ("date_started" in req.body) {
      fields.push(`date_started = $${index++}`);
      values.push(date_started);
    }

    if ("date_finished" in req.body) {
      fields.push(`date_finished = $${index++}`);
      values.push(date_finished);
    }

    if ("favorite" in req.body) {
      fields.push(`favorite = $${index++}`);
      values.push(favorite);
    }

    if (fields.length === 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ error: "No fields to update" });
    }

    fields.push(`updated_at = NOW()`);

    values.push(userId);
    values.push(bookId);

    const updateRes = await client.query(
      `
      UPDATE user_books
      SET ${fields.join(", ")}
      WHERE user_id = $${index++}
      AND id = $${index}
      RETURNING *;
      `,
      values,
    );

    const next = updateRes.rows[0];

    // STATUS CHANGE EVENTS (clean version, no status_changed spam)
    if ("status" in req.body && status !== prev.status) {
      if (next.status === "reading") {
        await createActivity(client, {
          actorId: userId,
          type: "started_reading",
          objectType: "user_book",
          objectId: String(next.id),
          targetType: "book",
          targetId: String(next.book_id),
        });
      } else if (next.status === "completed") {
        await createActivity(client, {
          actorId: userId,
          type: "finished_reading",
          objectType: "user_book",
          objectId: String(next.id),
          targetType: "book",
          targetId: String(next.book_id),
        });
      } else if (next.status === "dropped") {
        await createActivity(client, {
          actorId: userId,
          type: "dropped_book",
          objectType: "user_book",
          objectId: String(next.id),
          targetType: "book",
          targetId: String(next.book_id),
        });
      }
    }

    // RATING EVENT
    if ("rating" in req.body && rating !== prev.rating) {
      await createActivity(client, {
        actorId: userId,
        type: "rated_book",
        objectType: "user_book",
        objectId: String(next.id),
        targetType: "book",
        targetId: String(next.book_id),
        metadata: { rating },
      });
    }

    // REVIEW EVENT (only when first added)
    if ("review" in req.body && review && !prev.review) {
      await createActivity(client, {
        actorId: userId,
        type: "review_posted",
        objectType: "user_book",
        objectId: String(next.id),
        targetType: "book",
        targetId: String(next.book_id),
      });
    }

    await client.query("COMMIT");

    res.json(next);
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to update user book" });
  } finally {
    client.release();
  }
}
