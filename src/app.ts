import express from "express";
import cors from "cors";
import { Router } from "express";
import cookieParser from "cookie-parser";

import authRoutes from "./routes/auth.routes";
import userRoutes from "./routes/user.routes";
import friendsRoutes from "./routes/friends.routes";
import userBookRoutes from "./routes/userBooks.routes";
import messagesRoutes from "./routes/messages.routes";
import openLibraryRoutes from "./routes/openLibrary.routes";
import feedRoutes from "./routes/feed.routes";

import { errorHandler } from "./middlewares/error.middleware";

const app = express();
const router = Router();

/* ============================= */
/* CORS CONFIG */
/* ============================= */

app.use(
  cors({
    origin: "http://localhost:3000",
    credentials: true,
  }),
);

/* ============================= */
/* MIDDLEWARE */
/* ============================= */

app.use(cookieParser());
app.use(express.json());

/* ============================= */
/* ROUTES */
/* ============================= */

app.use("/auth", authRoutes);
app.use("/user", userRoutes);
app.use("/friends", friendsRoutes);
app.use("/openlibrary", openLibraryRoutes);
app.use("/userbooks", userBookRoutes);
app.use("/messages", messagesRoutes);
app.use("/feed", feedRoutes);
/* ============================= */
/* HEALTH CHECK */
/* ============================= */

router.get("/health", (_req, res) => {
  res.json({ status: "WE DID IT" });
});

app.use(router);

/* ============================= */
/* ERROR HANDLER (LAST) */
/* ============================= */

app.use(errorHandler);

export default app;
