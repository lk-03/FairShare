import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { zustandMMKVStorage } from '@/services/storage/mmkv';
import {
  UserProfile,
  EventCohort,
  GroupMember,
  Expense,
  TransactionComment,
  SharedListItem,
  PersonalReminderSettings,
} from '@/types';
import {
  DEFAULT_CURRENT_USER,
  DEFAULT_COHORTS,
  DEFAULT_MEMBERS,
  DEFAULT_EXPENSES,
  DEFAULT_SHARED_LISTS,
  DEFAULT_REMINDER_SETTINGS,
} from '@/services/supabase/placeholderData';
import * as profileService from '@/services/supabase/profileService';
import * as groupService from '@/services/supabase/groupService';
import * as expenseService from '@/services/supabase/expenseService';

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
  sharedLists: Record<string, SharedListItem[]>; // cohortId -> SharedListItem[]
  reminderSettings: Record<string, PersonalReminderSettings>; // cohortId -> PersonalReminderSettings

  // Async & Sync Status
  isLoading: boolean;
  isSyncing: boolean;
  error: string | null;

  // Local Offline Queue
  offlineQueue: any[];

  // Async Fetchers & Data Synchronization
  fetchInitialData: () => Promise<void>;
  fetchCohorts: () => Promise<void>;
  fetchExpensesForCohort: (cohortId: string) => Promise<void>;
  refreshAll: () => Promise<void>;
  clearError: () => void;

  // User Actions
  setCurrentUser: (user: UserProfile) => void;
  setActiveCohort: (cohortId: string | null) => void;

  // Cohort Actions
  addCohort: (cohort: EventCohort) => Promise<EventCohort>;
  updateCohort: (cohortId: string, updates: Partial<EventCohort>) => Promise<void>;
  joinCohortByInviteCode: (inviteCode: string) => Promise<EventCohort | null>;

  // Expense Actions
  addExpense: (expense: Expense) => Promise<void>;
  updateExpense: (expense: Expense) => Promise<void>;
  deleteExpense: (expenseId: string, cohortId: string) => Promise<void>;
  addComment: (comment: TransactionComment) => Promise<void>;

  // Shared Needs List Actions
  addListItem: (item: SharedListItem) => void;
  toggleListItem: (itemId: string, cohortId: string) => void;
  deleteListItem: (itemId: string, cohortId: string) => void;
  updateReminderSettings: (cohortId: string, settings: PersonalReminderSettings) => void;
}

