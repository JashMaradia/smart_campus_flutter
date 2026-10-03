# Smart Campus

An offline college management app built with Flutter (Material 3). All data lives in a local
SQLite database on the device and is pre-filled with sample data, so every screen has content on
first launch.

## Run it

1. Install Flutter (3.24 or newer) and set up an Android emulator or an iOS simulator.
2. In this folder create the platform projects (this keeps `lib/` and `pubspec.yaml` as they are):

   ```
   flutter create --org com.smartcampus --project-name smart_campus --platforms android,ios .
   flutter pub get
   flutter run
   ```
3. iOS only: add these keys to `ios/Runner/Info.plist` (needed for profile photos and attachments):

   ```xml
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Choose a profile photo or course material.</string>
   <key>NSCameraUsageDescription</key>
   <string>Take a profile photo.</string>
   ```
4. Run the tests with `flutter test`.

## Demo logins

| Role | Login | Password |
| --- | --- | --- |
| Admin | `admin@smartcampus.com` | `Admin@123` |
| Student | `CS2301` (Aarav Mehta) | `Student@123` |

Every seeded student that has a login uses the same password. Student IDs: CS2301 to CS2308, CS2201 to CS2203,
EC2301 to EC2304, ME2301 to ME2303.

Two students have no login yet so you can try **Create account** on the login screen:

| Student ID | Registered email |
| --- | --- |
| `EC2305` | `nidhi.agarwal@smartcampus.edu` |
| `ME2304` | `simran.kaur@smartcampus.edu` |

**Forgot password** works offline: enter the Student ID (or admin email), the registered email and
the date of birth.

| Account | Registered email | Date of birth |
| --- | --- | --- |
| Admin | `admin@smartcampus.com` | 15 Jun 1985 |
| CS2301 (Aarav Mehta) | `aarav.mehta@smartcampus.edu` | 5 Jan 2004 |

Seeded student emails follow the pattern `first.last@smartcampus.edu`.

## What is included

Admin: dashboard with live statistics and charts, students, faculty (with course assignment),
courses (with material upload), timetable (clash detection for class, faculty and room),
attendance (bulk marking, overview, per student history), notices (publish, draft, swipe to delete
with undo), events, fees (structure, payments, PDF receipts), reports (attendance, fees, courses,
performance, faculty; preview, PDF and CSV export), student requests, profile, settings (theme,
backup, restore, reset demo data).

Student: home dashboard, timetable with the current class highlighted, attendance with a warning
below 75 percent, courses and materials, notices with unread markers, events, fees with receipt PDFs,
notification center, requests, profile (edit phone, address and photo).

## Project structure

```
lib/
  core/        theme, constants, validators, utils, router, export (PDF/CSV), shared widgets
  data/
    local/     SQLite database, schema, demo data
    models/    plain Dart models
    repositories/  SQLite implementation of the repository
  domain/      CampusRepository (the interface every screen uses)
  features/    splash, auth, admin, student, shared
```

## Connecting a real backend later

Screens only talk to the abstract `CampusRepository` in `lib/domain/campus_repository.dart`.
To use an API, create `ApiCampusRepository implements CampusRepository` and change one line in
`lib/main.dart`:

```dart
final CampusRepository repo = ApiCampusRepository(/* your client */);
```

Passwords are stored as salted SHA-256 hashes. For a real server, move authentication to the
backend and use tokens.

## Database upgrades

The schema version is in `lib/data/local/app_database.dart`. When you change a table, raise
`schemaVersion` and add an `if (oldVersion < N)` block in `_migrate` so existing users keep their data.

## Known limits

* Device (push style) notifications are not included. The in-app notification center is complete.
  `flutter_local_notifications` can be added once the app is running.
* The list of programs is fixed in `lib/core/constants.dart` (`kPrograms`).
* Dark and light themes both work, but the app has not been checked on every screen size.
