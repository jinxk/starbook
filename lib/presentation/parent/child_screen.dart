import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/progress/progress.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../widgets/picture.dart';
import 'parts.dart';

const _pictures = [
  'cat',
  'dog',
  'rabbit',
  'bear',
  'lion',
  'tiger',
  'elephant',
  'monkey',
  'fox',
  'owl',
  'unicorn',
  'butterfly',
];

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: chipBorder, width: 1.5),
);

class ChildScreen extends ConsumerStatefulWidget {
  const ChildScreen({super.key});

  @override
  ConsumerState<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends ConsumerState<ChildScreen> {
  bool _loaded = false;
  String _name = '';
  String? _picture;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final child = (await ref.read(progressRepositoryProvider).child())
        .getOrElse((_) => null);
    if (!mounted) return;
    setState(() {
      _name = child?.name ?? '';
      _picture = child?.picture;
      _loaded = true;
    });
  }

  void _save() => unawaited(
    ref
        .read(progressRepositoryProvider)
        .setChild(Child(name: _name, picture: _picture)),
  );

  void _pick(String? picture) {
    setState(() => _picture = picture);
    _save();
  }

  Widget _tile(String? picture) {
    final chosen = _picture == picture;
    return Semantics(
      button: true,
      selected: chosen,
      label: picture ?? 'No picture',
      child: GestureDetector(
        key: ValueKey(picture ?? 'none'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(picture),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: chosen ? Colours.ink : cardBorder,
              width: chosen ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: picture == null
              ? Text(
                  'No picture',
                  textAlign: TextAlign.center,
                  style: hind(13, FontWeight.w400, Colours.inkSoft),
                )
              : Picture(picture, size: 52),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(parentTodayProvider);
      },
      child: Scaffold(
        backgroundColor: Colours.parentPaper,
        body: SafeArea(
          child: Column(
            children: [
              parentHeader('Child'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (_loaded) ...[
                      parentHeading('Name'),
                      TextFormField(
                        initialValue: _name,
                        maxLength: 20,
                        onChanged: (text) {
                          _name = text;
                          _save();
                        },
                        style: hind(16, FontWeight.w500, Colours.ink),
                        decoration: InputDecoration(
                          hintText: 'Name',
                          hintStyle: hind(16, FontWeight.w500, Colours.inkSoft),
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: _inputBorder,
                          focusedBorder: _inputBorder,
                        ),
                      ),
                      parentHeading('Picture'),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final name in _pictures) _tile(name),
                          _tile(null),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                        child: Text(
                          'The picture shows on home once a name is set.',
                          style: hind(
                            14,
                            FontWeight.w400,
                            Colours.inkSoft,
                          ).copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
