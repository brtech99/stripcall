# StripCall E2E Testing Guide

## Quick Start

### Prerequisites
1. **Docker** must be running
2. **Local Supabase** must be started and reset:
   ```bash
   cd /Users/brosen/Downloads/stripcallC/stripcall
   supabase start
   supabase db reset
   ```

### Running Tests

**On iOS Simulator:**
```bash
# Boot a simulator first
xcrun simctl boot "iPhone 16 Pro"
open -a Simulator

# Run the test with required environment variables
flutter test integration_test/exhaustive_problem_page_test.dart --no-pub \
  -d <SIMULATOR_ID> \
  --dart-define="SUPABASE_URL=http://127.0.0.1:54321" \
  --dart-define="SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
```

**Find available simulators:**
```bash
xcrun simctl list devices available | grep iPhone
```

**Note:** Web tests (`-d chrome`) are not supported for integration tests.

## Important: Always Reset Database Before Tests

The test creates Event2 and other data. If you run the test twice without resetting, you'll get duplicate data errors:
```bash
supabase db reset
```

## Environment Variables

Tests require these `--dart-define` arguments (the app throws an exception without them):
- `SUPABASE_URL=http://127.0.0.1:54321`
- `SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0`

## Test Users (from seed.sql)

All use password: `TestPassword123!`

| Email | Role | Simulator Phone |
|-------|------|-----------------|
| e2e_superuser@test.com | Superuser + Organizer | None |
| e2e_armorer1@test.com | Armorer crew chief | 2025551001 |
| e2e_armorer2@test.com | Armorer crew member | 2025551002 |
| e2e_medical1@test.com | Medical crew chief | 2025551003 |
| e2e_medical2@test.com | Medical crew member | 2025551004 |
| e2e_referee1@test.com | Referee (no crew) | None |

## Edge Functions and SMS

The SMS simulator requires edge functions to process messages and create problems. Check edge runtime status:
```bash
supabase status | grep -i edge
```

If edge runtime is stopped, SMS won't create problems. The test handles this by falling back to the Report Problem dialog.

To start edge functions locally:
```bash
supabase functions serve
```

## Common Test Patterns

### Widget Selection

Always use semantic `ValueKey` identifiers, never visible text:
```dart
// Good
find.byKey(const ValueKey('login_email_field'))
find.byKey(const ValueKey('problem_card_1'))

// Bad - fragile, breaks with text changes
find.text('Login')
```

### Key Naming Convention
Pattern: `{page}_{element}_{description}` or `{page}_{element}_{id}`

Examples:
- `login_email_field`
- `problem_card_1`
- `problem_resolve_button_123`
- `new_problem_crew_radio_3`

### Handling Dropdowns

Dropdown menu items appear in an overlay. Use `.last` for menu items:
```dart
await tester.tap(find.byKey(const ValueKey('my_dropdown')));
await tester.pumpAndSettle();
// Menu items are in overlay, use .last to get the popup version
await tester.tap(find.text('Option').last);
await tester.pumpAndSettle();
```

### Ensuring Visibility Before Tap

For elements that may be scrolled off-screen or in dialogs:
```dart
final widget = find.byKey(const ValueKey('my_widget'));
await tester.ensureVisible(widget);
await tester.pumpAndSettle();
await tester.tap(widget);
```

### Waiting for Async Operations

```dart
// Short wait for UI to settle
await tester.pumpAndSettle();

// Wait for network call
await tester.pumpAndSettle(const Duration(seconds: 2));

// Explicit pump for specific timing
await tester.pump(const Duration(seconds: 1));
await tester.pumpAndSettle();
```

### Debug Output

Use `debugPrint` for test debugging (shows in test output):
```dart
debugPrint('Widget found: ${finder.evaluate().length} widgets');
```

## Troubleshooting

### "Missing Supabase environment variables"
You forgot the `--dart-define` arguments. See Environment Variables section.

### "Found 0 widgets with key..."
- Widget may not exist yet - add `pumpAndSettle` or increase wait time
- Widget may be off-screen - use `ensureVisible` before tapping
- Key may be wrong - check the actual key in the source code

### "ambiguously found multiple matching widgets"
- Use `.first` or `.last` to select one
- Or use a more specific finder (e.g., `find.byKey` instead of `find.text`)

### Test passes locally but fails in CI
- Database state may differ - ensure `supabase db reset` runs before tests
- Timing issues - add more `pumpAndSettle` calls or longer waits

### Tap doesn't register / widget not hittable
The warning "derived an Offset that would not hit test on the specified widget" means:
- Widget is obscured by another widget (modal barrier, overlay)
- Widget is off-screen (needs scroll)
- Widget is disabled

Solutions:
1. Use `ensureVisible()` before tapping
2. Dismiss any open dialogs/dropdowns first
3. Check if a modal barrier is open

### Edge runtime not running
SMS-based problem creation won't work. Either:
1. Start edge functions: `supabase functions serve`
2. Or use fallback logic to create problems via Report Problem dialog

## Test Files

| File | Purpose |
|------|---------|
| `exhaustive_problem_page_test.dart` | Full workflow: event creation, crews, problems, editing, resolution |
| `simple_test.dart` | Basic smoke test |
| `create_account_test.dart` | Account creation flow |
| `problem_page_test.dart` | Problem page specific tests |
| `sms_workflow_test.dart` | SMS workflow tests |
| `test_config.dart` | Test user credentials and configuration |
| `helpers/sms_simulator.dart` | SMS simulator helper |

## Crew IDs in Event2

When the test creates Event2, the crew IDs are:
- Medical crew: ID 3
- Armorer crew: ID 4

These are used for keys like `new_problem_crew_radio_3`.
