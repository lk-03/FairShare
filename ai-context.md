# FairShare — AI Context & Codebase Architecture Guide

> **CRITICAL RULE FOR ALL AI ASSISTANTS:**
> Whenever you add, modify, rename, or delete any files, or make architectural/state changes to this project, you **MUST** update this file (`ai-context.md`) to keep the documentation synchronized and accurate.

---

## 1. Executive Summary & Project Goals

**FairShare** is a neo-fintech mobile application built with **React Native (Expo)**, **TypeScript**, **NativeWind v4**, **Zustand (MMKV)**, and **Supabase**. It is designed to modernize group expense tracking, bill splitting, and peer-to-peer settlement.

### Core Goals & Features
1. **Smart Debt Simplification**: Employs a Greedy Min-Flow Graph algorithm to resolve cyclic multi-person IOUs and reduce $N$-person group debts down to the mathematical minimum number of direct transactions.
2. **Zero-Fee Direct UPI P2P Settlements**: Generates standard OS-level `upi://pay` deep link intents to trigger instant payments via Google Pay, PhonePe, Paytm, BHIM, or CRED directly between bank VPAs without payment gateway fees.
3. **Household & Event Collaboration ("Needs List / Cart of the House")**: Shared checklist for roommates and trip cohorts with automatic 5-day item expiration and personal reminder schedules for quick-commerce shopping runs (Blinkit, Instamart, Zepto, BigBasket).
4. **Visual Spending Trends ("Monthly Spendings")**: Dynamic dual-bar visualization comparing total group expenditure against the individual user's personal share across billing cycles.
5. **Flexible Split Allocation Engine**: Supports four granular split modes: Equal splits, Exact rupee amounts (with real-time remaining auto-fill), Percentages (with 100% remaining auto-fill), and Custom share weightings/ratios.
6. **Receipt Compression & OCR Invoice Extraction**: Automated receipt photo compression via `expo-image-manipulator` and a Supabase Edge Function integrating Google Cloud Vision OCR for invoice breakdown.
7. **Offline-First Persistence**: High-speed local caching using **MMKV** with an in-memory fallback for Expo Go and Web environments.
8. **QR-Based Cohort Onboarding**: Camera QR code scanning and direct deep linking (`fairshare://join/<inviteCode>`) for zero-friction group joining.

---

## 2. Visual Theme & Aesthetic System

FairShare incorporates a **Revolut-inspired neo-fintech aesthetic**, featuring multi-stop curved SVG gradient headers, frosted accent pills, rounded elevated surface cards, and a dual-dimension theme engine:

### Theme Matrix (4 Palettes $\times$ 2 Modes $\times$ System Preference)
- **Nordic Steel** *(Default)*: Clean Scandinavian steel blue and midnight slate.
- **Muted Sage**: Organic eucalyptus and deep pine forest tones.
- **Warm Taupe**: Cozy sand and mocha clay.
- **Electric Cobalt**: Vibrant royal blue fintech theme.
- **Modes**: `Light`, `Dark`, and automatic `System` scheme detection.

All themes are configured through CSS custom variables declared in `src/global.css` and exposed through `tailwind.config.js`.

---

## 3. Detailed Description of Every File in the Project

```
FairShare/
├── Configuration & Setup
├── supabase/ (Database & Edge Functions)
├── scripts/ (Automation & Setup)
└── src/
    ├── types/ (TypeScript Domain Models)
    ├── constants/ (Styling & Design Tokens)
    ├── store/ (Zustand State Stores & Persistence)
    ├── services/ (Supabase, Storage, UPI Intents)
    ├── utils/ (Debt Simplifier, Image Compression)
    ├── hooks/ (Theme & Color Scheme Hooks)
    ├── components/
    │   ├── ui/ (Atomic Design Primitives & EmptyState)
    │   └── [Modals & Feature Tabs]
    └── app/ (Expo Router File-Based Routing)
```

