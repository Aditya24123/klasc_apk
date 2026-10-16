# KLASC Development History

## Earlier local development

KLASC was developed locally on October 12–13, 2026. The local project included the Stage 1 SQLite library, dark UI, Firebase authentication and private cloud storage, Android share intake, public snapshots and revocation, and the supplied mint symbol. The October 13 debug and Chrome records document the 3.1 verification scope and remaining phone-testing limit.

The original workspace had no commits. The target GitHub repository was empty when inspected for this class submission on October 16. Earlier local activity therefore cannot be presented as a historical Git commit trail. No commits have been backdated or invented to simulate development over several days.

## Repository submission work

The new commits record the actual submission work: importing the app and backend policy, importing its automated checks, and adding the report, architecture, setup instructions, and existing verification evidence. Commit timestamps reflect when those imports and documentation changes were made. They do not imply that each feature was first implemented at its import time.

This preserves an honest current history, but the assessment requirement for commits made throughout earlier development is only partially satisfied. Future changes should be committed as they are made, with messages explaining the behavior or issue addressed.

## Changes while preparing the submission

The app's production Dart/Kotlin code, Firebase policy, and branding are copied from the 3.1 source. The Windows APK helper now uses Flutter on PATH and writes to `dist/`, so another laptop does not need the author's private tooling paths. The repository excludes generated builds, dependency caches, local SDK paths, signing keys, temporary credentials, and ad hoc scripts that used local QA fixtures.

The README and report describe the final 3.1 state instead of retaining obsolete build links and superseded browser limitations. The downloadable APK remains the already built 3.1 artifact; documentation and helper changes do not change its runtime behavior.
