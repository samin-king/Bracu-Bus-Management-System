import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_message.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.auth, super.key});
  final AuthProvider auth;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final token = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    email.dispose();
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.directions_bus_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'BRACU Smart Transport',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('email'),
                              controller: email,
                              enabled: !auth.busy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'BRACU email',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter your BRACU email.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const Key('request-email'),
                              onPressed: auth.busy
                                  ? null
                                  : () {
                                      if (form.currentState!.validate()) {
                                        auth.requestEmail(email.text.trim());
                                      }
                                    },
                              child: const Text('Send sign-in link'),
                            ),
                            const SizedBox(height: 24),
                            if (auth.linkToken != null) ...[
                              const Text(
                                'Sign-in link received. Confirm to verify your email.',
                              ),
                              FilledButton(
                                key: const Key('verify-link'),
                                onPressed: auth.busy
                                    ? null
                                    : () => auth.verifyEmail(auth.linkToken!),
                                child: const Text('Verify email and sign in'),
                              ),
                            ],
                            TextField(
                              key: const Key('email-token'),
                              controller: token,
                              enabled: !auth.busy,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                labelText: 'Paste sign-in link or token',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('verify-email'),
                              onPressed: auth.busy || token.text.trim().isEmpty
                                  ? null
                                  : () {
                                      final value = token.text;
                                      token.clear();
                                      auth.verifyEmail(value);
                                    },
                              child: const Text('Verify and sign in'),
                            ),
                            if (auth.service.http.config.callback != null) ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                key: const Key('google-login'),
                                onPressed: auth.busy ? null : auth.googleLogin,
                                icon: const Icon(Icons.login),
                                label: const Text('Continue with BRACU Google'),
                              ),
                            ],
                            if (auth.busy)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            if (auth.error != null)
                              AuthMessage(auth.error!, isError: true),
                            if (auth.notice != null) AuthMessage(auth.notice!),
                            const SizedBox(height: 16),
                            const Text(
                              'For students and registered staff.\nUse your existing BRACU account.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
