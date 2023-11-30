import 'dart:async';

enum SessionTimeoutState { appFocusTimeout, userInactivityTimeout, warningUserInactivityTimeout }

class SessionConfig {
  /// Immediately invalidates the session after [invalidateSessionForUserInactivity] duration of user inactivity
  ///
  /// If null, never invalidates the session for user inactivity
  final Duration? invalidateSessionForUserInactivity;

  /// Immediately invalidates the session after [invalidateSessionForAppLostFocus] duration of app losing focus
  ///
  /// If null, never invalidates the session for app losing focus
  final Duration? invalidateSessionForAppLostFocus;

  /// Immediately warn after [warningForUserInactivity] duration of user inactivity
  ///
  /// If null, never invalidates the session for showing waring of user inactivity
  final Duration? warningForUserInactivity;

  SessionConfig({
    this.invalidateSessionForUserInactivity,
    this.invalidateSessionForAppLostFocus,
    this.warningForUserInactivity,
  });

  final _controller = StreamController<SessionTimeoutState>();

  /// Stream yields Map if session is valid, else null
  Stream<SessionTimeoutState> get stream => _controller.stream;

  /// invalidate session and pass [SessionTimeoutState.appFocusTimeout] through stream
  void pushAppFocusTimeout() {
    _controller.sink.add(SessionTimeoutState.appFocusTimeout);
  }

  /// invalidate session and pass [SessionTimeoutState.userInactivityTimeout] through stream
  void pushUserInactivityTimeout() {
    _controller.sink.add(SessionTimeoutState.userInactivityTimeout);
  }

  /// invalidate session and pass [SessionTimeoutState.warningUserInactivityTimeout] through stream
  void pushWarningOfUserInactivityTimeout() {
    _controller.sink.add(SessionTimeoutState.warningUserInactivityTimeout);
  }

  /// call dispose method to close the stream
  /// usually SessionConfig.stream should keep running until the app is terminated.
  /// But if your use case requires closing the stream, call the dispose method
  void dispose() {
    _controller.close();
  }
}
