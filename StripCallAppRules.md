StripCall is a mobile application designed to streamline communication between referees and support staff at fencing tournaments. The app enables:
- Referees to report problems on specific fencing strips
- Support teams (armorers, medics, national office) to receive and respond to problems
- Real-time communication among referees and support teams
- Problem resolution tracking and reporting

Technical Implementation:
- Frontend: Flutter (iOS, Android, Web)
- Backend: Supabase (Authentication, Database, Server Functions)
- Push Notifications: Firebase
- Email Services: Resend
- State Management: GetX
- SMS Integration: Twilio (for backward compatibility)

Project Structure and Implementation Guidelines:

1. Directory Structure
   - `/lib`
     * `/pages` - All screen implementations
       - `/auth` - Authentication related screens
       - `/events` - Tournament management screens
       - `/problems` - Problem reporting and management
       - `/crews` - Crew management screens
     * `/widgets` - Reusable UI components
     * `/models` - Data models and type definitions
     * `/services` - Business logic and external service integrations
     * `/utils` - Helper functions and utilities
     * `/routes.dart` - Application routing configuration

2. Naming Conventions
   - Files: snake_case.dart
   - Classes: PascalCase
   - Variables and functions: camelCase
   - Constants: SCREAMING_SNAKE_CASE
   - Database tables: snake_case
   - Database columns: snake_case

3. Database Table Naming
   - Use plural form for table names
   - Use snake_case for all table and column names
   - Foreign key columns should be named: referenced_table_id
   - Example: users, events, crews, crew_members, problems

4. Implementation Rules
   - All database operations must be performed through Supabase client
   - No direct database access allowed
   - All API calls must be wrapped in try-catch blocks
   - All user input must be validated before processing
   - All dates must be stored in UTC
   - All timestamps must include timezone information

5. State Management
   - Use GetX for state management
   - Keep controllers in separate files
   - One controller per major feature
   - Use reactive state management for real-time updates

6. Error Handling
   - All errors must be logged
   - User-facing errors must be displayed via SnackBar
   - Network errors must be handled gracefully
   - Authentication errors must redirect to login

7. UI Guidelines
   - Use platform-appropriate design components:
     * Material Design for Android and Web
     * Cupertino (iOS-style) for iOS
   - Use flutter_platform_widgets for platform-specific UI components
   - Follow platform-specific design patterns and guidelines
   - Support both light and dark themes
   - Use consistent spacing and typography within each platform
   - Implement proper loading states
   - Show appropriate error states
   - Ensure consistent user experience across platforms while respecting platform conventions

8. Testing Requirements
   - Unit tests for all business logic
   - Widget tests for all UI components
   - Integration tests for critical user flows
   - Mock external services in tests

9. Security Guidelines
   - No sensitive data in client-side code
   - All API keys must be stored in environment variables
   - Implement proper input sanitization
   - Use proper authentication checks
   - Implement rate limiting for API calls

10. Performance Guidelines
    - Implement proper pagination for lists
    - Use lazy loading for images
    - Implement proper caching strategies
    - Optimize database queries
    - Minimize network calls

User Roles and Permissions:
1. SuperUsers
   - Full access to all functions across all tournaments
   - Can manage all tournaments and users
   - Can force password resets
   - Can reassign tournament organizers

2. Organizers
   - Can create, edit, and delete their own tournaments
   - Can specify crews for their tournaments
   - Can assign crew chiefs for those crews
   - Can only manage tournaments they created (unless reassigned by a superuser)

3. Crew Chiefs
   - Can manage their specific crew(s)
   - Can add/remove crew members
   - Can be crew chief for multiple crews across different tournaments, but not multiple crews within the same tournament

4. Crew Members
   - Can receive and respond to problems
   - Can communicate with referees and other crew members
   - Can resolve problems
   - Can be members of multiple crews
   - Can use the app or SMS to communicate

5. Referees
   - Can report problems
   - Can receive updates on their reported problems
   - Can be registered or unregistered (guests)
   - Can use either the app or SMS to communicate

The project uses Supabase for authentication, database, and server
functions. Firebase is used for push notifications. It uses Resend for
email server functions to support authentication. go_router is used for navigation, and GetX is used for state management. StripCall is targeted to iOS, Android
and Web. There is backwards compatibility to an earlier system that uses
SMS messages. Twilio is used to support SMS.

Authentication uses email for confirmation of account set up and
password recovery. The login page requires email and password. It has
forgot password and create account links. Create account requires email
address, first and last name, phone number and a proposed password,
which must meet minimum requirements. An email is sent with a code,
which must be entered to create the account. Login just requires email
address and password. 2FA is not yet supported. Forgot Password requires
an email address. A code is sent via email which must be entered after
which a new password can be entered. An administrative function which
requires email address of a user can be used to force a password reset.

