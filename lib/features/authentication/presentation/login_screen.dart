import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/localization/app_localizations.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await ref.read(authControllerProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
      if (!mounted) return;
      if (!success) {
        final error = ref.read(authControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error?.toString() ?? context.tr('loginFailed')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo
                      Icon(
                        Icons.shield,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('appName'),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        context.tr('appSubtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Email Field
                      Text(
                        context.tr('email'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          hintText: 'admin@evidencehub.com',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('invalidEmail');
                          }
                          // Simple regex validation
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return context.tr('invalidEmail');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('password'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Mock: Reset instructions sent to ${_emailController.text}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Text(
                              context.tr('forgotPassword'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          hintText: '••••••',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty || value.length < 6) {
                            return context.tr('invalidPassword');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _submit,
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(context.tr('loginBtn')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
