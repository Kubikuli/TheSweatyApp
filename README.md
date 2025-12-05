# TheSweatyApp

A personalized Flutter workout tracking application with local database storage for managing workouts, tracking sessions, and timing exercises.

## Features

### 📅 Calendar Overview
- Weekly view with navigation between weeks
- Visual indicators showing workout sessions per day
- Monthly calendar view option
- Start new workouts directly from calendar
- Track workout history

### 💪 Workout Management
- Create custom workout routines
- Add exercises with sets, reps, weight, and rest periods
- Edit and delete existing workouts
- View detailed workout information
- Track workout sessions with start/end times

### ⏱️ Timer
- Fully functional timer with start, pause, resume, stop, and reset controls
- Automatic session saving to history
- Weekly history view with total duration tracking
- Delete individual timer sessions

### 🏃 Active Workout Mode
- Step-by-step exercise guidance
- Progress tracking through workout
- Automatic rest period management
- Set completion tracking
- Workout session logging

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── database/
│   └── database_helper.dart           # SQLite database management
├── models/
│   ├── workout.dart                   # Workout data model
│   ├── exercise.dart                  # Exercise data model
│   ├── workout_session.dart           # Workout session tracking model
│   └── timer_session.dart             # Timer session model
├── services/
│   ├── workout_service.dart           # Workout business logic
│   └── timer_service.dart             # Timer business logic
├── screens/
│   ├── main_screen.dart               # Bottom navigation container
│   ├── calendar_screen.dart           # Weekly calendar view
│   ├── monthly_calendar_screen.dart   # Monthly calendar view
│   ├── select_workout_screen.dart     # Workout selection for starting
│   ├── active_workout_screen.dart     # Active workout execution
│   ├── workouts_screen.dart           # Workout list
│   ├── workout_detail_screen.dart     # Workout details and exercises
│   ├── create_edit_workout_screen.dart # Create/edit workouts
│   ├── timer_screen.dart              # Timer controls
│   └── timer_history_screen.dart      # Timer session history
├── widgets/                            # Reusable custom widgets (ready for expansion)
└── providers/                          # State management (ready for expansion)
```

## Database Schema

### Tables
1. **workouts** - Stores workout templates
   - id, name, description, created_at, updated_at

2. **exercises** - Stores exercises for each workout
   - id, workout_id, name, sets, reps, weight, rest_seconds, notes, order_index

3. **workout_sessions** - Tracks completed workout sessions
   - id, workout_id, start_time, end_time, notes, is_completed

4. **timer_sessions** - Stores timer usage history
   - id, start_time, end_time, duration_seconds, notes

## Dependencies

- `sqflite` - Local SQLite database
- `path` - Path manipulation
- `intl` - Internationalization and date formatting
- `provider` - State management (ready for use)
- `cupertino_icons` - iOS-style icons

## Getting Started

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   flutter run
   ```

## Usage Flow

### Creating a Workout
1. Navigate to "Workouts" tab
2. Tap the "+" button
3. Enter workout name and optional description
4. Add exercises with sets, reps, weight, and rest periods
5. Save the workout

### Starting a Workout
1. From the Calendar screen, tap "Start Workout"
2. Select a workout from the list
3. Follow the on-screen instructions for each exercise
4. Complete sets and take rest periods
5. Finish the workout to save the session

### Using the Timer
1. Navigate to "Timer" tab
2. Tap "Start" to begin timing
3. Use Pause/Resume as needed
4. Tap "Stop" to save the session to history
5. View history by tapping the history icon

## Future Enhancements

- Exercise library with predefined exercises
- Progress tracking and statistics
- Charts and analytics
- Workout templates and sharing
- Rest timer countdown
- Exercise images and videos
- Cloud sync and backup
- Custom themes
- Export workout data

## Architecture

The app follows a layered architecture:
- **Presentation Layer**: Screens and widgets
- **Business Logic Layer**: Services for data operations
- **Data Layer**: Database helper and models

This structure ensures maintainability and scalability for future features.
