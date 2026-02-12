# Exhaustive Problem Page Test (Test 3)

## Prerequisites/Assumptions
1. **Seeded users**: Superuser, Medical1, Medical2, Armorer1, Armorer2, Referee1
2. **Referee2 created in this test** with phone 2025551005
3. Phone number to user mapping:
   - x1001 (2025551001): Armorer1
   - x1002 (2025551002): Armorer2
   - x1003 (2025551003): Medical1
   - x1004 (2025551004): Medical2
   - x1005 (2025551005): Referee2 (created in this test)
4. Test 1 (smoke test) and Test 2 (create account) are complete and pass
5. Seeded symptom data includes:
   - General > SMS Report - Needs Triage (for both crew types)
   - Head > Concussion (for Medical)
   - Equipment > Broken blade (for Armorer)
   - Actions include "Ran Concussion Protocol" for Concussion symptom

## Test Steps

### Setup: Create Referee2 User (New Step 0)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 0a | Navigate to Create Account | Registration page displayed |
| 0b | Create user: Referee Two, e2e_referee2@test.com, phone 2025551005 | Account created |
| 0c | Return to login page | Login page displayed |

### Event and Crew Setup (Steps 1-10)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Log in as superuser | Login successful, navigated to home |
| 2 | Navigate to Manage Events | Events management page displayed |
| 3 | Create Event2 (starts today, 2 days, **Pod-based strips with 10 pods**) | Event created successfully |
| 4 | Add Medical Crew with Medical1 as crew chief | Medical crew created |
| 5 | Add Armorer Crew with Armorer1 as crew chief | Armorer crew created |
| 6 | Navigate to Manage Crews | Crew management page displayed |
| 7 | Select Event2 Medical | Medical crew selected |
| 8 | Add Medical2 to crew | Medical2 added successfully |
| 9 | Select Event2 Armorer | Armorer crew selected |
| 10 | Add Armorer2 to crew | Armorer2 added successfully |

### User SMS Mode Setup (Steps 11-16)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 11 | Navigate to Database > Manage Users | Users list displayed |
| 12 | Edit Medical1: Enable SMS mode | SMS mode saved |
| 13 | Edit Medical2: Enable SMS mode | SMS mode saved |
| 14 | Edit Armorer1: Enable SMS mode | SMS mode saved |
| 15 | Edit Armorer2: Enable SMS mode | SMS mode saved |
| 16 | Edit Referee2: Enable SMS mode | SMS mode saved |

### Event Selection and Initial State (Steps 17-19)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 17 | Navigate to Select Event | Event selection page displayed |
| 18 | Select Event2 | Problem page displayed |
| 19 | Choose Medical crew | No problems displayed |

### SMS Simulator Setup (Steps 20-25)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 20 | Navigate to SMS Simulator | SMS Simulator page displayed with 5 phone panels |
| 21 | x1001 (Armorer1): Select "Send to Armorer" | Armorer selected |
| 22 | x1002 (Armorer2): Select "Send to Armorer" | Armorer selected |
| 23 | x1003 (Medical1): Select "Send to Medical" | Medical selected |
| 24 | x1004 (Medical2): Select "Send to Medical" | Medical selected |
| 25 | x1005 (Referee2): Select "Send to Medical" | Medical selected |

### SMS Problem Creation (Steps 26-29)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 26 | Referee2 (x1005) sends "Concussion at A1" | Message sent |
| 27 | Verify x1003 and x1004 received message | Both show "Referee Two: Concussion at A1, +1 to reply" |
| 28 | Navigate to Problems page | New problem visible: orange dot, "Strip A1: SMS Report - Needs Triage", last message "Referee Two: Concussion at A1" |
| 29 | Expand problem | Message visible, reporter visible, Edit/On My Way/Resolve buttons visible and enabled |

### Problem Editing (Step 30)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 30a | Edit: Change Problem Area to "Head", Symptom to "Concussion". Save | Strip still A1, Problem now "Concussion" |
| 30b | Edit again: Change strip to B2. Save | B2 displayed in problem header |

### App-to-SMS Messaging (Steps 31-33)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 31 | Check "Include Reporter", send "Is he conscious?" | Message displayed right-justified in chat |
| 32 | Uncheck "Include Reporter", send "I'll take care of it" | Message displayed right-justified in chat |
| 33 | Navigate to SMS Simulator | Verify crew assignments unchanged; x1003/x1004 got both messages; x1005 (referee) got only "Is he conscious?" |

### SMS Crew Member Reply (Steps 34-35)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 34 | x1003 (Medical1) sends "+1 Is there any bruising?" | Message right-justified in x1003; x1004 shows "Medical One: Is there any bruising?"; x1005 shows "Medical One: Is there any bruising?" |
| 35 | Navigate to Problems page | Both "Is he conscious?" and "Is there any bruising?" messages appear with sender names |

