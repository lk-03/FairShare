export type SplitType = 'equal' | 'exact' | 'percentage' | 'shares' | 'adjustment' | 'itemized';

export type EventCategory = 'trip' | 'house' | 'event' | 'dining' | 'transport' | 'utilities' | 'custom';

export interface UserProfile {
  id: string;
  email?: string;
  fullName: string;
  nickname?: string;
  username?: string; // e.g. 'rahul_k' (rendered as @rahul_k)
  avatarUrl?: string;
  vpaId?: string; // UPI ID (e.g. name@okaxis)
  phoneNumber?: string;
  isGuest: boolean;
  authProvider?: 'google' | 'email' | 'guest';
  createdAt: string;
}

export interface EventCohort {
  id: string;
  name: string;
  description?: string;
  category: EventCategory;
  customIcon?: string;
  bannerUrl?: string;
  avatarUrl?: string;
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
  isPlaceholder?: boolean; // True if created as shadow member from CSV import or manual placeholder
  originalCsvName?: string; // Original name in Splitwise CSV if imported
}

export type ItemSplitType = 'equal' | 'exact' | 'shares' | 'percentage' | 'quantity';

export interface LineItemAssignment {
  userId: string;
  splitType?: ItemSplitType; // Default 'equal'
  value?: number; // Exact amount, share weight, percentage, or quantity
  calculatedAmount: number;
}

export interface LineItem {
  id: string;
  title: string;
  price: number;
  quantity: number;
  splitType?: ItemSplitType; // Default 'equal'
  assignments?: LineItemAssignment[];
  assignedUserIds: string[]; // For fast multi-member lookups and backward compatibility
}

export interface ParsedReceiptData {
  merchantName?: string;
  date?: string;
  currency?: string;
  lineItems: Array<{
    title: string;
    quantity: number;
    price: number;
  }>;
  subtotal: number;
  taxAmount: number;
  serviceCharge: number;
  discountAmount: number;
  totalAmount: number;
  rawText?: string;
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
  subtotal?: number;
  taxAmount?: number;
  serviceCharge?: number;
  discountAmount?: number;
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

export interface ExpenseShortcut {
  id: string;
  cohortId: string;
  title: string;
  category: string;
  customIcon?: string;
  amount: number;
  paidByUserId?: string;
  isMultiplePayers?: boolean;
  paidAmounts?: Record<string, string>;
  splitType: SplitType;
  splits?: ExpenseSplit[];
  includedMemberIds?: string[];
  exactSplits?: Record<string, string>;
  percentageSplits?: Record<string, string>;
  sharesSplits?: Record<string, number>;
  adjustmentSplits?: Record<string, string>;
  createdAt: string;
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

export type ReminderFrequencyUnit = 'hours' | 'days';

export interface PersonalReminderSettings {
  enabled: boolean;
  frequencyUnit?: ReminderFrequencyUnit; // 'hours' | 'days' (default: 'hours')
  frequencyHours?: number; // 2, 4, 6, 8, 12, 24 (default: 6)
  frequencyDays?: number; // 1, 2, 3, 5, 7 (default: 1)
  reminderTime?: string; // '09:00', '13:00', '18:00', '21:00'
  notifyStaleItems?: boolean; // notify everyone when an item is unchecked for 3+ days
}

