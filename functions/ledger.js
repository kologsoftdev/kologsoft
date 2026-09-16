// functions/ledger.js
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { registerDefaultChart, DEFAULT_TYPES } = require("./accounts");

const accountRegistry = registerDefaultChart();

function toNumber(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  if (typeof value === "string") {
    const parsed = parseFloat(value.trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

// Remove undefined properties recursively to avoid Firestore errors
function cleanObject(obj) {
  if (obj === null || typeof obj !== "object") return obj;
  if (Array.isArray(obj)) return obj.map((v) => cleanObject(v));
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

// Simple mapping from account name (lowercased) to class/sub/type codes
const ACCOUNT_NAME_TO_META = {
  // Asset Accounts - Current
  cash: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  cash_in_hand: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  bank: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  gcb: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  ecobank: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  fidelity: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  zenith: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  gtbank: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  bank_transfer: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  accounts_receivable: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  debtors: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  suspense: { classCode: "A", subCode: "Current Asset", type: DEFAULT_TYPES.ASSET },
  
  // Asset Accounts - Inventory
  inventory: { classCode: "A", subCode: "Inventory", type: DEFAULT_TYPES.ASSET },
  stock: { classCode: "A", subCode: "Inventory", type: DEFAULT_TYPES.ASSET },
  
  // Income Accounts
  sales: { classCode: "I", subCode: "Sales Revenue", type: DEFAULT_TYPES.INCOME },
  sales_revenue: { classCode: "I", subCode: "Sales Revenue", type: DEFAULT_TYPES.INCOME },
  sales_return: { classCode: "I", subCode: "Sales Revenue", type: DEFAULT_TYPES.INCOME },
  service_revenue: { classCode: "I", subCode: "Service Revenue", type: DEFAULT_TYPES.INCOME },
  
  // Liability Accounts - Current
  accounts_payable: { classCode: "L", subCode: "Current Liability", type: DEFAULT_TYPES.LIABILITY },
  creditors: { classCode: "L", subCode: "Current Liability", type: DEFAULT_TYPES.LIABILITY },
  creditors_payable: { classCode: "L", subCode: "Current Liability", type: DEFAULT_TYPES.LIABILITY },
  purchase_creditor: { classCode: "L", subCode: "Current Liability", type: DEFAULT_TYPES.LIABILITY },
  
  // Expense Accounts
  discount: { classCode: "X", subCode: "Operating Expenses", type: DEFAULT_TYPES.EXPENSE },
  expense: { classCode: "X", subCode: "Expense", type: DEFAULT_TYPES.EXPENSE },
  fuel_purchase: { classCode: "X", subCode: "Fuel Purchase", type: DEFAULT_TYPES.EXPENSE },
  damage_expense: { classCode: "X", subCode: "Inventory Loss", type: DEFAULT_TYPES.EXPENSE },
  damage: { classCode: "X", subCode: "Inventory Loss", type: DEFAULT_TYPES.EXPENSE },
  cost_of_goods_sold: { classCode: "X", subCode: "Cost of Goods Sold", type: DEFAULT_TYPES.EXPENSE },
  
  // Inter-Branch Transfer
  inter_branch_transfer_out: { classCode: "X", subCode: "Inter-Branch Transfer", type: DEFAULT_TYPES.EXPENSE },
  inter_branch_transfer_in: { classCode: "X", subCode: "Inter-Branch Transfer", type: DEFAULT_TYPES.EXPENSE },
  
  // Equity Accounts
  capital: { classCode: "E", subCode: "Capital / Equity", type: DEFAULT_TYPES.EQUITY },
  owner_capital: { classCode: "E", subCode: "Capital / Equity", type: DEFAULT_TYPES.EQUITY },
  retained_earnings: { classCode: "E", subCode: "Retained Earnings", type: DEFAULT_TYPES.EQUITY },
};

function resolveAccountMeta(accountName, fallbackType = DEFAULT_TYPES.ASSET) {
  if (!accountName && accountName !== "") return null;
  const name = String(accountName).trim();
  const key = name.toLowerCase().replace(/\s+/g, "_");
  if (ACCOUNT_NAME_TO_META[key]) return ACCOUNT_NAME_TO_META[key];
  // fallback by checking registry subclasses names
  const sub = accountRegistry.findSubByName ? accountRegistry.findSubByName(name) : null;
  if (sub && sub.parent) {
    return { classCode: sub.parent.code || sub.parent, subCode: sub.code, type: sub.parent.type || fallbackType };
  }
  // fallback class by scanning classes for same name
  const cls = accountRegistry.findClassByName ? accountRegistry.findClassByName(name) : null;
  if (cls) return { classCode: cls.code, subCode: null, type: cls.type || fallbackType };
  const fallbackClass =
    fallbackType === DEFAULT_TYPES.ASSET ? "A" :
    fallbackType === DEFAULT_TYPES.LIABILITY ? "L" :
    fallbackType === DEFAULT_TYPES.EQUITY ? "E" :
    fallbackType === DEFAULT_TYPES.INCOME ? "I" :
    "X";
  return { classCode: fallbackClass, subCode: name || null, type: fallbackType };
}

exports.postExpenseToLedger = async (expenseData = {}, expenseId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = expenseData.companyId || expenseData.companyid || null;
    const companyname = expenseData.companyname || expenseData.companyName || expenseData.companyEmail || null;
    const branchId = expenseData.branchId || expenseData.branchid || null;
    const branchName = expenseData.branchName || expenseData.branchname || null;
    const amount = toNumber(expenseData.amount || expenseData.total || 0);
    const expenseAccount = String(expenseData.category || expenseData.expenseName || expenseData.subAccountName || expenseData.subAccountId || 'expense').trim();
    const paymentAccount = String(expenseData.paymentMethod || expenseData.subAccountId || expenseData.subAccountName || 'cash').trim();
    const staff = expenseData.staff || expenseData.updatedBy || expenseData.updatedby || 'system';
    const vendorName = expenseData.vendorName || null;
    const description = expenseData.description || `Expense ${expenseId}`;

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
      const meta = resolveAccountMeta(entry.account, entry.type === 'debit' ? DEFAULT_TYPES.EXPENSE : DEFAULT_TYPES.ASSET);
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
      const docId = `${expenseId}_${entryIndex++}`;
      batch.set(ledgerRef.doc(docId), cleaned);
    }

    if (amount <= 0) {
      logger.warn(`Expense ${expenseId} has no amount; skipping ledger post`);
      return;
    }

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: expenseAccount,
      type: 'debit',
      amount,
      description: `${description}`,
      vendorName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: paymentAccount,
      type: 'credit',
      amount,
      description: `Expense ${expenseId} - paid via ${paymentAccount}`,
      vendorName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    await batch.commit();
    logger.info(`Ledger entries (expense) created for expense ${expenseId}`);
    return;
  } catch (error) {
    logger.error(`Error posting expense ${expenseId} to ledger:`, error);
    throw error;
  }
};

exports.postToLedger = async (saleData = {}, saleId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    // safe reads with fallbacks
    const companyId = saleData.companyId || saleData.companyid || null;
    const companyname = saleData.companyname || saleData.companyName || null;
    const branchId = saleData.branchId || saleData.branchid || null;
    const branchName = saleData.branchName || saleData.branchname || null;
    const transMode = (saleData.transMode || "").toString().toLowerCase();
    const providedTotal = toNumber(saleData.totalamount || saleData.totalAmount || 0);
    const discountAmount = toNumber(saleData.discount || 0);
    const payments = Array.isArray(saleData.payments) ? saleData.payments : [];
    const staffemail = saleData.staffemail || saleData.createdBy || saleData.createdByEmail || "system@nologin";
    const isreturned = !!saleData.isreturned;
    const customerId = saleData.customerId || saleData.customerid || null;
    const customerName = saleData.customerName || saleData.customer || null;

    // derive grossAmount: prefer explicitly provided gross fields, else assume providedTotal is net and add discount
    const grossAmount =
      toNumber(saleData.grossAmount || saleData.grosstotalamount) ||
      (providedTotal > 0 ? providedTotal + discountAmount : 0);

    // fallback: if grossAmount still zero, compute from payments + discount
    const paymentsSum = payments.reduce((s, p) => s + toNumber(p?.amount), 0);
    const finalGross = grossAmount > 0 ? grossAmount : paymentsSum + discountAmount || providedTotal + discountAmount;

    const ledgerRef = db.collection("ledgers");

    // Helpers to create a ledger doc (sanitized)
    let entryIndex = 0;
    function addEntry(entry) {
      // Add date fields for reporting
      const now = new Date();
      const pad = (n) => n.toString().padStart(2, '0');
      const year = now.getFullYear();
      const monthNum = now.getMonth() + 1;
      const dateNum = now.getDate();
      const weekNum = (() => {
        // ISO week number
        const d = new Date(Date.UTC(year, now.getMonth(), dateNum));
        const dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(),0,1));
        return Math.ceil((((d - yearStart) / 86400000) + 1)/7);
      })();
      const dayName = now.toLocaleString('en-US', { weekday: 'long' });
      // Attach account class/subclass/type metadata
      const meta = resolveAccountMeta(entry.account);
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
      // Use saleId + index for uniqueness (double entry)
      let docId;
      if (isreturned) {
        docId = saleId + '_return_' + (entryIndex++);
      } else {
        docId = saleId + '_' + (entryIndex++);
      }
      batch.set(ledgerRef.doc(docId), cleaned);
    }

    if (isreturned) {
      // Sales return: reverse the sale effects and adjust debtor if credit
      const returnAmount = finalGross;
      const netReceivable = finalGross - discountAmount;

      // Debit sales_return for the full gross amount
      addEntry({
        companyId,
        companyname,
        branchId,
        branchName,
        account: "sales_return",
        type: "debit",
        amount: returnAmount,
        description: `Sale Return ${saleId} - Sales return`,
        customerId,
        customerName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staffemail,
      });

      if (transMode === "credit") {
        // Credit accounts_receivable for net amount
        if (netReceivable > 0) {
          addEntry({
            companyId,
            companyname,
            branchId,
            branchName,
            account: "accounts_receivable",
            type: "credit",
            amount: netReceivable,
            description: `Sale Return ${saleId} - Refund / reduce accounts_receivable`,
            customerId,
            customerName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: staffemail,
          });
        }
        // Credit discount for discount amount
        if (discountAmount > 0) {
          addEntry({
            companyId,
            companyname,
            branchId,
            branchName,
            account: "discount",
            type: "credit",
            amount: discountAmount,
            description: `Sale Return ${saleId} - Reverse discount`,
            customerId,
            customerName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: staffemail,
          });
        }

      } else {
        // Cash/MoMo/Card/Bank/Cheque: refund payment method for net amount, refund discount
        const netRefund = returnAmount - discountAmount;
        const creditAccount = payments[0]?.method || "cash";
        if (netRefund > 0) {
          addEntry({
            companyId,
            companyname,
            branchId,
            branchName,
            account: creditAccount,
            type: "credit",
            amount: netRefund,
            description: `Sale Return ${saleId} - Refund / reduce ${creditAccount}`,
            customerId,
            customerName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: staffemail,
          });
        }
        if (discountAmount > 0) {
          addEntry({
            companyId,
            companyname,
            branchId,
            branchName,
            account: "discount",
            type: "credit",
            amount: discountAmount,
            description: `Sale Return ${saleId} - Reverse discount`,
            customerId,
            customerName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: staffemail,
          });
        }
      }

      // If credit return, reduce debtor balance separately if you maintain a debt record (not covered here)
      await batch.commit();
      logger.info(`Ledger entries (return) created for sale ${saleId}`);
      return;
    }

    if (transMode === "cash") {
      // Cash sales:
      // Debit: payment methods (cash/momo/card/cheque/bank transfer) for amounts received
      // Debit: discount (if any)
      // Credit: sales for the gross sale amount (payments sum + discount) => finalGross

      const paymentEntries = payments.length ? payments : [{ method: "cash", amount: finalGross }];

      // Debit each payment method
      paymentEntries.forEach((p) => {
        const method = p.method || p.accountName || "cash";
        const amt = toNumber(p.amount);
        if (amt <= 0) return;
        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: method,
          type: "debit",
          amount: amt,
          description: `Sale ${saleId} - ${method} payment`,
          customerId,
          customerName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staffemail,
        });
      });

      // Debit discount if present
      if (discountAmount > 0) {
        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: "discount",
          type: "debit",
          amount: discountAmount,
          description: `Sale ${saleId} - Discount allowed`,
          customerId,
          customerName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staffemail,
        });
      }

      // Credit sales for total (payments + discount) -> finalGross
      addEntry({
        companyId,
        companyname,
        branchId,
        branchName,
        account: "sales",
        type: "credit",
        amount: finalGross,
        description: `Sale ${saleId} - Sales revenue`,
        customerId,
        customerName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staffemail,
      });

      // If payments sum doesn't match finalGross, post balancing entry to 'suspense'
      const sumPaid = paymentEntries.reduce((s, p) => s + toNumber(p.amount), 0);
      const expectedDebit = sumPaid + (discountAmount > 0 ? discountAmount : 0);
      const diff = Math.round((expectedDebit - finalGross) * 100) / 100;
      if (diff !== 0) {
        // If small mismatch, create balancing entry
        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: "suspense",
          type: diff > 0 ? "credit" : "debit",
          amount: Math.abs(diff),
          description: `Sale ${saleId} - Balancing entry due to rounding/payment mismatch`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staffemail,
        });
      }

      await batch.commit();
      logger.info(`Ledger entries (cash sale) created for sale ${saleId}`);
      return;
    }

    if (transMode === "credit") {
      // Credit sales:
      // Debit: accounts_receivable for net amount (finalGross - discountAmount)
      // Debit: discount (if any) as expense
      // Credit: sales for gross amount (finalGross)

      const netReceivable = finalGross - discountAmount;
      if (netReceivable > 0) {
        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: "accounts_receivable",
          type: "debit",
          amount: netReceivable,
          description: `Sale ${saleId} - Credit sale to ${customerName || customerId}`,
          customerId,
          customerName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staffemail,
        });
      }

      if (discountAmount > 0) {
        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: "discount",
          type: "debit",
          amount: discountAmount,
          description: `Sale ${saleId} - Discount allowed`,
          customerId,
          customerName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staffemail,
        });
      }

      addEntry({
        companyId,
        companyname,
        branchId,
        branchName,
        account: "sales",
        type: "credit",
        amount: finalGross,
        description: `Sale ${saleId} - Sales revenue`,
        customerId,
        customerName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staffemail,
      });

      await batch.commit();
      logger.info(`Ledger entries (credit sale) created for sale ${saleId}`);
      return;
    }

    // Fallback: unknown transMode - post to suspense and sales
    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: "suspense",
      type: "debit",
      amount: finalGross,
      description: `Sale ${saleId} - Unknown transMode; debit suspense`,
      customerId,
      customerName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staffemail,
    });

    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: "sales",
      type: "credit",
      amount: finalGross,
      description: `Sale ${saleId} - Sales revenue`,
      customerId,
      customerName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staffemail,
    });

    await batch.commit();
    logger.info(`Ledger entries (fallback) created for sale ${saleId}`);
  } catch (error) {
    logger.error(`Error posting to ledger for sale ${saleId}:`, error);
    throw error;
  }
};

