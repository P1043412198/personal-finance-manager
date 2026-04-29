import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/i18n.dart';

class PaletteScreen extends StatelessWidget {
  const PaletteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('palette'))),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          for (final p in kPalettes)
            GestureDetector(
              onTap: () => app.setThemePalette(p.key),
              child: Container(
                decoration: BoxDecoration(
                  color: p.lightBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: app.themePalette == p.key ? p.seed : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: p.seed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Spacer(),
                    Text(p.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (app.themePalette == p.key)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Выбрано',
                            style: TextStyle(color: p.seed, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
