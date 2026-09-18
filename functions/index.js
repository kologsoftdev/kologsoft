const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const https = require("https");
const querystring = require("querystring");
const axios = require("axios");
const {defineString} = require("firebase-functions/params");
require('dotenv').config();
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const { postDamageToLedger, postStockTransferToLedger, resolveAccountMeta } = require("./ledger");
const { postJournalToLedger } = require("./journal");
const { reconcileAccountsSummary } = require("./ledgersummary");
const smsModule = require("./sendSMS");
const {uploadStock,} = require("./stockupload");
const {uploadSales} = require("./salesupload");
const {uploadItemsreg} = require("./itemsupload");
//const { getFirebaseUsage } = require("./firebaseusage");
const { admin, db } = require("./fb");


const COLLECTION_MANAGER_PROTECTED = ["_config", "audit_logs"];
const COMPANY_FIELD_VARIANTS = ["companyId", "companyid", "companyID"];



//exports.getFirebaseUsage = getFirebaseUsage;
exports.uploadStock = uploadStock;
exports.uploadSales = uploadSales;
exports.uploadItemsreg = uploadItemsreg;

async function getStaffProfile(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const email = request.auth.token?.email;
  if (!email) {
    throw new HttpsError(
      "failed-precondition",
      "Signed-in account has no email on its auth token."
    );
  }
  const db = admin.firestore();
  const snap = await db.collection("staff").doc(email).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "No staff profile found for this account.");
  }
  return snap.data();
}

function assertSuperAdmin(profile) {
  if (profile.accesslevel !== "super admin") {
    throw new HttpsError("permission-denied", "Only super admins can perform this action.");
  }
}

exports.listFirestoreCollections = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const db = admin.firestore();
  const collections = await db.listCollections();
  return { collections: collections.map((c) => c.id).sort() };
});

exports.clearFirestoreCollections = onCall(async (request) => {
  const { collectionNames, staffId } = request.data || {};

  if (!Array.isArray(collectionNames) || collectionNames.length === 0) {
    throw new HttpsError("invalid-argument", "collectionNames must be a non-empty array.");
  }
  if (!staffId || typeof staffId !== "string") {
    throw new HttpsError("invalid-argument", "staffId is required.");
  }

  const profile = await getStaffProfile(request);
  assertSuperAdmin(profile);

  if (profile.email !== staffId) {
    throw new HttpsError("permission-denied", "Staff ID does not match the signed-in account.");
  }

  const companyId = profile.companyid || profile.companyId || profile.companyID;
  if (!companyId) {
    throw new HttpsError("failed-precondition", "Your staff profile has no companyid set.");
  }

  const blocked = collectionNames.filter((c) => COLLECTION_MANAGER_PROTECTED.includes(c));
  if (blocked.length > 0) {
    throw new HttpsError(
      "permission-denied",
      `These collections are protected: ${blocked.join(", ")}`
    );
  }

  const db = admin.firestore();
  const results = {};
  for (const name of collectionNames) {
    results[name] = await deleteCompanyDocsFromCollection(db, name, companyId, 300);
  }

  await db.collection("audit_logs").add({
    action: "clear_company_documents",
    performedByEmail: request.auth.token.email,
    staffId,
    companyId,
    collections: collectionNames,
    deletedCounts: results,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { deletedCounts: results };
});

async function deleteCompanyDocsFromCollection(db, collectionPath, companyId, batchSize) {
  const collectionRef = db.collection(collectionPath);
  const deletedPaths = new Set();

  for (const field of COMPANY_FIELD_VARIANTS) {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const snapshot = await collectionRef.where(field, "==", companyId).limit(batchSize).get();
      if (snapshot.empty) break;

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deletedPaths.add(doc.ref.path);
      });
      await batch.commit();

      if (snapshot.size < batchSize) break;
    }
  }
  return deletedPaths.size;
}

// Export SMS functions
exports.sendSMS = smsModule.sendSMS;
exports.processPendingSMS = smsModule.processPendingSMS;
exports.onSMSCreated = smsModule.onSMSCreated;
exports.sendBulkSMS = smsModule.sendBulkSMS;
exports.sendBulkSMSWithFilters = smsModule.sendBulkSMSWithFilters;

// =========================
// Dashboard Stats Aggregates
// =========================
// Maintains running totals so the app can display totals without scanning the sales collection.
// Collection name intentionally matches request spelling.

function toNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
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

function normalizeTransMode(mode) {
  const m = (mode ?? '').toString().trim().toLowerCase();
  if (m === 'credit'||m==='credit sales') return 'credit';
  if (m === 'momo' || m === 'mobilemoney' || m === 'mobile_money' || m === 'mobile money') return 'momo';
  if (m === 'card' || m === 'pos' || m === 'visa' || m === 'mastercard') return 'card';
  if (m === 'bank_transfer' || m === 'bank transfer' || m === 'banktransfer' || m === 'bank' || m === 'transfer') return 'bank_transfer';
  if (m === 'cheque' || m === 'check' || m === 'cheque_payment' || m === 'cheque payment') return 'cheque';
  return 'cash';
}

function isSaleApproved(saleData) {
  if (!saleData) return false;
  const status = saleData.stockCheckStatus;
  return typeof status === 'string' && status.toLowerCase() === 'approved';
}

function resolveSaleCompanyId(saleData) {
  return (
    saleData?.companyId ||
    saleData?.companyid ||
    saleData?.companyID ||
    null
  );
}


function resolveSaleBranchId(saleData) {
  return (
    saleData?.branchId ||
    saleData?.branchid ||
    saleData?.branch_id ||
    saleData?.branch ||
    saleData?.warehouse ||
    null
  );
}

function resolveSaleBranchName(saleData, branchId) {
  return (
    saleData?.branchName ||
    saleData?.branchname ||
    saleData?.branch_name ||
    saleData?.warehouseName ||
    branchId ||
    ''
  );
}

function resolveSaleTransMode(saleData) {
  return (
    saleData?.transMode ||
    saleData?.tranmode ||
    saleData?.tranMode ||
    saleData?.transmode ||
    saleData?.paymentMode ||
    saleData?.paymode ||
    'cash'
  );
}

function resolveSaleAmount(saleData) {
  return toNumber(
    saleData?.totalamount ??
      saleData?.totalAmount ??
      saleData?.amount ??
      saleData?.netTotal ??
      saleData?.grandTotal ??
      0,
  );
}

function resolveSaleDiscountTotal(saleData) {
  // Prefer explicit root fields if present, otherwise derive from line items.
  const explicit = toNumber(
    saleData?.discount_total ??
      saleData?.discountTotal ??
      saleData?.totalDiscount ??
      saleData?.discount ??
      0,
  );
  if (explicit !== 0) return explicit;

  const items = saleData?.items;
  if (!items || typeof items !== 'object') return 0;

  let sum = 0;
  for (const value of Object.values(items)) {
    if (!value || typeof value !== 'object') continue;
    sum += toNumber(value.discount ?? value.Discount ?? 0);
  }
  return sum;
}

function resolveSaleDate(saleData) {
  const ts = saleData?.createdAt ?? saleData?.receiptat ?? saleData?.printedat;
  if (ts && typeof ts.toDate === 'function') {
    try {
      return ts.toDate();
    } catch (_) {
      // fall through
    }
  }

  const epoch = saleData?.timestamp;
  if (typeof epoch === 'number' && Number.isFinite(epoch)) {
    const dt = new Date(epoch);
    return Number.isFinite(dt.getTime()) ? dt : null;
  }

  const fallbackDate = saleData?.dateymd || saleData?.date;
  if (typeof fallbackDate === 'string' && fallbackDate.length >= 8) {
    const dt = new Date(fallbackDate);
    if (Number.isFinite(dt.getTime())) return dt;
  }

  return null;
}

function formatDateOnly(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function getWeekNumber(date) {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const days = Math.floor((date - firstDayOfYear) / 86400000);
  const firstWeekday = ((firstDayOfYear.getDay() + 6) % 7) + 1;
  return Math.ceil((days + firstWeekday) / 7);
}

function resolveSaleDateParts(saleData) {
  const dateStr = saleData?.dateymd || saleData?.date;
  const sourceDate = resolveSaleDate(saleData) || (typeof dateStr === 'string' ? new Date(dateStr) : null) || new Date();

  const year = saleData?.year || `${sourceDate.getFullYear()}`;
  const month = saleData?.month || `${sourceDate.getFullYear()}.${sourceDate.getMonth() + 1}`;
  const week = saleData?.week || `${sourceDate.getFullYear()}.${getWeekNumber(sourceDate)}`;
  const day = saleData?.day || ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][sourceDate.getDay()];
  const dateymd = dateStr || formatDateOnly(sourceDate);

  return {dateymd, day, month, week, year};
}

function buildProfitAndLossReport(entries = [], filters = {}) {
  const normalizeAccount = (value) => String(value || '').trim().toLowerCase();

  const income = {};
  const costOfGoodsSold = {};
  const operatingExpenses = {};
  const otherActivity = {};
  const supporting = [];

  entries.forEach((entry) => {
    const amount = toNumber(entry?.amount || 0);
    if (!amount) return;

    const account = String(entry?.account || '').trim();
    const accountKey = normalizeAccount(account);
    const type = String(entry?.type || '').toLowerCase();
    const meta = resolveAccountMeta(account, null) || {};
    const accountType = String(entry?.accountType || meta.type || 'Other');
    const sourceType = String(entry?.sourceType || 'ledger');

    const isIncome = accountType === 'Income' || ['sales', 'sales_revenue', 'service_revenue', 'sales_return'].includes(accountKey);
    const isExpense = accountType === 'Expense' || ['discount', 'damage_expense', 'expense', 'fuel_purchase', 'cost_of_goods_sold'].includes(accountKey);
    const isCogs = ['inventory', 'stock', 'cost_of_goods_sold', 'purchase_return', 'purchase_returns'].includes(accountKey);

    const bucket = isIncome
      ? income
      : isCogs
        ? costOfGoodsSold
        : isExpense
          ? operatingExpenses
          : otherActivity;

    const value = type === 'debit' ? amount : 0;
    const creditValue = type === 'credit' ? amount : 0;

    if (isIncome) {
      bucket[account] = (bucket[account] || 0) + creditValue;
    } else if (isCogs) {
      bucket[account] = (bucket[account] || 0) + (type === 'debit' ? amount : 0);
    } else if (isExpense) {
      bucket[account] = (bucket[account] || 0) + value;
    } else {
      bucket[account] = (bucket[account] || 0) + (type === 'debit' ? amount : 0);
    }

    if (['receivable', 'payable', 'creditor', 'debtor', 'journal', 'inventory', 'stock'].includes(accountKey) || sourceType === 'journal') {
      supporting.push({
        account,
        type,
        amount,
        sourceType,
        description: entry?.description || '',
        branchId: entry?.branchId || '',
        branchName: entry?.branchName || '',
        date: entry?.date || '',
      });
    }
  });

  const totalSalesRevenue = Object.values(income).reduce((sum, value) => sum + value, 0);
  const totalCostOfGoodsSold = Object.values(costOfGoodsSold).reduce((sum, value) => sum + value, 0);
  const totalOperatingExpenses = Object.values(operatingExpenses).reduce((sum, value) => sum + value, 0);
  const totalOtherActivity = Object.values(otherActivity).reduce((sum, value) => sum + value, 0);

  const grossProfit = totalSalesRevenue - totalCostOfGoodsSold;
  const netProfit = grossProfit - totalOperatingExpenses + totalOtherActivity;

  return {
    period: {
      companyId: filters.companyId || null,
      branchId: filters.branchId || null,
      startDate: filters.startDate || null,
      endDate: filters.endDate || null,
    },
    totals: {
      salesRevenue: totalSalesRevenue,
      costOfGoodsSold: totalCostOfGoodsSold,
      grossProfit,
      operatingExpenses: totalOperatingExpenses,
      otherActivity: totalOtherActivity,
      netProfit,
    },
    details: {
      income,
      costOfGoodsSold,
      operatingExpenses,
      otherActivity,
      supportingEntries: supporting,
    },
  };
}

function dailyTotalKey(branchId, date) {
  if (!branchId || !date) return null;
  const y = date.getFullYear();
  const m = date.getMonth() + 1;
  const d = date.getDate();
  return `${branchId}_${y}_${m}_${d}`;
}

function dashboardBranchSaleUpdateArgs(branchId, values) {
  const args = [];
  Object.entries(values).forEach(([field, value]) => {
    args.push(new admin.firestore.FieldPath('branchsale', branchId, field), value);
  });
  return args;
}

// Trigger: Maintain aggregate totals for cash/credit sales and per-branch totals.
// Writes to: dashbaord_stats/{companyId}
// - sales_total: { cash, credit }
// - branchsale: { [branchId]: { cash, credit, branchname } }
// Also keeps compatibility fields used by the app: cash, credit, overallTotal, transModeTotals.
exports.aggregateSalesTotals = onDocumentWritten('sales/{saleId}', async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const saleId = event.params.saleId;

  const companyId = resolveSaleCompanyId(after) || resolveSaleCompanyId(before);
  if (!companyId) {
    logger.warn('aggregateSalesTotals: missing companyId', {saleId});
    return null;
  }

  const beforeApproved = isSaleApproved(before);
  const afterApproved = isSaleApproved(after);

  // Process sales on create/delete always, only skip unapproved updates
  const isCreate = !before && after;
  const isDelete = before && !after;
  const isUpdate = before && after;
  
  // For updates, only skip if both before and after are unapproved
  if (isUpdate && !beforeApproved && !afterApproved) {
    logger.debug(`aggregateSalesTotals: skipping unapproved sale update ${saleId}`);
    return null;
  }

  // Process before values for deletes or if sale was approved
  const shouldProcessBefore = isDelete || beforeApproved;
  // Process after values for creates or if sale becomes approved  
  const shouldProcessAfter = isCreate || afterApproved;

  const beforeMode = shouldProcessBefore && before ? normalizeTransMode(resolveSaleTransMode(before)) : null;
  const afterMode = shouldProcessAfter && after ? normalizeTransMode(resolveSaleTransMode(after)) : null;

  const beforeAmount = shouldProcessBefore && before ? resolveSaleAmount(before) : 0;
  const afterAmount = shouldProcessAfter && after ? resolveSaleAmount(after) : 0;

  const beforeDiscount = shouldProcessBefore && before ? resolveSaleDiscountTotal(before) : 0;
  const afterDiscount = shouldProcessAfter && after ? resolveSaleDiscountTotal(after) : 0;
  const discountDelta = afterDiscount - beforeDiscount;

  const beforeBranchId = shouldProcessBefore && before ? resolveSaleBranchId(before) : null;
  const afterBranchId = shouldProcessAfter && after ? resolveSaleBranchId(after) : null;
  const afterBranchName = shouldProcessAfter && after
    ? resolveSaleBranchName(after, afterBranchId)
    : '';

  const modeDeltas = {
    cash: 0,
    credit: 0,
    momo: 0,
    card: 0,
    bank_transfer: 0,
    cheque: 0,
  };

  const addModeDelta = (mode, delta) => {
    if (!mode || delta === 0) return;
    const key = normalizeTransMode(mode);
    if (Object.prototype.hasOwnProperty.call(modeDeltas, key)) {
      modeDeltas[key] += delta;
    } else {
      modeDeltas.cash += delta;
    }
  };

  if (shouldProcessBefore && beforeAmount !== 0) addModeDelta(beforeMode, -beforeAmount);
  if (shouldProcessAfter && afterAmount !== 0) addModeDelta(afterMode, afterAmount);

  const overallDelta = Object.values(modeDeltas).reduce((sum, v) => sum + v, 0);

  const beforeDayKey = shouldProcessBefore
    ? dailyTotalKey(beforeBranchId, resolveSaleDate(before))
    : null;
  const afterDayKey = shouldProcessAfter
    ? dailyTotalKey(afterBranchId, resolveSaleDate(after))
    : null;

  const hasAnyDelta =
    Object.values(modeDeltas).some((v) => v !== 0) ||
    discountDelta !== 0 ||
    (beforeDayKey !== afterDayKey && (beforeAmount !== 0 || afterAmount !== 0));
  if (!hasAnyDelta) return null;

  const db = admin.firestore();
  const statsRef = db.collection('dashbaord_stats').doc(companyId);

  // Build per-branch deltas.
  const branchDeltas = new Map();
  const addBranchDelta = (branchId, mode, delta) => {
    if (!branchId || !mode || delta === 0) return;
    const normalizedMode = normalizeTransMode(mode);
    const key = `${branchId}::${normalizedMode}`;
    branchDeltas.set(key, (branchDeltas.get(key) || 0) + delta);
  };

  const branchDiscountDeltas = new Map();
  const addBranchDiscountDelta = (branchId, delta) => {
    if (!branchId || delta === 0) return;
    branchDiscountDeltas.set(
      branchId,
      (branchDiscountDeltas.get(branchId) || 0) + delta,
    );
  };

  if (shouldProcessBefore && beforeBranchId && beforeAmount !== 0) {
    addBranchDelta(beforeBranchId, beforeMode, -beforeAmount);
  }
  if (shouldProcessAfter && afterBranchId && afterAmount !== 0) {
    addBranchDelta(afterBranchId, afterMode, afterAmount);
  }

  if (shouldProcessBefore && beforeBranchId && beforeDiscount !== 0) {
    addBranchDiscountDelta(beforeBranchId, -beforeDiscount);
  }
  if (shouldProcessAfter && afterBranchId && afterDiscount !== 0) {
    addBranchDiscountDelta(afterBranchId, afterDiscount);
  }

  try {
    await db.runTransaction(async (transaction) => {
      // Ensure doc exists and keep app-compatible fields.
      transaction.set(
        statsRef,
        {
          companyId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          cash: admin.firestore.FieldValue.increment(modeDeltas.cash),
          credit: admin.firestore.FieldValue.increment(modeDeltas.credit),
          momo: admin.firestore.FieldValue.increment(modeDeltas.momo),
          card: admin.firestore.FieldValue.increment(modeDeltas.card),
          bank_transfer: admin.firestore.FieldValue.increment(modeDeltas.bank_transfer),
          cheque: admin.firestore.FieldValue.increment(modeDeltas.cheque),
          overallTotal: admin.firestore.FieldValue.increment(overallDelta),
          discount_total: admin.firestore.FieldValue.increment(discountDelta),
        },
        {merge: true},
      );

      const updateArgs = [];

      if (modeDeltas.cash !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('sales_total', 'cash'),
          admin.firestore.FieldValue.increment(modeDeltas.cash),
          new admin.firestore.FieldPath('transModeTotals', 'cash'),
          admin.firestore.FieldValue.increment(modeDeltas.cash),
        );
      }

      if (modeDeltas.credit !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('sales_total', 'credit'),
          admin.firestore.FieldValue.increment(modeDeltas.credit),
          new admin.firestore.FieldPath('transModeTotals', 'credit'),
          admin.firestore.FieldValue.increment(modeDeltas.credit),
        );
      }

      if (modeDeltas.momo !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('sales_total', 'momo'),
          admin.firestore.FieldValue.increment(modeDeltas.momo),
          new admin.firestore.FieldPath('transModeTotals', 'momo'),
          admin.firestore.FieldValue.increment(modeDeltas.momo),
        );
      }

      if (modeDeltas.card !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('sales_total', 'card'),
          admin.firestore.FieldValue.increment(modeDeltas.card),
          new admin.firestore.FieldPath('transModeTotals', 'card'),
          admin.firestore.FieldValue.increment(modeDeltas.card),
        );
      }

      if (modeDeltas.bank_transfer !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('sales_total', 'bank_transfer'),
          admin.firestore.FieldValue.increment(modeDeltas.bank_transfer),
          new admin.firestore.FieldPath('transModeTotals', 'bank_transfer'),
          admin.firestore.FieldValue.increment(modeDeltas.bank_transfer),
        );
      }

      if (modeDeltas.cheque !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('sales_total', 'cheque'),
          admin.firestore.FieldValue.increment(modeDeltas.cheque),
          new admin.firestore.FieldPath('transModeTotals', 'cheque'),
          admin.firestore.FieldValue.increment(modeDeltas.cheque),
        );
      }

      // Per-branch totals.
      for (const [key, delta] of branchDeltas.entries()) {
        const [branchId, mode] = key.split('::');
        if (!branchId || !mode || delta === 0) continue;
        updateArgs.push(
          new admin.firestore.FieldPath('branchsale', branchId, mode),
          admin.firestore.FieldValue.increment(delta),
        );
      }

      // Per-branch discount totals.
      for (const [branchId, delta] of branchDiscountDeltas.entries()) {
        if (!branchId || delta === 0) continue;
        updateArgs.push(
          new admin.firestore.FieldPath('branchsale', branchId, 'discount_total'),
          admin.firestore.FieldValue.increment(delta),
        );
      }

      // Daily totals keyed as branchId_y_m_d.
      if (shouldProcessBefore && beforeDayKey && beforeAmount !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('dailytotal', beforeDayKey),
          admin.firestore.FieldValue.increment(-beforeAmount),
        );
      }

      if (shouldProcessAfter && afterDayKey && afterAmount !== 0) {
        updateArgs.push(
          new admin.firestore.FieldPath('dailytotal', afterDayKey),
          admin.firestore.FieldValue.increment(afterAmount),
        );
      }

      // Keep branch name up-to-date for the branch receiving the latest write.
      if (shouldProcessAfter && afterBranchId) {
        updateArgs.push(
          ...dashboardBranchSaleUpdateArgs(afterBranchId, {
            branchname: afterBranchName,
          }),
        );

        // Ensure mode keys exist on the branch map even if no transactions for that mode yet.
        // increment(0) will create the field with 0 if missing, without changing existing totals.
        updateArgs.push(
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'cash'),
          admin.firestore.FieldValue.increment(0),
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'credit'),
          admin.firestore.FieldValue.increment(0),
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'momo'),
          admin.firestore.FieldValue.increment(0),
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'card'),
          admin.firestore.FieldValue.increment(0),
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'bank_transfer'),
          admin.firestore.FieldValue.increment(0),
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'cheque'),
          admin.firestore.FieldValue.increment(0),
          new admin.firestore.FieldPath('branchsale', afterBranchId, 'discount_total'),
          admin.firestore.FieldValue.increment(0),
        );
      }

      // Only call update when we have field-path updates to apply.
      if (updateArgs.length > 0) {
        transaction.update(statsRef, ...updateArgs);
      }
    });

    logger.info('aggregateSalesTotals updated dashboard stats', {
      saleId,
      companyId,
      modeDeltas,
      overallDelta,
      discountDelta,
      beforeDayKey,
      afterDayKey,
      beforeApproved,
      afterApproved,
    });
    
    return null;
  } catch (error) {
    logger.error('aggregateSalesTotals error', {saleId, companyId, error});
    return null;
  }
});



const SMTP_USER = defineString("SMTP_USER");
const SMTP_PASS = defineString("SMTP_PASS");
const SMTP_FROM = defineString("SMTP_FROM");
const SMTP_REPLYTO = defineString("SMTP_REPLYTO");

// WhatsApp API credentials via Params/Env

async function sendEmail({to, subject, text, html}) {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: SMTP_USER.value() || process.env.SMTP_USER || "",
      pass: SMTP_PASS.value() || process.env.SMTP_PASS || ""
    }
  });
  const mailOptions = {
    from: SMTP_FROM.value() || process.env.SMTP_FROM || 'KologSoft POS <no-reply@kologsoft.com>',
    replyTo: SMTP_REPLYTO.value() || process.env.SMTP_REPLYTO || 'support@kologsoft.com',
    to,
    subject,
    text,
    html
  };
  return transporter.sendMail(mailOptions);
}

function generateNumericPassword(length = 12) {
  // Include uppercase, lowercase, and digits to satisfy Firebase Auth password policies.
  // At least one of each type is guaranteed by seeding the pool first.
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';
  const all = upper + lower + digits;

  const pick = (charset) => charset[crypto.randomInt(0, charset.length)];

  // Seed with one char from each required class
  const pool = [pick(upper), pick(lower), pick(digits)];
  while (pool.length < length) {
    pool.push(pick(all));
  }

  // Fisher-Yates shuffle using crypto.randomInt
  for (let i = pool.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }

  return pool.join('');
}

// Helper: derive payment status from ResponseCode/Message

async function resolveSmsConfig(companyId, fallbackSenderId) {
  const normalizedCompanyId = String(companyId || '').trim();

  if (!normalizedCompanyId) {
    return {
      apiKey: process.env.KOLOGSMS_API_KEY || process.env.SMS_API_KEY || '',
      senderid: fallbackSenderId || '',
    };
  }

  const snapshot = await admin.firestore().collection('sms_config').where('companyid', '==', normalizedCompanyId).limit(1).get();
  const config = snapshot.empty ? null : snapshot.docs[0].data() || {};

  return {
    apiKey: config.key || config.api_key || process.env.KOLOGSMS_API_KEY || process.env.SMS_API_KEY || '',
    senderid: config.senderid || fallbackSenderId || '',
  };
}

// Helper: SMS sending function
async function sendSMS(message, contact, senderid, companyId) {
  const { apiKey, senderid: configuredSenderId } = await resolveSmsConfig(companyId, senderid);
  const effectiveSenderId = configuredSenderId || senderid ||"KologSoft";

  if (!apiKey) {
    throw new Error('No SMS API key configured for this company.');
  }

  if (!effectiveSenderId) {
    throw new Error('No SMS sender ID configured for this company.');
  }

  return new Promise((resolve, reject) => {
    const params = querystring.stringify({
      action: "send-sms",
      api_key: apiKey||"SXlMVlJCcmlTV1dwVGRyZkVneUs",
      to: contact,
      from: effectiveSenderId,
      sms: message,
    });

    const url = `https://sms.kologsoft.com/sms/api?${params}`;

    https
      .get(url, (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          try {
            const json = JSON.parse(data);
            resolve(json);
          } catch (e) {
            resolve(data);
          }
        });
      })
      .on("error", (err) => {
        reject(err);
      });
  });
}

// Helper: build branchbalance updates without splitting branchId on dots
function branchBalanceUpdateArgs(branchId, values) {
  const args = [];
  Object.entries(values).forEach(([field, value]) => {
    args.push(new admin.firestore.FieldPath('branchbalance', branchId, field), value);
  });
  return args;
}

