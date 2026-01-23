import { Router } from "express";
import { searchFriends } from "../controllers/friends.controller";
import { requireAuth } from "../middlewares/requireAuth";

const router = Router();

router.get("/search", requireAuth, searchFriends);

export default router;
