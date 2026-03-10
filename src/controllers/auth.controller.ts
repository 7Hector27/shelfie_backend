import { Request, Response, NextFunction } from "express";
import * as authService from "../services/auth.services";
import { signJwt } from "../utils/jwt";
import jwt from "jsonwebtoken";
import * as userRepo from "../repositories/user.repository";

const COOKIE_NAME = "shelfie_session";

const COOKIE_OPTIONS = {
  httpOnly: true,
  secure: true,
  sameSite: "none" as const,
  maxAge: 1000 * 60 * 60 * 24 * 7,
};

export const register = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const result = await authService.register(req.body);
    const token = signJwt({ userId: result.id });

    res.cookie(COOKIE_NAME, token, COOKIE_OPTIONS);

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

    res.cookie(COOKIE_NAME, token, COOKIE_OPTIONS);

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
    secure: true,
    sameSite: "none",
  });

  return res.sendStatus(204);
};
