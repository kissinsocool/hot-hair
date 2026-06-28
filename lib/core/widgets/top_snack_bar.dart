import 'dart:math';

import 'package:flutter/material.dart';

SnackBar topSnackBar(BuildContext context, String message) {
  final media = MediaQuery.of(context);
  final bottomMargin = max(
    0.0,
    media.size.height - media.padding.top - kToolbarHeight - 72,
  );

  return SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
  );
}