---

### Root Configuration & Documentation Files

#### `package.json`
- **Role:** Defines project metadata, build scripts (`start`, `android`, `ios`, `web`, `lint`, `test`), npm dependencies, and dev tooling.
- **Key Dependencies:**
  - `expo` (~57.0.10) & `expo-router` (~57.0.10)
  - `nativewind` (^4.2.6) & `tailwindcss` (^3.4.19)
  - `zustand` (^5.0.3) & `react-native-mmkv` (^3.2.0)
  - `@supabase/supabase-js` (^2.48.1)
  - `expo-camera`, `expo-image`, `expo-image-manipulator`, `expo-image-picker`
  - `react-native-reanimated` (4.5.1), `react-native-svg` (15.15.4), `qrcode` (^1.5.4)

#### `app.json`
- **Role:** Expo Application Configuration manifest.
- **Details:** Sets app name (`FairShare`), package ID (`com.fairshare.app`), scheme (`fairshare`), splash screen branding (`#208AEF`), adaptive Android icons, and enables experimental features: `typedRoutes` and `reactCompiler`.

#### `tailwind.config.js`
- **Role:** Tailwind CSS / NativeWind configuration.
- **Details:** Scans `./src/**/*.{js,jsx,ts,tsx}` and maps custom CSS theme variables (`--bg-screen`, `--bg-surface`, `--border-surface`, `--text-main`, `--text-secondary`, `--text-positive`, `--text-negative`, `--accent-pill`) to Tailwind utility classes.

#### `babel.config.js`
- **Role:** Babel compiler configuration.
- **Details:** Applies `babel-preset-expo` with `jsxImportSource: "nativewind"` and registers the `nativewind/babel` plugin for ahead-of-time className-to-style compilation.

#### `metro.config.js`
- **Role:** Metro bundler configuration for Expo.
- **Details:** Wraps the default Metro configuration with `withNativeWind(config, { input: "./src/global.css" })` to process stylesheet transformations.

#### `tsconfig.json`
- **Role:** TypeScript compiler settings.
- **Details:** Extends `expo/tsconfig.base`, enables `strict` mode, sets module path aliases (`@/*` $\rightarrow$ `./src/*`, `@/assets/*` $\rightarrow$ `./assets/*`), and excludes Supabase Deno Edge functions.

#### `jest.config.js`
- **Role:** Jest unit test configuration.
- **Details:** Configures `ts-jest` for Node testing environment, maps `@/` path aliases, and mocks React Native modules using `src/__mocks__/react-native.js`.

#### `ai-rules.md`
- **Role:** Project AI coding standards and guidelines.
- **Details:** Outlines NativeWind v4 rules (no `StyleSheet.create`, flexbox-only layout, token usage), state preservation rules (Zustand & Supabase immutability), file structure conventions, and requirement to update `ai-context.md`.

#### `AGENTS.md` & `CLAUDE.md`
- **Role:** Agent instruction files instructing LLM agents to reference Expo v57 docs.

#### `README.md` & `LICENSE`
- **Role:** Standard repository documentation and MIT License.

#### Type Declaration Files: `env.d.ts`, `expo-env.d.ts`, `nativewind-env.d.ts`, `src/global.d.ts`
- **Role:** TypeScript declaration headers providing ambient type references for Expo types, NativeWind className props, and CSS module imports (`*.module.css`).

---

### Backend & Cloud Database (`supabase/`)

#### `supabase/schema.sql`
- **Role:** PostgreSQL database schema definition with Row Level Security (RLS) for Supabase.
- **Tables Defined:**
  1. `profiles`: User accounts, avatars, UPI VPA IDs (`vpa_id`), phone numbers, and guest flags.
  2. `event_cohorts`: Groups/events with categories (`trip`, `house`, `event`, `dining`, `other`), invite codes, and currencies.
  3. `group_members`: Membership joins with roles (`admin`, `member`).
  4. `expenses`: Expense records with total amount, category, payer ID, receipt URL, and split type.
  5. `expense_line_items`: Itemized receipt lines for OCR parsing and granular splits.
  6. `expense_splits`: Member-specific expense shares and percentage allocations.
  7. `transaction_comments`: Expense-level discussions and note trails.
