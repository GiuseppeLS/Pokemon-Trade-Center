import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { env } from "../config/env.js";
import { login, register } from "../modules/auth/authService.js";

export const authRouter = Router();

function internalErrorPayload(message, error) {
  if (env.nodeEnv === "development") {
    return { error: message, code: error?.code, detail: error?.message };
  }
  return { error: message };
}

authRouter.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body ?? {};
    if (!username || !email || !password) return res.status(400).json({ error: "username, email, and password are required" });
    const user = await register({ username, email, password });
    return res.status(201).json(user);
  } catch (error) {
    if (error?.code === "23505") return res.status(409).json({ error: "Username or email already exists" });
    console.error("Register error:", error);
    return res.status(500).json(internalErrorPayload("Failed to register user", error));
  }
});

authRouter.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) return res.status(400).json({ error: "email and password are required" });
    const result = await login({ email, password });
    if (!result) return res.status(401).json({ error: "Invalid credentials" });
    return res.json(result);
  } catch (error) {
    console.error("Login error:", error);
    return res.status(500).json(internalErrorPayload("Failed to login", error));
  }
});

authRouter.get("/me", requireAuth, async (req, res) => {
  return res.json({ id: req.user.sub, username: req.user.username });
});