// Helper: Generate bills for a workspace
// Trigger: Create Firebase Auth user when new staff is added
exports.staffAuthOnCreate = onDocumentCreated("staff/{staffId}", async (event) => {
  const staffData = event.data.data();
  const staffId = event.params.staffId;

  try {
    const email = staffData.email || `${staffData.phone}@krms.com`;
    const phone = staffData.phone || "";
    const name = staffData.name || "";
    const companyid = staffData.companyid || "";
    const tempPassword = generateNumericPassword(8);

    const userRecord = await admin.auth().createUser({
      email,
      password: tempPassword,
      displayName: name,
      phoneNumber: phone ? (phone.startsWith("+") ? phone : `+233${phone.substring(1)}`) : undefined,
    });

    let smsResponse = null;
    let smsError = null;

    let emailResponse = null;
    let emailError = null;

    if (phone) {
      const formattedPhone = phone.startsWith("+") ? phone : `+233${phone.substring(1)}`;
      const smsMessage = `Hello ${name}, your temporary password for KologSoft POS is: ${tempPassword}. Please log in and change this password immediately.`;
      try {

        smsResponse = await sendSMS(smsMessage, formattedPhone, "KologSoft",companyid);
        logger.info(`SMS sent successfully to ${formattedPhone}`, smsResponse);
      } catch (err) {
        smsError = err.message;
        logger.error(`Failed to send SMS to ${formattedPhone}:`, err);
      }
    }

    // Send password via email
    if (email) {
      const emailSubject = process.env.KOLOGSOFT_EMAIL_SUBJECT || `Your KologSoft POS Temporary Password`;
      const appStoreLink = process.env.KOLOGSOFT_APPSTORE || 'https://example.com/appstore';
      const playStoreLink = process.env.KOLOGSOFT_PLAYSTORE || 'https://example.com/playstore';
      const supportEmail = process.env.KOLOGSOFT_SUPPORT || 'support@kologsoft.com';
      const logoUrl = process.env.KOLOGSOFT_LOGO_URL || 'https://storage.googleapis.com/kologsoft-assets/kologsoft-logo.png';

      const emailText = `Hello ${name},\n\nYour temporary password for KologSoft POS is: ${tempPassword}.\nPlease log in and change this password immediately.\n\nLogin: ${email}`;

      const emailHtml = `
        <div style="max-width:600px;margin:0 auto;font-family:'Segoe UI',Arial,sans-serif;background:#f7f9fc;border-radius:8px;padding:28px;">
          <div style="text-align:center;margin-bottom:18px;">
            <img src="${logoUrl}" alt="KologSoft POS" style="height:64px;display:block;margin:0 auto 8px;" />
            <h2 style="color:#0b3d91;margin:0;font-weight:700;">KologSoft POS</h2>
          </div>
          <div style="background:#ffffff;padding:20px;border-radius:8px;border:1px solid #eef2f6;">
            <h3 style="color:#222;margin-top:0;">Hello ${name},</h3>
            <p style="color:#333;font-size:15px;">Welcome to <strong>KologSoft POS</strong> — your point-of-sale and business management app.</p>
            <p style="color:#333;font-size:15px;">Your temporary password is:</p>
            <div style="font-size:20px;font-weight:700;color:#0b67d0;background:#eef7ff;padding:12px;border-radius:6px;text-align:center;margin:12px 0;">${tempPassword}</div>
            <p style="color:#333;font-size:14px;">Login: <strong>${email}</strong></p>
            <p style="color:#333;font-size:14px;">Please open the <strong>KologSoft POS</strong> mobile app and log in with your credentials. You will be prompted to change this password immediately for security.</p>
            <p style="margin-top:14px;font-size:14px;color:#333;">Download the app:</p>
            <p style="margin:6px 0;"><a href="${playStoreLink}">Google Play Store</a> • <a href="${appStoreLink}">App Store</a></p>
            <hr style="border:none;border-top:1px solid #f0f3f6;margin:20px 0;" />
            <p style="font-size:13px;color:#666;margin:0;">Need help? Contact our support at <a href="mailto:${supportEmail}">${supportEmail}</a></p>
          </div>
          <div style="text-align:center;color:#99a0ad;font-size:12px;margin-top:18px;">
            &copy; ${new Date().getFullYear()} KologSoft POS. All rights reserved.
          </div>
        </div>
      `;

      try {
        emailResponse = await sendEmail({to: email, subject: emailSubject, text: emailText, html: emailHtml});
        logger.info(`Email sent successfully to ${email}`);
      } catch (err) {
        emailError = err.message;
        logger.error(`Failed to send email to ${email}:`, err);
      }
    }

    await admin
      .firestore()
      .collection("staff")
      .doc(staffId)
      .update({
        uid: userRecord.uid,
        authCreated: admin.firestore.FieldValue.serverTimestamp(),
        tempPassword,
        smsSent: !!(phone && smsResponse),
        smsResponse: smsResponse || null,
        smsError: smsError || null,
        emailSent: !!(email && emailResponse),
        emailError: emailError || null,
      });

    logger.info(`Auth user created for staff ${name} with email ${email}`);
  } catch (error) {
    logger.error(`Error creating auth user for staff ${staffId}:`, error);
    await admin
      .firestore()
      .collection("staff")
      .doc(staffId)
      .update({
        authError: error.message,
        authCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  }
});

// Trigger: Assign sequential position number to staff when created (GLOBAL counter)
exports.assignStaffPosition = onDocumentCreated("staff/{staffId}", async (event) => {
  const staffData = event.data.data();
  const staffId = event.params.staffId;

  const db = admin.firestore();

  try {
    // Use a transaction to ensure unique position numbers globally
    await db.runTransaction(async (transaction) => {
      const counterRef = db.collection('counters').doc('global_staff_position');
      const counterDoc = await transaction.get(counterRef);

      let position = 1;
      if (counterDoc.exists) {
        position = (counterDoc.data().lastPosition || 0) + 1;
      }

      // Update the global counter
      transaction.set(counterRef, {
        lastPosition: position,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // Update the staff document with position
      const staffRef = db.collection('staff').doc(staffId);
      transaction.update(staffRef, {
        position: position,
        positionAssignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`Assigned global position ${position} to staff ${staffId}`);
    });

    return null;
  } catch (error) {
    logger.error(`Error assigning position to staff ${staffId}:`, error);
    
    // Try to log the error in the staff document
    try {
      await db.collection('staff').doc(staffId).update({
        positionError: error.message,
        positionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (updateError) {
      logger.error(`Failed to update staff document with error:`, updateError);
    }
    
    return null;
  }
});

function resolveSaleCustomerId(saleData) {
  return saleData?.customerId || saleData?.customerid || null;
}

function resolveSaleCustomerName(saleData) {
  return saleData?.customerName || saleData?.customername || null;
}

function resolveSaleCustomerPhone(saleData) {
  return saleData?.customerPhone || saleData?.customerphone || null;
}

function resolveSaleAmountPaid(saleData) {
  return toNumber(
    saleData?.amountPaid ??
      saleData?.amountpaid ??
      saleData?.paidAmount ??
      0,
  );
}

function resolveSalePaymentStatus(saleData) {
  return saleData?.paymentStatus || saleData?.paymentstatus || 'pending';
}

function resolveSaleStockCheckStatus(saleData) {
  return saleData?.stockCheckStatus || saleData?.stockcheckstatus || null;
}

function resolveSaleItemCount(saleData) {
  const explicit = toNumber(saleData?.itemCount ?? saleData?.itemcount ?? 0);
  if (explicit > 0) return explicit;

  const items = saleData?.items;
  if (!items || typeof items !== 'object') return 0;
  return Object.keys(items).length;
}

function buildSaleLedgerPayload(saleData, saleId) {
  const totalAmount = resolveSaleAmount(saleData);
  const amountPaid = resolveSaleAmountPaid(saleData);

  return {
    sourceCollection: 'sales',
    sourceId: saleId,
    companyId: resolveSaleCompanyId(saleData),
    branchId: resolveSaleBranchId(saleData),
    branchName: resolveSaleBranchName(saleData, resolveSaleBranchId(saleData)),
    transMode: normalizeTransMode(resolveSaleTransMode(saleData)),
    customerId: resolveSaleCustomerId(saleData),
    customerName: resolveSaleCustomerName(saleData),
    customerPhone: resolveSaleCustomerPhone(saleData),
    totalAmount,
    amountPaid,
    balance: totalAmount - amountPaid,
    itemCount: resolveSaleItemCount(saleData),
    paymentStatus: resolveSalePaymentStatus(saleData),
    stockCheckStatus: resolveSaleStockCheckStatus(saleData),
    receiptNumber: saleData?.receiptNumber || saleData?.receiptnumber || null,
    saleTimestamp: saleData?.timestamp ?? null,
    saleCreatedAt: saleData?.createdAt ?? null,
  };
}

// Track all sales collection changes in ledger collection.
// A new ledger doc is created for every create/update/delete event on sales/{saleId}.
exports.syncSalesToLedger = onDocumentWritten('sales/{saleId}', async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const saleId = event.params.saleId;

  let eventType = 'updated';
  if (!before && after) eventType = 'created';
  if (before && !after) eventType = 'deleted';

  const current = after || before;
  if (!current) return null;

  try {
    const db = admin.firestore();
    const payload = buildSaleLedgerPayload(current, saleId);

    const changeSummary = {};
    if (before && after) {
      const beforeTotal = resolveSaleAmount(before);
      const afterTotal = resolveSaleAmount(after);
      const beforePaid = resolveSaleAmountPaid(before);
      const afterPaid = resolveSaleAmountPaid(after);
      const beforeStatus = resolveSalePaymentStatus(before);
      const afterStatus = resolveSalePaymentStatus(after);

      changeSummary.totalAmountDelta = afterTotal - beforeTotal;
      changeSummary.amountPaidDelta = afterPaid - beforePaid;
      changeSummary.paymentStatusChanged = beforeStatus !== afterStatus;
      changeSummary.stockCheckStatusChanged =
        resolveSaleStockCheckStatus(before) !== resolveSaleStockCheckStatus(after);
    }

    await db.collection('ledger').add({
      ...payload,
      eventType,
      action: `sales_${eventType}`,
      changedBy: current?.approvedby || current?.createdBy || current?.createdby || null,
      eventAt: admin.firestore.FieldValue.serverTimestamp(),
      changeSummary,
    });

    logger.info('syncSalesToLedger: ledger record created', {
      saleId,
      eventType,
      companyId: payload.companyId,
      branchId: payload.branchId,
    });
    return null;
  } catch (error) {
    logger.error('syncSalesToLedger error', {saleId, eventType, error});
    return null;
  }
});

// API Endpoint: Send SMS via POST request
exports.sendSmsApi = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({
      success: false,
      message: "Only POST requests are allowed",
    });
  }

  try {
    const {phone, message, senderid, companyId} = req.body;

    if (!phone) {
      return res.status(400).json({success: false, message: "Missing required field: phone"});
    }
    if (!message) {
      return res.status(400).json({success: false, message: "Missing required field: message"});
    }
    const formattedPhone = phone.startsWith("+") ? phone : `+233${phone.substring(1)}`;
    logger.info(`Sending SMS to ${formattedPhone} from ${senderid || 'configured sender'}`, {phone, senderid, companyId});

    const smsResponse = await sendSMS(message, formattedPhone, senderid, companyId);
    logger.info("SMS sent successfully", smsResponse);

    return res.status(200).json({
      success: true,
      message: "SMS sent successfully",
      response: smsResponse,
      phone: formattedPhone,
      senderid,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error("Error sending SMS:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to send SMS",
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// - limit: max number of docs to return (default 100, max 500)
exports.fetchSalesCollection = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "GET") {
    return res.status(405).json({
      success: false,
      message: "Only GET requests are allowed",
    });
  }

  try {
    const db = admin.firestore();
    const companyId = (req.query.companyId ?? "").toString().trim();
    const branchId = (req.query.branchId ?? "").toString().trim();
    const requestedLimit = parseInt((req.query.limit ?? "100").toString(), 10);
    const pageLimit = Number.isFinite(requestedLimit)
      ? Math.min(Math.max(requestedLimit, 1), 500)
      : 100;

    let query = db.collection("sales");

    if (companyId) {
      // Supports common naming variants for compatibility across existing docs.
      query = query.where("companyId", "==", companyId);
    }

    if (branchId) {
      query = query.where("branchId", "==", branchId);
    }

    const snapshot = await query.limit(pageLimit).get();
    const sales = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return res.status(200).json({
      success: true,
      count: sales.length,
      filters: {
        companyId: companyId || null,
        branchId: branchId || null,
        limit: pageLimit,
      },
      sales,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error("fetchSalesCollection error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch sales collection",
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

exports.generateProfitAndLossReport = onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const companyId = (req.query.companyId || req.body?.companyId || '').toString().trim();
    const branchId = (req.query.branchId || req.body?.branchId || '').toString().trim();
    const startDate = (req.query.startDate || req.body?.startDate || '').toString().trim();
    const endDate = (req.query.endDate || req.body?.endDate || '').toString().trim();

    if (!companyId) {
      return res.status(400).json({ error: 'companyId is required' });
    }

    let query = db.collection('ledgers').where('companyId', '==', companyId);
    if (branchId) query = query.where('branchId', '==', branchId);
    if (startDate) query = query.where('date', '>=', startDate);
    if (endDate) query = query.where('date', '<=', endDate);

    const snapshot = await query.orderBy('date', 'asc').get();
    const entries = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

    return res.status(200).json(buildProfitAndLossReport(entries, {
      companyId,
      branchId,
      startDate: startDate || null,
      endDate: endDate || null,
    }));
  } catch (error) {
    logger.error('generateProfitAndLossReport error', error);
    return res.status(500).json({ error: 'Failed to generate P&L report', details: error.message });
  }
});

// Track collection changes: update per-collection summary on create and update
// Only monitor specific collections for now
const MONITORED_COLLECTIONS = ['itemreg','stock','sales','transfer','request'];

exports.recordCollectionAdd = onDocumentCreated('{collectionId}/{docId}', async (event) => {
  try {
    const { collectionId, docId } = event.params;

    // limit to monitored collections
    if (!MONITORED_COLLECTIONS.includes(collectionId)) return null;

    const db = admin.firestore();
    const docRef = db.collection('collection_updates').doc(collectionId);

    // create a unique update id for this change
    const lastUpdateId = `${collectionId}_${docId}_${Date.now()}`;
    await docRef.set({
      collectionName: collectionId,
      lastAdded: admin.firestore.FieldValue.serverTimestamp(),
      lastDocId: docId,
      lastUpdateId,
      addedCount: admin.firestore.FieldValue.increment(1),
    }, { merge: true });

    logger.info(`Recorded add for collection ${collectionId} doc ${docId}`);
    return null;
  } catch (err) {
    logger.error('recordCollectionAdd error:', err);
    return null;
  }
});

exports.recordCollectionUpdate = onDocumentWritten('{collectionId}/{docId}', async (event) => {
  try {
    const { collectionId, docId } = event.params;
    // limit to monitored collections
    if (!MONITORED_COLLECTIONS.includes(collectionId)) return null;
    // Only treat this as an update if the document existed before
    const before = event.data?.before;
    const after = event.data?.after;
    // If no before snapshot, it's a create (handled by recordCollectionAdd)
    if (!before || !after) return null;
    const db = admin.firestore();
    const docRef = db.collection('collection_updates').doc(collectionId);
    // create a unique update id for this change
    const lastUpdateId = `${collectionId}_${docId}_${Date.now()}`;
    await docRef.set({
      collectionName: collectionId,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      lastDocId: docId,
      lastUpdateId,
      updatedCount: admin.firestore.FieldValue.increment(1),
    }, { merge: true });

    logger.info(`Recorded update for collection ${collectionId} doc ${docId}`);
    return null;
  } catch (err) {
    logger.error('recordCollectionUpdate error:', err);
    return null;
  }
});


// Update itemsreg openingstock when stock_transactions items map changes
// Also updates dashboard_stats with stock value totals
exports.syncStockTransactionsToItemsreg = onDocumentWritten("stock_transactions/{transactionId}", async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const transactionId = event.params.transactionId;

  try {
    const db = admin.firestore();
    const batch = db.batch();
    const updates = [];
    const toNumber = (value) => {
      const parsed = parseFloat(value);
      return Number.isFinite(parsed) ? parsed : 0;
    };
    const getBoxQtyFromDoc = (docData) => {
      const direct = toNumber(docData?.boxqty ?? docData?.boxQty ?? 0);
      if (direct > 0) return direct;
      const cartonQty = toNumber(docData?.modes?.carton?.qty ?? 0);
      return cartonQty;
    };

    const normalizeItems = (itemsData) => {
      if (!itemsData || typeof itemsData !== 'object') return {};
      
      // If items is an array, convert to object keyed by itemid
      if (Array.isArray(itemsData)) {
        const normalized = {};
        itemsData.forEach((itemData) => {
          if (itemData && typeof itemData === 'object') {
            const itemId = itemData.itemid || itemData.itemId;
            if (itemId) {
              normalized[itemId] = itemData;
            }
          }
        });
        return normalized;
      }
      
      // If already an object, verify all entries have itemid as key
      // If not, re-key them by itemid
      const normalized = {};
      Object.entries(itemsData).forEach(([key, itemData]) => {
        if (itemData && typeof itemData === 'object') {
          const itemId = itemData.itemid || itemData.itemId;
          if (itemId) {
            normalized[itemId] = itemData;
          }
        }
      });
      return normalized;
    };

    const itemIds = new Set();
    const transactionRef = db.collection('stock_transactions').doc(transactionId);

    const markTransactionSyncStatus = async (status, errorMessage = null) => {
      const transactionDoc = await transactionRef.get();
      if (!transactionDoc.exists) {
        return;
      }

      const payload = {
        syncstatus: status,
        syncstatuus: status,
        lastSyncAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (status === true) {
        payload.lastSyncedAt = admin.firestore.FieldValue.serverTimestamp();
      } else {
        payload.lastSyncError = errorMessage || 'pending';
      }

      await transactionRef.set(payload, { merge: true });
    };

    const dropSyncMetadata = (doc) => {
      if (!doc || typeof doc !== 'object') return doc;
      const cleaned = { ...doc };
      delete cleaned.syncstatus;
      delete cleaned.syncstatuus;
      delete cleaned.lastSyncedAt;
      delete cleaned.lastSyncAttemptAt;
      delete cleaned.lastSyncError;
      return cleaned;
    };

    const isOnlySyncMetadataChange = before && after &&
      JSON.stringify(dropSyncMetadata(before)) === JSON.stringify(dropSyncMetadata(after));

    if (isOnlySyncMetadataChange) {
      logger.debug(`Skipping stock transaction ${transactionId} because only sync metadata changed.`);
      return null;
    }

    // Get companyId for dashboard stats
    const companyId = (after?.companyId || after?.companyid || before?.companyId || before?.companyid);

    // Case 1: Document deleted - reverse all stock additions
    if (before && !after) {
      logger.info(`Stock transaction ${transactionId} deleted, reversing stock changes`);
      
      const items = normalizeItems(before.items);
      const branchId = before.branchId || before.branchid || before.branch_id;
      const branchName = before.branchName || before.branchname || before.branch_name || branchId;
      const updatedBy = before.createdby || before.createdBy || before.updatedBy || before.updatedby || 'system';

      if (!branchId) {
        logger.error(`No branch/warehouse ID found in deleted transaction ${transactionId}`);
        await markTransactionSyncStatus('pending', 'Missing branch/warehouse ID');
        return null;
      }

      for (const [itemId, itemData] of Object.entries(items)) {
        if (!itemData || typeof itemData !== 'object') continue;
        if (!itemId) continue;
        const quantity = parseFloat(itemData.quantity || 0) || 0;
        const stockinPieces = parseFloat(itemData.stockin_pieces || itemData.stockinPieces || itemData.pieces || 0) || 0;

        itemIds.add(itemId);
      }

      const itemRefs = Array.from(itemIds).map((id) => db.collection('itemsreg').doc(id));
      const itemDocs = itemRefs.length > 0 ? await db.getAll(...itemRefs) : [];
      const itemDocMap = new Map(itemDocs.map((doc) => [doc.id, doc.data() || {}]));

      let totalStockValue = 0;
      const today = before.date;
      const salesSummarydocId = `${companyId}_${today}`;
      const dailyRef = db.collection('stockreport').doc(salesSummarydocId);
      const stockReportBranchTotals = {
        branchId,
        branchName,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        summarydate: today,
        summaryid: salesSummarydocId,
        branch_newstock: 0,
        branch_newstockvalue: 0,
        branchstockin_balance: 0,
        branchstockin_value: 0,
        branchtransaction_count: 0,
        updatedby: updatedBy,
      };
      const stockReportItems = {};

      for (const [itemId, itemData] of Object.entries(items)) {
        if (!itemData || typeof itemData !== 'object') continue;
        if (!itemId) continue;
        const quantity = parseFloat(itemData.quantity || 0) || 0;
        const stockinPieces = parseFloat(itemData.stockin_pieces || itemData.stockinPieces || itemData.pieces || 0) || 0;

        const itemRegRef = db.collection('itemsreg').doc(itemId);
        const itemDocData = itemDocMap.get(itemId) || {};
        const boxQty = getBoxQtyFromDoc(itemDocData);
                const netQtyDelta = boxQty > 0 ? (stockinPieces / boxQty) : quantity;

//        const boxQty = toNumber(
//          itemData.boxpieces ||
//          itemDocData.boxpieces ||
//          1
//        );
//
//        const netQtyDelta = boxQty > 0
//            ? stockinPieces / boxQty
//            : quantity;

        // Calculate stock value using cost price
        //const costPrice = toNumber(itemDocData.cp || itemData.cp || 0);
        // Fall back to cp only for legacy transactions.
        const costPrice = toNumber(itemData.price ?? itemData.costprice ?? itemData.cp ?? itemDocData.cp ?? 0

        );

        const stockValue = costPrice * stockinPieces;
        totalStockValue += stockValue;

        stockReportBranchTotals.branch_newstock -= stockinPieces;
        stockReportBranchTotals.branch_newstockvalue -= stockValue;
        stockReportBranchTotals.branchstockin_balance -= stockinPieces;
        stockReportBranchTotals.branchstockin_value -= stockValue;
        stockReportBranchTotals.branchtransaction_count += 1;

        const itemReportEntry = stockReportItems[itemId] || {
          itemId,
          lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          newstock: 0,
          newstock_value: 0,
          stockin_balance: 0,
          cartonqty_in: 0,
          stockin_value: 0,
          transaction_count: 0,
        };
        itemReportEntry.newstock -= stockinPieces;
        itemReportEntry.newstock_value -= stockValue;
        itemReportEntry.stockin_balance -= stockinPieces;
        itemReportEntry.cartonqty_in -= netQtyDelta;
        itemReportEntry.stockin_value -= stockValue;
        itemReportEntry.transaction_count += 1;
        stockReportItems[itemId] = itemReportEntry;

        batch.set(
          itemRegRef,
          {
            branchbalance: {
              [branchId]: {
                quantity: admin.firestore.FieldValue.increment(-quantity),
                stockin_pieces: admin.firestore.FieldValue.increment(-stockinPieces),
                netpieces: admin.firestore.FieldValue.increment(-stockinPieces),
                stock_value: admin.firestore.FieldValue.increment(-stockValue),
                name: branchName,
                lastupdate: admin.firestore.FieldValue.serverTimestamp(),
                updatedby: updatedBy,
              },
            },
            lastModified: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        logger.info(`Reversing stock for item ${itemId} in branch ${branchName} (${branchId}): -${quantity} qty, -${stockinPieces} pcs, -GHS ${stockValue.toFixed(2)}`);
      }

      batch.set(
        dailyRef,
        {
          summarydate: today,
          summaryid: salesSummarydocId,
          companyid: companyId,
          branchbalance: {
            [branchId]: {
              ...stockReportBranchTotals,
              branch_newstock: admin.firestore.FieldValue.increment(stockReportBranchTotals.branch_newstock),
              branch_newstockvalue: admin.firestore.FieldValue.increment(stockReportBranchTotals.branch_newstockvalue),
              branchstockin_balance: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchstockin_balance),
              branchstockin_value: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchstockin_value),
              branchtransaction_count: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchtransaction_count),
            },
          },
          items: {
            [branchId]: Object.fromEntries(
              Object.entries(stockReportItems).map(([itemId, entry]) => [
                itemId,
                {
                  ...entry,
                  newstock: admin.firestore.FieldValue.increment(entry.newstock),
                  newstock_value: admin.firestore.FieldValue.increment(entry.newstock_value),
                  stockin_balance: admin.firestore.FieldValue.increment(entry.stockin_balance),
                  cartonqty_in: admin.firestore.FieldValue.increment(entry.cartonqty_in),
                  stockin_value: admin.firestore.FieldValue.increment(entry.stockin_value),
                  transaction_count: admin.firestore.FieldValue.increment(entry.transaction_count),
                },
              ])
            ),
          },
        },
        { merge: true }
      );
// Reverse supplier credit if purchase type was Credit
const purchaseType = (before.purchasetype || '').toString().trim().toLowerCase();

if (purchaseType === 'credit' && before.supplierid) {
  const supplierRef = db.collection('suppliers').doc(before.supplierid);

  const creditAmount = toNumber(before.netval || before.gross || 0);

  if (totalStockValue > 0) {
    batch.set(
      supplierRef,
      {
        creditaccount: admin.firestore.FieldValue.increment(-totalStockValue),
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info(
      `Reversed supplier credit for ${before.supplierid}: -GHS ${totalStockValue.toFixed(2)}`
    );
  }
}
      // Update dashboard_stats with reversed stock value
    if (companyId) {
      const statsRef = db.collection("dashbaord_stats").doc(companyId);

      batch.set(
        statsRef,
        {
          companyId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),

          ...(totalStockValue !== 0 && {
            stock_in_total: admin.firestore.FieldValue.increment(-totalStockValue),
          }),

          branchstock: {
            [branchId]: {
              ...(totalStockValue !== 0 && {
                stock_value: admin.firestore.FieldValue.increment(-totalStockValue),
              }),
              branchname: branchName,
            },
          },
        },
        { merge: true }
      );
    }

    await batch.commit();

    logger.info(
      `Reversed stock transaction ${transactionId}. ` +
      `Total stock value: -GHS ${totalStockValue.toFixed(2)}`
    );

    return null;
    }

    // Case 2: Document created or updated
    if (after) {
      const beforeItems = normalizeItems(before?.items);
      const afterItems = normalizeItems(after.items);
      const branchId = after.branchId || after.branchid || after.branch_id;
      const branchName = after.branchName || after.branchname || after.branch_name || branchId;
      const updatedBy = after.createdby || after.createdBy || after.updatedBy || after.updatedby || 'system';

      if (!branchId) {
        logger.error(`No branch/warehouse ID found in transaction ${transactionId}`);
        await markTransactionSyncStatus(false, 'Missing branch/warehouse ID');
        return null;
      }

      // Get all item keys from both before and after
      const allItemKeys = new Set([...Object.keys(beforeItems), ...Object.keys(afterItems)]);

      for (const itemId of allItemKeys) {
        const beforeItemData = beforeItems[itemId] || {};
        const afterItemData = afterItems[itemId] || {};
        if (!itemId) continue;
        itemIds.add(itemId);
      }

      const itemRefs = Array.from(itemIds).map((id) => db.collection('itemsreg').doc(id));
      const itemDocs = itemRefs.length > 0 ? await db.getAll(...itemRefs) : [];
      const itemDocMap = new Map(itemDocs.map((doc) => [doc.id, doc.data() || {}]));

      let totalStockValue = 0;
      const today = after.date;
      const salesSummarydocId = `${companyId}_${today}`;
      const dailyRef = db.collection('stockreport').doc(salesSummarydocId);
      const stockReportBranchTotals = {

        branchId,
        branchName,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        summarydate: today,
        summaryid: salesSummarydocId,
        branch_newstock: 0,
        branch_newstockvalue: 0,
        branchstockin_balance: 0,
        branchstockin_value: 0,
        branchtransaction_count: 0,
        updatedby: updatedBy,
      };
      const stockReportItems = {};
      stockReportBranchTotals.branchtransaction_count += 1;
      for (const itemId of allItemKeys) {
        const beforeItemData = beforeItems[itemId] || {};
        const afterItemData = afterItems[itemId] || {};
        if (!itemId) continue;
       
        // Calculate before and after quantities and pieces
        const beforeQty = parseFloat(beforeItemData.quantity || 0) || 0;
        const beforePieces = parseFloat(beforeItemData.stockin_pieces || beforeItemData.stockinPieces || beforeItemData.pieces || 0) || 0;

        const afterQty = parseFloat(afterItemData.quantity || 0) || 0;
        const afterPieces = parseFloat(afterItemData.stockin_pieces || afterItemData.stockinPieces || afterItemData.pieces || 0) || 0;

        // Calculate the differences
        const qtyDifference = afterQty - beforeQty;
        const piecesDifference = afterPieces - beforePieces;
        
        // Handle completely deleted items: if beforeData exists but afterData doesn't, reverse it
        const isItemDeleted = Object.keys(beforeItemData).length > 0 && Object.keys(afterItemData).length === 0;
        const actualQtyDiff = isItemDeleted ? -beforeQty : qtyDifference;
        const actualPiecesDiff = isItemDeleted ? -beforePieces : piecesDifference;
        
        if (actualQtyDiff === 0 && actualPiecesDiff === 0) continue; // No change

        // Get item document data for cost price and box info
        const itemDocData = itemDocMap.get(itemId) || {};

        // Calculate stock value using cost price
        //const costPrice = toNumber(itemDocData.cp || afterItemData.cp || beforeItemData.cp || 0);
        const costPrice = toNumber(afterItemData.price || beforeItemData.price || 0);
        const stockValueChange = costPrice * actualPiecesDiff;
        totalStockValue += stockValueChange;
        const pieces_in_Box = toNumber(afterItemData.boxpieces || itemDocData.boxpieces || 1);
        const boxBalance = pieces_in_Box > 0 ? (actualPiecesDiff / pieces_in_Box) : 0;

        stockReportBranchTotals.branch_newstock += actualPiecesDiff;
        stockReportBranchTotals.branch_newstockvalue += stockValueChange;
        stockReportBranchTotals.branchstockin_balance += actualPiecesDiff;
        stockReportBranchTotals.branchstockin_value += stockValueChange;


        const itemReportEntry = stockReportItems[itemId] || {
          item: afterItemData.item || beforeItemData.item,
          itemId,
          barcode: afterItemData.barcode || beforeItemData.barcode,
          lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          newstock: 0,
          newstock_value: 0,
          stockin_balance: 0,
          stockin_value: 0,
          boxpieces: pieces_in_Box,
          cartonqty_in: 0,
          transaction_count: 0,
        };
        itemReportEntry.newstock += actualPiecesDiff;
        itemReportEntry.newstock_value += stockValueChange;
        itemReportEntry.stockin_balance += actualPiecesDiff;
        itemReportEntry.stockin_value += stockValueChange;
        itemReportEntry.cartonqty_in += boxBalance;
        itemReportEntry.transaction_count += 1;
        stockReportItems[itemId] = itemReportEntry;

       // Use itemid as the document key in itemsreg - NO READ, just update with increment
        const itemRegRef = db.collection('itemsreg').doc(itemId);
     
        batch.set(
          itemRegRef,
          {
            branchbalance: {
              [branchId]: {
                quantity: admin.firestore.FieldValue.increment(actualQtyDiff),
                stockin_pieces: admin.firestore.FieldValue.increment(actualPiecesDiff),
                netpieces: admin.firestore.FieldValue.increment(actualPiecesDiff),
                stock_value: admin.firestore.FieldValue.increment(stockValueChange),
                name: branchName,
                lastupdate: admin.firestore.FieldValue.serverTimestamp(),
                updatedby: updatedBy,
              },
            },
            lastModified: admin.firestore.FieldValue.serverTimestamp(),
            lastStockTransactionId: transactionId,
          },
          { merge: true }
        );

        updates.push({
          itemId,
          branchId,
          branchName,
          itemName: afterItemData.item || beforeItemData.item || '',
          qtyChange: actualQtyDiff,
          piecesChange: actualPiecesDiff,
          stockValueChange,
        });


        logger.info(
          `Updated item ${itemId} in branch ${branchName} (${branchId}): ` +
          `${actualQtyDiff > 0 ? '+' : ''}${actualQtyDiff} qty, ${actualPiecesDiff > 0 ? '+' : ''}${actualPiecesDiff} pcs, ` +
          `${stockValueChange > 0 ? '+' : ''}GHS ${stockValueChange.toFixed(2)}`
        );
      }
// increase supplier credit if purchase type was Credit
const purchaseType = (after.purchasetype || '').toString().trim().toLowerCase();

if (purchaseType === 'credit' && after.supplierid) {
  const supplierRef = db.collection('suppliers').doc(after.supplierid);

  if (totalStockValue > 0) {
    batch.set(
      supplierRef,
      {
        creditaccount: admin.firestore.FieldValue.increment(totalStockValue),
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    logger.info(
      `Increased supplier credit for ${after.supplierid}: GHS ${totalStockValue.toFixed(2)}`
    );
  }
}
      if (updates.length > 0) {
        batch.set(
          dailyRef,
          {
            summarydate: today,
            summaryid: salesSummarydocId,
            companyid: companyId,
            lastupdate: admin.firestore.FieldValue.serverTimestamp(),
            companytransaction_count: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchtransaction_count),

            branchbalance: {
              [branchId]: {
                ...stockReportBranchTotals,
                branch_newstock: admin.firestore.FieldValue.increment(stockReportBranchTotals.branch_newstock),
                branch_newstockvalue: admin.firestore.FieldValue.increment(stockReportBranchTotals.branch_newstockvalue),
                branchstockin_balance: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchstockin_balance),
                branchstockin_value: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchstockin_value),
                branchtransaction_count: admin.firestore.FieldValue.increment(stockReportBranchTotals.branchtransaction_count),
              },
            },
            items: {
              [branchId]: Object.fromEntries(
                Object.entries(stockReportItems).map(([itemId, entry]) => [
                  itemId,
                  {
                    ...entry,
                    newstock: admin.firestore.FieldValue.increment(entry.newstock),
                    newstock_value: admin.firestore.FieldValue.increment(entry.newstock_value),
                    stockin_balance: admin.firestore.FieldValue.increment(entry.stockin_balance),
                    stockin_value: admin.firestore.FieldValue.increment(entry.stockin_value),
                    cartonqty_in: admin.firestore.FieldValue.increment(entry.cartonqty_in),
                    transaction_count: admin.firestore.FieldValue.increment(entry.transaction_count),
                  },
                ])
              ),
            },
          },
          { merge: true }
        );
        batch.set(
          transactionRef,
          {
            syncstatus: true,
            syncstatuus: true,
            lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSyncAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Update dashboard_stats with stock value totals
       if (companyId && totalStockValue !== 0) {
         const statsRef = db.collection("dashbaord_stats").doc(companyId);

         batch.set(
           statsRef,
           {
             companyId,
             updatedAt: admin.firestore.FieldValue.serverTimestamp(),
             stock_in_total: admin.firestore.FieldValue.increment(totalStockValue),

             branchstock: {
               [branchId]: {
                 stock_value: admin.firestore.FieldValue.increment(totalStockValue),
                 branchname: branchName,
               },
             },
           },
           { merge: true }
         );

       }
       await batch.commit();
          logger.info(`Processed stock transaction ${transactionId}. Updated ${updates.length} items.`);

      } else {
        await markTransactionSyncStatus(true);
      }
    }

    return null;
  } catch (error) {
    logger.error(`Error syncing stock transaction ${transactionId}:`, error);
    await markTransactionSyncStatus(false, error.message || 'Sync failed');

    return null;
  }
});


// Update itemsreg branchbalance when stock_transfer items change
exports.syncStockTransferToItemsreg = onDocumentWritten("stock_transfer/{transferId}", async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const transferId = event.params.transferId;

  const toNumber = (value) => {
    const parsed = parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  };

  const resolveTransferBranchId = (docData, type) => {
    if (!docData) return null;
    if (type === 'receive') {
      return (
        docData.recievebranchid ||
        docData.receivebranchid ||
        docData.recieveBranchId ||
        docData.receiveBranchId ||
        docData.branchId ||
        null
      );
    }

    return (
      docData.supplywarehouseid ||
      docData.supplyWarehouseId ||
      docData.supplybranchid ||
      docData.supplyBranchId ||
      null
    );
  };

  const resolveTransferBranchName = (docData, type, fallbackId) => {
    if (!docData) return fallbackId;
    if (type === 'receive') {
      return (
        docData.recievebranchname ||
        docData.receivebranchname ||
        docData.recieveBranchName ||
        docData.receiveBranchName ||
        fallbackId
      );
    }

    return (
      docData.supplywarehousename ||
      docData.supplyWarehouseName ||
      docData.supplybranchname ||
      docData.supplyBranchName ||
      fallbackId
    );
  };

  const getUpdatedBy = (docData) => (
    docData?.updatedby ||
    docData?.updatedBy ||
    docData?.createdby ||
    docData?.createdBy ||
    'system'
  );

  const normalizeTransferItems = (docData) => {
    if (!docData) return {};

    const rawItems = docData.items;
    const normalized = {};

    if (Array.isArray(rawItems)) {
      rawItems.forEach((itemData, index) => {
        if (!itemData || typeof itemData !== 'object') return;

        const itemId =
          itemData.itemid ||
          itemData.itemId ||
          itemData.item_id ||
          itemData.id ||
          `${index}`;

        if (!itemId) return;

        const quantity = toNumber(itemData.quantity ?? itemData.qty ?? 0);
        const pieces = toNumber(itemData.pieces ?? itemData.transferpieces ?? itemData.totalpieces ?? 0);
        const receivedquantity = toNumber(itemData.receivedquantity ?? itemData.receivedQuantity ?? 0);
        const receivedpieces = toNumber(itemData.receivedpieces ?? itemData.receivedPieces ?? 0);
        const itemName = itemData.item ?? itemData.itemName ?? '';
        const itemBarcode = itemData.barcode ?? '';
        const boxpieces = toNumber(itemData.boxpieces ?? itemData.boxPieces ?? 1);

        const current = normalized[itemId] || {
          itemId,
          quantity: 0,
          pieces: 0,
          receivedquantity: 0,
          receivedpieces: 0,
          itemName,
          itemBarcode,
          boxpieces,
        };

        current.quantity += quantity;
        current.pieces += pieces;
        current.receivedquantity += receivedquantity;
        current.receivedpieces += receivedpieces;
        normalized[itemId] = current;
      });

      return normalized;
    }

    if (rawItems && typeof rawItems === 'object') {
      Object.entries(rawItems).forEach(([itemKey, itemData]) => {
        if (!itemData || typeof itemData !== 'object') return;

        const itemId =
          itemData.itemid ||
          itemData.itemId ||
          itemData.item_id ||
          itemData.id ||
          itemKey;

        if (!itemId) return;

        const quantity = toNumber(itemData.quantity ?? itemData.qty ?? 0);
        const pieces = toNumber(itemData.pieces ?? itemData.transferpieces ?? itemData.totalpieces ?? 0);
        const receivedquantity = toNumber(itemData.receivedquantity ?? itemData.receivedQuantity ?? 0);
        const receivedpieces = toNumber(itemData.receivedpieces ?? itemData.receivedPieces ?? 0);
        const itemName = itemData.item ?? itemData.itemName ?? '';
        const itemBarcode = itemData.barcode ?? '';
        const boxpieces = toNumber(itemData.boxpieces ?? itemData.boxPieces ?? 1);

        const current = normalized[itemId] || {
          itemId,
          quantity: 0,
          pieces: 0,
          receivedquantity: 0,
          receivedpieces: 0,
          itemName,
          itemBarcode,
          boxpieces,
        };

        current.quantity += quantity;
        current.pieces += pieces;
        current.receivedquantity += receivedquantity;
        current.receivedpieces += receivedpieces;
        normalized[itemId] = current;
      });
    }

    return normalized;
  };

  try {
    const db = admin.firestore();
    const transferRef = db.collection('stock_transfer').doc(transferId);
    const batchWrites = [];
    const batchLimit = 450;
    const companyId = after?.companyid || after?.companyId || before?.companyid || before?.companyId || null;
    const branchValueChanges = new Map();

    const markTransferSyncStatus = async (status, errorMessage = null) => {
      const transferDoc = await transferRef.get();
      if (!transferDoc.exists) {
        return;
      }

      const payload = {
        syncstatus: status,
        syncstatuus: status,
        lastSyncAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (status === true) {
        payload.lastSyncedAt = admin.firestore.FieldValue.serverTimestamp();
      } else {
        payload.lastSyncError = errorMessage || 'pending';
      }

      await transferRef.set(payload, { merge: true });
    };

    const dropSyncMetadata = (doc) => {
      if (!doc || typeof doc !== 'object') return doc;
      const cleaned = { ...doc };
      delete cleaned.syncstatus;
      delete cleaned.syncstatuus;
      delete cleaned.lastSyncedAt;
      delete cleaned.lastSyncAttemptAt;
      delete cleaned.lastSyncError;
      return cleaned;
    };

    const isOnlySyncMetadataChange = before && after &&
      JSON.stringify(dropSyncMetadata(before)) === JSON.stringify(dropSyncMetadata(after));

    if (isOnlySyncMetadataChange) {
      logger.debug(`Skipping stock transfer ${transferId} because only sync metadata changed.`);
      return null;
    }

    const addBranchValueChange = (branchId, branchName, valueDelta) => {
      if (!branchId || valueDelta === 0) return;
      const current = branchValueChanges.get(branchId) || { value: 0, name: branchName || '' };
      current.value += valueDelta;
      if (branchName) current.name = branchName;
      branchValueChanges.set(branchId, current);
    };

    const flushBatchWrites = async () => {
      if (batchWrites.length === 0) return;

      for (let index = 0; index < batchWrites.length; index += batchLimit) {
        const chunk = batchWrites.slice(index, index + batchLimit);
        const chunkBatch = db.batch();
        chunk.forEach(({ ref, data, options }) => {
          chunkBatch.set(ref, data, options || { merge: true });
        });
        await chunkBatch.commit();
      }
    };

    const sourceBeforeId = resolveTransferBranchId(before, 'source');
    const sourceAfterId = resolveTransferBranchId(after, 'source');
    const receiveBeforeId = resolveTransferBranchId(before, 'receive');
    const receiveAfterId = resolveTransferBranchId(after, 'receive');

    const sourceBranchId = sourceAfterId || sourceBeforeId;
    const receiveBranchId = receiveAfterId || receiveBeforeId;

    if (!sourceBranchId || !receiveBranchId) {
      logger.warn(`Transfer ${transferId} missing source/receive branch IDs`, {
        sourceBranchId,
        receiveBranchId,
      });
      return null;
    }

    const sourceBranchName = resolveTransferBranchName(after || before, 'source', sourceBranchId);
    const receiveBranchName = resolveTransferBranchName(after || before, 'receive', receiveBranchId);
    const updatedBy = getUpdatedBy(after || before);

    const beforeItems = normalizeTransferItems(before);
    const afterItems = normalizeTransferItems(after);
    const allItemIds = new Set([...Object.keys(beforeItems), ...Object.keys(afterItems)]);

    if (allItemIds.size === 0) {
      await markTransferSyncStatus(true);
      return null;
    }

    const itemRefs = Array.from(allItemIds).map((id) => db.collection('itemsreg').doc(id));
    const itemDocs = itemRefs.length > 0 ? await db.getAll(...itemRefs) : [];
    const itemDocMap = new Map(itemDocs.map((doc) => [doc.id, doc.data() || {}]));

    let hasUpdates = false;
    const today = after?.date || before?.date;
    const salesSummarydocId = `${companyId}_${today}`;
    const dailyRef = db.collection('stockreport').doc(salesSummarydocId);
    const stockReportSnapshot = await dailyRef.get();
    const stockReportDoc = stockReportSnapshot.exists ? { ...stockReportSnapshot.data() } : {
      companyid: companyId,
      summarydate: today,
      summaryid: salesSummarydocId,
    };
    const stockReportBranchBalance = stockReportDoc.branchbalance || {};
    const stockReportItems = stockReportDoc.items || {};
    const statsRef = db.collection('dashbaord_stats').doc(companyId);

    for (const itemId of allItemIds) {
      const beforeItem = beforeItems[itemId] || { quantity: 0, pieces: 0, receivedquantity: 0, receivedpieces: 0 };
      const afterItem = afterItems[itemId] || { quantity: 0, pieces: 0, receivedquantity: 0, receivedpieces: 0 };
      const qtyDelta = toNumber(afterItem.quantity) - toNumber(beforeItem.quantity);
      const piecesDelta = toNumber(afterItem.pieces) - toNumber(beforeItem.pieces);
      const receivedQtyDelta = toNumber(afterItem.receivedquantity) - toNumber(beforeItem.receivedquantity);
      const receivedPiecesDelta = toNumber(afterItem.receivedpieces) - toNumber(beforeItem.receivedpieces);
      const boxpieces = toNumber(afterItem.boxpieces || beforeItem.boxpieces || 1);
      const cartonQty = boxpieces > 0 ? (piecesDelta / boxpieces) : 0;

      if (qtyDelta === 0 && piecesDelta === 0 && receivedQtyDelta === 0 && receivedPiecesDelta === 0) {
        continue;
      }

      const itemDocData = itemDocMap.get(itemId) || {};
      const costPrice = toNumber(
        itemDocData.cp ||
        itemDocData.costprice ||
        itemDocData.costPrice ||
        afterItem?.cp ||
        afterItem?.costprice ||
        afterItem?.costPrice ||
        beforeItem?.cp ||
        beforeItem?.costprice ||
        beforeItem?.costPrice ||
        0
      );
      const stockValueChange = costPrice * piecesDelta;

      addBranchValueChange(sourceBranchId, sourceBranchName, -stockValueChange);
      addBranchValueChange(receiveBranchId, receiveBranchName, stockValueChange);

      const itemRef = db.collection('itemsreg').doc(itemId);
      const itemData = afterItems[itemId] || beforeItems[itemId] || {};
      const itemName = itemData.itemName || itemData.item || 'missing name';
      const itemBarcode = itemData.itemBarcode || itemData.barcode || 'missing barcode';

      batchWrites.push({
        ref: itemRef,
        data: {
          branchbalance: {
            [receiveBranchId]: {
              quantity: admin.firestore.FieldValue.increment(qtyDelta),
              receivedquantity: admin.firestore.FieldValue.increment(qtyDelta),
              receivedpieces: admin.firestore.FieldValue.increment(piecesDelta),
              netpieces: admin.firestore.FieldValue.increment(piecesDelta),
              name: receiveBranchName,
              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
              updatedby: updatedBy,
            },
            [sourceBranchId]: {
              quantity: admin.firestore.FieldValue.increment(-qtyDelta),
              netpieces: admin.firestore.FieldValue.increment(-piecesDelta),
              name: sourceBranchName,
              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
              updatedby: updatedBy,
            },
          },
          lastModified: admin.firestore.FieldValue.serverTimestamp(),
          lastStockTransferId: transferId,
        },
        options: { merge: true },
      });

      const sourceSummary = stockReportBranchBalance[sourceBranchId] || {
        branchId: sourceBranchId,
        branchName: sourceBranchName,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        summarydate: today,
        summaryid: salesSummarydocId,
        branchtransfer_qty: 0,
        branchtransfer_value: 0,
        branchstockout_balance: 0,
        branchstockout_value: 0,
        branchtransaction_count: 0,
        updatedby: updatedBy,
      };
      const receiveSummary = stockReportBranchBalance[receiveBranchId] || {
        branchId: receiveBranchId,
        branchName: receiveBranchName,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        summarydate: today,
        summaryid: salesSummarydocId,
        branchstockin_balance: 0,
        branchtransferRecieved_qty: 0,
        branchstockin_value: 0,
        branchtransaction_count: 0,
        updatedby: updatedBy,
      };

      sourceSummary.branchtransfer_qty = toNumber(sourceSummary.branchtransfer_qty) + piecesDelta;
      sourceSummary.branchstockout_balance = toNumber(sourceSummary.branchstockout_balance) + piecesDelta;
      sourceSummary.branchtransaction_count = toNumber(sourceSummary.branchtransaction_count) + 1;
      sourceSummary.branchName = sourceBranchName;
      sourceSummary.updatedby = updatedBy;
      sourceSummary.lastupdate = admin.firestore.FieldValue.serverTimestamp();

      receiveSummary.branchstockin_balance = toNumber(receiveSummary.branchstockin_balance) + piecesDelta;
      receiveSummary.branchtransferRecieved_qty = toNumber(receiveSummary.branchtransferRecieved_qty) + piecesDelta;
      receiveSummary.branchtransaction_count = toNumber(receiveSummary.branchtransaction_count) + 1;
      receiveSummary.branchName = receiveBranchName;
      receiveSummary.updatedby = updatedBy;
      receiveSummary.lastupdate = admin.firestore.FieldValue.serverTimestamp();

      stockReportBranchBalance[sourceBranchId] = sourceSummary;
      stockReportBranchBalance[receiveBranchId] = receiveSummary;

      const sourceItemMap = stockReportItems[sourceBranchId] || {
        branchId: sourceBranchId,
        branchName: sourceBranchName,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        summarydate: today,
        summaryid: salesSummarydocId,
      };
      const receiveItemMap = stockReportItems[receiveBranchId] || {
        branchId: receiveBranchId,
        branchName: receiveBranchName,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        summarydate: today,
        summaryid: salesSummarydocId,
      };

      const sourceItem = sourceItemMap[itemId] || {
        itemId,
        item: itemName,
        barcode: itemBarcode,
        boxpieces,
        transfer_cartons: 0,
        transfer_qty: 0,
        transfer_value: 0,
        stockout_balance: 0,
        stockout_value: 0,
        transaction_count: 0,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
      };
      const receiveItem = receiveItemMap[itemId] || {
        itemId,
        item: itemName,
        barcode: itemBarcode,
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        transfer_value: 0,
        boxpieces,
        transfer_recieved_cartons: 0,
        stockin_balance: 0,
        transfer_recieved_qty: 0,
        stockin_value: 0,
        transaction_count: 0,
      };

      sourceItem.transfer_cartons = toNumber(sourceItem.transfer_cartons) + cartonQty;
      sourceItem.transfer_qty = toNumber(sourceItem.transfer_qty) + piecesDelta;
      sourceItem.stockout_balance = toNumber(sourceItem.stockout_balance) + piecesDelta;
      sourceItem.transaction_count = toNumber(sourceItem.transaction_count) + 1;
      sourceItem.lastupdate = admin.firestore.FieldValue.serverTimestamp();
      sourceItem.boxpieces = boxpieces;

      receiveItem.transfer_recieved_cartons = toNumber(receiveItem.transfer_recieved_cartons) + cartonQty;
      receiveItem.stockin_balance = toNumber(receiveItem.stockin_balance) + piecesDelta;
      receiveItem.transfer_recieved_qty = toNumber(receiveItem.transfer_recieved_qty) + piecesDelta;
      receiveItem.transaction_count = toNumber(receiveItem.transaction_count) + 1;
      receiveItem.lastupdate = admin.firestore.FieldValue.serverTimestamp();
      receiveItem.boxpieces = boxpieces;

      sourceItemMap[itemId] = sourceItem;
      receiveItemMap[itemId] = receiveItem;

      stockReportItems[sourceBranchId] = sourceItemMap;
      stockReportItems[receiveBranchId] = receiveItemMap;
      hasUpdates = true;
    }

    if (companyId && branchValueChanges.size > 0) {
      const dashboardUpdate = {
        companyId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        branchstock: {},
      };

      for (const [branchId, data] of branchValueChanges.entries()) {
        dashboardUpdate.branchstock[branchId] = {
          stock_value: admin.firestore.FieldValue.increment(data.value),
          branchname: data.name,
        };
      }

      batchWrites.push({
        ref: statsRef,
        data: dashboardUpdate,
        options: { merge: true },
      });
    }

    if (hasUpdates) {
      batchWrites.push({
        ref: dailyRef,
        data: {
          ...stockReportDoc,
          companyid: companyId,
          summarydate: today,
          summaryid: salesSummarydocId,
          lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          branchbalance: stockReportBranchBalance,
          items: stockReportItems,
        },
        options: { merge: false },
      });

      await flushBatchWrites();
      await markTransferSyncStatus(true);
      logger.info(`Processed stock transfer ${transferId} branchbalance sync.`);
    } else {
      await markTransferSyncStatus(true);
    }

    return null;
  } catch (error) {
    logger.error(`Error syncing stock transfer ${transferId} to itemsreg:`, error);
    await markTransferSyncStatus(false, error.message || 'Sync failed');
    return null;
  }
});

// Write stock_transfer to ledger using double-entry accounting.
exports.syncStockTransferToLedger = onDocumentWritten("stock_transfer/{transferId}", async (event) => {
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const transferId = event.params.transferId;
  const db = admin.firestore();

  try {
    const existing = await db.collection('ledgers')
      .where('sourceType', '==', 'stock_transfer')
      .where('sourceId', '==', transferId)
      .get();

    if (!existing.empty) {
      const deleteBatch = db.batch();
      existing.docs.forEach((doc) => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
      logger.info(`Existing stock transfer ledger entries removed for ${transferId}`);
    }

    if (!after) {
      logger.info(`Stock transfer ledger cleanup complete for deleted record ${transferId}`);
      return null;
    }

    await postStockTransferToLedger(after, transferId);
    logger.info(`Stock transfer ledger entries created for ${transferId}`);
    return null;
  } catch (error) {
    logger.error(`Error syncing stock transfer ledger for ${transferId}:`, error);
    return null;
  }
});

// Write journal entries to ledger using double-entry accounting
// Trigger: Create ledger entries when journal entries are created/updated
exports.syncJournalToLedger = onDocumentWritten("journal/{journalId}", async (event) => {
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const journalId = event.params.journalId;
  const db = admin.firestore();

  try {
    // Check if ledger entries already exist for this journal entry
    const existing = await db.collection('ledgers')
      .where('sourceType', '==', 'journal')
      .where('sourceId', '==', journalId)
      .get();

    // If updating, delete old entries first
    if (!existing.empty) {
      const deleteBatch = db.batch();
      existing.docs.forEach((doc) => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
      logger.info(`Existing journal ledger entries removed for ${journalId}`);
    }

    // If journal entry is deleted, cleanup is complete
    if (!after) {
      logger.info(`Journal ledger cleanup complete for deleted record ${journalId}`);
      return null;
    }

    // Post the journal entry to ledger using double-entry accounting
    await postJournalToLedger(after, journalId);
    logger.info(`Ledger entries (journal) created for ${journalId}`);
    return null;
  } catch (error) {
    logger.error(`Error syncing journal ledger for ${journalId}:`, error);
    return null;
  }
});

// Update itemsreg branchbalance stockout/net fields when sales items map changes
exports.syncSalesToItemsregStockout = onDocumentWritten("sales/{saleId}", async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const saleId = event.params.saleId;

  const toNumber = (value) => {const parsed = parseFloat(value);
return Number.isFinite(parsed) ? parsed : 0;
  };

  const getItemQuantity = (itemData) => (toNumber(itemData.quantity ?? itemData.qty ?? itemData.qnty ?? 0));

  const getItemPieces = (itemData) => ( toNumber(itemData.totalpieces ?? itemData.totalPieces ?? itemData.pieces ?? 0));

  const getItemdiscount = (itemData) => ( toNumber(itemData.discount ?? itemData.Discount ?? 0));

  const getItemModeQty = (itemData) => (toNumber(itemData.modeqty ?? itemData.modeQty ?? itemData.mode_qty ?? itemData.cartonqty ?? itemData.cartonQty ?? 0));
  const getBoxQtyFromDoc = (docData) => {
    const direct = toNumber(docData?.boxqty ?? docData?.boxQty ?? 0);
    if (direct > 0) return direct;
    const cartonQty = toNumber(docData?.modes?.carton?.qty ?? 0);
    const singleQty = toNumber(docData?.modes?.single?.qty ?? 0);
    return cartonQty > 0 ? cartonQty : (singleQty > 0 ? singleQty : 1);
};

  try {
    const db = admin.firestore();
    const batch = db.batch();
    let hasUpdates = false;
    const summaryDocStates = new Map();
    const stockReportDocStates = new Map();

    const MAX_TRANSFORM_BATCH_LIMIT = 450;

    const isFirestoreTransform = (value) => {
      if (!value || typeof value !== 'object') return false;
      const name = value.constructor && value.constructor.name;
      return name === 'NumericIncrementTransform' || name === 'ServerTimestampTransform';
    };

    const normalizeIncrementValue = (value) => {
      const numericValue = toNumber(value);
      return Number.isFinite(numericValue) ? numericValue : 0;
    };

    const estimateTransformCount = (value) => {
      if (Array.isArray(value)) {
        return value.reduce((total, entry) => total + estimateTransformCount(entry), 0);
      }

      if (value && typeof value === 'object') {
        if (isFirestoreTransform(value)) return 1;
        let total = 0;
        for (const child of Object.values(value)) {
          total += estimateTransformCount(child);
        }
        return total;
      }

      return 0;
    };

    const getOrCreateDocState = (docStates, key, ref, baseData) => {
      if (!docStates.has(key)) {
        docStates.set(key, { ref, data: { ...baseData } });
      }
      return docStates.get(key);
    };

    const ensureObject = (parent, key) => {
      if (!parent[key] || typeof parent[key] !== 'object' || Array.isArray(parent[key])) {
        parent[key] = {};
      }
      return parent[key];
    };

    const applyIncrement = (target, fieldName, amount) => {
      const safeAmount = normalizeIncrementValue(amount);
      const currentValue = target[fieldName];
      if (currentValue && isFirestoreTransform(currentValue)) {
        const currentOperand = normalizeIncrementValue(currentValue.operand);
        target[fieldName] = admin.firestore.FieldValue.increment(currentOperand + safeAmount);
      } else {
        target[fieldName] = admin.firestore.FieldValue.increment(safeAmount);
      }
    };

    const flushDocWriteStates = async (docStates, firestoreDb) => {
      const writes = [];
      for (const state of docStates.values()) {
        writes.push({
          type: 'set',
          ref: state.ref,
          data: state.data,
          options: { merge: true },
        });
      }

      if (writes.length === 0) return;

      let currentBatch = firestoreDb.batch();
      let currentTransformCount = 0;
      const currentWrites = [];

      const commitCurrentBatch = async () => {
        if (currentWrites.length === 0) return;
        for (const write of currentWrites) {
          if (write.type === 'set') {
            currentBatch.set(write.ref, write.data, write.options || { merge: true });
          }
        }
        await currentBatch.commit();
      };

      for (const write of writes) {
        const nextTransformCount = currentTransformCount + estimateTransformCount(write.data);
        if (currentWrites.length > 0 && nextTransformCount > MAX_TRANSFORM_BATCH_LIMIT) {
          await commitCurrentBatch();
          currentBatch = firestoreDb.batch();
          currentTransformCount = 0;
          currentWrites.length = 0;
        }

        currentWrites.push(write);
        currentTransformCount = nextTransformCount;
      }

      await commitCurrentBatch();
    };

    const resolveBranchId = (saleData, itemData) => (
      itemData.branchId || itemData.branchid || itemData.branch_id ||
      saleData.branchId || saleData.branchid || saleData.branch_id ||
      saleData.branch || saleData.warehouse
    );

    const resolveBranchName = (saleData, itemData, branchId) => (
      itemData.branchName || itemData.branchname || itemData.branch_name ||
      saleData.branchName || saleData.branchname || saleData.branch_name ||
      saleData.warehouseName || branchId
    );

    const resolveUpdatedBy = (saleData) => (
      saleData.updatedBy || saleData.updatedby || saleData.createdBy || saleData.createdby || "system"
    );

    const resolveItemId = (itemData, itemKey) => (
      itemData.itemid || itemData.itemId || itemData.item_id || itemData.id || itemData.productId || itemKey
    );

    // perItemStatus: Map<itemKey, 'approved' | 'rejected'>
    const buildItemStatusUpdates = (itemsSource, perItemStatus) => {
      if (Array.isArray(itemsSource)) {
        const nextItems = itemsSource.map((item) => (
          item && typeof item === 'object' ? {...item} : item
        ));

        for (const [key, status] of perItemStatus.entries()) {
          const index = Number(key);
          if (!Number.isInteger(index) || index < 0 || index >= nextItems.length) continue;
          if (!nextItems[index] || typeof nextItems[index] !== 'object') continue;
          nextItems[index].stockCheckStatus = status;
        }

        return ['items', nextItems];
      }

      const updates = [];
      for (const [key, status] of perItemStatus.entries()) {
        updates.push(
          new admin.firestore.FieldPath('items', key, 'stockCheckStatus'),
          status,
        );
      }
      return updates;
    };

    // Ignore only follow-up update events that add stockCheckStatus,
    // but do not skip initial create events.
    if (before && after?.stockCheckStatus && !before?.stockCheckStatus) {
      return null;
    }

    // Case 1: Document deleted - reverse all stockout changes
    if (before && !after) {
      if (before?.stockCheckStatus !== 'approved') return null;
      const items = before.items || {};
      const updatedBy = resolveUpdatedBy(before);
      const companyId = resolveSaleCompanyId(before);
      const itemIds = new Set();

      // Collect item IDs
      for (const [itemKey, itemData] of Object.entries(items)) {
        if (!itemData || typeof itemData !== "object") continue;
        const itemId = resolveItemId(itemData, itemKey);
        if (itemId) itemIds.add(itemId);
      }

      // Fetch item documents to get cost prices
      const itemRefs = Array.from(itemIds).map((id) => db.collection('itemsreg').doc(id));
      const itemDocs = itemRefs.length > 0 ? await db.getAll(...itemRefs) : [];
      const itemDocMap = new Map(itemDocs.map((doc) => [doc.id, doc.data() || {}]));

      const branchStockValues = new Map(); // Track stock value changes per branch
      const branchSalesValues = new Map();

      for (const [itemKey, itemData] of Object.entries(items)) {
        if (!itemData || typeof itemData !== "object") continue;

        const itemId = resolveItemId(itemData, itemKey);
        const branchId = resolveBranchId(before, itemData);
        if (!itemId || !branchId) {
          logger.warn(`Sales delete ${saleId} missing item/branch for key ${itemKey}`);
          continue;
        }

        const branchName = resolveBranchName(before, itemData, branchId);
        const quantity = getItemQuantity(itemData);
        const pieces = getItemPieces(itemData);
        const modeqty = getItemModeQty(itemData);
        const netQtyDelta = modeqty > 0 ? (pieces / modeqty) : quantity;
        const itemAmount = toNumber(itemData.amount || itemData.totalamount || 0);

        const item_amount = toNumber(pieces*itemData.price || 0);

        // Calculate stock value reduction (use cost price)
        const itemDocData = itemDocMap.get(itemId) || {};
        const costPrice = toNumber(itemData.cp ||itemDocData.cp || 0);
        const stockValueReduction = costPrice * quantity;
        const stockValreduction_pieces = costPrice * pieces;
        const itemDiscount = toNumber(itemData.discount || itemData.Discount || 0);
        const profit = toNumber( itemData.profit||itemDocData.profit || 0);
        const salesValue = itemAmount+itemDiscount;

        const paymentMode = (before.transMode || "cash").toLowerCase();

        const currentSales = branchSalesValues.get(branchId) || {
          sales: 0,
          discount: 0,
          name: branchName,
          modes: {
            cash: 0,
            card: 0,
            momo: 0,
            credit: 0,
            "bank transfer": 0,
          },
        };

        currentSales.sales += salesValue;
        currentSales.discount += itemDiscount;

        if (currentSales.modes.hasOwnProperty(paymentMode)) {
          currentSales.modes[paymentMode] += itemAmount;
        } else {
          currentSales.modes.cash += itemAmount;
        }

        branchSalesValues.set(branchId, currentSales);

        if (quantity === 0 && pieces === 0) continue;
        const boxpcs=getBoxQtyFromDoc(itemData);
        const carton_qty=pieces/boxpcs;
        const itemRegRef = db.collection("itemsreg").doc(itemId);
        batch.update(
          itemRegRef,
           'sales_value', admin.firestore.FieldValue.increment(-salesValue),
           'sales_qty', admin.firestore.FieldValue.increment(-pieces),
          ...branchBalanceUpdateArgs(branchId, {
            stockout_qty: admin.firestore.FieldValue.increment(-quantity),
            stockout_pieces: admin.firestore.FieldValue.increment(-pieces),
            netpieces: admin.firestore.FieldValue.increment(pieces),
            sales_value: admin.firestore.FieldValue.increment(-salesValue),
            stock_value: admin.firestore.FieldValue.increment(stockValreduction_pieces), // Restore stock value
            name: branchName,
            lastupdate: admin.firestore.FieldValue.serverTimestamp(),
            updatedby: updatedBy,
          }),
          'lastModified',
          admin.firestore.FieldValue.serverTimestamp(),
          'lastSaleId',
          saleId,
        );
// Daily transaction collection reference
const {dateymd, day, month, week, year} = resolveSaleDateParts(before);
const salesSummarydocId = `${companyId}_${dateymd}`;
const dailyRef = db.collection('stockreport').doc(salesSummarydocId);
const salesSummaryRef = db.collection('salesSummary').doc(salesSummarydocId);
const isReceipted=before?.reciepted || true;
const stockReportState = getOrCreateDocState(stockReportDocStates, salesSummarydocId, dailyRef, {
  summarydate: dateymd,
  companyid: companyId,
  lastupdate: admin.firestore.FieldValue.serverTimestamp(),
  day,
  month,
  week,
  year,
  summaryid: salesSummarydocId,
});

const summaryState = getOrCreateDocState(summaryDocStates, salesSummarydocId, salesSummaryRef, {
  summarydate: dateymd,
  day,
  month,
  week,
  year,
  companyid: companyId,
  company: before.companyname || companyId,
  summaryid: salesSummarydocId,
  createdat: admin.firestore.FieldValue.serverTimestamp(),
});

const branchBalanceRoot = ensureObject(stockReportState.data, 'branchbalance');
const stockReportBranchEntry = ensureObject(branchBalanceRoot, branchId);
stockReportBranchEntry.branchId = branchId;
stockReportBranchEntry.branchName = branchName;
stockReportBranchEntry.lastupdate = admin.firestore.FieldValue.serverTimestamp();
stockReportBranchEntry.summaryid = salesSummarydocId;
stockReportBranchEntry.summarydate = dateymd;
stockReportBranchEntry.day = day;
stockReportBranchEntry.month = month;
stockReportBranchEntry.week = week;
stockReportBranchEntry.year = year;
stockReportBranchEntry.updatedby = updatedBy;
applyIncrement(stockReportBranchEntry, 'branchstockin_balance', pieces);
applyIncrement(stockReportBranchEntry, 'branchstockin_value', stockValreduction_pieces);
applyIncrement(stockReportBranchEntry, 'branchsales_value', -salesValue);
applyIncrement(stockReportBranchEntry, 'branchsales_qty', -pieces);
applyIncrement(stockReportBranchEntry, 'branchstockout_balance', -pieces);
applyIncrement(stockReportBranchEntry, 'branchstockout_value', -stockValreduction_pieces);
applyIncrement(stockReportBranchEntry, 'branchtransaction_count', 1);

const stockReportItemsRoot = ensureObject(stockReportState.data, 'items');
const stockReportBranchItems = ensureObject(stockReportItemsRoot, branchId);
stockReportBranchItems.branchId = branchId;
stockReportBranchItems.branchName = branchName;
stockReportBranchItems.lastupdate = admin.firestore.FieldValue.serverTimestamp();
stockReportBranchItems.summaryid = salesSummarydocId;
stockReportBranchItems.summarydate = dateymd;
stockReportBranchItems.day = day;
stockReportBranchItems.month = month;
stockReportBranchItems.week = week;
stockReportBranchItems.year = year;
const stockItemEntry = ensureObject(stockReportBranchItems, itemId);
stockItemEntry.barcode = itemData.barcode || '';
stockItemEntry.itemid = itemId;
stockItemEntry.itemName = itemData.item;
stockItemEntry.summarydate = dateymd;
stockItemEntry.day = day;
stockItemEntry.month = month;
stockItemEntry.week = week;
stockItemEntry.year = year;
stockItemEntry.lastupdate = admin.firestore.FieldValue.serverTimestamp();
applyIncrement(stockItemEntry, 'stockin_balance', pieces);
applyIncrement(stockItemEntry, 'stockin_value', stockValreduction_pieces);
applyIncrement(stockItemEntry, 'sales_qty', -pieces);
applyIncrement(stockItemEntry, 'sales_value', -salesValue);
applyIncrement(stockItemEntry, 'stockout_balance', -pieces);
applyIncrement(stockItemEntry, 'stockout_value', -stockValreduction_pieces);
applyIncrement(stockItemEntry, 'transaction_count', 1);

applyIncrement(summaryState.data, 'companysales_value', -salesValue);
applyIncrement(summaryState.data, 'companysales_qty', -pieces);
applyIncrement(summaryState.data, 'company_Discount', -itemDiscount);
applyIncrement(summaryState.data, before.transMode || 'cash', -itemAmount);
applyIncrement(summaryState.data, 'companyCostof_goods', -stockValreduction_pieces);
applyIncrement(summaryState.data, 'companytransaction_count', 1);
applyIncrement(summaryState.data, 'company_profit', -profit);

const branchSummaryRoot = ensureObject(summaryState.data, 'branchSummary');
const branchSummaryEntry = ensureObject(branchSummaryRoot, branchId);
branchSummaryEntry.summaryid = salesSummarydocId;
branchSummaryEntry.summarydate = dateymd;
branchSummaryEntry.day = day;
branchSummaryEntry.month = month;
branchSummaryEntry.week = week;
branchSummaryEntry.year = year;
branchSummaryEntry.branchId = branchId;
branchSummaryEntry.branchName = branchName;
branchSummaryEntry.branchlastupdate = admin.firestore.FieldValue.serverTimestamp();
applyIncrement(branchSummaryEntry, 'branchsales_qty', -pieces);
applyIncrement(branchSummaryEntry, 'branchsales_value', -salesValue);
applyIncrement(branchSummaryEntry, 'branchtransaction_count', 1);
applyIncrement(branchSummaryEntry, 'branchCostof_goods', -stockValreduction_pieces);
applyIncrement(branchSummaryEntry, 'branch_Discount', -itemDiscount);
applyIncrement(branchSummaryEntry, before.transMode || 'cash', -itemAmount);
applyIncrement(branchSummaryEntry, 'branch_profit', -profit);
branchSummaryEntry.updatedby = updatedBy;
const branchItemsRoot = ensureObject(branchSummaryEntry, 'items');
const branchItemEntry = ensureObject(branchItemsRoot, itemId);
branchItemEntry.barcode = itemData.barcode || '';
branchItemEntry.itemid = itemId;
branchItemEntry.itemName = itemData.item;
branchItemEntry.summaryid = salesSummarydocId;
branchItemEntry.summarydate = dateymd;
branchItemEntry.day = day;
branchItemEntry.month = month;
branchItemEntry.week = week;
branchItemEntry.year = year;
branchItemEntry.lastupdate = admin.firestore.FieldValue.serverTimestamp();
applyIncrement(branchItemEntry, before.transMode || 'cash', -itemAmount);
applyIncrement(branchItemEntry, 'sales_qty', -pieces);
applyIncrement(branchItemEntry, 'sales_value', -salesValue);
applyIncrement(branchItemEntry, 'discount', -itemDiscount);
applyIncrement(branchItemEntry, 'costof_goods', -stockValreduction_pieces);
applyIncrement(branchItemEntry, 'transaction_count', 1);
applyIncrement(branchItemEntry, 'profit', -profit);
branchItemEntry.updatedby = updatedBy;

if(isReceipted){
const staffSummaryRoot = ensureObject(summaryState.data, 'staffSummary');
const staffBranchEntry = ensureObject(staffSummaryRoot, branchId);
const staffEntry = ensureObject(staffBranchEntry, before.staffemail || 'system');
staffEntry.staffemail = before.staffemail || 'system';
staffEntry.branchId = branchId;
staffEntry.branchName = branchName;
staffEntry.summaryid = salesSummarydocId;
staffEntry.summarydate = dateymd;
staffEntry.stafflastupdate = admin.firestore.FieldValue.serverTimestamp();
applyIncrement(staffEntry, 'staffdiscount', -itemDiscount);
applyIncrement(staffEntry, 'staffsales_value', -salesValue);
applyIncrement(staffEntry, 'staffsales_qty', -pieces);
applyIncrement(staffEntry, before.transMode || 'cash', -itemAmount);
applyIncrement(staffEntry, 'profit', -profit);
applyIncrement(staffEntry, 'stafftransaction_count', 1);
applyIncrement(staffEntry, 'staffCostof_goods', -stockValreduction_pieces);
}
// Reduce customer's credit balance if this was a credit sale
if (
  (((before.transMode || "").toLowerCase() === "credit") ||
   ((before.transMode || "").toLowerCase() === "credit sales")) &&
  (before.customerId)
)  
{
  const customerRef = db.collection("customers").doc(before.customerId);

  batch.set(
    customerRef,
    {
      creditBalance: admin.firestore.FieldValue.increment(-itemAmount),
      lastupdate: admin.firestore.FieldValue.serverTimestamp(),
      updatedby: updatedBy,
    },
    { merge: true }
  );
}
        // Accumulate stock value changes per branch
        const currentValue = branchStockValues.get(branchId) || {value: 0, name: branchName};
        currentValue.value += stockValreduction_pieces;
        branchStockValues.set(branchId, currentValue);

        hasUpdates = true;
      }

      if (hasUpdates) {
        await batch.commit();
        await flushDocWriteStates(summaryDocStates, db);
        await flushDocWriteStates(stockReportDocStates, db);

        //  Update dashboard_stats branchstock for each affected branch
        if (companyId && (branchStockValues.size > 0 || branchSalesValues.size > 0)) {
          const statsRef = db.collection("dashbaord_stats").doc(companyId);

          await db.runTransaction(async (transaction) => {
            const updateArgs = [];

            let totalStockValue = 0;
            let totalSales = 0;
            let companyDiscount = 0;
            let companyCash = 0;
            let companyCard = 0;
            let companyMomo = 0;
            let companyCredit = 0;
            let companyBankTransfer = 0;

            // =============================
            // Restore Stock Value
            // =============================
            for (const [branchId, data] of branchStockValues.entries()) {
              updateArgs.push(
                new admin.firestore.FieldPath("branchstock",branchId, "stock_value" ),
                admin.firestore.FieldValue.increment(data.value),

                new admin.firestore.FieldPath( "branchstock",  branchId, "branchname" ),
                data.name
              );

              totalStockValue += data.value;
            }

            // =============================
            // Reverse Sales Value
            // =============================
            for (const [branchId, data] of branchSalesValues.entries()) {
              updateArgs.push(
                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "sales_value"
                ),
                admin.firestore.FieldValue.increment(-data.sales),

                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "branchname"
                ),
                data.name,
            new admin.firestore.FieldPath("branchsales",branchId,"discount"),
            admin.firestore.FieldValue.increment(-data.discount),
                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "cash"
                ),
                admin.firestore.FieldValue.increment(-data.modes.cash),

                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "card"
                ),
                admin.firestore.FieldValue.increment(-data.modes.card),

                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "momo"
                ),
                admin.firestore.FieldValue.increment(-data.modes.momo),

                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "credit"
                ),
                admin.firestore.FieldValue.increment(-data.modes.credit),

                new admin.firestore.FieldPath(
                  "branchsales",
                  branchId,
                  "bank transfer"
                ),
                admin.firestore.FieldValue.increment(
                  -data.modes["bank transfer"]
                )
              );

              totalSales += data.sales;
               companyDiscount += data.discount;
              companyCash += data.modes.cash;
              companyCard += data.modes.card;
              companyMomo += data.modes.momo;
              companyCredit += data.modes.credit;
              companyBankTransfer += data.modes["bank transfer"];
            }

            transaction.set(
              statsRef,
              {
                companyId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),

                stock_in_total: admin.firestore.FieldValue.increment(totalStockValue),
                 company_Discount:admin.firestore.FieldValue.increment(-companyDiscount),
                companysales_value:admin.firestore.FieldValue.increment(-totalSales),

                cash:  admin.firestore.FieldValue.increment(-companyCash),

                card: admin.firestore.FieldValue.increment(-companyCard),

                momo: admin.firestore.FieldValue.increment(-companyMomo),

                credit: admin.firestore.FieldValue.increment(-companyCredit),

                "bank transfer": admin.firestore.FieldValue.increment(-companyBankTransfer),
              },
              { merge: true }
            );

            if (updateArgs.length > 0) {
              transaction.update(statsRef, ...updateArgs);
            }
          });

          logger.info(
            `Dashboard stats restored for deleted sale ${saleId}.`
          );
        }

      }
      return null;
    }

    // Case 2: Document created
    if (after && !before) {
      const items = after.items || {};
      const updatedBy = resolveUpdatedBy(after);
      const saleRef = db.collection('sales').doc(saleId);
      const companyId = resolveSaleCompanyId(after);

      const aggregated = new Map();
      for (const [itemKey, itemData] of Object.entries(items)) {
        if (!itemData || typeof itemData !== 'object') continue;

        const itemId = resolveItemId(itemData, itemKey);
        const branchId = resolveBranchId(after, itemData);
        if (!itemId || !branchId) continue;

        const key = `${itemId}::${branchId}`;
        const current = aggregated.get(key) || {
          itemId,
          branchId,
          quantity: 0,
          pieces: 0,
           amount: 0,
           discount: 0,
           profit: 0,
          itemData,
          itemKeys: [],
        };

        current.quantity += toNumber(getItemQuantity(itemData));
        current.pieces += toNumber(getItemPieces(itemData));
        current.amount += toNumber(itemData.amount || itemData.totalamount || 0);
        current.discount += toNumber(itemData.discount || 0);
        current.profit += toNumber(itemData.profit || 0);
        current.itemKeys.push(itemKey);
        aggregated.set(key, current);
      }

      const branchStockValues = new Map(); // Track stock value changes per branch
      const branchSalesValues = new Map();
      // Replace heavy transaction with chunked read + chunked writes to avoid timeouts
      let result;
      // Step A: read item docs outside transaction in chunks
      const perItemStatus = new Map();
      let overallApproved = true;
      let rejectInfo = null;

      // Helper: safely apply sale document updates in chunks to avoid
      // exceeding Firestore's ~500 field transform limit per write.
      const flushSaleUpdates = async (saleRef, baseUpdates, itemsUpdateFields) => {
        const MAX_TRANSFORMS = 400; // keep below 500 for safety
        // If itemsUpdateFields replaces the whole items array, do single update
        if (Array.isArray(itemsUpdateFields) && itemsUpdateFields[0] === 'items') {
          const chunk = db.batch();
          chunk.update(saleRef, ...baseUpdates, 'items', itemsUpdateFields[1]);
          await chunk.commit();
          return;
        }

        const basePairs = Math.floor(baseUpdates.length / 2);
        const itemsPairsTotal = Math.floor(itemsUpdateFields.length / 2);
        let perChunkPairs = Math.max(1, Math.floor(MAX_TRANSFORMS - basePairs));

        // If there are no item field updates, just run a single update
        if (itemsPairsTotal === 0) {
          const batchSingle = db.batch();
          batchSingle.update(saleRef, ...baseUpdates);
          await batchSingle.commit();
          return;
        }

        // Slice the itemsUpdateFields (which is [fieldPath1, val1, fieldPath2, val2, ...])
        for (let i = 0; i < itemsUpdateFields.length; i += perChunkPairs * 2) {
          const slice = itemsUpdateFields.slice(i, i + perChunkPairs * 2);
          const chunk = db.batch();
          chunk.update(saleRef, ...baseUpdates, ...slice);
          await chunk.commit();
        }
      };


        // Build itemDocMap by reading item documents in chunks
        const uniqueItemIds = Array.from(new Set(Array.from(aggregated.values()).map(e => e.itemId)));
        const itemRefs = uniqueItemIds.map(id => db.collection('itemsreg').doc(id));
        const itemDocMap = new Map();
        const GET_CHUNK = 400;
        for (let i = 0; i < itemRefs.length; i += GET_CHUNK) {
          const chunk = itemRefs.slice(i, i + GET_CHUNK);
          const snaps = await db.getAll(...chunk);
          snaps.forEach((snap) => itemDocMap.set(snap.id, snap.exists ? (snap.data() || {}) : {}));
        }

        for (const entry of aggregated.values()) {
          const itemDoc = itemDocMap.get(entry.itemId) || {};
          const productType = (itemDoc.producttype || "").toLowerCase();
          // Services do not participate in stock checking.
          if (productType === "service") {
            for (const key of entry.itemKeys) perItemStatus.set(key, "approved");
            continue;
          }

          const branchBalance = itemDoc.branchbalance || {};
          const branchData = branchBalance[entry.branchId] || {};
          const availableNetPieces = toNumber(branchData.netpieces ?? 0);

          const boxQty = getBoxQtyFromDoc(itemDoc);
          const availableBoxes = boxQty > 0 ? (availableNetPieces / boxQty) : 0;
          const requestedBoxes = boxQty > 0 ? (entry.pieces / boxQty) : 0;

          const entryStatus = requestedBoxes > availableBoxes ? 'rejected' : 'approved';
          for (const key of entry.itemKeys) perItemStatus.set(key, entryStatus);

          if (entryStatus === 'rejected') {
            overallApproved = false;
            if (!rejectInfo) {
              rejectInfo = { itemId: entry.itemId, branchId: entry.branchId, requestedBoxes, availableBoxes };
            }
          }
        }

        // Step 3a: If any item is rejected, update each item individually and set overall rejected
        if (!overallApproved) {
          const saleUpdates = [
            'stockCheckStatus', 'rejected',
            'stockCheckedAt', admin.firestore.FieldValue.serverTimestamp(),
            'stockRejectReason', 'insufficient_stock',
            'stockRejectItemId', rejectInfo.itemId,
            'stockRejectBranchId', rejectInfo.branchId,
            'stockRejectRequestedBoxes', rejectInfo.requestedBoxes,
            'stockRejectAvailableBoxes', rejectInfo.availableBoxes,
          ];
          saleUpdates.push(...buildItemStatusUpdates(items, perItemStatus));
          // Defer sale updates to chunked commit path below (avoid transaction)
        }

        

        // Replace transactional finalization with chunked commits below
     

      // perform chunked writes based on perItemStatus and aggregated data
      if (!overallApproved) {
        const saleUpdates = [
          'stockCheckStatus', 'rejected',
          'stockCheckedAt', admin.firestore.FieldValue.serverTimestamp(),
          'stockRejectReason', 'insufficient_stock',
          'stockRejectItemId', rejectInfo?.itemId,
          'stockRejectBranchId', rejectInfo?.branchId,
          'stockRejectRequestedBoxes', rejectInfo?.requestedBoxes,
          'stockRejectAvailableBoxes', rejectInfo?.availableBoxes,
        ];
        const itemsUpdateFields = buildItemStatusUpdates(items, perItemStatus);
        await flushSaleUpdates(saleRef, saleUpdates, itemsUpdateFields);
        result = { status: 'rejected' };
      } else {
        const batchWrites = [];
        for (const entry of aggregated.values()) {
          const itemDoc = itemDocMap.get(entry.itemId) || {};
          const itemRef = db.collection('itemsreg').doc(entry.itemId);
          const branchName = resolveBranchName(after, entry.itemData, entry.branchId);
          const costPrice = toNumber(entry.itemData.cp || itemDoc.cp || 0);
          const producttype = (entry.itemData.producttype || itemDoc.producttype ||"Not set");
          const stockValueReduction = costPrice * entry.pieces;
          const itemsales_value = toNumber(entry.amount) + toNumber(entry.discount);
        const transMode = (after.transMode || 'cash').toLowerCase().trim();

        const currentSales =
        branchSalesValues.get(entry.branchId) || {
        sales: 0,
        discount: 0,
        name: branchName,
        modes: {
        cash: 0,
        card: 0,
        momo: 0,
        credit: 0,
        "bank transfer": 0,
        },
        };

        currentSales.sales += itemsales_value;
        currentSales.discount += toNumber(entry.discount);

        if (transMode === 'cash'||transMode==='cash sales') {
        currentSales.modes.cash += toNumber(entry.amount);
        } else if (transMode === 'card') {
        currentSales.modes.card += toNumber(entry.amount);
        } else if (transMode === 'momo'||transMode==='mobile money'){
        currentSales.modes.momo += toNumber(entry.amount);
        } else if (transMode === 'credit'||transMode==='credit sales') {
        currentSales.modes.credit += toNumber(entry.amount);
        } else if (transMode === 'bank transfer') {
        currentSales.modes["bank transfer"] += toNumber(entry.amount);
        }

        branchSalesValues.set(entry.branchId, currentSales);
          const updateArgs = [
            'sales_value', admin.firestore.FieldValue.increment(itemsales_value),
            'sales_qty', admin.firestore.FieldValue.increment(entry.pieces),
            ...branchBalanceUpdateArgs(entry.branchId, {
              stockout_qty: admin.firestore.FieldValue.increment(entry.quantity),
              stockout_pieces: admin.firestore.FieldValue.increment(entry.pieces),
              netpieces: admin.firestore.FieldValue.increment(-entry.pieces),
              sales_value: admin.firestore.FieldValue.increment(itemsales_value),
              sales_qty: admin.firestore.FieldValue.increment(entry.pieces),
              stock_value: admin.firestore.FieldValue.increment(-stockValueReduction),
              name: branchName,
              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
              updatedby: updatedBy,
            }),
            'lastModified', admin.firestore.FieldValue.serverTimestamp(),
            'lastSaleId', saleId,
          ];

          batchWrites.push({ type: 'update', ref: itemRef, args: updateArgs });

          if (((after.transMode || "").toLowerCase() === 'credit')||((after.transMode || "").toLowerCase() === 'credit sales') && after.customerId) {
            const customerRef = db.collection('customers').doc(after.customerId);
            batchWrites.push({ type: 'set', ref: customerRef, data: {
              creditBalance: admin.firestore.FieldValue.increment(entry.amount),
              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
              updatedby: updatedBy,
            }, options: { merge: true } });
          }

          const isReceipted = after.reciepted === true;
          const {dateymd, day, month, week, year} = resolveSaleDateParts(after);
          const salesSummarydocId = `${companyId}_${dateymd}`;
          const salesSummaryRef = db.collection('salesSummary').doc(salesSummarydocId);
          const summaryState = getOrCreateDocState(summaryDocStates, salesSummarydocId, salesSummaryRef, {
            summarydate: dateymd,
            day,
            month,
            week,
            year,
            companyid: companyId,
            company: after.companyname || companyId,
            summaryid: salesSummarydocId,
            createdat: admin.firestore.FieldValue.serverTimestamp(),
          });

          applyIncrement(summaryState.data, 'companysales_value', itemsales_value || 0);
          applyIncrement(summaryState.data, 'companysales_qty', entry.pieces);
          applyIncrement(summaryState.data, 'company_Discount', entry.discount || 0);
          applyIncrement(summaryState.data, after.transMode || 'cash', entry.amount || 0);
          applyIncrement(summaryState.data, 'companyCostof_goods', stockValueReduction);
          applyIncrement(summaryState.data, 'companytransaction_count', 1);
          applyIncrement(summaryState.data, 'company_profit', entry.profit || 0);

          const branchSummaryRoot = ensureObject(summaryState.data, 'branchSummary');
          const branchSummaryEntry = ensureObject(branchSummaryRoot, entry.branchId);
          branchSummaryEntry.summaryid = salesSummarydocId;
          branchSummaryEntry.summarydate = dateymd;
          branchSummaryEntry.day = day;
          branchSummaryEntry.month = month;
          branchSummaryEntry.week = week;
          branchSummaryEntry.year = year;
          branchSummaryEntry.branchId = entry.branchId;
          branchSummaryEntry.branchName = branchName;
          branchSummaryEntry.branchlastupdate = admin.firestore.FieldValue.serverTimestamp();
          applyIncrement(branchSummaryEntry, 'branchsales_qty', entry.pieces);
          applyIncrement(branchSummaryEntry, 'branchsales_value', itemsales_value);
          applyIncrement(branchSummaryEntry, 'branchtransaction_count', 1);
          applyIncrement(branchSummaryEntry, 'branchCostof_goods', stockValueReduction);
          applyIncrement(branchSummaryEntry, 'branch_profit', toNumber(entry.profit));
          applyIncrement(branchSummaryEntry, 'branch_Discount',toNumber(entry.discount));
          applyIncrement(branchSummaryEntry, after.transMode || 'cash', entry.amount || 0);

          const branchItemsRoot = ensureObject(branchSummaryEntry, 'items');
          const branchItemEntry = ensureObject(branchItemsRoot, entry.itemId);
          branchItemEntry.barcode = entry.itemData.barcode || '';
          branchItemEntry.itemid = entry.itemId;
          branchItemEntry.itemName = entry.itemData.item;
          branchItemEntry.producttype = entry.itemData.producttype;
          branchItemEntry.summaryid = salesSummarydocId;
          branchItemEntry.summarydate = dateymd;
          branchItemEntry.day = day;
          branchItemEntry.month = month;
          branchItemEntry.week = week;
          branchItemEntry.year = year;
          branchItemEntry.lastupdate = admin.firestore.FieldValue.serverTimestamp();
          branchItemEntry.branchId = entry.branchId;
          branchItemEntry.branchName = branchName;
          applyIncrement(branchItemEntry, after.transMode || 'cash', toNumber(entry.amount));
          applyIncrement(branchItemEntry, 'sales_qty', entry.pieces);
          applyIncrement(branchItemEntry, 'sales_value', itemsales_value);
          applyIncrement(branchItemEntry, 'discount', toNumber(entry.discount));
          applyIncrement(branchItemEntry, 'costof_goods', stockValueReduction);
          applyIncrement(branchItemEntry, 'transaction_count', 1);
          applyIncrement(branchItemEntry, 'profit', toNumber(entry.profit));
          branchItemEntry.updatedby = updatedBy;

           if(isReceipted) {
           const staffSummaryRoot = ensureObject(summaryState.data, 'staffSummary');
            const staffBranchEntry = ensureObject(staffSummaryRoot, entry.branchId);
            const staffEntry = ensureObject(staffBranchEntry, after.staffemail || 'system');
            staffEntry.staffemail = after.staffemail || 'system';
            staffEntry.staff = after.receiptby || after.createdby || 'system';
            staffEntry.branchId = entry.branchId;
            staffEntry.branchName = branchName;
            staffEntry.summaryid = salesSummarydocId;
            staffEntry.summarydate = dateymd;

            staffEntry.stafflastupdate = admin.firestore.FieldValue.serverTimestamp();
            applyIncrement(staffEntry, 'staffdiscount', toNumber(entry.discount));
            applyIncrement(staffEntry, 'staffsales_value',itemsales_value);
            applyIncrement(staffEntry, 'staffsales_qty', entry.pieces);
            applyIncrement(staffEntry, after.transMode || 'cash', toNumber(entry.amount));
            applyIncrement(staffEntry, 'profit', toNumber(entry.profit));
            applyIncrement(staffEntry, 'staffCostof_goods', stockValueReduction);
}

          const dailyRef = db.collection('stockreport').doc(salesSummarydocId);
          const stockReportState = getOrCreateDocState(stockReportDocStates, salesSummarydocId, dailyRef, {
            companytransaction_count: admin.firestore.FieldValue.increment(0),
            lastupdate: admin.firestore.FieldValue.serverTimestamp(),
            summarydate: dateymd,
            companyid: companyId,
            day,
            month,
            week,
            year,
            summaryid: salesSummarydocId,
          });

          applyIncrement(stockReportState.data, 'companytransaction_count', 1);

          const branchBalanceRoot = ensureObject(stockReportState.data, 'branchbalance');
          const branchBalanceEntry = ensureObject(branchBalanceRoot, entry.branchId);
          branchBalanceEntry.branchId = entry.branchId;
          branchBalanceEntry.branchName = branchName;
          branchBalanceEntry.lastupdate = admin.firestore.FieldValue.serverTimestamp();
          branchBalanceEntry.summaryid = salesSummarydocId;
          branchBalanceEntry.summarydate = dateymd;
          branchBalanceEntry.day = day;
          branchBalanceEntry.month = month;
          branchBalanceEntry.week = week;
          branchBalanceEntry.year = year;
          branchBalanceEntry.updatedby = updatedBy;
          applyIncrement(branchBalanceEntry, 'branchsales_value', itemsales_value);
          applyIncrement(branchBalanceEntry, 'branchsales_qty', entry.pieces);
          applyIncrement(branchBalanceEntry, 'branchstockout_balance', entry.pieces);
          applyIncrement(branchBalanceEntry, 'branchstockout_value', stockValueReduction || 0);
          applyIncrement(branchBalanceEntry, 'branchtransaction_count', 1);

          const itemsRoot = ensureObject(stockReportState.data, 'items');
          const branchItemsEntry = ensureObject(itemsRoot, entry.branchId);
          branchItemsEntry.branchId = entry.branchId;
          branchItemsEntry.branchName = branchName;
          branchItemsEntry.lastupdate = admin.firestore.FieldValue.serverTimestamp();
          branchItemsEntry.summaryid = salesSummarydocId;
          branchItemsEntry.summarydate = dateymd;
          branchItemsEntry.day = day;
          branchItemsEntry.month = month;
          branchItemsEntry.week = week;
          branchItemsEntry.year = year;
          const itemEntry = ensureObject(branchItemsEntry, entry.itemId);
          itemEntry.itemid = entry.itemId;
          itemEntry.itemName = entry.itemData.item || '';
          itemEntry.barcode = entry.itemData.barcode || '';
          itemEntry.producttype = entry.itemData.producttype || '';
          itemEntry.summarydate = dateymd;
          itemEntry.day = day;
          itemEntry.month = month;
          itemEntry.week = week;
          itemEntry.year = year;
          applyIncrement(itemEntry, 'sales_qty', entry.pieces);
          applyIncrement(itemEntry, 'sales_value', itemsales_value);
          applyIncrement(itemEntry, 'stockout_balance', entry.pieces);
          applyIncrement(itemEntry, 'stockout_value', stockValueReduction);
          applyIncrement(itemEntry, 'transaction_count', 1);

          const currentValue = branchStockValues.get(entry.branchId) || {value: 0, name: branchName};
          currentValue.value += stockValueReduction;
          branchStockValues.set(entry.branchId, currentValue);
        }

        // prepare sale doc status and per-item statuses
        const saleUpdates = ['stockCheckStatus', 'approved', 'stockCheckedAt', admin.firestore.FieldValue.serverTimestamp()];
        const itemsUpdateFields = buildItemStatusUpdates(items, perItemStatus);

        // flush other writes in chunks
        for (let i = 0; i < batchWrites.length; i += 450) {
          const chunk = batchWrites.slice(i, i + 450);
          const chunkBatch = db.batch();
          for (const op of chunk) {
            if (op.type === 'set') chunkBatch.set(op.ref, op.data, op.options || { merge: true });
            else if (op.type === 'update') chunkBatch.update(op.ref, ...op.args);
          }
          await chunkBatch.commit();
        }

        // now apply sale doc updates in safe chunks
        await flushSaleUpdates(saleRef, saleUpdates, itemsUpdateFields);
        await flushDocWriteStates(summaryDocStates, db);
        await flushDocWriteStates(stockReportDocStates, db);

        result = { status: 'approved', branchStockValues, branchSalesValues };
      }

     if (
       result?.status === "approved" && companyId && (result.branchStockValues.size > 0 || result.branchSalesValues.size > 0)

     ) {
       const statsRef = db.collection("dashbaord_stats").doc(companyId);

       await db.runTransaction(async (transaction) => {
         const updateArgs = [];

         let totalStockValue = 0;
         let totalSales = 0;
        let totalDiscount = 0;
         let companyCash = 0;
         let companyCard = 0;
         let companyMomo = 0;
         let companyCredit = 0;
         let companyBankTransfer = 0;

         // ===========================
         // Update Stock Values
         // ===========================
         for (const [branchId, data] of result.branchStockValues.entries()) {
           updateArgs.push(
             new admin.firestore.FieldPath("branchstock", branchId, "stock_value"),
             admin.firestore.FieldValue.increment(-data.value),

             new admin.firestore.FieldPath(
               "branchstock",
               branchId,
               "branchname"
             ),
             data.name
           );

           totalStockValue += data.value;
         }

         // ===========================
         // Update Sales Values
         // ===========================
         for (const [branchId, data] of result.branchSalesValues.entries()) {
           updateArgs.push(
             new admin.firestore.FieldPath("branchsales",branchId, "sales_value"
             ),
             admin.firestore.FieldValue.increment(data.sales),

             new admin.firestore.FieldPath( "branchsales", branchId,"branchname"), data.name,

            new admin.firestore.FieldPath( "branchsales", branchId, "discount" ),
             admin.firestore.FieldValue.increment( data.discount || 0 ),

             new admin.firestore.FieldPath("branchsales", branchId,"cash"),
             admin.firestore.FieldValue.increment(data.modes.cash),

             new admin.firestore.FieldPath( "branchsales", branchId, "card"),
             admin.firestore.FieldValue.increment(data.modes.card),

             new admin.firestore.FieldPath("branchsales", branchId,"momo"),

             admin.firestore.FieldValue.increment(data.modes.momo),

             new admin.firestore.FieldPath("branchsales",branchId,"credit"),

             admin.firestore.FieldValue.increment(data.modes.credit),

             new admin.firestore.FieldPath( "branchsales",branchId,"bank transfer" ),

             admin.firestore.FieldValue.increment(data.modes["bank transfer"]) );

           totalSales += data.sales;
            totalDiscount += data.discount || 0;
           companyCash += data.modes.cash;
           companyCard += data.modes.card;
           companyMomo += data.modes.momo;
           companyCredit += data.modes.credit;
           companyBankTransfer += data.modes["bank transfer"];
         }

         transaction.set(
           statsRef,
           {
             companyId,updatedAt: admin.firestore.FieldValue.serverTimestamp(),
             stock_in_total:admin.firestore.FieldValue.increment(-totalStockValue),
             companysales_value:admin.firestore.FieldValue.increment(totalSales),
             company_Discount: admin.firestore.FieldValue.increment( totalDiscount ),
             cash:admin.firestore.FieldValue.increment(companyCash),
             card:admin.firestore.FieldValue.increment(companyCard),
             momo:admin.firestore.FieldValue.increment(companyMomo),
             credit:admin.firestore.FieldValue.increment(companyCredit),
             "bank_transfer":admin.firestore.FieldValue.increment(companyBankTransfer),

           },
           { merge: true }
         );

         if (updateArgs.length > 0) {
           transaction.update(statsRef, ...updateArgs);
         }
       });

       logger.info(
         `Dashboard stats updated for sale ${saleId}.`
       );
     }
      return null;
    }

    // Case 3: Document updated
    if (after) {
      const beforeItems = before?.items || {};
      const afterItems = after.items || {};
      const updatedBy = resolveUpdatedBy(after);
      const companyId = resolveSaleCompanyId(after) || resolveSaleCompanyId(before);

      const allItemKeys = new Set([...Object.keys(beforeItems), ...Object.keys(afterItems)]);
      const itemIds = new Set();

      // Collect item IDs
      for (const itemKey of allItemKeys) {
        const beforeItemData = beforeItems[itemKey] || {};
        const afterItemData = afterItems[itemKey] || {};
        const itemId = resolveItemId(afterItemData, itemKey) || resolveItemId(beforeItemData, itemKey);
        if (itemId) itemIds.add(itemId);
      }

      // Fetch item documents to get cost prices
      const itemRefs = Array.from(itemIds).map((id) => db.collection('itemsreg').doc(id));
      const itemDocs = itemRefs.length > 0 ? await db.getAll(...itemRefs) : [];
      const itemDocMap = new Map(itemDocs.map((doc) => [doc.id, doc.data() || {}]));
      const branchStockValues = new Map(); // Track stock value changes per branch
      const branchSalesValues = new Map();

      const cashier = after?.cashier || before?.cashier || "system";
      const cashierEmail = after?.cashieremail || before?.cashieremail || "system";
      const summaryId = `${companyId}_${resolveSaleDateParts(after).dateymd}`;
      const summaryRef = db.collection('salesSummary').doc(summaryId);
      const stockRef = db.collection('stockreport').doc(summaryId);
      const modeKey = after?.transMode || before?.transMode || 'cash';
      const branchId = after?.branchId || before?.branchId || after?.branchid || before?.branchid;
      const branchName = after?.branchName || before?.branchName || after?.branchname || before?.branchname ||"No branch";
      const beforeReceipted = before?.reciepted ?? false;
      const afterReceipted = after?.reciepted ?? false;
      const receiptJustIssued = beforeReceipted === false && afterReceipted === true;
      if (cashierEmail.trim() !== "" && receiptJustIssued) {
          const payments = after?.payments || before?.payments || [];
          const paymentUpdates = {};

          for (const payment of payments) {
            const method = (payment.method || "cash").toLowerCase();
            const amount = toNumber(payment.amount);

            paymentUpdates[method] =admin.firestore.FieldValue.increment(amount);
          }
          const cashierAmount = toNumber(after.amountPaid || before.amountPaid || 0);
          const cashierDiscount = toNumber(after.discount || before.discount || 0);
          const cashierProfit = toNumber(after.profit || before.profit || 0);
          const cashierSalesValue = cashierAmount+cashierDiscount;
          const receiptSummaryState = getOrCreateDocState(summaryDocStates, summaryId, summaryRef, {
            summarydate: resolveSaleDateParts(after).dateymd,
            day: resolveSaleDateParts(after).day,
            month: resolveSaleDateParts(after).month,
            week: resolveSaleDateParts(after).week,
            year: resolveSaleDateParts(after).year,
            companyid: companyId,
            company: after?.companyname || before?.companyname || companyId,
            summaryid: summaryId,
          });

          const staffSummaryRoot = ensureObject(receiptSummaryState.data, 'staffSummary');
          const staffBranchEntry = ensureObject(staffSummaryRoot, branchId);
          const staffEntry = ensureObject(staffBranchEntry, cashierEmail);
          staffEntry.staff = cashier;
          staffEntry.staffemail = cashierEmail;
          staffEntry.branchId = branchId;
          staffEntry.branchName = branchName;
          staffEntry.summaryid = summaryId;
          staffEntry.summarydate = resolveSaleDateParts(after).dateymd;
          applyIncrement(staffEntry, 'staffsales_value', cashierSalesValue);
          applyIncrement(staffEntry, 'staffdiscount', cashierDiscount);
          applyIncrement(staffEntry, 'profit', cashierProfit);
          applyIncrement(staffEntry, 'stafftransaction_count', 1);
          Object.entries(paymentUpdates).forEach(([method, incrementValue]) => {
            applyIncrement(staffEntry, method, incrementValue.operand || 0);
          });

          hasUpdates = true;
      }

      for (const itemKey of allItemKeys) {
        const beforeItemData = beforeItems[itemKey] || {};
        const afterItemData = afterItems[itemKey] || {};
        const itemId = resolveItemId(afterItemData, itemKey);
        const branchId = resolveBranchId(after, afterItemData);
        if (!itemId || !branchId) {
          logger.warn(`Sales update ${saleId} missing item/branch for key ${itemKey}`);
          continue;
        }

        const branchName = resolveBranchName(after, afterItemData, branchId);
        const beforeQty = getItemQuantity(beforeItemData);
        const beforePieces = getItemPieces(beforeItemData);
        const afterQty = getItemQuantity(afterItemData);
        const afterPieces = getItemPieces(afterItemData);
        const beforeModeQty = getItemModeQty(beforeItemData);
        const afterModeQty = getItemModeQty(afterItemData);

        const qtyDifference = afterQty - beforeQty;
        const piecesDifference = afterPieces - beforePieces;
        const effectiveModeQty = afterModeQty > 0 ? afterModeQty : beforeModeQty;
        const netQtyDifference = effectiveModeQty > 0? (piecesDifference / effectiveModeQty): qtyDifference;

        const beforeAmount = toNumber(beforeItemData.amount || beforeItemData.totalAmount || beforeItemData.totalamount || 0);
        const afterAmount = toNumber(afterItemData.amount || afterItemData.totalAmount || afterItemData.totalamount || 0);
        const amountDifference = afterAmount - beforeAmount;
        const beforeDiscount = toNumber(beforeItemData.discount || beforeItemData.Discount || 0);
        const afterDiscount = toNumber(afterItemData.discount || afterItemData.Discount || 0);
        const discountDifference = afterDiscount - beforeDiscount;
        const beforeProfit = toNumber(beforeItemData.profit || 0);
        const afterProfit = toNumber(afterItemData.profit || 0);
        const profitDifference = afterProfit - beforeProfit;
        const salesValue=amountDifference+discountDifference;

        const paymentMode = (
          after?.transMode ||
          before?.transMode ||
          "cash"
        ).toLowerCase();

        const currentSales = branchSalesValues.get(branchId) || {
          sales: 0,
          discount:0,
          name: branchName,
          modes: {
            cash: 0,
            card: 0,
            momo: 0,
            credit: 0,
            "bank transfer": 0,
          },
        };

        currentSales.sales += salesValue;
        currentSales.discount += discountDifference;

        if (currentSales.modes.hasOwnProperty(paymentMode)) {
          currentSales.modes[paymentMode] += amountDifference;
        } else {
          currentSales.modes.cash += amountDifference;
        }

        branchSalesValues.set(branchId, currentSales);

        // Calculate stock value change (use cost price)
        const itemDocData = itemDocMap.get(itemId) || {};
        const costPrice = toNumber(itemDocData.cp || afterItemData.cp || beforeItemData.cp || 0);
        const stockValueChange = costPrice * qtyDifference;
        const producttype=itemDocData.producttype ||afterItemData.producttype||beforeItemData.producttype || 'no producttype set'
        const isService = producttype.toLowerCase() === "service";
       if (qtyDifference === 0 && piecesDifference === 0 && amountDifference === 0) continue;

        const itemRegRef = db.collection("itemsreg").doc(itemId);
        batch.update(
          itemRegRef,
          'sales_value', admin.firestore.FieldValue.increment(salesValue),
          'sales_qty', admin.firestore.FieldValue.increment(piecesDifference),
          ...branchBalanceUpdateArgs(branchId, {
            stockout_qty: admin.firestore.FieldValue.increment(qtyDifference),
            stockout_pieces: admin.firestore.FieldValue.increment(piecesDifference),
            netpieces: admin.firestore.FieldValue.increment(-piecesDifference),
            sales_value: admin.firestore.FieldValue.increment(salesValue),
            stock_value: admin.firestore.FieldValue.increment(-stockValueChange), // Reduce stock value
            name: branchName,
            lastupdate: admin.firestore.FieldValue.serverTimestamp(),
            updatedby: updatedBy,
          }),
          'lastModified',
          admin.firestore.FieldValue.serverTimestamp(),
          'lastSaleId',
          saleId,
        );

        // Accumulate stock value changes per branch
        const currentValue = branchStockValues.get(branchId) || {value: 0, name: branchName};
        currentValue.value += stockValueChange;
        branchStockValues.set(branchId, currentValue);


        const entryCategory = itemDocData.pcategory || afterItemData.pcategory || beforeItemData.pcategory || 'no category set';
        const staffEmail = after?.staffemail || before?.staffemail || after?.cashieremail || before?.cashieremail || 'system';

        const summaryState = getOrCreateDocState(summaryDocStates, summaryId, summaryRef, {
          summarydate: resolveSaleDateParts(after).dateymd,
          day: resolveSaleDateParts(after).day,
          month: resolveSaleDateParts(after).month,
          week: resolveSaleDateParts(after).week,
          year: resolveSaleDateParts(after).year,
          companyid: companyId,
          company: after?.companyname || before?.companyname || companyId,
          summaryid: summaryId,
        });

        applyIncrement(summaryState.data, modeKey, amountDifference);
        applyIncrement(summaryState.data, 'companysales_value', salesValue);
        applyIncrement(summaryState.data, 'companysales_qty', piecesDifference);
        applyIncrement(summaryState.data, 'company_Discount', discountDifference);
        applyIncrement(summaryState.data, 'companyCostof_goods', stockValueChange);
        applyIncrement(summaryState.data, 'company_profit', profitDifference);
        applyIncrement(summaryState.data, 'companytransaction_count', 1);

        const branchSummaryRoot = ensureObject(summaryState.data, 'branchSummary');
        const branchSummaryEntry = ensureObject(branchSummaryRoot, branchId);
        branchSummaryEntry.branchId = branchId;
        branchSummaryEntry.branchName = branchName;
        branchSummaryEntry.summaryid = summaryId;
        branchSummaryEntry.summarydate = resolveSaleDateParts(after).dateymd;
        branchSummaryEntry.day = resolveSaleDateParts(after).day;
        branchSummaryEntry.month = resolveSaleDateParts(after).month;
        branchSummaryEntry.week = resolveSaleDateParts(after).week;
        branchSummaryEntry.year = resolveSaleDateParts(after).year;
        applyIncrement(branchSummaryEntry, 'branchsales_value', salesValue);
        applyIncrement(branchSummaryEntry, 'branchsales_qty', piecesDifference);
        applyIncrement(branchSummaryEntry, 'branch_Discount', discountDifference);
        applyIncrement(branchSummaryEntry, modeKey, amountDifference);
        applyIncrement(branchSummaryEntry, 'branch_profit', profitDifference);
        applyIncrement(branchSummaryEntry, 'branchtransaction_count', 1);
        applyIncrement(branchSummaryEntry, 'branchCostof_goods', stockValueChange);

        const branchItemsRoot = ensureObject(branchSummaryEntry, 'items');
        const branchItemEntry = ensureObject(branchItemsRoot, itemId);
        branchItemEntry.itemid = itemId;
        branchItemEntry.itemName = afterItemData.item || beforeItemData.item || itemId;
        branchItemEntry.barcode = afterItemData.barcode || beforeItemData.barcode || '';
        branchItemEntry.pcategory = entryCategory;
        branchItemEntry.summaryid = summaryId;
        branchItemEntry.summarydate = resolveSaleDateParts(after).dateymd;
        branchItemEntry.day = resolveSaleDateParts(after).day;
        branchItemEntry.month = resolveSaleDateParts(after).month;
        branchItemEntry.week = resolveSaleDateParts(after).week;
        branchItemEntry.year = resolveSaleDateParts(after).year;
        branchItemEntry.branchId = branchId;
        branchItemEntry.branchName = branchName;
        applyIncrement(branchItemEntry, modeKey, amountDifference);
        applyIncrement(branchItemEntry, 'sales_qty', piecesDifference);
        applyIncrement(branchItemEntry, 'sales_value', salesValue);
        applyIncrement(branchItemEntry, 'discount', discountDifference);
        applyIncrement(branchItemEntry, 'costof_goods', stockValueChange);
        applyIncrement(branchItemEntry, 'profit', profitDifference);
        applyIncrement(branchItemEntry, 'transaction_count', 1);

        const staffSummaryRoot = ensureObject(summaryState.data, 'staffSummary');
        const staffBranchEntry = ensureObject(staffSummaryRoot, branchId);
        const staffEntry = ensureObject(staffBranchEntry, staffEmail);
        staffEntry.staffemail = staffEmail;
        staffEntry.branchId = branchId;
        staffEntry.branchName = branchName;
        staffEntry.summaryid = summaryId;
        staffEntry.summarydate = resolveSaleDateParts(after).dateymd;
        applyIncrement(staffEntry, 'staffsales_value', salesValue);
        applyIncrement(staffEntry, 'staffsales_qty', piecesDifference);
        applyIncrement(staffEntry, 'staffdiscount', discountDifference);
        applyIncrement(staffEntry, modeKey, amountDifference);
        applyIncrement(staffEntry, 'profit', profitDifference);
        applyIncrement(staffEntry, 'stafftransaction_count', 1);
        applyIncrement(staffEntry, 'staffCostof_goods', stockValueChange);

        const stockReportState = getOrCreateDocState(stockReportDocStates, summaryId, stockRef, {
          summarydate: resolveSaleDateParts(after).dateymd,
          companyid: companyId,
          day: resolveSaleDateParts(after).day,
          month: resolveSaleDateParts(after).month,
          week: resolveSaleDateParts(after).week,
          year: resolveSaleDateParts(after).year,
          summaryid: summaryId,
        });

        applyIncrement(stockReportState.data, 'companytransaction_count', 1);

        const branchBalanceRoot = ensureObject(stockReportState.data, 'branchbalance');
        const branchBalanceEntry = ensureObject(branchBalanceRoot, branchId);
        branchBalanceEntry.branchId = branchId;
        branchBalanceEntry.branchName = branchName;
        branchBalanceEntry.summaryid = summaryId;
        branchBalanceEntry.summarydate = resolveSaleDateParts(after).dateymd;
        branchBalanceEntry.day = resolveSaleDateParts(after).day;
        branchBalanceEntry.month = resolveSaleDateParts(after).month;
        branchBalanceEntry.week = resolveSaleDateParts(after).week;
        branchBalanceEntry.year = resolveSaleDateParts(after).year;
        applyIncrement(branchBalanceEntry, 'branchsales_value', salesValue);
        applyIncrement(branchBalanceEntry, 'branchsales_qty', piecesDifference);
        applyIncrement(branchBalanceEntry, 'branchstockout_balance', piecesDifference);
        applyIncrement(branchBalanceEntry, 'branchstockout_value', stockValueChange);
        applyIncrement(branchBalanceEntry, 'branchtransaction_count', 1);

        const itemsRoot = ensureObject(stockReportState.data, 'items');
        const branchItemsEntry = ensureObject(itemsRoot, branchId);
        branchItemsEntry.branchId = branchId;
        branchItemsEntry.branchName = branchName;
        branchItemsEntry.summaryid = summaryId;
        branchItemsEntry.summarydate = resolveSaleDateParts(after).dateymd;
        branchItemsEntry.day = resolveSaleDateParts(after).day;
        branchItemsEntry.month = resolveSaleDateParts(after).month;
        branchItemsEntry.week = resolveSaleDateParts(after).week;
        branchItemsEntry.year = resolveSaleDateParts(after).year;
        const itemEntry = ensureObject(branchItemsEntry, itemId);
        itemEntry.itemid = itemId;
        itemEntry.itemName = afterItemData.item || beforeItemData.item || itemId;
        itemEntry.barcode = afterItemData.barcode || beforeItemData.barcode || '';
        itemEntry.summarydate = resolveSaleDateParts(after).dateymd;
        itemEntry.day = resolveSaleDateParts(after).day;
        itemEntry.month = resolveSaleDateParts(after).month;
        itemEntry.week = resolveSaleDateParts(after).week;
        itemEntry.year = resolveSaleDateParts(after).year;
        applyIncrement(itemEntry, 'sales_qty', piecesDifference);
        applyIncrement(itemEntry, 'sales_value', salesValue);
        applyIncrement(itemEntry, 'stockout_balance', piecesDifference);
        applyIncrement(itemEntry, 'stockout_value', stockValueChange);
        applyIncrement(itemEntry, 'transaction_count', 1);

        hasUpdates = true;
      }
// Update customer credit balance when a sale is edited
const beforeIsCredit = (before?.transMode || "").toLowerCase() === "credit"||(before?.transMode || "").toLowerCase() === "credit sales";
const afterIsCredit = (after?.transMode || "").toLowerCase() === "credit"||(after?.transMode || "").toLowerCase() === "credit sales";

const beforeAmountPaid = toNumber(before?.totalamount ?? before?.amountPaid ?? 0);
const afterAmountPaid = toNumber(after?.totalamount ?? after?.amountPaid ?? 0);

if (after?.customerId) {
  const customerRef = db.collection("customers").doc(after.customerId);

  // Credit -> Credit
  if (beforeIsCredit && afterIsCredit) {
    const difference = afterAmountPaid - beforeAmountPaid;

    if (difference !== 0) {
      batch.set(
        customerRef,
        {
          creditBalance: admin.firestore.FieldValue.increment(difference),
          lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          updatedby: updatedBy,
        },
        { merge: true }
      );
    }
  }

  // Cash/Other -> Credit
  else if (!beforeIsCredit && afterIsCredit) {
    batch.set(
      customerRef,
      {
        creditBalance: admin.firestore.FieldValue.increment(afterAmountPaid),
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        updatedby: updatedBy,
      },
      { merge: true }
    );
  }

  // Credit -> Cash/Other
  else if (beforeIsCredit && !afterIsCredit) {
    batch.set(
      customerRef,
      {
        creditBalance: admin.firestore.FieldValue.increment(-beforeAmountPaid),
        lastupdate: admin.firestore.FieldValue.serverTimestamp(),
        updatedby: updatedBy,
      },
      { merge: true }
    );
  }
}
      if (hasUpdates) {
        await batch.commit();
        await flushDocWriteStates(summaryDocStates, db);
        await flushDocWriteStates(stockReportDocStates, db);

        // Update dashboard_stats branchstock for each affected branch
// Update dashboard_stats
if (
  companyId &&
  (branchStockValues.size > 0 || branchSalesValues.size > 0)
) {
  const statsRef = db.collection("dashbaord_stats").doc(companyId);

  await db.runTransaction(async (transaction) => {
    const updateArgs = [];

    let totalStockValue = 0;
    let totalSales = 0;
    let companyDiscount=0;
    let companyCash = 0;
    let companyCard = 0;
    let companyMomo = 0;
    let companyCredit = 0;
    let companyBankTransfer = 0;

    // ==========================
    // STOCK CHANGES
    // ==========================
    for (const [branchId, data] of branchStockValues.entries()) {
      updateArgs.push(
        new admin.firestore.FieldPath(
          "branchstock",
          branchId,
          "stock_value"
        ),
        admin.firestore.FieldValue.increment(-data.value),

        new admin.firestore.FieldPath(
          "branchstock",
          branchId,
          "branchname"
        ),
        data.name
      );

      totalStockValue += data.value;
    }

    // ==========================
    // SALES CHANGES
    // ==========================
    for (const [branchId, data] of branchSalesValues.entries()) {
      updateArgs.push(
        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "sales_value"
        ),
        admin.firestore.FieldValue.increment(data.sales),

        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "branchname"
        ),
        data.name,

        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "cash"
        ),
        admin.firestore.FieldValue.increment(data.modes.cash),
      new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "discount"
        ),
        admin.firestore.FieldValue.increment(data.discount),

        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "card"
        ),
        admin.firestore.FieldValue.increment(data.modes.card),

        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "momo"
        ),
        admin.firestore.FieldValue.increment(data.modes.momo),

        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "credit"
        ),
        admin.firestore.FieldValue.increment(data.modes.credit),

        new admin.firestore.FieldPath(
          "branchsales",
          branchId,
          "bank transfer"
        ),
        admin.firestore.FieldValue.increment(
          data.modes["bank transfer"]
        )
      );

      totalSales += data.sales;
      companyDiscount+=data.discount;
      companyCash += data.modes.cash;
      companyCard += data.modes.card;
      companyMomo += data.modes.momo;
      companyCredit += data.modes.credit;
      companyBankTransfer += data.modes["bank transfer"];
    }

    transaction.set(
      statsRef,
      {
        companyId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),

        stock_in_total: admin.firestore.FieldValue.increment(-totalStockValue),

        companysales_value: admin.firestore.FieldValue.increment(totalSales),

        cash: admin.firestore.FieldValue.increment(companyCash),

        card: admin.firestore.FieldValue.increment(companyCard),

        momo: admin.firestore.FieldValue.increment(companyMomo),

        credit:admin.firestore.FieldValue.increment(companyCredit),
        company_Discount:admin.firestore.FieldValue.increment(companyDiscount),

        "bank transfer":
          admin.firestore.FieldValue.increment(companyBankTransfer),
      },
      { merge: true }
    );

    if (updateArgs.length > 0) {
      transaction.update(statsRef, ...updateArgs);
    }
  });

  logger.info(
    `Dashboard stats updated after editing sale ${saleId}.`
  );
}      }
    }

    return null;
  } catch (error) {
    logger.error(`Error syncing sales ${saleId} to itemsreg stockout:`, error);
    return null;
  }
});

