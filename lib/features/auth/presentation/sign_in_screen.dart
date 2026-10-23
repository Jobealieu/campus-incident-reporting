import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/auth_providers.dart';
import '../domain/email_policy.dart';
import 'widgets/auth_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text, _password.text);
    // On success the router redirects automatically.
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, state) {
      if (state.hasError) {
        context.showSnack(describeError(state.error!), isError: true);
      }
    });
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle:
          'Sign in with your ALU account to report and track campus '
          'issues.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: EmailPolicy.validate,
                decoration: const InputDecoration(
                  labelText: 'ALU email',
                  hintText: 'name@alustudent.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Password is required' : null,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              LoadingButton(
                label: 'Sign in',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('New to CampusFix?'),
                  TextButton(
                    onPressed: () => context.push('/sign-up'),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