function normalizeDamageItems(raw) {
  function normalizeObject(item) {
    if (!item || typeof item !== 'object') return null;
    const totalpieces = toNumber(item.totalpieces || item.pieces || item.quantity || 0);
    const cp = toNumber(item.cp || item.unitCost || item.costPrice || item.price || 0);
    return {
      itemid: item.itemid || item.itemId || item.id || null,
      item: item.item || item.itemName || item.name || null,
      barcode: item.barcode || item.bar_code || item.barCode || null,
      reason: item.reason || null,
      supplier: item.supplier || null,
      totalpieces,
      cp,
      totalValue: Math.round((totalpieces * cp) * 100) / 100,
    };
  }

  if (!raw) return [];
  if (Array.isArray(raw)) return raw.map(normalizeObject).filter(Boolean);
  if (typeof raw === 'object') return Object.values(raw).map(normalizeObject).filter(Boolean);
  if (typeof raw === 'string') {
    try {
      return normalizeDamageItems(JSON.parse(raw));
    } catch (error) {
      return [];
    }
  }
  return [];
}

exports.postDamageToLedger = async (damageData = {}, damageId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = damageData.companyid || damageData.companyId || null;
    const companyname = damageData.companyname || damageData.companyName || null;
    const branchId = damageData.branchid || damageData.branchId || null;
    const branchName = damageData.branchname || damageData.branchName || null;
    const description = damageData.description || damageData.reason || `Damage record ${damageId}`;
    const staff = damageData.updatedby || damageData.updatedBy || damageData.createdby || damageData.createdBy || 'system';
    const items = normalizeDamageItems(damageData.item);
    const totalAmount = toNumber(damageData.grandtotal || damageData.total || damageData.amount) || items.reduce((sum, item) => sum + item.totalValue, 0);

    if (totalAmount <= 0) {
      logger.warn(`Damage ${damageId} has no value; skipping ledger post`);
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
      const meta = resolveAccountMeta(entry.account, entry.type === 'debit' ? DEFAULT_TYPES.EXPENSE : DEFAULT_TYPES.ASSET);
      const enriched = {
        ...entry,
        accountClass: meta && meta.classCode ? meta.classCode : undefined,
        accountSubClass: meta && meta.subCode ? meta.subCode : undefined,
        accountType: meta && meta.type ? meta.type : undefined,
        date: `${year}-${pad(monthNum)}-${pad(dateNum)}`,
        month: `${year}.${monthNum}`,
        week: `${year}.${weekNum}`,
        day: dayName,
        sourceType: 'damageitems',
        sourceId: damageId,
      };
      const cleaned = cleanObject(enriched);
      const docId = `${damageId}_${entryIndex++}`;
      batch.set(ledgerRef.doc(docId), cleaned);
    }

    if (items.length > 0) {
      items.forEach((item) => {
        const itemAmount = toNumber(item.totalValue);
        if (itemAmount <= 0) return;
        const itemDescription = `${description}${item.item ? ` - ${item.item}` : ''}${item.reason ? ` (${item.reason})` : ''}`;

        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: 'damage_expense',
          type: 'debit',
          amount: itemAmount,
          description: `Damage expense for ${damageId}: ${itemDescription}`,
          itemId: item.itemid,
          item: item.item,
          barcode: item.barcode,
          reason: item.reason,
          supplier: item.supplier,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });

        addEntry({
          companyId,
          companyname,
          branchId,
          branchName,
          account: 'inventory',
          type: 'credit',
          amount: itemAmount,
          description: `Inventory credit for damaged item ${damageId}: ${item.item || item.itemid}`,
          itemId: item.itemid,
          item: item.item,
          barcode: item.barcode,
          reason: item.reason,
          supplier: item.supplier,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: staff,
        });
      });
    } else {
      addEntry({
        companyId,
        companyname,
        branchId,
        branchName,
        account: 'damage_expense',
        type: 'debit',
        amount: totalAmount,
        description: `Damage expense for ${damageId}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });
      addEntry({
        companyId,
        companyname,
        branchId,
        branchName,
        account: 'inventory',
        type: 'credit',
        amount: totalAmount,
        description: `Inventory credit for damage ${damageId}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: staff,
      });
    }

    await batch.commit();
    logger.info(`Ledger entries (damage) created for damage ${damageId}`);
    return;
  } catch (error) {
    logger.error(`Error posting damage ${damageId} to ledger:`, error);
    throw error;
  }
};

