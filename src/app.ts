import express from "express";
import cors from "cors";
import { Router } from "express";
import authRoutes from "./routes/auth.routes";
import { errorHandler } from "./middlewares/error.middleware";

const app = express();
const router = Router();

app.use(cors());
app.use(express.json());

app.use("/auth", authRoutes);

router.get("/health", (_req, res) => {
  res.json({ status: "WE DID IT" });
});

app.use(router);

// ERROR MIDDLEWARE LAST
app.use(errorHandler);

export default app;
