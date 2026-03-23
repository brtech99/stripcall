# Stripcall — Design Specification
**Version 1.0 · March 2026**

Covers iOS/Cupertino and Android/Material Design 3 variants. All screens support light and dark mode.

---

## 1. Platform targets

| Platform | Design language | Min OS |
|---|---|---|
| iOS | Apple HIG / Cupertino | iOS 16 |
| Android | Material Design 3 | Android 12 |
| Web | Material Design 3 (same as Android) | — |

---

## 2. Color tokens

### 2a. iOS / Cupertino

| Token | Light | Dark | Usage |
|---|---|---|---|
| `background` | `#F2F2F7` | `#000000` | Page background |
| `surface` | `#FFFFFF` | `#1C1C1E` | Cards, nav bars, grouped rows |
| `text-primary` | `#000000` | `#FFFFFF` | Body copy, labels |
| `text-secondary` | `#6D6D72` | `#8E8E93` | Captions, helper text, timestamps |
| `separator` | `#C6C6C8` | `#38383A` | Hairline dividers (0.5 pt) |
| `blue` | `#007AFF` | `#007AFF` | Primary action, links, active tint |
| `green` | `#34C759` | `#34C759` | Resolved state, success, toggles ON |
| `orange` | `#FF9500` | `#FF9500` | Responded/in-progress state |
| `red` | `#FF3B30` | `#FF3B30` | Reported/new problem state, destructive |
| `purple` | `#5856D6` | `#5856D6` | Accent (Privacy, Haptics icons) |
| `search-bg` | `#E5E5EA` | `#1C1C1E` | Search bar fill |

### 2b. Android / Material Design 3

Seed color: **Purple `#6750A4`** · Tonal palette generated via Material Theme Builder.

| Token (MD3 name) | Light | Dark | Usage |
|---|---|---|---|
| `md-sys-color-primary` | `#6750A4` | `#D0BCFF` | Buttons, active chips, links |
| `md-sys-color-on-primary` | `#FFFFFF` | `#381E72` | Text on primary |
| `md-sys-color-surface` | `#FFFBFE` | `#1C1B1F` | Page background |
| `md-sys-color-surface-container` | `#ECE6F0` | `#211F26` | Top app bar, status bar |
| `md-sys-color-surface-container-high` | `#E7E0EC` | `#2B2930` | Cards, list items |
| `md-sys-color-on-surface` | `#1C1B1F` | `#E6E1E5` | Body text |
| `md-sys-color-on-surface-variant` | `#49454F` | `#CAC4D0` | Secondary text, captions |
| `md-sys-color-outline` | `#79747E` | `#938F99` | Input borders, dividers |
| `md-sys-color-secondary-container` | `#E8DEF8` | `#4A4458` | Selected chip fill |
| `md-sys-color-error` | `#B3261E` | `#F2B8B5` | Destructive actions |

**Problem-state colors (both platforms)**

| State | Color | iOS token | MD3 |
|---|---|---|---|
| Reported (new) | Red | `#FF3B30` | `#B3261E` |
| Responded (in progress) | Orange | `#FF9500` | `#E8650A` |
| Resolved | Green | `#34C759` | `#386A20` |

Role badge colors (consistent across platforms):

| Role | Foreground | Background (light) |
|---|---|---|
| Armorer | `#FF9500` | `#FF9500` at 13% opacity |
| Medical | `#FF3B30` / `#B3261E` | `#F9DEDC` |
| Event Mgmt | `#34C759` / `#386A20` | `#E9F5E1` |

---

## 3. Typography

### iOS — SF Pro
| Style | Size | Weight | Usage |
|---|---|---|---|
| Large Title | 34pt | Bold | Not used (no large nav title screens) |
| Title 1 | 22pt | Bold | Screen headers (in-content only) |
| Headline | 17pt | Semibold | Nav bar title, group headers |
| Body | 17pt | Regular | Form inputs, card primary text |
| Callout | 16pt | Regular | Card body text, row labels |
| Subhead | 15pt | Regular | Secondary info, links |
| Footnote | 13pt | Regular | Captions, metadata, timestamps |
| Caption 1 | 12pt | Regular | Section headers (all-caps + 0.4pt spacing) |
| Caption 2 | 11pt | Regular | Badge labels |

