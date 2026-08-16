export type SplitType = 'equal' | 'exact' | 'percentage' | 'shares';

export type EventCategory = 'trip' | 'house' | 'event' | 'dining' | 'transport' | 'utilities' | 'custom';

export interface UserProfile {
  id: string;
  email?: string;
  fullName: string;
  avatarUrl?: string;
  vpaId?: string; // UPI ID (e.g. name@okaxis)
  phoneNumber?: string;
  isGuest: boolean;
  createdAt: string;
}

export interface EventCohort {
  id: string;
  name: string;
  description?: string;
  category: EventCategory;
  customIcon?: string;
  bannerUrl?: string;
  currency: string; // e.g. 'INR', 'USD'
  createdBy: string; // UserProfile id
  inviteCode: string;
  createdAt: string;
  updatedAt: string;
}

export interface GroupMember {
  id: string;
  cohortId: string;
  userId: string;
  role: 'admin' | 'member';
  joinedAt: string;
  profile?: UserProfile;
}

export interface LineItem {
  id: string;
  title: string;
  price: number;
  quantity: number;
  assignedUserIds: string[]; // User IDs sharing this line item
}

export interface ExpenseSplit {
  userId: string;
  amount: number;
  percentage?: number;
  lineItemIds?: string[];
}

export interface Expense {
  id: string;
  cohortId: string;
  title: string;
  category: string;
  customIcon?: string;
  totalAmount: number;
  currency: string;
  paidByUserId: string;
  splitType: SplitType;
  splits: ExpenseSplit[];
  lineItems?: LineItem[];
  receiptUrl?: string;
  ocrParsed?: boolean;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface TransactionComment {
  id: string;
  expenseId: string;
  userId: string;
  content: string;
  createdAt: string;
  profile?: UserProfile;
}

export interface NetBalance {
  userId: string;
  userProfile?: UserProfile;
  amount: number; // positive = owed money, negative = owes money
}

export interface DirectDebt {
  fromUserId: string;
  fromProfile?: UserProfile;
  toUserId: string;
  toProfile?: UserProfile;
  amount: number;
  currency: string;
}

export interface DebtSimplificationResult {
  cohortId: string;
  netBalances: Record<string, number>;
  simplifiedDebts: DirectDebt[];
}

export interface UPIPaymentConfig {
  vpaId: string;
  payeeName: string;
  amount: number;
  currency?: string;
  note?: string;
  transactionRef?: string;
}

export interface SharedListItem {
  id: string;
  cohortId: string;
  title: string;
  addedByUserId: string;
  isCompleted: boolean;
  completedAt?: string;
  createdAt: string;
}

export interface PersonalReminderSettings {
  enabled: boolean;
  frequencyDays: number;
  reminderTime: string;
}
