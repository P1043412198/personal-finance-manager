import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/lock_service.dart';
import '../../utils/i18n.dart';
import '../../widgets/section.dart';

class LockSettingsScreen extends StatefulWidget {
  const LockSettingsScreen({super.key});

  @override
  State<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends State<LockSettingsScreen> {
  bool _enabled = false;
  bool _bio = false;
  bool _hasPin = false;
  int _autolock = 60;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = LockService.instance;
    final e = await s.isEnabled();
    final b = await s.isBioEnabled();
    final h = await s.hasPin();
    final a = await s.autolockSeconds();
    if (mounted) setState(() {
      _enabled = e;
      _bio = b;
      _hasPin = h;
      _autolock = a;
    });
  }

  Future<void> _setPin() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новый PIN (4–6 цифр)'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true && c.text.length >= 4) {
      await LockService.instance.setPin(c.text);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('lock_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(children: [
              SwitchListTile(
                value: _enabled,
                title: Text(i18n.t('enable_lock')),
                onChanged: (v) async {
                  if (v && !_hasPin) {
                    await _setPin();
                  }
                  await LockService.instance.setEnabled(v && (await LockService.instance.hasPin()));
                  _load();
                },
              ),
              SwitchListTile(
                value: _bio,
                title: Text(i18n.t('biometric')),
                onChanged: !_enabled ? null : (v) async {
                  if (v) {
                    final ok = await LockService.instance.tryBiometric();
                    if (!ok) return;
                  }
                  await LockService.instance.setBioEnabled(v);
                  _load();
                },
              ),
              ListTile(
                title: Text(i18n.t('change_pin')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _setPin,
              ),
              ListTile(
                title: Text(i18n.t('autolock')),
                subtitle: Text('$_autolock сек.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final v = await showDialog<int>(
                    context: context,
                    builder: (_) => SimpleDialog(
                      title: const Text('Авто-блокировка через'),
                      children: [
                        for (final s in [0, 30, 60, 300, 900])
                          SimpleDialogOption(
                            child: Text(s == 0 ? 'Сразу' : '$s сек.'),
                            onPressed: () => Navigator.pop(context, s),
                          ),
                      ],
                    ),
                  );
                  if (v != null) {
                    await LockService.instance.setAutolockSeconds(v);
                    _load();
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: SwitchListTile(
              value: app.secureScreen,
              title: Text(i18n.t('secure_screen')),
              subtitle: Text(i18n.t('secure_screen_hint'),
                  style: const TextStyle(fontSize: 12)),
              onChanged: (v) => app.setSecureScreen(v),
            ),
          ),
        ],
      ),
    );
  }
}
