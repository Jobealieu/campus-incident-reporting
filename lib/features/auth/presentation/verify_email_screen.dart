import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_scaffold.dart';

/// Blocks access to the app until the ALU email address is verified.
/// Polls in the background so the user doesn't have to tap anything after
/// clicking the link in their inbox.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _resendCooldown = 60;

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownLeft = _resendCooldown;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check(silent: true));
    _startCooldown();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownLeft <= 1) timer.cancel();
      setState(() => _cooldownLeft--);
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = !silent);
    try {
      final verified = await ref
          .read(authRepositoryProvider)
          .refreshVerificationStatus();
      if (!verified && !silent && mounted) {
        context.showSnack(
          'Not verified yet. Check your inbox and spam folder.',
        );
      }
      // When verified, the token refresh triggers the router redirect.
    } catch (error) {
      if (!silent && mounted) {
        context.showSnack(describeError(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    final sent = await ref
        .read(authControllerProvider.notifier)
        .resendVerificationEmail();
    if (!mounted) return;
    if (sent) {
      context.showSnack('Verification email sent.');
      _startCooldown();
    } else {
      context.showSnack(
        describeError(ref.read(authControllerProvider).error!),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).value?.email ?? 'your inbox';
    final canResend = _cooldownLeft <= 0;

    return AuthScaffold(
      title: 'Verify your email',
      subtitle:
          'We sent a verification link to $email. Open it to activate '
          'your account. This page updates automatically.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoadingButton(
            label: "I've verified my email",
            icon: Icons.verified_outlined,
            isLoading: _checking,
            onPressed: _check,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: canResend ? _resend : null,
            child: Text(
              canResend ? 'Resend email' : 'Resend in ${_cooldownLeft}s',
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
