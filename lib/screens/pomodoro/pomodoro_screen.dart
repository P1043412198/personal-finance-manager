import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int _workSec = 25 * 60;
  int _breakSec = 5 * 60;
  int _remaining = 25 * 60;
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
        final wasWork = !_isBreak;
        if (wasWork) {
          context.read<AppState>().logPomodoroSession(_workSec ~/ 60);
        }
        setState(() {
          _running = false;
          if (wasWork) _completed += 1;
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

  void _changePreset(int work, int br) {
    _timer?.cancel();
    setState(() {
      _workSec = work * 60;
      _breakSec = br * 60;
      _isBreak = false;
      _remaining = _workSec;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_remaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_remaining % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    final progress = _isBreak ? _remaining / _breakSec : _remaining / _workSec;
    final app = context.watch<AppState>();
    final dailyMap = app.pomodoroDaily(7);
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todayMin = dailyMap[todayKey] ?? 0;
    final weekMin = dailyMap.values.fold<int>(0, (s, v) => s + v);
    final totalMin = app.pomodoroTotalMinutes();
    return Scaffold(
      appBar: AppBar(title: const Text('Pomodoro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
        children: [
          Center(
            child: Column(
              children: [
                Text(_isBreak ? 'Перерыв' : 'Работа',
                    style: TextStyle(
                        fontSize: 18,
                        color: _isBreak ? AppColors.income : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  height: 220,
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
                const SizedBox(height: 16),
                Text('Циклов в сессии: $_completed',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      label: const Text('25 / 5'),
                      onPressed: () => _changePreset(25, 5),
                    ),
                    ActionChip(
                      label: const Text('50 / 10'),
                      onPressed: () => _changePreset(50, 10),
                    ),
                    ActionChip(
                      label: const Text('15 / 3'),
                      onPressed: () => _changePreset(15, 3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Статистика'),
          Row(children: [
            _statBox('Сегодня', '${todayMin} мин'),
            const SizedBox(width: 8),
            _statBox('Неделя', '${weekMin} мин'),
            const SizedBox(width: 8),
            _statBox('Всего', '${totalMin} мин'),
          ]),
          const SizedBox(height: 16),
          if (dailyMap.isNotEmpty) ...[
            SectionHeader(title: 'История последних 7 дней'),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var i = 6; i >= 0; i--)
                    _historyRow(today.subtract(Duration(days: i)), dailyMap),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _historyRow(DateTime day, Map<String, int> daily) {
    final dKey =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final mins = daily[dKey] ?? 0;
    final maxMins = daily.values.fold<int>(1, (m, v) => v > m ? v : m);
    final pct = mins / maxMins;
    final dayName = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][day.weekday - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(dayName, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 56,
            child: Text('${day.day}.${day.month}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: AppColors.muted,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text('$mins мин',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