- **Security:** RLS policies restrict viewing and inserting cohort expenses to verified group members.

#### `supabase/functions/ocr-parser/index.ts`
- **Role:** Deno-based Supabase Edge Function for automated receipt OCR.
- **Details:** Accepts base64 encoded receipt images, connects to Google Cloud Vision API (`DOCUMENT_TEXT_DETECTION`), extracts text, executes regex-based total price extraction, and falls back to mock parsing if no API key is provided.

---

### Utility Scripts & Mocks

#### `scripts/reset-project.js`
- **Role:** Expo boilerplate cleanup script that can move starter templates to `/example` and generate clean `src/app/index.tsx` and `src/app/_layout.tsx` templates.

#### `src/__mocks__/react-native.js`
- **Role:** Jest mock for React Native environment, mocking `Platform`, `Linking` (`canOpenURL`, `openURL`), and `StyleSheet`.

---

### Domain Types & Styling System

#### `src/types/index.ts`
- **Role:** Core TypeScript domain definitions for the entire application.
- **Key Types:**
  - `SplitType`: `'equal' | 'exact' | 'percentage' | 'shares'`
  - `EventCategory`: `'trip' | 'house' | 'event' | 'dining' | 'transport' | 'utilities' | 'custom'`
  - `UserProfile`, `EventCohort`, `GroupMember`, `Expense`, `ExpenseSplit`, `LineItem`, `TransactionComment`
  - `DebtSimplificationResult` & `DirectDebt`: Structures for simplified P2P settlement graphs.
  - `UPIPaymentConfig`: Payee VPA, amount, note, and transaction parameters.
  - `SharedListItem` & `PersonalReminderSettings`: Household needs list items and reminder configs.

#### `src/constants/theme.ts`
- **Role:** Design token constants.
- **Details:** Exports base color constants, `CHART_PALETTE` array, platform-specific font family mappings (`ios`, `default`, `web`), standard spacing scale (`Spacing.half` to `Spacing.six`), and `BottomTabInset` metrics.

#### `src/global.css`
- **Role:** Global stylesheet and NativeWind component layer.
- **Details:**
  - Declares font families (`--font-display`, `--font-mono`, etc.) and chart tokens (`--chart-1` through `--chart-8`).
  - Configures 8 CSS theme classes (`.theme-nordic-dark`, `.theme-nordic-light`, `.theme-sage-dark`, `.theme-sage-light`, `.theme-taupe-dark`, `.theme-taupe-light`, `.theme-cobalt-dark`, `.theme-cobalt-light`).
  - `@layer components` definitions: `.screen-header`, `.card-main`, `.card-item`, `.card-group`, `.card-group-item`, `.group-card-title`, `.group-card-desc`, `.group-card-members`, `.fab-backdrop`, `.fab-speed-dial-menu`, `.fab-speed-dial-item`, `.fab-speed-dial-label`, `.fab-speed-dial-icon-qr`, `.fab-speed-dial-icon-add`, `.fab-main-btn`, `.btn-primary-dark`, `.btn-outline-light`, `.btn-icon-circle`, `.balance-positive`, `.balance-negative`, `.bottom-nav-bar`, and chart legend dot utility classes (`.chart-dot-1` through `.chart-dot-8`).

---

### State Management & Persistence (`src/store/`)

#### `src/store/useThemeStore.ts`
- **Role:** Zustand store managing visual theme selection and appearance mode.
- **Details:**
  - State: `themeBase` (`'nordic' | 'sage' | 'taupe' | 'cobalt'`), `colorScheme` (`'light' | 'dark' | 'system'`).
  - Persisted using MMKV storage via key `fairshare-theme-store`.
  - Exports theme metadata, preview hex codes, gradient stops (`THEME_GRADIENTS`), and helper functions: `getActiveThemeClass()` and `getThemeGradientColors()`.

