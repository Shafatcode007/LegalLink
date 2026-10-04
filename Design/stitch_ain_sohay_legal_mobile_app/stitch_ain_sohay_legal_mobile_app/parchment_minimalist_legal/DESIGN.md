---
name: Parchment Minimalist Legal
colors:
  surface: '#fbf9f3'
  surface-dim: '#dcdad4'
  surface-bright: '#fbf9f3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3ed'
  surface-container: '#f0eee8'
  surface-container-high: '#eae8e2'
  surface-container-highest: '#e4e2dc'
  on-surface: '#1b1c18'
  on-surface-variant: '#45464b'
  inverse-surface: '#30312d'
  inverse-on-surface: '#f3f1eb'
  outline: '#76777c'
  outline-variant: '#c6c6cc'
  surface-tint: '#5a5e6a'
  primary: '#02050d'
  on-primary: '#ffffff'
  primary-container: '#1a1e28'
  on-primary-container: '#828692'
  inverse-primary: '#c3c6d4'
  secondary: '#7c580f'
  on-secondary: '#ffffff'
  secondary-container: '#fecd7a'
  on-secondary-container: '#78550b'
  tertiary: '#000602'
  on-tertiary: '#ffffff'
  tertiary-container: '#082314'
  on-tertiary-container: '#708d77'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dfe2f0'
  primary-fixed-dim: '#c3c6d4'
  on-primary-fixed: '#171b25'
  on-primary-fixed-variant: '#434752'
  secondary-fixed: '#ffdeab'
  secondary-fixed-dim: '#efbf6e'
  on-secondary-fixed: '#271900'
  on-secondary-fixed-variant: '#5f4100'
  tertiary-fixed: '#cbead1'
  tertiary-fixed-dim: '#afceb6'
  on-tertiary-fixed: '#052011'
  on-tertiary-fixed-variant: '#324d3a'
  background: '#fbf9f3'
  on-background: '#1b1c18'
  surface-variant: '#e4e2dc'
typography:
  headline-xl:
    fontFamily: Inter
    fontSize: 34px
    fontWeight: '600'
    lineHeight: 41px
    letterSpacing: -0.022em
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.021em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.018em
  headline-sm:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.015em
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.015em
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: -0.010em
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.005em
  label-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: -0.010em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 12px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
---

## Brand & Style

This design system establishes a focused, hyper-restrained mobile environment built for high-stakes legal context. It merges strict Apple iOS Human Interface guidelines with an extreme minimalist editorial discipline: every element must justify its presence on the canvas. 

The aesthetic is quiet, authoritative, and tactfully calm. The target audience interacts with legal proceedings, emergency compliance alerts, or sensitive contract verification where visual chaos creates anxiety. To counter this, the interface behaves like an illuminated parchment desk: deeply tactile yet digital, unhurried, and completely devoid of decorative noise. 

Key attributes include:
- **Radical Reduction:** Text is condensed by up to 60%, strictly capping descriptions to 1–2 lines. Interfaces prefer icon-driven communication, tactile disclosure chevrons (`›`), and progressive reveal over cluttered dashboard feeds.
- **Warm Architectural Precision:** Instead of sterile lab white, natural parchment and deep oxford tones yield an institutional gravitas without coldness.
- **Pure Functional Hierarchy:** Visual interest is built strictly through scale, generous negative space, and tonal card layering, never through arbitrary ornamentation or harsh borders.

## Colors

The palette is tuned around subtle warmth and restrained contrast, replacing stark clinical whites with organic, archival tones.

### Canvas & Surfaces
- **Canvas Base (`#F0EEE8`):** The primary parchment field across full screens and system backdrops.
- **Surface Raised (`#F7F5F1`):** Applied to floating cards, modals, and actionable interactive blocks. Lighter than the canvas to draw focus forward naturally.
- **Surface Sunken (`#E7E4DC`):** Recessed wells, text fields, disabled states, and track backgrounds.

### Content & Typography
- **Primary Ink (`#1A1E28` - Oxford):** The singular high-contrast tone for headlines, primary labels, and active navigation icons.
- **Muted Ink (`#6B7280` - Oxford Muted):** Subtitles, meta-timestamps, and secondary instructions. Never dropped below WCAG AA legibility thresholds against Parchment surfaces.

### Accents & Semantic States
- **Active / Accent (`#7F5B12` - Brass):** Used with extreme restraint for active tab markers, primary CTA fills, and active filter states.
- **Emergency / Critical (`#7A2230` - Burgundy):** Dedicated strictly to SOS workflows, irreversible actions, and legal breach alerts. Prohibited from general marketing or standard warnings.
- **Verified / Success (`#2F4A38` - Forest):** Confirmed documents, active protection locks, notarized markers, and valid status chips.
- **Hairlines / Dividers (`#CFC7B6` - Stone):** Low-contrast structural bounds, timeline tracks, and segmented list separators.

## Typography

Typography is exclusively rendered in **Inter**, establishing a pure, geometric, and modern visual cadence across all platforms. Serif faces are entirely excluded to prevent faux-traditional clutter and sustain an agile iOS software character.

### Typographic Rules
- **Headline Scarcity:** Large headlines (`headline-xl`, `headline-lg`) appear only once per view at the top of the canvas during standard scroll states, compressing into standard iOS navigation bars on scroll.
- **Copy Restraint:** Body copy is restricted to a maximum of 2 lines per cell or item. Detailed text documents must be pushed behind tap-to-expand disclosure views or modal sheets.
- **Micro-Labels:** Use `label-sm` with slight positive tracking (`0.04em`) and uppercase styling exclusively for legal category badges, step indicators, and status tags.

