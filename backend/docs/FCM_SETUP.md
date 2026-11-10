# Firebase Cloud Messaging setup

The app can still run without Firebase configuration. Local scheduled reminders
are independent of FCM. Complete these steps to enable push messages from the
backend.

## Firebase Android app

1. Create or select the Firebase project used by this deployment.
2. Register an Android app with package name `com.asuhkita.mobile`.
3. Download that app's `google-services.json` to
   `android/app/google-services.json`. This file is ignored by Git.
4. Enable Firebase Cloud Messaging in the Firebase project.
5. Build and install the app again after adding the file:

   ```powershell
   flutter build apk --debug
   ```

The Android Gradle build applies the Google Services plugin only when this
configuration file exists.

## Backend service account

1. In Firebase Console, create a service-account private key for the same
   Firebase project. Keep the downloaded JSON outside the repository.
2. Encode the file as Base64 in PowerShell:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure\firebase-service-account.json'))
   ```

3. Put the resulting value in `backend/.env` as
   `FIREBASE_SERVICE_ACCOUNT_BASE64=...`. Do not commit or paste the private
   key into source files, chat, or `.env.example`.
4. Restart the backend. It will use the Firebase Admin SDK when an admin
   sends a broadcast through `POST /api/notifications/broadcast`.

The Android configuration and service-account key must belong to the same
Firebase project. Device tokens are registered when a user signs in with a
valid backend session. Offline/demo sessions do not register device tokens.

## Database migration

Set `DATABASE_URL` in `backend/.env` to the intended PostgreSQL/Supabase
database, then run:

```powershell
cd backend
npm run migrate:push-tokens
```

The migration checks that the AsuhKita `public.users` and `public.feedback`
tables exist, creates `public.push_tokens` and its user index transactionally,
and can safely be run again. It does not run the full schema or seed scripts.