// javascript
function normalizeItems(raw) {
  try {
    if (!raw) return [];

    const normalizeObject = (item) => {
      if (!item || typeof item !== "object") return null;

      // If fields are JSON strings, try to parse them
      for (const key of Object.keys(item)) {
        if (typeof item[key] === "string" && (item[key].startsWith("{") || item[key].startsWith("["))) {
          try {
            item[key] = JSON.parse(item[key]);
          } catch (e) {
            // ignore parse error, keep original string
          }
        }
      }

      // support nested item object: item.item = { name, title }
      const itemName =
        (typeof item.item === "string" && item.item) ||
        (item.item && (item.item.name || item.item.title || item.item.label)) ||
        item.name ||
        item.title ||
        "";

      const itemId =
        item.itemid ||
        item.itemId ||
        item.id ||
        item.sku ||
        item.code ||
        "";

      const totalpieces = toNumber(
  item.totalpieces ??
  item.totalPieces ??
  item.pieces ??
  item.qty ??
  item.quantity ??
  item.damageqty ??
  item.damage_qty ??
  0
);
      const cp = toNumber(item.cp ?? item.costprice ?? item.cost_price ?? item.cost ?? 0);
      const boxpiece = toNumber(item.boxpiece ?? item.boxPiece ?? item.box_piece ?? 0);

      return {
        itemid: String(itemId || "").trim(),
        item: String(itemName || "").trim(),
        barcode: item.barcode || item.bar_code || item.barCode || "",
        totalpieces,
        cp,
        boxpiece,
      };
    };

    // already array
    if (Array.isArray(raw)) {
      return raw
        .map(normalizeObject)
        .filter(Boolean);
    }

    // object / map (Firestore map)
    if (typeof raw === "object") {
      // If object values are primitive strings that are JSON, attempt to parse each value
      return Object.values(raw)
        .map(v => {
          if (typeof v === "string" && (v.startsWith("{") || v.startsWith("["))) {
            try { return JSON.parse(v); } catch (e) { return v; }
          }
          return v;
        })
        .map(normalizeObject)
        .filter(Boolean);
    }

    // stringified json
    if (typeof raw === "string") {
      const parsed = JSON.parse(raw);
      return normalizeItems(parsed);
    }

    return [];
  } catch (error) {
    logger.error("normalizeItems error:", error);
    return [];
  }
}

