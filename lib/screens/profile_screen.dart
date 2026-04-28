import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  String email = "";
  String name = "";
  bool chatEnabled = true;

  bool isLoading = true;

  final nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  // 🔹 Load user data from Firebase
  Future<void> loadUserData() async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(uid)
        .get();

    if (snapshot.exists) {
      setState(() {
        email = snapshot.child("email").value.toString();
        name = snapshot.child("name").value?.toString() ?? "";
        chatEnabled = snapshot.child("chatEnabled").value as bool;

        nameController.text = name;
        isLoading = false;
      });
    }
  }

  // 🔹 Update profile
  Future<void> updateProfile() async {
    await FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(uid)
        .update({
      "name": nameController.text.trim(),
      "chatEnabled": chatEnabled,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Profile updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Profile")),

      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 📧 Email (read only)
            Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(email),

            SizedBox(height: 20),

            // 👤 Name (editable)
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Name"),
            ),

            SizedBox(height: 20),

            // 🔒 Chat Preference
            SwitchListTile(
              title: Text("Enable Chat"),
              value: chatEnabled,
              onChanged: (value) {
                setState(() {
                  chatEnabled = value;
                });
              },
            ),

            SizedBox(height: 20),

            // 💾 Save Button
            ElevatedButton(
              onPressed: updateProfile,
              child: Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}