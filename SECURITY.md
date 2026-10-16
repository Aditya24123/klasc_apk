# KLASC Security Review

## GitHub alert review on October 16 2026

GitHub alerts 1 and 2 identify the Firebase-generated Browser and Android API keys in `assets/firebase-config.json`. GitHub displayed their validity as Unknown. These values are client project identifiers that must ship in the browser/APK; they are not account passwords, service-account private keys, Admin SDK credentials, or permission to read private items.

The project API key metadata was checked through the previously authorized Firebase CLI session. Both keys already had Firebase's default API allowlist, with no Generative Language API. That broad list was narrowed to the following six Firebase services:

- `identitytoolkit.googleapis.com`
- `securetoken.googleapis.com`
- `firestore.googleapis.com`
- `firebase.googleapis.com`
- `firebaseinstallations.googleapis.com`
- `firebaseappcheck.googleapis.com`

No application-origin/package restriction was newly enabled, because compatibility of every native client has not been verified. App Check enforcement is not configured; listing its API above does not enable App Check. The changes reduce API scope while keeping existing APKs and web clients on the same identifiers. No key rotation or user-password change was needed for these public Firebase identifiers.

Firestore Security Rules remain the boundary that protects private account data. They require verified authenticated ownership for private reads and writes. Public share requests use a sanitized snapshot and token validity checks. A Firebase key alone cannot bypass these rules. Public Authentication endpoints can still be targeted for signup or quota abuse; API restrictions alone do not eliminate that risk. App Check, production-specific application restrictions, authentication quota review, and monitoring are further hardening work.

[Firebase's API key guidance](https://firebase.google.com/docs/projects/api-keys) explains the distinction between Firebase client keys and privileged secrets. The source code and all recorded commit history were scanned for private-key markers, OAuth credential fields, and GitHub token formats. The focused repository guard explicitly permits only the reviewed client identifiers in their two configuration paths; it does not suppress other credential detections.

## Check before publishing

```sh
node scripts/check-secrets.mjs --self-test
node scripts/check-secrets.mjs
```

This focused guard complements GitHub secret scanning. It cannot prove that every possible secret format is absent. Keep signing keys, CLI tokens, service-account files, temporary test passwords, and local environment files out of Git and exported submissions. `.gitignore` excludes common private file locations, but ignoring a file does not remove an already tracked copy or erase commit history.

For a real privileged credential exposure, revoke or rotate the credential through its provider, update dependent clients/services, inspect relevant logs, and then resolve the matching alert. Removing text in a later commit does not revoke a credential or remove it from earlier commits. Never label an alert revoked unless revocation actually occurred.