Users have a name, phone number, email and possibly a set of privileges.
SuperUsers are allowed to access all functions for all tournaments.
Organizers are allowed to create, edit and delete tournaments.

A tournament has a name, a location, start and stop dates. Organizers
and super users can create/edit/delete this information. An organizer
can only edit or delete tournament they are the organizer for \-- a
tournament created by an organizer is theirs to manage, a Superuser can
(re)assign an organizer to any tournament. Super users can create, edit
or delete any tournament.

The organizer of a tournament (or a superuser) can add crews to a
tournament. A tournament can have several crews, but only one crew of a
given type. A crew has a crew chief, selected by the organizer (or
superuser). Crew chiefs manage crews by adding or deleting users to the
crew. Crews are specific to a tournament. While a user can be a crew
chief for multiple crews across different tournaments, they cannot be a
crew chief for multiple crews within the same tournament.

When logging in, a user selects a tournament, which is either active at
the time of login, or starting soon (usually 2 days prior to the
tournament start date/time). If the user is on one or more crews for
that tournament, they receive problem
reports/announcements/progress/messages for that tournament. A login by
a user who is not on a crew is considered a referee (ref). A ref can
select any ongoing or upcoming tournament.

Problems are the unit of work in the app. Anyone can report a problem. A
problem has a strip "number" (which is a designated, labeled area within
the tournament space where fencing occurs), a symptom and a message
list. Each type of crew has a list of possible problems, sorted into
areas. To report a problem, the reporter accesses the New Problem
function, selects the crew needed. selects the strip, then selects the
problem area from a menu, which brings up a problem list for that area,
where one item from the list is selected. Crew members all get a report
of the (new) problem on their problem page. Messages can be sent among
the crew responding to a problem. The person that reported the problem
(if they are not on the crew responding to the problem) can optionally
get the message as well as determined by the crew member sending a
message about the problem. A specific message "On our way" is invoked
any crew member with one button which goes to the team as well as the
problem reporter.

When the problem is fixed, one crew member resolves it by choosing from
a list of potential solutions given the problem. Each reportable problem
has a list of possible resolutions from which one is selected. When the
resolution is selected, the problem appears as "solved" on the problem
list for a few minutes, after which it is automatically removed from the
problem list. Once a problem is resolved, it cannot be reopened - a new
problem must be created if additional issues arise.


Strips have two methods by which a specific strip is identified. The
simplest is sequentially numbered, where each strip has a unique integer
that identifies it. The other method is "pods" where a pod is an area
that contains up to 4 strips. The pod is designated by a letter, and the
strip within the pod is designated by a digit (1-4). As an example, D3
is strip 3 in pod D. A tournament must use either sequential numbers or
pods - it cannot mix both systems. The number of strips in a pod may be
less than 4, but cannot exceed 4.

The database is a PostgreSQL relational database (part of Supabase). The current schema can be found at docs/schema.  The
Supabase authentication database is augmented by a users table, indexed
by the Id from the Supabase authentication database, and containing the
first and last name, phone number, and superuser and organizer flags.

The events table has a row for each tournament, which includes the
organizer (index from users), name, city, state, start and end dates.
There is a flag for what strip numbering is used (sequential numbers or
pods). There is a "count" field. If the strip numbering is sequential,
then count is the number of strips. If the strip numbering is pods, the
count is the number of pods. The "finals" strip is a special that is
present in both sequential and pods numbering schemes and is included in
count.

The crews table has a reference to the events table, a reference to a
crewtypes table which lists the possible types of crews, and a crew
chief, which is a reference to the users table. In addition, the crews
table has a "display_style" entry which can be "firstLast",
"firstInitialLast" or "firstLastInitial". This field specifies how names
of crew members are displayed using first and last names from the users
table. Examples of these, in order, are "JaneSmith", "JaneS" and
"JSmith".

The crewtypes table has an id and a crewtype string that names the crew type like "medical" or "armorer". It is referenced by the crews table.

The crewmembers table has a reference to crews and a reference to users.
It holds the list of crew members for a specific crew at a specific
tournament.

The problem table has a reference to the event, the strip number, a
reference to the crew assigned, the id of the originator, date and time it
was reported and closed, a reference to the symptom, a reference to the
action taken to resolve it and the id of the user closing the problem.

The symptomclass table has an index to crew type, and a string for the
class.

The symptom table has an index to symptomclass, and a string for the
symptom.

When a problem is resolved, the action taken to resolve it is selected from the actions table.  It has a reference to the symptomclass table and the string which is the action.

Because the symptom can change as a result of a crew working the issue,
an oldproblemsymptom table records the older symptom. It includes a
reference to the problem, a reference to the older symptom, the
changed-by user and the changed-at time.

When messages are sent about a problem, they are recorded in the messages table, which includes a reference to the crew table, a refererence to the user's table of the author of the message, and the message text.

