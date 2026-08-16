import { Expense, GroupMember, DirectDebt, DebtSimplificationResult } from '@/types';

/**
 * Calculates net balance per user and applies a Greedy Min-Flow Graph Algorithm
 * to simplify N debts down to the minimal possible direct transactions.
 */
export function calculateSimplifiedDebts(
  cohortId: string,
  members: GroupMember[],
  expenses: Expense[]
): DebtSimplificationResult {
  const netBalances: Record<string, number> = {};

  // Initialize all members with 0 balance
  members.forEach((m) => {
    netBalances[m.userId] = 0;
  });

  // Calculate net balances for each expense
  expenses.forEach((expense) => {
    if (expense.cohortId !== cohortId) return;

    const paidBy = expense.paidByUserId;
    const totalAmount = expense.totalAmount;

    // Credit the person who paid
    netBalances[paidBy] = (netBalances[paidBy] || 0) + totalAmount;

    // Debit each participant according to their split amount
    expense.splits.forEach((split) => {
      netBalances[split.userId] = (netBalances[split.userId] || 0) - split.amount;
    });
  });

  // Separate debtors (people who owe money) and creditors (people owed money)
  const debtors: { userId: string; amount: number }[] = [];
  const creditors: { userId: string; amount: number }[] = [];

  Object.entries(netBalances).forEach(([userId, balance]) => {
    // Round to 2 decimal places to avoid floating point precision issues
    const rounded = Math.round(balance * 100) / 100;
    netBalances[userId] = rounded;

    if (rounded < -0.01) {
      debtors.push({ userId, amount: Math.abs(rounded) });
    } else if (rounded > 0.01) {
      creditors.push({ userId, amount: rounded });
    }
  });

  // Sort debtors and creditors descending by amount
  debtors.sort((a, b) => b.amount - a.amount);
  creditors.sort((a, b) => b.amount - a.amount);

  const simplifiedDebts: DirectDebt[] = [];

  let i = 0; // debtor index
  let j = 0; // creditor index

  // Greedy matching: match largest debtor with largest creditor
  while (i < debtors.length && j < creditors.length) {
    const debtor = debtors[i];
    const creditor = creditors[j];

    const settledAmount = Math.min(debtor.amount, creditor.amount);

    if (settledAmount > 0.01) {
      const debtorMember = members.find((m) => m.userId === debtor.userId);
      const creditorMember = members.find((m) => m.userId === creditor.userId);

      simplifiedDebts.push({
        fromUserId: debtor.userId,
        fromProfile: debtorMember?.profile,
        toUserId: creditor.userId,
        toProfile: creditorMember?.profile,
        amount: Math.round(settledAmount * 100) / 100,
        currency: expenses[0]?.currency || 'INR',
      });
    }

    debtor.amount -= settledAmount;
    creditor.amount -= settledAmount;

    if (debtor.amount < 0.01) i++;
    if (creditor.amount < 0.01) j++;
  }

  return {
    cohortId,
    netBalances,
    simplifiedDebts,
  };
}
