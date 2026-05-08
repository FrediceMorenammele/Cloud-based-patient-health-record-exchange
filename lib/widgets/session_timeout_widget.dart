// lib/widgets/session_timeout_widget.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionTimeoutWidget extends StatefulWidget {
  final Widget child;
  final Duration timeoutDuration;
  final VoidCallback onTimeout;

  const SessionTimeoutWidget({
    super.key,
    required this.child,
    this.timeoutDuration = const Duration(minutes: 15), // Per Section 5
    required this.onTimeout,
  });

  @override
  State<SessionTimeoutWidget> createState() => _SessionTimeoutWidgetState();
}

class _SessionTimeoutWidgetState extends State<SessionTimeoutWidget> {
  DateTime? _lastInteraction;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    setState(() {
      _lastInteraction = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      child: NotificationListener(
        onNotification: (notification) {
          _resetTimer();
          return false;
        },
        child: TickerMode(
          enabled: true,
          child: _TimeoutChecker(
            lastInteraction: _lastInteraction ?? DateTime.now(),
            timeoutDuration: widget.timeoutDuration,
            onTimeout: widget.onTimeout,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _TimeoutChecker extends StatefulWidget {
  final DateTime lastInteraction;
  final Duration timeoutDuration;
  final VoidCallback onTimeout;
  final Widget child;

  const _TimeoutChecker({
    required this.lastInteraction,
    required this.timeoutDuration,
    required this.onTimeout,
    required this.child,
  });

  @override
  State<_TimeoutChecker> createState() => _TimeoutCheckerState();
}

class _TimeoutCheckerState extends State<_TimeoutChecker> {
  @override
  void initState() {
    super.initState();
    _checkTimeout();
  }

  void _checkTimeout() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(widget.lastInteraction);
      if (elapsed >= widget.timeoutDuration) {
        widget.onTimeout();
      } else {
        _checkTimeout();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
