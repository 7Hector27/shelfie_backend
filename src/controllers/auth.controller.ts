import { Request, Response, NextFunction } from "express";
import * as authService from "../services/auth.services";
import { signJwt } from "../utils/jwt";
import jwt from "jsonwebtoken";
import * as userRepo from "../repositories/user.repository";

const COOKIE_NAME = "shelfie_session";

export const register = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const result = await authService.register(req.body);
    // 🔐 create session
    const token = signJwt({ userId: result.id });

    res.cookie(COOKIE_NAME, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
    });

    console.log("Registered & logged in user:", result);

    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
};

export const signIn = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const user = await authService.login(req.body);

    const token = signJwt({ userId: user.id });

    res.cookie(COOKIE_NAME, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: 1000 * 60 * 60 * 24 * 7,
    });

    res.json(user);
  } catch (error: any) {
    if (error.message === "Invalid credentials") {
      return res.status(401).json({
        error: "Invalid email or password",
      });
    }
  }
};

export const me = async (req: Request, res: Response) => {
  const token = req.cookies[COOKIE_NAME];

  if (!token) {
    return res.sendStatus(401);
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as {
      userId: string;
    };
    const user = await userRepo.findById(payload.userId);
    console.log("Fetched current user:", user);
    return res.json({
      ...user,
    });
  } catch {
    return res.sendStatus(401);
  }
};

export const logout = (_req: Request, res: Response) => {
  res.clearCookie(COOKIE_NAME, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
  });

  return res.sendStatus(204);
};
