import { EventCohort, GroupMember, Expense, ExpenseSplit, SplitType } from '../types';

export interface SplitwiseImportPreview {
  groupName: string;
  memberNames: string[];
  totalTransactions: number;
  totalExpensesCount: number;
  totalPaymentsCount: number;
  totalTurnover: number;
  currency: string;
  startDate?: string;
  endDate?: string;
}

export type MemberAllocation =
  | { type: 'assign'; targetUserId: string; targetName?: string }
  | { type: 'shadow'; shadowName?: string };

export interface CohortImportResult {
  newShadowMembers: GroupMember[];
  expenses: Expense[];
  preview: SplitwiseImportPreview;
}

export interface SplitwiseImportResult {
  cohort: EventCohort;
  members: GroupMember[];
  expenses: Expense[];
  preview: SplitwiseImportPreview;
}

/**
 * Robust CSV line tokenizer handling quotes, commas within quotes, and escaped quotes.
 */
export function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let cur = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i++; // skip escaped quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === ',' && !inQuotes) {
      result.push(cur.trim());
      cur = '';
    } else {
      cur += char;
    }
  }
  result.push(cur.trim());
  return result;
}

/**
 * Normalizes member names from Splitwise headers (e.g. removes "(removed)").
 */
export function cleanMemberName(raw: string): string {
  return raw.replace(/\s*\(removed\)\s*$/i, '').trim();
}

/**
 * Maps Splitwise category strings to FairShare categories.
 */
export function mapSplitwiseCategory(rawCategory: string): string {
  const cat = rawCategory.toLowerCase();
  if (cat.includes('groceries') || cat.includes('household') || cat.includes('furniture') || cat.includes('water')) {
    return 'house';
  }
  if (cat.includes('dining') || cat.includes('food') || cat.includes('restaurant')) {
    return 'dining';
  }
  if (cat.includes('gas') || cat.includes('fuel') || cat.includes('car') || cat.includes('taxi') || cat.includes('bicycle')) {
    return 'transport';
  }
  if (cat.includes('trip') || cat.includes('hotel') || cat.includes('flight') || cat.includes('ticket')) {
    return 'trip';
  }
  if (cat.includes('utilities') || cat.includes('electricity') || cat.includes('wifi') || cat.includes('eb')) {
    return 'utilities';
  }
  return 'general';
}

/**
 * Quick, non-blocking preview extractor for Splitwise CSV.
 */
export function parseSplitwisePreview(csvContent: string): SplitwiseImportPreview {
  const lines = csvContent
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lines.length === 0) {
    throw new Error('CSV file is empty.');
  }

  const header = parseCsvLine(lines[0]);
  if (header.length < 5) {
    throw new Error('Invalid Splitwise CSV header format. Expected at least 5 standard columns.');
  }

  const rawMemberHeaders = header.slice(5);
  const memberNames = rawMemberHeaders.map(cleanMemberName).filter((name) => name.length > 0);

  if (memberNames.length === 0) {
    throw new Error('No group members found in the CSV header.');
  }

  let totalTurnover = 0;
  let totalExpensesCount = 0;
  let totalPaymentsCount = 0;
  let startDate: string | undefined;
  let endDate: string | undefined;

  for (let r = 1; r < lines.length; r++) {
    const row = parseCsvLine(lines[r]);
    if (row.length < 5) continue;

    const dateStr = row[0];
    const category = row[2];
    const cost = Math.abs(parseFloat(row[3]) || 0);

    if (!startDate || dateStr < startDate) startDate = dateStr;
    if (!endDate || dateStr > endDate) endDate = dateStr;

    const isPayment = category.toLowerCase() === 'payment' || /paid/i.test(row[1] || '');
    if (isPayment) {
      totalPaymentsCount++;
    } else {
      totalExpensesCount++;
      totalTurnover += cost;
    }
  }

  return {
    groupName: 'Splitwise Group',
    memberNames,
    totalTransactions: lines.length - 1,
    totalExpensesCount,
    totalPaymentsCount,
    totalTurnover: Number(totalTurnover.toFixed(2)),
    currency: 'INR',
    startDate,
    endDate,
  };
}

/**
 * Parses a Splitwise export.csv directly into an existing cohort with custom admin allocations.
 */
