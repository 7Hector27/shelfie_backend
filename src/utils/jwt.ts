import jwt from "jsonwebtoken";
import "dotenv/config";

const JWT_SECRET = process.env.JWT_SECRET!;
if (!JWT_SECRET) {
  throw new Error("JWT_SECRET is not defined");
}
export const signJwt = (payload: { userId: string }) => {
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: "7d",
  });
};
