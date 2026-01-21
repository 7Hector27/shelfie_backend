import { Router } from "express";
import { register, signIn, me } from "../controllers/auth.controller";

const router = Router();

router.post("/register", register);

router.post("/signIn", signIn);

router.get("/me", me);

export default router;
