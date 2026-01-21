import { Router } from "express";
import { register, signIn, me, logout } from "../controllers/auth.controller";

const router = Router();

router.post("/register", register);

router.post("/signIn", signIn);

router.get("/me", me);

router.post("/logout", logout);

export default router;
