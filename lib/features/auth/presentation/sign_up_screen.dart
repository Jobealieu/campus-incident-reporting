import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../application/auth_providers.dart';
import '../domain/email_policy.dart';
import 'widgets/auth_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .signUp(_name.text, _email.text, _password.text);
    // On success the router moves to the email verification screen.
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
      showBack: true,
      title: 'Create your account',
      subtitle:
          'Only @alustudent.com and @alueducation.com emails can join. '
          "We'll send you a verification link.",
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.requiredText(
                  'Full name',
                  min: 2,
                  max: 60,
                ),
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
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
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Confirm password',
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match' : null,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Create account',
                isLoading: isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
