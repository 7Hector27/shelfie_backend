import { registerSchema, loginSchema } from "../validations/auth.schema";
import * as userRepo from "../repositories/user.repository";
import bcrypt from "bcrypt";

const SALT_ROUNDS = 10;

export const hashPassword = (password: string) => {
  return bcrypt.hash(password, SALT_ROUNDS);
};

export const register = async (data: unknown) => {
  // 1. Validate input
  const { email, password, firstName, lastName } = registerSchema.parse(data);

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
    first_name: firstName,
    last_name: lastName,
  });

  // 5. Return safe response
  return {
    id: user.id,
    email: user.email,
  };
};

export const login = async (data: unknown) => {
  // 1. Validate input
  const { email, password } = loginSchema.parse(data);

  // 2. Find user
  const user = await userRepo.findByEmail(email);
  if (!user) {
    throw new Error("Invalid credentials");
  }
  console.log("Found user:", user);
  // 3. Verify password
  const isValid = await bcrypt.compare(password, user.password_hash);
  if (!isValid) {
    throw new Error("Invalid credentials");
  }

  // 4. Return minimal safe data
  return {
    id: user.id,
    email: user.email,
  };
};
