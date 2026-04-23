/// APEX — AutoDisposeMixin
/// ════════════════════════════════════════════════════════════════════
/// Eliminates the recurring memory-leak pattern where State classes
/// create TextEditingController (or other Disposable) instances in
/// initState/field initializers but forget to call .dispose().
///
/// Audit (April 2026) found 765 TextEditingController instances with
/// only 2 explicit .dispose() calls (0.26% coverage) — the biggest
/// source of long-session memory growth and PWA stalls.
///
/// Usage:
///   class _MyScreenState extends State<MyScreen>
///       with AutoDisposeMixin<MyScreen> {
///
///     late final nameCtl = track(TextEditingController());
///     late final emailCtl = track(TextEditingController());
///     late final focus = track(FocusNode());
///     late final animCtrl = track(AnimationController(vsync: this));
///
///     // No need to override dispose() — AutoDisposeMixin disposes
///     // every tracked resource automatically.
///   }
///
/// Supports any object with a no-arg `dispose()` method:
/// TextEditingController, FocusNode, ScrollController, TabController,
/// AnimationController, PageController, TransformationController,
/// ValueNotifier, StreamSubscription (via cancel-wrapper), etc.
/// ════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Any object with a no-arg `dispose()` method.
abstract class _DisposableLike {
  void dispose();
}

/// Mixin that accumulates disposables during the State lifecycle and
/// disposes them all in a single [dispose] override.
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  final List<void Function()> _disposers = <void Function()>[];
  bool _disposed = false;

  /// Register a disposable. Returns the same object so you can use:
  ///   final ctl = track(TextEditingController());
  D track<D>(D disposable) {
    if (_disposed) {
      // Guard against post-dispose registrations (shouldn't happen
      // in practice; logged in debug).
      assert(() {
        debugPrint(
            '[AutoDisposeMixin] track() called after dispose() on $T');
        return true;
      }());
      return disposable;
    }
    _register(disposable);
    return disposable;
  }

  /// Register a StreamSubscription (uses cancel() instead of dispose()).
  StreamSubscription<S> trackSub<S>(StreamSubscription<S> sub) {
    if (!_disposed) {
      _disposers.add(() {
        try {
          sub.cancel();
        } catch (_) {}
      });
    }
    return sub;
  }

  /// Register a custom cleanup callback that runs alongside dispose.
  void trackCleanup(void Function() onDispose) {
    if (!_disposed) _disposers.add(onDispose);
  }

  void _register(Object? disposable) {
    if (disposable == null) return;
    _disposers.add(() {
      try {
        // Duck-typed dispose() call — works for all Flutter disposables.
        (disposable as dynamic).dispose();
      } catch (_) {
        // Swallow: one failed dispose shouldn't block the others.
      }
    });
  }

  @override
  void dispose() {
    if (_disposed) {
      super.dispose();
      return;
    }
    _disposed = true;
    // Reverse order so later-registered resources dispose first
    // (mirrors natural construction order on the stack).
    for (final fn in _disposers.reversed) {
      fn();
    }
    _disposers.clear();
    super.dispose();
  }
}
