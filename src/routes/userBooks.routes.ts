import { Router } from "express";
import { addUserBook } from "../controllers/userBooks.controller";
import { requireAuth } from "../middlewares/requireAuth";

const router = Router();

router.post("/", requireAuth, addUserBook);

export default router;
