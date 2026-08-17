# Show the Original Report in the Edit Problem dialog

**Date:** 2026-06-05
**Status:** Designed (implementation deferred until after the production freeze)

## Problem

SMS-reported problems arrive with the symptom "SMS Report – Needs Triage" (symptom id 27),
which has no resolution actions. The intended crew workflow is to **edit the problem and set
the real symptom** before resolving. But the reporter's actual SMS text lives only in the
message window *behind* the Edit Problem dialog — it's dimmed and covered while the dialog is
open. To recall what the reporter wrote, the crew member must cancel the dialog, read the
message, and start over.

## Goal

Surface the problem's **first message** (the original report) directly inside the Edit Problem
dialog, read-only, so the crew member can triage without dismissing the dialog.

## Scope

- Applies to **any** problem that has a first message (option "B"). SMS-reported problems have
  the reporter's text as their first message; most app-created problems have no messages, so
  nothing is shown for them. No SMS-specific detection is required.
- Show **only the first (earliest) message** — the original report. Follow-up reporter texts are
  out of scope (YAGNI).
- **Read-only** reference text. No editing, no backend changes, no schema changes.

## Design

### Data path (no extra DB call)

`problems_page._showEditSymptomDialog(ProblemWithDetails problem)` already receives the full
problem with `messages` loaded (the message window renders them). `messages` is ordered
earliest→latest (the card uses `messages.last` for the newest), and each entry is a
`Map<String, dynamic>` with a `'message'` text field.

Extract the first message text in the caller and pass it in:

```dart
final firstMessage = (problem.messages?.isNotEmpty ?? false)
    ? problem.messages!.first['message'] as String?
    : null;
```

Pass `firstMessage` to `EditSymptomDialog` via a new optional parameter.

### UI (`edit_symptom_dialog.dart`)

- Add `final String? firstMessage;` to the widget and constructor.
- In `build()`, **between** the "Current: Strip X – Symptom" line and the strip selector,
  render a callout **only when `firstMessage` is non-null and not blank**:
  - Container styled with the theme's `surfaceContainerLow` background, rounded corners, padding.
  - A small bold label: **"Original Report"**.
  - The text rendered as `SelectableText` (wraps; capped at ~120px height with internal scroll
    for long messages).
- When `firstMessage` is null/blank, render nothing (no empty box). This is the no-harm path for
  app-created problems.

### Components touched

| File | Change |
|------|--------|
| `lib/pages/problems/edit_symptom_dialog.dart` | New `firstMessage` param; read-only "Original Report" callout in `build()` |
| `lib/pages/problems/problems_page.dart` | Compute first-message text and pass it to `EditSymptomDialog` |

## Error / edge handling

- `messages` null or empty → `firstMessage` null → callout hidden.
- First message text null or whitespace-only → callout hidden.
- Very long report text → callout scrolls internally (height cap), dialog layout unchanged.

## Testing

Widget test for `EditSymptomDialog`:
- Renders an "Original Report" callout containing the provided text when `firstMessage` is set.
- Renders no callout when `firstMessage` is null or blank.

## Out of scope

- Showing follow-up reporter messages.
- Any change to the resolve flow or to symptom 27's resolution actions (tracked separately).
- Backend / schema changes.

## Constraint

This is a client (Flutter) change requiring a build, so it lands **after the production freeze**
(live tournament). Spec only for now.
