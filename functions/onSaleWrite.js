// Firebase Cloud Function: Daily Staff Sales Summary Trigger
const functions = require("firebase-functions");
const admin = require("firebase-admin");
//admin.initializeApp();

const SUMMARY_COLLECTION = "dailysalesreport";

function getSummaryDocId(dateymd, companyId, branchId, staffEmail) {
  return `${dateymd}_${companyId}_${branchId}_${staffEmail}`;
}

function getRoleDeltas(sale, sign) {
  const deltas = {};
  if (sale.createdByEmail) {
    deltas[sale.createdByEmail] = {
      totalCreatedSalesCount: sign,
      totalCreatedSalesAmount: sign * (sale.totalamount || 0),
      totalDiscount: sign * (sale.discount || 0),
      totalReturnedSales: sign * (sale.isreturned ? 1 : 0),
      totalOutstandingBalance: sign * ((sale.totalamount || 0) - (sale.amountPaid || 0)),
      totalItemsSold: sign * (sale.itemCount || 0),
      totalTransactionsHandled: sign,
    };
  }
  if (sale.receiptByEmail) {
    deltas[sale.receiptByEmail] = {
      totalReceiptedSalesCount: sign,
      totalReceiptedAmount: sign * (sale.amountPaid || 0),
      totalCashSales: sign * (sale.transMode === "cash" ? (sale.amountPaid || 0) : 0),
      totalCreditSales: sign * (sale.transMode === "credit" ? (sale.amountPaid || 0) : 0),
      totalTransactionsHandled: sign,
    };
  }
  if (sale.printedByEmail) {
    deltas[sale.printedByEmail] = {
      totalPrintedSalesCount: sign,
      totalPrintedSalesAmount: sign * (sale.totalamount || 0),
      totalTransactionsHandled: sign,
    };
  }
  return deltas;
}

async function updateStaffSummary(sale, staffEmail, delta) {
  if (!staffEmail) return;
  const docId = getSummaryDocId(sale.dateymd, sale.companyId, sale.branchId, staffEmail);
  const docRef = admin.firestore().collection(SUMMARY_COLLECTION).doc(docId);
  const meta = {
    staffEmail,
    staffName: sale.createdBy || sale.receiptby || sale.printedby || "",
    branchId: sale.branchId,
    branchName: sale.branchName,
    companyId: sale.companyId,
    companyname: sale.companyname,
    dateymd: sale.dateymd,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const increments = {};
  for (const [k, v] of Object.entries(delta)) {
    increments[k] = admin.firestore.FieldValue.increment(v);
  }
  await docRef.set({ ...meta, ...increments }, { merge: true });
}

async function applySaleDelta(sale, sign) {
  const deltas = getRoleDeltas(sale, sign);
  const updates = Object.entries(deltas).map(([email, delta]) =>
    updateStaffSummary(sale, email, delta)
  );
  await Promise.all(updates);
}

exports.onSaleWrite = functions.firestore
  .document("sales/{saleId}")
  .onWrite(async (change, context) => {
    const saleId = context.params.saleId;
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    try {
      if (before && !after) {
        await applySaleDelta(before, -1);
        return;
      }
      if (!before && after) {
        await applySaleDelta(after, 1);
        return;
      }
      if (before && after) {
        const keysChanged =
          before.dateymd !== after.dateymd ||
          before.companyId !== after.companyId ||
          before.branchId !== after.branchId ||
          before.createdByEmail !== after.createdByEmail ||
          before.receiptByEmail !== after.receiptByEmail ||
          before.printedByEmail !== after.printedByEmail;
        if (keysChanged) {
          await applySaleDelta(before, -1);
          await applySaleDelta(after, 1);
        } else {
          await applySaleDelta(before, -1);
          await applySaleDelta(after, 1);
        }
      }
    } catch (err) {
      console.error(`[onSaleWrite][saleId=${saleId}] ERROR:`, err, { before, after });
      throw err;
    }
  });
