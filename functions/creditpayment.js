const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { registerDefaultChart, DEFAULT_TYPES } = require('./accounts');

const accountRegistry = registerDefaultChart();

function toNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') {
    const parsed = parseFloat(value.trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (value && typeof value === 'object' && typeof value.toNumber === 'function') {
    try {
      const n = value.toNumber();
      return typeof n === 'number' && Number.isFinite(n) ? n : 0;
    } catch (_) {
      return 0;
    }
  }
  return 0;
}

function cleanObject(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(cleanObject);
  const out = {};
  Object.keys(obj).forEach((k) => {
    const v = obj[k];
    if (v === undefined) return;
    const cv = cleanObject(v);
    if (cv === undefined) return;
    out[k] = cv;
  });
  return out;
}

const ACCOUNT_NAME_TO_META = {
  accounts_receivable: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  accounts_payable: { classCode: 'L', subCode: 'Current Liability', type: DEFAULT_TYPES.LIABILITY },
  creditors: { classCode: 'L', subCode: 'Current Liability', type: DEFAULT_TYPES.LIABILITY },
  cash: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  momo: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  mobile_money: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  card: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  cheque: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  bank_transfer: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
};

function resolveAccountMeta(accountName, fallbackType = DEFAULT_TYPES.ASSET) {
  if (!accountName && accountName !== '') return null;
  const name = String(accountName).trim();
  const key = name.toLowerCase().replace(/\s+/g, '_');
  if (ACCOUNT_NAME_TO_META[key]) return ACCOUNT_NAME_TO_META[key];
  const sub = accountRegistry.findSubByName ? accountRegistry.findSubByName(name) : null;
  if (sub && sub.parent) {
    return { classCode: sub.parent.code || sub.parent, subCode: sub.code, type: sub.parent.type || fallbackType };
  }
  const cls = accountRegistry.findClassByName ? accountRegistry.findClassByName(name) : null;
  if (cls) return { classCode: cls.code, subCode: null, type: cls.type || fallbackType };
  const fallbackClass =
    fallbackType === DEFAULT_TYPES.ASSET ? 'A' :
    fallbackType === DEFAULT_TYPES.LIABILITY ? 'L' :
    fallbackType === DEFAULT_TYPES.EQUITY ? 'E' :
    fallbackType === DEFAULT_TYPES.INCOME ? 'I' :
    'X';
  return { classCode: fallbackClass, subCode: name || null, type: fallbackType };
}

function normalizePaymentMethod(method) {
  const raw = (method || '').toString().trim().toLowerCase();
  if (raw === 'momo' || raw === 'mobile money' || raw === 'mobile_money' || raw === 'mobilemoney') return 'momo';
  if (raw === 'card' || raw === 'visa' || raw === 'mastercard' || raw === 'pos') return 'card';
  if (raw === 'cheque' || raw === 'check' || raw === 'cheque payment') return 'cheque';
  if (raw === 'bank transfer' || raw === 'bank_transfer' || raw === 'banktransfer' || raw === 'bank' || raw === 'transfer') return 'bank_transfer';
  if (raw === 'cash') return 'cash';
  return raw.replace(/\s+/g, '_') || 'cash';
}

exports.postCreditPaymentToLedger = async (paymentData = {}, paymentId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = paymentData.companyid || paymentData.companyId || null;
    const companyname = paymentData.companyname || paymentData.companyName || paymentData.companyemail || null;
    const branchId = paymentData.branchid || paymentData.branchId || null;
    const branchName = paymentData.branchname || paymentData.branchName || null;
    const amount = toNumber(paymentData.amount || paymentData.totalAmount || paymentData.amountPaid || 0);
    const paymentMethod = normalizePaymentMethod(paymentData.paymentMode || paymentData.paymentmode || paymentData.paymentMethod || paymentData.paymentmethod || paymentData.mode || paymentData.payment_type || 'cash');
    const paymentAccount = paymentData.account || paymentData.accountName || paymentData.subAccountName || paymentData.subAccountId || paymentMethod || 'cash';
    const creditorId = paymentData.creditorid || paymentData.creditorId || paymentData.creditorID || null;
    const creditorName = paymentData.creditorname || paymentData.creditorName || paymentData.vendorName || paymentData.supplierName || null;
    const reference = paymentData.transactionRef || paymentData.reference || paymentData.ref || paymentData.receiptNo || null;
    const transType = paymentData.activityType || paymentData.activitytype || paymentData.transType || paymentData.transtype || 'credit payment';
    const createdBy = paymentData.staff || paymentData.createdby || paymentData.createdBy || 'system';

    if (amount <= 0) {
      logger.warn(`Credit payment ${paymentId} skipped because amount is zero or invalid`, { paymentId, amount });
      return;
    }

    const ledgerRef = db.collection('ledgers');
    let entryIndex = 0;

    function addEntry(entry) {
      const now = new Date();
      const pad = (n) => n.toString().padStart(2, '0');
      const year = now.getFullYear();
      const monthNum = now.getMonth() + 1;
      const dateNum = now.getDate();
      const weekNum = (() => {
        const d = new Date(Date.UTC(year, now.getMonth(), dateNum));
        const dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
      })();
      const dayName = now.toLocaleString('en-US', { weekday: 'long' });
      const meta = resolveAccountMeta(entry.account, entry.type === 'debit' ? DEFAULT_TYPES.LIABILITY : DEFAULT_TYPES.ASSET);
      const enriched = {
        ...entry,
        accountClass: meta && meta.classCode ? meta.classCode : undefined,
        accountSubClass: meta && meta.subCode ? meta.subCode : undefined,
        accountType: meta && meta.type ? meta.type : undefined,
        date: `${year}-${pad(monthNum)}-${pad(dateNum)}`,
        month: `${year}.${monthNum}`,
        week: `${year}.${weekNum}`,
        day: dayName,
      };
      const cleaned = cleanObject(enriched);
      batch.set(ledgerRef.doc(`${paymentId}_${entryIndex++}`), cleaned);
    }

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: 'accounts_payable',
      type: 'debit',
      amount,
      description: `Credit payment ${paymentId} for ${creditorName || creditorId || 'creditor'} recorded`,
      creditorId,
      creditorName,
      paymentMethod,
      reference,
      transType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy,
    });

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: paymentAccount,
      type: 'credit',
      amount,
      description: `Credit payment ${paymentId} paid via ${paymentMethod}`,
      creditorId,
      creditorName,
      paymentMethod,
      reference,
      transType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy,
    });

    await batch.commit();
    logger.info(`Credit payment ledger entries created for ${paymentId}`);
  } catch (error) {
    logger.error(`Error posting credit payment ${paymentId} to ledger:`, error);
    throw error;
  }
};
