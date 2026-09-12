import 'package:flutter/material.dart';

import '../models/book.dart';

const _bookColors = <Color>[
  Color(0xFF4BAF8F),
  Color(0xFF6F8EDB),
  Color(0xFFE39A5B),
  Color(0xFFB276C9),
  Color(0xFFE16D78),
  Color(0xFF58A9B8),
];

Color ledgerBookColor(LedgerBook book) {
  var hash = 0;
  for (final codeUnit in book.id.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return _bookColors[hash % _bookColors.length];
}

class BookColorDot extends StatelessWidget {
  const BookColorDot({required this.book, this.size = 10, super.key});

  final LedgerBook book;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ledgerBookColor(book),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}
