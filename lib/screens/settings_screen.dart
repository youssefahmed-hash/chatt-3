import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(

      appBar: AppBar(
        title: const Text("Settings"),
      ),

      body: ListView(

        children: [

          const SizedBox(height: 20),

          const ListTile(

            title: Text(
              "Appearance",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

          ),

          RadioListTile<ThemeMode>(

            title: const Text("Light"),

            value: ThemeMode.light,

            groupValue: themeProvider.themeMode,

            onChanged: (mode) {

              if (mode != null) {
                themeProvider.setTheme(mode);
              }

            },
          ),

          RadioListTile<ThemeMode>(

            title: const Text("Dark"),

            value: ThemeMode.dark,

            groupValue: themeProvider.themeMode,

            onChanged: (mode) {

              if (mode != null) {
                themeProvider.setTheme(mode);
              }

            },
          ),

          RadioListTile<ThemeMode>(

            title: const Text("System Default"),

            value: ThemeMode.system,

            groupValue: themeProvider.themeMode,

            onChanged: (mode) {

              if (mode != null) {
                themeProvider.setTheme(mode);
              }

            },
          ),
        ],
      ),
    );
  }
}