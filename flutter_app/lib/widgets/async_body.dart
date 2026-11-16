import 'package:flutter/material.dart';
import '../design/transport_theme.dart';

class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.future,
    required this.retry,
    required this.builder,
  });
  final Future<T> future;
  final VoidCallback retry;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 18),
              Text(
                'Preparing your workspace…',
                style: TextStyle(fontSize: 11, color: TransportColors.muted),
              ),
            ],
          ),
        );
      }
      if (snapshot.hasError) {
        return PolishedState(
          title: 'Let’s try that again',
          message: '${snapshot.error}',
          icon: Icons.cloud_off_outlined,
          action: FilledButton(onPressed: retry, child: const Text('Retry')),
        );
      }
      return builder(snapshot.data as T);
    },
  );
}
