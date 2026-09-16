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
  if (raw === 'bank transfer' || raw === 'bank_transfer' || raw === 'banktransfer' || raw === 'bank') return 'bank_transfer';
  if (raw === 'cash') return 'cash';
  return raw.replace(/\s+/g, '_') || 'cash';
}

function getPaymentAmount(paymentData = {}) {
  return toNumber(paymentData.amount || paymentData.totalAmount || paymentData.amountPaid || paymentData.totalAmountPaid || 0);
}

function getPaymentMethod(paymentData = {}) {
  return normalizePaymentMethod(
    paymentData.paymentMode || paymentData.paymentmode || paymentData.paymentMethod || paymentData.paymentmethod || paymentData.mode || paymentData.payment_type || paymentData.paymentType || 'cash'
  );
}

function getSummaryDate(paymentData = {}) {
  const raw = paymentData.dateymd || paymentData.date || paymentData.paymentDate || paymentData.payment_date || paymentData.createdAt || paymentData.created_at;
  if (!raw) return new Date().toISOString().split('T')[0];
  let dateObj;
  if (raw instanceof admin.firestore.Timestamp || (raw && typeof raw.toDate === 'function')) {
    dateObj = raw.toDate();
  } else {
    dateObj = new Date(raw);
  }
  if (!dateObj || !Number.isFinite(dateObj.getTime())) return new Date().toISOString().split('T')[0];
  return dateObj.toISOString().split('T')[0];
}

function getCompanyId(paymentData = {}) {
  return paymentData.companyid || paymentData.companyId || null;
}

function getCompanyName(paymentData = {}) {
  return paymentData.companyname || paymentData.companyName || paymentData.company || null;
}

function getBranchId(paymentData = {}) {
  return paymentData.branchid || paymentData.branchId || null;
}

function getBranchName(paymentData = {}) {
  return paymentData.branchname || paymentData.branchName || paymentData.branch || null;
}

function getStaffEmail(paymentData = {}) {
  return paymentData.staffemail || paymentData.staffEmail || paymentData.createdByEmail || paymentData.createdBy || paymentData.createdby || paymentData.receiptByEmail || paymentData.staff || null;
}

function getStaffName(paymentData = {}) {
  return paymentData.staff || paymentData.staffName || paymentData.staffname || paymentData.createdBy || paymentData.createdby || paymentData.receiptby || null;
}

