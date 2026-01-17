# TheSweatyApp
A personalized Flutter workout tracking application with local database storage for managing workouts, tracking sessions, helping with timing during exercising, tracking your stats and more.

## 📋 Table of Contents
- [Overview](#overview)
- [Core Features](#core-features)
- [Technical Architecture](#technical-architecture)
- [Installation & Setup](#installation--setup)
- [User Guide](#user-guide)
- [Database Design](#database-design)
- [Project Structure](#project-structure)
- [Development](#development)
- [Version History](#version-history)

## Overview

**TheSweatyApp** is a fully-featured Flutter workout tracking application designed for personal fitness management. Built with local-first architecture using SQLite, the app provides comprehensive workout planning, execution tracking, statistical analysis, and flexible timer functionality—all while keeping your data private and offline-accessible.

**Current Version:** 1.2.6+9

### Key Highlights
- ✅ 100% offline functionality with local SQLite database
- ✅ Cross-platform support (iOS, Android, Web, Windows, macOS, Linux)
- ✅ Material Design 3 UI with dark theme support
- ✅ Zero external dependencies for core functionality
- ✅ Data backup and restore capabilities

## Core Features

### 📅 Calendar Overview
- **Weekly View**: Navigate through weeks with intuitive swipe gestures
- **Monthly View**: Full month calendar with workout session indicators
- **Session Indicators**: Visual dots showing workout activity per day
- **Quick Actions**: Start workouts directly from calendar dates
- **Historical Tracking**: Review past workout sessions with detailed information

### 💪 Workout Management
- **Custom Workouts**: Create personalized workout routines with custom names and exercies
- **Exercise Library**: Build exercises with configurable parameters:
  - Sets and repetitions
  - Weight tracking
  - Rest periods between sets
  - Exercise ordering
- **Workout Templates**: Save and reuse workout configurations
- **Edit Flexibility**: Modify existing workouts and exercises anytime
- **Color Coding**: Assign custom colors to workouts for better visual organization

### 🏃 Active Workout Execution
- **Guided Workflow**: Step-by-step exercise progression
- **Set Tracking**: Mark sets as completed with visual feedback
- **Auto Rest Timer**: Automatic countdown between sets
- **Progress Display**: Real-time workout completion status
- **Session Logging**: Automatic recording of start time and duration
- **Screen Wake Lock**: Keeps screen on during active workouts

### ⏱️ Flexible Timer
- Primarily designed for tracking **Plank** progression
- **Session History**: Save completed timer sessions
- **Weekly Statistics**: View timer usage grouped by week
- **Total Duration Tracking**: Check your per weeks statistics
- **Session Management**: Delete individual timer history entries
- **Background Persistence**: Timer keeps running even if you close the app
- **Push your goals**: Keeps track of your recent highest time

### 📊 Comprehensive Statistics
- **Time Range Filters**: overall or pick a custom time range for stats
- **Key Metrics**:
  - Total workouts completed
  - Average workouts per week
  - Total time spent working out
  - Last workout date
  - Total timer usage
  - Maximum timer session
- **Per-Workout Analytics**:
  - Completion counts by workout
  - Average duration per workout

### 💾 Backup & Restore
- **Export Data**: Create backup files of entire database
- **Import Data**: Restore from previous backups

### ⚙️ Settings & Customization
- **App Information**: Version number and build details
- **Data Management**: Access to backup/restore functionality
- **Theme Support**: Dark mode interface
- **Preferences**: Configurable app behavior via SharedPreferences
- **Reminders**: set reminders to keep yourself working out

### Pro user tips
- You can create two different order series for tracking different types of workouts. They need to be separated by at least one number(eg. First series with order numbers 1-4, second with orders 6-8)

## Technical Architecture

### Technology Stack
- **Framework**: Flutter 3.10.1+
- **Language**: Dart
- **Database**: SQLite (via sqflite)
- **State Management**: Provider pattern (ready for scaling)
- **Platform Support**: iOS, Android, Web, Windows, macOS, Linux

### Architectural Pattern
The app follows a **layered architecture** for maintainability and scalability:

```
┌─────────────────────────────────────┐
│     Presentation Layer              │
│  (Screens, Widgets, UI Logic)       │
├─────────────────────────────────────┤
│     Business Logic Layer            │
│  (Services, Data Operations)        │
├─────────────────────────────────────┤
│     Data Access Layer               │
│  (Database Helper, Models)          │
├─────────────────────────────────────┤
│     Data Persistence                │
│  (SQLite Database)                  │
└─────────────────────────────────────┘
```

### Core Dependencies
```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8      # iOS-style icons
  sqflite: ^2.3.0              # SQLite database
  path: ^1.9.0                 # File path manipulation
  intl: ^0.19.0                # Date/time formatting
  provider: ^6.1.1             # State management
  flutter_colorpicker: ^1.0.3  # Color selection UI
  wakelock_plus: ^1.4.0        # Screen wake lock
  shared_preferences: ^2.2.2   # Key-value storage
  package_info_plus: ^9.0.0    # App version info
  file_picker: ^8.0.0+1        # File selection
  file_saver: ^0.2.14          # File saving
  flutter_local_notifications: ^18.0.1  # Local notifications support
```

## Installation & Setup
(To just install the app you dont need any of the following)

### Prerequisites
- Flutter SDK 3.10.1 or higher
- Dart SDK ^3.10.1
- Platform-specific requirements:
  - **Android**: Android Studio, SDK 21+
  - **iOS**: Xcode, iOS 12.0+
  - **Windows**: Visual Studio 2022
  - **macOS**: Xcode
  - **Linux**: GTK development libraries

### Installation Steps

1. **Clone or download the project**
   ```bash
   cd workout_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify setup**
   ```bash
   flutter doctor
   ```

4. **Run on desired platform**
   ```bash
   # Android/iOS
   flutter run
   
   # Windows
   flutter run -d windows
   
   # Web
   flutter run -d chrome
   
   # macOS
   flutter run -d macos
   
   # Linux
   flutter run -d linux
   ```

### Building for Release

#### Android APK
```bash
flutter build apk --release
```

#### iOS
```bash
flutter build ios --release
```

#### Google Play Store release
```bash
flutter build appbundle --release
```

## User Guide

### Getting Started

#### Creating Your First Workout
1. Open the app and navigate to **Workouts** tab (dumbbell icon)
2. Tap the **+** (add) button in the app bar
3. Enter workout details:
   - **Name**: e.g., "Push"
   - **Description**: Optional details about the workout
   - **Color**: Tap color circle to choose a custom color
   - **Rest**: Rest period in seconds (e.g., 90)
   - **Order**: to help you rotating through the workouts
4. Add exercises by tapping **Add Exercise**:
   - **Exercise Name**: e.g., "Bench Press"
   - Long press on the exercise to customize following:
   - **Sets**: Number of sets (e.g., 3)
   - **Reps**: Repetitions per set (e.g., 10)
   - **Weight**: Weight in kg (e.g., 60)
5. Add more exercises as needed
6. Tap **Save** to create the workout

#### Performing a Workout
1. From **Calendar** tab, tap **Start Workout** button located on the current date
2. Select a workout from the list
3. The active workout screen will guide you through:
   - Current exercise name and parameters
   - Automatic rest timer between sets
   - Progress indicator
4. Rest timer starts automatically after completing each exercise
5. Tap **Finish Workout** when done to save the session

#### Using the Timer
1. Navigate to **Timer** tab (stopwatch icon)
2. Tap **Start** to begin timing
3. Controls available:
   - **Pause**: Temporarily stop the timer
   - **Resume**: Continue from paused state
   - **Save**: End session and save to history
   - **Reset**: Clear timer to 00:00:00
4. View timer history by tapping history icon (top-right)
5. Delete individual sessions by tapping delete icon on each entry

#### Viewing Statistics
1. Navigate to **Statistics** tab (in the side menu)
2. Select time range from dropdown:
   - All time
   - This year
   - Last 90 days
   - Last 30 days
   - Custom range (opens date picker)
3. Review metrics:
   - Overall workout statistics
   - Timer usage analytics
   - Per-workout breakdown

#### Managing Calendar
1. **Weekly View** (default):
   - Swipe left/right to navigate weeks
   - Colors indicate days with workout sessions and type of workout
   - Use **Start Workout** to begin new session
2. **Monthly View**:
   - Tap calendar icon to switch to month view
   - Navigate months with arrow buttons or with swiping
   - See workout distribution across the month

#### Backup & Restore
1. Open **Backup** tab (in the side menu)
2. **Export**:
   - Choose to export everything or only your workout presets
   - Create backup file and share
3. **Import**:
   - Select what you want to import
   - Choose file to import from

## Database Design

### Schema Overview

The application uses SQLite with four primary tables:

#### 1. `workouts` Table
Stores workout template information.

| Column       | Type    | Constraints          | Description                    |
|--------------|---------|----------------------|--------------------------------|
| id           | INTEGER | PRIMARY KEY          | Auto-incrementing workout ID   |
| name         | TEXT    | NOT NULL             | Workout name                   |
| description  | TEXT    |                      | Optional workout description   |
| color        | INTEGER | DEFAULT 4280391411   | Color value for UI display     |
| sort_order   | INTEGER | DEFAULT 0            | Custom sort ordering           |
| created_at   | TEXT    | NOT NULL             | ISO 8601 creation timestamp    |
| updated_at   | TEXT    | NOT NULL             | ISO 8601 last update timestamp |

#### 2. `exercises` Table
Stores exercises associated with workouts.

| Column       | Type    | Constraints                      | Description                  |
|--------------|---------|----------------------------------|------------------------------|
| id           | INTEGER | PRIMARY KEY                      | Auto-incrementing exercise ID|
| workout_id   | INTEGER | FOREIGN KEY → workouts(id)       | Parent workout reference     |
| name         | TEXT    | NOT NULL                         | Exercise name                |
| sets         | INTEGER | DEFAULT 0                        | Number of sets               |
| reps         | INTEGER | DEFAULT 0                        | Repetitions per set          |
| weight       | REAL    | DEFAULT 0                        | Weight in kg                 |
| rest_seconds | INTEGER | DEFAULT 0                        | Rest period between sets     |
| notes        | TEXT    |                                  | Exercise-specific notes      |
| order_index  | INTEGER | DEFAULT 0                        | Display order in workout     |

**Constraints**: Cascade delete when parent workout is deleted.

#### 3. `workout_sessions` Table
Tracks individual workout session executions.

| Column       | Type    | Constraints                      | Description                  |
|--------------|---------|----------------------------------|------------------------------|
| id           | INTEGER | PRIMARY KEY                      | Auto-incrementing session ID |
| workout_id   | INTEGER | FOREIGN KEY → workouts(id)       | Associated workout           |
| start_time   | TEXT    | NOT NULL                         | ISO 8601 session start       |
| end_time     | TEXT    |                                  | ISO 8601 session end         |
| notes        | TEXT    |                                  | Session notes                |
| is_completed | INTEGER | DEFAULT 0                        | Boolean completion flag      |

#### 4. `timer_sessions` Table
Records timer usage history.

| Column           | Type    | Constraints          | Description                  |
|------------------|---------|----------------------|------------------------------|
| id               | INTEGER | PRIMARY KEY          | Auto-incrementing session ID |
| start_time       | TEXT    | NOT NULL             | ISO 8601 timer start         |
| end_time         | TEXT    |                      | ISO 8601 timer end           |
| duration_seconds | INTEGER | NOT NULL             | Total duration in seconds    |
| notes            | TEXT    |                      | Optional session notes       |

## Project Structure

```
workout_app/
├── lib/
│   ├── main.dart                          # App entry point & theme
│   ├── database/
│   │   └── database_helper.dart           # SQLite database singleton
│   ├── models/
│   │   ├── workout.dart                   # Workout data model
│   │   ├── exercise.dart                  # Exercise data model
│   │   ├── workout_session.dart           # Session tracking model
│   │   └── timer_session.dart             # Timer session model
│   ├── services/
│   │   ├── workout_service.dart           # Workout CRUD operations
│   │   └── timer_service.dart             # Timer data operations
│   ├── screens/
│   │   ├── main_screen.dart               # Bottom navigation container
│   │   ├── calendar_screen.dart           # Weekly calendar view
│   │   ├── monthly_calendar_screen.dart   # Monthly calendar view
│   │   ├── select_workout_screen.dart     # Workout selection dialog
│   │   ├── active_workout_screen.dart     # Workout execution screen
│   │   ├── workouts_screen.dart           # Workout list management
│   │   ├── workout_detail_screen.dart     # Workout details & exercises
│   │   ├── create_edit_workout_screen.dart # Workout creation/editing
│   │   ├── timer_screen.dart              # Timer controls interface
│   │   ├── timer_history_screen.dart      # Timer session history
│   │   ├── statistics_screen.dart         # Analytics & stats display
│   │   ├── settings_screen.dart           # App settings & info
│   │   └── backup_screen.dart             # Backup/restore interface
│   ├── widgets/                            # Reusable custom widgets
│   ├── providers/                          # State management providers
│   └── utils/                              # Utility functions & helpers
├── android/                                # Android-specific files
├── ios/                                    # iOS-specific files
├── windows/                                # Windows-specific files
├── macos/                                  # macOS-specific files
├── linux/                                  # Linux-specific files
├── web/                                    # Web-specific files
├── test/                                   # Unit & widget tests
├── pubspec.yaml                            # Dependencies & metadata
├── analysis_options.yaml                   # Linter configuration
└── README.md                               # Primary documentation
```

## Version History

### v1.2.5+8 (Current)
- Added notifications
- Extended statistics
- Added new customization settings
- Many bugfixes and improvements

### Earlier Versions
- v1.2.x: Data export, calendar navigation by swiping with animation, settings
- v1.1.x: Added statistics, persistent screen for timer and active workout
- v1.0.x: Initial release with basic workout management

## Planned Features
- Advanced charts and visualizations
- Exercise images and video demonstrations
- Predefined exercise library
- Enhanced desing
- Audio cues and rest timer alerts
- Workout program templates

## Contributing
This is a personal project, but suggestions and feedback are welcome! Feel free to:
- Report bugs or issues
- Suggest new features
- Provide UX/UI feedback

## License
See [LICENSE](LICENSE) file for details.
