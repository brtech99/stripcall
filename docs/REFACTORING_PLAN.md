# StripCall Codebase Refactoring Plan

## Context

The StripCall Flutter app (17,827 lines, 53 files) has accumulated structural inconsistencies: missing mounted guards after async ops (crash risk), dead code, duplicated Supabase queries across dialogs, inconsistent error handling/logging, and duplicated logic in the problem service. This refactoring addresses all of these without changing any functionality or UI.

**Test strategy:** After each phase, reset local Supabase DB and run the exhaustive integration test. No test changes should be needed since all changes are internal.

---

## Phase 1: Critical Safety — Mounted Guards + Dead Code Removal

**Why first:** Missing mounted guards cause runtime crashes when users navigate away during async operations.

### 1A. Add `if (!mounted) return;` guards

**`lib/pages/account_page.dart`** (~7 locations):
- Every async method that calls `setState` after an `await` needs a guard before the `setState`
- Both success and catch paths need guards

**`lib/pages/sms_simulator_page.dart`** (~2 locations):
- `_loadMessages()`: guard before `setState` after Supabase query
- `_clearMessages()`: guard before `setState` after delete

**`lib/pages/user_management_page.dart`** (~4-6 locations):
- `_loadUsers()`: guard before `setState` in success and catch paths
- `_saveUser()`, `_deleteUser()`, `_addUser()`: guards before `ScaffoldMessenger` / `setState` after async ops

**`lib/pages/crews/manage_crew_page.dart`** (2 locations):
- `_loadCrewChief()` catch block: add guard
- `_loadCrewMembers()` catch block: add guard

### 1B. Remove dead `ProblemsPageProvider`

Confirmed: `ProblemsPage` never reads from the provider (no `Provider.of`, `context.watch`, `context.read`, or `Consumer` anywhere in `problems_page.dart`). It uses its own `ProblemsPageState` class + `ProblemService`.

- **`lib/router.dart`**: Remove lines 8 (`import provider`) and 17 (`import problems_page_provider`). Replace `ChangeNotifierProvider(create:..., child: ProblemsPage(...))` with just `ProblemsPage(...)`.
- **`lib/providers/problems_page_provider.dart`**: Delete (427 lines).

### Verify
```
supabase db reset && flutter test integration_test/exhaustive_problem_page_test.dart ...
flutter analyze
```

---

## Phase 2: Unified Logging & Silent Catch Fixes

**Why second:** Inconsistent logging makes debugging hard; silent catches hide real errors.

### 2A. Replace all `print()` with `debugLog()`/`debugLogError()`

