import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_text_field.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../auth/domain/entities/auth_provider.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/auth_page_scaffold.dart';
import 'register_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  static const String routeName = '/sign-in';

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
      AuthSignInRequested(email: _email.text.trim(), password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (BuildContext context, AuthState state) {
          final bool isLoading = state is AuthLoading;
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Center(
                  child: SectionLabel(
                    'Sign in to sync your bills',
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PaperTextField(
                  label: 'Email Address',
                  hint: 'your@name.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: FormValidators.email,
                ),
                const SizedBox(height: AppSpacing.lg),
                PaperTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  validator: (String? value) => FormValidators.required(
                    value,
                    message: 'Password is required',
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  labelTrailing: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset is coming soon.'),
                      ),
                    ),
                    child: const SectionLabel(
                      'Forgot?',
                      color: AppColors.inkMuted,
                      size: 10,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PaperButton(
                  label: 'Sign In',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xl),
                const _OrDivider(label: 'Or use Socials'),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PaperButton(
                        label: 'Google',
                        icon: Icons.g_mobiledata,
                        variant: PaperButtonVariant.secondary,
                        onPressed: isLoading
                            ? null
                            : () => context.read<AuthBloc>().add(
                                const AuthProviderSignInRequested(
                                  AuthProvider.google,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PaperButton(
                        label: 'Apple',
                        icon: Icons.apple,
                        variant: PaperButtonVariant.secondary,
                        onPressed: isLoading
                            ? null
                            : () => context.read<AuthBloc>().add(
                                const AuthProviderSignInRequested(
                                  AuthProvider.apple,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AuthFooterPrompt(
                  prompt: 'New here?',
                  action: 'Create account',
                  onTap: () =>
                      Navigator.of(context).pushNamed(RegisterPage.routeName),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Centred caption between two rules, used between the form and socials.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: AppFonts.display(size: 13, color: AppColors.inkMuted),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
