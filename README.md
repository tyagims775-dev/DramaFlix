# DramaFlix Admin Upload Starter (Flutter + Firebase)

## Features
- Firestore-driven show list and categories
- Show details with Firestore episode list
- Android phone video picker and Firebase Storage upload
- Upload progress, episode metadata, playback URL
- Email/password admin login (no in-app public signup)
- Local watchlist

## Critical billing note
Firebase Storage availability and billing requirements vary by project and current Firebase plan. Check the Firebase Console before uploading large files; it may require a billing-enabled plan. Video streaming bandwidth can create costs. Do not upload your full library until you have checked quotas and pricing.

## 1. Create Firebase project on Android phone
1. Open https://console.firebase.google.com/ in Chrome.
2. Create a project called `DramaFlix`.
3. Add an Android app using the exact application ID from your Flutter Android project (check `android/app/build.gradle` or `build.gradle.kts`, commonly `applicationId`).
4. Download `google-services.json` and place it at `android/app/google-services.json`.
5. Enable Authentication > Sign-in method > Email/Password.
6. In Authentication > Users, manually add your admin email and a strong password. Do not add public signup to this app.
7. Create Firestore Database.
8. Open Storage and check whether the project requires billing/Blaze to enable it before proceeding.

## 2. Connect Firebase to Android
Recommended if the cloud IDE has terminal and FlutterFire CLI:
- `dart pub global activate flutterfire_cli`
- `flutterfire configure`
However, the starter currently calls `Firebase.initializeApp()` and uses Android native configuration. Ensure Google Services Gradle plugin is configured.

In `android/settings.gradle` or `settings.gradle.kts`, add the Google Services plugin version compatible with your project's Gradle setup, e.g.:
`id("com.google.gms.google-services") version "4.4.2" apply false`
(or the Groovy equivalent).

In `android/app/build.gradle` or `build.gradle.kts`, apply:
`id("com.google.gms.google-services")`
(or Groovy: `id 'com.google.gms.google-services'`).

Use the exact syntax appropriate to the project's Gradle file. Do not paste Kotlin syntax into a Groovy file or vice versa.

## 3. Firestore rules
For a quick safe baseline, replace `ADMIN_EMAIL_HERE` with the exact email used to create your admin account. These rules allow public reading of published shows/episodes, and writes only for that authenticated email.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null
        && request.auth.token.email == 'ADMIN_EMAIL_HERE';
    }

    match /shows/{showId} {
      allow read: if true;
      allow create, update, delete: if isAdmin();

      match /episodes/{episodeId} {
        allow read: if true;
        allow create, update, delete: if isAdmin();
      }
    }
  }
}
```

## 4. Firebase Storage rules
Replace `ADMIN_EMAIL_HERE` with the same admin email. Public read is needed for this starter's direct playback URLs. For a commercial app, use signed URLs or a streaming provider with access control.

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isAdmin() {
      return request.auth != null
        && request.auth.token.email == 'ADMIN_EMAIL_HERE';
    }

    match /videos/{allPaths=**} {
      allow create, update: if isAdmin()
        && request.resource.size < 500 * 1024 * 1024
        && request.resource.contentType.matches('video/.*');
      allow delete: if isAdmin();
      allow read: if true;
    }
  }
}
```

## 5. Install packages and build
In project terminal:
```bash
flutter pub get
flutter analyze
flutter build appbundle
```
Android Internet permission should exist in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` and outside `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

## 6. Use admin panel
1. Run app.
2. Tap admin icon.
3. Sign in with the admin user you created in Firebase Authentication.
4. Add a show.
5. Open that show in Admin Panel.
6. Tap Upload episode, choose an MP4/MOV video from your phone, add title/number, then upload.
7. The episode appears in the public app after Firestore records are saved.

## Important limitations
- This is starter code and has not been built/tested in this environment.
- Public read rules mean anyone who obtains the video URL may be able to access it. For paid content, use a streaming provider with signed URLs and access control.
- Email-based rule checks are a simple small-project baseline. For production, use custom claims or a backend-managed admin role, stronger upload validation, and cost monitoring.
- Store only videos you own or have permission to distribute.
