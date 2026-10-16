# KLASC

A personal save-for-later app for notes, links, code snippets, and images. Save quickly, add tags, search your inbox, and archive things you want to keep.

**Submission version: 3.1.0 (Android version code 5).** Stages 1 and 2 are implemented; Stage 3 share intake and public read-only links are implemented. Native Android Share-menu testing on a physical phone remains pending.

- [Class project report](docs/REPORT.md)
- [Download the Task 2 report as PDF](docs/submission/KLASC_Task2_Report.pdf)
- [Architecture and data model](docs/ARCHITECTURE.md)
- [Setup and testing](docs/SETUP.md)
- [Verification evidence](docs/TESTING.md)
- [Development history](docs/DEVELOPMENT.md)

## Run KLASC

**Android 7 or later:** [Download KLASC 3.1 APK](https://drive.google.com/file/d/1t_LWcLUB3eImIw_qB8Wkr7on1zJxGFwD/view?usp=drivesdk). Transfer it to the phone, open it, and allow installation from that source when Android asks. App info should show **3.1.0**. Updating an existing installation requires the same signing certificate; keep the installed app to preserve its local data.

**Browser:** [Open KLASC](https://klasc-8d959.web.app/). Create your own email/password account for cloud saving, or choose the local library. Android Share-menu intake requires the APK.

The APK is a release-mode classroom build signed with a development key, not a Play Store production release. Build size, checksum, installation troubleshooting, and source setup are in [SETUP.md](docs/SETUP.md).

## Features and stack

Flutter and Dart UI; Kotlin bridge for Android shared text/URLs; SQLite (`sqflite`) locally; SQLite/IndexedDB adapter on web; Firebase Authentication, Cloud Firestore, and Firebase Hosting for cloud mode and public viewing. Dependencies and fonts are bundled or pinned through the lockfiles; Bebas Neue and Nunito font licenses are included.

Create, view, edit, delete, tag, search, filter, archive, and restore all four item types. Shared URLs open a draft for title/tags and explicit saving. Cloud owners can create or revoke a public link to one sanitized item snapshot.

## Authentication and privacy

Firebase Authentication handles email/password sign-up and sign-in. The optional username is a display name, not a login identifier. Cloud items live under `users/{uid}/items/{id}` in Firestore in Delhi (`asia-south2`). Firestore Security Rules require the authenticated UID to match the owner path and validate item ownership and writes; knowing another item's ID does not grant access. Passwords are not stored in item documents.

Public links use random 256-bit tokens and return only the selected snapshot. Backend rules deny public collection listing and visitor writes. Account information, inbox items, tags, and internal item IDs are excluded. See [the report](docs/REPORT.md#authentication-and-privacy) and [rules](firestore.rules).

## Build from source

Use Flutter **3.47.7** / Dart **3.13.5**, an Android SDK, and JDK 17. From the repository root:

```sh
flutter doctor
flutter pub get
flutter run
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`. On Windows, `./build-apk.ps1` also copies the build into `dist/`. [SETUP.md](docs/SETUP.md) covers Firebase emulators, web, and independent Firebase projects.

## Decisions and known limits

Local and cloud libraries are separate; signing in does not upload local saves. Cloud operations require internet and provide retry feedback; there is no offline sync queue. Small cloud images are stored in private Firestore documents (512 KiB limit) to keep authorization simple. Public links share a snapshot; revoke and create a new link after editing. Access control is enforced on the backend, but this is not end-to-end encryption.

Recorded checks: 24 Flutter tests, 12 emulator security tests, clean analysis, and live Chrome sign-in/save/search/edit/archive/restore/public-link/revocation checks. Android physical Share-menu testing, iOS distribution, and narrow-screen Chrome testing remain unverified. Details and dates are in [TESTING.md](docs/TESTING.md).

Earlier development took place locally on October 12–13, 2026. This previously empty repository was populated on October 16; its new commit history records the import and submission work honestly, without backdated development commits.

Security alert review: the two Firebase client identifiers were verified and restricted to six Firebase APIs; both GitHub alerts are resolved as false positives. See [SECURITY.md](SECURITY.md) for the review and remaining hardening work.