#### `src/store/useExpenseStore.ts`
- **Role:** Central domain Zustand store with asynchronous Supabase sync, loading states, error handling, and MMKV offline-first persistence.
- **Details:**
  - Manages `currentUser`, `cohorts`, `members`, `expenses`, `comments`, `sharedLists`, `reminderSettings`, `isLoading`, `isSyncing`, `error`, and `offlineQueue`.
  - Async Actions: `fetchInitialData`, `fetchCohorts`, `fetchExpensesForCohort`, `refreshAll`, `addCohort`, `updateCohort`, `joinCohortByInviteCode`, `addExpense`, `updateExpense`, `deleteExpense`, `addComment`, `clearError`.
  - Persisted using MMKV via key `fairshare-store-v1` with `partialize` configuration.

---

### Services & Data Layer (`src/services/`)

#### `src/services/supabase/placeholderData.ts`
- **Role:** Centralized fallback datasets for offline operation, initial bootstrapping, and mock recovery.
- **Data:** `DEFAULT_CURRENT_USER`, `DEFAULT_COHORTS`, `DEFAULT_MEMBERS`, `DEFAULT_EXPENSES`, `DEFAULT_SHARED_LISTS`, `DEFAULT_REMINDER_SETTINGS`.

#### `src/services/supabase/profileService.ts`
- **Role:** Profile fetching and updating operations via Supabase `profiles` table.
- **Functions:** `fetchProfile`, `updateProfile`, `getCurrentProfile`.

#### `src/services/supabase/groupService.ts`
- **Role:** Cohort and membership queries connecting to `event_cohorts` and `group_members`.
- **Functions:** `fetchUserCohorts`, `createCohort`, `updateCohort`, `joinCohortByInviteCode`.

#### `src/services/supabase/expenseService.ts`
- **Role:** Ledger operations connecting to `expenses`, `expense_splits`, and `transaction_comments`.
- **Functions:** `fetchExpensesForCohort`, `createExpense`, `updateExpense`, `deleteExpense`, `fetchCommentsForExpense`, `addComment`.

#### `src/services/payment/upiIntent.ts`
- **Role:** Deep linking engine for Indian Unified Payments Interface (UPI).
- **Functions:**
  - `buildUPIIntentURL(config)`: Constructs standardized URI `upi://pay?pa=<vpa>&pn=<name>&am=<amount>&cu=INR&tn=<note>`.
  - `launchUPIIntent(config)`: Triggers device app chooser (GPay, PhonePe, Paytm, etc.) via `Linking.openURL()`.
- **Test Suite:** `src/services/payment/__tests__/upiIntent.test.ts` verifies exact URI parameter encoding.

#### `src/services/storage/mmkv.ts`
- **Role:** Fast MMKV local key-value storage adapter for Zustand persistence.
- **Details:** Instantiates `react-native-mmkv` instance with graceful fallback to an in-memory `Map` for web and Expo Go environments.

#### `src/services/supabase/client.ts`
- **Role:** Supabase JS client initializer and configuration checker.
- **Details:** Configures client with `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY`, auto-refreshing tokens, exports `isSupabaseConfigured()` guard (preventing network error spam when placeholder credentials are used), and exports `signInAsGuest()` for anonymous authentication.


---

### Core Algorithms & Utilities (`src/utils/`)

#### `src/utils/debtSimplifier.ts`
- **Role:** Greedy Min-Flow Graph algorithm to simplify multi-party group debts.
- **Logic:**
  1. Computes net position for each member (Credits for paying, Debits for share of splits).
  2. Divides participants into `debtors` (negative balance) and `creditors` (positive balance).
  3. Sorts both lists in descending order of balance.
  4. Greedily pairs the largest debtor with the largest creditor, settling $\min(\text{debtor}, \text{creditor})$ and advancing pointers until all balances reach zero.
