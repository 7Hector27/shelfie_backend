import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

const COOKIE_NAME = "shelfie_session";

export const requireAuth = (
  req: Request & { user?: { id: string } },
  res: Response,
  next: NextFunction,
) => {
  const token =
    req.cookies[COOKIE_NAME] || req.headers.authorization?.split(" ")[1];

  if (!token) {
    return res.sendStatus(401);
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as {
      userId: string;
    };

    req.user = { id: payload.userId };
    next();
  } catch {
    return res.sendStatus(401);
  }
};