export function parseSplitwiseCsvForCohort(
  cohortId: string,
  csvContent: string,
  allocations: Record<string, MemberAllocation>,
  existingMembers: GroupMember[] = []
): CohortImportResult {
  const lines = csvContent
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lines.length === 0) {
    throw new Error('CSV file is empty.');
  }

  const header = parseCsvLine(lines[0]);
  if (header.length < 5) {
    throw new Error('Invalid Splitwise CSV header format. Expected at least 5 columns.');
  }

  const rawMemberHeaders = header.slice(5);
  const memberNames = rawMemberHeaders.map(cleanMemberName).filter((name) => name.length > 0);

  if (memberNames.length === 0) {
    throw new Error('No group members found in the CSV header.');
  }

  const newShadowMembers: GroupMember[] = [];
  const memberIdMap: Record<string, string> = {};

  const existingMemberMap = new Map<string, GroupMember>();
  existingMembers.forEach((m) => {
    existingMemberMap.set(m.userId, m);
  });

  const timestamp = Date.now();

  memberNames.forEach((name, index) => {
    const alloc = allocations[name];

    if (alloc && alloc.type === 'assign' && alloc.targetUserId) {
      memberIdMap[name] = alloc.targetUserId;
    } else {
      // Create as Shadow Member
      const shadowUserId = `user_shadow_${timestamp}_${index}`;
      memberIdMap[name] = shadowUserId;

      const shadowDisplayName = (alloc && alloc.type === 'shadow' && alloc.shadowName) ? alloc.shadowName : name;

      newShadowMembers.push({
        id: `gm_shadow_${timestamp}_${index}`,
        cohortId,
        userId: shadowUserId,
        role: 'member',
        joinedAt: new Date().toISOString(),
        isPlaceholder: true,
        originalCsvName: name,
        profile: {
          id: shadowUserId,
          fullName: shadowDisplayName,
          nickname: shadowDisplayName,
          username: shadowDisplayName.toLowerCase().replace(/[^a-z0-9_]/g, '_').slice(0, 15),
          isGuest: true,
          createdAt: new Date().toISOString(),
        },
      });
    }
  });

  const expenses: Expense[] = [];
  let totalTurnover = 0;
  let totalExpensesCount = 0;
  let totalPaymentsCount = 0;
  let startDate: string | undefined;
  let endDate: string | undefined;

  for (let r = 1; r < lines.length; r++) {
    const row = parseCsvLine(lines[r]);
    if (row.length < 5) continue;

    const dateStr = row[0];
    const description = row[1];
    const category = row[2];
    const cost = Math.abs(parseFloat(row[3]) || 0);
    const rowCurrency = row[4] || 'INR';

    if (cost === 0 && !description) continue;

    if (!startDate || dateStr < startDate) startDate = dateStr;
    if (!endDate || dateStr > endDate) endDate = dateStr;

    // Parse member net values
    const memberNetValues: Record<string, number> = {};
    for (let m = 0; m < memberNames.length; m++) {
      const name = memberNames[m];
      const val = parseFloat(row[5 + m]) || 0;
      memberNetValues[name] = val;
    }

    const isPayment = category.toLowerCase() === 'payment' || /paid/i.test(description);

    if (isPayment) {
      totalPaymentsCount++;
      let payerName = memberNames[0];
      let receiverName = memberNames[1] || memberNames[0];

      for (const [name, val] of Object.entries(memberNetValues)) {
        if (val > 0) payerName = name;
        if (val < 0) receiverName = name;
      }

      const payerId = memberIdMap[payerName];
      const receiverId = memberIdMap[receiverName];

      expenses.push({
        id: `exp_sw_${timestamp}_${r}`,
        cohortId,
        title: description || `${payerName} paid ${receiverName}`,
        category: 'Payment',
        totalAmount: cost,
        currency: rowCurrency,
        paidByUserId: payerId,
        splitType: 'exact',
        splits: [
          { userId: receiverId, amount: cost, percentage: 100 },
        ],
        notes: `Imported settlement from Splitwise on ${dateStr}`,
        createdAt: new Date(dateStr || Date.now()).toISOString(),
        updatedAt: new Date(dateStr || Date.now()).toISOString(),
      });
    } else {
      totalExpensesCount++;
      totalTurnover += cost;

      let highestPositiveVal = -Infinity;
      let primaryPayerName = memberNames[0];

      for (const [name, val] of Object.entries(memberNetValues)) {
        if (val > highestPositiveVal) {
          highestPositiveVal = val;
          primaryPayerName = name;
        }
      }

      const payerId = memberIdMap[primaryPayerName];

      const splits: ExpenseSplit[] = [];
      let totalNonPayerOwed = 0;

      for (const name of memberNames) {
        const userId = memberIdMap[name];
        const val = memberNetValues[name];

        if (name === primaryPayerName) continue;

        if (val < 0) {
          const owedShare = Math.abs(val);
          totalNonPayerOwed += owedShare;
          splits.push({
            userId,
            amount: Number(owedShare.toFixed(2)),
            percentage: cost > 0 ? Number(((owedShare / cost) * 100).toFixed(2)) : 0,
          });
        }
      }

      const payerShare = Math.max(0, cost - totalNonPayerOwed);
      if (payerShare > 0 || splits.length === 0) {
        splits.unshift({
          userId: payerId,
          amount: Number(payerShare.toFixed(2)),
          percentage: cost > 0 ? Number(((payerShare / cost) * 100).toFixed(2)) : 0,
        });
      }

      let splitType: SplitType = 'exact';
      const nonZeroSplits = splits.filter((s) => s.amount > 0);
      if (
        nonZeroSplits.length === memberNames.length &&
        nonZeroSplits.every((s) => Math.abs(s.amount - cost / memberNames.length) < 0.05)
      ) {
        splitType = 'equal';
      }

      expenses.push({
        id: `exp_sw_${timestamp}_${r}`,
        cohortId,
        title: description || 'Untitled Expense',
        category: mapSplitwiseCategory(category),
        totalAmount: cost,
        currency: rowCurrency,
        paidByUserId: payerId,
        splitType,
        splits,
        createdAt: new Date(dateStr || Date.now()).toISOString(),
        updatedAt: new Date(dateStr || Date.now()).toISOString(),
      });
    }
  }

  const preview: SplitwiseImportPreview = {
    groupName: 'Imported History',
    memberNames,
    totalTransactions: expenses.length,
    totalExpensesCount,
    totalPaymentsCount,
    totalTurnover: Number(totalTurnover.toFixed(2)),
    currency: 'INR',
    startDate,
    endDate,
  };

  return {
    newShadowMembers,
    expenses,
    preview,
  };
}

