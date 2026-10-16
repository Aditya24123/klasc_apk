# KLASC Setup and Running

## Install the submitted APK

1. Download [KLASC-3.1.0-New-Symbol.apk](https://drive.google.com/file/d/1t_LWcLUB3eImIw_qB8Wkr7on1zJxGFwD/view?usp=drivesdk) onto an Android 7 or later phone.
2. Open the file and permit installation from the browser or file manager when Android requests it.
3. Open Settings → Apps → KLASC → App info and confirm **3.1.0**. Version 3.0.0 is an older build.
4. Sign up with your own email/password for cloud mode, or choose the device-only library.

The supplied APK is 55,537,867 bytes. SHA-256:

```text
EFE0C3D7D1101256AF2A8B7EA5CFDAB91A753858C043841202CB56702CD4F2FF
```

On Windows, verify a downloaded file with `Get-FileHash ./KLASC-3.1.0-New-Symbol.apk -Algorithm SHA256`. On macOS/Linux, use `shasum -a 256` or `sha256sum`.

The build uses package `com.klasc.klasc` and a development signing certificate. Installing over the earlier supplied build preserves its data when signatures match. A fresh source build uses the developer's own debug key and may not update the supplied APK. If Android reports a signature conflict, preserve/export anything needed before removing an old installation; uninstalling erases the local library. Cloud data remains under its Firebase account. The repository intentionally contains no signing private key.

The [hosted app](https://klasc-8d959.web.app/) is another way to run KLASC. Local browser storage belongs to that browser/profile; cloud account data is shared across clients. Android Share-menu registration comes from the installed APK.

## Build prerequisites

The submitted app was built using Flutter **3.47.7 stable**, Dart **3.13.5**, JDK **17**, Android SDK platform **36**, Build Tools **36.0.0**, and NDK **28.2.13676358**. Flutter's Android build can request missing SDK components. The dependency lockfile requires at least Dart 3.12 and Flutter 3.44; the tested versions above are the reproducibility target.

Install Flutter and Android Studio/Android SDK, put Flutter's `bin` on PATH, configure `JAVA_HOME` and `ANDROID_HOME` for your machine, and accept Android SDK licenses:

```sh
git clone https://github.com/Aditya24123/klasc_apk.git
cd klasc_apk
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter devices
flutter run -d <device-id>
```

Android Gradle uses machine-specific `android/local.properties`; Flutter generates it for the local SDK installation. It is deliberately excluded from Git. Flutter and Gradle download dependencies on the first build.

## Build an APK or run the web app

```sh
flutter build apk --release
flutter run -d chrome
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. To install through a connected, USB-debugging-enabled Android phone:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Windows helper, with Flutter already on PATH:

```powershell
./build-apk.ps1
# Optional debug build:
./build-apk.ps1 -Debug
```

The helper writes a versioned APK into `dist/`. It uses your local SDK/environment and does not require the original author's folder layout. `dist/` and build outputs are ignored by Git.

## Firebase configuration

The included `assets/firebase-config.json`, `android/app/google-services.json`, and `.firebaserc` target the classroom Firebase project `klasc-8d959`. These are client configuration, not Admin SDK credentials; backend rules are the access boundary. No service-account keys or user passwords are required to run the app. Creating a cloud account writes to that project's live backend. Prefer the emulators below for repeatable development tests.

To use your own Firebase project:

1. Create the project and enable Firebase Authentication's Email/Password provider.
2. Create Cloud Firestore in your chosen region. The submitted project uses Delhi (`asia-south2`).
3. Register Android package `com.klasc.klasc` and a Web app. Copy the Web API key, Android API key, both app IDs, messaging sender ID, project ID, and auth domain into the existing keys in `assets/firebase-config.json`; replace `android/app/google-services.json` with your Android SDK configuration.
4. Enable Firebase Hosting and add your development/hosting domains to Authentication's authorized domains if needed.
5. Install the locked CLI dependencies with `npm ci --prefix backend`. Sign in to the Firebase CLI with an account authorized for your own project, then deploy the checked-in rules and indexes. Never deploy permissive test-mode rules as a substitute.
6. In `lib/cloud_store.dart`, change `CloudItemStore.shareOrigin` from `https://klasc-8d959.web.app` to your Hosting domain. Update `.firebaserc` if you want a new default project. The default is not a portable automatic Hosting-domain discovery mechanism.

From the repository root, using your actual project ID:

```sh
./backend/node_modules/.bin/firebase login
./backend/node_modules/.bin/firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
flutter build web --no-web-resources-cdn --no-wasm-dry-run
./backend/node_modules/.bin/firebase deploy --only hosting --project YOUR_PROJECT_ID
```

On Windows, use `firebase.cmd` at the same path. Firebase deployment requires ownership or granted project access; running the app does not grant deployment access. `firebase.json` serves `build/web`, rewrites routes for the Flutter app, and configures public-share headers.

## Run locally with Firebase emulators

For backend tests/emulators, install Node.js (tested with 24.18) and JDK **21**. Use JDK 17 for the tested Android build environment and switch `JAVA_HOME`/PATH to JDK 21 when starting Firebase emulators.

Terminal 1, from the repository root:

```sh
npm ci --prefix backend
./backend/node_modules/.bin/firebase emulators:start --only firestore,auth --project demo-klasc
```

Terminal 2:

```sh
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Emulator data is isolated from the live project. Chrome defaults to `127.0.0.1`; an Android emulator defaults to host address `10.0.2.2`. The bundled emulator configuration binds to localhost. For a physical phone on a trusted local network, change the emulator hosts to a reachable interface and supply `--dart-define=FIREBASE_EMULATOR_HOST=YOUR_LAPTOP_LAN_IP`; restore localhost binding afterward. The Firebase emulator UI runs at `http://127.0.0.1:4000` and is for development only.

See [TESTING.md](TESTING.md) for verification commands and a short classroom demonstration sequence.
