import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_panel.dart';

class DesktopAuthScreen extends ConsumerStatefulWidget {
  const DesktopAuthScreen({super.key});

  @override
  ConsumerState<DesktopAuthScreen> createState() => _DesktopAuthScreenState();
}

class _DesktopAuthScreenState extends ConsumerState<DesktopAuthScreen> {
  bool _isRegister = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      if (_isRegister) {
        final res = await client.post('/auth/register', body: {
          'email': email,
          'password': password,
          'name': _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : 'Enterprise Admin',
          'companyName': _companyController.text.trim().isNotEmpty
              ? _companyController.text.trim()
              : 'My Business',
        });

        final data = res is Map ? (res['data'] ?? res) : {};
        final token = data['token'] ?? data['accessToken'] ?? 'demo_token';
        final user = data['user'] ?? {};
        final userId = user['id'] ?? 'user_1';
        final companyId = user['companyId'] ?? user['company_id'] ?? 'comp_1';

        await ref.read(sessionProvider.notifier).applyLogin(
          accessToken: token.toString(),
          userId: userId.toString(),
          companyId: companyId.toString(),
          companyName: _companyController.text.trim(),
          email: email,
          name: _nameController.text.trim(),
        );
      } else {
        final res = await client.post('/auth/login', body: {
          'email': email,
          'password': password,
        });

        final data = res is Map ? (res['data'] ?? res) : {};
        final token = data['token'] ?? data['accessToken'] ?? 'demo_token';
        final user = data['user'] ?? {};
        final userId = user['id'] ?? 'user_1';
        final companyId = user['companyId'] ?? user['company_id'] ?? 'comp_1';
        final companyName = user['companyName'] ?? user['company_name'] ?? 'Enterprise';

        await ref.read(sessionProvider.notifier).applyLogin(
          accessToken: token.toString(),
          userId: userId.toString(),
          companyId: companyId.toString(),
          companyName: companyName.toString(),
          email: email,
          name: (user['name'] ?? 'Admin').toString(),
          role: (user['role'] ?? 'owner').toString(),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Connection error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: Row(
          children: [
            // Left Hero Pane (Branded Enterprise Showcase)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo & Title
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.aiGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.electricBlue.withOpacity(0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODIRI AI',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'ENTERPRISE DESKTOP',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: AppColors.electricBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Center Headline & Features
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Intelligent Business Operations,\nBuilt for Speed & Scale.',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Windows native edition with zero-latency POS, offline-first SQLite sync, dual-currency reporting, and AI-powered business analytics.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _buildFeaturePill(Icons.speed, 'High-Performance POS & Multi-Cart Architecture'),
                        const SizedBox(height: 14),
                        _buildFeaturePill(Icons.shield_outlined, 'Strict Multi-Tenant Isolation & Encryption'),
                        const SizedBox(height: 14),
                        _buildFeaturePill(Icons.cloud_sync_outlined, 'Seamless Cloud Sync to PostgreSQL & Render'),
                      ],
                    ),

                    // Bottom System Status
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.neonEmerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Production Node.js API Online (Render)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Vertical subtle divider
            Container(width: 1, color: AppColors.borderDark.withOpacity(0.5)),

            // Right Form Pane
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isRegister ? 'Create Enterprise Account' : 'Welcome to Modiri AI',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRegister
                                ? 'Sign up to manage your sales, stock, and reports'
                                : 'Sign in with your enterprise credentials to continue',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.neonRose.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.neonRose.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 18, color: AppColors.neonRose),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.neonRose,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          if (_isRegister) ...[
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Your Full Name',
                                prefixIcon: Icon(Icons.person_outline, size: 18),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _companyController,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Company Name',
                                prefixIcon: Icon(Icons.business_outlined, size: 18),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.mail_outline, size: 18),
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, size: 18),
                            ),
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.cyberNavyDeep,
                                    ),
                                  )
                                : Text(_isRegister ? 'Register & Open Console' : 'Sign In to Workspace'),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isRegister
                                    ? 'Already have an account? '
                                    : "Don't have an enterprise account? ",
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isRegister = !_isRegister;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  _isRegister ? 'Sign In' : 'Sign Up',
                                  style: const TextStyle(
                                    color: AppColors.electricBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevatedDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Icon(icon, size: 16, color: AppColors.electricBlue),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
