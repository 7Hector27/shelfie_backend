import { Request, Response } from "express";
import { pool } from "../db";

export async function addUserBook(req: Request, res: Response) {
  const userId = req.user?.id;
  const { external_book_id, external_source, status } = req.body;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  if (!external_book_id || !external_source) {
    return res.status(400).json({ error: "Missing book info" });
  }

  try {
    const { rows } = await pool.query(
      `
      INSERT INTO user_books (
        user_id,
        external_book_id,
        external_source,
        status,
        created_at,
        updated_at,
        favorite
      )
      VALUES ($1, $2, $3, $4, NOW(), NOW(), false)
      RETURNING *
      `,
      [userId, external_book_id, external_source, status ?? "want_to_read"],
    );

    res.status(201).json(rows[0]);
  } catch (err: any) {
    if (err.code === "23505") {
      return res
        .status(409)
        .json({ error: "Book already added to your shelf" });
    }

    console.error(err);
    res.status(500).json({ error: "Failed to add book" });
  }
}
