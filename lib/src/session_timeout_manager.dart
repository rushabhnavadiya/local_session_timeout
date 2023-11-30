import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'session_config.dart';

enum SessionState { startListening, stopListening }

class SessionTimeoutManager extends StatefulWidget {
  final SessionConfig _sessionConfig;
  final Widget child;

  /// (Optional) Used for enabling and disabling the SessionTimeoutManager
  ///
  /// you might want to disable listening, is specific cases as user could be reading, waiting for OTP
  /// where there is no user activity but you don't want to redirect user to login page
  /// in such cases SessionTimeoutManager can be disabled and re-enabled when necessary
  final Stream<SessionState>? _sessionStateStream;

  /// Since updating [Timer] fir all user interactions could be expensive, user activity are recorded
  /// only after [userActivityDebounceDuration] interval, by default its 1 minute
  final Duration userActivityDebounceDuration;
  const SessionTimeoutManager(
      {required sessionConfig,
        required this.child,
        sessionStateStream,
        this.userActivityDebounceDuration = const Duration(seconds: 1),
        super.key})
      : _sessionConfig = sessionConfig,
        _sessionStateStream = sessionStateStream;

  @override
  _SessionTimeoutManagerState createState() => _SessionTimeoutManagerState();
}

class _SessionTimeoutManagerState extends State<SessionTimeoutManager>
    with WidgetsBindingObserver {
  Timer? _appLostFocusTimer;
  Timer? _userInactivityTimer;
  Timer? _warningOfUserInactivityTimer;
  bool _isListening = false;

  bool _userTapActivityRecordEnabled = true;
  bool isHoverDetectionDisabled = false;
  bool isScrollDetectionDisabled = false;

  void _closeAllTimers() {
    if (_isListening == false) {
      return;
    }

    if (_appLostFocusTimer != null) {
      _clearTimeout(_appLostFocusTimer!);
    }

    if (_userInactivityTimer != null) {
      _clearTimeout(_userInactivityTimer!);
    }

    if (_warningOfUserInactivityTimer != null) {
      _clearTimeout(_warningOfUserInactivityTimer!);
    }
    if (mounted) {
      _isListening = false;
      _userTapActivityRecordEnabled = true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // if there is no stream to handle enabling and disabling of SessionTimeoutManager,
    // we always listen
    if (widget._sessionStateStream == null) {
      _isListening = true;
    }

    widget._sessionStateStream?.listen((SessionState sessionState) {
      if (sessionState == SessionState.startListening && mounted) {
        _isListening = true;

        recordPointerEvent();
      } else if (sessionState == SessionState.stopListening) {
        _closeAllTimers();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isListening == true &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      if (widget._sessionConfig.invalidateSessionForAppLostFocus != null) {
        _appLostFocusTimer ??= _setTimeout(
              () => widget._sessionConfig.pushAppFocusTimeout(),
          duration: widget._sessionConfig.invalidateSessionForAppLostFocus!,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_appLostFocusTimer != null) {
        _clearTimeout(_appLostFocusTimer!);
        _appLostFocusTimer = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Attach Listener only if user wants to invalidate session on user inactivity
    if (widget._sessionConfig.invalidateSessionForUserInactivity != null) {
      return MouseRegion(
        onHover: (PointerHoverEvent event) {
          // debugPrint('isHoverDetectionDisabled: $isHoverDetectionDisabled');

          if(!isHoverDetectionDisabled){
            recordPointerEvent();
            isHoverDetectionDisabled = true;
            Future.delayed(const Duration(seconds: 5),(){
              isHoverDetectionDisabled = false;
            });
          }
        },

        child: Listener(
          onPointerDown: (_) {
            recordPointerEvent();
          },
          onPointerSignal: (_) {
            // debugPrint('isScrollDetectionDisabled: $isScrollDetectionDisabled');

            if(!isScrollDetectionDisabled){
              recordPointerEvent();
              isScrollDetectionDisabled = true;
              Future.delayed(const Duration(seconds: 15),(){
                isScrollDetectionDisabled = false;
              });
            }
          },
          child: widget.child,
        ),
      );
    }

    return widget.child;
  }

  void recordPointerEvent() {
    if (!_isListening) {
      return;
    }

    if (_userTapActivityRecordEnabled &&
        widget._sessionConfig.invalidateSessionForUserInactivity != null) {
      _userInactivityTimer?.cancel();
      _warningOfUserInactivityTimer?.cancel();

      _userInactivityTimer = _setTimeout(
            () => widget._sessionConfig.pushUserInactivityTimeout(),
        duration: widget._sessionConfig.invalidateSessionForUserInactivity!,
      );
      _warningOfUserInactivityTimer = _setTimeout(
            () => widget._sessionConfig.pushWarningOfUserInactivityTimeout(),
        duration: widget._sessionConfig.warningForUserInactivity!,
      );

      /// lock the button for next [userActivityDebounceDuration] duration
      if (mounted) {
        _userTapActivityRecordEnabled = false;
      }

      // Enable it after [userActivityDebounceDuration] duration

      Timer(
        widget.userActivityDebounceDuration,
            () {
          if (mounted) {
            _userTapActivityRecordEnabled = true;
          }
        },
      );
    }
  }

  Timer _setTimeout(callback, {required Duration duration}) {
    return Timer(duration, callback);
  }

  void _clearTimeout(Timer t) {
    t.cancel();
  }
}
