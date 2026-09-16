// javascript
// functions/accounts.js
const DEFAULT_TYPES = {
  ASSET: 'Asset',
  LIABILITY: 'Liability',
  EQUITY: 'Equity',
  INCOME: 'Income',
  EXPENSE: 'Expense',
};

class AccountClass {
  constructor(code, name, type) {
    this.code = code; // unique code like 'A' or 'ASSET'
    this.name = name; // display name like 'Asset'
    this.type = type; // one of DEFAULT_TYPES
    this.subclasses = [];
  }

  addSub(sub) {
    if (sub instanceof AccountSubClass) {
      sub.parent = this;
      this.subclasses.push(sub);
    }
    return sub;
  }
}

class AccountSubClass {
  constructor(code, name, parentCode = null) {
    this.code = code; // unique code like 'A-CA' or 'ASSET_CURRENT'
    this.name = name; // e.g. 'Current Asset'
    this.parent = parentCode; // parent may be replaced with object by registry
  }
}

class AccountRegistry {
  constructor() {
    this.classes = new Map(); // key: class.code -> AccountClass
    this.subs = new Map(); // key: sub.code -> AccountSubClass
  }

  registerClass(accClass) {
    this.classes.set(accClass.code, accClass);
    return accClass;
  }

  registerSub(sub) {
    this.subs.set(sub.code, sub);
    // attach to parent object if parent exists
    if (typeof sub.parent === 'string' && this.classes.has(sub.parent)) {
      const parent = this.classes.get(sub.parent);
      parent.addSub(sub);
      sub.parent = parent;
    }
    return sub;
  }

  findClassByName(name) {
    for (const c of this.classes.values()) if (c.name === name) return c;
    return null;
  }

  findSubByName(name) {
    for (const s of this.subs.values()) if (s.name === name) return s;
    return null;
  }

  allClasses() {
    return Array.from(this.classes.values());
  }

  allSubs() {
    return Array.from(this.subs.values());
  }
}

// helpers to compute balances and reports
function isDebitPositive(type) {
  // Assets and Expenses have debit-positive balances
  return type === DEFAULT_TYPES.ASSET || type === DEFAULT_TYPES.EXPENSE;
}

function aggregateLedger(ledgerEntries = []) {
  // ledgerEntries: array of { account: 'accountName', type: 'debit'|'credit', amount: number }
  const map = new Map();
  ledgerEntries.forEach((e) => {
    const acct = e.account || 'unknown';
    const t = (e.type || 'debit').toLowerCase();
    const amt = Number(e.amount || 0);
    if (!map.has(acct)) map.set(acct, { debit: 0, credit: 0 });
    const rec = map.get(acct);
    if (t === 'debit') rec.debit += amt;
    else rec.credit += amt;
  });
  // compute net per account
  const result = {};
  map.forEach((v, k) => {
    result[k] = { debit: v.debit, credit: v.credit, net: v.debit - v.credit };
  });
  return result;
}

function computeTrialBalance(ledgerEntries = [], accountClassMap = {}) {
  // accountClassMap: { accountName -> { classCode, subCode, type } } optional mapping
  const agg = aggregateLedger(ledgerEntries);
  const trial = { byAccount: {}, totals: { debit: 0, credit: 0 } };

  Object.keys(agg).forEach((acct) => {
    const rec = agg[acct];
    // determine normal side using mapping if provided
    const meta = accountClassMap[acct] || {};
    const type = meta.type || DEFAULT_TYPES.ASSET; // default treat as asset if unknown
    let balance = rec.net;
    // present balance as debit/credit pair
    if (balance >= 0) {
      // positive net = debit balance
      trial.byAccount[acct] = { debit: balance, credit: 0, type };
      trial.totals.debit += balance;
    } else {
      trial.byAccount[acct] = { debit: 0, credit: -balance, type };
      trial.totals.credit += -balance;
    }
  });

  return trial;
}

