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
  id: 'usr_me',
  fullName: 'Kowsic L',
  nickname: 'Kowsic',
  username: 'kowsic_03',
  avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Dev&backgroundColor=ffd5dc',
  email: 'kowsic@fairshare.app',
  vpaId: 'kowsic@okaxis',
  isGuest: false,
  createdAt: new Date().toISOString(),
};

export const DEFAULT_COHORTS: EventCohort[] = [
  {
    id: 'cohort_goa',
    name: 'Goa Summer Trip',
    description: 'Beach villa, car rental, and dinner expenses',
    category: 'trip',
    currency: 'INR',
    createdBy: 'usr_me',
    inviteCode: 'GOA2026',
    createdAt: new Date(Date.now() - 86400000 * 7).toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cohort_apt',
    name: 'Apartment 402',
    description: 'Monthly rent, wifi, and grocery bills',
    category: 'house',
    currency: 'INR',
    createdBy: 'usr_alex',
    inviteCode: 'APT402',
    createdAt: new Date(Date.now() - 86400000 * 30).toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

export const DEFAULT_MEMBERS: Record<string, GroupMember[]> = {
  cohort_goa: [
    {
      id: 'm1',
      cohortId: 'cohort_goa',
      userId: 'usr_me',
      role: 'admin',
      joinedAt: new Date(Date.now() - 86400000 * 7).toISOString(),
      profile: DEFAULT_CURRENT_USER,
    },
    {
      id: 'm2',
      cohortId: 'cohort_goa',
      userId: 'usr_alex',
      role: 'member',
      joinedAt: new Date(Date.now() - 86400000 * 7).toISOString(),
      profile: {
        id: 'usr_alex',
        fullName: 'Alex Rivera',
        nickname: 'Alex',
        username: 'alex_r',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Marcus&backgroundColor=c0aede',
        email: 'alex@fairshare.app',
        vpaId: 'alex@upi',
        isGuest: false,
        createdAt: new Date(Date.now() - 86400000 * 30).toISOString(),
      },
    },
    {
      id: 'm3',
      cohortId: 'cohort_goa',
      userId: 'usr_priya',
      role: 'member',
      joinedAt: new Date(Date.now() - 86400000 * 7).toISOString(),
      profile: {
        id: 'usr_priya',
        fullName: 'Priya Sharma',
        nickname: 'Priya',
        username: 'priya_s',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Elena&backgroundColor=d1d4f9',
        email: 'priya@fairshare.app',
        vpaId: 'priya@ybl',
        isGuest: false,
        createdAt: new Date(Date.now() - 86400000 * 30).toISOString(),
      },
    },
  ],
  cohort_apt: [
    {
      id: 'm1',
      cohortId: 'cohort_apt',
      userId: 'usr_me',
      role: 'member',
      joinedAt: new Date(Date.now() - 86400000 * 30).toISOString(),
      profile: DEFAULT_CURRENT_USER,
    },
    {
      id: 'm2',
      cohortId: 'cohort_apt',
      userId: 'usr_alex',
      role: 'admin',
      joinedAt: new Date(Date.now() - 86400000 * 30).toISOString(),
      profile: {
        id: 'usr_alex',
        fullName: 'Alex Rivera',
        nickname: 'Alex',
        username: 'alex_r',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Marcus&backgroundColor=c0aede',
        email: 'alex@fairshare.app',
        vpaId: 'alex@upi',
        isGuest: false,
        createdAt: new Date(Date.now() - 86400000 * 30).toISOString(),
      },
    },
  ],
};

export const DEFAULT_EXPENSES: Record<string, Expense[]> = {
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
      title: 'Seafood Dinner & Drinks',
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

export const DEFAULT_SHARED_LISTS: Record<string, SharedListItem[]> = {
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
};

export const DEFAULT_REMINDER_SETTINGS: Record<string, PersonalReminderSettings> = {
  cohort_goa: {
    enabled: true,
    frequencyUnit: 'hours',
    frequencyHours: 6,
    frequencyDays: 1,
    reminderTime: '18:00',
    notifyStaleItems: true,
  },
};

export const DEFAULT_SHORTCUTS: Record<string, ExpenseShortcut[]> = {};
