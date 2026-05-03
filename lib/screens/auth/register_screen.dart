import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  File? _profileImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

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
        profileImage: _profileImage,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[800],
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white54) : null,
              ),
            ),
            const SizedBox(height: 16),
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