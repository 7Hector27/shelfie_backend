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

export async function getUserProfile(req: Request, res: Response) {
  const { id } = req.params;

  if (!req.user) {
    return res.status(400).json({ error: "Unauthorized" });
  }
  try {
    // 1. Basic user info
    const { rows: userResult } = await pool.query(
      `
      SELECT user_id, first_name, last_name, profile_image, bio, created_at, birthdate
      FROM profiles
      WHERE user_id = $1
      `,
      [id],
    );

    // 2. Shelf counts
    const shelvesResult = await pool.query(
      `
      SELECT status, COUNT(*) as count
      FROM user_books
      WHERE user_id = $1
      GROUP BY status
      `,
      [id],
    );
    const favoritesResult = await pool.query(
      `
      SELECT COUNT(*) 
      FROM user_books
      WHERE user_id = $1 AND favorite = true
      `,
      [id],
    );

    const shelves = {
      wantToRead: 0,
      currentlyReading: 0,
      read: 0,
      dropped: 0,
      favorites: Number(favoritesResult.rows[0].count),
    };

    shelvesResult.rows.forEach((row) => {
      if (row.status === "want_to_read") shelves.wantToRead = Number(row.count);
      if (row.status === "reading")
        shelves.currentlyReading = Number(row.count);
      if (row.status === "read") shelves.read = Number(row.count);
      if (row.status === "dropped") shelves.dropped = Number(row.count);
    });

    // 3. Currently reading preview
    const currentlyReadingResult = await pool.query(
      `
  SELECT 
    ub.id as user_book_id,
    ub.book_id,
    ub.status,
    ub.updated_at as shelf_updated_at,
    b.title,
    b.cover_url,
    b.author
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  WHERE ub.user_id = $1 
    AND ub.status = 'reading'
  ORDER BY ub.updated_at DESC
  LIMIT 5
  `,
      [id],
    );

    // 4. Friends preview
    const friendsResult = await pool.query(
      `
  SELECT 
    p.user_id,
    p.first_name,
    p.last_name,
    p.profile_image, 
    (
      SELECT COUNT(*)
      FROM friendships f2
      WHERE f2.user_id = p.user_id
    ) AS friends_count, 
    (
      SELECT COUNT(*)
      FROM user_books ub
      WHERE ub.user_id = p.user_id
    ) AS books_count

  FROM friendships f
  JOIN profiles p ON p.user_id = f.friend_id
  WHERE f.user_id = $1
  LIMIT 5
  `,
      [id],
    );

    const friendsCountResult = await pool.query(
      `
      SELECT COUNT(*) 
      FROM friendships
      WHERE user_id = $1
      `,
      [id],
    );

    res.json({
      user: {
        ...userResult[0],
      },
      stats: {
        friendsCount: Number(friendsCountResult.rows[0].count),
        currentlyReadingCount: shelves.currentlyReading,
        readCount: shelves.read,
      },
      currentlyReading: currentlyReadingResult.rows,
      shelves,
      friendsPreview: friendsResult.rows,
    });
  } catch (err) {
    console.error("Error fetching user profile:", err);
    res.status(500).json({ error: "Internal server error" });
  }
}
