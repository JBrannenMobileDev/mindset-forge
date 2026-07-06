/**
 * One-off admin script: list subscription candidates and migrate comped users
 * to subscriptionStatus 'lifetime' (protected from RevenueCat webhook downgrades).
 *
 * Usage (from functions/):
 *   npx ts-node scripts/migrate_comped_users.ts list
 *   npx ts-node scripts/migrate_comped_users.ts migrate --uids uid1,uid2
 *   npx ts-node scripts/migrate_comped_users.ts migrate --no-expiry [--dry-run]
 *
 * Requires application-default credentials:
 *   gcloud auth application-default login
 *   gcloud config set project mindsetforge-ai
 */

import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const CANDIDATE_STATUSES = ['active', 'trialing', 'canceled'] as const;

type UserRow = {
  uid: string;
  email: string;
  displayName: string;
  userType: string;
  subscriptionStatus: string;
  subscriptionExpiresAt: string | null;
};

async function fetchCandidates(): Promise<UserRow[]> {
  const rows: UserRow[] = [];

  for (const status of CANDIDATE_STATUSES) {
    const snap = await db
      .collection('users')
      .where('subscriptionStatus', '==', status)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      rows.push({
        uid: doc.id,
        email: (data.email as string | undefined) ?? '',
        displayName: (data.displayName as string | undefined) ?? '',
        userType: (data.userType as string | undefined) ?? 'user',
        subscriptionStatus: (data.subscriptionStatus as string | undefined) ?? status,
        subscriptionExpiresAt:
          (data.subscriptionExpiresAt as string | undefined) ?? null,
      });
    }
  }

  rows.sort((a, b) => a.email.localeCompare(b.email));
  return rows;
}

function printCandidates(rows: UserRow[]): void {
  if (rows.length === 0) {
    console.log('No users with subscriptionStatus in active/trialing/canceled.');
    return;
  }

  console.log(
    `Found ${rows.length} candidate(s). Manual comps often have null subscriptionExpiresAt.\n`,
  );
  console.log(
    'uid\temail\tdisplayName\tuserType\tstatus\texpiresAt',
  );
  for (const row of rows) {
    console.log(
      `${row.uid}\t${row.email || '(no email)'}\t${row.displayName || '(no name)'}\t${row.userType}\t${row.subscriptionStatus}\t${row.subscriptionExpiresAt ?? 'null'}`,
    );
  }
}

async function migrateUids(uids: string[], dryRun: boolean): Promise<void> {
  if (uids.length === 0) {
    console.error('No UIDs provided.');
    process.exit(1);
  }

  for (const uid of uids) {
    const ref = db.collection('users').doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
      console.warn(`SKIP ${uid}: user doc not found`);
      continue;
    }

    const data = snap.data() as {
      email?: string;
      subscriptionStatus?: string;
      userType?: string;
    };

    if (data.subscriptionStatus === 'lifetime') {
      console.log(`SKIP ${uid}: already lifetime`);
      continue;
    }

    if (data.userType === 'admin') {
      console.warn(`SKIP ${uid}: admin account (no migration needed)`);
      continue;
    }

    const label = data.email ?? uid;
    if (dryRun) {
      console.log(
        `[dry-run] Would set ${label} (${uid}) subscriptionStatus: '${data.subscriptionStatus}' -> 'lifetime'`,
      );
      continue;
    }

    await ref.update({ subscriptionStatus: 'lifetime' });
    console.log(`Migrated ${label} (${uid}) -> lifetime`);
  }
}

async function migrateNoExpiry(dryRun: boolean): Promise<void> {
  const candidates = await fetchCandidates();
  const likelyComped = candidates.filter(
    (row) =>
      row.subscriptionExpiresAt == null &&
      row.userType !== 'admin' &&
      row.userType !== 'partner',
  );

  if (likelyComped.length === 0) {
    console.log('No active/trialing/canceled users with null subscriptionExpiresAt.');
    return;
  }

  console.log(
    `${dryRun ? '[dry-run] ' : ''}Migrating ${likelyComped.length} user(s) with null subscriptionExpiresAt:\n`,
  );
  await migrateUids(
    likelyComped.map((row) => row.uid),
    dryRun,
  );
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);

  if (command === 'list') {
    printCandidates(await fetchCandidates());
    return;
  }

  if (command === 'migrate') {
    const dryRun = args.includes('--dry-run');
    const uidsArg = args.find((a) => a.startsWith('--uids='));
    if (uidsArg) {
      const uids = uidsArg.replace('--uids=', '').split(',').map((s) => s.trim()).filter(Boolean);
      await migrateUids(uids, dryRun);
      return;
    }

    if (args.includes('--no-expiry')) {
      await migrateNoExpiry(dryRun);
      return;
    }

    console.error(
      'Usage: migrate --uids=uid1,uid2 [--dry-run] | migrate --no-expiry [--dry-run]',
    );
    process.exit(1);
  }

  console.error('Usage: list | migrate --uids=... | migrate --no-expiry [--dry-run]');
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
