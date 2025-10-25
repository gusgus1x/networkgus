import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final mode = themeProvider.themeMode;
    final theme = Theme.of(context);

    void setMode(ThemeMode m) => context.read<ThemeProvider>().setThemeMode(m);

    Widget buildRadio({
      required ThemeMode value,
      required String title,
      String? subtitle,
      required IconData icon,
    }) {
      final selected = mode == value;
      return InkWell(
        onTap: () => setMode(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: selected ? theme.colorScheme.primary : theme.iconTheme.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ),
                  ],
                ),
              ),
              Radio<ThemeMode>(
                value: value,
                groupValue: mode,
                onChanged: (_) => setMode(value),
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section card
          Text('Appearance', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                buildRadio(value: ThemeMode.light, title: 'Light', icon: Icons.light_mode_outlined),
                Divider(height: 1, color: theme.dividerColor),
                buildRadio(value: ThemeMode.dark, title: 'Dark', icon: Icons.dark_mode_outlined),
                Divider(height: 1, color: theme.dividerColor),
                buildRadio(value: ThemeMode.system, title: 'System default', subtitle: 'Follow device theme', icon: Icons.phone_iphone),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Logout section card
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