Files with `print()` calls (do NOT touch `debug_utils.dart` itself — it's the wrapper):
- `lib/services/problem_service.dart` (~21 prints)
- `lib/router.dart` (~42 prints)
- `lib/pages/user_management_page.dart` (~19 prints)
- `lib/pages/auth/create_account_page.dart` (~13 prints)
- `lib/pages/auth/email_confirmation_page.dart` (~11 prints)
- `lib/pages/events/select_event_page.dart` (~4 prints)
- `lib/models/problem.dart` (1 print on line 17)
- `lib/main.dart` (check for any)
- Any others found via `grep -rn "print(" lib/ --include="*.dart"`

Add `import '../utils/debug_utils.dart';` (or appropriate relative path) where missing.

### 2B. Add logging to silent catch blocks in services

**`lib/services/problem_service.dart`**:
- `loadMissingSymptomData()`: catch returns null — add `debugLogError()`
- `loadMissingOriginatorData()`: same
- `loadMissingResolverData()`: same
- `checkForNewMessages()`: catch returns `[]` — add `debugLogError()`
- `loadMessagesForProblem()`: catch returns `[]` — add `debugLogError()`

### Verify
```
supabase db reset && flutter test integration_test/exhaustive_problem_page_test.dart ...
```

---

## Phase 3: Extract Shared Dialog Data Service

**Why third:** Three dialogs have copy-pasted Supabase query logic with identical display_order fallback patterns.

### 3A. Add shared methods to `lib/services/lookup_service.dart`

New static methods (~80 lines total):
- `getSymptomClassesForCrewType(int? crewTypeId)` — query with display_order fallback
- `getSymptomsForClass(int symptomClassId)` — query with display_order fallback
- `getActionsForSymptom(int? symptomId)` — query with display_order fallback
- `getStripConfig(int eventId)` — returns stripnumbering + count
- `getCrewTypeIdByName(String name)` — crewtype lookup

### 3B. Update dialogs to use shared methods

**`lib/pages/problems/new_problem_dialog.dart`**: Replace `_loadSymptomClassesForCrewType()`, `_loadSymptoms()`, `_loadEventInfo()` bodies with `LookupService` calls. Keep the `setState` and UI logic in the dialog.

**`lib/pages/problems/edit_symptom_dialog.dart`**: Replace `_loadSymptomClasses()`, `_loadSymptoms()`, `_loadStripConfig()` bodies with `LookupService` calls.

**`lib/pages/problems/resolve_problem_dialog.dart`**: Replace actions loading in `_loadProblemAndActions()` with `LookupService.getActionsForSymptom()`.

### Verify
```
supabase db reset && flutter test integration_test/exhaustive_problem_page_test.dart ...
```

---

## Phase 4: Problem Service Cleanup

**Why fourth:** Reduces duplication in the largest service file (856 lines).

### 4A. Extract common SELECT fields constant

All branches of `loadProblems()` and `checkForNewProblems()` use identical SELECT strings. Extract to a `static const _problemSelectFields`.

### 4B. Extract common problem parsing helper

All 3 branches of `loadProblems()` have identical post-query logic (parse JSON → filter resolved > 5min → log errors). Extract `_parseAndFilterProblems(List<Map<String, dynamic>> response)`.

### 4C. Add TODO comment for N+1 query

`enrichWithSmsReporterNames()` calls `get_reporter_name` RPC per phone — add `// TODO: Batch into single RPC` comment. Don't change behavior (requires DB-side changes).

### Verify
```
supabase db reset && flutter test integration_test/exhaustive_problem_page_test.dart ...
```

---

## Phase 5: Minor Page Structure Fixes

**Why last:** Lowest risk, smallest impact.

- **`lib/pages/events/select_event_page.dart`**: Clear `_error = null` at start of `_loadEvents()` so error state resets on retry.
- Any remaining minor inconsistencies found during earlier phases.

### Verify
```
supabase db reset && flutter test integration_test/exhaustive_problem_page_test.dart ...
```

---

## Key Files Modified

| File | Phases | Changes |
|------|--------|---------|
| `lib/pages/account_page.dart` | 1A | ~7 mounted guards |
| `lib/pages/sms_simulator_page.dart` | 1A | ~2 mounted guards |
| `lib/pages/user_management_page.dart` | 1A, 2A | mounted guards + print→debugLog |
| `lib/pages/crews/manage_crew_page.dart` | 1A | 2 mounted guards in catch blocks |
| `lib/router.dart` | 1B, 2A | Remove dead provider wrapper + print→debugLog |
| `lib/providers/problems_page_provider.dart` | 1B | DELETE |
| `lib/services/problem_service.dart` | 2A, 2B, 4 | print→debugLog, add catch logging, extract constant+helper |
| `lib/services/lookup_service.dart` | 3A | Add 5 new shared methods |
| `lib/pages/problems/new_problem_dialog.dart` | 3B | Use LookupService for queries |
| `lib/pages/problems/edit_symptom_dialog.dart` | 3B | Use LookupService for queries |
| `lib/pages/problems/resolve_problem_dialog.dart` | 3B | Use LookupService for actions query |
| `lib/models/problem.dart` | 2A | print→debugLog |
| `lib/pages/auth/create_account_page.dart` | 2A | print→debugLog |
| `lib/pages/auth/email_confirmation_page.dart` | 2A | print→debugLog |
| `lib/pages/events/select_event_page.dart` | 2A, 5 | print→debugLog, clear error on retry |
| `lib/main.dart` | 2A | print→debugLog |
