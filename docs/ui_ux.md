# Ain Sohay (LegalLink) — UI/UX Design System & Product Design Specification

**Status:** Single source of truth for frontend (Flutter Web + Flutter Android).
**Audience:** Frontend developers, designers, QA, accessibility review.
**Companion docs:** `prd.md` (features F1–F8, AI rules), `trd.md` (architecture), `docs/database_schema.md` (the states this UI must render).

## 0. Brand Premise

Ain Sohay ("a plea for help") is a Bangladesh legal-tech platform. The interface reads as **two moods sharing one brand**:

| Mood | Where | Behaviour |
|---|---|---|
| **Composed** | Landing, onboarding, case timeline, invoices, summaries | Parchment canvas, Oxford serif headings, brass accents, generous whitespace |
| **Urgent** | SOS screen, SOS alert banners, critical alerts | Burgundy, tight rhythm, one dominant action, motion |

A user must never be *startled* by colour. The SOS screen is the single place Burgundy appears at full strength. Urgency is signalled by **scale, isolation and one-tap geometry**, not by red everywhere.

### Design principles (apply to every screen)

1. **Whitespace is the product.** Premium = space. Min 24 dp gutter, 40 dp between content blocks, 96–128 px between major web sections.
2. **One primary action per screen.** Exactly one Brass CTA; SOS screens have exactly one Burgundy CTA.
3. **Plain Bangla first.** Legal terms appear as `জামিন (Jail)`, never the reverse.
4. **Nothing is unlabelled.** Status = icon + text + badge, never colour alone (WCAG 1.4.1).
5. **Calm by default, urgent on purpose.** Urgency is a state, not a theme.
6. **State is always visible.** Offline, syncing, queued, AI-thinking, error — each has a designed visual (§4).
7. **Immutable history.** Hearing dates, published summaries and invoices are archival artefacts, never edited in place.

---

## 1. Design System Foundation

### 1.1 Colour tokens

Base canvas is Parchment. Only four hues are permitted in the product chrome; everything else is a tint/shade of these. Forest is reserved exclusively for the verified-advocate badge.

| Token | Hex | Role | Contrast (WCAG 2.1) |
|---|---|---|---|
| `parchment` | `#F0EEE8` | App/web page background, card surface, sheet background | 14.4:1 vs Oxford (AAA) |
| `parchment-raised` | `#F7F5F1` | Elevated surface: dialogs, sheets, hover | AAA vs Oxford |
| `parchment-sunken` | `#E7E4DC` | Inset wells, timeline trough, disabled fills | decorative only |
| `oxford` | `#1A1E28` | Primary text, dark bands, dark surface, iconography | 14.4:1 vs Parchment (AAA) |
| `oxford-soft` | `#3A404F` | Secondary text on Parchment | 8.9:1 (AAA) |
| `oxford-muted` | `#6B7280` | Timestamps, helper text, body size only | 4.6:1 (AA) |
| `brass` | `#7F5B12` | Primary buttons, active states, icons, links, focus ring | 5.3:1 vs Parchment (AA) |
| `brass-hover` | `#6E4C0E` | Button hover/pressed | 6.6:1 |
| `brass-wash` | `#EFE7D6` | Brass-tinted fill: selected row, chip bg, loading glow | Oxford on it = 13.1:1 |
| `burgundy` | `#7A2230` | **SOS button only**, critical alert borders, overdue outline | 8.6:1 vs Parchment (AAA) |
| `burgundy-hover` | `#631A26` | SOS pressed | 10.1:1 |
| `burgundy-wash` | `#F3E2E4` | SOS alert banner background | Oxford on it = 12.8:1 |
| `stone` | `#CFC7B6` | Dividers, rails, past events, illustration strokes | 9.9:1 vs Oxford (AAA) |
| `stone-text` | `#8A8271` | Archived/disabled labels, non-text ≥ 18 px bold | 3.6:1 — **never body copy** |
| `forest` | `#2F4A38` | **Verified badge only** (seal-check + text) | 8.4:1 (AAA) |

**Rules**
- Brass is the only colour allowed to be loud in a calm context. Burgundy is never decorative, never a hover state, never emphasis in body copy.
- Verified badge = forest fill + white check-seal glyph + text `যাচাইকৃত (Verified)`. It is rendered as real text in the accessibility tree; green is never the sole signal.

**Semantic status map** (used by every screen in this document)

| Status | Colour | Glyph | Label (Bangla / English) |
|---|---|---|---|
| Open / SOS live | `burgundy` | ● pulsing | `চলমান (Live)` |
| Accepted / verified | `forest` | ✓ | `গৃহীত (Accepted)` / `যাচাইকৃত (Verified)` |
| Upcoming / next hearing | `oxford` | ◆ | `পরবর্তী (Next)` |
| Completed / past | `stone` | ○ | `সম্পন্ন (Done)` |
| Adjourned | `stone` + struck-through old date | ↻ | `স্থগিত (Adjourned)` |
| Syncing | `brass` animated arc | ◐ | `সিংক হচ্ছে (Syncing)` |
| Offline / queued | `stone` dashed border | ⛌ | `অফলাইন (Offline)` |
| Overdue | `burgundy` outline only | ! | `বকেয়া (Overdue)` |

### 1.2 Typography

| Role | Family | Weights | Source |
|---|---|---|---|
| Display / headings | **Playfair Display** | 400–700 | Google Fonts |
| UI / body | **Inter** | 400–600 | Google Fonts |
| Bangla (all runs) | **Noto Sans Bengali** | 400–700 | Google Fonts / bundled |

**Fallback stacks (declare verbatim)**

