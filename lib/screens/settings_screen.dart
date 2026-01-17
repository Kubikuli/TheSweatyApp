import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _dailyRemindersEnabled = false;
  bool _inexactDaily = false;
  int _reminderHour = 9;
  int _reminderMinute = 0;
  String _unitSystem = 'metric'; // 'metric' or 'imperial'
  int _handRestSeconds = 30;
  bool _rightHandFirst = true; // true: right->left, false: left->right
  final TextEditingController _handRestController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _handRestController.text = _handRestSeconds.toString();
    _loadSettings();
  }

  @override
  void dispose() {
    _handRestController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _dailyRemindersEnabled = prefs.getBool('daily_reminders_enabled') ?? false;
      _inexactDaily = prefs.getBool('daily_reminders_inexact') ?? false;
      _reminderHour = prefs.getInt('reminder_hour') ?? 9;
      _reminderMinute = prefs.getInt('reminder_minute') ?? 0;
      _unitSystem = prefs.getString('unit_system') ?? 'metric';
      _handRestSeconds = prefs.getInt('hand_rest_seconds') ?? 30;
      _rightHandFirst = (prefs.getString('hand_order') ?? 'right_left') != 'left_right';
      _handRestController.text = _handRestSeconds.toString();
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _updateReminder(bool enabled, {int? hour, int? minute}) async {
    final prefs = await SharedPreferences.getInstance();
    final finalHour = hour ?? _reminderHour;
    final finalMinute = minute ?? _reminderMinute;

    if (enabled) {
      // Schedule the reminder
      if (_inexactDaily) {
        await NotificationService.instance
            .scheduleDailyWorkoutReminderPeriodic(hour: finalHour, minute: finalMinute);
      } else {
        await NotificationService.instance
            .scheduleDailyWorkoutReminder(hour: finalHour, minute: finalMinute);
      }
    } else {
      // Cancel the reminder
      await NotificationService.instance.cancelReminders();
    }

    await prefs.setBool('daily_reminders_enabled', enabled);
  }

  void _showTimePickerDialog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );

    if (time != null) {
      setState(() {
        _reminderHour = time.hour;
        _reminderMinute = time.minute;
      });

      if (_dailyRemindersEnabled) {
        await _updateReminder(true, hour: time.hour, minute: time.minute);
      }
    }
  }

  Future<void> _resetToDefaults() async {
    const defaultSound = true;
    const defaultUnit = 'metric';
    const defaultHandRest = 30;
    const defaultHandOrder = 'right_left';

    setState(() {
      _soundEnabled = defaultSound;
      _dailyRemindersEnabled = true;
      _reminderHour = 15;
      _reminderMinute = 0;
      _unitSystem = defaultUnit;
      _handRestSeconds = defaultHandRest;
      _rightHandFirst = true;
      _handRestController.text = defaultHandRest.toString();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', defaultSound);
    await prefs.setBool('daily_reminders_enabled', false);
    await prefs.setString('unit_system', defaultUnit);
    await prefs.setInt('hand_rest_seconds', defaultHandRest);
    await prefs.setString('hand_order', defaultHandOrder);
    
    // Cancel any scheduled reminders
    await NotificationService.instance.cancelReminders();
    
    // Reset theme to default
    if (mounted) {
      context.read<ThemeProvider>().resetToDefault();
    }
  }

  Future<void> _confirmAndRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore defaults?'),
        content: const Text('This will reset all settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _resetToDefaults();
    }
  }

  void _showColorPicker(BuildContext context) {
    Color current = context.read<ThemeProvider>().primaryColor;
    Color temp = current;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ThemeProvider>().setPrimaryColor(temp);
              Navigator.pop(context);
            },
            child: const Text('Use Color'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          children: [
          const ListTile(
            title: Text('General'),
          ),
          SwitchListTile(
            title: const Text('Daily Workout Reminder'),
            subtitle: const Text('Get reminded if you haven\'t worked out today'),
            value: _dailyRemindersEnabled,
            onChanged: (v) async {
              setState(() => _dailyRemindersEnabled = v);
              await _updateReminder(v);
            },
          ),
          if (_dailyRemindersEnabled)
            SwitchListTile(
              title: const Text('Approximate timing (battery-friendly)'),
              subtitle: const Text('Repeat roughly every 24h; ignores exact clock time'),
              value: _inexactDaily,
              onChanged: (v) async {
                setState(() => _inexactDaily = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('daily_reminders_inexact', v);
                // Reschedule according to new mode
                await _updateReminder(true);
              },
            ),
          if (_dailyRemindersEnabled)
            ListTile(
              title: const Text('Reminder Time'),
              subtitle: Text(
                '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.schedule),
              onTap: _showTimePickerDialog,
            ),
          SwitchListTile(
            title: const Text('Sound'),
            subtitle: const Text('Play timer sounds during active workout'),
            value: _soundEnabled,
            onChanged: (v) async {
              setState(() => _soundEnabled = v);
              await _saveBool('sound_enabled', v);
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Appearance'),
          ),
          ListTile(
            title: const Text('Primary Color'),
            subtitle: const Text('Choose your theme color'),
            trailing: GestureDetector(
              onTap: () => _showColorPicker(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.read<ThemeProvider>().primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 2),
                ),
              ),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Units'),
          ),
          ListTile(
            title: const Text('Measurement System'),
            subtitle: Text(_unitSystem == 'metric' ? 'Metric (kg)' : 'Imperial (lb)'),
            trailing: DropdownButton<String>(
              value: _unitSystem,
              items: const [
                DropdownMenuItem(value: 'metric', child: Text('Metric')),
                DropdownMenuItem(value: 'imperial', child: Text('Imperial')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _unitSystem = v);
                await _saveString('unit_system', v);
              },
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Per-hand settings'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Per-hand rest'),
                const Spacer(),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _handRestController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Seconds',
                      filled: true,
                      fillColor: const Color.fromARGB(255, 36, 36, 36),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      labelStyle: const TextStyle(color: Color.fromARGB(255, 180, 180, 180)),
                      hintStyle: const TextStyle(color: Color.fromARGB(255, 130, 130, 130)),
                    ),
                    onChanged: (value) async {
                      final parsed = int.tryParse(value);
                      final seconds = parsed != null && parsed >= 0 ? parsed : 0;
                      setState(() => _handRestSeconds = seconds);
                      await _saveInt('hand_rest_seconds', seconds);
                    },
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Hand order'),
            subtitle: Text(_rightHandFirst ? 'Right → Left' : 'Left → Right'),
            value: _rightHandFirst,
            onChanged: (v) async {
              setState(() => _rightHandFirst = v);
              await _saveString('hand_order', v ? 'right_left' : 'left_right');
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('Restore defaults'),
                onPressed: _confirmAndRestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
