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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _unitSystem = prefs.getString('unit_system') ?? 'metric';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
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
            subtitle: const Text('Play sounds for timer and alerts'),
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
            subtitle: Text(_unitSystem == 'metric' ? 'Metric (kg, m)' : 'Imperial (lb, ft)'),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'These settings are saved on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
