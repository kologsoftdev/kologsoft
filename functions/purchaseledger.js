// functions/purchaseledger.js
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { registerDefaultChart, DEFAULT_TYPES } = require('./accounts');

const accountRegistry = registerDefaultChart();

// simple mapping from account name (lowercased) to class/sub/type codes
const ACCOUNT_NAME_TO_META = {
  inventory: { classCode: 'A', subCode: 'Inventory', type: DEFAULT_TYPES.ASSET },
  accounts_payable: { classCode: 'L', subCode: 'Current Liability', type: DEFAULT_TYPES.LIABILITY },
  purchase_discount: { classCode: 'X', subCode: 'Purchase Discount', type: DEFAULT_TYPES.EXPENSE },
  opening_stock: { classCode: 'A', subCode: 'Inventory', type: DEFAULT_TYPES.ASSET },
  suspense: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  cash: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  bank: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
  accounts_receivable: { classCode: 'A', subCode: 'Current Asset', type: DEFAULT_TYPES.ASSET },
};
function toNumber(v) {
  if (typeof v === 'number') return Number.isFinite(v) ? v : 0;
  if (typeof v === 'string') {
    const n = parseFloat(v.trim());
    return Number.isFinite(n) ? n : 0;
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

function resolveAccountMeta(accountName) {
  if (!accountName && accountName !== '') return null;
  const name = String(accountName).trim();
  const key = name.toLowerCase().replace(/\s+/g, '_');
  if (ACCOUNT_NAME_TO_META[key]) return ACCOUNT_NAME_TO_META[key];
  // fallback by checking registry subclasses names
  const sub = accountRegistry.findSubByName ? accountRegistry.findSubByName(name) : null;
  if (sub && sub.parent) {
    return { classCode: sub.parent.code || sub.parent, subCode: sub.code, type: sub.parent.type || DEFAULT_TYPES.ASSET };
  }
  // fallback class by scanning classes for same name
  const cls = accountRegistry.findClassByName ? accountRegistry.findClassByName(name) : null;
  if (cls) return { classCode: cls.code, subCode: null, type: cls.type || DEFAULT_TYPES.ASSET };
  // default unknown -> treat as Asset
  return { classCode: 'A', subCode: null, type: DEFAULT_TYPES.ASSET };
}

module.exports.postPurchaseToLedger = async (purchaseData = {}, purchaseId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = purchaseData.companyid || purchaseData.companyId || null;
    const company = purchaseData.company || purchaseData.companyname || null;
    const branchId = purchaseData.branchid || purchaseData.branchId || null;
    const branchName = purchaseData.branchname || purchaseData.branchName || null;

    const purchasetype = (purchaseData.purchasetype || purchaseData.purchaseType || '').toString().toLowerCase();
    const returnValue = toNumber(purchaseData.returnvalue || purchaseData.returnValue || purchaseData.return_amount || purchaseData.returnAmount || 0);
    const gross = toNumber(purchaseData.gross || purchaseData.total || returnValue || 0);
    const discountAmount = toNumber(purchaseData.discount || 0);
    const items = Array.isArray(purchaseData.items) ? purchaseData.items : [];
    const payments = Array.isArray(purchaseData.payments) ? purchaseData.payments : [];
    const defaultPayment = (purchaseData.paymentaccount || purchaseData.paymentAccount || 'Cash');
    const paymentEntries = payments.length ? payments : [{ method: defaultPayment, amount: 0 }];
    const isReturned = !!purchaseData.isreturned || !!purchaseData.isReturn || !!purchaseData.returned || !!purchaseData.returnid || returnValue > 0 || purchasetype.includes('return');
    const supplierId = purchaseData.supplierid || purchaseData.supplierId || null;
    const supplierName = purchaseData.suppliername || purchaseData.supplierName || null;
    const staff = purchaseData.createdby || purchaseData.createdBy || purchaseData.staff || 'system';

    const itemsTotal = items.reduce((s, it) => s + toNumber(it?.total), 0);
    const finalGross = gross > 0 ? gross : (returnValue > 0 ? returnValue : (itemsTotal || paymentEntries.reduce((s, p) => s + toNumber(p?.amount), 0) + discountAmount));
    const netAmount = Math.max(0, finalGross - discountAmount);

    const ledgerRef = db.collection('ledgers');
    let idx = 0;
    function addEntry(entry) {
      const now = new Date();
      const pad = (n) => String(n).padStart(2, '0');
      const year = now.getFullYear();
      const monthNum = now.getMonth() + 1;
      const dateNum = now.getDate();
      const dayName = now.toLocaleString('en-US', { weekday: 'long' });

      // attach account class/subclass/type metadata
      const meta = resolveAccountMeta(entry.account);
      const enriched = {
        ...entry,
        accountClass: meta && meta.classCode ? meta.classCode : undefined,
        accountSubClass: meta && meta.subCode ? meta.subCode : undefined,
        accountType: meta && meta.type ? meta.type : undefined,
        date: `${year}-${pad(monthNum)}-${pad(dateNum)}`,
        month: `${year}.${monthNum}`,
        day: dayName,
      };
        let docId;
      if (isReturned) {
        docId = `${purchaseId}_return_${idx++}`;
      } else {
        docId = `${purchaseId}_${idx++}`;
      }
      const cleaned = cleanObject(enriched);
      batch.set(ledgerRef.doc(docId), cleaned);
    }

    if (isReturned) {
      const returnAmount = netAmount > 0 ? netAmount : finalGross;

      // Reduce inventory (credit)
      addEntry({
        companyId,
        company,
        branchId,
        branchName,
        account: 'inventory',
        type: 'credit',
        amount: returnAmount,
        description: `Purchase Return ${purchaseId} - reduce inventory`,
        supplierId,
        supplierName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });

      if (purchasetype === 'credit') {
        // Reduce payable (debit accounts_payable)
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: 'accounts_payable',
          type: 'debit',
          amount: returnAmount,
          description: `Purchase Return ${purchaseId} - reduce payable to supplier`,
          supplierId,
          supplierName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      } else {
        // Refund to the payment account (debit)
        const refundAccount = paymentEntries[0]?.method || defaultPayment || 'Cash';
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: refundAccount,
          type: 'debit',
          amount: returnAmount,
          description: `Purchase Return ${purchaseId} - refund to ${refundAccount}`,
          supplierId,
          supplierName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      }

      // Reverse purchase discount if originally applied
      if (discountAmount > 0) {
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: 'purchase_discount',
          type: 'debit',
          amount: discountAmount,
          description: `Purchase Return ${purchaseId} - reverse discount`,
          supplierId,
          supplierName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      }

      await batch.commit();
      logger.info(`Purchase return ledger entries created for ${purchaseId}`);
      return;
    }

    if (purchasetype === 'opening stock') {
      addEntry({
        companyId,
        company,
        branchId,
        branchName,
        account: 'inventory',
        type: 'debit',
        amount: netAmount,
        description: `Opening Stock ${purchaseId} - add opening inventory`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });

      addEntry({
        companyId,
        company,
        branchId,
        branchName,
        account: 'opening_stock',
        type: 'credit',
        amount: netAmount,
        description: `Opening Stock ${purchaseId} - offset opening balance`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });

      await batch.commit();
      logger.info(`Opening stock ledger entries created for ${purchaseId}`);
      return;
    }

    if (purchasetype === 'cash' || purchasetype === 'cash purchase' || purchasetype === 'cashpayment') {
      // Debit inventory for net amount
      addEntry({
        companyId,
        company,
        branchId,
        branchName,
        account: 'inventory',
        type: 'debit',
        amount: netAmount,
        description: `Purchase ${purchaseId} - inventory (cash)`,
        supplierId,
        supplierName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });

      // Credit payment accounts for amounts paid
      paymentEntries.forEach((p) => {
        const method = p.method || p.accountName || defaultPayment || 'Cash';
        const amt = toNumber(p.amount);
        if (amt <= 0) return;
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: method,
          type: 'credit',
          amount: amt,
          description: `Purchase ${purchaseId} - paid via ${method}`,
          supplierId,
          supplierName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      });

      // If discount applied: credit purchase_discount (reduces cost/liability)
      if (discountAmount > 0) {
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: 'purchase_discount',
          type: 'credit',
          amount: discountAmount,
          description: `Purchase ${purchaseId} - discount`,
          supplierId,
          supplierName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      }

      // Balancing: ensure debits == credits; small diffs go to suspense
      const sumCredits = paymentEntries.reduce((s, p) => s + toNumber(p.amount), 0) + (discountAmount > 0 ? discountAmount : 0);
      const debitExpected = netAmount;
      const diff = Math.round((debitExpected - sumCredits) * 100) / 100;
      if (Math.abs(diff) > 0) {
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: 'suspense',
          type: diff > 0 ? 'credit' : 'debit',
          amount: Math.abs(diff),
          description: `Purchase ${purchaseId} - balancing entry`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      }

      await batch.commit();
      logger.info(`Cash purchase ledger entries created for ${purchaseId}`);
      return;
    }

    if (purchasetype === 'credit' || purchasetype === 'supplier credit') {
      // Debit inventory
      addEntry({
        companyId,
        company,
        branchId,
        branchName,
        account: 'inventory',
        type: 'debit',
        amount: netAmount,
        description: `Purchase ${purchaseId} - inventory (credit)`,
        supplierId,
        supplierName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });

      // Credit accounts_payable (supplier)
      addEntry({
        companyId,
        company,
        branchId,
        branchName,
        account: 'accounts_payable',
        type: 'credit',
        amount: netAmount,
        description: `Purchase ${purchaseId} - payable to supplier ${supplierName || supplierId}`,
        supplierId,
        supplierName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });

      // Discount on credit purchase: credit purchase_discount (reduces payable/cost)
      if (discountAmount > 0) {
        addEntry({
          companyId,
          company,
          branchId,
          branchName,
          account: 'purchase_discount',
          type: 'credit',
          amount: discountAmount,
          description: `Purchase ${purchaseId} - discount`,
          supplierId,
          supplierName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      }

      await batch.commit();
      logger.info(`Credit purchase ledger entries created for ${purchaseId}`);
      return;
    }

    // Fallback: unknown purchase type -> debit inventory, credit suspense
    addEntry({
      companyId,
      company,
      branchId,
      branchName,
      account: 'inventory',
      type: 'debit',
      amount: netAmount,
      description: `Purchase ${purchaseId} - unknown type`,
      supplierId,
      supplierName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    addEntry({
      companyId,
      company,
      branchId,
      branchName,
      account: 'suspense',
      type: 'credit',
      amount: netAmount,
      description: `Purchase ${purchaseId} - unknown type credit suspense`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    await batch.commit();
    logger.info(`Fallback purchase ledger entries created for ${purchaseId}`);
  } catch (err) {
    logger.error(`Error posting purchase ${purchaseId} to ledger:`, err);
    throw err;
  }
};
