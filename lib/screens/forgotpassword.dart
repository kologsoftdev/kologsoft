import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formkey = GlobalKey<FormState>();

  bool isLoading = false;

  Future<void> resetPassword() async {

 if(!formkey.currentState!.validate()) {
      setState(() => isLoading = false);
      return;
    }
 setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset email sent. Check your inbox.",style: TextStyle(color: Colors.white),),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'missing-email':
          message = 'Please enter your email address.';
          break;

        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
        case 'user-not-found':
          message = 'No account found with that email.';
          break;
        default:
          message = e.message ?? 'Something went wrong.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() => isLoading = false);
  }
  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 400,
            width: 400,
            child: Form(
              key: formkey,
              child: Column(
                children: [
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Enter email",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter your email";
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                        return "Please enter a valid email";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : resetPassword,
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Send Reset Email",style: TextStyle(color: Colors.white70),),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}