# 🧠 NeuroNote

### Study Smarter, Not Harder.

NeuroNote is an **AI-powered learning companion built with Flutter** to help students learn more effectively through interactive study tools.

Instead of studying from static notes alone, students can use NeuroNote to transform their learning content into **AI-generated quizzes, flashcards, summaries, mind maps, and audio-based study material**.

The project was developed as my **Final Year Project (FYP)**, with a focus on combining mobile app development, AI-assisted learning, and personalized study experiences.

---

## ✨ Features

### 🤖 AI-Powered Learning

* AI Chat Assistant for study-related questions
* AI-generated flashcards
* AI-generated practice quizzes
* AI-generated summaries and mind maps
* Learning content transformation from uploaded material

### 📚 Study Tools

* Flashcards for active recall
* Practice quizzes and assessments
* Combined summaries and mind maps
* Audio Notes for learning through audio
* PDF generation and printing
* Learning Hub for organizing study content

### 📊 Learning & Progress

* Progress tracking
* Study history
* Learning streaks
* Personalized learning experience
* Saved/favourite learning content
* Notifications and reminders

### 📱 App Features

* Email/password authentication
* Email verification
* Firebase Authentication
* Cloud Firestore data storage
* User profiles
* Dark/Light theme
* Responsive Flutter interface
* Lottie animations and interactive UI

---

## 🎯 Project Goal

NeuroNote aims to make studying more **interactive, personalized, and efficient**.

The idea is simple:

> **Upload your learning material → let AI transform it → learn through interactive study tools.**

The application is designed for students preparing for exams as well as students studying general academic subjects.

---

## 🛠️ Tech Stack

| Technology                  | Purpose                                       |
| --------------------------- | --------------------------------------------- |
| **Flutter**                 | Cross-platform mobile application development |
| **Dart**                    | Application programming language              |
| **Firebase Authentication** | User authentication and email verification    |
| **Cloud Firestore**         | User data and learning history                |
| **Cloud Functions**         | Backend/serverless functionality              |
| **HTTP**                    | API communication                             |
| **Provider**                | State management                              |
| **PDF / Syncfusion PDF**    | PDF creation and processing                   |
| **Printing**                | PDF printing and sharing                      |
| **Flutter TTS**             | Text-to-speech functionality                  |
| **Speech to Text**          | Voice input                                   |
| **AudioPlayers**            | Audio playback                                |
| **Lottie**                  | Animations                                    |
| **Google Fonts**            | Typography                                    |
| **FL Chart**                | Progress and data visualization               |
| **Table Calendar**          | Calendar-based study features                 |
| **Shared Preferences**      | Local preferences/storage                     |

---

## 🏗️ How NeuroNote Works

```text
        Student
           │
           ▼
   Upload Study Material
   ┌─────────────────────┐
   │ PDF │ Image │ Notes │
   │ Past Papers │ Text  │
   └─────────────────────┘
           │
           ▼
      AI Processing
           │
           ▼
   ┌─────────────────────┐
   │     Study Tools     │
   │                     │
   │ • Flashcards        │
   │ • Quizzes           │
   │ • Summary           │
   │ • Mind Maps         │
   │ • Audio Notes       │
   │ • AI Chat           │
   └─────────────────────┘
           │
           ▼
    Personalized Learning
           │
           ▼
   Progress & Study History
```

---

## 📱 Main Modules

### Authentication

Users can create an account and securely sign in using Firebase Authentication with email verification.

### AI Chat

An interactive AI assistant allows students to ask questions and receive study-focused assistance.

### Flashcards

Learning material can be converted into question-and-answer flashcards to support active recall.

### Practice Quizzes

Students can practice their knowledge through generated questions and track their performance.

### Summary & Mind Maps

NeuroNote can transform learning content into a combined **summary and mind-map style study resource** for easier revision.

### Audio Notes

Students can work with audio-based learning content and text-to-speech functionality.

### Learning Hub

A centralized space for accessing saved learning materials and study resources.

### Progress Tracking

The application provides progress-related information such as learning history, streaks, and performance.

---

## 🔐 Security

Sensitive configuration files and API credentials are **not included in this repository**.

Examples of excluded configuration files include:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
lib/config.php
```

> **Important:** API keys and private credentials should never be hard-coded into a public Flutter application or committed to Git.

---

## 🚀 Getting Started

### Prerequisites

Make sure you have:

* Flutter SDK
* Dart SDK
* Git
* A configured Android/iOS development environment

### Clone the Repository

```bash
git clone https://github.com/Misbah-Amjad/NeuroNote.git
cd NeuroNote
```

### Install Dependencies

```bash
flutter pub get
```

### Configure Firebase

Create/configure your own Firebase project and add the required Firebase configuration files for your target platform.

The configuration files are intentionally excluded from this repository for security reasons.

### Run the Application

```bash
flutter run
```

### Build Android APK

```bash
flutter build apk --release
```

---

## 📂 Project Structure

```text
neuronote/
│
├── android/
├── ios/
├── assets/
│   ├── animations/
│   ├── audio/
│   └── images/
│
├── lib/
│   ├── AI & learning modules
│   ├── authentication
│   ├── study tools
│   ├── navigation
│   ├── services
│   ├── UI screens
│   └── utilities
│
├── test/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 🎓 Academic Project

**NeuroNote** was developed as my **Final Year Project (FYP)** for the Bachelor of Science in Information Technology.

The project combines:

* Mobile application development
* Artificial intelligence
* Educational technology
* Cloud-based authentication and data storage
* Personalized learning
* Interactive UI/UX

---

## 👩‍💻 Developer

### Misbah Amjad

**Flutter Developer | Mobile App Developer**

BS Information Technology — University of Sahiwal

I developed NeuroNote as my Final Year Project and worked extensively with Flutter, Dart, Firebase, UI development, and AI-assisted learning functionality.

### Connect with me

* **GitHub:** https://github.com/Misbah-Amjad
* **LinkedIn:** https://www.linkedin.com/in/misbahh-amjad/

---

## 🔮 Future Improvements

Some possible future enhancements include:

* Offline learning support
* More advanced personalized recommendations
* Collaborative study groups
* Multiplayer study challenges
* Voice-based AI learning
* Expanded subject-specific learning resources
* Improved adaptive learning algorithms

---

## 📌 Project Status

**Academic / Portfolio Project**

NeuroNote is being maintained as a portfolio and demonstration project showcasing Flutter mobile development and AI-powered learning concepts.

---

### Built with Flutter ❤️

**NeuroNote — Study Smarter, Not Harder.**
