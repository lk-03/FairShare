/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}", "./app/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        screen: 'var(--bg-screen)',
        surface: 'var(--bg-surface)',
        'surface-border': 'var(--border-surface)',
        main: 'var(--text-main)',
        secondary: 'var(--text-secondary)',
        positive: 'var(--text-positive)',
        negative: 'var(--text-negative)',
        'accent-pill': 'var(--accent-pill)',
        'accent-pill-text': 'var(--accent-pill-text)',
      },
      borderColor: {
        surface: 'var(--border-surface)',
      },
    },
  },
  plugins: [],
}
