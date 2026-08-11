// Seeds a few demo users so you can log in and test immediately.
// Run with:  npm run seed
import { connectDB, db } from '../config/database.js';
import { User } from '../models/User.js';

const DEMO_USERS = [
  { name: 'Ahmed', email: 'ahmed@chatt.dev', password: '123456' },
  { name: 'Sara', email: 'sara@chatt.dev', password: '123456' },
  { name: '3abasya', email: '3abasya@chatt.dev', password: '123456' },
];

async function seed() {
  await connectDB();

  for (const u of DEMO_USERS) {
    const existing = await User.findOne({ where: { email: u.email } });
    if (existing) {
      console.log(`• ${u.email} already exists`);
      continue;
    }
    const user = await User.create({
      name: u.name,
      email: u.email,
      passwordHash: u.password, // Will be hashed by the hook
    });
    console.log(`✓ created ${u.email} (password: ${u.password})`);
  }

  await db.close();
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed error:', err.message);
  process.exit(1);
});
