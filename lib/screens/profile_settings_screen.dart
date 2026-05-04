import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _hasLoadedInitialData = false;
  bool _chatEnabled = true;
  bool _publicProfile = true;
  final List<String> _preferredCategories = [];

  final List<String> _availableCategories = const [
    'Restaurants',
    'Hidden Gems',
    'Experiences',
    'Cafes',
    'Nightlife',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Profile & Privacy',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: context.read<UserProvider>().watchCurrentUserProfile(),
        builder: (context, snapshot) {
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Please log in to view your profile.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey[700]),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !_hasLoadedInitialData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && !_hasLoadedInitialData) {
            _loadInitialData(const {}, user);
          }

          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          _loadInitialData(data, user);

          return Consumer<UserProvider>(
            builder: (context, provider, child) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        title: 'Profile',
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final name = value?.trim() ?? '';
                              if (name.isEmpty) return 'Display name is required';
                              if (name.length < 2) return 'Name is too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: user.email,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bioController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: provider.isSaving
                                ? null
                                : () => _saveProfile(provider),
                            child: const Text('Save Profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Privacy & Preferences',
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable chat'),
                            subtitle: const Text(
                              'Allow other users and place owners to message you.',
                            ),
                            value: _chatEnabled,
                            onChanged: provider.isSaving
                                ? null
                                : (value) => _savePrivacy(
                                      provider,
                                      chatEnabled: value,
                                      publicProfile: _publicProfile,
                                      preferredCategories:
                                          List<String>.from(_preferredCategories),
                                    ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Public profile'),
                            subtitle: const Text(
                              'Show your profile name with reviews.',
                            ),
                            value: _publicProfile,
                            onChanged: provider.isSaving
                                ? null
                                : (value) => _savePrivacy(
                                      provider,
                                      chatEnabled: _chatEnabled,
                                      publicProfile: value,
                                      preferredCategories:
                                          List<String>.from(_preferredCategories),
                                    ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Preferred categories',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableCategories.map((category) {
                              final selected =
                                  _preferredCategories.contains(category);
                              return FilterChip(
                                label: Text(category),
                                selected: selected,
                                onSelected: provider.isSaving
                                    ? null
                                    : (_) {
                                        final next = List<String>.from(
                                          _preferredCategories,
                                        );
                                        if (selected) {
                                          next.remove(category);
                                        } else {
                                          next.add(category);
                                        }
                                        _savePrivacy(
                                          provider,
                                          chatEnabled: _chatEnabled,
                                          publicProfile: _publicProfile,
                                          preferredCategories: next,
                                        );
                                      },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      if (provider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          provider.errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _loadInitialData(Map<String, dynamic> data, User? user) {
    if (_hasLoadedInitialData) return;
    _nameController.text = data['displayName'] ?? user?.displayName ?? '';
    _bioController.text = data['bio'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _chatEnabled = data['chatEnabled'] ?? true;
    _publicProfile = data['publicProfile'] ?? true;
    _preferredCategories
      ..clear()
      ..addAll(_readStringList(data['preferredCategories']));
    _hasLoadedInitialData = true;
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  Future<void> _saveProfile(UserProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    await provider.updateProfile(
      displayName: _nameController.text,
      bio: _bioController.text,
      phone: _phoneController.text,
    );

    if (!mounted || provider.errorMessage != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> _savePrivacy(
    UserProvider provider, {
    required bool chatEnabled,
    required bool publicProfile,
    required List<String> preferredCategories,
  }) async {
    final nextCategories = List<String>.from(preferredCategories);

    setState(() {
      _chatEnabled = chatEnabled;
      _publicProfile = publicProfile;
      _preferredCategories
        ..clear()
        ..addAll(nextCategories);
    });

    await provider.updatePrivacySettings(
      chatEnabled: chatEnabled,
      publicProfile: publicProfile,
      preferredCategories: nextCategories,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
