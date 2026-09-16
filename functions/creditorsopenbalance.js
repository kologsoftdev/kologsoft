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
  opening_balance_equity: { classCode: 'E', subCode: 'Opening Balance Equity', type: DEFAULT_TYPES.EQUITY },
  opening_balance: { classCode: 'E', subCode: 'Opening Balance Equity', type: DEFAULT_TYPES.EQUITY },
  creditor_opening_balance: { classCode: 'E', subCode: 'Opening Balance Equity', type: DEFAULT_TYPES.EQUITY },
  cash: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  momo: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
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

function parseDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isFinite(date.getTime()) ? date : null;
}

exports.postCreditorOpeningBalanceToLedger = async (balanceData = {}, balanceId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = balanceData.companyid || balanceData.companyId || null;
    const companyname = balanceData.company || balanceData.companyname || balanceData.companyName || null;
    const branchId = balanceData.branchid || balanceData.branchId || null;
    const branchName = balanceData.branchname || balanceData.branchName || null;
    const creditorId = balanceData.creditorId || balanceData.creditorid || balanceData.creditorID || null;
    const creditorName = balanceData.creditorName || balanceData.creditorname || null;
    const amount = toNumber(balanceData.amount || balanceData.balance || 0);
    const transactionDate = parseDate(balanceData.date || balanceData.datecreated);
    const transType = balanceData.activityType || balanceData.activitytype || 'creditor opening balance';
    const createdBy = balanceData.updatedBy || balanceData.updatedby || balanceData.staff || 'system';
    const description = `Creditor opening balance for ${creditorName || creditorId || 'unknown creditor'}`;

    if (amount <= 0) {
      logger.warn(`Creditor opening balance ${balanceId} has invalid amount; skipping ledger post`, { balanceId, amount });
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
      const meta = resolveAccountMeta(entry.account, entry.type === 'debit' ? DEFAULT_TYPES.EQUITY : DEFAULT_TYPES.LIABILITY);
      const enriched = {
        ...entry,
        accountClass: meta && meta.classCode ? meta.classCode : undefined,
        accountSubClass: meta && meta.subCode ? meta.subCode : undefined,
        accountType: meta && meta.type ? meta.type : undefined,
        ledgerDate: transactionDate ? transactionDate.toISOString() : null,
        date: `${year}-${pad(monthNum)}-${pad(dateNum)}`,
        month: `${year}.${monthNum}`,
        week: `${year}.${weekNum}`,
        day: dayName,
      };
      const cleaned = cleanObject(enriched);
      batch.set(ledgerRef.doc(`${balanceId}_${entryIndex++}`), cleaned);
    }

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      creditorId,
      creditorName,
      account: 'opening_balance_equity',
      type: 'debit',
      amount,
      description,
      transType,
      createdBy,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      creditorId,
      creditorName,
      account: 'accounts_payable',
      type: 'credit',
      amount,
      description: `Offset creditor opening balance for ${creditorName || creditorId || 'creditor'}`,
      transType,
      createdBy,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    logger.info(`Creditor opening balance ledger entries created for ${balanceId}`);
  } catch (error) {
    logger.error(`Error posting creditor opening balance ${balanceId} to ledger:`, error);
    throw error;
  }
};
