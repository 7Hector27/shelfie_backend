import express from "express";
import cors from "cors";
import { Router } from "express";
import authRoutes from "./routes/auth.routes";
import userRouters from "./routes/user.routes";
import friendsRoutes from "./routes/friends.routes";
import { errorHandler } from "./middlewares/error.middleware";
import cookieParser from "cookie-parser";

const app = express();
const router = Router();

app.use(
  cors({
    origin: "http://localhost:3000", // 👈 exact origin
    credentials: true, // 👈 REQUIRED for cookies
  }),
);

app.use(cookieParser());
app.use(express.json());

app.use("/auth", authRoutes);
app.use("/user", userRouters);
app.use("/friends", friendsRoutes);

router.get("/health", (_req, res) => {
  res.json({ status: "WE DID IT" });
});

app.use(router);

// ERROR MIDDLEWARE LAST
app.use(errorHandler);

export default app;
