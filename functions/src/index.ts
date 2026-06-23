import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onRequest } from 'firebase-functions/v2/https';
import Anthropic from '@anthropic-ai/sdk';
import { defineSecret } from 'firebase-functions/params';

admin.initializeApp();

const anthropicKey = defineSecret('ANTHROPIC_API_KEY');
const db = admin.firestore();

// ─── Anthropic helper ──────────────────────────────────────────────────────

async function callAnthropicInternal(
  systemPrompt: string,
  userPrompt: string,
  maxTokens = 1000,
  apiKey: string,
): Promise<string> {
  const client = new Anthropic({ apiKey });
  const message = await client.messages.create({
    model: 'claude-sonnet-4-5',
    max_tokens: maxTokens,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  });
  const block = message.content[0];
  if (block.type !== 'text') throw new Error('Unexpected response type from Claude');
  return block.text;
}

// ─── Core AI callable ─────────────────────────────────────────────────────

/**
 * callClaude — auth-gated HTTPS Callable function.
 * All Claude calls from the Flutter app route through here.
 * Input:  { systemPrompt?: string, userPrompt: string, maxTokens?: number }
 * Output: { content: string }
 */
export const callClaude = onCall(
  { secrets: [anthropicKey], enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated to call Claude.');
    }

    const { systemPrompt = '', userPrompt, maxTokens = 1000 } = request.data as {
      systemPrompt?: string;
      userPrompt: string;
      maxTokens?: number;
    };

    if (!userPrompt || typeof userPrompt !== 'string') {
      throw new HttpsError('invalid-argument', 'userPrompt is required.');
    }

    try {
      const content = await callAnthropicInternal(
        systemPrompt,
        userPrompt,
        maxTokens,
        anthropicKey.value(),
      );
      return { content };
    } catch (err) {
      console.error('Claude API error:', err);
      throw new HttpsError('internal', 'Failed to get AI response. Please try again.');
    }
  },
);

// ─── RevenueCat webhook ────────────────────────────────────────────────────

/**
 * revenueCatWebhook — HTTP function that receives RevenueCat webhook events.
 * Syncs subscriptionStatus on the user's Firestore doc.
 * Configure in RevenueCat dashboard: Webhook URL → this function's URL.
 * Set Authorization header to a secret shared with RevenueCat.
 */
export const revenueCatWebhook = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const event = req.body.event as {
    type: string;
    app_user_id: string;
    period_type?: string;
    expiration_at_ms?: number;
  } | undefined;

  if (!event?.app_user_id) {
    res.status(400).send('Missing event data');
    return;
  }

  const uid = event.app_user_id;
  const expirationDate = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  const statusMap: Record<string, string> = {
    INITIAL_PURCHASE: 'active',
    RENEWAL: 'active',
    PRODUCT_CHANGE: 'active',
    CANCELLATION: 'canceled',
    EXPIRATION: 'expired',
    BILLING_ISSUE: 'past_due',
    SUBSCRIBER_ALIAS: 'active',
    TRANSFER: 'active',
  };

  const newStatus = statusMap[event.type] ?? 'free';

  try {
    await db.collection('users').doc(uid).update({
      subscriptionStatus: newStatus,
      ...(expirationDate ? { subscriptionExpiresAt: expirationDate } : {}),
    });
    res.status(200).send('OK');
  } catch (err) {
    console.error('RevenueCat webhook error:', err);
    res.status(500).send('Internal error');
  }
});

// ─── Partner invite functions ──────────────────────────────────────────────

/**
 * sendPartnerInviteEmail — creates an invite doc and sends invite email.
 * Called from Flutter when a user invites a partner by email.
 */