The action table has an id, a reference to the symptomclass table, and an actionstring that describes the action taken to resolve a problem. It is referenced by the problem table when a problem is resolved.

Because the symptom can change as a result of a crew working the issue,
an oldproblemsymptom table records the older symptom. It includes a
reference to the problem, a reference to the older symptom, the
changed-by user and the changed-at time.

The messages table has an id, a reference to the crew table, a reference to the user's table for the author of the message, the message text, and a created_at timestamp. It records all messages sent about problems.

Finally, to record the entries needed to sign up a new user until the
email confirmation succeeds, a pending_users table holds the name, email
address, phone number and timestamp of a pending user add. This data is
copied to the users table (matched by the email address) when the
confirmation code is entered.

For backwards compatibility refs and/or crew members may opt to use SMS
instead of the app. For this purpose, there is a Twilio telephone number
that receives messages for a specific team. Each team would have a
different Twilio number. A message sent to that number goes to crew
members. A message from a ref creates a new problem. The SMS system is
maintained for backward compatibility and will eventually be phased out,
though this transition may take several years. The system attempts to
extract strip numbers from messages and uses keyword matching to
determine problem symptoms. The users table maintains records for
SMS-only users to provide identity information for message originators.

Screens:

Authentication:

1.  Login:

    a.  Appearance: text boxes for email and password. Button to login.
        Links for Forgot Password and Create Account

    b.  Function: Login invokes Supabase Auth. If successful, navigate
        to Select Event. If unsuccessful, snackbar with error message.
        If Forgot Password is clicked, navigate to Forgot Password page.
        If Create Account is clicked, navigate to Create Account page

2.  Create Account:

    a.  Appearance: text boxes for email. Password, First Name, Last
        Name and Phone number. Button to Create Account. Back button.

    b.  Function: When Create Account button is clicked, invoke Supabase
        new user function. If successful, show Snackbar with check email
        info, create entry in pending users, then navigate to Login, if
        error, snackbar with error message. Back Button click returns to
        Login without creating an account.

3.  Forgot Password:

    a.  Appearance: text box for email. Button to Request Password
        Reset. Back button.

    b.  Function: when Request Password Reset button is clicked,
        snackbar to advise looking for email then navigate to Login. If
        back button clicked, navigate back to Login.

4.  Password Reset:

    a.  Appearance: Text Box for new password. Automatic check for
        password rules, keep Reset Password button disabled until all
        rules are met, Button to Reset Password. Back button

    b.  Function: When Reset Password is clicked, invoke Supabase update
        password function. If Back button is clicked, navigate to Login.

5.  Force Reset:

    a.  Appearance: Text Box for user email. Button for Force Password
        Reset

    b.  Function: when Force Password Reset function is clicked, verify
        email address is one of our users. If it is, set password
        invalid.

> Select Event:

1.  Select Event:

    a.  Appearance: Clickable list of tournaments starting soon or
        underway. Settings button (Logout for all users, Account for all
        users. Manage Tournaments for superusers and organizers, manage
        crews for crew chiefs in current or upcoming tournaments,
        database for superusers)

    b.  Function: When a tournament is clicked, save the index for use
        in this session and navigate to Problems. Settings Button brings
        up a menu:

        i.  Logout logout user and navigate to Login

        ii. Account: Navigate to Account Page

        iii. Manage Tournaments: Navigate to Manage Tournaments

        iv. Manage Crews: Navigate to Manage Crews

        v.  Database: Navigate to database

> Problems:

1.  Problems:

    a.  Appearance: Scrolling list of problems for crews this user is a
        part of, except for refs, which only see problems they reported.
        Each problem has Strip Number, Symptom text and Resolve button
        in a bar a the top, the identity of the reporter below, with a
        chat window below that. Within the chat window is a scrollable
        list with messages about the problem. Messages received are left
        justified. Messages sent are right justified. Below the message
        window is a message compose bar with a text input window, an
        include reporter check box and a Send button. At the top is a
        bar with the crew name, and a New Problem button, plus a
        settings button. Settings menu same as Select Event

    b.  Function: When New Problem is clicked, navigate to New Problem
        page. As messages arrive for the problem distribute to all
        members of the crew and to the reporter if the reporter is not
        on the crew and the include reporter checkbox is checked. Allow
        text input into message compose bar. When Send is clicked,
        distribute the message and push notifications to recipients.
        When resolve button is clicked, navigate to Resolve page. If
        Symptom is clicked, save current symptom in oldSymptom table and
        repeat symptom selection from New Problem. When new symptom is
        selected, update problem table and push notify all crew members.
        Settings menu same as select event.

