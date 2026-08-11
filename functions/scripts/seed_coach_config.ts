/**
 * Seeds app_config/roles with the analyst allowlist and the coach signup codes.
 *
 * `analystUids` grants coach-level READ access to every team (firestore.rules
 * isAnalyst() plus assertTeamAccess in coach.ts). `coachSignupCodes` is what
 * initializeCoachAccount validates, so anything in that array can mint a coach
 * account on the public signup page. Both are denied to clients in
 * firestore.rules and must never be logged or pasted anywhere shared.
 *
 * Usage:
 *   1. Create the analyst Firebase Auth user, then copy its UID from
 *      Firebase Console → Authentication.
 *   2. Run one of:
 *        npx ts-node scripts/seed_coach_config.ts --analyst=UID --code=SECRET
 *        ANALYST_UIDS=uid1,uid2 COACH_SIGNUP_CODES=code1,code2 \
 *          npx ts-node scripts/seed_coach_config.ts
 *
 * Merges by default, so an existing list is preserved and new values are added.
 * Pass --replace to overwrite instead, which is how you REVOKE a code or an
 * analyst: rerun with --replace and only the values you want to keep.
 */
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

const ROLES_DOC_PATH = 'app_config/roles';

function fromFlag(args: string[], name: string): string[] {
  return args
    .filter((arg) => arg.startsWith(`--${name}=`))
    .map((arg) => arg.slice(name.length + 3).trim())
    .filter(Boolean);
}

function fromEnv(name: string): string[] {
  return (process.env[name] ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

async function main() {
  const args = process.argv.slice(2);
  const replace = args.includes('--replace');

  const analystUids = [
    ...new Set([...fromFlag(args, 'analyst'), ...fromEnv('ANALYST_UIDS')]),
  ];
  const coachSignupCodes = [
    ...new Set([...fromFlag(args, 'code'), ...fromEnv('COACH_SIGNUP_CODES')]),
  ];

  if (analystUids.length === 0 && coachSignupCodes.length === 0) {
    console.error(
      'Nothing to seed. Pass --analyst=UID and/or --code=SECRET, or set '
        + 'ANALYST_UIDS / COACH_SIGNUP_CODES.',
    );
    process.exit(1);
  }

  const ref = db.doc(ROLES_DOC_PATH);

  if (replace) {
    await ref.set(
      { analystUids, coachSignupCodes, updatedAt: new Date().toISOString() },
      { merge: true },
    );
  } else {
    const existing = (await ref.get()).data() ?? {};
    const mergedUids = [
      ...new Set([...((existing.analystUids ?? []) as string[]), ...analystUids]),
    ];
    const mergedCodes = [
      ...new Set([
        ...((existing.coachSignupCodes ?? []) as string[]),
        ...coachSignupCodes,
      ]),
    ];
    await ref.set(
      {
        analystUids: mergedUids,
        coachSignupCodes: mergedCodes,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
  }

  // Counts only. The signup codes are secrets and never belong in a terminal
  // scrollback or a CI log.
  const after = (await ref.get()).data() ?? {};
  console.log(
    `Seeded ${ROLES_DOC_PATH} (${replace ? 'replace' : 'merge'}): `
      + `${((after.analystUids ?? []) as string[]).length} analyst UID(s), `
      + `${((after.coachSignupCodes ?? []) as string[]).length} signup code(s).`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
