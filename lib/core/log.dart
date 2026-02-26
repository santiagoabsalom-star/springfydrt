import 'dart:developer';

import 'package:flutter/foundation.dart';

class Log {
  static void d(String message) {
    if (!kDebugMode) return;

    final trace = StackTrace.current.toString().split('\n');


    final caller = trace.length > 1 ? trace[1] : '';

    final parsedCaller = _parseCaller(caller);

    log("[$parsedCaller] $message");
  }
  static String _parseCaller(String raw) {
    final regExp = RegExp(r'\((.*)\)');
    final match = regExp.firstMatch(raw);

    if (match != null) {
      return match.group(1) ?? 'unknown';
    }

    return 'unknown';
  }
}