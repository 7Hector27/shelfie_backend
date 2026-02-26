import { Request, Response } from "express";
import * as messagesService from "../services/messages.service";

export const getUserConversations = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }
    const userId = req.user.id;

    const conversations = await messagesService.getUserConversations(userId);

    return res.status(200).json(conversations);
  } catch (error) {
    console.error("getUserConversations error:", error);
    return res.status(500).json({ message: "Failed to fetch conversations" });
  }
};
export const startConversation = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const { friendId } = req.body;

    if (!friendId) {
      return res.status(400).json({ message: "friendId required" });
    }

    const conversation = await messagesService.startConversation(
      req.user.id,
      friendId,
    );

    return res.status(200).json(conversation);
  } catch (error) {
    console.error("startConversation error:", error);
    return res.status(500).json({ message: "Failed to start conversation" });
  }
};

export const getConversationById = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const { conversationId } = req.params;

    if (!conversationId || Array.isArray(conversationId)) {
      return res.status(400).json({ message: "Invalid conversation id" });
    }

    const conversation = await messagesService.getConversationById(
      conversationId,
      req.user.id,
    );

    return res.status(200).json(conversation);
  } catch (error) {
    console.error("getConversationById error:", error);
    return res.status(500).json({ message: "Failed to fetch conversation" });
  }
};

export const sendMessage = async (req: Request, res: Response) => {
  try {
    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const { conversationId } = req.params;
    const { body } = req.body;

    if (!conversationId || Array.isArray(conversationId)) {
      return res.status(400).json({ message: "Invalid conversation id" });
    }

    if (!body || !body.trim()) {
      return res.status(400).json({ message: "Message body required" });
    }

    const message = await messagesService.sendMessage(
      conversationId,
      req.user.id,
      body.trim(),
    );

    return res.status(201).json(message);
  } catch (error) {
    console.error("sendMessage error:", error);
    return res.status(500).json({ message: "Failed to send message" });
  }
};

import { markConversationAsRead } from "../services/messages.service";

export const markConversationReadController = async (
  req: any,
  res: any,
  next: any,
) => {
  try {
    const { conversationId } = req.params;
    const userId = req?.user.id;
    if (!conversationId || !userId) {
      return res.status(400).json({ message: "Missing data" });
    }
    const result = await markConversationAsRead(conversationId, userId);

    res.json(result);
  } catch (error) {
    next(error);
  }
};