// javascript
exports.syncDamageToStockReport = onDocumentWritten("damageitems/{damageId}", async (event) => {
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const damageId = event.params.damageId;

  const db = admin.firestore();
  const batch = db.batch();
  let hasUpdates = false;

  try {
    // DELETE
    if (before && !after) {
      const companyId = before.companyid;
      const branchId = before.branchid;
      const branchName = before.branchname;
      const updatedBy = before.createdby || "system";
      const today = before.date || new Date().toISOString().split("T")[0];

      if (!companyId || !branchId) {
        logger.warn(`syncDamageToStockReport delete: missing companyid or branchid for ${damageId}`);
        return null;
      }

      const summaryId = `${companyId}_${today}`;
      const stockReportRef = db.collection('stockreport').doc(summaryId);

      const items = normalizeItems(before.item);
      for (const itemData of items) {
        if (!itemData) continue;
        const itemId = itemData.itemid;
        if (!itemId) continue;

        const pieces = toNumber(itemData.totalpieces || 0);
        const cp = toNumber(itemData.cp || 0);
        const damageValue = cp * pieces;
        const boxpieces = toNumber(itemData.boxpiece || 0);
        const cartonqty = toNumber(pieces / boxpieces);

        batch.set(
          stockReportRef,
          {
            companyid: companyId,
            summarydate: today,
            summaryid: summaryId,
            branchbalance: {
              [branchId]: {
                branchId: branchId,
                branchName: branchName,
                lastupdate: admin.firestore.FieldValue.serverTimestamp(),
                branchdamage_qty: admin.firestore.FieldValue.increment(-pieces),
                branchdamage_value: admin.firestore.FieldValue.increment(-damageValue),
                branchstockout_balance: admin.firestore.FieldValue.increment(-pieces),
                branchstockout_value: admin.firestore.FieldValue.increment(-damageValue),
                branchtransaction_count: admin.firestore.FieldValue.increment(1),
                updatedby: updatedBy,
              },
            },
            items: {
              [branchId]: {
                [itemId]: {
                  itemId,
                  item: itemData.item || "",
                  barcode: itemData.barcode || "",
                  lastupdate: admin.firestore.FieldValue.serverTimestamp(),
                  damage_qty: admin.firestore.FieldValue.increment(-pieces),
                  damage_value: admin.firestore.FieldValue.increment(-damageValue),
                  boxpieces: boxpieces,
                  damage_cartonqty: admin.firestore.FieldValue.increment(-cartonqty),
                  stockout_balance: admin.firestore.FieldValue.increment(-pieces),
                  stockout_value: admin.firestore.FieldValue.increment(-damageValue),
                  transaction_count: admin.firestore.FieldValue.increment(1),
                },
              },
            },
          },
          { merge: true }
        );

        hasUpdates = true;
      }

      if (hasUpdates) {
        await batch.commit();
        logger.info(`Damage delete synced: ${damageId}`);
      } else {
        logger.info(`syncDamageToStockReport delete: no valid items for ${damageId}`);
      }

      return null;
    }

    // CREATE / UPDATE
    if (after) {
      const companyId = after.companyid;
      const branchId = after.branchid;
      const branchName = after.branchname;
      const updatedBy = after.updatedby || after.createdby || "system";
      const today = after.dateymd || new Date().toISOString().split("T")[0];

      if (!companyId || !branchId) {
        logger.warn(`syncDamageToStockReport upsert: missing companyid or branchid for ${damageId}`);
        return null;
      }

      const summaryId = `${companyId}_${today}`;
      const stockReportRef = db.collection('stockreport').doc(summaryId);

      const beforeItems = normalizeItems(before?.item);
      const afterItems = normalizeItems(after?.item);

      logger.debug(`syncDamageToStockReport items`, {
        damageId,
        beforeCount: beforeItems.length,
        afterCount: afterItems.length,
        beforeSample: beforeItems.slice(0, 5),
        afterSample: afterItems.slice(0, 5),
      });

      const beforeIds = beforeItems.filter(i => i && i.itemid).map(i => i.itemid);
      const afterIds = afterItems.filter(i => i && i.itemid).map(i => i.itemid);
      const allItemIds = new Set([...beforeIds, ...afterIds]);

      for (const itemId of allItemIds) {
        const beforeItem = beforeItems.find(i => i.itemid === itemId) || {};
        const afterItem = afterItems.find(i => i.itemid === itemId) || {};

        const beforePieces = toNumber(beforeItem.totalpieces || 0);
        const afterPieces = toNumber(afterItem.totalpieces || 0);
        const piecesDelta = afterPieces - beforePieces;

        if (piecesDelta === 0) {
          logger.debug(`syncDamageToStockReport no delta for item`, {
            damageId,
            itemId,
            beforePieces,
            afterPieces,
            beforeItem,
            afterItem,
          });
          continue;
        }

        const cp = toNumber(afterItem.cp || beforeItem.cp || 0);
        const damageValue = cp * piecesDelta;
        const boxpieces=toNumber(afterItem.boxpiece || beforeItem.boxpiece || 0);
        const cartonqty= toNumber(piecesDelta/boxpieces);
      
        batch.set(
          stockReportRef,
          {
            companyid: companyId,
            summarydate: today,
            summaryid: summaryId,
            branchbalance: {
              [branchId]: {
                branchId: branchId,
                branchName: branchName,
                lastupdate: admin.firestore.FieldValue.serverTimestamp(),
                branchdamage_qty: admin.firestore.FieldValue.increment(piecesDelta),
                branchdamage_value: admin.firestore.FieldValue.increment(damageValue),
                branchstockout_balance: admin.firestore.FieldValue.increment(piecesDelta),
                branchstockout_value: admin.firestore.FieldValue.increment(damageValue),
                branchtransaction_count: admin.firestore.FieldValue.increment(1),
                updatedby: updatedBy,
              },
            },
            items: {
              [branchId]: {
                [itemId]: {
                  itemId: itemId,
                  item: afterItem.item || beforeItem.item || "",
                  barcode: afterItem.barcode || beforeItem.barcode || "",
                  lastupdate: admin.firestore.FieldValue.serverTimestamp(),
                  damage_qty: admin.firestore.FieldValue.increment(piecesDelta),
                  damage_value: admin.firestore.FieldValue.increment(damageValue),
                  boxpieces:boxpieces,
                  damage_cartonqty:admin.firestore.FieldValue.increment(cartonqty),
                  stockout_balance: admin.firestore.FieldValue.increment(piecesDelta),
                  stockout_value: admin.firestore.FieldValue.increment(damageValue),
                  transaction_count: admin.firestore.FieldValue.increment(1),
                },
              },
            },
          },
          { merge: true }
        );

        hasUpdates = true;
      }

      if (hasUpdates) {
        await batch.commit();
        logger.info(`Damage synced: ${damageId}`);
      } else {
        logger.info(`syncDamageToStockReport upsert: no delta for ${damageId}`);
      }
    }

    return null;
  } catch (error) {
    logger.error(`Error syncing damage ${damageId}:`, error);
    return null;
  }
});

