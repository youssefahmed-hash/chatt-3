import { db } from '../config/database.js';

// db.sync({ alter: true }) cannot add values to an existing PostgreSQL ENUM.
// This helper adds any new message type values to the existing enum before
// sync runs, so a running production DB is upgraded without recreating the
// column. It is a no-op on a fresh database (the enum is created with all
// values from the model).
export async function ensureEnumValues() {
  const enumName = 'enum_messages_type';
  const values = ['file', 'video'];

  try {
    const [res] = await db.query(
      `SELECT t.typname AS name
         FROM pg_type t
         JOIN pg_enum e ON e.enumtypid = t.oid
        WHERE t.typname = $1
        GROUP BY t.typname
        HAVING count(*) > 0`,
      { bind: [enumName] },
    );

    if (!res || res.length === 0) {
      // Enum does not exist yet (fresh DB) — nothing to migrate.
      return;
    }

    for (const value of values) {
      const [existing] = await db.query(
        `SELECT 1
           FROM pg_enum e
           JOIN pg_type t ON e.enumtypid = t.oid
          WHERE t.typname = $1 AND e.enumlabel = $2`,
        { bind: [enumName, value] },
      );

      if (!existing || existing.length === 0) {
        await db.query(
          `ALTER TYPE ${enumName} ADD VALUE :value`,
          { replacements: { value } },
        );
      }
    }
  } catch (err) {
    // The column may not be an enum (e.g. it was already varchar), or the
    // enum lives under a different name. Log and continue — sync will still
    // work for the rest of the schema.
    console.error('⚠️ ensureEnumValues skipped:', err.message);
  }
}