function buildBranchUpdate(branchId, branchName, summaryId, summaryDate, fieldDeltas, transactionDelta) {
  const update = {
    summaryid: summaryId,
    summarydate: summaryDate,
    branchId,
    branchName,
    branchlastupdate: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (transactionDelta) {
    update.branchtransaction_count = admin.firestore.FieldValue.increment(transactionDelta);
  }
  Object.entries(fieldDeltas).forEach(([field, delta]) => {
    if (!delta) return;
    update[field] = admin.firestore.FieldValue.increment(delta);
  });
  return update;
}

async function applySalesSummaryMutation(
  db,
  docId,
  companyId,
  companyName,
  summaryDate,
  fieldDeltas,
  branchUpdates,
  transactionCountDelta,
  isCreate,
  staffUpdates,
) {
  if (!docId) return;
  const salesSummaryRef = db.collection('salesSummary').doc(docId);
  const update = {
    companyid: companyId,
    company: companyName,
    summaryid: docId,
    summarydate: summaryDate,
  };
  if (isCreate) {
    update.createdat = admin.firestore.FieldValue.serverTimestamp();
  }
  if (transactionCountDelta) {
    update.companytransaction_count = admin.firestore.FieldValue.increment(transactionCountDelta);
  }
  Object.entries(fieldDeltas).forEach(([field, delta]) => {
    if (!delta) return;
    update[field] = admin.firestore.FieldValue.increment(delta);
  });
  if (branchUpdates && Object.keys(branchUpdates).length) {
    update.branchSummary = branchUpdates;
  }
  if (staffUpdates && Object.keys(staffUpdates).length) {
    update.staffSummary = staffUpdates;
  }
  const hasPayload = Object.keys(update).some((key) => key !== 'summaryid' && key !== 'companyid' && key !== 'company' && key !== 'summarydate');
  if (!hasPayload) return;
  await salesSummaryRef.set(update, { merge: true });
}

function buildStaffUpdate(branchId, branchName, staffEmail, staffName, summaryId, summaryDate, fieldDeltas, transactionDelta) {
  if (!staffEmail) return null;
  const update = {
    summaryid: summaryId,
    summarydate: summaryDate,
    branchId,
    branchName,
    staffemail: staffEmail,
    staff: staffName || staffEmail,
    staffName: staffName || staffEmail,
    stafflastupdate: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (transactionDelta) {
    update.stafftransaction_count = admin.firestore.FieldValue.increment(transactionDelta);
  }
  Object.entries(fieldDeltas).forEach(([field, delta]) => {
    if (!delta) return;
    update[field] = admin.firestore.FieldValue.increment(delta);
  });
  return update;
}

exports.updateSalesSummaryForDebtPayment = async ({ beforeData, afterData, paymentId }) => {
  const db = admin.firestore();
  const oldPayment = beforeData || {};
  const newPayment = afterData || {};

  const oldAmount = beforeData ? getPaymentAmount(oldPayment) : 0;
  const newAmount = afterData ? getPaymentAmount(newPayment) : 0;

  const rawOldMethod = beforeData ? getPaymentMethod(oldPayment) : null;
  const rawNewMethod = afterData ? getPaymentMethod(newPayment) : null;

  const oldMethod = rawOldMethod ? `debtpayment_${rawOldMethod}` : null;
  const newMethod = rawNewMethod ? `debtpayment_${rawNewMethod}` : null;

  const oldBranchId = beforeData ? getBranchId(oldPayment) : null;
  const newBranchId = afterData ? getBranchId(newPayment) : null;
  const oldBranchName = beforeData ? getBranchName(oldPayment) : null;
  const newBranchName = afterData ? getBranchName(newPayment) : null;
  const oldCompanyId = beforeData ? getCompanyId(oldPayment) : null;
  const newCompanyId = afterData ? getCompanyId(newPayment) : null;
  const oldCompanyName = beforeData ? getCompanyName(oldPayment) : null;
  const newCompanyName = afterData ? getCompanyName(newPayment) : null;
  const oldDate = beforeData ? getSummaryDate(oldPayment) : null;
  const newDate = afterData ? getSummaryDate(newPayment) : null;
  const oldStaffEmail = beforeData ? getStaffEmail(oldPayment) : null;
  const newStaffEmail = afterData ? getStaffEmail(newPayment) : null;
  const oldStaffName = beforeData ? getStaffName(oldPayment) : null;
  const newStaffName = afterData ? getStaffName(newPayment) : null;

  if (!beforeData && afterData && newAmount <= 0) {
    return;
  }
  if (beforeData && !afterData && oldAmount <= 0) {
    return;
  }

  const oldDocId = oldCompanyId && oldDate ? `${oldCompanyId}_${oldDate}` : null;
  const newDocId = newCompanyId && newDate ? `${newCompanyId}_${newDate}` : null;

  const promises = [];

  if (beforeData && !afterData) {
    const fieldDeltas = { [oldMethod]: -oldAmount };
    const branchUpdates = oldBranchId
      ? { [oldBranchId]: buildBranchUpdate(oldBranchId, oldBranchName, oldDocId, oldDate, fieldDeltas, -1) }
      : null;
    const staffUpdates = oldStaffEmail && oldBranchId
      ? { [oldBranchId]: { [oldStaffEmail]: buildStaffUpdate(oldBranchId, oldBranchName, oldStaffEmail, oldStaffName, oldDocId, oldDate, { debtpayments_value: -oldAmount, [oldMethod]: -oldAmount }, -1) } }
      : null;
    promises.push(
      applySalesSummaryMutation(db, oldDocId, oldCompanyId, oldCompanyName, oldDate, fieldDeltas, branchUpdates, -1, false, staffUpdates),
    );
  } else if (!beforeData && afterData) {
    const fieldDeltas = { [newMethod]: newAmount };
    const branchUpdates = newBranchId
      ? { [newBranchId]: buildBranchUpdate(newBranchId, newBranchName, newDocId, newDate, fieldDeltas, 1) }
      : null;
    const staffUpdates = newStaffEmail && newBranchId
      ? { [newBranchId]: { [newStaffEmail]: buildStaffUpdate(newBranchId, newBranchName, newStaffEmail, newStaffName, newDocId, newDate, { debtpayments_value: newAmount, [newMethod]: newAmount }, 1) } }
      : null;
    promises.push(
      applySalesSummaryMutation(db, newDocId, newCompanyId, newCompanyName, newDate, fieldDeltas, branchUpdates, 1, true, staffUpdates),
    );

  } else if (beforeData && afterData) {
    if (oldDocId === newDocId) {
      const topFieldDeltas = {};
      if (oldMethod === newMethod) {
        topFieldDeltas[newMethod] = newAmount - oldAmount;
      } else {
        topFieldDeltas[oldMethod] = -oldAmount;
        topFieldDeltas[newMethod] = newAmount;
      }
      const branchUpdates = {};
      if (oldBranchId) {
        branchUpdates[oldBranchId] = buildBranchUpdate(
          oldBranchId,
          oldBranchName,
          oldDocId,
          oldDate,
          { [oldMethod]: oldMethod === newMethod ? newAmount - oldAmount : -oldAmount },
          0,
        );
      }
      if (newBranchId) {
        branchUpdates[newBranchId] = buildBranchUpdate(
          newBranchId,
          newBranchName,
          newDocId,
          newDate,
          { [newMethod]: newBranchId === oldBranchId && oldMethod === newMethod ? newAmount - oldAmount : newAmount },
          0,
        );
      }
      const staffUpdates = {};
      if (oldStaffEmail && oldBranchId && newStaffEmail && newBranchId && oldStaffEmail === newStaffEmail) {
        staffUpdates[oldBranchId] = { [oldStaffEmail]: buildStaffUpdate(
          oldBranchId,
          oldBranchName,
          oldStaffEmail,
          oldStaffName,
          oldDocId,
          oldDate,
          {
            debtpayments_value: newAmount - oldAmount,
            [oldMethod]: oldMethod === newMethod ? newAmount - oldAmount : -oldAmount,
            ...(oldMethod !== newMethod ? { [newMethod]: newAmount } : {}),
          },
          0,
        ) };
      } else {
        if (oldStaffEmail && oldBranchId) {
          staffUpdates[oldBranchId] = staffUpdates[oldBranchId] || {};
          staffUpdates[oldBranchId][oldStaffEmail] = buildStaffUpdate(
            oldBranchId,
            oldBranchName,
            oldStaffEmail,
            oldStaffName,
            oldDocId,
            oldDate,
            { debtpayments_value: -oldAmount, [oldMethod]: -oldAmount },
            0,
          );
        }
        if (newStaffEmail && newBranchId) {
          staffUpdates[newBranchId] = staffUpdates[newBranchId] || {};
          staffUpdates[newBranchId][newStaffEmail] = buildStaffUpdate(
            newBranchId,
            newBranchName,
            newStaffEmail,
            newStaffName,
            newDocId,
            newDate,
            { debtpayments_value: newAmount, [newMethod]: newAmount },
            0,
          );
        }
      }
      promises.push(
        applySalesSummaryMutation(db, newDocId, newCompanyId, newCompanyName, newDate, topFieldDeltas, branchUpdates, 0, false, staffUpdates),
      );
    } else {
      if (oldAmount > 0) {
        const oldFieldDeltas = { [oldMethod]: -oldAmount };
        const oldBranchUpdates = oldBranchId
          ? { [oldBranchId]: buildBranchUpdate(oldBranchId, oldBranchName, oldDocId, oldDate, oldFieldDeltas, -1) }
          : null;
        const oldStaffUpdates = oldStaffEmail && oldBranchId
          ? { [oldBranchId]: { [oldStaffEmail]: buildStaffUpdate(oldBranchId, oldBranchName, oldStaffEmail, oldStaffName, oldDocId, oldDate, { debtpayments_value: -oldAmount, [oldMethod]: -oldAmount }, -1) } }
          : null;
        promises.push(
          applySalesSummaryMutation(db, oldDocId, oldCompanyId, oldCompanyName, oldDate, oldFieldDeltas, oldBranchUpdates, -1, false, oldStaffUpdates),
        );
      }
      if (newAmount > 0) {
        const newFieldDeltas = { [newMethod]: newAmount };
        const newBranchUpdates = newBranchId
          ? { [newBranchId]: buildBranchUpdate(newBranchId, newBranchName, newDocId, newDate, newFieldDeltas, 1) }
          : null;
        const newStaffUpdates = newStaffEmail && newBranchId
          ? { [newBranchId]: { [newStaffEmail]: buildStaffUpdate(newBranchId, newBranchName, newStaffEmail, newStaffName, newDocId, newDate, { debtpayments_value: newAmount, [newMethod]: newAmount }, 1) } }
          : null;
        promises.push(
          applySalesSummaryMutation(db, newDocId, newCompanyId, newCompanyName, newDate, newFieldDeltas, newBranchUpdates, 1, false, newStaffUpdates),
        );
      }
    }
  }

  await Promise.all(promises);
}

exports.postDebtPaymentToLedger = async (paymentData = {}, paymentId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = paymentData.companyid || paymentData.companyId || null;
    const companyname = paymentData.companyname || paymentData.companyName || null;
    const branchId = paymentData.branchid || paymentData.branchId || null;
    const branchName = paymentData.branchname || paymentData.branchName || null;
    const amount = toNumber(paymentData.amount || 0);
    const paymentAccount = paymentData.account || paymentData.accountName || paymentData.subAccountName || paymentData.subAccountId || 'Cash';
    const paymentMethod = normalizePaymentMethod(paymentData.paymentmethod || paymentData.paymentMethod || paymentAccount || 'cash');
    const customerId = paymentData.customerid || paymentData.customerId || null;
    const customerName = paymentData.customername || paymentData.customerName || null;
    const contact = paymentData.contact || null;
    const transType = paymentData.transType || paymentData.transtype || 'debt payment';
    const reference = paymentData.reference || paymentData.ref || null;
    const createdBy = paymentData.createdby || paymentData.createdBy || 'system';

    if (amount <= 0) {
      logger.warn(`Debt payment ${paymentId} skipped because amount is zero or invalid`, { paymentId, amount });
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
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
        return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
      })();
      const dayName = now.toLocaleString('en-US', { weekday: 'long' });
      const meta = resolveAccountMeta(entry.account, entry.type === 'debit' ? DEFAULT_TYPES.ASSET : DEFAULT_TYPES.ASSET);
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
      account: paymentAccount,
      type: 'debit',
      amount,
      description: `Debt payment ${paymentId} received via ${paymentMethod}`,
      customerId,
      customerName,
      contact,
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
      account: 'accounts_receivable',
      type: 'credit',
      amount,
      description: `Debt payment ${paymentId} applied to receivables for ${customerName || customerId}`,
      customerId,
      customerName,
      contact,
      reference,
      transType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy,
    });

    await batch.commit();
    logger.info(`Debt payment ledger entries created for ${paymentId}`);
  } catch (error) {
    logger.error(`Error posting debt payment ${paymentId} to ledger:`, error);
    throw error;
  }
};
