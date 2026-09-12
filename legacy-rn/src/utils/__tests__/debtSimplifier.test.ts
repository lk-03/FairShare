import { calculateSimplifiedDebts } from '../debtSimplifier';
import { GroupMember, Expense } from '@/types';

describe('calculateSimplifiedDebts Algorithm', () => {
  const members: GroupMember[] = [
    {
      id: 'm1',
      cohortId: 'c1',
      userId: 'user_A',
      role: 'admin',
      joinedAt: '',
      profile: { id: 'user_A', fullName: 'Alice', isGuest: false, createdAt: '' },
    },
    {
      id: 'm2',
      cohortId: 'c1',
      userId: 'user_B',
      role: 'member',
      joinedAt: '',
      profile: { id: 'user_B', fullName: 'Bob', isGuest: false, createdAt: '' },
    },
    {
      id: 'm3',
      cohortId: 'c1',
      userId: 'user_C',
      role: 'member',
      joinedAt: '',
      profile: { id: 'user_C', fullName: 'Charlie', isGuest: false, createdAt: '' },
    },
  ];

  it('should simplify simple pairwise debt', () => {
    const expenses: Expense[] = [
      {
        id: 'exp1',
        cohortId: 'c1',
        title: 'Dinner',
        category: 'Food',
        totalAmount: 300,
        currency: 'INR',
        paidByUserId: 'user_A',
        splitType: 'equal',
        splits: [
          { userId: 'user_A', amount: 100 },
          { userId: 'user_B', amount: 100 },
          { userId: 'user_C', amount: 100 },
        ],
        createdAt: '',
        updatedAt: '',
      },
    ];

    const result = calculateSimplifiedDebts('c1', members, expenses);

    expect(result.netBalances['user_A']).toBe(200);
    expect(result.netBalances['user_B']).toBe(-100);
    expect(result.netBalances['user_C']).toBe(-100);

    expect(result.simplifiedDebts.length).toBe(2);
    expect(result.simplifiedDebts).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ fromUserId: 'user_B', toUserId: 'user_A', amount: 100 }),
        expect.objectContaining({ fromUserId: 'user_C', toUserId: 'user_A', amount: 100 }),
      ])
    );
  });

  it('should resolve circular debt (A paid B, B paid C, C paid A)', () => {
    const expenses: Expense[] = [
      // A pays 30 for A & B ($15 each) -> B owes A 15
      {
        id: 'exp1',
        cohortId: 'c1',
        title: 'Lunch',
        category: 'Food',
        totalAmount: 30,
        currency: 'INR',
        paidByUserId: 'user_A',
        splitType: 'equal',
        splits: [
          { userId: 'user_A', amount: 15 },
          { userId: 'user_B', amount: 15 },
        ],
        createdAt: '',
        updatedAt: '',
      },
      // B pays 30 for B & C ($15 each) -> C owes B 15
      {
        id: 'exp2',
        cohortId: 'c1',
        title: 'Movie',
        category: 'Entertainment',
        totalAmount: 30,
        currency: 'INR',
        paidByUserId: 'user_B',
        splitType: 'equal',
        splits: [
          { userId: 'user_B', amount: 15 },
          { userId: 'user_C', amount: 15 },
        ],
        createdAt: '',
        updatedAt: '',
      },
      // C pays 30 for C & A ($15 each) -> A owes C 15
      {
        id: 'exp3',
        cohortId: 'c1',
        title: 'Cab',
        category: 'Travel',
        totalAmount: 30,
        currency: 'INR',
        paidByUserId: 'user_C',
        splitType: 'equal',
        splits: [
          { userId: 'user_C', amount: 15 },
          { userId: 'user_A', amount: 15 },
        ],
        createdAt: '',
        updatedAt: '',
      },
    ];

    const result = calculateSimplifiedDebts('c1', members, expenses);

    // Everyone spent 30 and received 30 worth -> Net balances should all be 0
    expect(result.netBalances['user_A']).toBe(0);
    expect(result.netBalances['user_B']).toBe(0);
    expect(result.netBalances['user_C']).toBe(0);

    // Simplified debts should be 0 transactions!
    expect(result.simplifiedDebts.length).toBe(0);
  });
});
