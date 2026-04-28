import 'package:flutter/material.dart';

import '../../services/lock_service.dart';
import '../../theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _maybeBio();
  }

  Future<void> _maybeBio() async {
    if (await LockService.instance.isBioEnabled()) {
      final ok = await LockService.instance.tryBiometric();
      if (ok && mounted) widget.onUnlock();
    }
  }

  Future<void> _verify() async {
    final ok = await LockService.instance.verifyPin(_entered);
    if (ok && mounted) {
      widget.onUnlock();
    } else {
      setState(() {
        _error = 'Неверный PIN';
        _entered = '';
      });
    }
  }

  void _push(String d) {
    if (_entered.length >= 6) return;
    setState(() {
      _entered += d;
      _error = null;
    });
    if (_entered.length >= 4) _verify();
  }

  void _back() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              const Text('Введите PIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _entered.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? theme.colorScheme.primary : AppColors.muted,
                      ),
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (int i = 1; i <= 9; i++) _digit(i.toString()),
                  IconButton(
                    iconSize: 28,
                    onPressed: _maybeBio,
                    icon: const Icon(Icons.fingerprint),
                  ),
                  _digit('0'),
                  IconButton(
                    iconSize: 28,
                    onPressed: _back,
                    icon: const Icon(Icons.backspace_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _digit(String d) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: () => _push(d),
      child: Center(
        child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
