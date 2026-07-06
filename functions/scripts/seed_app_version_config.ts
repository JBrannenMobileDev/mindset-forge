/**
 * One-off admin script: create/update the app_config/version doc that backs
 * AppVersionGateService (lib/core/services/app_version_gate_service.dart).
 *
 * Safe to run multiple times (merge: true) and safe to run before any gate is
 * needed — defaults to minBuildNumber: 0 / featureMinBuildNumbers: {} (no
 * gates active), matching the fail-open default the client already assumes
 * when the doc is missing entirely. Only bump these values later, deliberately,
 * when you actually want to cut a build off from the app or a specific feature.
 *
 * Usage (from functions/):
 *   npx ts-node scripts/seed_app_version_config.ts
 *   npx ts-node scripts/seed_app_version_config.ts --min-build=12 --feature=coachChat:12
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

function parseArgs(argv: string[]): {
  minBuild: number;
  features: Record<string, number>;
} {
  let minBuild = 0;
  const features: Record<string, number> = {};

  for (const arg of argv) {
    if (arg.startsWith('--min-build=')) {
      minBuild = Number(arg.replace('--min-build=', ''));
    } else if (arg.startsWith('--feature=')) {
      const [key, value] = arg.replace('--feature=', '').split(':');
      if (key && value) features[key] = Number(value);
    }
  }

  return { minBuild, features };
}

async function main(): Promise<void> {
  const { minBuild, features } = parseArgs(process.argv.slice(2));

  const ref = db.collection('app_config').doc('version');
  const existing = await ref.get();

  const payload = {
    minBuildNumber: minBuild,
    featureMinBuildNumbers: {
      coachChat: 0,
      ...features,
    },
  };

  await ref.set(payload, { merge: true });

  console.log(
    existing.exists
      ? `Updated app_config/version in ${PROJECT_ID}:`
      : `Created app_config/version in ${PROJECT_ID}:`,
  );
  console.log(JSON.stringify(payload, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
