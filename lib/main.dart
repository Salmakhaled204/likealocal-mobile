import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/home_provider.dart';
import 'providers/reviews_provider.dart';
import 'providers/search_provider.dart';
import 'providers/user_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => ReviewsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          cardColor: Colors.white,
        ),
        home: AuthWrapper(),
      ),
    );
  }
}

// 🔐 Check if user logged in
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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

        final user = snapshot.data;
        if (user != null) {
          return FutureBuilder<void>(
            future: context.read<UserProvider>().ensureUserDocument(user),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return HomeScreen();
            },
          );
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

// The new HomeScreen is imported from screens/home_screen.dart

// 🔐 Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String error = "";
  bool isLoading = false;
  bool isSignupMode = false;

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      _setError(_authErrorMessage(e));
    } catch (e) {
      _setError("Login failed. Please try again.");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = userCredential.user!;
      await user.updateDisplayName(nameController.text.trim());

      try {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
          {
            "email": emailController.text.trim(),
            "displayName": nameController.text.trim(),
            "bio": "",
            "phone": "",
            "chatEnabled": true,
            "publicProfile": true,
            "preferredCategories": <String>[],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } on FirebaseException catch (e) {
        debugPrint("User profile setup failed: ${e.message}");
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authErrorMessage(e));
    } catch (e) {
      _setError("Signup failed. Please try again.");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      _setError("Enter your email first, then tap Forgot password.");
      return;
    }

    setState(() {
      isLoading = true;
      error = "";
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _setError("Password reset email sent.");
    } on FirebaseAuthException catch (e) {
      _setError(_authErrorMessage(e));
    } catch (e) {
      _setError("Could not send reset email. Please try again.");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "Email already in use. Try logging in instead.";
      case 'invalid-email':
        return "Invalid email format.";
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return "Incorrect email or password.";
      case 'operation-not-allowed':
        return "Email/password login is not enabled in Firebase Console.";
      case 'weak-password':
        return "Password must be at least 6 characters.";
      case 'network-request-failed':
        return "Network error. Check your internet connection.";
      default:
        return e.message ?? "Authentication failed.";
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      error = message;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isSignupMode ? "Create Account" : "Login")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isSignupMode ? "Create your account" : "Welcome back",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              if (isSignupMode) ...[
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: "Display name"),
                  validator: (value) {
                    if (!isSignupMode) return null;
                    final name = value?.trim() ?? "";
                    if (name.isEmpty) return "Display name is required";
                    if (name.length < 2) return "Name is too short";
                    return null;
                  },
                ),
                SizedBox(height: 12),
              ],
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: "Email"),
                validator: (value) {
                  final email = value?.trim() ?? "";
                  if (email.isEmpty) return "Email is required";
                  if (!email.contains("@")) return "Enter a valid email";
                  return null;
                },
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                autofillHints: isSignupMode
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                decoration: InputDecoration(labelText: "Password"),
                validator: (value) {
                  final password = value ?? "";
                  if (password.isEmpty) return "Password is required";
                  if (password.length < 6) {
                    return "Password must be at least 6 characters";
                  }
                  return null;
                },
              ),
              if (isSignupMode) ...[
                SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(labelText: "Confirm password"),
                  validator: (value) {
                    if (!isSignupMode) return null;
                    if (value != passwordController.text) {
                      return "Passwords do not match";
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: 20),
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: isSignupMode ? signup : login,
                  child: Text(isSignupMode ? "Sign Up" : "Login"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      error = "";
                      isSignupMode = !isSignupMode;
                    });
                  },
                  child: Text(
                    isSignupMode
                        ? "Already have an account? Login"
                        : "Need an account? Sign up",
                  ),
                ),
                if (!isSignupMode)
                  TextButton(
                    onPressed: resetPassword,
                    child: Text("Forgot password?"),
                  ),
              ],
              SizedBox(height: 10),
              if (error.isNotEmpty)
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
