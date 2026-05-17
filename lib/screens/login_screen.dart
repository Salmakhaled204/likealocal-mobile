import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String error = "";
  bool isLoading = false;

  // 🔹 VALIDATION FUNCTION
  bool validateInputs() {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        error = "Please fill all fields";
      });
      return false;
    }

    if (!emailController.text.contains("@")) {
      setState(() {
        error = "Invalid email format";
      });
      return false;
    }

    if (passwordController.text.length < 6) {
      setState(() {
        error = "Password must be at least 6 characters";
      });
      return false;
    }

    return true;
  }

  // 🔹 LOGIN FUNCTION
  Future<void> login() async {
    if (!validateInputs()) return;

    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        error = "No user found for this email";
      } else if (e.code == 'wrong-password') {
        error = "Wrong password";
      } else {
        error = e.message ?? "Login failed";
      }
    } catch (e) {
      error = e.toString();
    }

    setState(() {
      isLoading = false;
    });
  }

  // 🔹 SIGNUP FUNCTION
  Future<void> signup() async {
    if (!validateInputs()) return;

    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      // Create user
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // Save user in database
      final dbRef = FirebaseDatabase.instance.ref();

      await dbRef.child("users").child(uid).set({
        "email": emailController.text.trim(),
        "name": "New User", // ⭐ important for profile
        "chatEnabled": true,
        "createdAt": DateTime.now().toString(),
      });

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        error = "Email already in use";
      } else if (e.code == 'weak-password') {
        error = "Weak password";
      } else {
        error = e.message ?? "Signup failed";
      }
    } catch (e) {
      error = e.toString();
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),

      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [

            // 📧 Email
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),

            // 🔑 Password
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),

            SizedBox(height: 20),

            if (isLoading) CircularProgressIndicator(),

            SizedBox(height: 10),

            // 🔐 Login
            ElevatedButton(
              onPressed: login,
              child: Text("Login"),
            ),

            // 🆕 Signup
            ElevatedButton(
              onPressed: signup,
              child: Text("Sign Up"),
            ),

            SizedBox(height: 10),

            // ❌ Error message
            Text(
              error,
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}