// Write damageitems to ledger using double-entry accounting.
exports.syncDamageItemsToLedger = onDocumentWritten("damageitems/{damageId}", async (event) => {
  const before = event.data?.before?.data() || null;
  const after = event.data?.after?.data() || null;
  const damageId = event.params.damageId;
  const db = admin.firestore();

  try {
    const existing = await db.collection('ledgers')
      .where('sourceType', '==', 'damageitems')
      .where('sourceId', '==', damageId)
      .get();

    if (!existing.empty) {
      const deleteBatch = db.batch();
      existing.docs.forEach((doc) => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
      logger.info(`Existing damage ledger entries removed for ${damageId}`);
    }

    if (!after) {
      logger.info(`Damage ledger cleanup complete for deleted record ${damageId}`);
      return null;
    }

    await postDamageToLedger(after, damageId);
    logger.info(`Damage ledger entries created for ${damageId}`);
    return null;
  } catch (error) {
    logger.error(`Error syncing damage ledger for ${damageId}:`, error);
    return null;
  }
});

// Update itemsreg branchbalance when stock_request items are supplied
exports.syncStockRequestToItemsreg = onDocumentWritten("stock_request/{requestId}", async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const requestId = event.params.requestId;

  const toNumber = (value) => {
    if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
    if (typeof value === 'string') {
      const parsed = parseFloat(value.trim());
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  };

  const getUpdatedBy = (docData) => (
    docData?.submittedby ||
    docData?.submittedBy ||
    docData?.createdby ||
    docData?.createdBy ||
    'system'
  );

  // Normalize items from array to map by itemid
  const normalizeRequestItems = (docData) => {
    if (!docData) return {};
    const rawItems = docData.items;
    const normalized = {};

    if (Array.isArray(rawItems)) {
      rawItems.forEach((itemData, index) => {
        if (!itemData || typeof itemData !== 'object') return;
        const itemId =
          itemData.itemid ||
          itemData.itemId ||
          itemData.item_id ||
          itemData.id ||
          `${index}`;
        if (!itemId) return;

        const suppliedpieces = toNumber(itemData.suppliedpieces ?? itemData.suppliedPieces ?? 0);
        normalized[itemId] = { suppliedpieces };
      });
    } else if (rawItems && typeof rawItems === 'object') {
      Object.entries(rawItems).forEach(([itemKey, itemData]) => {
        if (!itemData || typeof itemData !== 'object') return;
        const itemId =
          itemData.itemid ||
          itemData.itemId ||
          itemData.item_id ||
          itemData.id ||
          itemKey;
        if (!itemId) return;

        const suppliedpieces = toNumber(itemData.suppliedpieces ?? itemData.suppliedPieces ?? 0);
        normalized[itemId] = { suppliedpieces };
      });
    }

    return normalized;
  };

  try {
    const db = admin.firestore();
    const batch = db.batch();
    let hasUpdates = false;

    // Get the warehouse (supplier) and requesting branch IDs
    const warehouseId = after?.warehouseid || before?.warehouseid;
    const branchId = after?.branchid || before?.branchid;

    if (!warehouseId || !branchId) {
      logger.warn(`Stock request ${requestId} missing warehouseid or branchid`, {
        warehouseId,
        branchId,
      });
      return null;
    }

    const warehouseName = after?.warehousename || before?.warehousename || warehouseId;
    const branchName = after?.branchname || before?.branchname || branchId;
    const updatedBy = getUpdatedBy(after || before);

    const beforeItems = normalizeRequestItems(before);
    const afterItems = normalizeRequestItems(after);
    const allItemIds = new Set([...Object.keys(beforeItems), ...Object.keys(afterItems)]);

    for (const itemId of allItemIds) {
      const beforeSupplied = beforeItems[itemId]?.suppliedpieces || 0;
      const afterSupplied = afterItems[itemId]?.suppliedpieces || 0;

      const suppliedDelta = toNumber(afterSupplied) - toNumber(beforeSupplied);

      // Only process if there's an actual change in supplied pieces
      if (suppliedDelta === 0) continue;

      const itemRef = db.collection('itemsreg').doc(itemId);

      // Decrease warehouse balance, increase requesting branch balance
      batch.set(
        itemRef,
        {
          branchbalance: {
            [warehouseId]: {
              netpieces: admin.firestore.FieldValue.increment(-suppliedDelta),
              name: warehouseName,
              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
              updatedby: updatedBy,
            },
            [branchId]: {
              netpieces: admin.firestore.FieldValue.increment(suppliedDelta),
              name: branchName,
              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
              updatedby: updatedBy,
            },
          },
          lastModified: admin.firestore.FieldValue.serverTimestamp(),
          lastStockRequestId: requestId,
        },
        {merge: true},
      );

      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
      logger.info(`Processed stock request ${requestId} branchbalance sync: ${[...allItemIds].length} items updated`);
    }

    return null;
  } catch (error) {
    logger.error(`Error syncing stock request ${requestId} to itemsreg:`, error);
    return null;
  }
});
exports.syncDamageItemsToItemsreg = onDocumentWritten(
  "damageitems/{damageId}",
  async (event) => {
    const before = event.data?.before
      ? event.data.before.data()
      : null;

    const after = event.data?.after
      ? event.data.after.data()
      : null;

    const damageId = event.params.damageId;

    const toNumber = (value) => {
      if (typeof value === "number") {
        return Number.isFinite(value) ? value : 0;
      }

      if (typeof value === "string") {
        const parsed = parseFloat(value.trim());
        return Number.isFinite(parsed) ? parsed : 0;
      }

      return 0;
    };

    const resolveBranchId = (docData, itemData) => (
      itemData?.branchid ||
      itemData?.branchId ||
      docData?.branchid ||
      docData?.branchId ||
      null
    );

    const resolveBranchName = (docData, itemData, branchId) => (
      itemData?.branchname ||
      itemData?.branchName ||
      docData?.branchname ||
      docData?.branchName ||
      branchId
    );

    const resolveUpdatedBy = (docData) => (
      docData?.updatedby ||
      docData?.updatedBy ||
      docData?.createdby ||
      docData?.createdBy ||
      "system"
    );

    const normalizeDamageItems = (docData) => {
      if (!docData) return {};

      const rawItems = docData.item || docData.items;
      const normalized = {};

      if (Array.isArray(rawItems)) {
        rawItems.forEach((itemData, index) => {
          if (!itemData || typeof itemData !== "object") return;

          const itemId =
            itemData.itemid ||
            itemData.itemId ||
            itemData.item_id ||
            itemData.id ||
            `${index}`;

          if (!itemId) return;

          const totalpieces = toNumber(
            itemData.totalpieces ??
            itemData.totalPieces ??
            itemData.pieces ??
            0
          );

          const branchId = resolveBranchId(docData, itemData);

          const current = normalized[itemId] || {
            itemId,
            totalpieces: 0,
            branchId,
            itemData,
          };

          current.totalpieces += totalpieces;

          if (!current.branchId && branchId) {
            current.branchId = branchId;
          }

          if (!current.itemData && itemData) {
            current.itemData = itemData;
          }

          normalized[itemId] = current;
        });

        return normalized;
      }

      if (rawItems && typeof rawItems === "object") {
        Object.entries(rawItems).forEach(([itemKey, itemData]) => {
          if (!itemData || typeof itemData !== "object") return;

          const itemId =
            itemData.itemid ||
            itemData.itemId ||
            itemData.item_id ||
            itemData.id ||
            itemKey;

          if (!itemId) return;

          const totalpieces = toNumber(
            itemData.totalpieces ??
            itemData.totalPieces ??
            itemData.pieces ??
            0
          );

          const branchId = resolveBranchId(docData, itemData);

          const current = normalized[itemId] || {
            itemId,
            totalpieces: 0,
            branchId,
            itemData,
          };

          current.totalpieces += totalpieces;

          if (!current.branchId && branchId) {
            current.branchId = branchId;
          }

          if (!current.itemData && itemData) {
            current.itemData = itemData;
          }

          normalized[itemId] = current;
        });
      }

      return normalized;
    };

    try {
      const db = admin.firestore();

      const batch = db.batch();

      let hasUpdates = false;

      const beforeItems = normalizeDamageItems(before);
      const afterItems = normalizeDamageItems(after);

      const allItemIds = new Set([
        ...Object.keys(beforeItems),
        ...Object.keys(afterItems),
      ]);

      /*
       * Dashboard stock-value changes.
       *
       * branchStockValues:
       *   branchId -> {
       *     value,
       *     name
       *   }
       */
      const branchStockValues = new Map();

      /*
       * Company ID used by dashbaord_stats.
       *
       * Keep the existing company ID structure from the damage document.
       */
      const companyid =
        after?.companyid ||
        after?.companyId ||
        before?.companyid ||
        before?.companyId ||
        null;

      for (const itemId of allItemIds) {
        const beforeItem = beforeItems[itemId] || {
          totalpieces: 0,
          branchId: null,
          itemData: null,
        };

        const afterItem = afterItems[itemId] || {
          totalpieces: 0,
          branchId: null,
          itemData: null,
        };

        const beforePieces = toNumber(beforeItem.totalpieces);
        const afterPieces = toNumber(afterItem.totalpieces);

        const piecesDelta = afterPieces - beforePieces;

        const beforeBranchId =
          beforeItem.branchId ||
          resolveBranchId(before, beforeItem.itemData);

        const afterBranchId =
          afterItem.branchId ||
          resolveBranchId(after, afterItem.itemData);

        const beforeBranchName = resolveBranchName(
          before,
          beforeItem.itemData,
          beforeBranchId
        );

        const afterBranchName = resolveBranchName(
          after,
          afterItem.itemData,
          afterBranchId
        );

        const updatedBy = resolveUpdatedBy(after || before);

        const itemRef = db
          .collection("itemsreg")
          .doc(itemId);

        /*
         * Get current cost price.
         *
         * itemsreg.cp is the normal cost price.
         */
        let costPrice = 0;

        const itemSnapshot = await itemRef.get();

        if (itemSnapshot.exists) {
          const itemRegData = itemSnapshot.data() || {};

          costPrice = toNumber(itemRegData.cp);

          /*
           * Fallback to damage item CP if itemsreg.cp
           * is not available.
           */
          if (costPrice === 0) {
            costPrice = toNumber(
              afterItem.itemData?.cp ??
              afterItem.itemData?.costprice ??
              afterItem.itemData?.costPrice ??
              beforeItem.itemData?.cp ??
              beforeItem.itemData?.costprice ??
              beforeItem.itemData?.costPrice ??
              0
            );
          }
        } else {
          costPrice = toNumber(
            afterItem.itemData?.cp ??
            afterItem.itemData?.costprice ??
            afterItem.itemData?.costPrice ??
            beforeItem.itemData?.cp ??
            beforeItem.itemData?.costprice ??
            beforeItem.itemData?.costPrice ??
            0
          );
        }

        /*
         * -------------------------------------------------------
         * EXISTING DAMAGE BRANCH LOGIC
         * -------------------------------------------------------
         */

        // If branch changed for an item,
        // reverse old branch and apply new branch.
        if (
          beforeBranchId &&
          afterBranchId &&
          beforeBranchId !== afterBranchId
        ) {
          if (beforePieces !== 0) {
            batch.update(
              itemRef,
              ...branchBalanceUpdateArgs(
                beforeBranchId,
                {
                  netpieces:
                    admin.firestore.FieldValue.increment(
                      beforePieces
                    ),

                  name: beforeBranchName,

                  lastupdate:
                    admin.firestore.FieldValue.serverTimestamp(),

                  updatedby: updatedBy,
                }
              ),

              "lastModified",
              admin.firestore.FieldValue.serverTimestamp(),

              "lastDamageId",
              damageId
            );

            hasUpdates = true;

            /*
             * Dashboard:
             *
             * Reversing the old damage restores stock value.
             *
             * + beforePieces * CP
             */
            if (companyid && costPrice !== 0) {
              const value =
                beforePieces * costPrice;

              const existing =
                branchStockValues.get(beforeBranchId) || {
                  value: 0,
                  name: beforeBranchName,
                };

              existing.value += value;

              if (!existing.name) {
                existing.name = beforeBranchName;
              }

              branchStockValues.set(
                beforeBranchId,
                existing
              );
            }
          }

          if (afterPieces !== 0) {
            batch.update(
              itemRef,
              ...branchBalanceUpdateArgs(
                afterBranchId,
                {
                  netpieces:
                    admin.firestore.FieldValue.increment(
                      -afterPieces
                    ),

                  name: afterBranchName,

                  lastupdate:
                    admin.firestore.FieldValue.serverTimestamp(),

                  updatedby: updatedBy,
                }
              ),

              "lastModified",
              admin.firestore.FieldValue.serverTimestamp(),

              "lastDamageId",
              damageId
            );

            hasUpdates = true;

            /*
             * Dashboard:
             *
             * Applying new damage reduces stock value.
             *
             * - afterPieces * CP
             */
            if (companyid && costPrice !== 0) {
              const value =
                -afterPieces * costPrice;

              const existing =
                branchStockValues.get(afterBranchId) || {
                  value: 0,
                  name: afterBranchName,
                };

              existing.value += value;

              if (!existing.name) {
                existing.name = afterBranchName;
              }

              branchStockValues.set(
                afterBranchId,
                existing
              );
            }
          }

          continue;
        }

        const effectiveBranchId =
          afterBranchId || beforeBranchId;

        const effectiveBranchName =
          afterBranchName ||
          beforeBranchName ||
          effectiveBranchId;

        if (
          !effectiveBranchId ||
          piecesDelta === 0
        ) {
          continue;
        }

        /*
         * Damage increase reduces branch stock.
         *
         * Damage decrease/delete restores branch stock.
         */
        batch.update(
          itemRef,

          ...branchBalanceUpdateArgs(
            effectiveBranchId,
            {
              netpieces:
                admin.firestore.FieldValue.increment(
                  -piecesDelta
                ),

              name: effectiveBranchName,

              lastupdate:
                admin.firestore.FieldValue.serverTimestamp(),

              updatedby: updatedBy,
            }
          ),

          "lastModified",
          admin.firestore.FieldValue.serverTimestamp(),

          "lastDamageId",
          damageId
        );

        hasUpdates = true;

        /*
         * -------------------------------------------------------
         * DASHBOARD STOCK VALUE
         * -------------------------------------------------------
         *
         * piecesDelta > 0
         *     damage increased
         *     stock value decreases
         *
         * piecesDelta < 0
         *     damage decreased/deleted
         *     stock value increases
         *
         * Therefore:
         *
         * valueDelta = -piecesDelta * CP
         */
        if (companyid && costPrice !== 0) {
          const valueDelta =
            -piecesDelta * costPrice;

          const existing =
            branchStockValues.get(
              effectiveBranchId
            ) || {
              value: 0,
              name: effectiveBranchName,
            };

          existing.value += valueDelta;

          if (!existing.name) {
            existing.name = effectiveBranchName;
          }

          branchStockValues.set(
            effectiveBranchId,
            existing
          );
        }
      }

      /*
       * -------------------------------------------------------
       * COMMIT ITEMSREG UPDATES
       * -------------------------------------------------------
       */

      if (hasUpdates) {
        await batch.commit();

        /*
         * -------------------------------------------------------
         * UPDATE dashbaord_stats
         * -------------------------------------------------------
         */

        if (
          companyid &&
          branchStockValues.size > 0
        ) {
          const statsRef = db
            .collection("dashbaord_stats")
            .doc(companyid);

          await db.runTransaction(
            async (transaction) => {
              let totalStockValue = 0;

              const updateArgs = [];

              for (
                const [
                  branchId,
                  data,
                ] of branchStockValues.entries()
              ) {
                if (data.value === 0) {
                  continue;
                }

                updateArgs.push(
                  new admin.firestore.FieldPath(
                    "branchstock",
                    branchId,
                    "stock_value"
                  ),

                  admin.firestore.FieldValue.increment(
                    data.value
                  ),

                  new admin.firestore.FieldPath(
                    "branchstock",
                    branchId,
                    "branchname"
                  ),

                  data.name
                );

                totalStockValue += data.value;
              }

              /*
               * Update total stock value.
               */
              transaction.set(
                statsRef,
                {
                  companyId: companyid,

                  updatedAt:
                    admin.firestore.FieldValue
                      .serverTimestamp(),

                  stock_in_total:
                    admin.firestore.FieldValue.increment(
                      totalStockValue
                    ),
                },
                {
                  merge: true,
                }
              );

              /*
               * Update each branch's stock value.
               */
              if (updateArgs.length > 0) {
                transaction.update(
                  statsRef,
                  ...updateArgs
                );
              }
            }
          );
        }

        logger.info(
          `Processed damageitems ${damageId} branchbalance and dashboard stock-value sync.`
        );
      }

      return null;
    } catch (error) {
      logger.error(
        `Error syncing damageitems ${damageId} to itemsreg:`,
        error
      );

      return null;
    }
  }
);
// Update itemsreg branchbalance when damageitems are created/updated/deleted
//exports.syncDamageItemsToItemsreg = onDocumentWritten("damageitems/{damageId}", async (event) => {
//  const before = event.data?.before ? event.data.before.data() : null;
//  const after = event.data?.after ? event.data.after.data() : null;
//  const damageId = event.params.damageId;
//
//  const toNumber = (value) => {
//    if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
//    if (typeof value === 'string') {
//      const parsed = parseFloat(value.trim());
//      return Number.isFinite(parsed) ? parsed : 0;
//    }
//    return 0;
//  };
//
//  const resolveBranchId = (docData, itemData) => (
//    itemData?.branchid ||
//    itemData?.branchId ||
//    docData?.branchid ||
//    docData?.branchId ||
//    null
//  );
//
//  const resolveBranchName = (docData, itemData, branchId) => (
//    itemData?.branchname ||
//    itemData?.branchName ||
//    docData?.branchname ||
//    docData?.branchName ||
//    branchId
//  );
//
//  const resolveUpdatedBy = (docData) => (
//    docData?.updatedby ||
//    docData?.updatedBy ||
//    docData?.createdby ||
//    docData?.createdBy ||
//    "system"
//  );
//
//  const normalizeDamageItems = (docData) => {
//    if (!docData) return {};
//    const rawItems = docData.item || docData.items;
//    const normalized = {};
//
//    if (Array.isArray(rawItems)) {
//      rawItems.forEach((itemData, index) => {
//        if (!itemData || typeof itemData !== "object") return;
//
//        const itemId =
//          itemData.itemid ||
//          itemData.itemId ||
//          itemData.item_id ||
//          itemData.id ||
//          `${index}`;
//        if (!itemId) return;
//
//        const totalpieces = toNumber(itemData.totalpieces ?? itemData.totalPieces ?? itemData.pieces ?? 0);
//        const branchId = resolveBranchId(docData, itemData);
//        const current = normalized[itemId] || {
//          itemId,
//          totalpieces: 0,
//          branchId,
//          itemData,
//        };
//
//        current.totalpieces += totalpieces;
//        if (!current.branchId && branchId) current.branchId = branchId;
//        if (!current.itemData && itemData) current.itemData = itemData;
//        normalized[itemId] = current;
//      });
//      return normalized;
//    }
//
//    if (rawItems && typeof rawItems === "object") {
//      Object.entries(rawItems).forEach(([itemKey, itemData]) => {
//        if (!itemData || typeof itemData !== "object") return;
//
//        const itemId =
//          itemData.itemid ||
//          itemData.itemId ||
//          itemData.item_id ||
//          itemData.id ||
//          itemKey;
//        if (!itemId) return;
//
//        const totalpieces = toNumber(itemData.totalpieces ?? itemData.totalPieces ?? itemData.pieces ?? 0);
//        const branchId = resolveBranchId(docData, itemData);
//        const current = normalized[itemId] || {
//          itemId,
//          totalpieces: 0,
//          branchId,
//          itemData,
//        };
//
//        current.totalpieces += totalpieces;
//        if (!current.branchId && branchId) current.branchId = branchId;
//        if (!current.itemData && itemData) current.itemData = itemData;
//        normalized[itemId] = current;
//      });
//    }
//
//    return normalized;
//  };
//
//  try {
//    const db = admin.firestore();
//    const batch = db.batch();
//    let hasUpdates = false;
//
//    const beforeItems = normalizeDamageItems(before);
//    const afterItems = normalizeDamageItems(after);
//    const allItemIds = new Set([...Object.keys(beforeItems), ...Object.keys(afterItems)]);
//
//    for (const itemId of allItemIds) {
//      const beforeItem = beforeItems[itemId] || {totalpieces: 0, branchId: null, itemData: null};
//      const afterItem = afterItems[itemId] || {totalpieces: 0, branchId: null, itemData: null};
//
//      const beforePieces = toNumber(beforeItem.totalpieces);
//      const afterPieces = toNumber(afterItem.totalpieces);
//      const piecesDelta = afterPieces - beforePieces;
//
//      const beforeBranchId = beforeItem.branchId || resolveBranchId(before, beforeItem.itemData);
//      const afterBranchId = afterItem.branchId || resolveBranchId(after, afterItem.itemData);
//      const beforeBranchName = resolveBranchName(before, beforeItem.itemData, beforeBranchId);
//      const afterBranchName = resolveBranchName(after, afterItem.itemData, afterBranchId);
//
//      const updatedBy = resolveUpdatedBy(after || before);
//      const itemRef = db.collection("itemsreg").doc(itemId);
//
//      // If branch changed for an item, reverse old branch and apply new branch.
//      if (beforeBranchId && afterBranchId && beforeBranchId !== afterBranchId) {
//        if (beforePieces !== 0) {
//          batch.update(
//            itemRef,
//            ...branchBalanceUpdateArgs(beforeBranchId, {
//              netpieces: admin.firestore.FieldValue.increment(beforePieces),
//              name: beforeBranchName,
//              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
//              updatedby: updatedBy,
//            }),
//            "lastModified",
//            admin.firestore.FieldValue.serverTimestamp(),
//            "lastDamageId",
//            damageId,
//          );
//          hasUpdates = true;
//        }
//
//        if (afterPieces !== 0) {
//          batch.update(
//            itemRef,
//            ...branchBalanceUpdateArgs(afterBranchId, {
//              netpieces: admin.firestore.FieldValue.increment(-afterPieces),
//              name: afterBranchName,
//              lastupdate: admin.firestore.FieldValue.serverTimestamp(),
//              updatedby: updatedBy,
//            }),
//            "lastModified",
//            admin.firestore.FieldValue.serverTimestamp(),
//            "lastDamageId",
//            damageId,
//          );
//          hasUpdates = true;
//        }
//        continue;
//      }
//
//      const effectiveBranchId = afterBranchId || beforeBranchId;
//      const effectiveBranchName = afterBranchName || beforeBranchName || effectiveBranchId;
//
//      if (!effectiveBranchId || piecesDelta === 0) continue;
//
//      // Damage increase reduces branch stock; damage decrease/delete restores stock.
//      batch.update(
//        itemRef,
//        ...branchBalanceUpdateArgs(effectiveBranchId, {
//          netpieces: admin.firestore.FieldValue.increment(-piecesDelta),
//          name: effectiveBranchName,
//          lastupdate: admin.firestore.FieldValue.serverTimestamp(),
//          updatedby: updatedBy,
//        }),
//        "lastModified",
//        admin.firestore.FieldValue.serverTimestamp(),
//        "lastDamageId",
//        damageId,
//      );
//
//   hasUpdates = true;
//    }
//
//    if (hasUpdates) {
//      await batch.commit();
//      logger.info(`Processed damageitems ${damageId} branchbalance sync.`);
//    }
//
//    return null;
//  } catch (error) {
//    logger.error(`Error syncing damageitems ${damageId} to itemsreg:`, error);
//    return null;
//  }
//});

// Handles CREATE, UPDATE, and DELETE operations with proper data source fallbacks
exports.syncSalesReturnToItemsreg = onDocumentWritten("salesreturn/{returnId}", async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const returnId = event.params.returnId;

  const toNumber = (value) => {
    if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
    if (typeof value === 'string') {
      const parsed = parseFloat(value.trim());
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  };

  const resolveUpdatedBy = (docData) => (
    docData?.returned_updatedby ||
    docData?.returned_updatedBy ||
    docData?.updatedBy ||
    docData?.updatedby ||
    docData?.createdBy ||
    docData?.createdby ||
    "system"
  );

  const resolveItemId = (itemData, itemKey) => (
    itemData?.returned_itemid ||
    itemData?.returned_itemId ||
    itemData?.itemid ||
    itemData?.itemId ||
    itemData?.item_id ||
    itemData?.id ||
    itemData?.productId ||
    itemKey
  );

  
  const resolveItemBranchId = (docData, itemData) => (
    itemData?.returned_branchid ||
    itemData?.returned_branchId ||
    docData?.returned_branchid ||
    docData?.returned_branchId ||
    null
  );

  const resolveItemBranchName = (docData, itemData, branchId) => (
    itemData?.returned_branchname ||
    itemData?.returned_branchName ||
    docData?.returned_branchname ||
    docData?.returned_branchName ||
    branchId
  );

  const resolveReturnAmount = (itemData) => {
    const explicitAmount = toNumber(
      itemData?.returned_totalamount ??
      itemData?.returned_amount ??
      itemData?.totalamount ??
      itemData?.amount ??
      0
    );

    if (explicitAmount > 0) return explicitAmount;

    const grossAmount = toNumber(itemData?.returned_grosstotalamount ?? itemData?.grossamount ?? 0);
    const lineDiscount = toNumber(itemData?.returned_discount ?? itemData?.discount ?? 0);
    if (grossAmount > 0) return Math.max(grossAmount - lineDiscount, 0);

    const returnedQty = toNumber(itemData?.returned_quantity ?? itemData?.returned_qty ?? 0);
    const returnedUnitPrice = toNumber(
      itemData?.returned_price ??
      itemData?.price ??
      itemData?.unitprice ??
      itemData?.unitPrice ??
      0
    );

    return returnedQty > 0 && returnedUnitPrice > 0 ? returnedQty * returnedUnitPrice : 0;
  };

  const resolveReturnProfit = (itemData) => {
    const explicitProfit = toNumber(
      itemData?.returned_profit ??
      itemData?.returnedProfit ??
      itemData?.profit ??
      0
    );

    if (explicitProfit !== 0) return explicitProfit;

    const returnedQty = toNumber(itemData?.returned_quantity ?? itemData?.returned_qty ?? 0);
    const returnedPieces = toNumber(
      itemData?.returned_totalpieces ??
      itemData?.returned_pieces ??
      itemData?.returnedpieces ??
      itemData?.returnedPieces ??
      0
    );
    const returnedCost = toNumber(itemData?.returned_cp ?? itemData?.cp ?? 0);
    const lineAmount = resolveReturnAmount(itemData);
    const costUnits = returnedPieces > 0 ? returnedPieces : returnedQty;

    return returnedCost > 0 && costUnits > 0 ? lineAmount - (costUnits * returnedCost) : 0;
  };

  const normalizeReturnItems = (docData) => {
    if (!docData) return {};
    const rawItems = docData.returned_items || docData.items;
    const normalized = {};

    if (Array.isArray(rawItems)) {
      rawItems.forEach((itemData, index) => {
        if (!itemData || typeof itemData !== "object") return;

        const itemId = resolveItemId(itemData, `item_${index}`);
        if (!itemId) return;

        const explicitReturnedPieces = toNumber(
          itemData.returned_totalpieces ??
          itemData.returned_pieces ??
          itemData.returnedpieces ??
          itemData.returnedPieces ??
          0
        );
        const returnedQty = toNumber(itemData.returned_quantity ?? itemData.returned_qty ?? 0);
        const returnedModeQty = toNumber(itemData.returned_modeqty ?? itemData.returned_modeQty ?? 0);
        const computedReturnedPieces = returnedQty * returnedModeQty;
        const returnedpieces = computedReturnedPieces > 0 ? computedReturnedPieces : explicitReturnedPieces;

        const branchId = resolveItemBranchId(docData, itemData);
        const branchName = resolveItemBranchName(docData, itemData, branchId);
        const itemName=(itemData.returned_item);
        const itemBarcode=(itemData.returned_barcode);
        const companyid=(docData.returned_companyid);
        const returnGrossAmount=(docData.returned_grosstotalamount);
        const return_grossdiscount=(docData.returned_discount);
        const returnPrice=(docData.returned_price);
        const returnstaff=(docData.returned_staff);
        const returned_transMode=(docData.returned_transMode);
        const returned_discount = toNumber(
          itemData.returned_discount ??
          itemData.returned_discountAmount ??
          docData.returned_discount ??
          0
        );
        const returnAmount = resolveReturnAmount(itemData);
        const returned_profit = resolveReturnProfit(itemData);
        const current = normalized[itemId] || {
          itemId,
          returnedpieces: 0,
          branchId,
          branchName,
          itemBarcode,
          itemName,
          companyid,
          returnAmount:0,
          returnPrice,
          returnstaff,
          returned_transMode,
          returned_discount:0,
          returned_profit:0,
          return_grossdiscount,
        };
        current.returnedpieces += returnedpieces;
        current.returned_discount += returned_discount;
        current.returnAmount += returnAmount;
        current.returned_profit += returned_profit;
        if (!current.branchId && branchId) current.branchId = branchId;
        if (!current.branchName && branchName) current.branchName = branchName;
        normalized[itemId] = current;
      });
    } else if (rawItems && typeof rawItems === "object") {
      Object.entries(rawItems).forEach(([itemKey, itemData]) => {
        if (!itemData || typeof itemData !== "object") return;

        const itemId = resolveItemId(itemData, itemKey);
        if (!itemId) return;

        const explicitReturnedPieces = toNumber(
          itemData.returned_totalpieces ??
          itemData.returned_pieces ??
          itemData.returnedpieces ??
          itemData.returnedPieces ??
          0
        );
        const returnedQty = toNumber(itemData.returned_quantity ?? itemData.returned_qty ?? 0);
        const returnedModeQty = toNumber(itemData.returned_modeqty ?? itemData.returned_modeQty ?? 0);
        const computedReturnedPieces = returnedQty * returnedModeQty;
        const returnedpieces = computedReturnedPieces > 0 ? computedReturnedPieces : explicitReturnedPieces;

        const branchId = resolveItemBranchId(docData, itemData);
        const branchName = resolveItemBranchName(docData, itemData, branchId);
         const itemName=(itemData.returned_item);
        const itemBarcode=(itemData.returned_barcode);
        const companyid=(docData.returned_companyid);
        const returnGrossAmount=(docData.returned_grosstotalamount);
        const return_grossdiscount=(docData.return_grossdiscount);
        const returnPrice=(docData.returned_price);
        const returnstaff=(docData.returned_staff);
        const returned_transMode=(docData.returned_transMode);
       const returned_discount = toNumber(itemData.returned_discount ?? itemData.returned_discountAmount ?? docData.returned_discount ?? 0
        );
       const returnAmount = resolveReturnAmount(itemData);
      const returned_profit = resolveReturnProfit(itemData);

        const current = normalized[itemId] || {
          itemId,
          returnedpieces: 0,
          branchId,
          branchName,
          itemBarcode,
          itemName,
          companyid,
          returnAmount:0,
          returnPrice,
          returnstaff,
          returned_transMode,
          returned_discount:0,
          returned_profit:0,
          return_grossdiscount,
        };
        current.returnedpieces += returnedpieces;
        current.returned_discount += returned_discount;
        current.returnAmount += returnAmount;
        current.returned_profit += returned_profit;
        if (!current.branchId && branchId) current.branchId = branchId;
        if (!current.branchName && branchName) current.branchName = branchName;
        normalized[itemId] = current;
      });
    }

    return normalized;
  };

  try {
    const db = admin.firestore();
    const batch = db.batch();
    let hasUpdates = false;

    // Explicitly detect operation type
    const isDelete = !after && before;
    const isCreate = after && !before;

    // Use before data for metadata on delete, after data otherwise
    const docForMetadata = after || before;
    const companyid = docForMetadata?.returned_companyid;
    const today = docForMetadata?.dateymd;
    const staffEmail = docForMetadata?.staffemail || "system";
    const staffName = docForMetadata?.returned_staff;
    const returned_transMode = docForMetadata?.returned_transMode || "system";

    // Early validation of critical fields
    if (!companyid || !today) {
      logger.warn(`Sales return ${returnId} missing required metadata (companyid or dateymd). Operation: ${isDelete ? 'DELETE' : isCreate ? 'CREATE' : 'UPDATE'}`);
      return null;
    }

    const beforeItems = normalizeReturnItems(before);
    const afterItems = normalizeReturnItems(after);
    const allItemIds = new Set([...Object.keys(beforeItems), ...Object.keys(afterItems)]);
    const updatedBy = resolveUpdatedBy(docForMetadata);
    const branchStockValues = new Map();
    for (const itemId of allItemIds) {
      const beforeItem = beforeItems[itemId] || {returnedpieces: 0, branchId: null, branchName: null};
      const afterItem = afterItems[itemId] || {returnedpieces: 0, branchId: null, branchName: null};

      const beforePieces = toNumber(beforeItem.returnedpieces);
      const afterPieces = toNumber(afterItem.returnedpieces);
      const piecesDelta = afterPieces - beforePieces;

      const afterValue = toNumber(afterItem.returnAmount);
      const beforeValue = toNumber(beforeItem.returnAmount);
      const returnValue= afterValue-beforeValue;

      const afterProfit=toNumber(afterItem.returned_profit);
      const beforeProfit=toNumber(beforeItem.returned_profit);

      const returned_profit=afterProfit-beforeProfit;

      const beforeDiscount=toNumber(beforeItem.returned_discount);
      const afterDiscount=toNumber(afterItem.returned_discount);
      const returned_discount=afterDiscount-beforeDiscount;

      const branchId = afterItem.branchId || beforeItem.branchId;
      const branchName = afterItem.branchName || beforeItem.branchName || branchId;

      const return_netAmount = returnValue || 0;
      const costof_goods = return_netAmount - toNumber(returned_profit);
      const returnSalesValue = return_netAmount + toNumber(returned_discount);
      const current = branchStockValues.get(branchId) || {
        value: 0,
        name: branchName,
      };



      // Skip if no change
      if (piecesDelta === 0) continue;
       const stockValueDelta =
           isDelete ? -costof_goods : costof_goods;

       current.value += stockValueDelta;
      branchStockValues.set(branchId, current);
      if (!branchId) {
        logger.warn(`Sales return ${returnId} missing returned_branchid for item ${itemId}`);
        continue;
      }



      // Log operation type for debugging
      if (isDelete) {
        logger.info(`DELETE: sales return ${returnId}, item ${itemId}, pieces delta: ${piecesDelta}`);
      } else if (isCreate) {
        logger.info(`CREATE: sales return ${returnId}, item ${itemId}, pieces delta: ${piecesDelta}`);
      }

      const itemRef = db.collection("itemsreg").doc(itemId);

      // Increase branch balance for returned pieces (restore inventory)
      batch.update(
        itemRef,
        ...branchBalanceUpdateArgs(branchId, {
          netpieces: admin.firestore.FieldValue.increment(piecesDelta),
          name: branchName,
          lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          updatedby: updatedBy,
        }),
        "lastModified",
        admin.firestore.FieldValue.serverTimestamp(),
        "lastSalesReturnId",
        returnId,
      );

      // Daily stockReport collection reference
      const salesSummarydocId = `${companyid}_${today}`;
      const dailyRef = db.collection('stockreport').doc(salesSummarydocId);

      batch.set(
        dailyRef,
        {
        companyid: companyid,
        summarydate:today,
        summaryid:salesSummarydocId,
          branchbalance: {
            [branchId]: {
              branchId: branchId,
              branchName: branchName,
              lastupdate:admin.firestore.FieldValue.serverTimestamp(),
              summaryid:salesSummarydocId,
              branchstockin_balance:admin.firestore.FieldValue.increment(piecesDelta),
              branchsales_value:admin.firestore.FieldValue.increment(-returnSalesValue),

              branchsales_qty:admin.firestore.FieldValue.increment(-piecesDelta),
              branchstockout_balance:admin.firestore.FieldValue.increment(-piecesDelta),
              branchtransaction_count:admin.firestore.FieldValue.increment(1),
              summarydate:today,
              updatedby: updatedBy, 
             
            }
          },
             items:{
              [branchId]:{
              branchId: branchId,
              branchName: branchName,
              lastupdate:admin.firestore.FieldValue.serverTimestamp(),
              summaryid:salesSummarydocId,
              [itemId]:{
              itemid: itemId,
              item: afterItems[itemId]?.itemName ||beforeItems[itemId]?.itemName ||"",
              barcode: afterItems[itemId]?.itemBarcode || beforeItems[itemId]?.itemBarcode ||"",
              lastupdate:admin.firestore.FieldValue.serverTimestamp(),
              stockin_balance: admin.firestore.FieldValue.increment(piecesDelta),
              sales_value: admin.firestore.FieldValue.increment(returnSalesValue),
              salesReturn_qty:admin.firestore.FieldValue.increment(piecesDelta),
              sales_qty:admin.firestore.FieldValue.increment(-piecesDelta),
              stockout_balance: admin.firestore.FieldValue.increment(-piecesDelta),
              transaction_count:admin.firestore.FieldValue.increment(1),
              summarydate:today,
                }
              }
                
              }
        },
        { merge: true }
      );

      // Daily salesSummary collection
      const salesSummaryRef = db.collection('salesSummary').doc(salesSummarydocId);
      batch.set(
        salesSummaryRef,
        {
       
            
              companysales_returnsqty: admin.firestore.FieldValue.increment(piecesDelta),
              ['company'+returned_transMode+ '_returns']: admin.firestore.FieldValue.increment(return_netAmount),
              company_returnDiscount:admin.firestore.FieldValue.increment(returned_discount),
              companysales_value:admin.firestore.FieldValue.increment(-returnSalesValue),
              companyCostof_goods:admin.firestore.FieldValue.increment(-costof_goods),
              companytransaction_count:admin.firestore.FieldValue.increment(1),
              company_returnprofit:admin.firestore.FieldValue.increment(toNumber(returned_profit)),
         
              branchSummary: {
            [branchId]: {
             summaryid:salesSummarydocId,
              summarydate:today,
              branchId: branchId,
              branchName: branchName,
              branchlastupdate:admin.firestore.FieldValue.serverTimestamp(),
              branchsales_value:admin.firestore.FieldValue.increment(-returnSalesValue),
              branchsalesReturn_qty: admin.firestore.FieldValue.increment(piecesDelta),
              branchsalesReturn_value:admin.firestore.FieldValue.increment(return_netAmount),
              branch_returnDiscount:admin.firestore.FieldValue.increment(returned_discount),
              ['branch_'+returned_transMode+ '_returns']:admin.firestore.FieldValue.increment(return_netAmount),
              branchtransaction_count:admin.firestore.FieldValue.increment(1),
              branchCostof_goods:admin.firestore.FieldValue.increment(-costof_goods),
              branch_returnprofit:admin.firestore.FieldValue.increment(toNumber(returned_profit)),

               items: {
              [itemId]: {

              itemid: itemId,
              item: afterItems[itemId]?.itemName ||beforeItems[itemId]?.itemName ||"",
              barcode: afterItems[itemId]?.itemBarcode || beforeItems[itemId]?.itemBarcode ||"",
              summaryid:salesSummarydocId,
              summarydate:today,
              lastupdate:admin.firestore.FieldValue.serverTimestamp(),

              [returned_transMode+ '_returns']:admin.firestore.FieldValue.increment(return_netAmount),

              [returned_transMode+ '_returnqty']:admin.firestore.FieldValue.increment(piecesDelta),
              salesReturn_value:admin.firestore.FieldValue.increment(return_netAmount),
              sales_value: admin.firestore.FieldValue.increment(-returnSalesValue),
              return_discount:admin.firestore.FieldValue.increment(returned_discount),
              costof_goods:admin.firestore.FieldValue.increment(-costof_goods),
              transaction_count: admin.firestore.FieldValue.increment(1),
              return_profit:admin.firestore.FieldValue.increment(toNumber(returned_profit)),
              updatedby: updatedBy,
            }
          }
            }
          },
           staffSummary: {
            [branchId]:{
            [staffEmail]: {
              staff:staffName,
              staffemail:staffEmail,
              branchId: branchId,
              branchName: branchName,
              summaryid:salesSummarydocId,
              summarydate:today,
              stafflastupdate:admin.firestore.FieldValue.serverTimestamp(),
              staffsales_value:admin.firestore.FieldValue.increment(-returnSalesValue),
              staff_returndiscount:admin.firestore.FieldValue.increment(returned_discount),
              staffsalesReturn_qty:admin.firestore.FieldValue.increment(piecesDelta),
              staffsalesReturn_value:admin.firestore.FieldValue.increment(return_netAmount),
              [returned_transMode+ '_returns']:admin.firestore.FieldValue.increment(return_netAmount),
              returnprofit:admin.firestore.FieldValue.increment(toNumber(returned_profit)),
              stafftransaction_count:admin.firestore.FieldValue.increment(1),
              staffCostof_goods:admin.firestore.FieldValue.increment(-costof_goods),

            }
          }
          }
        },
        { merge: true }
      );
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
      const statsRef = db.collection("dashbaord_stats").doc(companyid);

      await db.runTransaction(async (transaction) => {
        let totalStockValue = 0;
        const updateArgs = [];

        for (const [branchId, data] of branchStockValues.entries()) {
          updateArgs.push(
            new admin.firestore.FieldPath("branchstock", branchId, "stock_value"),
            admin.firestore.FieldValue.increment(data.value),

            new admin.firestore.FieldPath("branchstock", branchId, "branchname"),
            data.name
          );

          totalStockValue += data.value;
        }

        transaction.set(
          statsRef,
          {
            companyId: companyid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            stock_in_total: admin.firestore.FieldValue.increment(totalStockValue),
          },
          { merge: true }
        );

        if (updateArgs.length > 0) {
          transaction.update(statsRef, ...updateArgs);
        }
      });
      const opType = isDelete ? 'DELETE' : isCreate ? 'CREATE' : 'UPDATE';
      logger.info(`Processed ${opType}: salesreturn ${returnId} branchbalance sync.`);

    }

    return null;
  } catch (error) {
    logger.error(`Error syncing salesreturn ${returnId} to itemsreg:`, error);
    return null;
  }
});

function normalizePurchaseItems(raw) {
  try {
    if (!raw) return [];

    // array
    if (Array.isArray(raw)) {
      return raw.map((item) => ({
        itemid: item.itemid || "",
        item: item.item || "",
        barcode: item.barcode || "",
        pieces: toNumber(item.returnpieces ??item.pieces ?? 0),
        boxpieces: toNumber(item.boxpieces ??item.modeqty ?? 0),
        value: toNumber(item.price ??item.returnvalue ?? 0 ),
      }));
    }

    // firestore map
    if (typeof raw === "object") {
      return Object.values(raw).map((item) => ({
        itemid: item.itemid || "",
        item: item.item || "",
        barcode: item.barcode || "",
        pieces: toNumber(item.returnpieces ??item.pieces ?? 0),
        boxpieces: toNumber(item.boxpieces ??item.modeqty ?? 0),
        value: toNumber(item.price ??item.returnvalue ?? 0),
      }));
    }

    return [];
  } catch (error) {
    logger.error("normalizeItems error:", error);
    return [];
  }
}

exports.syncPurchaseReturnToStockReport = onDocumentWritten( "purchase_returns/{returnId}",
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    const before = beforeSnap?.exists ? beforeSnap.data() : null;
    const after = afterSnap?.exists ? afterSnap.data() : null;

    const returnId = event.params.returnId;

    const db = admin.firestore();
    const batch = db.batch();

    let hasUpdates = false;

    try {
     
      // DELETE
      if (before && !after) {
        const companyId = before.companyid;
        const companyName = before.companyname || "";
        const branchId = before.branchid;
        const branchName = before.branchname || branchId;
        const today = before.date;

        const summaryId = `${companyId}_${today}`;

        const stockReportRef = db.collection("stockreport").doc(summaryId);

        const items = normalizePurchaseItems(before.items);
        let totalStockValue = 0;

        for (const itemData of items) {
          if (!itemData.itemid) continue;

          const itemId = itemData.itemid;
          const boxpieces=toNumber(itemData.boxpieces||1);
          const pieces = toNumber(itemData.pieces);
          const cartonqty=pieces/boxpieces;
          const value = toNumber(itemData.value);
          totalStockValue += value;
          const itemRegRef = db.collection('itemsreg').doc(itemId);

              batch.update(
          itemRegRef,
          ...branchBalanceUpdateArgs(before.branchid, {
            quantity: admin.firestore.FieldValue.increment(pieces),
            stockin_pieces: admin.firestore.FieldValue.increment(pieces),
            netpieces: admin.firestore.FieldValue.increment(pieces),
            stock_value: admin.firestore.FieldValue.increment(value),
            name: before.branchname,
            lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          }),
          'lastModified',
          admin.firestore.FieldValue.serverTimestamp(),
        );
          batch.set(
            stockReportRef,
            {
             summarydate: today,
             summaryid: summaryId,
             companyId: companyId,
              branchbalance: {

                [before.branchid]:{
                   summarydate: today,
                   summaryid: summaryId,
                   branchId:before.branchid,
                  branchpurchaseReturn_qty:admin.firestore.FieldValue.increment(-pieces),
                  branchpurchaseReturn_value:admin.firestore.FieldValue.increment(-value),
                  branchstockout_balance:admin.firestore.FieldValue.increment(-pieces),
                  branchstockout_value:admin.firestore.FieldValue.increment(-value),
                  transaction_count:admin.firestore.FieldValue.increment(1),
                  lastupdate:admin.firestore.FieldValue.serverTimestamp(),
                },
               
              },

              items: {
                [before.branchid]: {
                branchId:before.branchid,
                branchName:before.branchname,

                [itemId]: {
                  branchId:before.branchid,
                  branchName:before.branchname,
                  itemid: itemId,
                  item: itemData.item,
                  barcode: itemData.barcode,
                  cartonqty_in:admin.firestore.FieldValue.increment(-cartonqty),
                  purchaseReturn_cartonqty:admin.firestore.FieldValue.increment(-cartonqty),
                  purchaseReturn_qty:admin.firestore.FieldValue.increment(-pieces),
                  purchaseReturn_value: admin.firestore.FieldValue.increment(-value),
                  stockout_balance:admin.firestore.FieldValue.increment(-pieces),
                  stockout_value:admin.firestore.FieldValue.increment(-value),
                  lastupdate:admin.firestore.FieldValue.serverTimestamp(),
                },
              },
            },
            },
            { merge: true }
          );

          hasUpdates = true;
        }

        if (hasUpdates) {
          await batch.commit();

          if (companyId && totalStockValue !== 0) {
            const statsRef = db.collection('dashbaord_stats').doc(companyId);
            const updateData = {
              companyId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              stock_in_total: admin.firestore.FieldValue.increment(totalStockValue),
            };

            const updateArgs = [
              new admin.firestore.FieldPath('branchstock', branchId, 'stock_value'),
              admin.firestore.FieldValue.increment(totalStockValue),
              new admin.firestore.FieldPath('branchstock', branchId, 'branchname'),
              branchName,
            ];

            await db.runTransaction(async (transaction) => {
              transaction.set(statsRef, updateData, { merge: true });
              transaction.update(statsRef, ...updateArgs);
            });

            logger.info(`Updated dashboard stats for deleted purchase return ${returnId}: +GHS ${totalStockValue.toFixed(2)}`);
          }

          logger.info(
            `Purchase return delete synced: ${returnId}`
          );
        }

        return null;
      }

      // CREATE / UPDATE
      if (after) {
        const companyId = after.companyid;
        const companyName = after.companyname || "";
        const today = after.date;
        const branchId= after.branchid;
        const branchName =after.branchname;
        const summaryId = `${companyId}_${today}`;
        const stockReportRef = db.collection("stockreport").doc(summaryId);
        const beforeItems = normalizePurchaseItems(before?.items);
        const afterItems = normalizePurchaseItems(after?.items);
        let totalStockValue = 0;

        const beforeIds = beforeItems.map((i) => i.itemid);
        const afterIds = afterItems.map((i) => i.itemid);

        const allItemIds = new Set([
          ...beforeIds,
          ...afterIds,
        ]);

        for (const itemId of allItemIds) {
          const beforeItem =beforeItems.find((i) => i.itemid === itemId) || {};

          const afterItem =afterItems.find((i) => i.itemid === itemId) || {};

            const beforePieces = toNumber( beforeItem.pieces || 0);

            const afterPieces = toNumber(afterItem.pieces || 0);
            const boxpieces=toNumber(afterItem.boxpieces || beforeItem.boxpieces || 1);
            const beforeReturnVal = toNumber(beforeItem.value || 0);

            const afterReturnVal = toNumber(afterItem.value || 0);
          
            const piecesDelta =afterPieces - beforePieces;
            const cartonqty = piecesDelta/boxpieces;

          const valueDelta =
            afterReturnVal - beforeReturnVal;
          totalStockValue += valueDelta;

          if (
            piecesDelta === 0 &&
            valueDelta === 0
          ) {
            continue;
          }
        const itemRegRef = db.collection('itemsreg').doc(itemId);

              batch.update(
          itemRegRef,
          ...branchBalanceUpdateArgs(branchId, {
            quantity: admin.firestore.FieldValue.increment(-piecesDelta),
            stockin_pieces: admin.firestore.FieldValue.increment(-piecesDelta),
            netpieces: admin.firestore.FieldValue.increment(-piecesDelta),
            stock_value: admin.firestore.FieldValue.increment(-valueDelta),
            name: branchName,
            lastupdate: admin.firestore.FieldValue.serverTimestamp(),
          }),
          'lastModified',
          admin.firestore.FieldValue.serverTimestamp(),
        );

          batch.set(
            stockReportRef,
            {
               companyid: companyId,

               summarydate: today,
               summaryid: summaryId,
                branchbalance: {
                   companyid: companyId,
                   companyname: companyName,
            
                   summarydate: today,
                   summaryid: summaryId,
                   [branchId]:{
                   branchId:branchId ,
                   branchName:branchName,
                   summarydate: today,
                   summaryid: summaryId,
                   branchpurchaseReturn_qty:admin.firestore.FieldValue.increment(piecesDelta),
                  branchpurchaseReturn_value:admin.firestore.FieldValue.increment(valueDelta),
                  branchstockout_balance:admin.firestore.FieldValue.increment(piecesDelta),
                  branchstockout_value:admin.firestore.FieldValue.increment(valueDelta),
                  transaction_count:admin.firestore.FieldValue.increment(1),
                  lastupdate:admin.firestore.FieldValue.serverTimestamp(),
                },
               
              },

              items: {
            [branchId]: {
             branchId:branchId ,
             branchName:branchName,
              [itemId]: {
              summarydate: today,
              summaryid: summaryId,
              branchId: branchId,
              branchName: branchName,
              itemid: itemId,
              item: afterItem.item || beforeItem.item || "",
              barcode: afterItem.barcode || beforeItem.barcode || "",
              purchaseReturn_qty:admin.firestore.FieldValue.increment(piecesDelta),

              purchaseReturn_value:admin.firestore.FieldValue.increment(valueDelta),
              purchaseReturn_cartonqty:admin.firestore.FieldValue.increment(cartonqty),
              stockout_balance:admin.firestore.FieldValue.increment(piecesDelta),
              boxpieces:boxpieces,
              stockout_value:admin.firestore.FieldValue.increment(valueDelta),

              lastupdate:admin.firestore.FieldValue.serverTimestamp(),
},
              },
              },
            },
            { merge: true }
          );

          hasUpdates = true;
        }

        if (hasUpdates) {
          await batch.commit();

          if (companyId && totalStockValue !== 0) {
            const statsRef = db.collection('dashbaord_stats').doc(companyId);
            const updateData = {
              companyId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              stock_in_total: admin.firestore.FieldValue.increment(totalStockValue),
            };

            const updateArgs = [
              new admin.firestore.FieldPath('branchstock', branchId, 'stock_value'),
              admin.firestore.FieldValue.increment(totalStockValue),
              new admin.firestore.FieldPath('branchstock', branchId, 'branchname'),
              branchName,
            ];

            await db.runTransaction(async (transaction) => {
              transaction.set(statsRef, updateData, { merge: true });
              transaction.update(statsRef, ...updateArgs);
            });

            logger.info(`Updated dashboard stats for purchase return ${returnId}: ${totalStockValue > 0 ? '+' : ''}GHS ${totalStockValue.toFixed(2)}`);
          }

          logger.info(
            `Purchase return synced: ${returnId}`
          );
        } else {
          logger.info(
            `Purchase return no delta: ${returnId}`
          );
        }
      }

      return null;
    } catch (error) {
      logger.error(
        `Error syncing purchase return ${returnId}:`,
        error
      );

      return null;
    }
  }
);
const { postToLedger, postExpenseToLedger } = require("./ledger");
const { postDebtPaymentToLedger, updateSalesSummaryForDebtPayment } = require('./debtpayment');
const { postCreditPaymentToLedger } = require('./creditpayment');
const { postDebtorOpeningBalanceToLedger } = require('./debtorsopenbalance');
const { postCreditorOpeningBalanceToLedger } = require('./creditorsopenbalance');

