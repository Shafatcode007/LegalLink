---
name: Ain Sohay
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
  on-surface-variant: '#4f4538'
  inverse-surface: '#30312d'
  inverse-on-surface: '#f3f1eb'
  outline: '#807566'
  outline-variant: '#d2c4b3'
  surface-tint: '#7c580f'
  primary: '#634400'
  on-primary: '#ffffff'
  primary-container: '#7f5b12'
  on-primary-container: '#ffd899'
  inverse-primary: '#efbf6e'
  secondary: '#5a5e6a'
  on-secondary: '#ffffff'
  secondary-container: '#dcdfed'
  on-secondary-container: '#5f626e'
  tertiary: '#35503d'
  on-tertiary: '#ffffff'
  tertiary-container: '#4c6854'
  on-tertiary-container: '#c6e5cd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdeab'
  primary-fixed-dim: '#efbf6e'
  on-primary-fixed: '#271900'
  on-primary-fixed-variant: '#5f4100'
  secondary-fixed: '#dfe2f0'
  secondary-fixed-dim: '#c3c6d4'
  on-secondary-fixed: '#171b25'
  on-secondary-fixed-variant: '#434752'
  tertiary-fixed: '#cbead1'
  tertiary-fixed-dim: '#afceb6'
  on-tertiary-fixed: '#052011'
  on-tertiary-fixed-variant: '#324d3a'
  background: '#fbf9f3'
  on-background: '#1b1c18'
  surface-variant: '#e4e2dc'
  parchment-canvas: '#F0EEE8'
  parchment-raised: '#F7F5F1'
  parchment-sunken: '#E7E4DC'
  oxford: '#1A1E28'
  oxford-soft: '#3A404F'
  oxford-muted: '#6B7280'
  brass: '#7F5B12'
  brass-hover: '#6E4C0E'
  brass-wash: '#EFE7D6'
  burgundy: '#7A2230'
  burgundy-wash: '#F3E2E4'
  stone: '#CFC7B6'
  forest: '#2F4A38'
typography:
  display-lg:
    fontFamily: Playfair Display
    fontSize: 48px
    fontWeight: '600'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-md:
    fontFamily: Playfair Display
    fontSize: 36px
    fontWeight: '600'
    lineHeight: 44px
    letterSpacing: -0.01em
  display-sm:
    fontFamily: Playfair Display
    fontSize: 30px
    fontWeight: '600'
    lineHeight: 38px
  headline-lg:
    fontFamily: Playfair Display
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Playfair Display
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Playfair Display
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  title-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
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
  gutter: 1.5rem
  gutter-sm: 1rem
  margin: 2rem
  margin-sm: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

# Ain Sohay (LegalLink) Design System

## Brand & Colors
- Parchment (Canvas): #F0EEE8
- Parchment Raised (Card surfaces, dialogs, sheets): #F7F5F1
- Parchment Sunken: #E7E4DC
- Oxford (Primary text, dark elements, brand): #1A1E28
- Oxford Soft: #3A404F
- Oxford Muted: #6B7280
- Brass (Primary buttons, active states, accents): #7F5B12
- Brass Hover: #6E4C0E
- Brass Wash: #EFE7D6
- Burgundy (SOS button, critical alerts, overdue outline): #7A2230
- Burgundy Wash: #F3E2E4
- Stone (Borders, dividers, rails): #CFC7B6
- Forest (Verified badge, accepted): #2F4A38

## Typography
- Display / Headings: 'Playfair Display', serif
- Body / UI: 'Inter', sans-serif
- Bengali: 'Noto Sans Bengali', sans-serif
- Numbers: Western digits always

## Component Patterns
- Sidebar: 240px wide, Parchment surface, Oxford items, Brass vertical active indicator, pinned Burgundy SOS item at bottom.
- Buttons: Brass primary button (#7F5B12), pill or md radius, 48dp min height.
- Cards: Parchment-raised (#F7F5F1) surface, 1px Stone border, rounded-2xl (16px).
- Legal Notice Card: 2px Oxford border with 4px Brass top rule.
- Badges: Forest (#2F4A38) for Verified, Brass-wash for active/chips, Burgundy outline for Overdue.
