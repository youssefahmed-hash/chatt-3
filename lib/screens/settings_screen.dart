import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(
              l10n.appearance,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          RadioListTile<ThemeMode>(
            title: Text(l10n.light),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (mode) {
              if (mode != null) {
                themeProvider.setTheme(mode);
              }
            },
          ),

          RadioListTile<ThemeMode>(
            title: Text(l10n.dark),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (mode) {
              if (mode != null) {
                themeProvider.setTheme(mode);
              }
            },
          ),

          RadioListTile<ThemeMode>(
            title: Text(l10n.systemDefault),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (mode) {
              if (mode != null) {
                themeProvider.setTheme(mode);
              }
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(l10n.language),
            subtitle: Text(
              localeProvider.locale?.languageCode == 'ar'
                  ? l10n.arabic
                  : l10n.english,
            ),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () => _pickLanguage(context),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.read<LocaleProvider>();

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: Text(l10n.english),
              selected: localeProvider.locale?.languageCode == 'en',
              onTap: () {
                localeProvider.setLocale(const Locale('en'));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check),
              title: Text(l10n.arabic),
              selected: localeProvider.locale?.languageCode == 'ar',
              onTap: () {
                localeProvider.setLocale(const Locale('ar'));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: Text(l10n.systemDefault),
              selected: localeProvider.locale == null,
              onTap: () {
                localeProvider.clearLocale();
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}