- **Test Suite:** `src/utils/__tests__/debtSimplifier.test.ts` verifies pairwise debt resolution and multi-person circular debt elimination ($A \rightarrow B \rightarrow C \rightarrow A$).

#### `src/utils/imageCompressor.ts`
- **Role:** Client-side receipt image compression.
- **Details:** Uses `expo-image-manipulator` to resize invoice photos to max width 1200px and compress to JPEG (0.7 quality), keeping file sizes under 300KB to reduce Supabase storage overhead.

---

### Custom Hooks (`src/hooks/`)

#### `src/hooks/use-theme.ts`
- **Role:** Returns color token palette from `Colors` based on current color scheme.

#### `src/hooks/use-color-scheme.ts` & `src/hooks/use-color-scheme.web.ts`
- **Role:** Universal color scheme hook handling hydration on Web to prevent SSR mismatched styles.

---

### Design System & UI Primitives (`src/components/ui/`)

#### `src/components/ui/EmptyState.tsx`
- **Role:** Reusable neo-fintech empty state card and inline fallback component with frosted pill icon, title, description, primary CTA, and optional secondary action.

#### `src/components/ui/Button.tsx`
- **Role:** Reusable atomic button component supporting `default`, `outline`, and `ghost` variants in `default` or `icon` sizes.

#### `src/components/ui/Text.tsx`
- **Role:** Custom NativeWind-compatible Text primitive wrapping React Native's `<Text>` with automatic `text-main` theme color fallback when no explicit text color is specified.


#### `src/components/ui/CategoryIcon.tsx`
- **Role:** Renders rounded category badge icons (`trip`, `house`, `dining`, `event`, `transport`, `utilities`, or custom icons). Includes `GENERIC_CUSTOM_ICONS` catalog of 30+ Ionicons for custom categories. Uses stable inline styling for solid and light variants to guarantee immunity from NativeWind v4 dynamic CSS-variable upgrades and avoid modal crashes during active category switching.


#### `src/components/ui/GroupAvatar.tsx`
- **Role:** Displays a group profile picture if `avatarUrl` (or `bannerUrl`) is set, seamlessly falling back to `CategoryIcon` when no custom picture is chosen. Used across group cards, lists, banners, and modals.

#### `src/components/ui/ThemeGradientHeader.tsx`
- **Role:** Curved 3-stop SVG linear gradient container rendered via `react-native-svg` (`Defs`, `LinearGradient`, `Rect`) that dynamically resizes using `onLayout`.

#### `src/components/ui/collapsible.tsx`
- **Role:** Animated expandable accordion widget powered by `react-native-reanimated` (`FadeIn`).

---

### Feature Modals & Tab Components (`src/components/`)

#### `src/components/AddExpenseModal.tsx`
- **Role:** Full-screen modal for adding expenses using the clean Splitwise-style multi-step workflow.
- **Capabilities:** Features an uncluttered main form with group badge, category icon button, underlined description and rupee amount inputs, natural language sentence selector (`Paid by [you] and split [equally]`), bottom accessory toolbar with date/camera receipt/notes, sub-screens for **Who paid?** (single-payer selection and multiple-payer amount allocation), and **Adjust split** (5 tabs: Equally with per-person calculation and all-select toggle, Unequally, By %, By shares, and **By adjustment** with dynamic remainder distribution). Styled with `.fairshare-expense-*` classes in `global.css`.

#### `src/components/EditExpenseModal.tsx`
- **Role:** Full-screen modal for editing existing expenses, pre-populating existing splits, payers, receipt attachments, and adjustment amounts in the clean Splitwise-style multi-step layout.



#### `src/components/ExpenseDetailsModal.tsx`
- **Role:** Bottom-sheet modal displaying full transaction breakdown, payer badge, split distributions, notes, and embedded comment thread.

