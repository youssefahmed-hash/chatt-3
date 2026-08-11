import { Router } from "express";
import { testMail } from "../controllers/test.controller.js";

const router = Router();

router.get("/mail", testMail);

export default router;