exports.syncAccountsSummaryForLedgers = onDocumentWritten("ledgers/{ledgerId}", async (event) => {
  try {
    await reconcileAccountsSummary(event);
  } catch (error) {
    logger.error('Error syncing accounts_summary for ledger write:', error);
  }
  return null;
});

exports.syncSalesToLedgers = onDocumentWritten("sales/{saleId}", async (event) => {
  const before = event.data?.before ? event.data.before.data() : null;
  const after = event.data?.after ? event.data.after.data() : null;
  const saleId = event.params.saleId;

  if (!after) return null; // Skip deletes

  try {
    await postToLedger(after, saleId);
  } catch (error) {
    logger.error(`Error syncing sale ${saleId} to ledger:`, error);
  }
});


const { postPurchaseToLedger } = require('./purchaseledger');

async function deleteLedgerEntriesForPurchase(purchaseId) {
  const db = admin.firestore();
  const ledgerRef = db.collection('ledgers');
  // listDocuments returns DocumentReference[]; filter by id prefix used by purchaseledger
  const docs = await ledgerRef.listDocuments();
  const toDelete = docs.filter((d) => d.id === purchaseId || d.id.startsWith(`${purchaseId}_`));
  if (toDelete.length === 0) return;
  const batch = db.batch();
  toDelete.forEach((docRef) => batch.delete(docRef));
  await batch.commit();
  logger.info(`Deleted ${toDelete.length} ledger docs for purchase ${purchaseId}`);
}

