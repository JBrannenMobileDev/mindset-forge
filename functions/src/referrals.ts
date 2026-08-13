import * as admin from 'firebase-admin';

/**
 * Referral commission ledger.
 *
 * One row per revenue event, written from the RevenueCat webhook, plus a
 * monthly aggregation into draft payout statements.
 *
 * These figures are an ACCRUAL ESTIMATE, not a settled payable. RevenueCat
 * documents `commission_percentage` and `tax_percentage` as estimates, and both
 * can arrive null. Every row therefore records which inputs were estimated, and
 * statements are generated as drafts carrying an adjustment field so the actual
 * Apple/Google proceeds can be reconciled before anyone is paid.
 */

export const REFERRAL_COMMISSIONS = 'referral_commissions';
export const REFERRAL_PARTNERS = 'referral_partners';
export const REFERRAL_PAYOUTS = 'referral_payouts';

/**
 * Store commission assumed when RevenueCat omits `commission_percentage`.
 * 15% matches Apple's Small Business Program and Google Play's rate on the
 * first $1M of annual earnings. Rows relying on this are flagged `estimated`.
 */
const DEFAULT_COMMISSION_PCT = 0.15;

/** Events that represent money coming in. */
const EARNING_EVENT_TYPES = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'NON_RENEWING_PURCHASE',
  // A previously refunded transaction was reinstated, so the clawback reverses.
  'REFUND_REVERSED',
]);

/**
 * A CANCELLATION carrying this reason is a refund rather than a user turning
 * off auto-renew. Only refunds move money, so only they produce a clawback.
 */
const REFUND_CANCEL_REASON = 'CUSTOMER_SUPPORT';

/**
 * PRODUCT_CHANGE is deliberately excluded: the resulting charge arrives
 * separately as a RENEWAL, so counting both would pay commission twice on one
 * payment.
 */

export type RevenueCatEvent = {
  id?: string;
  type?: string;
  app_user_id?: string;
  period_type?: string;
  environment?: string;
  price?: number | null;
  currency?: string | null;
  tax_percentage?: number | null;
  commission_percentage?: number | null;
  product_id?: string;
  store?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  cancel_reason?: string;
  event_timestamp_ms?: number;
  purchased_at_ms?: number;
};

type PartnerRate = { rateBps?: number; effectiveFrom?: string };

type PartnerConfig = {
  name?: string;
  active?: boolean;
  rateHistory?: PartnerRate[];
};

function toCents(amountUsd: number): number {
  return Math.round(amountUsd * 100);
}

/**
 * Picks the rate that was in effect when the subscriber was referred, which is
 * what makes rate changes forward-only as the partner agreement promises.
 *
 * Falls back to the earliest configured rate when the user predates any entry,
 * so an early referral is still paid rather than silently earning nothing.
 */
export function resolveRateBps(
  config: PartnerConfig,
  referredAt: string | undefined,
): number | null {
  const history = (config.rateHistory ?? [])
    .filter((r): r is { rateBps: number; effectiveFrom: string } =>
      typeof r.rateBps === 'number' && typeof r.effectiveFrom === 'string')
    .sort((a, b) => a.effectiveFrom.localeCompare(b.effectiveFrom));

  if (history.length === 0) return null;
  if (!referredAt) return history[0].rateBps;

  let resolved = history[0].rateBps;
  for (const entry of history) {
    if (entry.effectiveFrom <= referredAt) resolved = entry.rateBps;
    else break;
  }
  return resolved;
}

/**
 * Signed gross amount in USD. Refunds are stored negative so a month's rows sum
 * directly to the payable without special-casing at read time.
 */
function signedGrossUsd(event: RevenueCatEvent, isRefund: boolean): number {
  const raw = typeof event.price === 'number' ? event.price : 0;
  const magnitude = Math.abs(raw);
  return isRefund ? -magnitude : magnitude;
}

export type CommissionOutcome =
  | { recorded: false; reason: string }
  | { recorded: true; commissionUsdCents: number; partnerId: string };

/**
 * Records a commission row for a revenue event, if one is owed.
 *
 * Idempotent by construction: the document id is the RevenueCat event id, which
 * RevenueCat reuses across retries, and the write uses create() so a redelivery
 * cannot double-pay.
 */
