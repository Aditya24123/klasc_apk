import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloud_store.dart';
import 'design.dart';
import 'main.dart' show Home;
import 'public_share.dart';

class CloudGate extends StatefulWidget {
  const CloudGate({super.key});
  @override
  State<CloudGate> createState() => _CloudGateState();
}

class _CloudGateState extends State<CloudGate> {
  late Future<bool> ready;
  @override
  void initState() {
    super.initState();
    ready = initialize();
  }

  Future<bool> initialize() async {
    const emulator = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    final config =
        jsonDecode(await rootBundle.loadString('assets/firebase-config.json'))
            as Map<String, dynamic>;
    if (!emulator && (config['apiKey'] as String).isEmpty) return false;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: FirebaseOptions(
              apiKey: emulator
                  ? 'AIzaSyDemoKlascForLocalEmulatorsOnly'
                  : config[kIsWeb ? 'apiKey' : 'apiKeyAndroid'] as String,
              appId: emulator
                  ? (kIsWeb
                      ? '1:1234567890:web:abcdef123456'
                      : '1:1234567890:android:abcdef123456')
                  : config[kIsWeb ? 'appIdWeb' : 'appIdAndroid'] as String,
              messagingSenderId: emulator
                  ? '1234567890'
                  : config['messagingSenderId'] as String,
              projectId:
                  emulator ? 'demo-klasc' : config['projectId'] as String,
              authDomain: emulator
                  ? 'demo-klasc.firebaseapp.com'
                  : config['authDomain'] as String));
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
      if (emulator) {
        const configuredHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
        final host = configuredHost.isNotEmpty
            ? configuredHost
            : (kIsWeb ? '127.0.0.1' : '10.0.2.2');
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      }
    }
    return true;
  }

  void retry() => setState(() => ready = initialize());
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            KlascMark(size: 70),
            SizedBox(height: 20),
            CircularProgressIndicator()
          ])));
        }
        if (snapshot.hasError) {
          return AuthScreen(
              cloudReady: false,
              setupError:
                  'Cloud connection is unavailable. Retry or use the library on this device.',
              retry: retry);
        }
        if (snapshot.data != true) {
          return AuthScreen(
              cloudReady: false,
              setupError:
                  'Cloud setup is pending. Your local library is available.',
              retry: retry);
        }
        if (kIsWeb && Uri.base.path.startsWith('/s/')) {
          return PublicItemPage(token: Uri.base.path.substring(3));
        }
        return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, authState) {
              if (authState.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              final user = authState.data;
              if (user == null) return const AuthScreen(cloudReady: true);
              return Home(
                  key: ValueKey(user.uid),
                  store: CloudItemStore(user.uid),
                  account: user.displayName,
                  onUpdateName: (name) => user.updateDisplayName(name),
                  onSignOut: () async {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    await FirebaseAuth.instance.signOut();
                  });
            });
      });
}

