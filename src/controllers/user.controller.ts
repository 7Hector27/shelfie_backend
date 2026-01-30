import { Request, Response } from "express";
import { updateProfile } from "../services/user.services";
import { uploadProfileImage } from "../services/s3";
import { pool } from "../db";

export async function uploadProfileImageController(
  req: Request,
  res: Response,
) {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }
  if (!req.user) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const imageUrl = await uploadProfileImage(
    req.file.buffer,
    req.user.id,
    req.file.mimetype,
  );

  await pool.query(
    `UPDATE profiles SET profile_image = $1 WHERE user_id = $2`,
    [imageUrl, req.user.id],
  );

  res.json({ imageUrl });
}

export async function updateUserProfile(req: Request, res: Response) {
  if (!req.user) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  await updateProfile(req.user.id, req.body);

  res.json({ message: "Profile updated successfully" });
}
