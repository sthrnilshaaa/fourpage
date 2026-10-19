import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'window_class.dart';

/// A bottom sheet on phones; a centered dialog (max 560 wide, 80% tall) on
/// medium/expanded windows, where a full-width sheet looks stretched.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (context.windowClass.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: backgroundColor ?? AppColors.sheetSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8),
        child: builder(dialogContext),
      ),
    ),
  );
}
