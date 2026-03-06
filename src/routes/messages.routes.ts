import { Router } from "express";
import {
  getUserConversations,
  startConversation,
  startAiConversation,
  getConversationById,
  sendMessage,
  markConversationReadController,
  deleteConversation,
} from "../controllers/messages.controller";
import { requireAuth } from "../middlewares/requireAuth";

const router = Router();

router.get("/", requireAuth, getUserConversations);
router.post("/start", requireAuth, startConversation);
router.post("/start-ai", requireAuth, startAiConversation);
router.get("/:conversationId", requireAuth, getConversationById);
router.post("/:conversationId", requireAuth, sendMessage);
router.post(
  "/:conversationId/read",
  requireAuth,
  markConversationReadController,
);
router.delete("/conversation/:conversationId", requireAuth, deleteConversation);

export default router;
