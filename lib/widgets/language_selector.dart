import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/language_definition.dart';
import '../services/localization_service.dart';

class LanguageSelectorDialog extends StatefulWidget {
  final String? selectedCode;
  final AppLocale? locale;
  const LanguageSelectorDialog({super.key, this.selectedCode, this.locale});

  @override
  State<LanguageSelectorDialog> createState() => _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<LanguageSelectorDialog> {
  final _search = TextEditingController();
  String get query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations(
      widget.locale ?? AppLocalizations.of(context).locale,
    );
    final languages = LanguageDefinition.all
        .where(
          (item) =>
              strings.languageName(item.code).toLowerCase().contains(query) ||
              item.englishName.toLowerCase().contains(query) ||
              item.nativeName.toLowerCase().contains(query) ||
              item.code.contains(query),
        )
        .toList();
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        220;
    return AlertDialog(
      title: Text(strings.get('select_language')),
      content: SizedBox(
        width: double.maxFinite,
        height: math.max(100, math.min(420, availableHeight)),
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: strings.get('search_languages'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: languages.isEmpty
                  ? Center(child: Text(strings.get('no_languages')))
                  : ListView.builder(
                      itemCount: languages.length,
                      itemBuilder: (_, index) {
                        final language = languages[index];
                        return ListTile(
                          title: Text(strings.languageName(language.code)),
                          subtitle: Text(language.nativeName),
                          trailing: language.code == widget.selectedCode
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, language.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.get('cancel')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
