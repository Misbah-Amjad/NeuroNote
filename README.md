# NeuroNote

An intelligent learning companion app built with Flutter that combines AI-powered assistance, spaced repetition, and interactive learning tools to enhance educational experiences.

## 📱 Features

- **AI Chat Assistant** - Get instant help with your studies through an intelligent chatbot
- **Audio Notes** - Record and organize lecture notes with audio playback
- **Flashcards** - Create and study with interactive flashcard decks
- **Quiz Practice** - Test your knowledge with practice quizzes and track progress
- **Summary & Mind Maps** - Generate automated summaries and mind maps from lecture content
- **Learning Hub** - Centralized learning dashboard with personalized recommendations
- **Progress Tracking** - Monitor your learning streaks and academic progress
- **PDF Support** - Generate and export learning materials as PDFs
- **User Profile** - Customizable profile with progress history and preferences
- **Authentication** - Secure sign-up and login with email verification
- **Notifications** - Stay updated with learning reminders and achievements
- **Dark/Light Theme** - Comfortable viewing in any lighting condition

## 🛠️ Tech Stack

- **Framework**: Flutter 3.10.1+
- **Language**: Dart
- **Backend**: Firebase (Authentication, Firestore)
- **State Management**: Provider
- **UI Enhancements**: Lottie animations, Animate Do, Google Fonts
- **Chat UI**: Flutter Chat UI & Types
- **PDF Generation**: PDF package with Printing support
- **Additional**: UUID for unique identifiers, Intl for internationalization

## 📋 Prerequisites

Before you begin, ensure you have the following installed:
- Flutter SDK 3.10.1 or higher
- Dart SDK (included with Flutter)
- Android Studio or Xcode (for mobile development)
- Git

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd neuronote
   ```

2. **Get Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up environment variables**
   - Create a `.env` file in the project root
   - Add your Firebase and API configuration

4. **Configure Firebase**
   - For Android: Ensure `google-services.json` is in `android/app/`
   - For iOS: Ensure `GoogleService-Info.plist` is in `ios/Runner/`

5. **Run the app**
   ```bash
   flutter run
   ```

## 📂 Project Structure

```
lib/
├── ai_chat.dart                 # AI chat interface
├── audionotescreen.dart        # Audio recording and playback
├── flashcard.dart              # Flashcard creation and study
├── practice_quiz.dart          # Quiz practice module
├── learning_hub.dart           # Main learning dashboard
├── auth_service.dart           # Authentication service
├── firebase_options.dart       # Firebase configuration
├── api_service.dart            # API service layer
├── local_storage_service.dart  # Local data persistence
├── progress_service.dart       # Progress tracking
├── theme.dart                  # App theme configuration
├── navigation.dart             # Navigation routing
├── utils/                      # Utility functions
└── [other screens and services]
```

## 🔧 Development Setup

### Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable Authentication (Email/Password)
3. Enable Firestore Database
4. Download configuration files:
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS
5. Place them in the respective directories

### Environment Variables

Create a `.env` file with:
```
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
```

## 📚 Available Scripts

```bash
# Run the app
flutter run

# Build release APK (Android)
flutter build apk --release

# Build release IPA (iOS)
flutter build ios --release

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

## 🤝 Contributing

1. Create a new branch for your feature (`git checkout -b feature/AmazingFeature`)
2. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
3. Push to the branch (`git push origin feature/AmazingFeature`)
4. Open a Pull Request

## 📝 Code Style

- Follow Dart/Flutter conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Run `dart format .` before committing

## 🐛 Known Issues

- [Track issues in the GitHub Issues page]

## 📄 License

This project is proprietary and confidential.

## 📧 Support

For support, email support@neuronote.com or open an issue in the repository.

## 🎯 Roadmap

- [ ] Offline mode support
- [ ] Collaborative study groups
- [ ] Advanced AI-powered recommendations
- [ ] Integration with popular learning platforms
- [ ] Multiplayer quiz challenges

---

Built with ❤️ using Flutter
