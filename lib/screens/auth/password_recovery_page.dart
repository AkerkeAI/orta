import 'package:flutter/material.dart';

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    super.key,
    required this.onPasswordUpdated,
    required this.onReturnToSignIn,
  });

  final Future<void> Function(String password) onPasswordUpdated;
  final Future<void> Function() onReturnToSignIn;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _updated = false;
  String? _message;

  Future<void> _updatePassword() async {
    if (_password.text.length < 8) {
      setState(() => _message = 'Use at least 8 characters for your password.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _message = 'The passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onPasswordUpdated(_password.text);
      if (mounted) {
        setState(() {
          _updated = true;
          _message = 'Your password has been changed.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not change the password. The recovery link may have expired. Request a new one and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToSignIn() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onReturnToSignIn();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Password changed. Sign out and sign in again with your new password.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F5FC),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      _updated ? 'Password updated' : 'Choose a new password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    if (!_updated) ...[
                      TextField(
                        controller: _password,
                        obscureText: true,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmation,
                        obscureText: true,
                        enabled: !_busy,
                        onSubmitted: (_) {
                          if (!_busy) _updatePassword();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Repeat new password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _updatePassword,
                        child: Text(_busy ? 'Saving…' : 'Save new password'),
                      ),
                    ] else
                      FilledButton(
                        onPressed: _busy ? null : _returnToSignIn,
                        child: Text(
                          _busy ? 'Please wait…' : 'Return to sign in',
                        ),
                      ),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
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
