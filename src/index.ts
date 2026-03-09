import "dotenv/config";
import { createServer } from "http";
import { Server } from "socket.io";
import app from "./app";
import { connectDB } from "./db";

const PORT = process.env.PORT || 4000;

/* ============================= */
/* Create HTTP Server            */
/* ============================= */

const server = createServer(app);

/* ============================= */
/* Attach Socket.IO              */
/* ============================= */

export const io = new Server(server, {
  cors: {
    origin: process.env.CLIENT_URL || "http://localhost:3000", // ✅ use env var
    credentials: true,
  },
});

/* ============================= */
/* Socket Logic                  */
/* ============================= */

const onlineUsers = new Map<string, string>();

io.on("connection", (socket) => {
  console.log("Socket connected:", socket.id);

  socket.on("join_conversation", (conversationId: string) => {
    socket.join(conversationId);
  });

  socket.on("typing_start", ({ conversationId, userId }) => {
    socket.to(conversationId).emit("user_typing", { userId });
  });

  socket.on("typing_stop", ({ conversationId, userId }) => {
    socket.to(conversationId).emit("user_stop_typing", { userId });
  });

  socket.on("register_user", (userId: string) => {
    onlineUsers.set(userId, socket.id);
    io.emit("online_users", Array.from(onlineUsers.keys()));
  });

  socket.on("disconnect", () => {
    console.log("Socket disconnected:", socket.id);
    for (const [userId, socketId] of onlineUsers.entries()) {
      if (socketId === socket.id) {
        onlineUsers.delete(userId);
        break;
      }
    }
    io.emit("online_users", Array.from(onlineUsers.keys()));
  });
});

/* ============================= */
/* Start Server                  */
/* ============================= */

async function start() {
  await connectDB();

  server.listen(PORT, () => {
    console.log(`Backend running on port ${PORT}`);
  });
}

start();
