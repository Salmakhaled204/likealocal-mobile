import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
    );
  }
}

// 🔐 Check if user logged in
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

// 🏠 Home Screen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
          child: Text("Logout"),
        ),
      ),
    );
  }
}

// 🔐 Login Screen
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String error = "";
  bool isLoading = false;

  // 🔹 LOGIN FUNCTION
  Future<void> login() async {
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
      } else if (e.code == 'invalid-email') {
        error = "Invalid email format";
      } else {
        error = e.message ?? "Login failed";
      }
      setState(() {});
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  // 🔹 SIGNUP FUNCTION (WITH DATABASE SAVE)
  Future<void> signup() async {
    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      // 1. Create user in Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2. Get UID
      String uid = userCredential.user!.uid;

      // 3. Save user in Realtime Database
      final dbRef = FirebaseDatabase.instance.ref();

      await dbRef.child("users").child(uid).set({
        "email": emailController.text.trim(),
        "chatEnabled": true,
        "createdAt": DateTime.now().toString(),
      });

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        error = "Email already in use";
      } else if (e.code == 'weak-password') {
        error = "Password must be at least 6 characters";
      } else if (e.code == 'invalid-email') {
        error = "Invalid email format";
      } else {
        error = e.message ?? "Signup failed";
      }
      setState(() {});
    } catch (e) {
      setState(() {
        error = e.toString();
      });
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
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),

            SizedBox(height: 20),

            if (isLoading) CircularProgressIndicator(),

            SizedBox(height: 10),

            ElevatedButton(
              onPressed: login,
              child: Text("Login"),
            ),

            ElevatedButton(
              onPressed: signup,
              child: Text("Sign Up"),
            ),

            SizedBox(height: 10),

            Text(error, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}