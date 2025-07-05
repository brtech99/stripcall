# Missing Features in ManageEventsPage

## Event Filtering
- [ ] Filter out concluded events
- [ ] Distinguish between superuser and regular user views
- [ ] Check for event ownership
- [ ] Filter events based on user role (superuser vs organizer)

## Settings Menu
- [ ] Add settings menu with required options:
  - [ ] Logout
  - [ ] Account
  - [ ] Manage Tournaments (for superusers and organizers)
  - [ ] Manage Crews (for crew chiefs)
  - [ ] Database (for superusers)

## User Role Handling
- [ ] Implement superuser vs organizer vs regular user permissions
- [ ] Add special access for superusers to see all events
- [ ] Handle role-based event visibility

## Event Status
- [ ] Add handling of event status (concluded vs ongoing)
- [ ] Implement date-based filtering for future events
- [ ] Add event status indicators in the UI

## Navigation
- [ ] Ensure proper navigation to Manage Event with existing event data
- [ ] Ensure proper navigation to Manage Event with blank info for new events
- [ ] Add back button functionality

## UI Elements
- [ ] Add settings menu button
- [ ] Implement proper scrolling list for events
- [ ] Add visual indicators for event status
- [ ] Add proper loading states and error handling

## Data Management
- [ ] Implement proper event data fetching based on user role
- [ ] Add proper error handling for data operations
- [ ] Implement proper state management for events list

# Missing Features in ManageEvent Page

## Form Fields
- [ ] Event Name field
- [ ] City field
- [ ] State field
- [ ] Start Date picker
- [ ] End Date picker
- [ ] Strip Numbering selector (Sequential or Pod-based)
- [ ] Count field for strips/pods

## Crew Management
- [ ] Scrolling list of Crews showing:
  - [ ] Crew type
  - [ ] Crew chief name
  - [ ] Edit button for each crew
  - [ ] Delete button for each crew
- [ ] Add Crew button
- [ ] Add/Edit Crew popup with:
  - [ ] Crew type selector
  - [ ] Name finder for crew chief
  - [ ] Save button

## Superuser Features
- [ ] Name finder for organizer
- [ ] Update users table with organizer flag when assigning new organizer

## Validation
- [ ] Field validation before save
- [ ] Date validation (end date after start date)
- [ ] Strip count validation based on numbering system

## Navigation
- [ ] Back button functionality
- [ ] Settings menu (same as Select Event, excluding Manage Events)

# Missing Features in SelectEvent Page

## Event List
- [ ] Clickable list of tournaments that are:
  - [ ] Active at time of login
  - [ ] Starting soon (usually 2 days prior)
- [ ] Filter events based on user role:
  - [ ] Crew members see events they're part of
  - [ ] Refs can select any ongoing/upcoming tournament

## Settings Menu
- [ ] Logout option
- [ ] Account option
- [ ] Manage Tournaments (for superusers and organizers)
- [ ] Manage Crews (for crew chiefs)
- [ ] Database (for superusers)

## Navigation
- [ ] Save selected tournament index for session
- [ ] Navigate to Problems page after selection
- [ ] Proper handling of settings menu navigation

## User Role Handling
- [ ] Different views based on user role:
  - [ ] Crew members see their assigned tournaments
  - [ ] Refs see all available tournaments
  - [ ] Superusers see all tournaments

## Data Management
- [ ] Proper event data fetching based on:
  - [ ] Current date
  - [ ] User role
  - [ ] User's crew assignments
- [ ] Handle tournament selection persistence
- [ ] Proper error handling for data operations

# Missing Features in Authentication Pages

## Login Page
- [ ] Email and password text boxes
- [ ] Login button
- [ ] Forgot Password link
- [ ] Create Account link
- [ ] Supabase Auth integration
- [ ] Error handling with SnackBar
- [ ] Navigation to:
  - [ ] Select Event on successful login
  - [ ] Forgot Password page
  - [ ] Create Account page

## Create Account Page
- [ ] Form fields:
  - [ ] Email address
  - [ ] Password (with minimum requirements)
  - [ ] First Name
  - [ ] Last Name
  - [ ] Phone number
- [ ] Create Account button
- [ ] Back button
- [ ] Supabase new user function integration
- [ ] Email confirmation code handling
- [ ] Pending users table integration
- [ ] Success/error SnackBar messages
- [ ] Navigation to Login after successful creation

## Forgot Password Page
- [ ] Email text box
- [ ] Request Password Reset button
- [ ] Back button
- [ ] Supabase password reset integration
- [ ] Success message SnackBar
- [ ] Navigation to Login

## Password Reset Page
- [ ] New password text box
- [ ] Automatic password rules checking
- [ ] Reset Password button (disabled until rules met)
- [ ] Back button
- [ ] Supabase update password function
- [ ] Navigation to Login

## Force Reset Page (Admin)
- [ ] User email text box
- [ ] Force Password Reset button
- [ ] Email address validation
- [ ] Password invalidation functionality
- [ ] Success/error feedback

## Common Authentication Features
- [ ] Password requirements validation
- [ ] Email format validation
- [ ] Phone number format validation
- [ ] Proper error messages for:
  - [ ] Invalid credentials
  - [ ] Network errors
  - [ ] Validation failures
- [ ] Loading states during authentication
- [ ] Session management
- [ ] Proper navigation flow between auth pages
- [ ] Security features:
  - [ ] Password strength requirements
  - [ ] Rate limiting for attempts
  - [ ] Secure storage of credentials
  - [ ] Proper token handling 