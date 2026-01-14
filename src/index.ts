import express from "express";
import cors from "cors";
import { createServer } from "http";
import { Router } from "express";

const app = express();
const router = Router();
const PORT = 4000;

app.use(cors());
app.use(express.json());
app.use(router);

const server = createServer(app);

router.get("/health", (_req, res) => {
  res.json({ status: "WE DID IT" });
});

server.listen(PORT, () => {
  console.log(`Backend running on http://localhost:${PORT}`);
});