#### `src/components/CreateGroupModal.tsx` & `src/components/EditGroupModal.tsx`
- **Role:** Modals for creating and editing event cohorts, categories, currencies, and unique invite codes (`<NAME><SUFFIX>`).
- **Details:** Wrapped in `activeThemeClass` to ensure CSS custom variables (`--bg-surface`, `--text-main`, `--accent-pill`) resolve seamlessly in detached native modal portals without triggering `cssInterop` upgrade crashes. Includes safe null checks on `cohort`, normalized category/custom category sync, and persistent custom icon selection.



#### `src/components/SelectGroupModal.tsx`
- **Role:** Bottom-sheet selector allowing users to choose which cohort an expense belongs to before launching the Add Expense modal.

#### `src/components/QRCodeModal.tsx`
- **Role:** Modal displaying an in-memory generated QR code matrix (`qrcode` library) linking to `fairshare://join/<inviteCode>` for instant cohort invites.

#### `src/components/ThemeSettingsModal.tsx`
- **Role:** Modal allowing users to preview and select from the 4 color palettes (Nordic, Sage, Taupe, Cobalt) and 3 appearance modes (System, Light, Dark).

#### `src/components/MonthlySpendingsTab.tsx`
- **Role:** Cohort tab component rendering an SVG Donut Pie chart breakdown of spending by participant with side color legends including both amount (₹) and percentage (%), themed summary cards, and group spend statistics (Top Spender who paid upfront vs. Highest Consumer who incurred the most share).



#### `src/components/NeedsListTab.tsx`
- **Role:** Cohort tab providing a shared "Cart of the House" grocery/supplies checklist, styled with frosted accent pill backgrounds and theme tokens, auto-clearing checked items older than 5 days, highlighting 3+ day stale items, and featuring configurable reminder intervals (every 6 hours default, or customized hours/days with time of day and notification disable toggles).

#### `src/components/StaleNeedsReminderModal.tsx`
- **Role:** Pop-up reminder modal displayed on app launch alerting users when any household needs list items have remained unchecked for 3 or more days, with direct "Mark as Bought" and dismiss actions.



#### `src/components/TransactionComments.tsx`
- **Role:** Real-time expense discussion thread and note logging component.

#### `src/components/BottomNav.tsx`
- **Role:** Custom 4-tab bottom navigation bar (`Home`, `Groups`, `Activity`, `Profile`) matching theme tokens.

#### Starter/Template Components:
- `animated-icon.tsx`, `animated-icon.web.tsx`, `animated-icon.module.css`: Keyframe animated splash screen and rotating logo overlays.
- `app-tabs.tsx` & `app-tabs.web.tsx`: Expo experimental tab trigger bar.
- `external-link.tsx`: In-app browser link handler via `expo-web-browser`.
- `hint-row.tsx`, `themed-text.tsx`, `themed-view.tsx`, `title-bar.tsx`, `web-badge.tsx`: Template starter components and Expo badge wrappers.

---

### App Navigation & Screens (`src/app/`)

#### `src/app/_layout.tsx`
- **Role:** Root layout of the entire application.
- **Details:** Sets up Buffer polyfill, initializes `SafeAreaProvider`, listens to theme state from `useThemeStore`, applies the active theme CSS class to the root `<View>`, renders `<AnimatedSplashOverlay />`, and defines the `Stack` router navigation (`(tabs)`, `event/[id]`, and `scan` modal).

#### `src/app/(tabs)/_layout.tsx`
- **Role:** Tab navigator layout defining the 4 main tabs (`index`, `groups`, `activity`, `profile`) rendered through `BottomNav.tsx`.

