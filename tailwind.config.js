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
        chart: {
          1: 'var(--chart-1)',
          2: 'var(--chart-2)',
          3: 'var(--chart-3)',
          4: 'var(--chart-4)',
          5: 'var(--chart-5)',
          6: 'var(--chart-6)',
          7: 'var(--chart-7)',
          8: 'var(--chart-8)',
        },
      },
      borderColor: {
        surface: 'var(--border-surface)',
      },
    },
  },
  plugins: [],
}
