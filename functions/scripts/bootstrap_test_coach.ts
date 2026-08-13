/**
 * One-shot bootstrap for a test coach account.
 *
 * Usage:
 *   npx ts-node scripts/bootstrap_test_coach.ts \
 *     --uid=UID --email=EMAIL --code=SIGNUP_CODE \
 *     [--name="Example Coach"] [--team="Test Team"] [--sport=Football]
 */
import * as admin from 'firebase-admin';
import { randomBytes } from 'crypto';

admin.initializeApp({ projectId: 'mindsetforge-ai' });
const db = admin.firestore();

function flag(args: string[], name: string): string | undefined {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3).trim() : undefined;
}

async function main() {
  const args = process.argv.slice(2);
  const uid = flag(args, 'uid');
  const email = flag(args, 'email');
  const code = flag(args, 'code') || randomBytes(15).toString('base64url').slice(0, 20);
  const coachName = flag(args, 'name') || 'Example Coach';
  const teamName = flag(args, 'team') || 'Test Team';
  const sport = flag(args, 'sport') || 'Football';

  if (!uid || !email) {
    console.error('Required: --uid= and --email=');
    process.exit(1);
  }

  const rolesRef = db.doc('app_config/roles');
  const existing = (await rolesRef.get()).data() ?? {};
  const codes = [
    ...new Set(
      [...((existing.coachSignupCodes ?? []) as string[]), code].filter(Boolean),
    ),
  ];
  const analystUids = ((existing.analystUids ?? []) as string[]).filter(Boolean);
  await rolesRef.set(
    {
      coachSignupCodes: codes,
      analystUids,
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );
  console.log(
    `Seeded app_config/roles: ${codes.length} signup code(s), ${analystUids.length} analyst(s)`,
  );
  console.log(`Signup code (save this): ${code}`);

  const existingTeam = await db
    .collection('teams')
    .where('coachUid', '==', uid)
    .limit(1)
    .get();
  if (!existingTeam.empty) {
    const t = existingTeam.docs[0];
    console.log(`Coach already owns team ${t.id} (${t.data().name})`);
    return;
  }

  const teamRef = db.collection('teams').doc();
  const teamId = teamRef.id;
  const now = new Date().toISOString();
  const seasonEndsAt = '2026-12-31T23:59:59.000Z';

  const batch = db.batch();
  batch.set(teamRef, {
    teamId,
    name: teamName,
    sport,
    coachUid: uid,
    memberUids: [],
    seasonEndsAt,
    guidance: { sport, season: '', focusAreas: [], tone: '', notes: '' },
    createdAt: now,
  });
  batch.set(
    db.collection('users').doc(uid),
    {
      uid,
      email,
      displayName: coachName,
      userType: 'coach',
      teamId,
      // Keep in sync with createCoachTeam in src/coach.ts: must equal the
      // Flutter app's total onboarding step count or the coach is treated as
      // mid-onboarding.
      onboardingStep: 8,
      subscriptionStatus: 'free',
      createdAt: now,
    },
    { merge: true },
  );
  await batch.commit();

  console.log(`Bootstrapped coach ${uid}`);
  console.log(`teamId=${teamId} name=${teamName} sport=${sport}`);
  console.log(`seasonEndsAt=${seasonEndsAt}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
