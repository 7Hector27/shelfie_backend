import express from "express";
import {
  uploadProfileImageController,
  updateUserProfile,
} from "../controllers/user.controller";
import { requireAuth } from "../middlewares/requireAuth";
import { upload } from "../middlewares/upload";

const router = express.Router();

router.post(
  "/profile-image",
  requireAuth,
  upload.single("image"),
  uploadProfileImageController,
);

router.post("/profile", requireAuth, updateUserProfile);

export default router;
