import { Request, Response } from "express";
import { searchUsersForFriends } from "../services/friends.services";

export async function searchFriends(req: Request, res: Response) {
  if (!req.user) return res.sendStatus(401);
  const userId = req.user.id;
  const query = req.query.q as string;

  if (!query || query.length < 2) {
    return res.status(200).json({ users: [] });
  }

  const users = await searchUsersForFriends(query, userId);

  res.json({
    users: users.map((u) => ({
      id: u.id,
      firstName: u.first_name,
      lastName: u.last_name,
      email: u.email,
      profilePictureUrl: u.profile_picture_url,
    })),
  });
}
