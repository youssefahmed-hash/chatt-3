import { Router } from 'express';
import { listCalls, logCall } from '../controllers/call.controller.js';
import { protect } from '../middleware/auth.js';

const router = Router();

router.use(protect);

router.get('/', listCalls);
router.post('/', logCall);

export default router;
