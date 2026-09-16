// functions/journal.js
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { resolveAccountMeta, cleanObject } = require("./ledger");
const { DEFAULT_TYPES } = require("./accounts");

function toNumber(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  if (typeof value === "string") {
    const parsed = parseFloat(value.trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

exports.postJournalToLedger = async (journalData = {}, journalId) => {
  const db = admin.firestore();
  const batch = db.batch();

  try {
    const companyId = journalData.companyId || journalData.companyid || null;
    const companyname = journalData.companyEmail || journalData.companyName || null;
    const branchId = journalData.branchId || journalData.branchid || null;
    const branchName = journalData.branchName || journalData.branchname || null;
    const amount = toNumber(journalData.amount || 0);
    const debitAccount = String(journalData.debitAccount || 'suspense').trim();
    const creditAccount = String(journalData.creditAccount || 'suspense').trim();
    const narration = journalData.narration || `Journal entry ${journalId}`;
    const staff = journalData.staff || journalData.updatedBy || journalData.updatedby || 'system';
    const journalType = journalData.journalType || 'General Journal';
    const journalDate = journalData.date || new Date().toISOString();

    const ledgerRef = db.collection('ledgers');
    let entryIndex = 0;

    function addEntry(entry) {
      const now = new Date();
      const pad = (n) => n.toString().padStart(2, '0');
      const year = now.getFullYear();
      const monthNum = now.getMonth() + 1;
      const dateNum = now.getDate();
      const weekNum = (() => {
        const d = new Date(year, monthNum - 1, dateNum);
        const firstDay = new Date(year, 0, 1);
        const pastDaysOfYear = d - firstDay;
        return Math.ceil((pastDaysOfYear + 1) / 7);
      })();
      const dayName = now.toLocaleString('en-US', { weekday: 'long' });

      // Attach account class/subclass/type metadata
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
        sourceType: 'journal',
        sourceId: journalId,
      };
      const cleaned = cleanObject(enriched);
      const docId = `${journalId}_${entryIndex++}`;
      batch.set(ledgerRef.doc(docId), cleaned);
    }

    if (amount <= 0) {
      logger.warn(`Journal entry ${journalId} has no amount; skipping ledger post`);
      return;
    }

    // Debit entry
    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: debitAccount,
      type: 'debit',
      amount,
      description: `${journalType} - ${narration}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    // Credit entry (balancing debit)
    addEntry({
      companyId,
      companyname,
      branchId,
      branchName,
      account: creditAccount,
      type: 'credit',
      amount,
      description: `${journalType} - ${narration}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: staff,
    });

    await batch.commit();
    logger.info(`Ledger entries (journal) created for journal ${journalId}`);
    return;
  } catch (error) {
    logger.error(`Error posting journal ${journalId} to ledger:`, error);
    throw error;
  }
};
