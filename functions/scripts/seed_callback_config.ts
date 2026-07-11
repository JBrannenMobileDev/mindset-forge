/**
 * One-off admin script: create/update app_config/callback for the Coach
 * Callback Engine (confidence threshold, cooldown, warm-up gates, etc.).
 *
 * Usage (from functions/):
 *   npx ts-node scripts/seed_callback_config.ts
 *
 * Requires application-default credentials:
 *   gcloud auth application-default login
 */

import * as admin from 'firebase-admin';

const PROJECT_ID = 'mindsetforge-ai';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

const DEFAULTS = {
  confidenceThreshold: 0.72,
  cooldownDays: 5,
  positiveBiasMargin: 0.08,
  warmupMinAccountAgeDays: 7,
  warmupMinActiveDays: 5,
  targetLocalHour: 11,
};

async function main(): Promise<void> {
  const ref = db.collection('app_config').doc('callback');
  const existing = await ref.get();

  await ref.set(DEFAULTS, { merge: true });

  console.log(
    existing.exists
      ? `Updated app_config/callback in ${PROJECT_ID}:`
      : `Created app_config/callback in ${PROJECT_ID}:`,
  );
  console.log(JSON.stringify(DEFAULTS, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
