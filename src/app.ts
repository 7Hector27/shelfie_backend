import express from "express";
import cors from "cors";
import { Router } from "express";

const app = express();
const router = Router();

app.use(cors());
app.use(express.json());

router.get("/health", (_req, res) => {
  res.json({ status: "WE DID IT" });
});

app.use(router);

export default app;
