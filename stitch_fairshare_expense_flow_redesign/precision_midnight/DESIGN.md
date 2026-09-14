---
name: Precision Midnight
colors:
  surface: '#111317'
  surface-dim: '#111317'
  surface-bright: '#37393d'
  surface-container-lowest: '#0c0e11'
  surface-container-low: '#1a1c1f'
  surface-container: '#1e2023'
  surface-container-high: '#282a2d'
  surface-container-highest: '#333538'
  on-surface: '#e2e2e6'
  on-surface-variant: '#bbc9cf'
  inverse-surface: '#e2e2e6'
  inverse-on-surface: '#2f3034'
  outline: '#859399'
  outline-variant: '#3c494e'
  surface-tint: '#47d6ff'
  primary: '#a5e7ff'
  on-primary: '#003543'
  primary-container: '#00d2ff'
  on-primary-container: '#00566a'
  inverse-primary: '#00677f'
  secondary: '#7bd0ff'
  on-secondary: '#00354a'
  secondary-container: '#00a6e0'
  on-secondary-container: '#00374d'
  tertiary: '#d2ddf5'
  on-tertiary: '#263143'
  tertiary-container: '#b6c1d9'
  on-tertiary-container: '#444f63'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#b6ebff'
  primary-fixed-dim: '#47d6ff'
  on-primary-fixed: '#001f28'
  on-primary-fixed-variant: '#004e60'
  secondary-fixed: '#c4e7ff'
  secondary-fixed-dim: '#7bd0ff'
  on-secondary-fixed: '#001e2c'
  on-secondary-fixed-variant: '#004c69'
  tertiary-fixed: '#d8e3fb'
  tertiary-fixed-dim: '#bcc7de'
  on-tertiary-fixed: '#111c2d'
  on-tertiary-fixed-variant: '#3c475a'
  background: '#111317'
  on-background: '#e2e2e6'
  surface-variant: '#333538'
typography:
  headline-xl:
    fontFamily: Hanken Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.03em
  headline-xl-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-sm:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Geist
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.25rem
  gutter-sm: 0.75rem
  gutter-lg: 2rem
  margin: 1.5rem
  margin-sm: 1rem
  margin-lg: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system delivers an exacting, high-performance financial atmosphere tailored for precision expense tracking and shared capital allocation. The aesthetic balances deep-space minimalism with technical financial tooling, instilling confidence, absolute clarity, and frictionless collaboration.

The visual direction draws on modern dark-mode fintech interfaces:
- **Surface Depth over Clutter:** Obsidian-tinted foundations layered beneath subtle midnight blue and slate-gray planes.
- **Electric Accents:** Deliberately restrained hits of cyan and electric blue reserved purely for critical actions, key telemetry, and dynamic focus rings.
- **Surgical Typography:** Monoline, hyper-clean grotesque letterforms calibrated for data density and tabular scannability.
- **Tactile Precision:** Softened rectangular forms with gentle interior glow effects and microscopic borders that define space without adding visual noise.

## Colors

The palette establishes an ultra-deep charcoal and midnight ecosystem designed to eliminate eye fatigue while making monetary values leap forward with crisp contrast.

- **Canvas Foundation (`#0d0f12`):** True deep-space black with a fraction of midnight tint, anchoring the application background.
- **Surface Elevation 1 (`#12161c`):** Slightly lifted surface for container groupings, primary cards, and persistent navigation bars.
- **Surface Elevation 2 (`#1a202c`):** Interactive inputs, nested summary cards, and hover states.
- **Primary Accent (`#00d2ff`):** Electric Cyan, applied strictly to high-priority interactive calls-to-action, active toggles, and live balance counters.
- **Secondary Accent (`#38bdf8`):** Sky Slate, applied to secondary actions, focus indicators, and chart telemetry paths.
- **Subtle Midnight/Slate Tint (`#1e293b`):** Subdued structure lines, borders, and passive segmented controls.
- **Text Primary (`#f8fafc`):** Pure optical contrast for key amounts and headlines.
- **Text Secondary (`#94a3b8`):** Cool slate tone for labels, timestamps, and secondary metadata.
- **Success / Positive (`#10b981`):** Net positive balances and settlements.
- **Destructive / Negative (`#f43f5e`):** Debts, overdue splits, and destructive confirmations.

## Typography

The type system pairs **Hanken Grotesk** for conversational and structural elements with **Geist** for technical data, transaction rows, and UI microcopy.

