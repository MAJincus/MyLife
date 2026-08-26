import 'package:flutter/material.dart';

import 'app_lock.dart';

/// Enveloppe l'app : affiche un écran de déverrouillage si un PIN est défini,
/// au démarrage et à chaque retour depuis l'arrière-plan.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _checked = false;
  bool _locked = false;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final enabled = await AppLock.isEnabled();
    setState(() {
      _locked = enabled;
      _checked = true;
    });
    if (enabled) _tryBiometric();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AppLock.isEnabled().then((enabled) {
        if (enabled && mounted) setState(() => _locked = true);
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (_authInProgress) return;
    if (!await AppLock.biometricEnabled()) return;
    if (!await AppLock.canUseBiometrics()) return;
    _authInProgress = true;
    final ok = await AppLock.authenticateBiometric();
    _authInProgress = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_checked && _locked)
          _LockScreen(
            onUnlocked: () => setState(() => _locked = false),
            onBiometric: _tryBiometric,
          ),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen({required this.onUnlocked, required this.onBiometric});
  final VoidCallback onUnlocked;
  final VoidCallback onBiometric;

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (await AppLock.verifyPin(_pin.text)) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Code incorrect');
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 56, color: scheme.primary),
              const SizedBox(height: 16),
              Text('MyLife verrouillé',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _pin,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '••••',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Déverrouiller'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Biométrie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
