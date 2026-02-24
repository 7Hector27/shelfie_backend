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
    const countsResult = await pool.query(
      `
  SELECT
    COUNT(*)::int AS total,
    COUNT(*) FILTER (WHERE status = 'want_to_read')::int AS want_to_read,
    COUNT(*) FILTER (WHERE status = 'reading')::int AS reading,
    COUNT(*) FILTER (WHERE status = 'completed')::int AS completed,
    COUNT(*) FILTER (WHERE status = 'dropped')::int AS dropped,
    COUNT(*) FILTER (WHERE favorite = true)::int AS favorites
  FROM user_books
  WHERE user_id = $1
  `,
      [id],
    );

    const counts = countsResult.rows[0];

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

    res.json({
      user: {
        ...userResult[0],
      },
      currentlyReading: currentlyReadingResult.rows,
      shelves: {
        total: counts.total,
        wantToRead: counts.want_to_read,
        currentlyReading: counts.reading,
        read: counts.completed,
        dropped: counts.dropped,
        favorites: counts.favorites,
      },
      friendsPreview: friendsResult.rows,
    });
  } catch (err) {
    console.error("Error fetching user profile:", err);
    res.status(500).json({ error: "Internal server error" });
  }
}

export async function getUserBooks(req: Request, res: Response) {
  try {
    const { id: userId } = req.params;
    const { shelf, favorite, page = "1", limit = "10" } = req.query;

    const pageNumber = parseInt(page as string, 10);
    const limitNumber = parseInt(limit as string, 10);
    const offset = (pageNumber - 1) * limitNumber;

    // base filter
    let where = `WHERE user_id = $1`;
    const values: any[] = [userId];
    let paramIndex = 2;

    if (shelf) {
      where += ` AND status = $${paramIndex}`;
      values.push(shelf);
      paramIndex++;
    }

    if (favorite) {
      where += ` AND favorite = $${paramIndex}`;
      values.push(favorite === "true");
      paramIndex++;
    }

    // 1) total count
    const countQuery = `
      SELECT COUNT(*)::int AS total
      FROM user_books
      ${where}
    `;
    const countRes = await pool.query(countQuery, values);
    const total = countRes.rows[0]?.total ?? 0;

    // 2) paged data
    const dataQuery = `
  SELECT 
    ub.*,  
    ub.rating::float AS rating,
    b.title,
    b.author,
    b.author_id,
    b.cover_url,
    b.description
  FROM user_books ub
  JOIN books b ON ub.book_id = b.id
  ${where.replace("WHERE user_id", "WHERE ub.user_id")}
  ORDER BY ub.updated_at DESC
  LIMIT $${paramIndex}
  OFFSET $${paramIndex + 1}
`;
    const countsResult = await pool.query(
      `
  SELECT
    COUNT(*)::int AS total,
    COUNT(*) FILTER (WHERE status = 'want_to_read')::int AS want_to_read,
    COUNT(*) FILTER (WHERE status = 'reading')::int AS reading,
    COUNT(*) FILTER (WHERE status = 'completed')::int AS completed,
    COUNT(*) FILTER (WHERE status = 'dropped')::int AS dropped,
    COUNT(*) FILTER (WHERE favorite = true)::int AS favorites
  FROM user_books
  WHERE user_id = $1
  `,
      [userId],
    );

    const counts = countsResult.rows[0];

    const dataValues = [...values, limitNumber, offset];
    const { rows } = await pool.query(dataQuery, dataValues);

    const totalPages = Math.max(1, Math.ceil(total / limitNumber));
    // Fetch profile
    const profileResult = await pool.query(
      `SELECT * FROM profiles WHERE user_id = $1`,
      [userId],
    );

    const profile = profileResult.rows[0] || null;
    res.json({
      data: rows,
      pagination: {
        page: pageNumber,
        limit: limitNumber,
        total,
        totalPages,
        hasNextPage: pageNumber < totalPages,
        hasPrevPage: pageNumber > 1,
      },
      counts: {
        total: counts.total,
        wantToRead: counts.want_to_read,
        currentlyReading: counts.reading,
        read: counts.completed,
        dropped: counts.dropped,
        favorites: counts.favorites,
      },
      profile: profile,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to fetch user books" });
  }
}
