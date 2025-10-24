# StockDrop Setup Guide

Complete setup instructions for the StockDrop Flutter stock market app with Supabase backend and OneSignal push notifications.

## 📋 Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (comes with Flutter)
- Android Studio / VS Code with Flutter extensions
- Git

## 🚀 Quick Start

### 1. Clone and Setup Project

```bash
git clone <your-repo-url>
cd stockdrop
flutter pub get
```

### 2. Supabase Setup

#### Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your project URL and anon key from Settings > API

#### Configure Database

1. In your Supabase dashboard, go to SQL Editor
2. Run the database setup script from `database/stockdrop_schema.sql`
3. Verify tables `st_favorites` and `st_settings` are created

#### Update Configuration

In `lib/main.dart`, replace the placeholder values:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',           // Replace with your Supabase URL
  anonKey: 'YOUR_SUPABASE_ANON_KEY',  // Replace with your anon key
);
```

### 3. OneSignal Setup

#### Create OneSignal App

1. Go to [onesignal.com](https://onesignal.com) and create a new app
2. Follow the setup for Android/iOS platforms
3. Note your OneSignal App ID

#### Update Configuration

In `lib/main.dart`, replace the placeholder:

```dart
OneSignal.initialize('YOUR_ONESIGNAL_APP_ID'); // Replace with your App ID
```

### 4. FMP API Setup

#### Get API Key

1. Sign up at [Financial Modeling Prep](https://financialmodelingprep.com)
2. Get your free API key

#### Update Configuration

In `lib/services/api_service.dart`, replace:

```dart
static const String _apiKey = 'YOUR_FMP_API_KEY'; // Replace with your API key
```

## 🔧 Configuration Files

### Environment Variables (Recommended)

Create a `.env` file in the root directory:

```env
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here
ONESIGNAL_APP_ID=your_onesignal_app_id_here
FMP_API_KEY=your_fmp_api_key_here
```

Then use packages like `flutter_dotenv` to load these values.

### Supabase Configuration

Your Supabase project should have:

- ✅ Row Level Security (RLS) enabled
- ✅ Authentication enabled
- ✅ Tables: `st_favorites`, `st_settings`
- ✅ Proper RLS policies for user data isolation

### OneSignal Configuration

Required for push notifications:

- ✅ Android configuration with FCM
- ✅ iOS configuration with APNs (for iOS builds)
- ✅ Web push configuration (for web builds)

## 📱 Running the App

### Development

```bash
flutter run
```

### Build for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web
```

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point with initialization
├── models/
│   ├── stock.dart              # Stock data model
│   └── news.dart               # News data model
├── providers/
│   ├── auth_provider.dart      # Authentication state management
│   ├── theme_provider.dart     # Theme state with Supabase sync
│   └── stock_provider.dart     # Stock data and favorites management
├── screens/
│   ├── login_screen.dart       # Authentication screen
│   ├── home_screen.dart        # Main dashboard
│   ├── search_screen.dart      # Stock search
│   ├── favorites_screen.dart   # User favorites
│   ├── detail_screen.dart      # Individual stock details
│   └── settings_screen.dart    # App settings
├── services/
│   ├── api_service.dart        # FMP API integration
│   ├── supabase_service.dart   # Supabase backend service
│   └── push_service.dart       # OneSignal push notifications
└── widgets/
    ├── stock_card.dart         # Reusable stock display
    └── chart_widget.dart       # Stock chart widget
```

## 🔐 Security Setup

### Supabase RLS Policies

The database schema includes Row Level Security policies that ensure:

- Users can only access their own favorites
- Users can only modify their own settings
- Authentication is required for all operations

### API Key Security

For production apps:

- Use environment variables
- Implement API key rotation
- Monitor API usage and quotas

## 🧪 Testing

### Run Tests

```bash
flutter test
```

### Test Features

- [ ] User authentication (login/logout)
- [ ] Stock search and favorites
- [ ] Theme switching and persistence
- [ ] Push notification handling
- [ ] Offline functionality

## 🚨 Troubleshooting

### Common Issues

**Supabase Connection Errors**

- Verify URL and anon key are correct
- Check internet connection
- Ensure Supabase project is active

**OneSignal Not Working**

- Verify App ID is correct
- Check platform-specific setup (Android/iOS)
- Ensure notification permissions are granted

**API Rate Limits**

- FMP free tier has request limits
- Implement caching and request throttling
- Consider upgrading API plan for production

**Build Errors**

```bash
flutter clean
flutter pub get
flutter pub deps
```

### Getting Help

- Check Flutter documentation
- Review Supabase documentation
- Check OneSignal documentation
- Open issues in the project repository

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the project
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request
