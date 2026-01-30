import express from "express";
import { uploadProfileImageController } from "../controllers/user.controller";
import { requireAuth } from "../middlewares/requireAuth";
import { upload } from "../middlewares/upload";

const router = express.Router();

router.post(
  "/profile-image",
  requireAuth,
  upload.single("image"),
  uploadProfileImageController,
);

export default router;
