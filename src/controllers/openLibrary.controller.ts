import { Request, Response } from "express";
import {
  searchBooks,
  getWorkById,
  getAuthorByKey,
} from "../services/openLibrary.services";

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

export const getWorkController = async (req: Request, res: Response) => {
  const { id } = req.params;

  if (typeof id !== "string") {
    return res.status(400).json({ error: "Invalid work id" });
  }

  try {
    const data = await getWorkById(id);
    res.status(200).json(data);
  } catch {
    res.status(503).json({ error: "Work unavailable" });
  }
};

export const getAuthorController = async (req: Request, res: Response) => {
  const { key } = req.query;

  if (typeof key !== "string") {
    return res.status(400).json({ error: "Invalid author key" });
  }

  try {
    const data = await getAuthorByKey(key);
    res.status(200).json(data);
  } catch {
    res.status(503).json({ error: "Author unavailable" });
  }
};
