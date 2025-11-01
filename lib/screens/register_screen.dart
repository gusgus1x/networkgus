import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _passwordFieldKey = GlobalKey();
  final GlobalKey _fullNameFieldKey = GlobalKey();
  final GlobalKey _usernameFieldKey = GlobalKey();
  final GlobalKey _emailFieldKey = GlobalKey();

  bool _showPasswordTips = false;
  bool _showFullNameTips = false;
  bool _showUsernameTips = false;
  bool _showEmailTips = false;

  bool _passwordObscured = true;
  bool _confirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setState(() => _showPasswordTips = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _passwordFieldKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.2,
              curve: Curves.easeInOut,
            );
          }
        });
      } else {
        setState(() => _showPasswordTips = false);
      }
    });

    _fullNameFocusNode.addListener(() {
      if (_fullNameFocusNode.hasFocus) {
        setState(() => _showFullNameTips = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _fullNameFieldKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.2,
              curve: Curves.easeInOut,
            );
          }
        });
      } else {
        setState(() => _showFullNameTips = false);
      }
    });

    _usernameFocusNode.addListener(() {
      if (_usernameFocusNode.hasFocus) {
        setState(() => _showUsernameTips = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _usernameFieldKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.2,
              curve: Curves.easeInOut,
            );
          }
        });
      } else {
        setState(() => _showUsernameTips = false);
      }
    });

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        setState(() => _showEmailTips = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _emailFieldKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.2,
              curve: Curves.easeInOut,
            );
          }
        });
      } else {
        setState(() => _showEmailTips = false);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _displayNameController.text.trim(),
        _usernameController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        // AppWrapper will navigate to Home when auth changes; pop this screen
        Navigator.pop(context);
      } else {
        final err = authProvider.lastError ?? 'Sign up failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1F1F1F),
              Color(0xFFFF8A00),
            ],
            stops: [0.0, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              final paddingBottom = (bottomInset > 0) ? bottomInset + 16 : 32.0;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(32, 32, 32, paddingBottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - bottomInset),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: Offset(0, 10)),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text('DekSomBun', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        const Text('Create your account', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 40),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                                const SizedBox(height: 8),
                                Text('Sign up to see photos and videos from your friends.',
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
                                const SizedBox(height: 32),

                                _buildTextField(
                                  fieldKey: _fullNameFieldKey,
                                  controller: _displayNameController,
                                  label: 'Full Name',
                                  hintText: 'e.g., John Appleseed',
                                  icon: Icons.person_outline,
                                  focusNode: _fullNameFocusNode,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_showFullNameTips)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Full name tips', style: TextStyle(fontWeight: FontWeight.w700)),
                                        SizedBox(height: 8),
                                        Text('• Use your real name'),
                                        SizedBox(height: 4),
                                        Text('• Example: John Appleseed'),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  fieldKey: _usernameFieldKey,
                                  controller: _usernameController,
                                  label: 'Username',
                                  hintText: 'e.g., johnny_99',
                                  icon: Icons.alternate_email,
                                  focusNode: _usernameFocusNode,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Please enter a username';
                                    if (value.contains(' ')) return 'Username cannot contain spaces';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_showUsernameTips)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Username tips', style: TextStyle(fontWeight: FontWeight.w700)),
                                        SizedBox(height: 8),
                                        Text('• 3–20 characters'),
                                        SizedBox(height: 4),
                                        Text('• Letters, numbers, underscores; no spaces'),
                                        SizedBox(height: 4),
                                        Text('• Example: johnny_99'),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  fieldKey: _emailFieldKey,
                                  controller: _emailController,
                                  label: 'Email',
                                  hintText: 'e.g., name@example.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  focusNode: _emailFocusNode,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Please enter your email';
                                    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+").hasMatch(value)) return 'Please enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_showEmailTips)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Email tips', style: TextStyle(fontWeight: FontWeight.w700)),
                                        SizedBox(height: 8),
                                        Text('• Use a valid address you can access'),
                                        SizedBox(height: 4),
                                        Text('• Example: name@example.com'),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  fieldKey: _passwordFieldKey,
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _passwordObscured,
                                  focusNode: _passwordFocusNode,
                                  onToggleObscure: () => setState(() => _passwordObscured = !_passwordObscured),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please enter your password';
                                    if (value.length < 6) return 'Password must be at least 6 characters';
                                    final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
                                    final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\]~+=]').hasMatch(value);
                                    if (!hasUppercase) return 'Password must contain at least one uppercase letter';
                                    if (!hasSpecial) return 'Password must contain at least one special character';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_showPasswordTips)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Password requirements', style: TextStyle(fontWeight: FontWeight.w700)),
                                        SizedBox(height: 8),
                                        Text('• At least 6 characters'),
                                        SizedBox(height: 4),
                                        Text('• At least 1 uppercase letter (A–Z)'),
                                        SizedBox(height: 4),
                                        Text('• At least 1 special character (e.g. ! @ # \$ %)'),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  icon: Icons.lock_reset_outlined,
                                  obscureText: _confirmPasswordObscured,
                                  onToggleObscure: () => setState(() => _confirmPasswordObscured = !_confirmPasswordObscured),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please confirm your password';
                                    if (value != _passwordController.text) return 'Passwords do not match';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, child) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: authProvider.isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFFF8A00),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                        ),
                                        child: authProvider.isLoading
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
                            child: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Log In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                      decorationThickness: 2.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                );
            },
          ),
        ),
      ),
    );
  }

  // (Popup version removed per request)

  Widget _buildTextField({
    Key? fieldKey,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? helperText,
    String? hintText,
    FocusNode? focusNode,
    VoidCallback? onTap,
    VoidCallback? onToggleObscure,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      focusNode: focusNode,
      onTap: onTap,
      style: const TextStyle(color: Colors.black),
      cursorColor: Colors.black,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black87),
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black45),
        helperText: helperText,
        helperMaxLines: 3,
        helperStyle: const TextStyle(color: Colors.black54, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.black87),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black87),
                onPressed: onToggleObscure,
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black54)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black54)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
