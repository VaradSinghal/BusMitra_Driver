# BusMitra Driver - Configuration Setup

## Required API Keys and Configuration

### 1. Google Maps API Key
- Go to [Google Cloud Console](https://console.cloud.google.com/)
- Enable the following APIs:
  - Maps SDK for Android
  - Maps SDK for iOS
  - Directions API
  - Places API
- Create an API key and restrict it to your app's package name
- Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `lib/config/api_config.dart`

### 2. Firebase Configuration
- Go to [Firebase Console](https://console.firebase.google.com/)
- Create a new project or use existing one
- Add Android app with package name: `com.example.busmitra_driver`
- Download `google-services.json` and place it in `android/app/`
- For iOS: Download `GoogleService-Info.plist` and place it in `ios/Runner/`
- Run `flutterfire configure` to generate `lib/firebase_options.dart`

### 3. Environment Variables (Optional)
Create a `.env` file in the root directory:
```
GOOGLE_MAPS_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id
```

### 4. Android Keystore (for release builds)
- Generate a keystore file for signing release builds
- Create `android/key.properties`:
```
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../path/to/your/keystore.jks
```

## Setup Instructions
1. Copy `api_config.dart.template` to `api_config.dart` and add your API key
2. Add Firebase configuration files
3. Run `flutter pub get`
4. Run `flutter run`

## Security Notes
- Never commit API keys or configuration files to version control
- Use environment variables for sensitive data in production
- Restrict API keys to specific domains/IPs when possible
- Regularly rotate API keys