export async function recordReferralCommission(
  db: admin.firestore.Firestore,
  event: RevenueCatEvent,
  profile: { referralSource?: string; referredAt?: string } | undefined,
): Promise<CommissionOutcome> {
  const eventId = event.id;
  if (!eventId) return { recorded: false, reason: 'missing event id' };

  // Sandbox purchases would otherwise fill the ledger with money that does not
  // exist.
  if (event.environment && event.environment !== 'PRODUCTION') {
    return { recorded: false, reason: 'non-production event' };
  }

  const type = event.type ?? '';
  const isRefund =
    type === 'CANCELLATION' && event.cancel_reason === REFUND_CANCEL_REASON;
  if (!isRefund && !EARNING_EVENT_TYPES.has(type)) {
    return { recorded: false, reason: `non-revenue event type ${type}` };
  }

  // No money changes hands during a free trial, so no commission accrues.
  if (event.period_type === 'TRIAL') {
    return { recorded: false, reason: 'trial period' };
  }

  const partnerId = profile?.referralSource;
  if (!partnerId) return { recorded: false, reason: 'no referral source' };

  const grossUsd = signedGrossUsd(event, isRefund);
  if (grossUsd === 0) return { recorded: false, reason: 'zero price' };

  const partnerSnap = await db.collection(REFERRAL_PARTNERS).doc(partnerId).get();
  if (!partnerSnap.exists) {
    return { recorded: false, reason: `no partner config for ${partnerId}` };
  }
  const config = partnerSnap.data() as PartnerConfig;
  if (config.active === false) {
    return { recorded: false, reason: `partner ${partnerId} inactive` };
  }

  const rateBps = resolveRateBps(config, profile?.referredAt);
  if (rateBps === null) {
    return { recorded: false, reason: `no rate configured for ${partnerId}` };
  }

  const commissionPctRaw = event.commission_percentage;
  const taxPctRaw = event.tax_percentage;
  const commissionPct =
    typeof commissionPctRaw === 'number' ? commissionPctRaw : DEFAULT_COMMISSION_PCT;
  const taxPct = typeof taxPctRaw === 'number' ? taxPctRaw : 0;
  const estimated =
    typeof commissionPctRaw !== 'number' || typeof taxPctRaw !== 'number';

  // Guard against a malformed payload producing a negative or inflated base.
  const retainedPct = Math.min(Math.max(1 - commissionPct - taxPct, 0), 1);
  const netUsd = grossUsd * retainedPct;
  const commissionUsdCents = Math.round(toCents(netUsd) * (rateBps / 10000));

  const occurredAtMs = event.purchased_at_ms ?? event.event_timestamp_ms ?? Date.now();

  const row = {
    eventId,
    eventType: type,
    partnerId,
    uid: event.app_user_id ?? '',
    isRefund,
    grossUsdCents: toCents(grossUsd),
    netUsdCents: toCents(netUsd),
    commissionUsdCents,
    commissionRateBps: rateBps,
    storeCommissionPct: commissionPct,
    taxPct,
    // True when RevenueCat omitted a percentage and a default was assumed.
    // Statements surface this so reconciliation can prioritise these rows.
    estimated,
    productId: event.product_id ?? null,
    store: event.store ?? null,
    periodType: event.period_type ?? null,
    currency: event.currency ?? 'USD',
    transactionId: event.transaction_id ?? null,
    originalTransactionId: event.original_transaction_id ?? null,
    occurredAt: new Date(occurredAtMs).toISOString(),
    month: new Date(occurredAtMs).toISOString().slice(0, 7),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    await db.collection(REFERRAL_COMMISSIONS).doc(eventId).create(row);
    return { recorded: true, commissionUsdCents, partnerId };
  } catch (err) {
    // ALREADY_EXISTS means this is a RevenueCat retry of an event we already
    // ledgered, which is exactly what create() is here to make safe.
    if ((err as { code?: number }).code === 6) {
      return { recorded: false, reason: 'duplicate event (already ledgered)' };
    }
    throw err;
  }
}

export type StatementTotals = {
  partnerId: string;
  month: string;
  grossUsdCents: number;
  netUsdCents: number;
  commissionUsdCents: number;
  eventCount: number;
  refundCount: number;
  estimatedRowCount: number;
  subscriberCount: number;
};

/**
 * Rolls every ledger row for `month` (YYYY-MM) into one draft statement per
 * partner.
 *
 * Existing statements are only overwritten while they are still `draft`, so
 * regenerating can never silently rewrite a figure that has already been
 * reviewed or paid.
 */
export async function buildMonthlyStatements(
  db: admin.firestore.Firestore,
  month: string,
): Promise<StatementTotals[]> {
  const snap = await db
    .collection(REFERRAL_COMMISSIONS)
    .where('month', '==', month)
    .get();

  const byPartner = new Map<string, StatementTotals & { uids: Set<string> }>();

  for (const doc of snap.docs) {
    const row = doc.data() as {
      partnerId?: string;
      uid?: string;
      isRefund?: boolean;
      estimated?: boolean;
      grossUsdCents?: number;
      netUsdCents?: number;
      commissionUsdCents?: number;
    };
    const partnerId = row.partnerId;
    if (!partnerId) continue;

    let totals = byPartner.get(partnerId);
    if (!totals) {
      totals = {
        partnerId,
        month,
        grossUsdCents: 0,
        netUsdCents: 0,
        commissionUsdCents: 0,
        eventCount: 0,
        refundCount: 0,
        estimatedRowCount: 0,
        subscriberCount: 0,
        uids: new Set<string>(),
      };
      byPartner.set(partnerId, totals);
    }

    totals.grossUsdCents += row.grossUsdCents ?? 0;
    totals.netUsdCents += row.netUsdCents ?? 0;
    totals.commissionUsdCents += row.commissionUsdCents ?? 0;
    totals.eventCount += 1;
    if (row.isRefund) totals.refundCount += 1;
    if (row.estimated) totals.estimatedRowCount += 1;
    if (row.uid) totals.uids.add(row.uid);
  }

  const results: StatementTotals[] = [];

  for (const [partnerId, totals] of byPartner) {
    const { uids, ...rest } = totals;
    const statement: StatementTotals = { ...rest, subscriberCount: uids.size };
    const ref = db.collection(REFERRAL_PAYOUTS).doc(`${partnerId}_${month}`);

    const existing = await ref.get();
    if (existing.exists && (existing.data()?.status ?? 'draft') !== 'draft') {
      // Reviewed or already paid: leave it alone.
      results.push(statement);
      continue;
    }

    await ref.set(
      {
        ...statement,
        status: 'draft',
        // Manual reconciliation against actual store proceeds lands here rather
        // than editing the computed figure, so the arithmetic stays auditable.
        adjustmentUsdCents: existing.data()?.adjustmentUsdCents ?? 0,
        adjustmentNote: existing.data()?.adjustmentNote ?? null,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    results.push(statement);
  }

  return results;
}

/** Returns the previous calendar month as `YYYY-MM`, in UTC. */
export function previousMonthKey(now: Date = new Date()): string {
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  d.setUTCMonth(d.getUTCMonth() - 1);
  return d.toISOString().slice(0, 7);
}
