import express from "express";
import { env } from "./config/env.js";
import { authRouter } from "./routes/authRoutes.js";

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRouter);

app.listen(env.port, () => {
  console.log("API listening on port " + env.port);
});