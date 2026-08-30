import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { zustandMMKVStorage } from '@/services/storage/mmkv';
import {
  UserProfile,
  EventCohort,
  GroupMember,
  Expense,
  ExpenseShortcut,
  TransactionComment,
  SharedListItem,
  PersonalReminderSettings,
} from '@/types';
import {
  DEFAULT_CURRENT_USER,
  DEFAULT_COHORTS,
  DEFAULT_MEMBERS,
  DEFAULT_EXPENSES,
  DEFAULT_SHORTCUTS,
  DEFAULT_SHARED_LISTS,
  DEFAULT_REMINDER_SETTINGS,
} from '@/services/supabase/placeholderData';
import * as profileService from '@/services/supabase/profileService';
import * as groupService from '@/services/supabase/groupService';
import * as expenseService from '@/services/supabase/expenseService';
import * as needsService from '@/services/supabase/needsService';
import * as shortcutService from '@/services/supabase/shortcutService';

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
  shortcuts: Record<string, ExpenseShortcut[]>; // cohortId -> ExpenseShortcut[]
  sharedLists: Record<string, SharedListItem[]>; // cohortId -> SharedListItem[]
  reminderSettings: Record<string, PersonalReminderSettings>; // cohortId -> PersonalReminderSettings

  // Async & Sync Status
  isLoading: boolean;
  isSyncing: boolean;
  error: string | null;

  // Local Offline Queue
  offlineQueue: any[];

  // Onboarding & Auth State
  hasCompletedOnboarding: boolean;
  hasSeenAppTour: boolean;
  setHasCompletedOnboarding: (completed: boolean) => void;
  setHasSeenAppTour: (seen: boolean) => void;
  setGuestMode: (isGuest: boolean) => void;
  linkAccount: (authData: { email: string; fullName: string; avatarUrl?: string; provider: 'google' | 'email' }) => void;
  importSplitwiseGroup: (cohort: EventCohort, members: GroupMember[], expenses: Expense[]) => void;
  importCsvIntoCohort: (cohortId: string, newShadowMembers: GroupMember[], newExpenses: Expense[]) => void;
  reassignShadowMember: (cohortId: string, shadowUserId: string, targetUserId: string) => void;

  // Async Fetchers & Data Synchronization
  fetchInitialData: () => Promise<void>;
  fetchCohorts: () => Promise<void>;
  fetchExpensesForCohort: (cohortId: string) => Promise<void>;
  refreshAll: () => Promise<void>;
  clearError: () => void;

  // User Actions
  setCurrentUser: (user: UserProfile) => void;
  updateCurrentUserVpa: (vpaId: string) => Promise<void>;
  updateUserProfile: (updates: Partial<UserProfile>) => Promise<void>;
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

  // Expense Shortcut Actions
  addShortcut: (shortcut: ExpenseShortcut) => void;
  updateShortcut: (shortcutId: string, cohortId: string, updates: Partial<ExpenseShortcut>) => void;
  deleteShortcut: (shortcutId: string, cohortId: string) => void;

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
      activeCohortId: null,
      members: DEFAULT_MEMBERS,
      expenses: DEFAULT_EXPENSES,
      comments: {},
      shortcuts: DEFAULT_SHORTCUTS,
      sharedLists: DEFAULT_SHARED_LISTS,
      reminderSettings: DEFAULT_REMINDER_SETTINGS,
      offlineQueue: [],

      hasCompletedOnboarding: false,
      hasSeenAppTour: false,
      isLoading: false,
      isSyncing: false,
      error: null,

      setHasCompletedOnboarding: (completed: boolean) =>
        set({ hasCompletedOnboarding: completed }),

      setHasSeenAppTour: (seen: boolean) =>
        set({ hasSeenAppTour: seen }),

      setGuestMode: (isGuest: boolean) =>
        set((state) => ({
          currentUser: {
            ...state.currentUser,
            isGuest,
            authProvider: isGuest ? 'guest' : state.currentUser.authProvider || 'google',
          },
        })),

      linkAccount: ({ email, fullName, avatarUrl, provider }) =>
        set((state) => {
          const updatedUser: UserProfile = {
            ...state.currentUser,
            email,
            fullName,
            avatarUrl: avatarUrl || state.currentUser.avatarUrl,
            isGuest: false,
            authProvider: provider,
          };

          const updatedMembers: Record<string, GroupMember[]> = {};
          Object.keys(state.members).forEach((cohortId) => {
            updatedMembers[cohortId] = (state.members[cohortId] || []).map((m) => {
              if (m.userId === state.currentUser.id) {
                return {
                  ...m,
                  profile: {
                    ...(m.profile || updatedUser),
                    email,
                    fullName,
                    avatarUrl: avatarUrl || m.profile?.avatarUrl,
                    isGuest: false,
                    authProvider: provider,
                  },
                };
              }
              return m;
            });
          });

          return {
            currentUser: updatedUser,
            members: updatedMembers,
          };
        }),

      importSplitwiseGroup: (cohort, cohortMembers, cohortExpenses) =>
        set((state) => ({
          cohorts: [cohort, ...state.cohorts.filter((c) => c.id !== cohort.id)],
          activeCohortId: cohort.id,
          members: {
            ...state.members,
            [cohort.id]: cohortMembers,
          },
          expenses: {
            ...state.expenses,
            [cohort.id]: cohortExpenses,
          },
        })),

      importCsvIntoCohort: (cohortId, newShadowMembers, newExpenses) =>
        set((state) => {
          const existingM = state.members[cohortId] || [];
          const existingE = state.expenses[cohortId] || [];

          const existingUserIds = new Set(existingM.map((m) => m.userId));
          const mergedMembers = [
            ...existingM,
            ...newShadowMembers.filter((sm) => !existingUserIds.has(sm.userId)),
          ];

          return {
            members: {
              ...state.members,
              [cohortId]: mergedMembers,
            },
            expenses: {
              ...state.expenses,
              [cohortId]: [...newExpenses, ...existingE],
            },
          };
        }),

      reassignShadowMember: (cohortId, shadowUserId, targetUserId) =>
        set((state) => {
          const existingM = state.members[cohortId] || [];
          const existingE = state.expenses[cohortId] || [];

          // 1. Update expenses: replace shadowUserId with targetUserId in paidByUserId and splits
          const updatedExpenses = existingE.map((exp) => {
            let isChanged = false;
            let newPaidBy = exp.paidByUserId;
            if (exp.paidByUserId === shadowUserId) {
              newPaidBy = targetUserId;
              isChanged = true;
            }

            const newSplits = exp.splits.map((sp) => {
              if (sp.userId === shadowUserId) {
                isChanged = true;
                return { ...sp, userId: targetUserId };
              }
              return sp;
            });

            if (isChanged) {
              return {
                ...exp,
                paidByUserId: newPaidBy,
                splits: newSplits,
              };
            }
            return exp;
          });

          // 2. Remove shadow member from roster (since they are now represented by targetUserId)
          const updatedMembers = existingM.filter((m) => m.userId !== shadowUserId);

          return {
            members: {
              ...state.members,
              [cohortId]: updatedMembers,
            },
            expenses: {
              ...state.expenses,
              [cohortId]: updatedExpenses,
            },
          };
        }),

      clearError: () => set({ error: null }),

      setCurrentUser: (user) => set({ currentUser: user }),

      updateCurrentUserVpa: async (vpaId: string) => {
        const currentUser = get().currentUser;
        const updatedUser: UserProfile = { ...currentUser, vpaId };

        // 1. Optimistic local state update
        set((state) => {
          const updatedMembers: Record<string, GroupMember[]> = {};
          Object.keys(state.members).forEach((cohortId) => {
            updatedMembers[cohortId] = (state.members[cohortId] || []).map((m) => {
              if (m.userId === currentUser.id) {
                return {
                  ...m,
                  profile: m.profile
                    ? { ...m.profile, vpaId }
                    : updatedUser,
                };
              }
              return m;
            });
          });

          return {
            currentUser: updatedUser,
            members: updatedMembers,
          };
        });

        // 2. Persist to backend
        try {
          await profileService.updateProfile(currentUser.id, { vpaId });
        } catch (err) {
          console.warn('[Store] updateCurrentUserVpa backend sync failed:', err);
        }
      },

      updateUserProfile: async (updates: Partial<UserProfile>) => {
        const currentUser = get().currentUser;
        const updatedUser: UserProfile = { ...currentUser, ...updates };

        // 1. Optimistic local state update
        set((state) => {
          const updatedMembers: Record<string, GroupMember[]> = {};
          Object.keys(state.members).forEach((cohortId) => {
            updatedMembers[cohortId] = (state.members[cohortId] || []).map((m) => {
              if (m.userId === currentUser.id) {
                return {
                  ...m,
                  profile: m.profile
                    ? { ...m.profile, ...updates }
                    : updatedUser,
                };
              }
              return m;
            });
          });

          return {
            currentUser: updatedUser,
            members: updatedMembers,
          };
        });

        // 2. Persist to backend
        try {
          await profileService.updateProfile(currentUser.id, updates);
        } catch (err) {
          console.warn('[Store] updateUserProfile backend sync failed:', err);
        }
      },

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

          // 3. Fetch expenses, shortcuts & house needs for all cohorts in parallel
          const expensesMap: Record<string, Expense[]> = {};
          const shortcutsMap: Record<string, ExpenseShortcut[]> = {};
          const sharedListsMap: Record<string, SharedListItem[]> = {};

          await Promise.all(
            cohorts.map(async (c) => {
              const [exps, scs, needs] = await Promise.all([
                expenseService.fetchExpensesForCohort(c.id),
                shortcutService.fetchShortcuts(c.id),
                needsService.fetchSharedListItems(c.id),
              ]);
              expensesMap[c.id] = exps;
              shortcutsMap[c.id] = scs;
              sharedListsMap[c.id] = needs;
            })
          );

          set({
            currentUser: user,
            cohorts,
            members,
            expenses: expensesMap,
            shortcuts: shortcutsMap,
            sharedLists: sharedListsMap,
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
          const shortcutsMap: Record<string, ExpenseShortcut[]> = {};
          const sharedListsMap: Record<string, SharedListItem[]> = {};

          await Promise.all(
            cohorts.map(async (c) => {
              const [exps, scs, needs] = await Promise.all([
                expenseService.fetchExpensesForCohort(c.id),
                shortcutService.fetchShortcuts(c.id),
                needsService.fetchSharedListItems(c.id),
              ]);
              expensesMap[c.id] = exps;
              shortcutsMap[c.id] = scs;
              sharedListsMap[c.id] = needs;
            })
          );

          set({
            cohorts,
            members,
            expenses: expensesMap,
            shortcuts: shortcutsMap,
            sharedLists: sharedListsMap,
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

      // Expense Shortcut Actions
      addShortcut: async (shortcut) => {
        set((state) => {
          const list = state.shortcuts[shortcut.cohortId] || [];
          return {
            shortcuts: {
              ...state.shortcuts,
              [shortcut.cohortId]: [shortcut, ...list.filter((s) => s.id !== shortcut.id)],
            },
          };
        });
        try {
          const saved = await shortcutService.createShortcut(shortcut);
          if (saved && saved.id !== shortcut.id) {
            set((state) => {
              const list = state.shortcuts[shortcut.cohortId] || [];
              return {
                shortcuts: {
                  ...state.shortcuts,
                  [shortcut.cohortId]: list.map((sc) => (sc.id === shortcut.id ? saved : sc)),
                },
              };
            });
          }
        } catch (err) {
          console.warn('[Store] createShortcut backend error:', err);
        }
      },

      updateShortcut: (shortcutId, cohortId, updates) =>
        set((state) => {
          const list = state.shortcuts[cohortId] || [];
          return {
            shortcuts: {
              ...state.shortcuts,
              [cohortId]: list.map((sc) => (sc.id === shortcutId ? { ...sc, ...updates } : sc)),
            },
          };
        }),

      deleteShortcut: (shortcutId, cohortId) => {
        set((state) => {
          const list = state.shortcuts[cohortId] || [];
          return {
            shortcuts: {
              ...state.shortcuts,
              [cohortId]: list.filter((sc) => sc.id !== shortcutId),
            },
          };
        });
        shortcutService.deleteShortcut(shortcutId).catch((err) => {
          console.warn('[Store] deleteShortcut backend error:', err);
        });
      },

      // Shared Needs List Actions
      addListItem: (item) => {
        set((state) => {
          const list = state.sharedLists[item.cohortId] || [];
          return {
            sharedLists: {
              ...state.sharedLists,
              [item.cohortId]: [item, ...list],
            },
          };
        });
        needsService.createSharedListItem(item).catch((err) => {
          console.warn('[Store] createSharedListItem backend error:', err);
        });
      },

      toggleListItem: (itemId, cohortId) => {
        let isCompleted = false;
        set((state) => {
          const list = state.sharedLists[cohortId] || [];
          const updated = list.map((it) => {
            if (it.id === itemId) {
              const nextVal = !it.isCompleted;
              isCompleted = nextVal;
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
        });
        needsService.toggleSharedListItem(itemId, isCompleted).catch((err) => {
          console.warn('[Store] toggleSharedListItem backend error:', err);
        });
      },

      deleteListItem: (itemId, cohortId) => {
        set((state) => {
          const list = state.sharedLists[cohortId] || [];
          return {
            sharedLists: {
              ...state.sharedLists,
              [cohortId]: list.filter((it) => it.id !== itemId),
            },
          };
        });
        needsService.deleteSharedListItem(itemId).catch((err) => {
          console.warn('[Store] deleteSharedListItem backend error:', err);
        });
      },

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
        shortcuts: state.shortcuts,
        sharedLists: state.sharedLists,
        reminderSettings: state.reminderSettings,
        hasCompletedOnboarding: state.hasCompletedOnboarding,
        offlineQueue: state.offlineQueue,
      }),
    }
  )
);
