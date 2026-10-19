import 'package:flutter/widgets.dart';

import 'window_class.dart';

/// Bottom padding for browse lists: on phones the floating nav pill needs
/// [compact] points of clearance; with the side rail a normal margin is enough.
double browseBottomPadding(BuildContext context, {required double compact}) =>
    context.windowClass.isCompact ? compact : 24;
