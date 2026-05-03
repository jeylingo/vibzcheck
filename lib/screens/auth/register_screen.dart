import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'registration_success_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final photoUrlController = TextEditingController();
  final preferredGenresController = TextEditingController();

  bool loading = false;
  String error = '';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    photoUrlController.dispose();
    preferredGenresController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      await AuthService().register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text.trim(),
        photoUrl: photoUrlController.text.trim(),
        preferredGenres: preferredGenresController.text
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationSuccessScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? 'Registration failed';
      });
    } catch (e) {
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            TextField(
              controller: photoUrlController,
              decoration: const InputDecoration(labelText: "Photo URL (optional)"),
            ),

            TextField(
              controller: preferredGenresController,
              decoration: const InputDecoration(labelText: "Preferred genres (comma separated)"),
            ),

            const SizedBox(height: 20),

            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),

            ElevatedButton(
              onPressed: loading ? null : register,
              child: Text(loading ? "Creating..." : "Register"),
            ),
          ],
        ),
      ),
    );
  }
}