function normalizeTransferItems(raw) {
  if (!raw) return {};
  const normalized = {};

  if (Array.isArray(raw)) {
    raw.forEach((item, index) => {
      if (!item || typeof item !== 'object') return;
      const itemId = item.itemid || item.itemId || item.id || `${index}`;
      if (!itemId) return;
      const quantity = toNumber(item.quantity ?? item.qty ?? 0);
      const pieces = toNumber(item.pieces ?? item.transferpieces ?? item.totalpieces ?? 0);
      const cp = toNumber(item.cp || item.costprice || 0);
      const boxpieces = toNumber(item.boxpieces ?? item.boxPieces ?? 1);
      const current = normalized[itemId] || { itemId, quantity: 0, pieces: 0, cp: 0, boxpieces };
      current.quantity += quantity;
      current.pieces += pieces;
      current.cp = cp || current.cp;
      current.boxpieces = boxpieces || current.boxpieces;
      normalized[itemId] = current;
    });
  } else if (typeof raw === 'object') {
    Object.entries(raw).forEach(([itemKey, item]) => {
      if (!item || typeof item !== 'object') return;
      const itemId = item.itemid || item.itemId || item.id || itemKey;
      if (!itemId) return;
      const quantity = toNumber(item.quantity ?? item.qty ?? 0);
      const pieces = toNumber(item.pieces ?? item.transferpieces ?? item.totalpieces ?? 0);
      const cp = toNumber(item.cp || item.costprice || 0);
      const boxpieces = toNumber(item.boxpieces ?? item.boxPieces ?? 1);
      const current = normalized[itemId] || { itemId, quantity: 0, pieces: 0, cp: 0, boxpieces };
      current.quantity += quantity;
      current.pieces += pieces;
      current.cp = cp || current.cp;
      current.boxpieces = boxpieces || current.boxpieces;
      normalized[itemId] = current;
    });
  }

  return normalized;
}

