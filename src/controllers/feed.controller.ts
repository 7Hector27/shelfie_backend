import { Request, Response } from "express";
import { buildUserFeed } from "../services/feed.services";

export async function getFeed(req: Request, res: Response) {
  const userId = req.user?.id;

  if (!userId) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  try {
    const limit = Number(req.query.limit) || 20;

    const feed = await buildUserFeed(userId, limit);

    res.json(feed);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch feed" });
  }
}