#### `src/app/(tabs)/index.tsx`
- **Role:** Main Dashboard screen.
- **Details:** Renders `ThemeGradientHeader` with user avatar, search pill, settings shortcut, prominent Net Balance display ($\pm ₹X$), quick action buttons (*Add*, *Scan Receipt*, *Scan QR*, *New Group*), pull-to-refresh (`RefreshControl`), horizontal group card carousel with empty state fallback, and recent activity feed with empty state fallback.

#### `src/app/(tabs)/groups.tsx`
- **Role:** Groups & Event Cohorts directory screen.
- **Details:** Features dual group card layouts with bold title typography, clearly differentiated descriptions and icon-prefixed desaturated member rosters, styled via `.card-group-item`, `.group-card-title`, `.group-card-desc`, and `.group-card-members` in `global.css`, with a compact, bottom-right pinned expandable speed-dial Floating Action Button (FAB) positioned immediately above the tab bar.







#### `src/app/(tabs)/activity.tsx`
- **Role:** Global chronologically-sorted activity feed.
- **Details:** Aggregates expenses and comments across all cohorts where the current user is involved, formatting relative timestamps (e.g. *2h ago*, *yesterday*).

#### `src/app/(tabs)/profile.tsx`
- **Role:** User Profile and Settings screen.
- **Details:** Displays user credentials, UPI VPA ID, payment preferences, notification controls, and entry to the `ThemeSettingsModal`.

#### `src/app/event/[id].tsx`
- **Role:** Single Event / Cohort Ledger details screen.
- **Details:**
  - Banner Card featuring `GroupAvatar` profile picture, bold Group Name, category badge pill with icon and title, group description, and personal net balance ($\pm ₹X$).
  - Sub-tab switcher: **General Ledger** featuring **Status** (personalized settlement directives such as *"Person X owes you ₹X"* / *"You owe Person X ₹X"* with one-tap UPI payments) and **History** (expense log displaying total amount alongside user's net $+\text{₹X}$ / $-\text{₹X}$ share), **Monthly Spendings** (spending charts), and **Needs / House Cart** (shared grocery checklist).
  - FAB for logging new expenses, three-dot options menu for QR invites and editing group details.



#### `src/app/scan.tsx`
- **Role:** QR code camera scanner screen using `expo-camera`.
- **Details:** Asynchronously detects QR codes or deep link formats (`fairshare://join/<code>`), verifies invite code against local cohorts or Supabase, joins the group, and routes directly to the event ledger. Includes a simulator button (`GOA2026`) for emulator testing.

#### `src/app/explore.tsx`
- **Role:** Starter documentation and template reference screen.

---

### Static Assets (`assets/`)

- `assets/Untitled/`: High-fidelity design mockups (`home-dashboard.png`, `activity-history.png`, `groups.png`, `profile-settings.png`).
- `assets/images/`: App logos, Android adaptive foreground/backgrounds, splash icon, tab icons (`home.png`, `explore.png`).
- `assets/expo.icon/`: iOS asset catalog icon configuration.

---

## 4. Key Architectural Patterns & Data Flow

```mermaid
graph TD
    User([User Action]) --> AppRouter[Expo Router /app]
    AppRouter --> Screen[Screen Component]
    Screen --> Zustand[Zustand Store: useExpenseStore / useThemeStore]
    Zustand --> MMKV[MMKV Fast Storage]
    Zustand --> Services[Supabase Services: groupService / expenseService / profileService]
    Services --> DB[(Supabase PostgreSQL)]
    Screen --> DebtEngine[debtSimplifier.ts]
    DebtEngine --> MinFlowGraph[Greedy Min-Flow Graph Solver]
    MinFlowGraph --> DirectDebts[Direct P2P Settle-Up List]
    DirectDebts --> UPI[upiIntent.ts]
    UPI --> NativeApps[GPay / PhonePe / Paytm Deep Link]
    Screen --> ImageComp[imageCompressor.ts]
    ImageComp --> EdgeOCR[Supabase Edge Function: ocr-parser]
    EdgeOCR --> GoogleVision[Google Cloud Vision OCR]
```
