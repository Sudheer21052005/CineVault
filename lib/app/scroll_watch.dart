import 'package:provider/provider.dart';

import '../core/material.dart';
import '../core/performance.dart';

class ScrollWatch extends StatefulWidget {
  const ScrollWatch({required this.area, required this.child, super.key});

  final PerfArea area;
  final Widget child;

  @override
  State<ScrollWatch> createState() => _ScrollWatchState();
}

class _ScrollWatchState extends State<ScrollWatch> {
  late final ScrollProbe _probe;

  @override
  void initState() {
    super.initState();
    _probe = ScrollProbe(context.read<AppPerformance>());
  }

  @override
  void dispose() {
    _probe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (event.depth != 0 || event.metrics.axis != Axis.vertical) {
            return false;
          }
          if (event is ScrollStartNotification) _probe.start(widget.area);
          if (event is ScrollEndNotification) _probe.end();
          return false;
        },
        child: widget.child,
      );
}
