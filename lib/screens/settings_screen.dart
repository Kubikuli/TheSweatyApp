import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
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
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
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

  Future<void> _resetToDefaults() async {
    const defaultNotifications = true;
    const defaultSound = true;
    const defaultUnit = 'metric';
    const defaultHandRest = 30;
    const defaultHandOrder = 'right_left';

    setState(() {
      _notificationsEnabled = defaultNotifications;
      _soundEnabled = defaultSound;
      _unitSystem = defaultUnit;
      _handRestSeconds = defaultHandRest;
      _rightHandFirst = true;
      _handRestController.text = defaultHandRest.toString();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', defaultNotifications);
    await prefs.setBool('sound_enabled', defaultSound);
    await prefs.setString('unit_system', defaultUnit);
    await prefs.setInt('hand_rest_seconds', defaultHandRest);
    await prefs.setString('hand_order', defaultHandOrder);
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
            title: const Text('Notifications'),
            subtitle: const Text('Enable workout reminders and alerts'),
            value: _notificationsEnabled,
            onChanged: (v) async {
              setState(() => _notificationsEnabled = v);
              await _saveBool('notifications_enabled', v);
            },
          ),
          SwitchListTile(
            title: const Text('Sound'),
            subtitle: const Text('Play sounds for timers'),
            value: _soundEnabled,
            onChanged: (v) async {
              setState(() => _soundEnabled = v);
              await _saveBool('sound_enabled', v);
            },
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
