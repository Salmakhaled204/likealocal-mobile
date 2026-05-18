import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _aiRecommendationsEnabled = true;
  bool _publicProfile = true;
  bool _chatEnabled = true;
  bool _loading = true;
  bool _saving = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final data = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _aiRecommendationsEnabled = data['aiRecommendationsEnabled'] != false;
      _publicProfile = data['publicProfile'] != false;
      _chatEnabled = data['chatEnabled'] != false;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(_uid).set({
      'aiRecommendationsEnabled': _aiRecommendationsEnabled,
      'publicProfile': _publicProfile,
      'chatEnabled': _chatEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SwitchRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI recommendations',
                  subtitle: 'Use your saved preferences for suggestions.',
                  value: _aiRecommendationsEnabled,
                  onChanged: (value) =>
                      setState(() => _aiRecommendationsEnabled = value),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Public profile',
                  subtitle: 'Show your contributor profile to other users.',
                  value: _publicProfile,
                  onChanged: (value) => setState(() => _publicProfile = value),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Allow chat messages',
                  subtitle: 'Let users message you about places.',
                  value: _chatEnabled,
                  onChanged: (value) => setState(() => _chatEnabled = value),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveSettings,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Settings'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
