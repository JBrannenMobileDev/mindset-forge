/**
 * One-off admin script: create/update app_config/mindset_progress for the
 * Blueprint Evolution lifecycle (graduation thresholds, excavation readiness).
 *
 * Usage (from functions/):
 *   npx ts-node scripts/seed_mindset_progress_config.ts
 *
 * Requires application-default credentials:
 *   gcloud auth application-default login
 */

import * as admin from 'firebase-admin';
import { MINDSET_PROGRESS_DEFAULTS } from '../src/mindset_progress';

const PROJECT_ID = 'mindsetforge-ai';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

async function main(): Promise<void> {
  const ref = db.collection('app_config').doc('mindset_progress');
  const existing = await ref.get();

  await ref.set(MINDSET_PROGRESS_DEFAULTS, { merge: true });

  console.log(
    existing.exists
      ? `Updated app_config/mindset_progress in ${PROJECT_ID}:`
      : `Created app_config/mindset_progress in ${PROJECT_ID}:`,
  );
  console.log(JSON.stringify(MINDSET_PROGRESS_DEFAULTS, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
