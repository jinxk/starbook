import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/presentation/child/word_books_screen.dart';
import 'package:starbook/presentation/theme/colours.dart';

void main() {
  test('the letter colouring marks exactly the book\'s letter and nothing '
      'else', () {
    const mark = Colours.tomato;
    List<String> marked(TextSpan span) {
      final out = <String>[];
      span.visitChildren((s) {
        if (s is TextSpan && s.style?.color == mark) out.add(s.text!);
        return true;
      });
      return out;
    }

    final banana = markedWord('banana', 'a', mark);
    expect(marked(banana), ['a', 'a', 'a']);
    expect(banana.toPlainText(), 'banana');

    final hen = markedWord('hen', 'a', mark);
    expect(marked(hen), isEmpty);
    expect(hen.toPlainText(), 'hen');

    final cat = markedWord('cat', null, mark);
    expect(marked(cat), isEmpty);
    expect(cat.toPlainText(), 'cat');
  });
}
