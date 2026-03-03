import { Router } from "express";
import {
  searchFriends,
  sendRequest,
  getRequests,
  acceptRequest,
  declineRequest,
  getFriendsList,
  deleteFriend,
} from "../controllers/friends.controller";

import { requireAuth } from "../middlewares/requireAuth";

const router = Router();

router.get("/search", requireAuth, searchFriends);
router.get("/list", requireAuth, getFriendsList);
router.post("/request", requireAuth, sendRequest);
router.get("/requests", requireAuth, getRequests);
router.post("/requests/:id/accept", requireAuth, acceptRequest);
router.post("/requests/:id/decline", requireAuth, declineRequest);
router.delete("/:friendId", requireAuth, deleteFriend);

export default router;
