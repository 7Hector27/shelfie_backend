import { registerSchema } from "../validations/auth.schema";
import * as userRepo from "../repositories/user.repository";
import bcrypt from "bcrypt";

const SALT_ROUNDS = 10;

export const hashPassword = (password: string) => {
  return bcrypt.hash(password, SALT_ROUNDS);
};

export const register = async (data: unknown) => {
  // 1. Validate input
  const { email, password } = registerSchema.parse(data);

  // 2. Check if user exists
  const existingUser = await userRepo.findByEmail(email);
  if (existingUser) {
    throw new Error("User already exists");
  }

  // 3. Hash password
  const hashedPassword = await hashPassword(password);

  // 4. Create user
  const user = await userRepo.create({
    email,
    password: hashedPassword,
  });

  // 5. Return safe response
  return {
    id: user.id,
    email: user.email,
  };
};
