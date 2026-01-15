import "dotenv/config";
import { createServer } from "http";
import app from "./app";
import { connectDB } from "./db";

const PORT = process.env.PORT || 4000;

const server = createServer(app);
async function start() {
  await connectDB();

  server.listen(PORT, () => {
    console.log(`Backend running on http://localhost:${PORT}`);
  });
}

start();
