import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { zustandMMKVStorage } from '@/services/storage/mmkv';
import {
  UserProfile,
  EventCohort,
  GroupMember,
  Expense,
  TransactionComment,
  DebtSimplificationResult,
} from '@/types';

interface ExpenseState {
  // Current Active User
  currentUser: UserProfile;

  // Event Cohorts & Groups
  cohorts: EventCohort[];
  activeCohortId: string | null;
  members: Record<string, GroupMember[]>; // cohortId -> GroupMember[]

  // Expenses & Ledger
  expenses: Record<string, Expense[]>; // cohortId -> Expense[]
  comments: Record<string, TransactionComment[]>; // expenseId -> TransactionComment[]
  sharedLists: Record<string, import('@/types').SharedListItem[]>; // cohortId -> SharedListItem[]
  reminderSettings: Record<string, import('@/types').PersonalReminderSettings>; // cohortId -> PersonalReminderSettings

  // Local Offline Queue
  offlineQueue: any[];

  // Actions
  setCurrentUser: (user: UserProfile) => void;
  setActiveCohort: (cohortId: string | null) => void;
  addCohort: (cohort: EventCohort) => void;
  updateCohort: (cohortId: string, updates: Partial<EventCohort>) => void;
  addExpense: (expense: Expense) => void;
  deleteExpense: (expenseId: string, cohortId: string) => void;
  addComment: (comment: TransactionComment) => void;
  joinCohortByInviteCode: (inviteCode: string) => EventCohort | null;

  // Shared Needs List Actions
  addListItem: (item: import('@/types').SharedListItem) => void;
  toggleListItem: (itemId: string, cohortId: string) => void;
  deleteListItem: (itemId: string, cohortId: string) => void;
  updateReminderSettings: (cohortId: string, settings: import('@/types').PersonalReminderSettings) => void;
}

const DEFAULT_CURRENT_USER: UserProfile = {
  id: 'usr_me',
  fullName: 'Kowsic L',
  email: 'kowsic@fairshare.app',
  vpaId: 'kowsic@okaxis',
  isGuest: false,
  createdAt: new Date().toISOString(),
};