### Android — Google Sans / Roboto
| Style (MD3) | Size | Weight | Usage |
|---|---|---|---|
| Display Small | 36sp | Regular | — |
| Headline Large | 32sp | Regular | — |
| Headline Medium | 28sp | Regular | Welcome headings (Login) |
| Title Large | 22sp | Regular | Top app bar title |
| Title Medium | 16sp | Medium | Card primary text |
| Body Large | 16sp | Regular | Form inputs |
| Body Medium | 14sp | Regular | Secondary text, captions |
| Label Large | 14sp | Medium | Button labels |
| Label Medium | 12sp | Medium | Section headers, role badges |
| Label Small | 11sp | Medium | Badge text |

---

## 4. Spacing & sizing

### Core grid
- Base unit: **8dp/pt**
- Content padding (horizontal): **16pt / 16dp** from screen edge
- Card internal padding: **14–16pt / 14–16dp**
- Section gap (between grouped rows): **16–24pt**
- Inline gap (icon → text): **12dp**

### Key component heights
| Component | iOS | Android |
|---|---|---|
| Status bar | 44pt | 24dp |
| Navigation / Top app bar | 44pt (with nav) | 64dp |
| List row / card row | 50–52pt | 52–56dp |
| Primary button | 52pt | 52dp |
| Input field height | 50–52pt | 56dp (outlined) |
| Toggle / Switch | 31×51pt | 32×52dp |
| Avatar (account page) | 84pt diameter | 88dp diameter |
| App icon / logo | 72pt, radius 16pt | 64dp, radius 16dp |

### Corner radii
| Element | iOS | Android |
|---|---|---|
| Grouped card | 12pt | 12dp |
| Button (primary) | 12pt | 100dp (full pill) |
| Chip / badge | 6pt | 100dp (full pill) |
| Input field | 12pt (iOS grouped) | 4dp (outlined) |
| App icon | 16pt | 16dp |
| Avatar | 50% (circle) | 50% (circle) |
| Bottom sheet / dialog | 16pt top corners | 28dp top corners |

---

## 5. Iconography

Library: **Lucide** (stroke icons, 24dp base, stroke-width 2).

| Icon | Usage |
|---|---|
| `Plus` | New Problem FAB / nav button |
| `ChevronDown / Up` | Expand / collapse problem card |
| `ChevronLeft` | iOS back navigation |
| `ArrowLeft` | Android back navigation |
| `Settings` (gear) | Nav bar settings shortcut |
| `Send` | Submit message in chat thread |
| `Check / CheckCircle2` | Resolve action, confirmation |
| `Bell` | Notification settings rows |
| `Volume2` | Sound toggle |
| `Vibrate` | Haptics toggle |
| `Eye / EyeOff` | Password show/hide |
| `MapPin` | Event venue |
| `Hash` | Join with event code |
| `LogOut` | Sign out |
| `Pencil` | Edit profile (Android) |
| `Calendar` | View all events |
| `Search` | Search bar leading icon |
| `RefreshCw` | Auto-refresh setting |
| `Info` | About / version |
| `FileText` | Terms of Service |
| `Shield` | Privacy Policy |

---

## 6. Navigation patterns

### iOS
- **Tab bar**: not used. All navigation is stack-based (push/pop).
- Nav bar: standard height, **centred title**, back chevron (`ChevronLeft`) + destination label.
- Dark mode toggle lives as a trailing nav bar icon (dev convenience; production may remove).
- No hamburger menu. Settings accessed via gear icon in nav bar.

### Android / MD3
- **Navigation drawer**: not implemented in mockups; Settings and Account accessed from the top app bar.
- Top app bar: 64dp, `surface-container` background, **left-aligned title** (22sp Regular).
- Leading icon: `ArrowLeft` (back) — never a hamburger on a non-root screen.
- Root screens (Select Event, Problems list) may show a menu icon if a drawer is added.

---

## 7. Screen inventory & states

### Login
- Fields: Email, Password (show/hide toggle)
- Primary button disabled until both fields non-empty
- Links: Forgot Password, Create Account

### Create Account
- Fields: First Name, Last Name, Phone, Email, Password
- iOS: First+Last stacked in one grouped card; Android: two-column grid
- Primary button disabled until all fields filled
- "Already have an account? Sign In" below button

### Forgot Password
- Single email field
- Button activates on any input
- After submit: transitions to confirmation state (green tick, "Check your inbox", email shown, "Try a different email" link)

### Select Event
- Search bar filters by name or city
- Sections: **Happening Now** (LIVE badge, red) / **Upcoming**
- Event card: full name, venue + city, date range, strip count, role badge
- "Join with event code" — expands to an inline code entry field

