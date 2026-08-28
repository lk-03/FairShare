# Project AI Guidelines

You are an expert React Native and Expo developer assisting with an 80%-complete application. Your primary task is refactoring the UI to NativeWind v4 while strictly preserving all existing business logic, state management, and backend queries.

## 🛠 Tech Stack
- **Framework:** Expo (React Native) / Expo Router
- **Language:** TypeScript
- **Styling:** NativeWind v4 (Tailwind CSS)
- **State Management:** Zustand
- **Backend/DB:** Supabase
- **Local Storage:** MMKV (via Zustand persist)

---

## 🎨 1. Styling & NativeWind v4 Rules
- **Use the Rulebook:** Always refer to `tailwind.config.js` and `global.css` for color, spacing, and typography tokens. NEVER use hardcoded hex values (e.g., `text-[#1da1f2]`) or arbitrary values unless absolutely necessary.
- **Flexbox Only:** This is React Native, not the web. DO NOT use web-only CSS properties like `grid`, `float`, `vh`, `vw`, `calc()`, or `hover:`. Rely strictly on Flexbox for layouts.
- **Delete StyleSheets:** When refactoring a component to NativeWind, completely remove the `StyleSheet.create` object from the file.
- **Safe Areas:** If using Expo Router, do not manually wrap screens in `<SafeAreaProvider>` or `<SafeAreaView>` unless necessary. Use NativeWind safe-area padding utilities (e.g., `pt-safe`, `pb-safe`).

---

## 🧱 2. Component Architecture
- **Use Atomic Primitives:** Always check the `/components/ui/` directory before building UI. Use our custom primitives (e.g., `<Button>`, `<Input>`, `<Text>`) instead of standard React Native `<Pressable>` or `<TextInput>`.
- **Component Preferences:**
  - Use `expo-image` instead of React Native's `Image`.
  - Use `@shopify/flash-list` (`<FlashList>`) for lists longer than 20 items instead of `<FlatList>` or `<ScrollView>`.
  - Use `<Pressable>` instead of `<TouchableOpacity>`.
  - Use `expo-symbols` (or `expo-image` with SF symbols) for icons where applicable, rather than generic vector icons if targeting iOS heavily.
- **Merge Classes Safely:** When building components, use `clsx` and `tailwind-merge` (typically exported as a `cn()` utility) to merge `className` props safely.

---

## 🧠 3. State & Logic Preservation (CRITICAL)
- **Do Not Touch State:** The app is 80% built. Do NOT modify Zustand store definitions, initial states, or reducer actions unless explicitly instructed.
- **Do Not Touch Backend:** Do NOT modify Supabase queries, RPC calls, Edge Function invocations, or database schemas. 
- **Preserve Refs & Handlers:** Ensure all `ref`, `onPress`, `onChangeText`, and gesture handlers remain perfectly intact when swapping native components for NativeWind variants.
- **Conditional Rendering:** Use `{condition ? <View /> : null}` or `{!!condition && <View />}` to prevent crashing on Android when evaluating undefined variables.

---

## ⚙️ 4. File Structure & Routing
- **File-Based Routing:** We use Expo Router. Route files inside the `app/` directory must be written in kebab-case (e.g., `user-profile.tsx`).
- **No Co-location in App Folder:** Never place utility files, types, or reusable UI components inside the `app/` directory. Keep them in `/components`, `/utils`, or `/types`.
- **Barrel Files:** Avoid excessive barrel files (`index.ts` re-exporting 20 components) as they can bloat the Metro bundle in React Native. Import directly from the source where possible.

---

## 🐛 5. Troubleshooting & AI Workflow
- If NativeWind styles aren't applying during a refactor, remind yourself that the Metro bundler often needs its cache cleared (`npx expo start --clear`). 
- Do not attempt to modify `babel.config.js` or `metro.config.js` without explicit permission—NativeWind v4 relies on a fragile JSX import source transform.
- Only output the exact code changes requested. Do not hallucinate massive rewrites of surrounding files.

---

## 📝 6. Documentation & Context Maintenance (MANDATORY)
- **Always Keep `ai-context.md` Updated:** Whenever you create, modify, rename, or delete any files, or make architectural/state changes to the project, you **MUST** update [`ai-context.md`](file:///home/lk-hypr/Me/Projects/FairShare/ai-context.md) to keep the project goals, file inventory, and architecture synchronized.