```
--font-display: 'Playfair Display', 'Noto Serif Bengali', 'Times New Roman', serif;
--font-ui:      'Inter', 'Noto Sans Bengali', 'Segoe UI', system-ui, sans-serif;
--font-bangla:  'Noto Sans Bengali', 'SolaimanLipi', 'Kalpurush', 'Shonar Bangla', sans-serif;
```

`Shonar Bangla` is a high-collision legacy font, kept as final fallback for low-memory Android devices that cannot fetch Noto Sans Bengali. Bundle only Noto Sans Bengali (regular + bold) unless the APK budget (PRD §9, < 50 MB) allows more.

**Bangla typography rules**

- Bangla body copy: **16 sp minimum, 1.6 line-height.** Never 14 sp — conjuncts and matras collapse.
- `Noto Serif Bengali` is permitted only for headings ≥ 24 px.
- Bangla runs are **never** letter-spaced and **never** uppercased. The sample's uppercase display treatment does not apply to Bangla.
- Numbers, dates and money are **always Western digits**, even inside Bangla: `25 জুন 2026`, `5,000 টাকা`. Never `২৫ জুন ২০২৬`.
- Measure: 68ch Latin, ~38 Bangla characters.
- Legal-term pattern: `জামিন (Jail)`, `জামিন-আস্থার (Bail)`, `থানা (Thana)`.

**Type scale** (web px / mobile sp)

| Token | Size | Family | Weight | LH | Tracking | Use |
|---|---|---|---|---|---|---|
| `display-1` | 56 / 42 | Playfair | 500 | 1.05 | −0.02em | Landing hero (one per page) |
| `display-2` | 40 / 30 | Playfair | 500 | 1.10 | −0.01em | Dark band headline |
| `heading-1` | 32 / 24 | Playfair | 600 | 1.20 | 0 | Screen titles |
| `heading-2` | 24 / 20 | Playfair | 600 | 1.25 | 0 | Card / section titles |
| `heading-3` | 18 / 17 | Inter | 600 | 1.35 | 0 | List headers |
| `body-lg` | 16 / 16 | Inter | 400 | 1.60 | 0 | Primary body |
| `body` | 15 / 14 | Inter | 400 | 1.60 | 0 | Secondary body (Bangla floor 15/16) |
| `caption` | 13 / 12 | Inter | 500 | 1.45 | 0.01em | Timestamps, labels |
| `label` | 12 / 11 | Inter | 600 | 1.20 | 0.08em | Uppercase Latin labels only |
| `button` | 15 / 15 | Inter | 600 | 1.0 | 0.02em | Buttons |
| `numeric` | 28 / 24 | Playfair | 600 | 1.10 | −0.01em | Totals, countdown |

**Signature treatment:** the landing hero uses uppercase Playfair `display-1` with tight tracking on **Latin only**. Marketing-only; forbidden in-app.

### 1.3 Spacing, radii, elevation, motion

- Base unit **8**; steps 4, 8, 12, 16, 24, 32, 40, 48, 64, 96, 128.
- Section rhythm: web 128 px, mobile 40 px.
- Radii: `sm 4` (badges/chips), `md 8` (inputs, small cards), `lg 16` (cards, sheets), `xl 24` (dialogs), `pill 999` (ribbon, SOS).
- Shadows only where things genuinely float: `e1 0 1px 2px rgba(26,30,40,.06)` hover card; `e2 0 6px 24px rgba(26,30,40,.10)` sticky header / bottom sheet; `e3 0 18px 48px rgba(26,30,40,.16)` dialog; SOS `0 0 0 8px rgba(122,34,48,.14), 0 12px 32px rgba(122,34,48,.28)`.
- Motion: 160 ms state, 240 ms enter/exit, 320 ms sheet; easing `cubic-bezier(.2,.8,.2,1)`. `prefers-reduced-motion` disables the SOS pulse and all parallax.

### 1.4 Component library

#### 1.4.1 Buttons

