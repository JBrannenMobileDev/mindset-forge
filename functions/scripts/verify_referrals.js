/**
 * Regression checks for the referral commission ledger.
 *
 * Runs against the compiled output with a fake Firestore, so it needs no test
 * framework and no emulator: `npm run verify:referrals` builds and runs it.
 * Worth keeping green because this is the only code path that decides how much
 * real money a partner is owed.
 */

const { recordReferralCommission, resolveRateBps, previousMonthKey } =
  require('../lib/referrals.js');

let pass = 0, fail = 0;
function check(name, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (ok) { pass++; console.log(`  PASS  ${name}`); }
  else { fail++; console.log(`  FAIL  ${name}\n        expected ${JSON.stringify(expected)}\n        actual   ${JSON.stringify(actual)}`); }
}

// ── Fake Firestore ────────────────────────────────────────────────────────
function makeDb({ partner, existingIds = new Set() }) {
  const written = [];
  return {
    written,
    collection(name) {
      return {
        doc(id) {
          return {
            async get() {
              if (name === 'referral_partners') {
                return { exists: !!partner, data: () => partner };
              }
              return { exists: false, data: () => undefined };
            },
            async create(row) {
              if (existingIds.has(id)) {
                const e = new Error('ALREADY_EXISTS'); e.code = 6; throw e;
              }
              existingIds.add(id);
              written.push({ id, row });
            },
          };
        },
      };
    },
  };
}

const PARTNER = {
  name: 'Test Partner',
  active: true,
  rateHistory: [{ rateBps: 2500, effectiveFrom: '2026-01-01' }],
};

const baseEvent = {
  id: 'evt_1',
  type: 'INITIAL_PURCHASE',
  app_user_id: 'user_1',
  environment: 'PRODUCTION',
  period_type: 'NORMAL',
  price: 12.99,
  commission_percentage: 0.15,
  tax_percentage: 0,
  purchased_at_ms: Date.parse('2026-03-15T00:00:00Z'),
};
const PROFILE = { referralSource: 'partner_test', referredAt: '2026-02-01T00:00:00Z' };

(async () => {
  console.log('\nRate resolution');
  check('picks rate effective at referredAt', resolveRateBps({
    rateHistory: [
      { rateBps: 2500, effectiveFrom: '2026-01-01' },
      { rateBps: 2000, effectiveFrom: '2026-06-01' },
    ],
  }, '2026-03-01'), 2500);
  check('later cohort gets the newer rate', resolveRateBps({
    rateHistory: [
      { rateBps: 2500, effectiveFrom: '2026-01-01' },
      { rateBps: 2000, effectiveFrom: '2026-06-01' },
    ],
  }, '2026-07-01'), 2000);
  check('referral predating all rates uses earliest', resolveRateBps({
    rateHistory: [{ rateBps: 2500, effectiveFrom: '2026-05-01' }],
  }, '2026-01-01'), 2500);
  check('no history yields null', resolveRateBps({ rateHistory: [] }, '2026-01-01'), null);

  console.log('\nCommission math (25% of net, 15% store cut)');
  let db = makeDb({ partner: PARTNER });
  let r = await recordReferralCommission(db, baseEvent, PROFILE);
  check('monthly $12.99 pays $2.76', r.commissionUsdCents, 276);
  check('net recorded as $11.04', db.written[0].row.netUsdCents, 1104);
  check('month bucket derived', db.written[0].row.month, '2026-03');
  check('not flagged estimated', db.written[0].row.estimated, false);

  db = makeDb({ partner: PARTNER });
  r = await recordReferralCommission(db,
    { ...baseEvent, id: 'evt_2', price: 99.99 }, PROFILE);
  check('annual $99.99 pays $21.25', r.commissionUsdCents, 2125);

  console.log('\nEstimated inputs');
  db = makeDb({ partner: PARTNER });
  r = await recordReferralCommission(db,
    { ...baseEvent, id: 'evt_3', commission_percentage: null, tax_percentage: null },
    PROFILE);
  check('null percentages fall back to 15%', r.commissionUsdCents, 276);
  check('row flagged estimated', db.written[0].row.estimated, true);

  console.log('\nRefund clawback');
  db = makeDb({ partner: PARTNER });
  r = await recordReferralCommission(db, {
    ...baseEvent, id: 'evt_4', type: 'CANCELLATION',
    cancel_reason: 'CUSTOMER_SUPPORT', price: -12.99,
  }, PROFILE);
  check('refund produces negative commission', r.commissionUsdCents, -276);
  check('refund flagged', db.written[0].row.isRefund, true);

  db = makeDb({ partner: PARTNER });
  r = await recordReferralCommission(db, {
    ...baseEvent, id: 'evt_5', type: 'CANCELLATION',
    cancel_reason: 'UNSUBSCRIBE', price: 12.99,
  }, PROFILE);
  check('plain unsubscribe is not a refund', r.recorded, false);

  console.log('\nSkips');
  const skips = [
    ['trial', { ...baseEvent, id: 'a', period_type: 'TRIAL' }, PROFILE],
    ['sandbox', { ...baseEvent, id: 'b', environment: 'SANDBOX' }, PROFILE],
    ['no referral source', { ...baseEvent, id: 'c' }, {}],
    ['zero price', { ...baseEvent, id: 'd', price: 0 }, PROFILE],
    ['product change', { ...baseEvent, id: 'e', type: 'PRODUCT_CHANGE' }, PROFILE],
    ['missing event id', { ...baseEvent, id: undefined }, PROFILE],
  ];
  for (const [label, ev, prof] of skips) {
    const d = makeDb({ partner: PARTNER });
    const res = await recordReferralCommission(d, ev, prof);
    check(`skips ${label}`, [res.recorded, d.written.length], [false, 0]);
  }

  const d2 = makeDb({ partner: { ...PARTNER, active: false } });
  check('skips inactive partner',
    (await recordReferralCommission(d2, { ...baseEvent, id: 'f' }, PROFILE)).recorded, false);

  const d3 = makeDb({ partner: null });
  check('skips unknown partner',
    (await recordReferralCommission(d3, { ...baseEvent, id: 'g' }, PROFILE)).recorded, false);

  console.log('\nIdempotency');
  const shared = makeDb({ partner: PARTNER });
  const first = await recordReferralCommission(shared, baseEvent, PROFILE);
  const second = await recordReferralCommission(shared, baseEvent, PROFILE);
  check('first delivery records', first.recorded, true);
  check('retry does not double-pay', second.recorded, false);
  check('only one row written', shared.written.length, 1);

  console.log('\nMonth key');
  check('previous month across year boundary',
    previousMonthKey(new Date('2026-01-14T00:00:00Z')), '2025-12');
  check('previous month mid-year',
    previousMonthKey(new Date('2026-08-03T00:00:00Z')), '2026-07');

  console.log(`\n${pass} passed, ${fail} failed\n`);
  process.exit(fail === 0 ? 0 : 1);
})();
