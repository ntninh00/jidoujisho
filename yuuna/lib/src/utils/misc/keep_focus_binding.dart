import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Flutter's binding, except that a text field keeps its focus, and its
/// keyboard, when the keyboard hides itself on Android.
///
/// Flutter 3.13's Android engine tells a text field its connection closed
/// whenever the keyboard stops showing, and the field then loses focus.
/// Flutter itself undid this in a later release (flutter/flutter #140508);
/// until the app moves to it, that message is dropped here.
///
/// Picking another keyboard language from the keyboard's list opens a
/// system window over the app. When the app gets focus back, Android hides
/// the keyboard, as Flutter's view doesn't say it edits text, so the keyboard
/// is shown again here for the field that still has focus.
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

  /// When the app last came back from behind another window, such as the
  /// keyboard's list of languages.
  DateTime? _returnedAt;

  /// Whether a window is over the app now.
  bool _away = false;

  /// Whether the keyboard hid while the app was away or just back, and is
  /// to show again.
  bool _keyboardWanted = false;

  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    super.handleAppLifecycleStateChanged(state);
    bool away = state != AppLifecycleState.resumed;
    if (_away && !away) {
      _returnedAt = DateTime.now();
      if (_keyboardWanted) {
        _showKeyboardAgain();
      }
    }
    _away = away;
  }

  /// The keyboard stopped showing without the field losing focus.
  void _keyboardHidden() {
    DateTime? returnedAt = _returnedAt;
    bool justBack = returnedAt != null &&
        DateTime.now().difference(returnedAt) < const Duration(seconds: 1);
    if (_away || justBack) {
      _keyboardWanted = true;
      if (!_away) {
        _showKeyboardAgain();
      }
    }
  }

  /// Once Android has finished hiding it, shows the keyboard for the field
  /// that has focus, if one still does.
  void _showKeyboardAgain() {
    Timer(const Duration(milliseconds: 400), () {
      if (_away || !_keyboardWanted) {
        return;
      }
      _keyboardWanted = false;
      BuildContext? context = FocusManager.instance.primaryFocus?.context;
      EditableTextState? field = context?.mounted == true
          ? context!.findAncestorStateOfType<EditableTextState>()
          : null;
      field?.requestKeyboard();
    });
  }

  @override
  BinaryMessenger createBinaryMessenger() =>
      _KeepFocusMessenger(super.createBinaryMessenger(), this);
}

class _KeepFocusMessenger extends BinaryMessenger {
  _KeepFocusMessenger(this._inner, this._binding);

  final BinaryMessenger _inner;
  final KeepFocusBinding _binding;

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
            _binding._keyboardHidden();
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