async function deleteLedgerEntriesForPurchaseReturn(returnId) {
  const db = admin.firestore();
  const ledgerRef = db.collection('ledgers');
  // Only delete ledger entries for purchase returns (with _return_ pattern)
  const docs = await ledgerRef.listDocuments();
  const toDelete = docs.filter((d) => d.id.startsWith(`${returnId}_return_`));
  if (toDelete.length === 0) return;
  const batch = db.batch();
  toDelete.forEach((docRef) => batch.delete(docRef));
  await batch.commit();
  logger.info(`Deleted ${toDelete.length} ledger docs for purchase return ${returnId}`);
}

exports.onPurchaseWritten = onDocumentWritten('stock_transactions/{purchaseId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const purchaseId = event.params?.purchaseId;

  try {
    if (!before && after) {
      // CREATE
      await postPurchaseToLedger(after, purchaseId);
      logger.info(`Posted purchase ${purchaseId} to ledger (create)`);
    } else if (before && after) {
      // UPDATE: remove previous ledger entries then re-post
      await deleteLedgerEntriesForPurchase(purchaseId);
      await postPurchaseToLedger(after, purchaseId);
      logger.info(`Reposted purchase ${purchaseId} to ledger (update)`);
    } else if (before && !after) {
      // DELETE: remove related ledger entries
      await deleteLedgerEntriesForPurchase(purchaseId);
      logger.info(`Removed ledger entries for deleted purchase ${purchaseId}`);
    }
  } catch (err) {
    logger.error(`Error processing purchase ${purchaseId}:`, err);
    throw err;
  }
});

