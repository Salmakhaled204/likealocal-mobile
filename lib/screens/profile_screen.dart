import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../providers/search_provider.dart';
import 'chat_list_screen.dart';

/// lib/screens/profile_screen.dart
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _areaController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final List<String> _allCategories = [
    'Restaurants',
    'Hidden Gems',
    'Experiences',
    'Cafes',
    'Nightlife',
    'Museum',
    'Shopping',
  ];
  final List<String> _budgets = ['', 'Cheap', 'Medium', 'Expensive'];
  final List<String> _atmospheres = [
    '',
    'Quiet',
    'Fun',
    'Family',
    'Friends',
    'Romantic',
  ];
  final List<String> _timeOptions = const [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
  ];

  List<String> _selectedPreferences = [];
  String _budgetPreference = '';
  String _atmospherePreference = '';
  bool _chatEnabled = true;
  bool _chatScheduleEnabled = false;
  String _chatStartTime = '10:00';
  String _chatEndTime = '18:00';
  bool _publicProfile = true;
  bool _aiRecommendationsEnabled = true;
  UserRole _userRole = UserRole.regularFree();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _photoUrlController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _error = 'Please sign in to view your profile.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['displayName'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _photoUrlController.text = data['photoUrl'] ?? '';
        _selectedPreferences = List<String>.from(data['preferences'] ?? []);
        _budgetPreference = data['budgetPreference'] ?? '';
        _atmospherePreference = data['atmospherePreference'] ?? '';
        _areaController.text = data['areaPreference'] ?? '';
        _chatEnabled = data['chatEnabled'] ?? true;
        final schedule = data['chatSchedule'];
        if (schedule is Map<String, dynamic>) {
          _chatScheduleEnabled = schedule['enabled'] == true;
          _chatStartTime = (schedule['startTime'] ?? '10:00').toString();
          _chatEndTime = (schedule['endTime'] ?? '18:00').toString();
        }
        _publicProfile = data['publicProfile'] ?? true;
        _aiRecommendationsEnabled = data['aiRecommendationsEnabled'] ?? true;
        _userRole = UserRole.fromData(data);
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(
              UserRole.defaultFirestoreData(
                uid: uid,
                email: user.email ?? '',
                name: user.displayName ?? '',
                photoUrl: user.photoURL ?? '',
              ),
            );
      }
    } catch (e) {
      _error = 'Failed to load profile';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _error = 'Please sign in to save your profile.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': name,
        'bio': _bioController.text.trim(),
        'photoUrl': _photoUrlController.text.trim(),
        'preferences': _selectedPreferences,
        'budgetPreference': _budgetPreference,
        'atmospherePreference': _atmospherePreference,
        'areaPreference': _areaController.text.trim(),
        'aiRecommendationsEnabled': _aiRecommendationsEnabled,
        'chatEnabled': _chatEnabled,
        'chatSchedule': {
          'enabled': _chatScheduleEnabled,
          'startTime': _chatStartTime,
          'endTime': _chatEndTime,
        },
        'publicProfile': _publicProfile,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        context.read<SearchProvider>().setDiscoveryPreferences(
          categories: _selectedPreferences,
          budget: _budgetPreference,
          atmosphere: _atmospherePreference,
          area: _areaController.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
      }
    } catch (e) {
      setState(() => _error = 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'My Profile',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.blue[100],
                        backgroundImage:
                            _photoUrlController.text.trim().isNotEmpty
                            ? NetworkImage(_photoUrlController.text.trim())
                            : null,
                        child: _photoUrlController.text.trim().isEmpty
                            ? Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        FirebaseAuth.instance.currentUser?.email ?? '',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RoleSummary(role: _userRole),
                    const SizedBox(height: 12),
                    _RoleActions(role: _userRole),
                    const SizedBox(height: 28),

                    // Display Name
                    Text(
                      'Display Name',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name cannot be empty'
                          : v.trim().length < 2
                          ? 'Name is too short'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Your name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Photo URL',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _photoUrlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/photo.jpg',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Bio
                    Text(
                      'Bio',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      maxLength: 160,
                      decoration: InputDecoration(
                        hintText: 'Tell others about yourself…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Preferences
                    Text(
                      'Preferences',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'My Interests',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Used to personalise your recommendations.',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allCategories.map((cat) {
                        final selected = _selectedPreferences.contains(cat);
                        return FilterChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (val) => setState(() {
                            if (val) {
                              _selectedPreferences.add(cat);
                            } else {
                              _selectedPreferences.remove(cat);
                            }
                          }),
                          selectedColor: Colors.blue.withValues(alpha: 0.15),
                          checkmarkColor: Colors.blue,
                          labelStyle: GoogleFonts.inter(
                            color: selected ? Colors.blue : Colors.black87,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _budgetPreference,
                      decoration: InputDecoration(
                        labelText: 'Budget preference',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _budgets
                          .map(
                            (budget) => DropdownMenuItem(
                              value: budget,
                              child: Text(
                                budget.isEmpty ? 'Any budget' : budget,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _budgetPreference = value ?? ''),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _atmospherePreference,
                      decoration: InputDecoration(
                        labelText: 'Atmosphere / vibe preference',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _atmospheres
                          .map(
                            (atmosphere) => DropdownMenuItem(
                              value: atmosphere,
                              child: Text(
                                atmosphere.isEmpty ? 'Any vibe' : atmosphere,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _atmospherePreference = value ?? ''),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _areaController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Preferred area / location',
                        hintText: 'e.g. Zamalek, Maadi, Downtown',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Messages shortcut
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.blueAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'My Messages',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_userRole.isAdmin) ...[
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/admin/reports'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: Colors.deepPurple,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Moderation Reports',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Settings
                    Text(
                      'Settings',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.settings_outlined,
                              color: Colors.blueGrey,
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Open Settings',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          'AI recommendations',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Use your preferences for smarter suggestions',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: _aiRecommendationsEnabled,
                        onChanged: (val) =>
                            setState(() => _aiRecommendationsEnabled = val),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Privacy
                    Text(
                      'Privacy',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          'Allow chat messages',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Other users can message you about places',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: _chatEnabled,
                        onChanged: (val) => setState(() => _chatEnabled = val),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Chat availability schedule',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                            subtitle: Text(
                              'Only allow chats during your available hours',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            value: _chatScheduleEnabled,
                            onChanged: (val) =>
                                setState(() => _chatScheduleEnabled = val),
                          ),
                          if (_chatScheduleEnabled)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _chatStartTime,
                                    decoration: const InputDecoration(
                                      labelText: 'Start',
                                    ),
                                    items: _timeOptions
                                        .map(
                                          (time) => DropdownMenuItem(
                                            value: time,
                                            child: Text(time),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => _chatStartTime = value ?? '10:00',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _chatEndTime,
                                    decoration: const InputDecoration(
                                      labelText: 'End',
                                    ),
                                    items: _timeOptions
                                        .map(
                                          (time) => DropdownMenuItem(
                                            value: time,
                                            child: Text(time),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(
                                      () => _chatEndTime = value ?? '18:00',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          'Public profile',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        subtitle: Text(
                          'Allow others to see your name and bio',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: _publicProfile,
                        onChanged: (val) =>
                            setState(() => _publicProfile = val),
                      ),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: Text(
                          'Logout',
                          style: GoogleFonts.inter(color: Colors.redAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async =>
                            await FirebaseAuth.instance.signOut(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RoleSummary extends StatelessWidget {
  final UserRole role;

  const _RoleSummary({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = role.isAdmin
        ? Colors.red[700]!
        : role.isSuperUser
        ? Colors.amber[700]!
        : role.isPremium
        ? Colors.purple[600]!
        : role.isContributor
        ? Colors.green[700]!
        : Colors.blue[700]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(_roleIcon(role), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  role.benefitText,
                  style: GoogleFonts.inter(
                    color: Colors.grey[700],
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pins ${role.limits.pinsUsed}/${role.maxPins} | Reminders ${role.limits.remindersUsed}/${role.maxReminders} | AI/day ${role.maxAiRequestsPerDay}',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    if (role.isAdmin) return Icons.admin_panel_settings_outlined;
    if (role.isSuperUser) return Icons.workspace_premium;
    if (role.isPremium) return Icons.diamond_outlined;
    if (role.isContributor) return Icons.add_location_alt_outlined;
    return Icons.person_outline;
  }
}

class _RoleActions extends StatelessWidget {
  final UserRole role;
<<<<<<<<< Temporary merge branch 1
  final VoidCallback onBecomeContributor;

  const _RoleActions({
    required this.role,
    required this.onBecomeContributor,
  });
=========

  const _RoleActions({required this.role});
>>>>>>>>> Temporary merge branch 2

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (role.isRegular)
          Text(
            'Contributor access is reviewed by an admin before place uploads are enabled.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
        if (!role.isPremium)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Premium is assigned through Firebase/admin setup, not by a client-side demo toggle.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        if (role.isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Admin access is assigned manually in Firebase and cannot be edited here.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}
