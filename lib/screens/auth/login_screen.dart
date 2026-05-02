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

  bool loading = false;
  String error = '';

  Future<void> login() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      await AuthService().login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()), // ✅ NO const
      );
    } catch (e) {
      setState(() {
        error = 'Login failed';
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Vibzcheck", style: TextStyle(fontSize: 32)),

              const SizedBox(height: 20),

              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),

              const SizedBox(height: 20),

              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),

              ElevatedButton(
                onPressed: loading ? null : login,
                child: Text(loading ? "Loading..." : "Login"),
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
                child: const Text("Create account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}