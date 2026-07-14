/**
 * Seeds app_config/blog with an empty admin UID list.
 *
 * Usage:
 *   1. Create your admin Firebase Auth user (email/password) in the console
 *      or via the admin app login flow once deployed.
 *   2. Copy the UID from Firebase Console → Authentication.
 *   3. Run: npx ts-node scripts/seed_blog_config.ts YOUR_UID
 *
 * Or set BLOG_ADMIN_UIDS env (comma-separated) before running.
 */
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

async function main() {
  const fromArgs = process.argv.slice(2).filter((arg) => !arg.startsWith('-'));
  const fromEnv = (process.env.BLOG_ADMIN_UIDS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const adminUids = [...new Set([...fromArgs, ...fromEnv])];

  await db.doc('app_config/blog').set(
    {
      adminUids,
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );

  console.log(
    `Seeded app_config/blog with ${adminUids.length} admin UID(s):`,
    adminUids.length > 0 ? adminUids.join(', ') : '(none — add UIDs and re-run)',
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
