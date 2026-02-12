import { Request, Response } from "express";
import { pool } from "../db";

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

  try {
    // Check if book exists
    const existingBook = await pool.query(
      `SELECT id FROM books WHERE id = $1`,
      [book_id],
    );

    // If not, insert it
    if (existingBook.rows.length === 0) {
      await pool.query(
        `
        INSERT INTO books (id, title, author, description, cover_url, author_id)
        VALUES ($1, $2, $3, $4, $5, $6)
        `,
        [book_id, title, author, description, cover_url, author_id],
      );
    }

    // Now insert into user_books (your original logic)
    const { rows } = await pool.query(
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

    res.status(201).json(rows[0]);
  } catch (err: any) {
    console.error(err);
    res.status(500).json({ error: "Failed to add book" });
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
