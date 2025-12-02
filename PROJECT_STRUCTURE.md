# Workout App - Project Structure Overview

## Complete File Structure

```
lib/
├── main.dart                                   # App entry with MaterialApp setup
│
├── database/
│   └── database_helper.dart                   # SQLite database singleton with CRUD operations
│
├── models/
│   ├── workout.dart                           # Workout template model
│   ├── exercise.dart                          # Exercise model with sets/reps/weight
│   ├── workout_session.dart                   # Historical workout session model
│   └── timer_session.dart                     # Timer history model
│
├── services/
│   ├── workout_service.dart                   # Workout & exercise business logic
│   └── timer_service.dart                     # Timer session management
│
├── screens/
│   # Main Navigation
│   ├── main_screen.dart                       # Bottom nav with 3 tabs (Calendar, Workouts, Timer)
│   
│   # Calendar Flow
│   ├── calendar_screen.dart                   # Week view, navigate weeks, start workout button
│   ├── monthly_calendar_screen.dart           # Month view of workout sessions
│   ├── select_workout_screen.dart             # Choose workout to start
│   └── active_workout_screen.dart             # Active workout with exercise progression
│   
│   # Workouts Flow
│   ├── workouts_screen.dart                   # List all workouts
│   ├── workout_detail_screen.dart             # View workout details & exercises
│   └── create_edit_workout_screen.dart        # Create/edit workout form
│   
│   # Timer Flow
│   ├── timer_screen.dart                      # Timer with start/pause/stop controls
│   └── timer_history_screen.dart              # Weekly timer history view
│
├── widgets/                                    # Ready for custom reusable widgets
└── providers/                                  # Ready for state management
```

## Screen Navigation Flow

### Calendar Tab Flow:
```
CalendarScreen
    ├─> MonthlyCalendarScreen (view monthly overview)
    └─> SelectWorkoutScreen (start new workout)
            └─> ActiveWorkoutScreen (execute workout)
```

### Workouts Tab Flow:
```
WorkoutsScreen (list)
    ├─> WorkoutDetailScreen (view)
    │       ├─> CreateEditWorkoutScreen (edit)
    │       └─> Delete confirmation
    └─> CreateEditWorkoutScreen (create new)
```

### Timer Tab Flow:
```
TimerScreen (controls)
    └─> TimerHistoryScreen (weekly history)
```

## Database Tables

1. **workouts** - User-created workout templates
2. **exercises** - Exercises within workouts
3. **workout_sessions** - History of completed workouts
4. **timer_sessions** - History of timer usage