### Problems (main screen)
- Header: event name, active problem count, New Problem button
- Problem card (collapsed): status dot · title (strip + issue) · reporter name + time · "Responded: name, name" right-aligned · unread badge · last-message preview with blue dot
- Problem card (expanded): full message thread with sender, role label, timestamp · message compose field
- States: **Reported** (red dot) → **Responded** (orange dot) → **Resolved** (green dot)
- Resolved problems disappear silently after 5 minutes
- Dialogs: New Problem, Edit Problem, Resolve Problem (see §8)

### Settings
- Sections: Notifications, Display, Data, About
- Notification toggles: New Problems, Responder Alerts, Resolved Alerts, Sound, Haptics
- Display: Dark Mode, Large Text
- Data: Auto-refresh
- About: Version, Terms, Privacy (chevron rows)
- Sign Out: full-width destructive button at bottom

### Account
- Avatar: initials circle (primary color)
- Profile fields: Full Name, Email (read-only), Phone · tap Edit to make Name + Phone editable inline
- Events: current (LIVE badge) + upcoming list · "View all events" link
- Sign Out: destructive button at bottom

---

## 8. Dialog patterns

All three dialogs are bottom sheets (modal) on both platforms.

### New Problem dialog
| Field | Type | Options |
|---|---|---|
| Crew type | Segmented button / Picker | Armorer · Medical · Event Mgmt |
| Pod | Segmented button | A · B · C · D |
| Strip number | Segmented button | 1 · 2 · 3 · 4 |
| Description (optional) | Text area | Free text |

- iOS: sheet with centred title, Cancel (left) / Report (right, blue, disabled until crew+strip selected)
- Android: bottom sheet with "New Problem" title, Cancel text button + filled "Report" button

### Edit Problem dialog
- Pre-fills crew, pod, strip from the selected problem
- Same fields as New Problem
- Action label: "Save" instead of "Report"

### Resolve Problem dialog
- Confirmation prompt only — no form fields
- Shows problem title for confirmation
- iOS: destructive "Resolve" in red, Cancel in blue
- Android: "Resolve" filled button, "Cancel" text button

---

## 9. Problem card anatomy

```
┌─────────────────────────────────────────────────────────────────┐
│ ● [status dot]  Strip A2: Broken blade    [▼ collapse]  [🔴 2] │
│                 Reported by J. Martinez 14:23  Responded: T. Webb│
│                 · Last message preview text here…               │
└─────────────────────────────────────────────────────────────────┘
Expanded:
┌─────────────────────────────────────────────────────────────────┐
│ ● Strip A2: Broken blade                          [▲]  [🔴 2]  │
│ ─────────────────────────────────────────────────────────────── │
│  J. Martinez (Reporter) · 14:23                                 │
│  "The blade snapped mid-bout, need a replacement ASAP"          │
│                                                                 │
│  T. Webb (Responder) · 14:25                                    │
│  "On my way"                                                    │
│ ─────────────────────────────────────────────────────────────── │
│  [Reported by J. Martinez 14:23 · Responded: T. Webb]          │
│  [message input field ________________________] [→ send]        │
│  [Edit]                                      [✓ Resolve]       │
└─────────────────────────────────────────────────────────────────┘
```

**Status dot sizes**: 10–12pt diameter, no border
**Unread badge**: red filled pill, white text, min-width 18pt

---

## 10. Strip / Pod numbering

- Pods: **A, B, C, D** (letters, configurable per event)
- Strips per pod: **1–4** (configurable; default 4)
- Finals strips: separate category, not in pod/number grid
- Strip address format: `[Pod letter][Strip number]` e.g. `A2`, `B1`

---

## 11. Crew types

Up to 3 (configurable per event). Default set:
- **Armorer** — equipment repairs
- **Medical** — injury/health response
- **Event Mgmt** — logistics / officiating issues

---

## 12. Problem lifecycle

```
Reporter taps + New Problem
        │
        ▼
   [Reported] ──────► crew notified, red indicator
        │
        │ any crew member taps "On my way"
        ▼
  [Responded] ──────► orange indicator, responder name shown
        │
        │ referee or crew taps Resolve
        ▼
   [Resolved] ──────► green indicator, card disappears after 5 min
```

No re-open after Resolved. Reporter and all responders receive push notification at each transition.

---

## 13. Accessibility

- All interactive elements minimum 44×44pt touch target (Apple HIG) / 48×48dp (MD3)
- Text contrast ratio ≥ 4.5:1 for body, ≥ 3:1 for large text (WCAG AA)
- Status communicated via color **and** label (never color alone)
- Dark mode supported on all screens
- Dynamic type / font scaling should be respected in production (mockups use fixed sizes)

---

*Generated from interactive mockups built in the Stripcall design session, March 2026.*
