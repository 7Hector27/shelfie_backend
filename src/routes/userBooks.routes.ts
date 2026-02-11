import { Router } from "express";
import {
  addUserBook,
  getUserBooks,
  getBookById,
  removeUserBook,
} from "../controllers/userBooks.controller";
import { requireAuth } from "../middlewares/requireAuth";

const router = Router();

router.post("/", requireAuth, addUserBook);
router.get("/", requireAuth, getUserBooks);
router.get("/getBookById/:id", requireAuth, getBookById);
router.delete("/:externalBookId", requireAuth, removeUserBook);

export default router;