export const useExpenseStore = create<ExpenseState>()(
  persist(
    (set, get) => ({
      currentUser: DEFAULT_CURRENT_USER,
      cohorts: DEFAULT_COHORTS,
      activeCohortId: 'cohort_goa',
      members: DEFAULT_MEMBERS,
      expenses: DEFAULT_EXPENSES,
      comments: {},
      sharedLists: DEFAULT_SHARED_LISTS,
      reminderSettings: DEFAULT_REMINDER_SETTINGS,
      offlineQueue: [],

      isLoading: false,
      isSyncing: false,
      error: null,

      clearError: () => set({ error: null }),

      setCurrentUser: (user) => set({ currentUser: user }),

      setActiveCohort: (cohortId) => set({ activeCohortId: cohortId }),

      /**
       * Initial bootstrap fetch: grabs user profile, all cohorts, and expenses in parallel
       */
      fetchInitialData: async () => {
        set({ isLoading: true, error: null });
        try {
          // 1. Fetch current profile
          const user = await profileService.getCurrentProfile();

          // 2. Fetch cohorts and membership
          const { cohorts, members } = await groupService.fetchUserCohorts(user.id);

          // 3. Fetch expenses for all cohorts in parallel
          const expensesMap: Record<string, Expense[]> = {};
          await Promise.all(
            cohorts.map(async (c) => {
              const exps = await expenseService.fetchExpensesForCohort(c.id);
              expensesMap[c.id] = exps;
            })
          );

          set({
            currentUser: user,
            cohorts,
            members,
            expenses: {
              ...get().expenses,
              ...expensesMap,
            },
            activeCohortId: cohorts[0]?.id || null,
            isLoading: false,
          });
        } catch (err: any) {
          console.warn('[Store] fetchInitialData error:', err);
          set({
            isLoading: false,
            error: err?.message || 'Failed to fetch data from Supabase. Working in offline mode.',
          });
        }
      },

      /**
       * Refreshes all cohorts and expenses
       */
      refreshAll: async () => {
        set({ isSyncing: true, error: null });
        try {
          const user = get().currentUser;
          const { cohorts, members } = await groupService.fetchUserCohorts(user.id);

          const expensesMap: Record<string, Expense[]> = {};
          await Promise.all(
            cohorts.map(async (c) => {
              const exps = await expenseService.fetchExpensesForCohort(c.id);
              expensesMap[c.id] = exps;
            })
          );

          set({
            cohorts,
            members,
            expenses: {
              ...get().expenses,
              ...expensesMap,
            },
            isSyncing: false,
          });
        } catch (err: any) {
          console.warn('[Store] refreshAll error:', err);
          set({
            isSyncing: false,
            error: err?.message || 'Sync failed. Using cached data.',
          });
        }
      },

      /**
       * Fetches cohorts for current user
       */
      fetchCohorts: async () => {
        try {
          const user = get().currentUser;
          const { cohorts, members } = await groupService.fetchUserCohorts(user.id);
          set({ cohorts, members });
        } catch (err: any) {
          console.warn('[Store] fetchCohorts error:', err);
        }
      },

      /**
       * Fetches expenses for a specific cohort
       */
      fetchExpensesForCohort: async (cohortId: string) => {
        try {
          const exps = await expenseService.fetchExpensesForCohort(cohortId);
          set((state) => ({
            expenses: {
              ...state.expenses,
              [cohortId]: exps,
            },
          }));
        } catch (err: any) {
          console.warn(`[Store] fetchExpensesForCohort error for ${cohortId}:`, err);
        }
      },

      /**
       * Adds a new cohort with optimistic update + backend persistence
       */
      addCohort: async (cohort: EventCohort) => {
        const currentUser = get().currentUser;

        // Optimistic local state update
        const optimisticMember: GroupMember = {
          id: `m_${Date.now()}`,
          cohortId: cohort.id,
          userId: currentUser.id,
          role: 'admin',
          joinedAt: new Date().toISOString(),
          profile: currentUser,
        };

        set((state) => ({
          cohorts: [cohort, ...state.cohorts],
          activeCohortId: cohort.id,
          members: {
            ...state.members,
            [cohort.id]: [optimisticMember],
          },
          expenses: {
            ...state.expenses,
            [cohort.id]: [],
          },
        }));

        try {
          const { cohort: savedCohort, member: savedMember } = await groupService.createCohort(
            cohort,
            currentUser
          );

          // Reconcile saved cohort IDs if generated by DB
          if (savedCohort.id !== cohort.id) {
            set((state) => ({
              cohorts: state.cohorts.map((c) => (c.id === cohort.id ? savedCohort : c)),
              activeCohortId: savedCohort.id,
              members: {
                ...state.members,
                [savedCohort.id]: [savedMember],
              },
              expenses: {
                ...state.expenses,
                [savedCohort.id]: state.expenses[cohort.id] || [],
              },
            }));
            return savedCohort;
          }
        } catch (err) {
          console.warn('[Store] addCohort backend persistence failed:', err);
        }

        return cohort;
      },

      /**
       * Updates cohort metadata
       */
      updateCohort: async (cohortId: string, updates: Partial<EventCohort>) => {
        set((state) => ({
          cohorts: state.cohorts.map((c) => {
            if (c.id !== cohortId) return c;
            const updated = { ...c, ...updates, updatedAt: new Date().toISOString() };
            if (
              updates.category &&
              ['trip', 'house', 'event', 'dining', 'transport', 'utilities'].includes(updates.category)
            ) {
              delete updated.customIcon;
            }
            return updated;
          }),
        }));

        try {
          await groupService.updateCohort(cohortId, updates);
        } catch (err) {
          console.warn(`[Store] updateCohort backend failed for ${cohortId}:`, err);
        }
      },

      /**
       * Joins a cohort by invite code
       */
      joinCohortByInviteCode: async (inviteCode: string) => {
        const currentUser = get().currentUser;
        try {
          const result = await groupService.joinCohortByInviteCode(inviteCode, currentUser);
          if (result) {
            const { cohort, member } = result;
            set((state) => {
              const existingList = state.members[cohort.id] || [];
              const memberExists = existingList.some((m) => m.userId === currentUser.id);

              return {
                cohorts: state.cohorts.some((c) => c.id === cohort.id)
                  ? state.cohorts
                  : [cohort, ...state.cohorts],
                activeCohortId: cohort.id,
                members: {
                  ...state.members,
                  [cohort.id]: memberExists ? existingList : [...existingList, member],
                },
                expenses: {
                  ...state.expenses,
                  [cohort.id]: state.expenses[cohort.id] || [],
                },
              };
            });
            return cohort;
          }
        } catch (err) {
          console.warn(`[Store] joinCohortByInviteCode error for ${inviteCode}:`, err);
        }
        return null;
      },

      /**
       * Adds an expense with optimistic local update + backend persistence
       */
      addExpense: async (expense: Expense) => {
        set((state) => {
          const cohortExpenses = state.expenses[expense.cohortId] || [];
          return {
            expenses: {
              ...state.expenses,
              [expense.cohortId]: [expense, ...cohortExpenses],
            },
          };
        });

        try {
          const savedExp = await expenseService.createExpense(expense);
          if (savedExp.id !== expense.id) {
            set((state) => {
              const list = state.expenses[expense.cohortId] || [];
              return {
                expenses: {
                  ...state.expenses,
                  [expense.cohortId]: list.map((e) => (e.id === expense.id ? savedExp : e)),
                },
              };
            });
          }
        } catch (err) {
          console.warn('[Store] addExpense backend persistence failed:', err);
        }
      },

      /**
       * Updates an existing expense
       */
      updateExpense: async (expense: Expense) => {
        set((state) => {
          const cohortExpenses = state.expenses[expense.cohortId] || [];
          return {
            expenses: {
              ...state.expenses,
              [expense.cohortId]: cohortExpenses.map((e) => (e.id === expense.id ? expense : e)),
            },
          };
        });

        try {
          await expenseService.updateExpense(expense);
        } catch (err) {
          console.warn(`[Store] updateExpense backend failed for ${expense.id}:`, err);
        }
      },

      /**
       * Deletes an expense
       */
      deleteExpense: async (expenseId: string, cohortId: string) => {
        set((state) => ({
          expenses: {
            ...state.expenses,
            [cohortId]: (state.expenses[cohortId] || []).filter((e) => e.id !== expenseId),
          },
        }));

        try {
          await expenseService.deleteExpense(expenseId);
        } catch (err) {
          console.warn(`[Store] deleteExpense backend failed for ${expenseId}:`, err);
        }
      },

      /**
       * Adds a comment to an expense
       */
      addComment: async (comment: TransactionComment) => {
        set((state) => {
          const list = state.comments[comment.expenseId] || [];
          return {
            comments: {
              ...state.comments,
              [comment.expenseId]: [...list, comment],
            },
          };
        });

        try {
          const savedComment = await expenseService.addComment(comment);
          if (savedComment.id !== comment.id) {
            set((state) => {
              const list = state.comments[comment.expenseId] || [];
              return {
                comments: {
                  ...state.comments,
                  [comment.expenseId]: list.map((c) => (c.id === comment.id ? savedComment : c)),
                },
              };
            });
          }
        } catch (err) {
          console.warn('[Store] addComment backend failed:', err);
        }
      },

      // Shared Needs List Actions
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
    }),
    {
      name: 'fairshare-store-v1',
      storage: createJSONStorage(() => zustandMMKVStorage),
      partialize: (state) => ({
        currentUser: state.currentUser,
        cohorts: state.cohorts,
        activeCohortId: state.activeCohortId,
        members: state.members,
        expenses: state.expenses,
        comments: state.comments,
        sharedLists: state.sharedLists,
        reminderSettings: state.reminderSettings,
        offlineQueue: state.offlineQueue,
      }),
    }
  )
);
