import { Router } from "express";
import { searchBooksController } from "../controllers/openLibrary.controller";

const router = Router();

router.get("/search", searchBooksController);

export default router;