### On My Way Flow (Steps 36-37)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 36 | Click "On my way" | "Responding: Super User" appears lower right; button changes to "En route" (disabled) |
| 37 | Navigate to SMS Simulator | "On the way" message appears in x1003, x1004, and x1005 |

### Problem Resolution (Step 38)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 38 | Click Resolve, select "Ran Concussion Protocol", add note "Negative, resumed fencing", click Resolve | Problem status green, "Resolved by: Super User" displayed |

---

## NEW: Report Problem Dialog Test (Steps 39-44)

### Create Problem via UI
| Step | Action | Expected Result |
|------|--------|-----------------|
| 39 | Click "Report Problem" button | New Problem dialog opens |
| 40 | Select crew: Armorer | Armorer crew selected, symptom classes load for Armorer |
| 41 | Select strip: C3 (tap C pod, tap 3) | Strip C3 selected |
| 42 | Select Problem Area: Weapon Issue | Weapon Issue selected, symptoms load |
| 43 | Select Problem: Blade broken | Blade broken selected |
| 44 | Click Submit | Dialog closes, new problem appears in list with "Strip C3: Blade broken" |

---

## NEW: Crew Member Permissions Test (Steps 45-55)

### Login as Regular Crew Member (Medical1)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 45 | Logout from Superuser | Login page displayed |
| 46 | Login as Medical1 (e2e_medical1@test.com) | Login successful |
| 47 | Select Event2 | Problems page displayed |
| 48 | Verify NO crew dropdown in app bar | Only "Medical" title shown (not a dropdown) |
| 49 | Verify resolved Medical problem (B2 Concussion) visible | Problem shows resolved status |

### View Other Crew's Problem
| Step | Action | Expected Result |
|------|--------|-----------------|
| 50 | Verify Armorer problem (C3 Blade broken) is visible | Problem displayed |
| 51 | Verify "Other Crew" badge on Armorer problem | Orange/secondary color badge shows "Other Crew" |
| 52 | Expand Armorer problem | Problem expands to show details |
| 53 | Verify NO "On my way" button for other crew problem | Button not present |
| 54 | Verify NO "Resolve" button for other crew problem | Button not present |
| 55 | Verify NO "Edit" button for other crew problem | Button not present |

---

## NEW: Referee/Reporter View Test (Steps 56-62)

### Login as Referee (Reporter without crew)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 56 | Logout from Medical1 | Login page displayed |
| 57 | Login as Referee2 (e2e_referee2@test.com) | Login successful |
| 58 | Select Event2 | Problems page displayed with "My Problems" title |
| 59 | Verify only Referee2's reported problem visible | Only the B2 Concussion problem (originally reported by Referee2 via SMS) |
| 60 | Expand problem | Problem details visible |
| 61 | Verify NO "On my way" button | Button not present (referees can't respond) |
| 62 | Verify NO "Resolve" button | Button not present (referees can't resolve) |

---

## Coverage Areas
- User account creation (Referee2)
- Event creation with pod-based strip numbering
- Crew creation and member management
- User SMS mode toggle
- SMS Simulator phone-to-crew routing
- SMS problem creation from referee
- SMS message routing to crew members
- Problem editing (symptom and strip changes)
- App-to-SMS messaging (with/without reporter inclusion)
- SMS crew member +n replies
- Reply routing to other crew members and reporter
- "On my way" functionality and SMS notifications
- Problem resolution with action and notes
- **NEW: Report Problem dialog (UI-based problem creation)**
- **NEW: Regular crew member permissions (no crew dropdown)**
- **NEW: "Other Crew" badge display**
- **NEW: Cannot respond/resolve/edit other crew's problems**
- **NEW: Referee/reporter view (My Problems only)**
- **NEW: Referee cannot respond or resolve**

## Seed Data Requirements
The following data must be present in seed.sql:
- **Symptom Classes**: 
  - Armorer: Weapon Issue, Scoring Equipment, Electrical, General
  - Medical: Injury, Illness, Head, General
- **Symptoms**: 
  - Weapon Issue: Blade broken, Point not registering, Guard loose
  - Head: Concussion, Laceration to head
  - General (both): SMS Report - Needs Triage, Other
- **Actions**: 
  - Blade broken: Replaced blade, Repaired blade, Fencer provided replacement
  - Concussion: Ran Concussion Protocol, Cleared to continue, Referred to ER
  - SMS Report - Needs Triage: Triaged and resolved, Reclassified problem

---

## Future Test Enhancements (Not Yet Implemented)

### Message Verification
- Verify sent messages appear in chat with correct alignment
- Verify "Include reporter" checkbox toggles message visibility
- Test SMS message format parsing

### Error Handling
- Network failure during problem creation
- Invalid form submission (missing required fields)
- No available resolutions scenario

### Real-time Updates
- New problem appears without manual refresh
- New message appears in chat
- Problem resolution updates in real-time
- "On my way" status from other users

### Edge Cases
- Sequential strip numbering (vs pod-based)
- "Finals" strip selection
- Very long symptom names
- Many messages (scroll behavior)
- Problem with missing data (lazy loading)
