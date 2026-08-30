import {
  UserProfile,
  EventCohort,
  GroupMember,
  Expense,
  ExpenseShortcut,
  SharedListItem,
  PersonalReminderSettings,
} from '@/types';

export const DEFAULT_CURRENT_USER: UserProfile = {
  id: '',
  fullName: '',
  email: '',
  isGuest: false,
  createdAt: new Date().toISOString(),
};

export const DEFAULT_COHORTS: EventCohort[] = [];
export const DEFAULT_MEMBERS: Record<string, GroupMember[]> = {};
export const DEFAULT_EXPENSES: Record<string, Expense[]> = {};
export const DEFAULT_SHORTCUTS: Record<string, ExpenseShortcut[]> = {};
export const DEFAULT_SHARED_LISTS: Record<string, SharedListItem[]> = {};
export const DEFAULT_REMINDER_SETTINGS: Record<string, PersonalReminderSettings> = {};
