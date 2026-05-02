import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  bool loading = false;
  String error = '';

  Future<void> login() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        error = 'Login failed. Check your email and password.';
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Vibzcheck',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Collaborative Music App'),
                const SizedBox(height: 32),

                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),

                const SizedBox(height: 20),

                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: loading ? null : login,
                  child: Text(loading ? 'Logging in...' : 'Login'),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}