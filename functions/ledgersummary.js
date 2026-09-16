// functions/ledgersummary.js
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { resolveAccountMeta, DEFAULT_TYPES } = require("./ledger");

function toNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value.trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function summaryDocId(entry) {
  const companyId = String(entry?.companyId || entry?.companyid || 'global').trim();
  const branchId = String(entry?.branchId || entry?.branchid || 'all').trim();
  const account = String(entry?.account || 'unknown').trim().toLowerCase().replace(/[^a-z0-9]+/g, '_');
  return `${companyId}_${branchId}_${account}`;
}

async function applyLedgerSummaryDelta(entry, direction = 1) {
  if (!entry || !entry.companyId || !entry.branchId || !entry.account) return null;

  const db = admin.firestore();
  const summaryRef = db.collection('accounts_summary').doc(summaryDocId(entry));
  const meta = resolveAccountMeta(entry.account, entry.type === 'debit' ? DEFAULT_TYPES.EXPENSE : DEFAULT_TYPES.ASSET);
  const amount = toNumber(entry.amount || 0) * direction;
  const isDebit = String(entry.type || '').toLowerCase() === 'debit';
  const isCredit = String(entry.type || '').toLowerCase() === 'credit';

  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(summaryRef);
    const current = existing.exists ? existing.data() || {} : {};

    const next = {
      companyId: entry.companyId || current.companyId || null,
      branchId: entry.branchId || current.branchId || null,
      account: String(entry.account || current.account || 'unknown').trim(),
      accountClass: meta?.classCode || current.accountClass || null,
      accountSubClass: meta?.subCode || current.accountSubClass || null,
      accountType: meta?.type || current.accountType || null,
      debit: toNumber(current.debit || 0) + (isDebit ? amount : 0),
      credit: toNumber(current.credit || 0) + (isCredit ? amount : 0),
      balance: toNumber(current.balance || 0) + (isDebit ? amount : isCredit ? -amount : 0),
      transactionCount: toNumber(current.transactionCount || 0) + (direction > 0 ? 1 : 0),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(summaryRef, next, { merge: true });
  });

  return summaryRef;
}

exports.applyLedgerSummaryDelta = applyLedgerSummaryDelta;

exports.reconcileAccountsSummary = async (change) => {
  const before = change?.before?.exists ? change.before.data() : null;
  const after = change?.after?.exists ? change.after.data() : null;

  try {
    if (before && after) {
      await applyLedgerSummaryDelta(before, -1);
      await applyLedgerSummaryDelta(after, 1);
    } else if (after) {
      await applyLedgerSummaryDelta(after, 1);
    } else if (before) {
      await applyLedgerSummaryDelta(before, -1);
    }

    return null;
  } catch (error) {
    logger.error('Error reconciling accounts_summary for ledger update:', error);
    throw error;
  }
};

/**
 * Firestore trigger to summarize ledgers by date, branch, company, year, and month.
 * Writes to ledgersummary/{companyId}_{branchId}_{date}
 *
 * Each summary doc contains:
 *   - companyId, branchId, date, year, month
 *   - accountTotals: { [account]: { debit: number, credit: number } }
 *   - lastUpdated
 */
exports.summarizeLedger = async (change, context) => {
  const after = change.after ? change.after.data() : null;
  const before = change.before ? change.before.data() : null;
  const docId = change.after ? change.after.id : change.before.id;

  // Only process creates/updates
  if (!after) return null;

  const {
    companyId,
    branchId,
    date,
    year,
    month,
    account,
    type,
    amount = 0,
  } = after;

  if (!companyId || !branchId || !date || !account || !type) return null;

  const summaryId = `${companyId}_${branchId}_${date}`;
  const summaryRef = admin.firestore().collection("ledgersummary").doc(summaryId);

  await admin.firestore().runTransaction(async (transaction) => {
    const summaryDoc = await transaction.get(summaryRef);
    let data = summaryDoc.exists ? summaryDoc.data() : {
      companyId,
      branchId,
      date,
      year,
      month,
      accountTotals: {},
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!data.accountTotals[account]) {
      data.accountTotals[account] = { debit: 0, credit: 0 };
    }
    if (type === "debit") {
      data.accountTotals[account].debit += amount;
    } else if (type === "credit") {
      data.accountTotals[account].credit += amount;
    }
    data.lastUpdated = admin.firestore.FieldValue.serverTimestamp();

    transaction.set(summaryRef, data, { merge: true });
  });

  logger.info(`Ledger summary updated for ${summaryId}`);
  return null;
};


// Callable function to batch summarize ledgers for a given date, branch, and company
// Usage: call this from a script or HTTP endpoint for repair or on-demand summary
exports.summarizeAllLedgers = async (req, res) => {
  // Query params: companyId, branchId, date (Y-m-d)
  const { companyId, branchId, date } = req.query;
  if (!companyId || !branchId || !date) {
    return res.status(400).json({ error: 'companyId, branchId, and date are required' });
  }
  const ledgersRef = admin.firestore().collection('ledgers');
  const snapshot = await ledgersRef
    .where('companyId', '==', companyId)
    .where('branchId', '==', branchId)
    .where('date', '==', date)
    .get();
  if (snapshot.empty) {
    return res.status(404).json({ error: 'No ledgers found for given criteria' });
  }
  // Aggregate
  const accountTotals = {};
  let year = null, month = null;
  snapshot.forEach(doc => {
    const l = doc.data();
    if (!l.account || !l.type || typeof l.amount !== 'number') return;
    if (!accountTotals[l.account]) accountTotals[l.account] = { debit: 0, credit: 0 };
    if (l.type === 'debit') accountTotals[l.account].debit += l.amount;
    else if (l.type === 'credit') accountTotals[l.account].credit += l.amount;
    if (!year && l.date) year = l.date.split('-')[0];
    if (!month && l.month) month = l.month;
  });
  const summaryId = `${companyId}_${branchId}_${date}`;
  await admin.firestore().collection('ledgersummary').doc(summaryId).set({
    companyId,
    branchId,
    date,
    year,
    month,
    accountTotals,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return res.json({ success: true, summaryId, accountTotals });
};
