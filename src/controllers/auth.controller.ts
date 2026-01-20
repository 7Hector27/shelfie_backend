import { Request, Response, NextFunction } from "express";
import * as authService from "../services/auth.services";
import { signJwt } from "../utils/jwt";

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
  } catch (err) {
    next(err);
  }
};