## Layout & Spacing

The layout model is driven by generous, deliberate whitespace to enforce mental clarity. The interface relies on an airy content flow centered inside an iOS safe-area frame.

### Spatial Rhythm
- **Outer Canvas Margins:** On mobile, a base padding of 16px (`1rem`) scales to 24px (`1.5rem`) on tablet and 32px (`2rem`) on wider screens.
- **Card Interior Padding:** Core cards maintain a strict 24px–32px interior inset (`space-lg` to `space-xl`) to establish an open, floating presence.
- **Inter-Card Spacing:** Distinct cards and group units maintain 24px (`space-lg`) separation.
- **Major Section Division:** Major groupings and workflows use 48px (`space-2xl`) vertical margins, allowing the parchment background to clearly delimit information chunks without heavy dividing lines.

### Structure
- Mobile adopts a single-column layout prioritizing single-thumb interactions.
- Tablet and desktop constrain content within a centered 720px reader frame for documents, or an 8-column layout with 24px gutters for split verification queues.

## Elevation & Depth

Hierarchy in this design system rejects heavy outlines, multi-colored drop shadows, and high-opacity borders. Depth is realized through **tonal stacking** complemented by an ambient, diffused shadow.

### Layer Stacking
1. **Floor (Parchment `#F0EEE8`):** The primary view boundary.
2. **Elevated (Parchment-Raised `#F7F5F1`):** Primary floating content cards, action surfaces, and sheets.
3. **Sunken (Parchment-Sunken `#E7E4DC`):** Inset controls, search trays, inputs, and track indicators.

### Shadow Architecture
- **Soft Ambient Float:** `box-shadow: 0 2px 8px rgba(26, 30, 40, 0.06);` applied to raised cards and floating interactive elements.
- **Floating Modals & Sheets:** `box-shadow: 0 12px 32px rgba(26, 30, 40, 0.08);` applied strictly to modal bottom sheets and floating centered dialogs.
- **Hairlines:** In places where separation is required without elevation change (such as list groups), use a 0.5px hairline in Stone (`#CFC7B6`). Never use black or high-contrast structural borders.

## Shapes

The shape vocabulary mirrors contemporary iOS surfacing, balancing smooth curvature with structured content clarity:

- **Cards & Primary Blocks:** `16px` radius (`rounded-lg`). Ensures cards appear as soft, distinct units over the parchment background.
- **Floating Dialogs & Bottom Sheets:** `24px` radius (`rounded-xl`) on top edges or full bounds to convey elevation and dismissibility.
- **Pills, Chips & Nav Items:** Fully rounded `999px` capsule geometry for tags, status indicators, and touch targets.
- **Inputs & Inset Wells:** `12px` radius to maintain nested concentricity inside 16px cards.

## Components

### Buttons
- **Primary Action:** Solid Oxford (`#1A1E28`) background with Parchment-Raised (`#F7F5F1`) text, 999px pill radius, 52px height. Under active press, opacity smoothly transitions to `0.85`.
- **Accent Action:** Solid Brass (`#7F5B12`) with white text, used strictly for progression triggers (e.g., "Sign Legal Hold", "Authorize").
- **Secondary / Ghost:** Parchment-Sunken (`#E7E4DC`) fill or borderless Oxford text with `label-lg` sizing, no shadow.
- **Emergency Button:** Burgundy (`#7A2230`) fill, white text, pill radius. Restricted strictly to SOS actions.

### Cards & Grouped Containers
- Rendered in Parchment-Raised (`#F7F5F1`) with the signature ambient shadow (`0 2px 8px rgba(26,30,40,0.06)`).
- Padding is fixed at 24px (compact) or 32px (generous).
- No outline stroke. Border-radius is locked at 16px.

### Progressive Disclosure Lists
- Grouped list rows rest within a unified 16px card.
- Rows are separated by a 0.5px Stone (`#CFC7B6`) hairline that stops 16px short of the left/right bounds.
- Every interactive row ends with an Oxford-Muted (`#6B7280`) disclosure chevron (`›`), signaling progressive detail views.
- Text labels are strictly single-line; secondary explanations truncate with ellipsis at 1 line.

### Input Fields
- Built with a Parchment-Sunken (`#E7E4DC`) background, 12px radius, and 48px height.
- Default state has zero border. Focus state introduces an inner or faint stroke in Brass (`#7F5B12`).
- Placeholder text is set in Oxford-Muted (`#6B7280`).

### Chips & Badges
- 999px pill form factor. Height is 24px for micro-badges, 32px for interactive filter chips.
- Status badges use muted tinted backgrounds:
  - Verified: Forest tint (`rgba(47, 74, 56, 0.1)`) with Forest text (`#2F4A38`).
  - Emergency/Active Breach: Burgundy tint (`rgba(122, 34, 48, 0.1)`) with Burgundy text (`#7A2230`).
  - Standard/Neutral: Parchment-Sunken (`#E7E4DC`) with Oxford text (`#1A1E28`).

### Navigation & Tab Bar
- **Bottom Navigation:** Fixed floating bar with blur (`backdrop-filter: blur(20px)`) over Parchment-Raised (`rgba(247, 245, 241, 0.85)`).
- Strictly icon-only navigation without text labels. Active tab rendered in Brass (`#7F5B12`), inactive in Oxford-Muted (`#6B7280`).
- Safe-area aware, pill-shaped floating envelope or edge-to-edge docked bar with 0.5px Stone border top.