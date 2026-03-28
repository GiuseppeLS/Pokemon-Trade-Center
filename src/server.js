import express from "express";
import { env } from "./config/env.js";
const app = express();
app.use(express.json());
app.get("/health", (_req, res) => res.json({ status: "ok" }));
app.listen(env.port, () => console.log(`API on ${env.port}`));
