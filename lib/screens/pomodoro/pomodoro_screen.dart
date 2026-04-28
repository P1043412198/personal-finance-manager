import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  static const _workSec = 25 * 60;
  static const _breakSec = 5 * 60;
  int _remaining = _workSec;
  bool _running = false;
  bool _isBreak = false;
  int _completed = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _running = false;
          if (!_isBreak) _completed += 1;
          _isBreak = !_isBreak;
          _remaining = _isBreak ? _breakSec : _workSec;
        });
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _isBreak ? _breakSec : _workSec;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_remaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_remaining % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    final progress = _isBreak ? _remaining / _breakSec : _remaining / _workSec;
    return Scaffold(
      appBar: AppBar(title: const Text('Pomodoro')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isBreak ? 'Перерыв' : 'Работа',
                  style: TextStyle(
                      fontSize: 18,
                      color: _isBreak ? AppColors.income : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                width: 220, height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: AppColors.muted,
                        valueColor: AlwaysStoppedAnimation(
                            _isBreak ? AppColors.income : theme.colorScheme.primary),
                      ),
                    ),
                    Text('$mins:$secs',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Циклов выполнено: $_completed',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(onPressed: _reset, child: const Text('Сброс')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggle,
                    child: Text(_running ? 'Пауза' : 'Старт'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