class AuthScreen extends StatefulWidget {
  final bool cloudReady;
  final String? setupError;
  final VoidCallback? retry;
  const AuthScreen(
      {super.key, required this.cloudReady, this.setupError, this.retry});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool registering = false, busy = false, showPassword = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (registering) {
        final account = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: email.text.trim(), password: password.text);
        if (name.text.trim().isNotEmpty) {
          await account.user?.updateDisplayName(name.text.trim());
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: BrandHeader()),
                            const SizedBox(height: 24),
                            LayoutBuilder(builder: (context, constraints) {
                              final hero = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const KlascMark(size: 76),
                                    const SizedBox(height: 18),
                                    const Text.rich(
                                        TextSpan(children: [
                                          TextSpan(text: 'KEEP WHAT\n'),
                                          TextSpan(
                                              text: 'MATTERS.',
                                              style: TextStyle(color: accent))
                                        ]),
                                        style: TextStyle(
                                            fontFamily: 'BebasNeue',
                                            fontSize: 58,
                                            height: .98,
                                            letterSpacing: .5)),
                                    const SizedBox(height: 12),
                                    const Text(
                                        'A thought. A useful link. A piece of code.\nSave it now. Find it when you need it.',
                                        style: TextStyle(
                                            color: muted,
                                            fontSize: 15,
                                            height: 1.6)),
                                    const SizedBox(height: 18),
                                    const Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _FeatureTile(
                                              icon: Icons.notes_rounded,
                                              label: 'Notes',
                                              color: accent,
                                              example:
                                                  'The idea worth keeping'),
                                          _FeatureTile(
                                              icon: Icons.link_rounded,
                                              label: 'Links',
                                              color: Color(0xffb7a5ff),
                                              example: 'Your next good read'),
                                          _FeatureTile(
                                              icon: Icons.code_rounded,
                                              label: 'Snippets',
                                              color: Color(0xffffd089),
                                              example:
                                                  'That useful little fix'),
                                          _FeatureTile(
                                              icon: Icons.image_outlined,
                                              label: 'Images',
                                              color: Color(0xff8bc8ef),
                                              example: 'A little inspiration'),
                                        ]),
                                    const SizedBox(height: 18),
                                    const Row(children: [
                                      Icon(Icons.lock_outline_rounded,
                                          size: 16, color: accent),
                                      SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              'Your account. Your private inbox.',
                                              style: TextStyle(
                                                  color: muted, fontSize: 12)))
                                    ]),
                                  ]);
                              final auth = Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: panel,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: line)),
                                  child: Form(
                                      key: form,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                                registering
                                                    ? 'MAKE IT YOURS.'
                                                    : 'WELCOME BACK.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium),
                                            const SizedBox(height: 6),
                                            Text(
                                                registering
                                                    ? 'Create your private inbox.'
                                                    : 'Pick up right where you left off.',
                                                style: const TextStyle(
                                                    color: muted)),
                                            const SizedBox(height: 16),
                                            SegmentedButton<bool>(
                                                direction:
                                                    MediaQuery.textScalerOf(
                                                                    context)
                                                                .scale(1) >
                                                            1.3
                                                        ? Axis.vertical
                                                        : Axis.horizontal,
                                                segments: const [
                                                  ButtonSegment(
                                                      value: false,
                                                      label: Text('Sign in')),
                                                  ButtonSegment(
                                                      value: true,
                                                      label: Text(
                                                          'Create account'))
                                                ],
                                                selected: {registering},
                                                onSelectionChanged: busy
                                                    ? null
                                                    : (value) => setState(() {
                                                          registering =
                                                              value.first;
                                                          error = null;
                                                        })),
                                            const SizedBox(height: 18),
                                            if (registering) ...[
                                              TextFormField(
                                                  controller: name,
                                                  enabled: !busy,
                                                  maxLength: 40,
                                                  decoration: const InputDecoration(
                                                      labelText:
                                                          'Display name (optional)')),
                                              const SizedBox(height: 12)
                                            ],
                                            TextFormField(
                                                controller: email,
                                                enabled:
                                                    widget.cloudReady && !busy,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                autofillHints: const [
                                                  AutofillHints.email
                                                ],
                                                decoration: const InputDecoration(
                                                    labelText: 'Email',
                                                    prefixIcon: Icon(Icons
                                                        .alternate_email_rounded)),
                                                validator: (v) => v == null ||
                                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                            .hasMatch(v.trim())
                                                    ? 'Enter a valid email address.'
                                                    : null),
                                            const SizedBox(height: 12),
                                            TextFormField(
                                                controller: password,
                                                enabled:
                                                    widget.cloudReady && !busy,
                                                obscureText: !showPassword,
                                                autofillHints: [
                                                  registering
                                                      ? AutofillHints
                                                          .newPassword
                                                      : AutofillHints.password
                                                ],
                                                decoration: InputDecoration(
                                                    labelText: 'Password',
                                                    prefixIcon: const Icon(Icons
                                                        .lock_outline_rounded),
                                                    suffixIcon: IconButton(
                                                        tooltip: showPassword
                                                            ? 'Hide password'
                                                            : 'Show password',
                                                        onPressed: () => setState(
                                                            () => showPassword =
                                                                !showPassword),
                                                        icon: Icon(showPassword
                                                            ? Icons
                                                                .visibility_off_outlined
                                                            : Icons
                                                                .visibility_outlined))),
                                                validator: (v) => (v ?? '')
                                                        .isEmpty
                                                    ? 'Enter your password.'
                                                    : registering &&
                                                            v!.length < 8
                                                        ? 'Use at least 8 characters.'
                                                        : null),
                                            if (error != null ||
                                                widget.setupError != null)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 12),
                                                  child: Text(
                                                      error ??
                                                          widget.setupError!,
                                                      style: const TextStyle(
                                                          color: Color(
                                                              0xffffa598)))),
                                            const SizedBox(height: 18),
                                            FilledButton.icon(
                                                onPressed:
                                                    !widget.cloudReady || busy
                                                        ? null
                                                        : submit,
                                                icon: busy
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2))
                                                    : const Icon(Icons
                                                        .arrow_forward_rounded),
                                                label: Text(busy
                                                    ? 'Connecting…'
                                                    : registering
                                                        ? 'Create my inbox'
                                                        : 'Sign in to KLASC')),
                                            if (!widget.cloudReady &&
                                                widget.retry != null)
                                              TextButton(
                                                  onPressed: widget.retry,
                                                  child: const Text(
                                                      'Retry cloud connection')),
                                            const SizedBox(height: 10),
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () => Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (_) =>
                                                                const Home())),
                                                child: const Text(
                                                    'Use this device only')),
                                            const Text(
                                                'Local mode stays on this device. Cloud mode follows your account.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: muted)),
                                          ])));
                              if (constraints.maxWidth >= 720) {
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: hero),
                                      const SizedBox(width: 28),
                                      Expanded(child: auth)
                                    ]);
                              }
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    hero,
                                    const SizedBox(height: 22),
                                    auth
                                  ]);
                            }),
                          ]))))));
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label, example;
  final Color color;
  const _FeatureTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.example});
  @override
  Widget build(BuildContext context) => Container(
      width: 166,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)))
        ]),
        const SizedBox(height: 9),
        Text(example, style: const TextStyle(fontSize: 11, color: muted)),
      ]));
}