export const sendPartnerInviteEmail = onCall(
  { secrets: [anthropicKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const { partnerEmail, partnerName } = request.data as {
      partnerEmail: string;
      partnerName: string;
    };

    if (!partnerEmail) {
      throw new HttpsError('invalid-argument', 'partnerEmail is required.');
    }

    const inviteId = db.collection('partner_invites').doc().id;
    const inviteData = {
      id: inviteId,
      primaryUserId: request.auth.uid,
      partnerEmail,
      partnerName: partnerName || '',
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('partner_invites').doc(inviteId).set(inviteData);

    // Get primary user's name for the email
    const primarySnap = await db.collection('users').doc(request.auth.uid).get();
    const primaryName = (primarySnap.data() as { displayName?: string })?.displayName ?? 'Your friend';

    // Store invite reference on primary user's profile
    await db.collection('users').doc(request.auth.uid).update({
      pendingPartnerInvites: admin.firestore.FieldValue.arrayUnion(inviteId),
    });

    const deepLink = `mindsetforge://partner-invite/${inviteId}`;
    console.log(`Partner invite created: ${inviteId} for ${partnerEmail} from ${primaryName}`);
    console.log(`Deep link: ${deepLink}`);

    return { inviteId, deepLink };
  },
);

/**
 * acceptPartnerInvite — called from the Flutter partner invite screen.
 * Creates accountability relationship on both user docs.
 */
export const acceptPartnerInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { inviteId } = request.data as { inviteId: string };
  if (!inviteId) {
    throw new HttpsError('invalid-argument', 'inviteId is required.');
  }

  const inviteSnap = await db.collection('partner_invites').doc(inviteId).get();
  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'Invite not found or already used.');
  }

  const invite = inviteSnap.data() as {
    primaryUserId: string;
    partnerEmail: string;
    partnerName: string;
    status: string;
  };

  if (invite.status !== 'pending') {
    throw new HttpsError('already-exists', 'This invite has already been accepted.');
  }

  const partnerUid = request.auth.uid;
  const primaryUid = invite.primaryUserId;

  const relationshipId = db.collection('_').doc().id;
  const now = new Date().toISOString();

  // Add partner to primary user's doc
  await db.collection('users').doc(primaryUid).update({
    accountabilityRelationships: admin.firestore.FieldValue.arrayUnion({
      id: relationshipId,
      type: 'primary',
      partnerUid,
      partnerEmail: invite.partnerEmail,
      partnerName: invite.partnerName,
      status: 'active',
      acceptedAt: now,
    }),
    // Flat array of partner UIDs for Firestore security rules
    partnerUids: admin.firestore.FieldValue.arrayUnion(partnerUid),
  });

  // Get primary user name for partner's record
  const primarySnap = await db.collection('users').doc(primaryUid).get();
  const primaryData = primarySnap.data() as { displayName?: string; email?: string } | undefined;

  // Add primary to partner's doc
  await db.collection('users').doc(partnerUid).update({
    accountabilityRelationships: admin.firestore.FieldValue.arrayUnion({
      id: relationshipId,
      type: 'partner',
      primaryUid,
      primaryEmail: primaryData?.email ?? '',
      primaryName: primaryData?.displayName ?? '',
      status: 'active',
      acceptedAt: now,
    }),
  });

  // Mark invite as accepted
  await db.collection('partner_invites').doc(inviteId).update({ status: 'accepted' });

  return { success: true, primaryUid };
});

/**
 * sendEncouragement — partner sends an encouragement message to the primary user.
 * Writes to the primary user's encouragementMessages array.
 */
export const sendEncouragement = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { primaryUid, message } = request.data as { primaryUid: string; message: string };
  if (!primaryUid || !message) {
    throw new HttpsError('invalid-argument', 'primaryUid and message are required.');
  }

  // Verify the caller is actually a partner of this user
  const partnerSnap = await db.collection('users').doc(request.auth.uid).get();
  const partnerData = partnerSnap.data() as {
    displayName?: string;
    accountabilityRelationships?: Array<{ type: string; primaryUid?: string }>;
  } | undefined;

  const isPartner = (partnerData?.accountabilityRelationships ?? []).some(
    (r) => r.type === 'partner' && r.primaryUid === primaryUid,
  );
  if (!isPartner) {
    throw new HttpsError('permission-denied', 'You are not a partner of this user.');
  }

  const msgId = db.collection('_').doc().id;
  const encouragement = {
    id: msgId,
    fromUid: request.auth.uid,
    fromName: partnerData?.displayName ?? 'Your partner',
    message,
    sentAt: new Date().toISOString(),
    read: false,
  };

  await db.collection('users').doc(primaryUid).update({
    encouragementMessages: admin.firestore.FieldValue.arrayUnion(encouragement),
  });

  return { success: true };
});

