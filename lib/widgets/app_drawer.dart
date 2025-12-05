import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.black87),
            child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 20)),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Statistics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/statistics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup & Export'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
