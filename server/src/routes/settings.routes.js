import { Router } from "express";
import { getSettings, updateSettings, testOtp } from "../controllers/settings.controller.js";
import { protect, adminOnly } from "../middleware/auth.js";

const router = Router();

// Apply admin protection to all settings routes
router.use(protect, adminOnly);

router.get("/", getSettings);
router.put("/", updateSettings);
router.post("/test-otp", testOtp);

export default router;