// ─── Account management functions ─────────────────────────────────────────

/**
 * deleteUserAccount — deletes all user data and Firebase Auth account.
 * Called from Settings screen.
 */
export const deleteUserAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const uid = request.auth.uid;

  // Delete Firestore documents
  const batch = db.batch();

  // Delete journal entries
  const journals = await db.collection('journals').where('uid', '==', uid).get();
  journals.docs.forEach((doc) => batch.delete(doc.ref));

  // Delete chat sessions
  const chats = await db.collection('chat_sessions').where('uid', '==', uid).get();
  chats.docs.forEach((doc) => batch.delete(doc.ref));

  // Delete partner invites
  const invites = await db.collection('partner_invites').where('primaryUserId', '==', uid).get();
  invites.docs.forEach((doc) => batch.delete(doc.ref));

  // Delete user profile
  batch.delete(db.collection('users').doc(uid));

  await batch.commit();

  // Delete Firebase Auth user
  await admin.auth().deleteUser(uid);

  return { success: true };
});

/**
 * getPartnerInviteInfo — returns metadata for a partner invite link.
 * Called from the PartnerInviteScreen before accepting.
 */
export const getPartnerInviteInfo = onCall(async (request) => {
  const { inviteId } = request.data as { inviteId: string };
  if (!inviteId) {
    throw new HttpsError('invalid-argument', 'inviteId is required.');
  }

  const inviteSnap = await db.collection('partner_invites').doc(inviteId).get();
  if (!inviteSnap.exists) {
    throw new HttpsError('not-found', 'Invite not found.');
  }

  const invite = inviteSnap.data() as {
    primaryUserId: string;
    partnerEmail: string;
    status: string;
  };

  // Get primary user name
  const primarySnap = await db.collection('users').doc(invite.primaryUserId).get();
  const primaryData = primarySnap.data() as { displayName?: string } | undefined;

  return {
    primaryName: primaryData?.displayName ?? 'Someone',
    partnerEmail: invite.partnerEmail,
    status: invite.status,
  };
});

// ─── Scheduled functions ───────────────────────────────────────────────────

/**
 * weeklyMindsetAnalysis — runs every Sunday at 9am UTC.
 * Analyzes each active user's week and updates mindset scores.
 */
export const weeklyMindsetAnalysis = onSchedule(
  { schedule: '0 9 * * 0', secrets: [anthropicKey] },
  async () => {
    const usersSnap = await db
      .collection('users')
      .where('onboardingStep', '>=', 6)
      .limit(100)
      .get();

    const apiKey = anthropicKey.value();

    for (const userDoc of usersSnap.docs) {
      const profile = userDoc.data() as {
        displayName?: string;
        identityStatement?: string;
        limitingBeliefs?: string[];
        mindsetBlueprint?: Record<string, number>;
        dailyCompletions?: Array<{ date: string; completedCount?: number }>;
        goals?: Array<{ title: string; status: string }>;
        currentStreak?: number;
      };

      try {
        const prompt = `Analyze this user's week and provide a mindset coaching insight:
Name: ${profile.displayName ?? 'User'}
Identity: "${profile.identityStatement ?? ''}"
Limiting Beliefs: ${(profile.limitingBeliefs ?? []).join(', ')}
Active Goals: ${(profile.goals ?? []).filter(g => g.status === 'active').map(g => g.title).join(', ')}
Days completed this week: ${(profile.dailyCompletions ?? []).length}

Write a 2-paragraph personalized weekly insight. Highlight their biggest win and their main growth edge for the coming week. Be specific and encouraging.`;

        const insight = await callAnthropicInternal(
          'You are a world-class mindset coach writing weekly insights for your clients. Be personal, specific, and transformational.',
          prompt,
          400,
          apiKey,
        );

        await userDoc.ref.update({
          weeklyInsight: {
            text: insight,
            generatedAt: new Date().toISOString(),
          },
        });

        console.log(`Weekly analysis complete for user: ${userDoc.id}`);
      } catch (err) {
        console.error(`Failed weekly analysis for user ${userDoc.id}:`, err);
      }
    }
  },
);