2.  New Problem

    a.  Appearance: Start by displaying a crew selector: button for each
        crew. Then display a strip selection panel: for tournaments with
        sequential strip numbers, present a tiled list of strip numbers
        and allow a selection, for tournaments with pod numbering,
        present a tiled list of pod letters and a 1-4 strip number. Then
        display a problem area selector, showing all problem areas for
        the crew selected. Then display a problem selector, showing all
        problems for the problem area. Settings menu same as Select
        Event

    b.  Function: When crew selector is clicked, record crew and present
        strip selector. When strip number or pod/strip number is
        selected, present problem area selector. When a problem area is
        selected, present a problem selector. When problem is selected,
        create new problem in problem table, distribute new problem to
        all crew members, send push notification. Navigate to problem
        screen. Settings menu same as Select Event.

3.  Resolve (Pop up form)

    a.  Appearance: Display clickable list of actions appropriate for
        the symptom

    b.  Function: when action is selected, update problem table. Notify
        all users. Remove problem from the active problem list. Navigate
        to Problem page

\`Manage Events:

1.  Manage Events

    a.  Appearance: Scrolling clickable list of events that are not
        concluded where the user is the owner (creator) of. Superusers
        see all ongoing and future events. Back button, New Event
        button. Settings menu same as Select Event, but doesn't have
        Manage Events option.

    b.  Function: When existing event is clicked, navigate to Manage
        Event with that event. When New Event button is clicked,
        navigate to Manage Event with blank info. Settings menu same as
        Select Event.

2.  Manage Event

    a.  Appearance: Form with fields for Event Name, City, State. Date
        Pickers for Start and End dates. Selector for Strip Numbering ,
        field for Count. Save button. Settings menu same as Select Event
        but doesn't have Manage Events option. Scrolling list of Crews
        showing crew type and crew chief name with edit and delete
        button for each. Add Crew button. If user is superuser, name
        finder for organizer

    b.  Function: When Save is clicked, validate fields, and create a
        new entry or modify existing entry in events. Add Crew button
        shows Add Crew popup with blank entries. Edit button for a crew
        shows Edit Crew popup with existing values. Delete button
        deletes entry from crew table. Settings menu same as Select
        Event. If user is superuser, and organizer is not already marked
        as an organizer in users table, update users table with
        organizer true for that user.

3.  Add/Edit Crew (popup)

    a.  Appearance: Header shows add or edit as appropriate. Selector
        for crew type. Name finder for crew chief. Save button.

    b.  Function: When save is clicked, save new entry (Add) or update
        entry (Edit) in crew table.

4.  Name Finder (popup)

    a.  Appearance: Text box for first name and last name. As name is
        typed, show scrolling, clickable list of users. Allow \* as a
        wildcard.

    b.  Function: When user list entry is clicked, choose that user.

Manage Crews:

1.  Select Crew:

    a.  Appearance: Scrolling clickable list if events/crews this user
        is crew chief of. Super users see all crews for all ongoing and
        upcoming events. Settings menu same as Select Events but manage
        crews is not shown.

    b.  Function: When a crew is selected, navigate to Manage Crew with
        selected crew. Settings menu same as Select Events.

2.  Add/Manage Crews:

    a.  Appearance: Show crew type and crew chief at the top. Scrolling
        list of current crew members. Each has a delete button. Add
        crewmember button. Settings menu same as Select Event, but no
        manage crews option. B

    b.  Function: When Add Crewmember button is clicked, popup Name
        Finder. Add entry to crewmembers when user is selected. When
        delete button is clicked, remove that crewmember from the
        crewmember table.

Tournament Structure:
1. Basic Information
   - Name
   - Location (City, State)
   - Start and End Dates
   - Strip Numbering System (Sequential or Pod-based)
   - Strip Count (number of strips or pods)

2. Crew Organization
   - Each tournament can have multiple crews
   - Each crew type (armorer, medic, national office) can only have one crew
   - Each crew has a crew chief and multiple crew members
   - Crew members can be part of multiple crews
   - Crew chiefs can only lead one crew per tournament, but can be crew chief for multiple tournaments with different crews

Problem Management Workflow:
1. Problem Reporting
   - Referee selects crew type (armorer, medic, national office)
   - Referee identifies strip location:
     * For sequential numbering: selects strip number
     * For pod-based numbering: selects pod letter and strip number (1-4)
   - Referee selects problem area from menu
   - Referee selects specific problem from area's problem list
   - System creates new problem and notifies relevant crew

2. Problem Resolution Process
   - Crew members receive notification of new problem
   - Crew members can communicate about the problem
   - Crew can update problem symptoms if needed
   - Crew selects resolution from predefined list
   - Problem appears as "solved" for a few minutes
   - Problem is automatically removed from active list
   - Problem cannot be reopened (new problem must be created)

3. Communication During Problem Resolution
   - Crew members can send messages to each other
   - Reporter can receive messages if included by crew
   - "On our way" message can be sent with one click
   - Messages are displayed in chronological order
   - Messages show sender


