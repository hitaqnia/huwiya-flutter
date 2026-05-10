import 'package:flutter/material.dart';
import 'package:huwiya_sdk/huwiya_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HuwiyaSDK.initialize(
    const HuwiyaConfig(
      baseUrl: 'https://id.example.com',
      projectId: 'your-project-id',
      clientId: 'your-client-id',
      redirectUri: 'com.example.app://auth/callback',
      scopes: ['openid', 'profile'],
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huwiya SDK Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sdk = HuwiyaSDK.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Huwiya SDK Example')),
      body: Center(
        child: StreamBuilder<AuthState>(
          stream: sdk.authStateStream,
          initialData: const Unauthenticated(),
          builder: (context, snapshot) {
            final state = snapshot.data ?? const Unauthenticated();
            return switch (state) {
              Unauthenticated() => _SignInButton(sdk: sdk),
              Authenticating() => const CircularProgressIndicator(),
              Authenticated(:final user) => _UserView(user: user, sdk: sdk),
              Refreshing(:final user) => _UserView(
                user: user,
                sdk: sdk,
                refreshing: true,
              ),
              AuthError(:final error) => Text(
                'Error: ${error.message}',
                style: const TextStyle(color: Colors.red),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.sdk});

  final HuwiyaSDK sdk;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.login),
      label: const Text('Sign in with Huwiya'),
      onPressed: () async {
        try {
          await sdk.signIn();
        } on UserCancelledException {
          // User closed the browser — silent.
        } on HuwiyaException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    );
  }
}

class _UserView extends StatelessWidget {
  const _UserView({
    required this.user,
    required this.sdk,
    this.refreshing = false,
  });

  final HuwiyaUser user;
  final HuwiyaSDK sdk;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Welcome, ${user.name}!', style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 8),
        Text('id: ${user.id}'),
        Text('locale: ${user.locale} · zone: ${user.zoneinfo}'),
        if (refreshing) ...[
          const SizedBox(height: 16),
          const Text('Refreshing token…'),
        ],
        const SizedBox(height: 24),
        TextButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          onPressed: () => sdk.signOut(),
        ),
      ],
    );
  }
}
