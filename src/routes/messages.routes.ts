import { Router } from "express";
import {
  getUserConversations,
  startConversation,
  getConversationById,
  sendMessage,
  markConversationReadController,
} from "../controllers/messages.controller";
import { requireAuth } from "../middlewares/requireAuth";

const router = Router();

router.get("/", requireAuth, getUserConversations);
router.post("/start", requireAuth, startConversation);
router.get("/:conversationId", requireAuth, getConversationById);
router.post("/:conversationId", requireAuth, sendMessage);
router.post(
  "/:conversationId/read",
  requireAuth,
  markConversationReadController,
);

export default router;
