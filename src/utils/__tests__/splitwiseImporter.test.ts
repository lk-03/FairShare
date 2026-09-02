import fs from 'fs';
import path from 'path';
import {
  parseCsvLine,
  cleanMemberName,
  parseSplitwiseCsv,
  parseSplitwisePreview,
  parseSplitwiseCsvForCohort,
} from '../splitwiseImporter';
import { GroupMember } from '../../types';

describe('Splitwise Importer Utility', () => {
  it('correctly parses CSV line with quotes and commas', () => {
    const line = '2026-03-15,"Instamart(maggi,syrup,curd,banana)",Groceries,390.00,INR,-167.50,-167.50,335.00,0.00';
    const tokens = parseCsvLine(line);
    expect(tokens.length).toBe(9);
    expect(tokens[1]).toBe('Instamart(maggi,syrup,curd,banana)');
    expect(tokens[3]).toBe('390.00');
  });

  it('cleans member names stripping (removed)', () => {
    expect(cleanMemberName('keith james (removed)')).toBe('keith james');
    expect(cleanMemberName('LK')).toBe('LK');
    expect(cleanMemberName('  KATTU PUCHI  ')).toBe('KATTU PUCHI');
  });

  it('generates fast preview from CSV content', () => {
    const csvContent = `Date,Description,Category,Cost,Currency,LK,Njj,KATTU PUCHI,keith james
2026-03-15,"Instamart",Groceries,300.00,INR,200.00,-100.00,-100.00,0.00
2026-03-16,"Payment",Payment,100.00,INR,-100.00,100.00,0.00,0.00`;

    const preview = parseSplitwisePreview(csvContent);
    expect(preview.memberNames).toEqual(['LK', 'Njj', 'KATTU PUCHI', 'keith james']);
    expect(preview.totalTransactions).toBe(2);
    expect(preview.totalExpensesCount).toBe(1);
    expect(preview.totalPaymentsCount).toBe(1);
    expect(preview.totalTurnover).toBe(300);
  });

  it('imports CSV into existing cohort with member allocations and shadow members', () => {
    const csvContent = `Date,Description,Category,Cost,Currency,LK,Njj,KATTU PUCHI,keith james
2026-03-15,"Instamart",Groceries,300.00,INR,200.00,-100.00,-100.00,0.00
2026-03-16,"Payment",Payment,100.00,INR,-100.00,100.00,0.00,0.00`;

    const existingMembers: GroupMember[] = [
      { id: 'm1', cohortId: 'cohort_1', userId: 'user_lk', role: 'admin', joinedAt: '2026-01-01' },
      { id: 'm2', cohortId: 'cohort_1', userId: 'user_njj', role: 'member', joinedAt: '2026-01-01' },
      { id: 'm3', cohortId: 'cohort_1', userId: 'user_kattu', role: 'member', joinedAt: '2026-01-01' },
    ];

    const allocations = {
      'LK': { type: 'assign' as const, targetUserId: 'user_lk' },
      'Njj': { type: 'assign' as const, targetUserId: 'user_njj' },
      'KATTU PUCHI': { type: 'assign' as const, targetUserId: 'user_kattu' },
      'keith james': { type: 'shadow' as const, shadowName: 'Keith (Old Roommate)' },
    };

    const result = parseSplitwiseCsvForCohort('cohort_1', csvContent, allocations, existingMembers);

    expect(result.expenses.length).toBe(2);
    expect(result.newShadowMembers.length).toBe(1);
    expect(result.newShadowMembers[0].profile?.fullName).toBe('Keith (Old Roommate)');
    expect(result.newShadowMembers[0].isPlaceholder).toBe(true);

    // Expense 1: Paid by user_lk
    expect(result.expenses[0].paidByUserId).toBe('user_lk');
    expect(result.expenses[0].splits.find((s) => s.userId === 'user_njj')?.amount).toBe(100);
    expect(result.expenses[0].splits.find((s) => s.userId === 'user_kattu')?.amount).toBe(100);
  });

  it('imports the user export.csv file accurately', () => {
    const csvPath = path.resolve(__dirname, '../../../export.csv');
    if (!fs.existsSync(csvPath)) {
      console.warn('export.csv not found at root, skipping integration test');
      return;
    }

    const csvContent = fs.readFileSync(csvPath, 'utf8');
    const result = parseSplitwiseCsv(csvContent, {
      groupName: 'Housemates 2026',
      currentUserId: 'user_lk_1',
      currentUserName: 'LK',
    });

    expect(result.cohort.name).toBe('Housemates 2026');
    expect(result.members.length).toBe(4);
    expect(result.preview.memberNames).toEqual(['LK', 'Njj', 'KATTU PUCHI', 'keith james']);
    expect(result.expenses.length).toBeGreaterThan(200);
    expect(result.preview.totalTurnover).toBeGreaterThan(10000);

    // Verify no "Total balance" row exists as an expense
    const totalBalanceExpense = result.expenses.find((e) => e.title.toLowerCase().includes('total balance'));
    expect(totalBalanceExpense).toBeUndefined();
  });
});
