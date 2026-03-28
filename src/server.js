import express from "express";
import { env } from "./config/env.js";
import { authRouter } from "./routes/authRoutes.js";
import { matchRouter } from "./routes/matchRoutes.js";
import { pokemonRouter } from "./routes/pokemonRoutes.js";
import { reportRouter } from "./routes/reportRoutes.js";
import { tradeRouter } from "./routes/tradeRoutes.js";

const app = express();
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRouter);
app.use("/pokemon", pokemonRouter);
app.use("/trades", tradeRouter);
app.use("/match", matchRouter);
app.use("/report", reportRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(env.port, () => {
  console.log("Pokemon Trade Center API listening on port " + env.port);
});