/**
 * weeklyManifestationReport — runs every Sunday at 10am UTC.
 * Generates a manifestation alignment report for each user.
 */
export const weeklyManifestationReport = onSchedule(
  { schedule: '0 10 * * 0', secrets: [anthropicKey] },
  async () => {
    const usersSnap = await db
      .collection('users')
      .where('onboardingStep', '>=', 6)
      .limit(100)
      .get();

    const apiKey = anthropicKey.value();

    for (const userDoc of usersSnap.docs) {
      const profile = userDoc.data() as {
        displayName?: string;
        manifestationAlignment?: {
          subconscious: number;
          thought: number;
          action: number;
          results: number;
        };
        goals?: Array<{ title: string; status: string }>;
        evidenceLog?: Array<{ content: string }>;
      };

      try {
        const alignment = profile.manifestationAlignment;
        const recentEvidence = (profile.evidenceLog ?? []).slice(-5).map(e => e.content).join('; ');

        const prompt = `Generate a weekly manifestation alignment report:
Name: ${profile.displayName ?? 'User'}
Alignment Scores - Subconscious: ${alignment?.subconscious ?? 50}%, Thought: ${alignment?.thought ?? 50}%, Action: ${alignment?.action ?? 50}%, Results: ${alignment?.results ?? 50}%
Active Goals: ${(profile.goals ?? []).filter(g => g.status === 'active').map(g => g.title).join(', ')}
Recent Evidence of Growth: ${recentEvidence || 'None logged'}

Write a 2-paragraph report on their manifestation alignment. Identify the weakest layer and give one specific practice to strengthen it this week.`;

        const report = await callAnthropicInternal(
          'You are a manifestation coach writing weekly alignment reports. Be insightful, specific, and practical.',
          prompt,
          400,
          apiKey,
        );

        await userDoc.ref.update({
          weeklyManifestationReport: {
            text: report,
            generatedAt: new Date().toISOString(),
          },
        });
      } catch (err) {
        console.error(`Failed manifestation report for user ${userDoc.id}:`, err);
      }
    }
  },
);

/**
 * lowActivityAlert — runs daily at 10am UTC.
 * Finds users inactive for 3+ days and generates a personalized re-engagement message.
 */
export const lowActivityAlert = onSchedule(
  { schedule: '0 10 * * *', secrets: [anthropicKey] },
  async () => {
    const threeDaysAgo = new Date();
    threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
    const cutoff = threeDaysAgo.toISOString();

    const usersSnap = await db
      .collection('users')
      .where('onboardingStep', '>=', 6)
      .where('lastActiveAt', '<', cutoff)
      .limit(50)
      .get();

    const apiKey = anthropicKey.value();

    for (const userDoc of usersSnap.docs) {
      const profile = userDoc.data() as {
        displayName?: string;
        identityStatement?: string;
        goals?: Array<{ title: string; status: string }>;
        fcmToken?: string;
      };

      try {
        const prompt = `Write a short, warm re-engagement message (2-3 sentences) for ${profile.displayName ?? 'a user'} who hasn't checked in for 3+ days. 
Their identity: "${profile.identityStatement ?? 'becoming their best self'}"
Their goals: ${(profile.goals ?? []).filter(g => g.status === 'active').map(g => g.title).slice(0, 2).join(', ')}
Make it personal, not generic. No guilt-tripping. Just a warm reminder of who they're becoming.`;

        const alertMessage = await callAnthropicInternal(
          'You write brief, warm re-engagement messages for a mindset coaching app. Never guilt-trip. Always inspire.',
          prompt,
          150,
          apiKey,
        );

        // Send FCM push if token is available
        if (profile.fcmToken) {
          await admin.messaging().send({
            token: profile.fcmToken,
            notification: {
              title: 'Your mindset journey misses you ✨',
              body: alertMessage,
            },
            data: { type: 'low_activity_alert' },
          });
        }

        console.log(`Low activity alert sent to: ${userDoc.id}`);
      } catch (err) {
        console.error(`Failed low activity alert for user ${userDoc.id}:`, err);
      }
    }
  },
);
