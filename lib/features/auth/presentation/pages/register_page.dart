import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_checkbox.dart';
import '../../../../core/widgets/paper_text_field.dart';
import '../../../../core/widgets/section_label.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/auth_page_scaffold.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  static const String routeName = '/register';

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _agreed = false;
  bool _showAgreementError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final bool formIsValid = _formKey.currentState?.validate() ?? false;
    if (!_agreed) setState(() => _showAgreementError = true);
    if (!formIsValid || !_agreed) return;
    context.read<AuthBloc>().add(
          AuthRegisterRequested(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          ),
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
                  'Join the Fold',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Center(
                  child: SectionLabel(
                    'Start tracking like a pro',
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PaperTextField(
                  label: 'Full Name',
                  hint: 'John Doe',
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.name],
                  validator: (String? value) =>
                      FormValidators.required(value, message: 'Name is required'),
                ),
                const SizedBox(height: AppSpacing.lg),
                PaperTextField(
                  label: 'Email Address',
                  hint: 'your@email.com',
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
                  autofillHints: const <String>[AutofillHints.newPassword],
                  validator: FormValidators.password,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                PaperCheckbox(
                  value: _agreed,
                  onChanged: (bool value) => setState(() {
                    _agreed = value;
                    _showAgreementError = false;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: AppFonts.display(size: 13, color: AppColors.inkMuted),
                      children: <TextSpan>[
                        const TextSpan(text: 'I agree to the '),
                        _linkSpan('Rules of the Paper'),
                        const TextSpan(text: ' & '),
                        _linkSpan('Privacy Policy'),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
                if (_showAgreementError) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Please accept the terms to continue',
                    style: AppFonts.display(
                      size: 12,
                      color: const Color(0xFFB3261E),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PaperButton(
                  label: 'Register',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AuthFooterPrompt(
                  prompt: 'Already a member?',
                  action: 'Sign in',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TextSpan _linkSpan(String text) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.accent,
        decorationThickness: 2.5,
      ),
    );
  }
}