exports.onPurchaseReturnWritten = onDocumentWritten('purchase_returns/{returnId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const returnId = event.params?.returnId;

  try {
    const normalizeReturnData = (docData) => {
      if (!docData) return null;

      // Calculate returnvalue as sum of net_returnvalue from all items
      const items = Array.isArray(docData.items) ? docData.items : [];
      const calculatedReturnValue = items.reduce((sum, item) => {
        const netReturnValue = toNumber(item?.net_returnvalue ?? 0);
        return sum + netReturnValue;
      }, 0);

      return {
        companyid: docData.companyid,
        company: docData.companyname,
        branchid: docData.branchid,
        branchname: docData.branchname,
        supplierid: docData.supplierid,
        suppliername: docData.suppliername,
        purchasetype: docData.purchasetype,
        invoice: docData.invoice,
        waybill: docData.waybill,
        createdby: docData.createdby,
        date: docData.date,
        items: items.map(item => ({
          itemid: item.itemid,
          item: item.item,
          barcode: item.barcode,
          pieces: toNumber(item.returnpieces ?? 0),
          quantity: toNumber(item.returnquantity ?? 0),
          price: toNumber(item.price ?? 0),
          total: toNumber(item.net_returnvalue ?? 0),
          discount: toNumber(item.discount ?? 0),
        })),
        gross: calculatedReturnValue,
        returnvalue: calculatedReturnValue,
        discount: toNumber(docData.discount ?? 0),
        netval: calculatedReturnValue - toNumber(docData.discount ?? 0),
        purchasereturn: true,
      };
    };

    if (!before && after) {
      // CREATE
      const normalizedData = normalizeReturnData(after);
      await postPurchaseToLedger(normalizedData, returnId);
      logger.info(`Posted purchase return ${returnId} to ledger (create)`);
    } else if (before && after) {
      // UPDATE: remove previous ledger entries then re-post
      await deleteLedgerEntriesForPurchaseReturn(returnId);
      const normalizedData = normalizeReturnData(after);
      await postPurchaseToLedger(normalizedData, returnId);
      logger.info(`Reposted purchase return ${returnId} to ledger (update)`);
    } else if (before && !after) {
      // DELETE: remove related ledger entries
      await deleteLedgerEntriesForPurchaseReturn(returnId);
      logger.info(`Removed ledger entries for deleted purchase return ${returnId}`);
    }
  } catch (err) {
    logger.error(`Error processing purchase return ${returnId}:`, err);
    throw err;
  }
});

exports.onExpenseWritten = onDocumentWritten('expenses/{expenseId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const expenseId = event.params?.expenseId;

  try {
    if (!before && after) {
      await postExpenseToLedger(after, expenseId);
      await updateDashboardExpense(
          after,
          toNumber(after.amount),
          "CREATE"
        );

      logger.info(`Posted expense ${expenseId} to ledger (create)`);
    } else if (before && after) {
      await deleteLedgerEntriesForPurchase(expenseId);
      await postExpenseToLedger(after, expenseId);
        const oldAmount = toNumber(before.amount);
        const newAmount = toNumber(after.amount);
        const difference = newAmount - oldAmount;
      await updateDashboardExpense(after,difference,"UPDATE");
      logger.info(`Reposted expense ${expenseId} to ledger (update)`);
    } else if (before && !after) {
      await deleteLedgerEntriesForPurchase(expenseId);
      await updateDashboardExpense(before,-toNumber(before.amount),"DELETE" );
      logger.info(`Removed ledger entries for deleted expense ${expenseId}`);
    }
  } catch (err) {
    logger.error(`Error processing expense ${expenseId}:`, err);
    throw err;
  }
});

exports.onDebtPaymentWritten = onDocumentWritten('debtpayment/{paymentId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const paymentId = event.params?.paymentId;

  try {
    if (!before && after) {
      await postDebtPaymentToLedger(after, paymentId);
      await updateSalesSummaryForDebtPayment({ beforeData: null, afterData: after, paymentId });
      logger.info(`Posted debt payment ${paymentId} to ledger and updated sales summary (create)`);
    } else if (before && after) {
      await deleteLedgerEntriesForPurchase(paymentId);
      await postDebtPaymentToLedger(after, paymentId);
      await updateSalesSummaryForDebtPayment({ beforeData: before, afterData: after, paymentId });
      logger.info(`Reposted debt payment ${paymentId} to ledger and updated sales summary (update)`);
    } else if (before && !after) {
      await deleteLedgerEntriesForPurchase(paymentId);
      await updateSalesSummaryForDebtPayment({ beforeData: before, afterData: null, paymentId });
      logger.info(`Removed ledger entries for deleted debt payment ${paymentId} and updated sales summary (delete)`);
    }
  } catch (err) {
    logger.error(`Error processing debt payment ${paymentId}:`, err);
    throw err;
  }
});

async function updateDebtorOpeningCreditBalance( balanceData = {}, amount, operation = "add" ) {
 const db = admin.firestore();
 const companyId = balanceData.companyId || balanceData.companyid || null;
 const branchId = balanceData.branchId || balanceData.branchid || null;
 const branchName = balanceData.branchName || balanceData.branchname || branchId || null;
 const value = toNumber(amount);
 if (!companyId || !branchId || value === 0) {
 logger.warn( "Skipping opening_credit_bal dashboard update",
  { companyId, branchId, value, operation, } );
   return;
   }
  const dashboardRef = db .collection("dashbaord_stats") .doc(companyId);
  let delta = value;
  if (operation === "remove") { delta = -value; }
  await dashboardRef.set(
  { branchsales: { [branchId]:
  { branchname: branchName,
   opening_credit_bal: admin.firestore.FieldValue.increment(delta),
  },
   },
    },
     { merge: true, } );
     logger.info( `opening_credit_bal ${operation}d`, { companyId, branchId, amount: value, delta, } );
      }

exports.onDebtorOpeningBalanceWritten = onDocumentWritten('debtorsbalance/{balanceId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const balanceId = event.params?.balanceId;

  try {
    if (!before && after) {
      await postDebtorOpeningBalanceToLedger(after, balanceId);

      logger.info(`Posted debtor opening balance ${balanceId} to ledger (create)`);
    } else if (before && after) {
      await deleteLedgerEntriesForPurchase(balanceId);
      await postDebtorOpeningBalanceToLedger(after, balanceId);
      const oldAmount = toNumber( before.amount || before.balance || 0 );
      const newAmount = toNumber( after.amount || after.balance || 0 );
      // Remove old dashboard opening balance
       if (oldAmount > 0) {
       await updateDebtorOpeningCreditBalance( before, oldAmount, "remove" );
        }
      logger.info(`Reposted debtor opening balance ${balanceId} to ledger (update)`);
    } else if (before && !after) {
      await deleteLedgerEntriesForPurchase(balanceId);
      const oldAmount = toNumber( before.amount || before.balance || 0 );
       // Remove dashboard opening balance
       if (oldAmount > 0) {
       await updateDebtorOpeningCreditBalance( before, oldAmount, "remove" );
       }
      logger.info(`Removed ledger entries for deleted debtor opening balance ${balanceId}`);
    }
  } catch (err) {
    logger.error(`Error processing debtor opening balance ${balanceId}:`, err);
    throw err;
  }
});

exports.onCreditorOpeningBalanceWritten = onDocumentWritten('creditor_balances/{balanceId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const balanceId = event.params?.balanceId;

  try {
    if (!before && after) {
      await postCreditorOpeningBalanceToLedger(after, balanceId);
      logger.info(`Posted creditor opening balance ${balanceId} to ledger (create)`);
    } else if (before && after) {
      await deleteLedgerEntriesForPurchase(balanceId);
      await postCreditorOpeningBalanceToLedger(after, balanceId);
      logger.info(`Reposted creditor opening balance ${balanceId} to ledger (update)`);
    } else if (before && !after) {
      await deleteLedgerEntriesForPurchase(balanceId);
      logger.info(`Removed ledger entries for deleted creditor opening balance ${balanceId}`);
    }
  } catch (err) {
    logger.error(`Error processing creditor opening balance ${balanceId}:`, err);
    throw err;
  }
});

exports.onCreditPaymentWritten = onDocumentWritten('creditor_payments/{paymentId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const paymentId = event.params?.paymentId;

  try {
    if (!before && after) {
      await postCreditPaymentToLedger(after, paymentId);
      logger.info(`Posted credit payment ${paymentId} to ledger (create)`);
    } else if (before && after) {
      await deleteLedgerEntriesForPurchase(paymentId);
      await postCreditPaymentToLedger(after, paymentId);
      logger.info(`Reposted credit payment ${paymentId} to ledger (update)`);
    } else if (before && !after) {
      await deleteLedgerEntriesForPurchase(paymentId);
      logger.info(`Removed ledger entries for deleted credit payment ${paymentId}`);
    }
  } catch (err) {
    logger.error(`Error processing credit payment ${paymentId}:`, err);
    throw err;
  }
});

exports.onPurchaseReturnWritten = onDocumentWritten('purchase_returns/{returnId}', async (event) => {
  const beforeSnap = event.data?.before;
  const afterSnap = event.data?.after;
  const before = beforeSnap?.exists ? beforeSnap.data() : null;
  const after = afterSnap?.exists ? afterSnap.data() : null;
  const returnId = event.params?.returnId;

  try {
    if (!before && after) {
      // CREATE
      await postPurchaseToLedger(after, returnId);
      logger.info(`Posted purchase return ${returnId} to ledger (create)`);
    } else if (before && after) {
      // UPDATE: remove previous ledger entries then re-post
      await deleteLedgerEntriesForPurchase(returnId);
      await postPurchaseToLedger(after, returnId);
      logger.info(`Reposted purchase return ${returnId} to ledger (update)`);
    } else if (before && !after) {
      // DELETE: remove related ledger entries
      await deleteLedgerEntriesForPurchase(returnId);
      logger.info(`Removed ledger entries for deleted purchase return ${returnId}`);
    }
  } catch (err) {
    logger.error(`Error processing purchase return ${returnId}:`, err);
    throw err;
  }
});

/**
 * Update dashboard expense totals
 */
async function updateDashboardExpense(expenseData, amountDelta, action = "UNKNOWN") {
  try {
    const db = admin.firestore();

    const companyId =
      expenseData.companyId ||
      expenseData.companyid;

    const branchId =
      expenseData.branchId ||
      expenseData.branchid;

    const branchName =
      expenseData.branchName ||
      expenseData.branchname ||
      branchId;

    if (!companyId) {
      logger.warn(`[Expense Dashboard] ${action}: Missing companyId.`);
      return;
    }

    if (!branchId) {
      logger.warn(`[Expense Dashboard] ${action}: Missing branchId.`);
      return;
    }

    if (!amountDelta || amountDelta === 0) {
      logger.info(
        `[Expense Dashboard] ${action}: Amount difference is zero. Nothing to update.`
      );
      return;
    }

    const statsRef = db.collection("dashbaord_stats").doc(companyId);

    await statsRef.set(
      {
        companyId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),

        expense_total:
          admin.firestore.FieldValue.increment(amountDelta),

        branchexpense: {
          [branchId]: {
            branchid: branchId,
            branchname: branchName,
            expense_value:
              admin.firestore.FieldValue.increment(amountDelta),
            updatedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          },
        },
      },
      { merge: true }
    );

    logger.info(
      `[Expense Dashboard] ${action}: Successfully updated dashboard stats.\n` +
      `Company : ${companyId}\n` +
      `Branch  : ${branchName} (${branchId})\n` +
      `Amount  : ${amountDelta > 0 ? "+" : ""}${amountDelta.toFixed(2)}`
    );
  } catch (error) {
    logger.error(
      `[Expense Dashboard] ${action}: Failed updating dashboard.`,
      error
    );
    throw error;
  }
}








