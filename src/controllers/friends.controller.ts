import { Request, Response } from "express";
import {
  searchUsersForFriends,
  sendFriendRequest,
  getIncomingFriendRequests,
  acceptFriendRequest,
  declineFriendRequest,
} from "../services/friends.services";

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

export async function sendRequest(req: Request, res: Response) {
  const { receiverId } = req.body;

  if (!receiverId) {
    return res.status(400).json({ error: "receiverId required" });
  }

  await sendFriendRequest(req.user!.id, receiverId);
  res.sendStatus(204);
}

export async function getRequests(req: Request, res: Response) {
  const requests = await getIncomingFriendRequests(req.user!.id);
  res.json({ requests });
}

export async function acceptRequest(req: Request, res: Response) {
  const requestId = req.params.id;

  if (typeof requestId !== "string") {
    return res.status(400).json({ error: "Invalid request id" });
  }

  await acceptFriendRequest(requestId, req.user!.id);
  res.sendStatus(204);
}

export async function declineRequest(req: Request, res: Response) {
  const requestId = req.params.id;

  if (typeof requestId !== "string") {
    return res.status(400).json({ error: "Invalid request id" });
  }

  await declineFriendRequest(requestId, req.user!.id);
  res.sendStatus(204);
}