- All numeric data, including balances, splits, and percentages, must render with tabular figures (`font-variant-numeric: tabular-nums`) to maintain vertical alignment across columns.
- Headlines leverage tight negative tracking to maintain punchiness and density.
- Secondary labels and status badges use `Geist` with positive letter tracking for legibility at compact dimensions.

## Layout & Spacing

The layout adopts an adaptable 12-column grid on desktop screens, scaling down smoothly to an 8-column layout on tablets and a 4-column layout on mobile devices.

- **Desktop (1024px+):** Max-width 1280px, 12 columns, 32px (`gutter-lg`) gutters, 48px (`margin-lg`) margin.
- **Tablet (640px - 1023px):** Fluid layout, 8 columns, 20px (`gutter`) gutters, 24px (`margin`) margins.
- **Mobile (under 640px):** Single primary stack, 4 columns, 12px (`gutter-sm`) gutters, 16px (`margin-sm`) edge margins.
- **Component Geometry:** Padding uses an 8px base rhythm (`space-sm` = 8px, `space-md` = 16px, `space-lg` = 24px), preserving structured internal whitespace across balance breakdowns and feed listings.

## Elevation & Depth

Visual plane differentiation relies on surface tonal transitions paired with hair-thin borders rather than deep diffuse drop-shadows, maintaining a sleek, digital instrument feel.

- **Base Layer:** `#0d0f12` canvas background.
- **Level 1 (Cards, Modules, Persistent Bars):** Background `#12161c`, layered with a 1px border using `rgba(148, 163, 184, 0.08)`.
- **Level 2 (Popovers, Overlays, Dropdowns):** Background `#1a202c`, 1px border `rgba(148, 163, 184, 0.16)`, accompanied by an ambient shadow: `0 12px 32px -4px rgba(0, 0, 0, 0.6)`.
- **Active Focus & Glow:** Elements under active focus receive an electric outer ring: `0 0 0 1px #00d2ff, 0 0 16px -2px rgba(0, 210, 255, 0.3)`.

## Shapes

The design system employs refined geometric rounding to balance computational rigor with approachable softness:

- **Cards & Primary Modules:** 16px to 20px radius (`rounded-lg` / `rounded-xl`) defining card boundaries, balancing large displays and mobile viewports.
- **Inputs & Secondary Controls:** 10px to 12px radius, yielding comfortable touch zones with distinct internal hierarchy.
- **Badges & Status Pills:** Fully circular capsule radius (`9999px`) for micro-indicators, participant avatars, and category markers.

## Components

### Buttons
- **Primary:** Solid `#00d2ff` fill with `#0d0f12` high-contrast bold text. On hover, shifts to `#38bdf8` with a soft cyan radial edge reflection.
- **Secondary:** Surface `#12161c` background with a subtle border in `rgba(56, 189, 248, 0.3)` and `#f8fafc` text. Hover state brightens border to `rgba(56, 189, 248, 0.7)` and surfaces `#1a202c`.
- **Ghost:** Transparent background, slate `#94a3b8` label, transitioning to white on interaction.

### Input Fields
- **Container:** `#12161c` background with a 1px border of `rgba(148, 163, 184, 0.12)`.
- **State:** On focus, the border shifts to `#00d2ff` accompanied by an electric micro-glow.
- **Numeric Fields:** Tabular currency symbols fixed in `#38bdf8` with prominent, right-aligned entry typography.

### Cards
- Constructed with `#12161c` backgrounds and a 16px–20px corner radius.
- Cards group expenses, individual balance summaries, and settlement timelines with distinct 16px padding on mobile and 24px on desktop.

### Chips & Filter Pills
- Inactive state utilizes `#12161c` surface with muted text.
- Active state uses a midnight cyan tint (`rgba(0, 210, 255, 0.12)`) bounded by a 1px `#00d2ff` hairline stroke and vibrant cyan text.

### Checkboxes & Radios
- Square with 4px radius (checkbox) or circle (radio), `#1a202c` background, `#334155` border.
- Selected state fills with `#00d2ff` and displays an obsidian mark.

### Split Sliders & Dynamic Splitters
- Custom track in `#1e293b` with a continuous fill in `#00d2ff`. Thumb control is a solid `#f8fafc` capsule with a 2px inner ring of `#0d0f12`.

### Transaction List Items
- Flat rows separated by `1px solid rgba(148, 163, 184, 0.06)` dividers.
- Positive figures styled in `#10b981`, owed debts styled in `#f43f5e`, and zero/settled balances displayed in slate `#94a3b8`.