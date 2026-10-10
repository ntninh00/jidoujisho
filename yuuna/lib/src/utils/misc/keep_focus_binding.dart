import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Flutter's binding, except that a text field keeps its focus when the
/// keyboard hides itself on Android.
///
/// Flutter 3.13's Android engine tells a text field its connection closed
/// whenever the keyboard stops showing, and the field then loses focus.
/// Switching the keyboard's language, or to another keyboard, hides it for
/// a moment, so the search bar lost focus and the keyboard did not come
/// back. Flutter itself undid this in a later release (flutter/flutter
/// #140508); until the app moves to it, that message is dropped here.
class KeepFocusBinding extends WidgetsFlutterBinding {
  /// Start Flutter with this binding, before anything else uses one.
  static WidgetsBinding ensureInitialized() {
    if (Platform.isAndroid) {
      try {
        KeepFocusBinding();
      } on FlutterError {
        // A binding was already made.
      }
    }
    return WidgetsFlutterBinding.ensureInitialized();
  }

  @override
  BinaryMessenger createBinaryMessenger() =>
      _KeepFocusMessenger(super.createBinaryMessenger());
}

class _KeepFocusMessenger extends BinaryMessenger {
  _KeepFocusMessenger(this._inner);

  final BinaryMessenger _inner;

  static const String _closed = 'TextInputClient.onConnectionClosed';

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) =>
      // ignore: deprecated_member_use
      _inner.handlePlatformMessage(channel, data, callback);

  @override
  Future<ByteData?>? send(String channel, ByteData? message) =>
      _inner.send(channel, message);

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null || channel != SystemChannels.textInput.name) {
      _inner.setMessageHandler(channel, handler);
      return;
    }
    _inner.setMessageHandler(channel, (data) async {
      if (data != null) {
        try {
          MethodCall call =
              SystemChannels.textInput.codec.decodeMethodCall(data);
          if (call.method == _closed) {
            return null;
          }
        } catch (_) {
          // Not a call this needs to look at.
        }
      }
      return handler(data);
    });
  }
}
