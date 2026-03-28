import { Router } from "express";
import { login, register } from "../modules/auth/authService.js";

export const authRouter = Router();

authRouter.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body || {};
    if (!username || !email || !password) {
      return res.status(400).json({ error: "username, email, password required" });
    }

    const user = await register({ username, email, password });
    return res.status(201).json(user);
  } catch (err) {
    if (err?.code === "23505") {
      return res.status(409).json({ error: "username or email already exists" });
    }
    return res.status(500).json({ error: "register failed" });
  }
});

authRouter.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: "email, password required" });
    }

    const result = await login({ email, password });
    if (!result) {
      return res.status(401).json({ error: "invalid credentials" });
    }

    return res.json(result);
  } catch {
    return res.status(500).json({ error: "login failed" });
  }
});