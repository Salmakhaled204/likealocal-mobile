import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// A dedicated Settings screen accessible from the Drawer.
/// Covers notification preferences, cache management, and account actions.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _proximityNotifications = true;
  bool _pushNotifications = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _proximityNotifications =
          prefs.getBool('setting_proximity_notifications') ?? true;
      _pushNotifications =
          prefs.getBool('setting_push_notifications') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_places_v1');
      await prefs.remove('cached_recommendations_v1');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to clear cache.')),
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete account. Please re-authenticate and try again. ($e)',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Notifications ──────────────────────────────────────────────────
          _SectionHeader('Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive general app updates',
            trailing: Switch(
              value: _pushNotifications,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) {
                setState(() => _pushNotifications = val);
                _savePref('setting_push_notifications', val);
              },
            ),
          ),
          _SettingsTile(
            icon: Icons.near_me_outlined,
            title: 'Proximity Notifications',
            subtitle: 'Alert when near a saved place',
            trailing: Switch(
              value: _proximityNotifications,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) {
                setState(() => _proximityNotifications = val);
                _savePref('setting_proximity_notifications', val);
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Storage & Cache ────────────────────────────────────────────────
          _SectionHeader('Storage & Offline'),
          _SettingsTile(
            icon: Icons.storage_outlined,
            title: 'Clear Cache',
            subtitle: 'Remove locally stored places data',
            trailing: _isClearing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: AppTheme.textLight),
            onTap: _isClearing ? null : _clearCache,
          ),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: '1.0.0 (Milestone 2)',
            trailing: const SizedBox.shrink(),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon.')),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Account ────────────────────────────────────────────────────────
          _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            subtitle: 'Sign out of your account',
            iconColor: AppTheme.peach,
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
            onTap: () async => await FirebaseAuth.instance.signOut(),
          ),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently remove your data',
            iconColor: Colors.red,
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
            onTap: _deleteAccount,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? AppTheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textLight),
        ),
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }
}
