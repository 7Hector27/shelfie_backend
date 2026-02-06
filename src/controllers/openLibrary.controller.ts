import { Request, Response } from "express";
import { searchBooks } from "../services/openLibrary.services";

export const searchBooksController = async (req: Request, res: Response) => {
  const { q, limit } = req.query;

  if (!q || typeof q !== "string") {
    return res.status(400).json({ docs: [] });
  }

  try {
    const docs = await searchBooks(q, Number(limit) || 5);
    res.status(200).json({ docs });
  } catch (err) {
    res.status(503).json({ docs: [] });
  }
};