exports.postStockTransferToLedger = async (transferData = {}, transferId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = transferData.companyid || transferData.companyId || null;
    const companyname = transferData.companyname || transferData.companyName || null;

    const sourceBranchId = transferData.supplybranchid || transferData.supplyBranchId ||
                          transferData.supplywarehouseid || transferData.supplyWarehouseId || null;
    const sourceBranchName = transferData.supplybranchname || transferData.supplyBranchName ||
                            transferData.supplywarehousename || transferData.supplyWarehouseName || sourceBranchId;

    const receiveBranchId = transferData.receivebranchid || transferData.receiveBranchId ||
                           transferData.recievebranchid || transferData.recieveBranchId || null;
    const receiveBranchName = transferData.receivebranchname || transferData.receiveBranchName ||
                             transferData.recievebranchname || transferData.recieveBranchName || receiveBranchId;

    const description = transferData.description || `Stock transfer ${transferId}`;
    const staff = transferData.updatedby || transferData.updatedBy || transferData.createdby || transferData.createdBy || 'system';

    if (!companyId || !sourceBranchId || !receiveBranchId) {
      logger.warn(`Stock transfer ${transferId} missing required fields`, {
        companyId,
        sourceBranchId,
        receiveBranchId,
      });
      return;
    }

    const items = normalizeTransferItems(transferData.items);

    let totalValue = 0;
    Object.values(items).forEach((item) => {
      const cp = toNumber(item.cp || 0);
      const pieces = toNumber(item.pieces || 0);
      totalValue += (cp * pieces);
    });

    if (totalValue <= 0) {
      logger.warn(`Stock transfer ${transferId} has no value; skipping ledger post`);
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
      const meta = resolveAccountMeta(entry.account, DEFAULT_TYPES.ASSET);
      const enriched = {
        ...entry,
        accountClass: meta && meta.classCode ? meta.classCode : undefined,
        accountSubClass: meta && meta.subCode ? meta.subCode : undefined,
        accountType: meta && meta.type ? meta.type : undefined,
        date: `${year}-${pad(monthNum)}-${pad(dateNum)}`,
        month: `${year}.${monthNum}`,
        week: `${year}.${weekNum}`,
        day: dayName,
        sourceType: 'stock_transfer',
        sourceId: transferId,
      };
      const cleaned = cleanObject(enriched);
      const docId = `${transferId}_${entryIndex++}`;
      batch.set(ledgerRef.doc(docId), cleaned);
    }

    // Receiving branch: Debit inventory (asset increase)
    addEntry({
      companyId,
      companyname,
      branchId: receiveBranchId,
      branchName: receiveBranchName,
      account: 'inventory',
      type: 'debit',
      amount: totalValue,
      description: `Stock transfer in to ${receiveBranchName} from ${sourceBranchName} - ${transferId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    // Source branch: Credit inventory (asset decrease)
    addEntry({
      companyId,
      companyname,
      branchId: sourceBranchId,
      branchName: sourceBranchName,
      account: 'inventory',
      type: 'credit',
      amount: totalValue,
      description: `Stock transfer out from ${sourceBranchName} to ${receiveBranchName} - ${transferId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    // Inter-branch clearing entries to track the transfer
    addEntry({
      companyId,
      companyname,
      branchId: sourceBranchId,
      branchName: sourceBranchName,
      account: 'inter_branch_transfer_out',
      type: 'debit',
      amount: totalValue,
      description: `Transfer out clearing ${transferId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    addEntry({
      companyId,
      companyname,
      branchId: receiveBranchId,
      branchName: receiveBranchName,
      account: 'inter_branch_transfer_in',
      type: 'credit',
      amount: totalValue,
      description: `Transfer in clearing ${transferId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    await batch.commit();
    logger.info(`Ledger entries (stock transfer) created for transfer ${transferId}`);
    return;
  } catch (error) {
    logger.error(`Error posting stock transfer ${transferId} to ledger:`, error);
    throw error;
  }
};

// Export utility functions for use in other ledger-related modules
module.exports.cleanObject = cleanObject;
module.exports.resolveAccountMeta = resolveAccountMeta;
module.exports.DEFAULT_TYPES = DEFAULT_TYPES;
module.exports.ACCOUNT_NAME_TO_META = ACCOUNT_NAME_TO_META;
