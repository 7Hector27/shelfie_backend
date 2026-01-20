import { Request, Response, NextFunction } from "express";

export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.error(err);

  if (err.message === "User already exists") {
    return res.status(409).json({ error: err.message });
  }

  if (err.name === "ZodError") {
    return res.status(400).json({ error: err.errors });
  }

  res.status(500).json({ error: "Internal server error" });
};