function generateProfitAndLoss(ledgerEntries = [], accountClassMap = {}) {
  // returns { totalIncome, totalExpense, grossProfit, details }
  const tb = computeTrialBalance(ledgerEntries, accountClassMap);
  let totalIncome = 0;
  let totalExpense = 0;
  const details = { incomes: {}, expenses: {} };

  Object.entries(tb.byAccount).forEach(([acct, rec]) => {
    const type = (accountClassMap[acct] && accountClassMap[acct].type) || rec.type || DEFAULT_TYPES.ASSET;
    const balance = rec.credit - rec.debit; // income normally credit-positive
    if (type === DEFAULT_TYPES.INCOME) {
      const amt = Math.max(0, balance);
      details.incomes[acct] = amt;
      totalIncome += amt;
    } else if (type === DEFAULT_TYPES.EXPENSE) {
      const amt = Math.max(0, -balance);
      details.expenses[acct] = amt;
      totalExpense += amt;
    }
  });

  const netProfit = totalIncome - totalExpense;
  return { totalIncome, totalExpense, netProfit, details };
}

function generateBalanceSheet(ledgerEntries = [], accountClassMap = {}) {
  // returns { assets: {}, liabilities: {}, equity: {}, totals }
  const tb = computeTrialBalance(ledgerEntries, accountClassMap);
  const assets = {}, liabilities = {}, equity = {};
  let totalAssets = 0, totalLiabilities = 0, totalEquity = 0;

  Object.entries(tb.byAccount).forEach(([acct, rec]) => {
    const meta = accountClassMap[acct] || {};
    const type = meta.type || rec.type || DEFAULT_TYPES.ASSET;
    // For presentation normalize to positive amounts:
    let bal = rec.debit - rec.credit; // debit - credit
    if (type === DEFAULT_TYPES.ASSET) {
      const val = Math.max(0, bal);
      assets[acct] = val;
      totalAssets += val;
    } else if (type === DEFAULT_TYPES.LIABILITY) {
      const val = Math.max(0, -bal);
      liabilities[acct] = val;
      totalLiabilities += val;
    } else if (type === DEFAULT_TYPES.EQUITY) {
      const val = Math.max(0, -bal);
      equity[acct] = val;
      totalEquity += val;
    }
  });

  return {
    assets, liabilities, equity,
    totals: { totalAssets, totalLiabilities, totalEquity, balanced: (Math.abs(totalAssets - (totalLiabilities + totalEquity)) < 0.01) },
  };
}

// register some useful defaults
function registerDefaultChart() {
  const reg = new AccountRegistry();

  const A = new AccountClass('A', 'Asset', DEFAULT_TYPES.ASSET);
  const L = new AccountClass('L', 'Liability', DEFAULT_TYPES.LIABILITY);
  const E = new AccountClass('E', 'Equity', DEFAULT_TYPES.EQUITY);
  const I = new AccountClass('I', 'Income', DEFAULT_TYPES.INCOME);
  const X = new AccountClass('X', 'Expense', DEFAULT_TYPES.EXPENSE);

  reg.registerClass(A);
  reg.registerClass(L);
  reg.registerClass(E);
  reg.registerClass(I);
  reg.registerClass(X);

  reg.registerSub(new AccountSubClass('A-CURRENT', 'Current Asset', 'A'));
  reg.registerSub(new AccountSubClass('A-FIXED', 'Fixed Asset', 'A'));
  reg.registerSub(new AccountSubClass('A-INVENTORY', 'Inventory', 'A'));

  reg.registerSub(new AccountSubClass('L-CURRENT', 'Current Liability', 'L'));
  reg.registerSub(new AccountSubClass('L-LONG', 'Long Term Liability', 'L'));
  reg.registerSub(new AccountSubClass('E-CAPITAL', 'Capital / Equity', 'E'));

  reg.registerSub(new AccountSubClass('I-SALES', 'Sales Revenue', 'I'));
  reg.registerSub(new AccountSubClass('X-COGS', 'Cost of Goods Sold', 'X'));
  reg.registerSub(new AccountSubClass('X-OPER', 'Operating Expenses', 'X'));
  reg.registerSub(new AccountSubClass('X-PURDISC', 'Purchase Discount', 'X'));

  return reg;
}

module.exports = {
  DEFAULT_TYPES,
  AccountClass,
  AccountSubClass,
  AccountRegistry,
  registerDefaultChart,
  aggregateLedger,
  computeTrialBalance,
  generateProfitAndLoss,
  generateBalanceSheet,
};
