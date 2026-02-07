import { Router } from "express";
import {
  searchBooksController,
  getWorkController,
  getAuthorController,
} from "../controllers/openLibrary.controller";

const router = Router();

router.get("/search", searchBooksController);

router.get("/works/:id", getWorkController);

router.get("/authors", getAuthorController);

export default router;
