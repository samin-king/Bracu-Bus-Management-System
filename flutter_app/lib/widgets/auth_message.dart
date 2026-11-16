import 'package:flutter/material.dart';

class AuthMessage extends StatelessWidget {
  const AuthMessage(this.message, {this.isError = false, super.key});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isError
                ? colors.onErrorContainer
                : colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
