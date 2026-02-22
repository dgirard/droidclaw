import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';

/// Screen for selecting the app locale.
class LocaleConfigScreen extends ConsumerWidget {
  const LocaleConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.localeSettingsTitle)),
      body: RadioGroup<String>(
        groupValue: config.locale,
        onChanged: (v) {
          if (v != null) _setLocale(ref, v);
        },
        child: ListView(
          children: [
            RadioListTile<String>(
              title: Text(l.localeSystem),
              value: 'system',
            ),
            RadioListTile<String>(
              title: Text(l.localeEnglish),
              value: 'en',
            ),
            RadioListTile<String>(
              title: Text(l.localeFrench),
              value: 'fr',
            ),
            RadioListTile<String>(
              title: Text(l.localeSpanish),
              value: 'es',
            ),
            RadioListTile<String>(
              title: Text(l.localeGerman),
              value: 'de',
            ),
            RadioListTile<String>(
              title: Text(l.localeItalian),
              value: 'it',
            ),
          ],
        ),
      ),
    );
  }

  void _setLocale(WidgetRef ref, String locale) {
    final config = ref.read(appConfigProvider);
    final newConfig = config.copyWith(locale: locale);
    ref.read(configStorageProvider).save(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);
  }
}