const DEFAULT_COHORTS: EventCohort[] = [
  {
    id: 'cohort_goa',
    name: 'Goa Summer Trip 🏖️',
    description: 'Beach villa, car rental, and dinner expenses',
    category: 'trip',
    currency: 'INR',
    createdBy: 'usr_me',
    inviteCode: 'GOA2026',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cohort_apt',
    name: 'Apartment 402 🏠',
    description: 'Monthly rent, wifi, and grocery bills',
    category: 'house',
    currency: 'INR',
    createdBy: 'usr_alex',
    inviteCode: 'APT402',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

const DEFAULT_MEMBERS: Record<string, GroupMember[]> = {
  cohort_goa: [
    {
      id: 'm1',
      cohortId: 'cohort_goa',
      userId: 'usr_me',
      role: 'admin',
      joinedAt: new Date().toISOString(),
      profile: DEFAULT_CURRENT_USER,
    },
    {
      id: 'm2',
      cohortId: 'cohort_goa',
      userId: 'usr_alex',
      role: 'member',
      joinedAt: new Date().toISOString(),
      profile: {
        id: 'usr_alex',
        fullName: 'Alex Rivera',
        vpaId: 'alex@upi',
        isGuest: false,
        createdAt: new Date().toISOString(),
      },
    },
    {
      id: 'm3',
      cohortId: 'cohort_goa',
      userId: 'usr_priya',
      role: 'member',
      joinedAt: new Date().toISOString(),
      profile: {
        id: 'usr_priya',
        fullName: 'Priya Sharma',
        vpaId: 'priya@ybl',
        isGuest: false,
        createdAt: new Date().toISOString(),
      },
    },
  ],
  cohort_apt: [
    {
      id: 'm1',
      cohortId: 'cohort_apt',
      userId: 'usr_me',
      role: 'member',
      joinedAt: new Date().toISOString(),
      profile: DEFAULT_CURRENT_USER,
    },
    {
      id: 'm2',
      cohortId: 'cohort_apt',
      userId: 'usr_alex',
      role: 'admin',
      joinedAt: new Date().toISOString(),
      profile: {
        id: 'usr_alex',
        fullName: 'Alex Rivera',
        vpaId: 'alex@upi',
        isGuest: false,
        createdAt: new Date().toISOString(),
      },
    },
  ],
};

const DEFAULT_EXPENSES: Record<string, Expense[]> = {
  cohort_goa: [
    {
      id: 'exp_1',
      cohortId: 'cohort_goa',
      title: 'Beach Resort Booking',
      category: 'Accommodation',
      totalAmount: 12000,
      currency: 'INR',
      paidByUserId: 'usr_me',
      splitType: 'equal',
      splits: [
        { userId: 'usr_me', amount: 4000 },
        { userId: 'usr_alex', amount: 4000 },
        { userId: 'usr_priya', amount: 4000 },
      ],
      notes: 'Paid via GPay to Villa Manager',
      createdAt: new Date(Date.now() - 86400000 * 2).toISOString(),
      updatedAt: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: 'exp_2',
      cohortId: 'cohort_goa',
      title: 'Seafood Dinner & Drinks 🦐',
      category: 'Dining',
      totalAmount: 4500,
      currency: 'INR',
      paidByUserId: 'usr_alex',
      splitType: 'equal',
      splits: [
        { userId: 'usr_me', amount: 1500 },
        { userId: 'usr_alex', amount: 1500 },
        { userId: 'usr_priya', amount: 1500 },
      ],
      createdAt: new Date(Date.now() - 86400000).toISOString(),
      updatedAt: new Date(Date.now() - 86400000).toISOString(),
    },
  ],
  cohort_apt: [
    {
      id: 'exp_3',
      cohortId: 'cohort_apt',
      title: 'High-Speed Fiber Wifi',
      category: 'Utilities',
      totalAmount: 1499,
      currency: 'INR',
      paidByUserId: 'usr_alex',
      splitType: 'equal',
      splits: [
        { userId: 'usr_me', amount: 749.5 },
        { userId: 'usr_alex', amount: 749.5 },
      ],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
  ],
};

export const useExpenseStore = create<ExpenseState>()(
  persist(
    (set, get) => ({
      currentUser: DEFAULT_CURRENT_USER,
      cohorts: DEFAULT_COHORTS,
      activeCohortId: 'cohort_goa',
      members: DEFAULT_MEMBERS,
      expenses: DEFAULT_EXPENSES,
      comments: {},
      sharedLists: {
        cohort_goa: [
          {
            id: 'item_1',
            cohortId: 'cohort_goa',
            title: 'Milk 1L & Bread',
            addedByUserId: 'usr_me',
            isCompleted: false,
            createdAt: new Date().toISOString(),
          },
          {
            id: 'item_2',
            cohortId: 'cohort_goa',
            title: 'Eggs (Dozen)',
            addedByUserId: 'usr_alex',
            isCompleted: true,
            completedAt: new Date().toISOString(),
            createdAt: new Date(Date.now() - 86400000).toISOString(),
          },
        ],
      },
      reminderSettings: {
        cohort_goa: {
          enabled: true,
          frequencyDays: 2,
          reminderTime: '18:00',
        },
      },
      offlineQueue: [],

      setCurrentUser: (user) => set({ currentUser: user }),

      setActiveCohort: (cohortId) => set({ activeCohortId: cohortId }),

      addCohort: (cohort) =>
        set((state) => ({
          cohorts: [cohort, ...state.cohorts],
          activeCohortId: cohort.id,
          members: {
            ...state.members,
            [cohort.id]: [
              {
                id: `m_${Date.now()}`,
                cohortId: cohort.id,
                userId: state.currentUser.id,
                role: 'admin',
                joinedAt: new Date().toISOString(),
                profile: state.currentUser,
              },
            ],
          },
          expenses: {
            ...state.expenses,
            [cohort.id]: [],
          },
        })),

      updateCohort: (cohortId, updates) =>
        set((state) => ({
          cohorts: state.cohorts.map((c) =>
            c.id === cohortId ? { ...c, ...updates, updatedAt: new Date().toISOString() } : c
          ),
        })),

      addListItem: (item) =>
        set((state) => {
          const list = state.sharedLists[item.cohortId] || [];
          return {
            sharedLists: {
              ...state.sharedLists,
              [item.cohortId]: [item, ...list],
            },
          };
        }),

      toggleListItem: (itemId, cohortId) =>
        set((state) => {
          const list = state.sharedLists[cohortId] || [];
          const updated = list.map((it) => {
            if (it.id === itemId) {
              const nextVal = !it.isCompleted;
              return {
                ...it,
                isCompleted: nextVal,
                completedAt: nextVal ? new Date().toISOString() : undefined,
              };
            }
            return it;
          });
          return {
            sharedLists: {
              ...state.sharedLists,
              [cohortId]: updated,
            },
          };
        }),

      deleteListItem: (itemId, cohortId) =>
        set((state) => {
          const list = state.sharedLists[cohortId] || [];
          return {
            sharedLists: {
              ...state.sharedLists,
              [cohortId]: list.filter((it) => it.id !== itemId),
            },
          };
        }),

      updateReminderSettings: (cohortId, settings) =>
        set((state) => ({
          reminderSettings: {
            ...state.reminderSettings,
            [cohortId]: settings,
          },
        })),

      addExpense: (expense) =>
        set((state) => {
          const cohortExpenses = state.expenses[expense.cohortId] || [];
          return {
            expenses: {
              ...state.expenses,
              [expense.cohortId]: [expense, ...cohortExpenses],
            },
          };
        }),

      deleteExpense: (expenseId, cohortId) =>
        set((state) => ({
          expenses: {
            ...state.expenses,
            [cohortId]: (state.expenses[cohortId] || []).filter(
              (e) => e.id !== expenseId
            ),
          },
        })),

      addComment: (comment) =>
        set((state) => {
          const list = state.comments[comment.expenseId] || [];
          return {
            comments: {
              ...state.comments,
              [comment.expenseId]: [...list, comment],
            },
          };
        }),

      joinCohortByInviteCode: (inviteCode) => {
        const state = get();
        const found = state.cohorts.find(
          (c) => c.inviteCode.toUpperCase() === inviteCode.trim().toUpperCase()
        );
        if (found) {
          set({ activeCohortId: found.id });
          return found;
        }
        return null;
      },
    }),
    {
      name: 'fairshare-store-v1',
      storage: createJSONStorage(() => zustandMMKVStorage),
    }
  )
);
