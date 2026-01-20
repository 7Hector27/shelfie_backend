import { Router } from "express";
import { register, signIn } from "../controllers/auth.controller";

const router = Router();

router.post("/register", register);

router.post("/signIn", signIn);

export default router;
