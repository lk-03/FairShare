# FairShare - Comprehensive Project & Codebase Documentation

**FairShare** is a modern cross-platform mobile expense-splitting application built with React Native, Expo v57, and Supabase.

## 1. Project Goals & Vision

### Core Goals:
1. **Seamless Group Bill Splitting** across trips, households, events, dining
2. **Algorithmic Debt Simplification** using greedy minimization 
3. **Instant UPI Settlement** with deep GPay/PhonePe/Paytm integration
4. **Smart Receipt OCR** via Supabase Edge Functions
5. **Dynamic Theme Engine** with 4 themes (Nordic, Sage, Taupe, Cobalt) × light/dark
6. **Shared Needs Lists** for household planning
7. **Offline-First** with MMKV persistence

## 2. Tech Stack

- **Framework:** Expo 57, React Native 0.86, React 19
- **Routing:** expo-router (file-based)
- **Styling:** NativeWind v4, Tailwind CSS v3
- **State:** Zustand + MMKV persistence
- **Backend:** Supabase (PostgreSQL + RLS + Edge Functions)
- **Testing:** Jest, ts-jest

## 3. Design System

4 theme palettes managed via `src/store/useThemeStore.ts`:
1. **Nordic Steel** - slate blue Scandinavian
2. **Muted Sage** - eucalyptus green organic
3. **Warm Taupe** - sand/mocha earth tones
4. **Electric Cobalt** - vibrant fintech blue

Each supports light/dark via CSS variables in `src/global.css`.

## 4. Business Logic

### Debt Simplification (`src/utils/debtSimplifier.ts`)
Greedy algorithm:
1. Calculate net balances (paid - owed)
2. Sort debtors and creditors by amount
3. Match largest pairs to minimize transaction count

### Split Types
- `equal`: Divide equally
- `exact`: Custom amounts
- `percentage`: Proportional shares
- `itemized`: Per line-item assignment

### UPI Integration (`src/services/payment/upiIntent.ts`)
Generates `upi://pay` deep links for instant settlement via Indian payment apps.

## 5. File Reference

### Root Config
- `app.json` - Expo manifest
- `package.json` - Dependencies & scripts
- `tailwind.config.js` - Tailwind theme config
- `tsconfig.json` - TypeScript with `@/*` alias
- `babel.config.js`, `metro.config.js` - Build tooling
- `jest.config.js` - Test configuration

### Backend (`supabase/`)
- `schema.sql` - 7 tables: profiles, event_cohorts, group_members, expenses, expense_line_items, expense_splits, transaction_comments (all with RLS)
- `functions/ocr-parser/index.ts` - Deno Edge Function for receipt OCR

### Source (`src/`)

**Types & Styles:**
- `global.css` - Tailwind + theme CSS variables
- `types/index.ts` - Full TypeScript definitions (UserProfile, EventCohort, Expense, etc.)
- `constants/theme.ts` - Colors, Fonts, Spacing, layout constants

**Hooks:**
- `hooks/use-color-scheme.ts` (.web.ts) - System theme detection
- `hooks/use-theme.ts` - Theme utilities

**Services:**
- `services/storage/mmkv.ts` - Fast persistence with Zustand adapter
- `services/supabase/client.ts` - Supabase initialization
- `services/payment/upiIntent.ts` - UPI deep link generation (+ tests)

**State:**
- `store/useExpenseStore.ts` - Central store: users, cohorts, members, expenses, comments, lists, reminders (with seed data: "Goa Trip" & "Apartment 402")
- `store/useThemeStore.ts` - Theme & color scheme management

**Utils:**
- `utils/debtSimplifier.ts` - Debt minimization algorithm (+ tests)
- `utils/imageCompressor.ts` - Receipt photo optimization

### Screens (`src/app/`)
- `_layout.tsx` - Root: SafeArea, theme classes, StatusBar, splash, Stack navigator
- `(tabs)/_layout.tsx` - Bottom tab bar config
- `(tabs)/index.tsx` - **Home Dashboard**: hero balance, gradient header, action buttons, group cards, recent feed
- `(tabs)/groups.tsx` - **Groups list**
- `(tabs)/activity.tsx` - **Transaction history**
- `(tabs)/profile.tsx` - **Profile & settings**
- `event/[id].tsx` - **Group detail**: expenses, settlements (UPI buttons), analytics, needs list
- `scan.tsx` - **Camera modal** for receipts/QR
- `explore.tsx` - Feature showcase

### Components (`src/components/`)

**Modals:**
- `AddExpenseModal.tsx` - Create expense with split config
- `EditExpenseModal.tsx` - Edit/delete expense
- `ExpenseDetailsModal.tsx` - Full breakdown + comments
- `CreateGroupModal.tsx` - New group form
- `EditGroupModal.tsx` - Group settings
- `SelectGroupModal.tsx` - Quick group picker
- `ThemeSettingsModal.tsx` - Theme customization
- `QRCodeModal.tsx` - UPI QR display
- `TransactionComments.tsx` - Comment thread
- `NeedsListTab.tsx` - Shopping list
- `MonthlySpendingsTab.tsx` - Analytics

**UI Primitives (`ui/`):**
- `Text.tsx`, `Button.tsx` - Themed base components
- `CategoryIcon.tsx` - Icon mapping (trip→plane, house→home, etc.)
- `ThemeGradientHeader.tsx` - Gradient hero section
- `collapsible.tsx` - Accordion panel

**Other:**
- `BottomNav.tsx`, `title-bar.tsx`, `themed-text/view.tsx`
- `animated-icon.tsx` (.web.tsx, .module.css) - Splash animation
- `app-tabs.tsx` (.web.tsx) - Platform tab bars
- `external-link.tsx`, `hint-row.tsx`, `web-badge.tsx`

### Assets (`assets/`)
- `images/` - Icons (launcher, splash, favicon, Android adaptive), logos, tab icons (@2x/@3x), tutorial graphics
- `expo.icon/` - iOS SF Symbols metadata
- `Untitled/` - Design mockups (4 screens + zip)

## 6. Architecture

```
React Native App (Expo Router + NativeWind)
    ↓
Zustand Stores ←→ MMKV Storage (local persistence)
    ↓
Supabase Backend
    ├─ PostgreSQL (RLS policies)
    └─ Edge Functions (OCR)
```

**Flow:**
1. User action → Zustand store → MMKV persistence
2. Calculate debts via `calculateSimplifiedDebts()`
3. Settlement → UPI deep link → native payment app
4. Background sync to Supabase with RLS isolation

---
*Maintained by Kowsic L*