| Variant | Look | Use |
|---|---|---|
| **Ribbon (primary, landing only)** | Brass fill, `pill` radius, **concave notched left/right ends** (CSS `clip-path` with 6 px inset triangles, matching the sample's ribbon), uppercase Inter 13/600 tracking .08em, padding 14×32. Hover: brass-hover + 2 px float. | Landing CTA "Get Started" / "Get Help Now" |
| **Primary (in-app)** | Brass fill, `md` radius, 48 dp min height, optional 20 px leading icon | "Continue", "Confirm" |
| **Secondary** | Transparent, 1.5 px brass border, brass label | "Cancel", "Back" |
| **Tertiary / link** | No chrome, brass label, 1 px brass underline on hover | "Learn more", "Request update" |
| **Ghost (on dark)** | Transparent, 1.5 px stone border, parchment label | Dark band CTA |
| **Danger** | burgundy fill — **SOS and invoice void only** | SOS |
| **Disabled** | `parchment-sunken` fill, stone border, `stone-text` label. Never opacity-only (kills contrast). | — |

Rules: min touch target **48×48 dp**; every button carries icon **and** text (PRD §9) except tertiary links, which must have descriptive text; focus ring = 2 px brass outline + 2 px offset, switching to parchment on dark.

#### 1.4.2 The SOS Button (distinct component)

Deliberately unlike every other control:

- Shape: **circular, 200 dp diameter** on mobile (148 dp on small phones); `pill` on web.
- Fill: `burgundy` with a soft radial gradient (lighter top-left) so it reads as physical.
- Ring: outer 12 px `burgundy` at 18% opacity that **breathes** (scale 1.0 → 1.04, 2.4 s ease-in-out infinite). Disabled under reduced motion.
- Content: siren/gavel glyph (56 dp, white) + two lines — `জরুরি সাহায্য` (Inter 22/700) over `SOS` (Playfair 14/600, tracking .2em).
- **Hold-to-confirm:** press and hold **600 ms** to arm (accidental activation is unacceptable when the phone is in a pocket during panic). A brass arc fills clockwise around the ring. Releasing early cancels with a 150 ms fade, no error toast.
- On arm: `HapticFeedback.mediumImpact()`, then the SOS capture sheet opens and a live timer starts.
- Exactly one SOS button exists in the app shell, as a persistent floating dock button.

#### 1.4.3 Cards

Surface `parchment-raised`, radius `lg`, border 1 px stone @ 60% (the border carries definition — the sample is flat), padding 20–24. Variants:

- **Case Card** — case number in Playfair `heading-3`, court + type in `body`, advocate row with forest verified badge, next-hearing date in a brass-wash footer strip.
- **Advocate Card** — 64 dp circular photo, name, specialization chips (brass-wash), courts served, fee range always visible (anti-dalal transparency), verified badge.
- **Invoice Card** — tabular figures, status badge top-right, number `INV-2026-0042` in letterspaced `caption`.

Interactive cards get `e1` + 1 px brass border on hover/focus.

#### 1.4.4 Inputs

Height 52 dp, radius `md`, 1.5 px stone border, parchment fill, label floating above in `caption`, turning `brass` on focus. Focus: brass border + 3 px brass-wash halo. Error: burgundy border + ⚠ message in `body` beneath.

**The phone input is the hero of onboarding**: `+880` prefix as a static brass-wash chip outside the field; 6 OTP boxes (56 dp, `md` radius) that auto-advance, support paste, and show a brass check when complete. Resend link disabled 30 s with a visible countdown — no silent failure.

Every input offers a voice-input mic affordance (PRD §9), with Bangla dictation via the platform keyboard.

#### 1.4.5 Shared components

| Component | Spec |
|---|---|
| **Chip** | `sm` radius pill, `brass-wash` fill, Oxford 13/600 label. Case type, specialization, urgency. |
| **Badge** | Status map §1.1; always glyph + text |
| **Verified badge** | Forest, seal-check glyph, `যাচাইকৃত (Verified)` |
| **AI disclaimer bar** | Stone-tinted strip, 12/500, permanently visible on AI output (PRD §8.4) |
| **Sync indicator** | Fixed chip; states in §4.3 |
| **Empty state** | Stone-line illustration + Playfair `heading-2` + one sentence + one Brass CTA |
| **Toast** | Bottom, `oxford` fill / parchment text, radius `md`, auto-dismiss 4 s. Never for errors that need action. |
| **Sheet** | `parchment-raised`, top radius `xl`, drag handle, max 85% height, `e2` |
| **Bottom nav (mobile)** | Parchment; Oxford active icon with a 2 dp brass indicator bar above the label; centre slot is the SOS dock (§3.1) |
| **Sidebar (web ≥ 1024 px)** | 240 px, parchment, Oxford items, brass active pill; SOS item pinned at the bottom in burgundy |
| **Countdown** | Playfair `numeric` on parchment; used for the SOS live timer |

### 1.5 Accessibility contract

- Target **WCAG 2.1 AA**. Oxford/Parchment and every status pair are already AAA — do not regress them by tinting.
- Contrast floor 4.5:1 for text < 18 px, 3:1 for large text and UI borders. Brass at 5.3:1 is safe as text on parchment. `stone-text` is never body copy.
- Bangla strings live in `localizations/bn.json`; never concatenate translated fragments.
- Screen-reader labels on every graphic; each timeline node announces `"{date}, {title}, {status}"`.
- High-contrast mode: parchment → `#FFFFFF`, stone borders → `#1A1E28`, brass/burgundy unchanged.
- Full keyboard traversal on web with a visible focus ring everywhere, plus a skip-to-content link.
- `aria-live="polite"` region announces sync state changes and newly published advocate updates.

---

## 2. Web Landing Page (the "Floristy" adaptation)

### 2.1 Structural mapping from the reference

| Reference element | Ain Sohay equivalent |
|---|---|
| Bronze Lady Justice statue | 3D render of the **Barrister Tabs** app icon, or a stylised brass balance scale |
| Floating side labels + arrow | Floating label chips pinned to the hero object |
| Parchment canvas | `parchment` `#F0EEE8` |
| Full-width dark benefits band | Oxford `#1A1E28` "Why Choose Ain Sohay?" |
| "GET STARTED" notched ribbon | Brass ribbon "Get Help Now" |
| 3-column service row | Business / Criminal / Family Law |
| Gavel + oversized watermark word | Watermark `LAW` at 6% Oxford, behind the hero |
| Circular "watch video" badge | Rotating brass seal: `যাচাইকৃত উকিল • VERIFIED ADVOCATE •` around a ▶ glyph |
| Play/pause media control | The same seal, reused as the app-store / reel launcher |

Layout container: max-width **1200 px**, 24 px gutters, 12-column grid, 128 px between sections. Breakpoints: `sm < 600`, `md 600–1023`, `lg ≥ 1024`. Below 600 px the layout is the mobile layout with bottom nav (PRD §6 F8).

### 2.2 Section-by-section

**(a) Header — sticky, parchment, 88 px**
Wordmark `AIN SOHAY` in Playfair 22/600, Oxford, left. Right: `হোম`, `সেবা`, `কেন আমরা`, `যোগাযোগ` as Inter 13/600 `label` items, then the brass ribbon `GET STARTED`. After 40 px of scroll the header gains `e2` and a 1 px stone bottom border; its colour never changes.

**(b) Hero — min-height 88 vh, centred**
1. Playfair `display-1`, Oxford, uppercase, two lines: **"HIGH QUALITY LEGAL ACCESS"**. Bangla sub-line beneath in Noto Sans Bengali 20/500, sentence case: `মুহূর্তে যাচাইকৃত আইনজীবী, সহজ ভাষায় আইনি সহায়তা।`
2. Hero object: high-quality 3D render of the **Barrister Tabs** app icon (two brass tabs over a parchment shield, soft contact shadow), max height 480 px / 360 px mobile, inside a 1 px stone outline frame offset 24 px — echoing the reference's ruled frame.
3. Floating label 1 — left of the object with a downward arrow above the text (reference behaviour): `24/7 Emergency SOS / জরুরি সাহায্য ২৪/৭`.
4. Floating label 2 — right of the object: `Verified Advocates / যাচাইকৃত উকিলবিদ`.
   Both labels: Inter 14/600 Oxford with a `brass` arrow, tied to the object by a 1 px stone hairline. On mobile they stack beneath the object as two brass-wash chips. Animate in on scroll (fade + 12 px rise, 240 ms, staggered 120 ms); disabled under reduced motion.
5. Watermark: `LAW` in Playfair 320 px at 6% Oxford opacity, `z-index: 0`, clipped by the section edge.
6. Rotating seal, bottom-right: circular text `যাচাইকৃত উকিল • VERIFIED ADVOCATE •` around a ▶ glyph, 24 s linear infinite rotation, brass.
7. CTA: brass ribbon **"Get Help Now / এখনই সাহায্য নিন"** with a 1 px brass outer glow ring. Ghost CTA beneath: "Browse Services".
8. Small print: `এটি সাধারণ তথ্য, আইনি পরামর্শ নয়। · General information, not legal advice.` in `caption`.

**(c) "The Area Where We Practise Law" — intro band, centred, single column**
Playfair `heading-1` "THE AREA WHERE WE PRACTISE LAW" with a 64 px brass hairline divider, then one Bangla paragraph in `body-lg`, max 640 px, centred.

**(d) Services — 3-column grid, 48 px gap**
Column: 48 px brass line-icon inside a 56 px stone circle, Playfair `heading-3` title, `body` description (max 34ch).
- **Business Law / ব্যবসায়িক আইন** — corporate structuring, contracts, compliance.
- **Criminal Law / ফৌজদারি আইন** — bail, arrest assistance, criminal defence.
- **Family Law / পারিবারিক আইন** — divorce, custody, family disputes.

Below the grid, a full-width `brass-wash` strip card: `জামিন-আস্থার (Bail) · জমি ও সম্পত্তি (Property) · নারী ও শিশু (Women & Child) · শ্রম আইন (Labor)` — this makes all six PRD F2 specializations reachable. Hover: card lifts 2 px, icon becomes brass-filled.

**(e) Meet Our Most Talented and Qualified Attorneys**
Left column: Playfair `heading-2` "LEAD COUNSEL, VERIFIED ATTORNEYS" + Bangla body + brass underlined link `যাচাইকৃত উকিল দেখুন`.
Right: an advocate photograph masked with a torn-paper top edge (the reference device) and three floating **circular status badges** in a staggered arc — `100% Verified`, `12 yrs Experience`, `24/7 SOS` — echoing the reference's `50%` circles.
Below: advocate card row (horizontal scroll on mobile, 3-column grid on web). Each card carries the forest verified badge, courts served and the fee range.

**(f) Dark band — full-bleed Oxford `#1A1E28`, 128 px padding**
Solid Oxford with a 4% parchment engraved-scales watermark at the right edge.
- Left: Playfair `display-2` in Parchment — "Why Choose Ain Sohay? / কেন আইন সোহায়?"; body copy in parchment at 90% opacity, max 46ch: "We provide high-quality legal service for those in need."; ghost CTA on dark `আমাদের সুবিধা (Platform)` with a brass underline.
- Centre: photograph of a lawyer using the phone, masked with torn-paper top and bottom edges (exactly the reference device), `e3` shadow.
- Right: three benefit blocks separated by 1 px `rgba(240,238,232,.16)` rules:
  1. **Legal representation / আইনি প্রতিনিধিত্ব** — Bar Council verified advocates with real case numbers.
  2. **Alerts / অ্যালার্ট** — instant SOS alerts to nearby verified advocates.
  3. **Support / সহায়তা** — plain-Bangla AI summaries, 24/7.

**(g) "Want a Lawyer?" — contact band, centred, parchment**
Playfair `display-2` "WANT A LAWYER?" → hairline arrow → "LET'S TALK". Outlined `CONTACT US` button, then the address in Playfair `heading-1` uppercase: `HELLO@AINSOHAY.COM`.

**(h) Footer — parchment, 1 px stone top border, 64 px padding**
Wordmark, one-line mission statement, three columns (Services / Company / Legal — including `গোপনীয়তা (Privacy)` and `শর্তাবলি (Terms)`), and a contact block: `+880 1700 000000`, `hello@ainsohay.com`, `ঢাকা, বাংলাদেশ`. Bottom rule: `© 2026 Ain Sohay (LegalLink)` with the Bangla sub-line `সর্বস্বত্ব সংরক্ষিত।`

---

## 3. Mobile App UI (Flutter)

The app keeps the "premium legal" aesthetic but is optimized for **mobile urgency**: 48 dp targets, thumb-zone controls, and a permanently reachable SOS dock.

### 3.1 App shell

- **Mobile (< 600 px):** top app bar 64 px, parchment, `heading-2` title, Oxford. Bottom navigation, 5 slots, 72 px + 16 px safe-area inset: `হোম (Home)` · `মামলা (Cases)` · **SOS dock (centre)** · `ডকুমেন্ট (Documents)` · `প্রোফাইল (Profile)`. Active slot: Oxford icon with a 2 dp brass indicator bar above the 11 px label. The centre slot is visually detached — a 64 dp burgundy circle breaking 10 px above the bar so it reads as the emergency control.
- **Web (≥ 1024 px):** 240 px left sidebar, parchment, Oxford items with a brass active pill; the SOS item pinned at the bottom in burgundy.

### 3.2 Onboarding (PRD F1)

Full-screen parchment, single column, max 440 px, centred, 40 px vertical rhythm.

1. **Logo screen** — Barrister Tabs mark 96 dp, wordmark `AIN SOHAY` in Playfair `heading-1`, tagline `জরুরি আইনি সহায়তা` in `caption`. Single Brass CTA `শুরু করুন (Get Started)`, tertiary link `ইতিমধ্যে অ্যাকাউন্ট আছে? · Sign in`.
2. **Language** — two 56 dp selectable cards (বাংলা / English) with a brass border when selected. Bangla preselected.
3. **Phone** — `heading-1` `আপনার নম্বর দিন (Enter your number)`. `+880` brass-wash prefix chip + 10-digit field, numeric keypad, Brass CTA `পরবর্তী (Next)`.
4. **OTP** — six 56 dp boxes, header `আমরা একটি কোড পাঠিয়েছি (We sent a code)`. `আবার পাঠান` unlocks after 30 s; max 3 attempts per 5 minutes, then `ইমেইল কোড চেষ্টা করুন · Contact support` appears (PRD F1).
5. **Role** — client vs advocate. Client is preselected and visually dominant; the advocate card carries `উকিল হিসেবে এগোন (I'm an advocate)` in `caption`.
6. **Advocate extras (conditional)** — name, NID, Bar Council number, Sanad photo upload, courts, specializations, fee range, languages, and the **4-digit summary-approval PIN** (masked dots, brass strength meter, confirmation field) with the explainer `এই পিন দিয়ে আপনার ক্লায়েন্টের জন্য সারাংশ প্রকাশ করবেন।`
7. **Permissions** — notifications (required for SOS) and location (optional, for nearby advocates), each with a "why" line before the system prompt.

Every screen has a back affordance and progress dots (1/6 … 6/6); onboarding never dead-ends.

### 3.3 The SOS screen (critical)

The one screen where the calm aesthetic is deliberately broken.

**Layout (top to bottom)**
1. Parchment canvas, no cards, no imagery — maximum visual quiet so the single control dominates.
2. `heading-1` `জরুরি সাহায্য (Emergency SOS)` and one line: `একটি বাটনে কাছের যাচাইকৃত উকিলকে জানান।`
3. **The SOS button**, centred, 200 dp (148 dp on small phones): circular burgundy with a breathing 12 px ring, siren glyph, `জরুরি সাহায্য / SOS`. Hold 600 ms to arm — a brass arc sweeps clockwise around the ring; early release cancels silently.
4. Below it, a thin secondary link in burgundy-outline pill form: `অফিসিয়াল ১০৯ নম্বরে কল করুন (Call 109)` — the government emergency line stays one tap away and is **not** styled as a primary button.
5. `caption` reassurance: `আপনার নাম ও ঠিকানা শুধু যাচাইকৃত উকিলরা দেখতে পাবেন।`

**One-tap flow after arming**
1. Sheet slides up (320 ms): burgundy header `SOS শুরু হয়েছে`, live timer in Playfair `numeric`, pulsing `status: live` dot.
2. **Minimal capture — 4 required fields max**, 48 dp each, generous spacing, numeric-friendly: arrested person's name · Thana (থানা) · District/Court · contact number. Optional extras collapsed under `বিস্তারিত (Details)`: charges, arrest time, NID, urgency. Pre-fill the contact number from the profile; pre-select district from location behind a clearable `অবস্থান অনুযায়ী (From your location)` chip.
3. One Brass CTA pinned at the sheet bottom: `পাঠান (Broadcast to advocates)`. Above it, `caption`: `আপনার থানার 12 জন যাচাইকৃত উকিলকে জানানো হবে।`
4. On send: haptic + the sheet collapses into a full-screen **Broadcasting** state — a brass arc circling a burgundy SOS glyph, the live advocate count ticking up (`3 জন উকিল জানেছেন`), and a `Cancel SOS` tertiary link. No generic spinner (§4.2).
5. **Accepted** (≤ 15 min target, PRD F3): burgundy-wash full-screen card, 72 dp advocate photo, name, forest verified badge, phone, courts; Brass CTA `কল করুন (Call)`, secondary `অ্যাপে চ্যাট (Chat)`. A toast confirms `উকিল গ্রহণ করেছেন।` and the case auto-creates.
6. **Timeout** (no accept in 24 h, PRD F3): parchment screen, `সময় শেষ (Expired)` in stone, explanation, Brass CTA `সম্পাদনা করে আবার পাঠান (Edit and repost)`, plus `উকিল খুঁজুন (Browse advocates)`.
7. **Offline send:** the SOS is queued locally and shows `⛌ অফলাইন — পাঠানোর অপেক্ষায় (queued)`. The UI never claims a broadcast that has not left the device. Sending also surfaces the 109 call prompt.

**Advocate-side SOS alert**: full-screen burgundy-wash alert, burgundy header `জরুরি SOS · {Thana}`, arrest details in Oxford, distance `2.4 কিমি`, then two stacked buttons — Brass `গ্রহণ করুন (Accept)` and Secondary `পারবেন না (Decline)`. The first accept locks the SOS (PRD F3); a losing advocate sees `এই SOS ইতিমধ্যে গৃহীত হয়েছে` with no action.

### 3.4 Home dashboard

- Greeting row: `শুভ সকাল, [নাম]` in Playfair `heading-2`, with a language toggle chip on the right.
- **Situation banner** (PRD F5): a `brass-wash` card, radius `lg`, showing the latest outcome in one Bangla line plus the next hearing date in Playfair `numeric` with a brass ◆ `পরবর্তী (Next)` badge. Tap opens the timeline.
- Case list: Case Cards (§1.4.3), single column, 16 px gap.
- A right-aligned `নতুন মামলা (New case)` Brass button sits below the banner, never hidden in an app-bar ellipsis.
- The `⛌ অফলাইন` chip appears only when offline (§4.3).

### 3.5 Case timeline (PRD F5)

A **vertical timeline** on parchment: a row + 24 px gutter + a 2 px stone rail. No heavy third-party widget.

**Anatomy per node**
- A 12 dp node dot on the rail: past = stone filled ○, active = Oxford filled ◆ with a 4 px brass halo, future = stone hollow.
- Date in `caption`, coloured per the status map; a state chip sits beside it.
- Title in `heading-3` (Inter 600, Oxford).
- Detail in `body` (Bangla ≥ 16 sp), max 62ch.
- Optional brass-wash footer strip: `পরবর্তী শুনানি (Next hearing): 25 জুন 2026`.

**Distinguishing "Hearing Adjourned" from "Next Date"**

| Situation | Visual treatment |
|---|---|
| **Completed hearing (past)** | Stone dot, stone date, Oxford title `শুনানি সম্পন্ন (Hearing completed)`. Visually recedes. |
| **Adjourned (স্থগিত)** | Stone dot with a ↻ glyph; the **original date is struck through** in stone (`10 জুন 2026`), then an Oxford arrow and the new date in `heading-3`: `10 জুন → 25 জুন 2026`. A `স্থগিত (Adjourned)` chip is mandatory so it is never read as a cancellation. |
| **Rescheduled** | Its own logged event: `Hearing rescheduled from X to Y` (PRD F5), so an old date never silently disappears. |
| **Next date (future)** | Oxford filled ◆ dot with brass halo, Oxford date (never stone), `পরবর্তী (Next)` chip. The only visually loud node. |
| **Amendment** | `সংশোধিত (Amended)` chip in brass beside the title + `আগের সংস্করণ দেখুন (View previous version)` to the immutable prior record (PRD F5). |

Header above the timeline: `case_number` in Playfair `heading-2`, court + case type as chips, then the advocate row with verified badge and a `আপডেট চান (Request update)` tertiary link (max 1 per 24 h, PRD F6).

Edge states (PRD F5): no hearings yet → `আপনার মামলা শুরু হয়েছে। প্রথম শুনানির তারিখ এখানে দেখা যাবে।` plus a subtle stone-line illustration; closed cases move to an `আর্কাইভ (Archive)` section after 90 days, read-only with a `stone-text` label.

### 3.6 AI summary view — the "Legal Notice" card (PRD F6)

Clients only ever see `published` summaries; drafts are invisible by RLS (PRD F6).

- Card: `parchment-raised`, radius `lg`, a **2 px Oxford border** (heavier than other cards, so it reads as an official document) and a 4 px brass top rule.
- Header block, centred, split by a 1 px stone rule: small brass gavel glyph, Playfair `heading-2` `আইনি বিজ্ঞপ্তি (Legal Notice)`, then `caption` with case number, court, hearing date. A `burgundy-wash` `চূড়ান্ত (Final)` tag — or `প্রকাশকারী কর্মকর্তা দ্বারা প্রকাশিত (Published by platform staff)` when the admin override was used (PRD F6) — sits in the corner.
- Body: the plain-Bangla summary in `body-lg` (Inter 16 / 1.7), legal terms in brackets, limited to three sections: **যা হয়েছে (What happened)**, **পরবর্তী পদক্ষেপ (Next steps)**, and a brass-wash strip with the next hearing date.
- Footer rule, then `প্রকাশকারী আইনজীবী` + advocate name, forest verified badge, and a `timestamp` in `caption`.
- A permanent disclaimer bar at the card's bottom edge: `এটি সাধারণ তথ্য, আইনি পরামর্শ নয়।` (PRD §8.4 rule 1).
- Optional `Share / Download PDF` tertiary link → signed 15-minute URL (PRD F6/F7).

**Advocate-side authoring (never client-visible):** raw notes in a large text area with voice dictation → brass pulse while the AI drafts (§4.2) → an editable draft with `সম্পাদনা (Edit)` → **PIN publish**: a 4-digit PIN dialog, brass check on success, 5 failures → 30-minute lockout notice (PRD F6).

### 3.7 Document checklist (PRD F4)

- Header chip until advocate approval (PRD F3): `প্রস্তাবিত — আপনার উকিল শীঘ্রই নিশ্চিত করবেন (Suggested — your lawyer will confirm shortly)`.
- Grouped by importance, each group a Playfair `heading-3` header over a stone rule: `অত্যন্ত প্রয়োজনীয় (Critical)` / `প্রয়োজনীয় (Required)` / `বিকল্প (Optional)`.
- Item row: 48 dp checkbox (stone outline; brass fill + white ✓ when done), Bangla document name in `body`, a `caption` line with the purpose, and an `↑ আপলোড (Upload)` button. Uploads show a brass progress bar and, while pending, the row reads `আপলোড হচ্ছে — শুধু এই ডিভাইসে দেখা যাচ্ছে`.
- After advocate approval the chip flips to forest `✓ উকিল অনুমোদিত (Approved by your lawyer)`.
- With no assigned advocate, a `burgundy-wash` warning shows: `এটি একটি সাধারণ তালিকা। অনুগ্রহ করে একজন যাচাইকৃত উকিলের সাথে যোগাযোগ করুন।` (PRD F4).
- A reminder chip appears when a critical document is still missing before the next hearing (PRD F4).

### 3.8 Advocate search & profile (PRD F2)

- Search bar (52 dp) + district/court filter chips in a horizontally scrolling brass-wash row.
- Advocate Cards always show: photo, name, forest verified badge, years of practice, specialization chips, courts served, languages, and the **fee range** — the anti-dalal transparency promise.
- **No win-rate rankings anywhere** (PRD F2). Ranking is explained neutrally: `মামলার ধরন ও আদালতের সঙ্গে মিল · Matched by case type & court`.
- Profile detail page ends in a sticky Brass CTA `যোগাযোগ করুন (Contact)`.

### 3.9 Invoices (PRD F7)

- List grouped by case. Invoice Card: number `INV-2026-0042`, issue date, status badge, total in Playfair `numeric`.
- Detail renders as a **formal invoice sheet**: letterhead rule, advocate name + Bar Council number, client, case link, then line items in a tabular list (description left, amount right, tabular figures), subtotal, `15% ভ্যাট (VAT)`, and the total in Playfair `numeric` 28 px above a 2 px brass rule.
- Payment history: date, method chip (bKash / Nagad / Cash / Bank), transaction ID in `caption`, amount.
- Status is text + badge only: `sent`; `partially_paid` (`আংশিক পরিশোধিত` + a brass progress bar); `paid`; `overdue` (burgundy outline + 3/7/14-day reminder schedule); `void` (stone, struck through, number retained — PRD F7).
- Clients are read-only except paying/marking; advocates get `নতুন ইনভয়েস (New invoice)` as the single Brass CTA.

### 3.10 Advocate & Admin shells (brief)

- **Advocate dashboard:** SOS alert badge (burgundy count) · today's hearings · `নতুন শুনানির নোট লিখুন` quick-entry (voice-first) · pending checklist approvals (`অনুমোদনের অপেক্ষায়`, brass count) · invoices due.
- **Admin console:** informational weight, not urgency. Cards for `অপেক্ষমাণ যাচাইকরণ (Pending verifications)` with the 48 h SLA clock (PRD F2), `AI নিরাপত্তা পর্যালোচনা (AI safety review)` for flagged summaries, and complaints. Admin screens are Oxford-on-parchment dense tables — deliberately *not* the marketing aesthetic.

---

## 4. UX Flows & States

### 4.1 Empty states

The rule: **illustration in Stone, headline in Playfair, one sentence, one Brass CTA.** Never a bare grey box, never a shrug emoji.

| Screen | Illustration (single-weight Stone line art, 160 dp) | Headline | Body | CTA |
|---|---|---|---|---|
| Home, no cases | Empty brass balance scale, tilted | `এখনো কোনো মামলা নেই` (No cases yet) | `জরুরি অবস্থায় SOS চাপুন, অথবা একজন উকিলকে খুঁজুন।` | `একজন উকিল খুঁজুন (Find an advocate)` |
| Timeline, no hearings | Stone calendar with one blank page | `আপনার মামলা শুরু হয়েছে` (Your case has started) | `প্রথম শুনানির তারিখ এখানে দেখা যাবে।` (PRD F5 exact copy) | none — passive state |
| Checklist, none | Closed stone folder | `এখনো কোনো নথির তালিকা নেই` | `উকিল নিয়োগের পর এটি তৈরি হবে।` | `উকিল খুঁজুন` |
| Search, no advocates | Stone gavel lying flat | `কোনো উকিল পাওয়া যায়নি` | `ফিল্টার কমিয়ে আবার চেষ্টা করুন, অথবা জরুরি SOS পাঠান।` | `ফিল্টার পরিষ্কার করুন (Clear filters)` |
| Invoices, none | Stone receipt outline | `কোনো ইনভয়েস নেই` | `আপনার উকিল ইনভয়েস এখানে যোগ করবেন।` | — |
| Summary, none yet | Sealed stone envelope, unopened | `এখনো কোনো সারাংশ প্রকাশিত হয়নি` | `আপনার উকিল শুনানির নোট লিখে প্রকাশ করলে এখানে দেখা যাবে।` (PRD F6 draft-expiry copy) | `আপডেট চান (Request update)` |

Illustration rules: single weight 2 px Stone strokes, no fill, no shadow, no colour other than Stone plus a single Brass accent dot on the focal element. A one-time 240 ms draw-in is disabled under reduced motion.

### 4.2 Loading states

**No generic circular spinners anywhere.** Each context gets its own metaphor, built from Brass and Stone.

| Context | Loading visual |
|---|---|
| **AI thinking** (summary, triage, chatbot) | A **brass pulse**: a 40 dp brass ring that breathes (scale 1.0 → 1.06, opacity .45 → 1, 1.6 s ease-in-out infinite) around a small brass gavel glyph, with `বিশ্লেষণ করা হচ্ছে… (Thinking…)` in `caption` below. On the legal-notice card the brass top rule animates its brightness instead, so the card does not jump. |
| **Page / list fetch** | **Skeleton in Parchment**: 3–4 rounded Stone-tinted blocks (`parchment-sunken`) with a slow 1.8 s brass-to-stone shimmer sweep at 12% opacity. Skeletons mirror the real card layout exactly (the advocate skeleton includes the circular photo placeholder). |
| **SOS broadcast** | A brass arc rotating around the burgundy SOS glyph plus the live advocate counter (§3.3). |
| **Uploads** | A brass linear progress bar (2 dp) under the item name; the row never moves. |
| **Button submit** | The label is replaced in place by a brass arc inside the same button footprint — the button never resizes. |
| **PIN publish** | A brass ring around the PIN dialog. |
| **Full-screen wait > 5 s** | Add `একটু সময় লাগছে… (This is taking longer)` in `caption`; after 15 s offer `বাতিল করুন (Cancel)`. |

Reduced-motion variants: the pulse becomes a static 40% brass ring, the shimmer a static `parchment-sunken`, the arcs a static brass ring plus `কাজ হচ্ছে…`. **Status is never communicated by motion alone** — text is always present.

### 4.3 Offline & sync (PRD F8)

Offline is a *first-class court-basement state*, not an error.

- **Offline chip** — fixed just under the app bar, full width, `parchment` fill, 1 px dashed `stone` border, `⛌` glyph + `অফলাইন — কোর্টে সংযোগ নেই (Offline — no connection)` in `caption`. Calm, never burgundy: offline is a fact, not an error.
- **Read flows stay full.** Timeline, checklists, invoices and documents render from the Hive cache with `শেষ আপডেট 2 মিনিট আগে (Last updated 2 min ago)` in `stone-text`.
- **Writes queue silently** and show `N পরিবর্তন অপেক্ষায় (N changes waiting)`.
- **Per-item pending marker** — any locally created item shows a dashed-stone `অপেক্ষায় (Queued)` chip. Files show `আপলোড হচ্ছে — শুধু এই ডিভাইসে (Uploading — this device only)`.
- **Sync indicator** (persistent, per PRD F8), bottom-left above the nav:
  - `⛌ অফলাইন (N pending)` — stone, dashed.
  - `◐ সিংক হচ্ছে… (Syncing)` — brass arc, animated.
  - `✓ সব সংরক্ষিত (All changes saved)` — stone, fades after 3 s, announced via the polite live region.
- **Queue limits** (PRD F8): at 50 queued ops a `brass-wash` inline banner `সংযোগ দুর্বল — পরিবর্তনগুলো পরে সিংক হবে।`; at 100, writes block behind a `burgundy-wash` banner `অপেক্ষারতার সীমা পূর্ণ। সংযোগ ফিরে আসলে আবার চেষ্টা করুন।`
- **Conflicts** (version-based optimistic locking, PRD F8): a brass-outlined dialog titled `পরিবর্তনের সংঘর্ষ (Conflict)`, a plain Bangla explanation of which side is newer, and two explicit buttons — `আমার সংস্করণ রাখুন (Keep mine)` / `তাদের সংস্করণ নিন (Use theirs)`. Never a silent overwrite.
- **Consent rule surfaced in UI:** after a revocation, any pending advocate write fails and the client sees `আপনার সম্মতি প্রত্যাহার করা হয়েছে; উকিলের এই আপডেট আর যোগ হবে না।` (PRD F8).
- **Offline SOS** is never silently dropped — queued with a clear `queued` banner and an explicit nudge to call 109.

### 4.4 Error, conflict & destructive states

| Case | Treatment |
|---|---|
| Validation error | Inline, burgundy border + ⚠ + Bangla message under the field; focus moves to the first error |
| Network error on read | Stone-line empty state + `কাজ করছে না (Something went wrong)` + Brass `আবার চেষ্টা করুন (Retry)`; cached content stays visible beneath a `stone-text` staleness note |
| 403 / RLS denial | Neutral Oxford sheet: `এই তথ্য দেখার অনুমতি আপনার নেই।` + `সহায়তায় যোগাযোগ করুন` — never a raw error code |
| Rate limit (SOS/OTP) | Brass-wash banner with the real countdown, not a toast |
| Destructive action (invoice void, case close, consent revoke) | Confirm dialog: Playfair `heading-3` title, the consequence stated in Bangla, destructive button in burgundy **with a text label** (never icon-only), plus `অপরিবর্তনীয় (This cannot be undone)` where true |

### 4.5 Notifications & reminders

- Hearing reminders use a `brass-wash` in-app card + system push; lead time is user-configurable (PRD F5).
- A published summary pushes as `নতুন আইনি বিজ্ঞপ্তি প্রকাশিত হয়েছে`.
- A notification must never leak case data on a locked screen — generic text plus deep link only.
- Per-event notification settings live in Profile, with SOS and hearing alerts locked **on** (safety features).

---

## 5. Frontend Implementation Checklist

- [ ] All colours come from the §1.1 token set; no ad-hoc hex (enforce with a lint rule).
- [ ] Playfair Display, Inter and Noto Sans Bengali loaded; §1.2 fallback stacks declared.
- [ ] Bangla runs: no letter-spacing, no uppercase, Western digits, ≥ 16 sp body.
- [ ] Every button ≥ 48×48 dp with icon + text; visible focus ring on web; skip-to-content link.
- [ ] Contrast verified: Oxford/Parchment 14.4:1, brass 5.3:1, burgundy 8.6:1, forest 8.4:1.
- [ ] SOS button: 600 ms hold-to-arm, breathing ring, reduced-motion fallback, exactly one instance in the shell.
- [ ] Every state in §4 implemented; zero generic circular spinners.
- [ ] Published vs draft summaries separated by RLS *and* UI; drafts never rendered client-side.
- [ ] Timeline renders past/adjourned/next/amended exactly as §3.5 — Stone for past, Oxford for active.
- [ ] AI disclaimer bar present on every AI surface (PRD §8.4).
- [ ] Offline/queued/syncing indicator implemented with the PRD F8 queue limits (50 / 100).
- [ ] No win-rate ranking, dalal referral or public fee bidding anywhere in search (§3.8).
