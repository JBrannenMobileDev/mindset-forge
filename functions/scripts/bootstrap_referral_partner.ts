/**
 * One-shot bootstrap for a referral partner.
 *
 * Referral attribution depends on the same identifier appearing in three
 * places, and a mismatch fails silently rather than erroring: commissions
 * simply never accrue. This script derives all of them from one definition so
 * they cannot drift:
 *
 *   1. `referral_partners/{id}`            commission rate config
 *   2. `app_config/attribution_sources`    the in-app "How did you hear" list
 *   3. the `campaign` token in the web repo's lib/site.ts PARTNERS
 *
 * It can only enforce the first two. It prints the exact value the third must
 * hold so you can eyeball it.
 *
 * Usage:
 *   npx ts-node scripts/bootstrap_referral_partner.ts \
 *     --id=partner_wes --label="Wes Lowery" [--rate=2500] \
 *     [--effective=2026-08-12] [--position=2] [--dry-run]
 *
 * Safe to re-run. Rate changes append to the history rather than overwriting,
 * so existing subscribers keep the rate they were referred under.
 */
import * as admin from 'firebase-admin';

admin.initializeApp({ projectId: 'mindsetforge-ai' });
const db = admin.firestore();

/** Generic channels seeded when the attribution config does not yet exist.
 *  Labels must match AppStrings in the Flutter app so the fallback list and
 *  the remote list read identically. */
const DEFAULT_SOURCES = [
  { id: 'instagram', label: 'Instagram' },
  { id: 'tiktok', label: 'TikTok' },
  { id: 'youtube', label: 'YouTube' },
  { id: 'podcast', label: 'A podcast' },
  { id: 'friend', label: 'A friend or family member' },
  { id: 'search', label: 'App Store search' },
  { id: 'other', label: 'Somewhere else' },
];

type Source = { id: string; label: string };
type Rate = { rateBps: number; effectiveFrom: string };

function flag(args: string[], name: string): string | undefined {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3).trim() : undefined;
}

function has(args: string[], name: string): boolean {
  return args.includes(`--${name}`);
}

async function main() {
  const args = process.argv.slice(2);
  const id = flag(args, 'id');
  const label = flag(args, 'label');
  const rateBps = Number(flag(args, 'rate') ?? 2500);
  const effectiveFrom = flag(args, 'effective') ?? new Date().toISOString().slice(0, 10);
  const position = Number(flag(args, 'position') ?? 2);
  const dryRun = has(args, 'dry-run');

  if (!id || !label) {
    console.error('Required: --id=partner_slug and --label="Display Name"');
    process.exit(1);
  }
  // The id travels through a Play Store referrer query string and an Apple
  // campaign token, so keep it to characters that survive both untouched.
  if (!/^[a-z0-9_]+$/.test(id)) {
    console.error(`Invalid --id "${id}": use lowercase letters, digits and underscores only.`);
    process.exit(1);
  }
  if (!id.startsWith('partner_')) {
    console.error(`Invalid --id "${id}": partner ids must start with "partner_".`);
    process.exit(1);
  }
  if (!Number.isInteger(rateBps) || rateBps <= 0 || rateBps > 10000) {
    console.error(`Invalid --rate "${rateBps}": basis points, 1 to 10000 (2500 = 25%).`);
    process.exit(1);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom)) {
    console.error(`Invalid --effective "${effectiveFrom}": expected YYYY-MM-DD.`);
    process.exit(1);
  }

  console.log(
    `${dryRun ? '[dry run] ' : ''}Partner ${id} (${label}) at ` +
      `${(rateBps / 100).toFixed(2)}% effective ${effectiveFrom}\n`,
  );

  // ── 1. Commission rate config ───────────────────────────────────────────
  const partnerRef = db.collection('referral_partners').doc(id);
  const partnerSnap = await partnerRef.get();
  const existingHistory = ((partnerSnap.data()?.rateHistory ?? []) as Rate[])
    .filter((r) => typeof r.rateBps === 'number' && typeof r.effectiveFrom === 'string')
    .sort((a, b) => a.effectiveFrom.localeCompare(b.effectiveFrom));

  const latest = existingHistory[existingHistory.length - 1];
  let rateHistory = existingHistory;

  if (!latest) {
    rateHistory = [{ rateBps, effectiveFrom }];
    console.log(`  referral_partners/${id}: seeding rate history`);
  } else if (latest.rateBps === rateBps) {
    console.log(`  referral_partners/${id}: rate unchanged, history untouched`);
  } else if (effectiveFrom <= latest.effectiveFrom) {
    // Backdating would retroactively reprice subscribers already referred,
    // which clause 2.4 of the partner agreement forbids.
    console.error(
      `  refusing to backdate: --effective ${effectiveFrom} is not after the ` +
        `current entry (${latest.effectiveFrom} @ ${latest.rateBps}bps).`,
    );
    process.exit(1);
  } else {
    rateHistory = [...existingHistory, { rateBps, effectiveFrom }];
    console.log(
      `  referral_partners/${id}: appending ${rateBps}bps from ${effectiveFrom} ` +
        `(existing referrals stay at ${latest.rateBps}bps)`,
    );
  }

  // ── 2. In-app attribution options ───────────────────────────────────────
  const sourcesRef = db.doc('app_config/attribution_sources');
  const sourcesSnap = await sourcesRef.get();
  const current = (sourcesSnap.data()?.sources ?? []) as Source[];
  let sources: Source[] = current.length > 0 ? [...current] : [...DEFAULT_SOURCES];
  if (current.length === 0) console.log('  app_config/attribution_sources: seeding defaults');

  const existingIndex = sources.findIndex((s) => s.id === id);
  if (existingIndex >= 0) {
    sources[existingIndex] = { id, label };
    console.log(`  app_config/attribution_sources: updated label for ${id}`);
  } else {
    const at = Math.max(0, Math.min(position, sources.length));
    sources.splice(at, 0, { id, label });
    console.log(`  app_config/attribution_sources: inserted ${id} at position ${at}`);
  }
  // Keep the catch-all last no matter where anything else landed.
  const other = sources.filter((s) => s.id === 'other');
  sources = [...sources.filter((s) => s.id !== 'other'), ...other];

  if (dryRun) {
    console.log('\n[dry run] would write:');
    console.log(JSON.stringify({ rateHistory, sources }, null, 2));
    return;
  }

  await partnerRef.set(
    { name: label, active: true, rateHistory, updatedAt: new Date().toISOString() },
    { merge: true },
  );
  await sourcesRef.set(
    { sources, updatedAt: new Date().toISOString() },
    { merge: true },
  );

  console.log('\nDone. Attribution list is now:');
  sources.forEach((s, i) => console.log(`  ${i}. ${s.label}  (${s.id})`));
  console.log(
    `\nConfirm the web repo matches. In ~/mindsetforge-web/lib/site.ts, PARTNERS ` +
      `must contain an entry whose campaign is exactly "${id}".`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
