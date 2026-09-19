import 'package:flutter/material.dart';

import '../models/language_definition.dart';

class LanguageSelectorDialog extends StatefulWidget {
  final String? selectedCode;
  const LanguageSelectorDialog({super.key, this.selectedCode});

  @override
  State<LanguageSelectorDialog> createState() => _LanguageSelectorDialogState();
}

class _LanguageSelectorDialogState extends State<LanguageSelectorDialog> {
  final _search = TextEditingController();
  String get query => _search.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final languages = LanguageDefinition.all
        .where(
          (item) =>
              item.englishName.toLowerCase().contains(query) ||
              item.nativeName.toLowerCase().contains(query),
        )
        .toList();
    return AlertDialog(
      title: const Text('Select a language'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search languages...',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (_, index) {
                  final language = languages[index];
                  return ListTile(
                    title: Text(language.englishName),
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
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