/**
 * Backward-compatible helper for standalone group creation from CSV.
 */
export function parseSplitwiseCsv(
  csvContent: string,
  options: {
    groupName?: string;
    currentUserId: string;
    currentUserName?: string;
    selectedUserMapping?: Record<string, string>;
  }
): SplitwiseImportResult {
  const preview = parseSplitwisePreview(csvContent);
  const cohortId = `cohort_sw_${Date.now()}`;
  const currency = 'INR';

  const allocations: Record<string, MemberAllocation> = {};
  preview.memberNames.forEach((name) => {
    let targetUserId = options.selectedUserMapping?.[name];
    if (!targetUserId && options.currentUserName && name.toLowerCase() === options.currentUserName.toLowerCase()) {
      targetUserId = options.currentUserId;
    }

    if (targetUserId) {
      allocations[name] = { type: 'assign', targetUserId };
    } else {
      allocations[name] = { type: 'shadow', shadowName: name };
    }
  });

  const { newShadowMembers, expenses } = parseSplitwiseCsvForCohort(cohortId, csvContent, allocations);

  const cohort: EventCohort = {
    id: cohortId,
    name: options.groupName?.trim() || preview.groupName,
    description: `Imported from Splitwise (${expenses.length} records)`,
    category: 'house',
    currency,
    createdBy: options.currentUserId,
    inviteCode: Math.random().toString(36).substring(2, 8).toUpperCase(),
    createdAt: preview.startDate ? new Date(preview.startDate).toISOString() : new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  // Build members list including current user if assigned
  const members: GroupMember[] = [...newShadowMembers];
  const hasCurrentUser = Object.values(allocations).some((a) => a.type === 'assign' && a.targetUserId === options.currentUserId);
  if (hasCurrentUser) {
    members.unshift({
      id: `gm_admin_${Date.now()}`,
      cohortId,
      userId: options.currentUserId,
      role: 'admin',
      joinedAt: new Date().toISOString(),
      profile: {
        id: options.currentUserId,
        fullName: options.currentUserName || 'Admin',
        nickname: options.currentUserName || 'Admin',
        username: (options.currentUserName || 'admin').toLowerCase().replace(/[^a-z0-9_]/g, '_').slice(0, 15),
        isGuest: false,
        createdAt: new Date().toISOString(),
      },
    });
  }

  return {
    cohort,
    members,
    expenses,
    preview,
  };
}
