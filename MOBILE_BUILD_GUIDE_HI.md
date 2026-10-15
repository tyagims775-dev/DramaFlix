# DramaFlix — Android mobile se APK banane ka guide

## APK build workflow

Is repository mein `.github/workflows/build-apk.yml` workflow hai. GitHub Actions cloud runner par Flutter install karta hai, missing Android project files generate karta hai aur debug APK artifact upload karta hai.

## Mobile steps
1. ZIP ko extract karein.
2. GitHub par **Private** repository `DramaFlix` banayein: https://github.com/new
3. Repository ke andar **Add file → Upload files** se ZIP ke andar ki files/folders upload karein. ZIP file ko akeli upload na karein; extracted contents upload karein. `.github` hidden folder agar mobile browser se upload na ho, to pehle `Add file → Create new file` se `.github/workflows/build-apk.yml` banayein aur workflow content ZIP mein maujood file se copy karein.
4. Files commit karein to `main` branch.
5. Repository → **Actions** tab → **Build DramaFlix APK** workflow → **Run workflow** → **Run workflow**.
6. Build green/success hone par workflow run kholein, neeche **Artifacts** mein `DramaFlix-debug-apk` tap karein. ZIP download hoga; Files app se extract karke `app-debug.apk` install karein.
7. Agar Actions tab mein workflow disabled ho, **I understand my workflows, go ahead and enable them** jaisa button aaye to use enable karein.

## Firebase note
Yeh pehla APK debug/testing ke liye hai. Firebase config abhi na hone par app Firebase setup screen dikhayegi; yeh expected hai. Firebase connect karne ke baad naya build karein.

Firebase setup: https://console.firebase.google.com/
- Firebase project banayein.
- Android app register karein. Package name `flutter create` ke default se milna chahiye; app-level `android/app/build.gradle.kts` mein `applicationId` check karein. Agar use badlein, Firebase Android app ko usi exact package name se register karein.
- `google-services.json` download karke repository ke `android/app/` folder mein add karein.
- `android/settings.gradle.kts` mein Google Services plugin declaration aur `android/app/build.gradle.kts` mein `id("com.google.gms.google-services")` plugin apply karna zaroori ho sakta hai. Firebase ki official current instructions follow karein: https://firebase.google.com/docs/android/setup
- Flutter Firebase packages aur code ko configure karne ke liye app ke pubspec/dependencies aur native config compatible hone chahiye.
- Authentication mein Email/Password enable karein; Firestore database aur restrictive rules configure karein.

Cloud Storage for Firebase ke liye Blaze billing plan aur linked billing account required ho sakta hai. Video upload shuru karne se pehle pricing/budget alerts check karein: https://firebase.google.com/docs/storage/android/start

**Safety:** Is first workflow ka APK debug build hai, Play Store release nahin. Public production ke liye release signing, testing, privacy policy, secure database/storage rules, app icon, package ID aur Play Console requirements alag se poore karne honge. `google-services.json` unique project identifiers rakhta hai; is file mein private server secrets nahin hote, lekin Firebase Security Rules ko kabhi bhi loose na rakhein.
