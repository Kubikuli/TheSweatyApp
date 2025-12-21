import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isBusy = false;
  String? _status;

  _BackupScope _exportScope = _BackupScope.everything;
  _BackupScope _importScope = _BackupScope.everything;

  bool get _exportWorkouts => _exportScope != _BackupScope.historyOnly;
  bool get _exportHistory => _exportScope != _BackupScope.workoutsOnly;
  bool get _importWorkouts => _importScope != _BackupScope.historyOnly;
  bool get _importHistory => _importScope != _BackupScope.workoutsOnly;

  Future<void> _exportBackup() async {
    final suggestedName = 'workout_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

    setState(() {
      _isBusy = true;
      _status = null;
    });

    try {
      final payload = await _backupService.buildBackupPayload(
        includeWorkouts: _exportWorkouts,
        includeHistory: _exportHistory,
      );
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

      final savedPath = await FileSaver.instance.saveFile(
        name: suggestedName,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );

      if (!mounted) return;

      if (savedPath.isEmpty) {
        _status = 'Export failed';
        _showSnack('Export failed: could not save file');
        return;
      }

      _status = 'Exported to $savedPath';
      _showSnack('Data exported to device Downloads folder');
    } catch (e) {
      if (!mounted) return;
      _status = 'Export failed';
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (picked == null) {
      return;
    }

    final path = picked.files.single.path;
    final bytes = picked.files.single.bytes;

    final scopeDescription = _importScope == _BackupScope.historyOnly
        ? 'Only history will be replaced (timer + workout sessions). Workouts stay unchanged.'
        : _importScope == _BackupScope.workoutsOnly
            ? 'Workouts will be merged (no deletion). History stays unchanged.'
            : 'Everything will be replaced: workouts, exercises, and history.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace existing data?'),
        content: Text(scopeDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isBusy = true;
      _status = null;
    });

    try {
      if (path != null) {
        await _backupService.importFromFile(
          path,
          importWorkouts: _importWorkouts,
          importHistory: _importHistory,
          clearWorkouts: _importScope == _BackupScope.everything,
          clearHistory: _importHistory,
        );
      } else if (bytes != null) {
        await _backupService.importFromJsonString(
          utf8.decode(bytes),
          importWorkouts: _importWorkouts,
          importHistory: _importHistory,
          clearWorkouts: _importScope == _BackupScope.everything,
          clearHistory: _importHistory,
        );
      } else {
        throw const FormatException('No file data found');
      }
      if (!mounted) return;
      _status = 'Import completed';
      _showSnack('Backup imported successfully');
    } catch (e) {
      if (!mounted) return;
      _status = 'Import failed';
      _showSnack('Import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Import'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Export',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ScopeSelector(
            title: 'What to export',
            value: _exportScope,
            onChanged: (v) => setState(() => _exportScope = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What is included:'),
                  const SizedBox(height: 8),
                  const Text('• 1. All the workout sets with exercises and details'),
                  const Text('• 2. Workout history and past timers'),
                  const Text('• 3. EVERYTHING'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export to JSON file'),
                    onPressed: _isBusy ? null : _exportBackup,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Import',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _ScopeSelector(
            title: 'What to import',
            value: _importScope,
            onChanged: (v) => setState(() => _importScope = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _importScope == _BackupScope.historyOnly
                        ? 'Only history will be replaced. Workouts stay unchanged.'
                        : _importScope == _BackupScope.workoutsOnly
                            ? 'Workouts will be merged (no deletion). History stays unchanged.'
                            : 'Everything will be replaced (workouts, timers, history).',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Import from JSON file'),
                    onPressed: _isBusy ? null : _importBackup,
                  ),
                ],
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(
              _status!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
          if (_isBusy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

enum _BackupScope { historyOnly, workoutsOnly, everything }

class _ScopeSelector extends StatelessWidget {
  final String title;
  final _BackupScope value;
  final ValueChanged<_BackupScope> onChanged;

  const _ScopeSelector({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        RadioListTile<_BackupScope>(
          title: const Text('History only'),
          subtitle: const Text('Workout + timer history'),
          value: _BackupScope.historyOnly,
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        RadioListTile<_BackupScope>(
          title: const Text('Workout presets only'),
          subtitle: const Text('Workout presets'),
          value: _BackupScope.workoutsOnly,
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        RadioListTile<_BackupScope>(
          title: const Text('Everything'),
          subtitle: const Text('Workout presets + history'),
          value: _BackupScope.everything,
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
