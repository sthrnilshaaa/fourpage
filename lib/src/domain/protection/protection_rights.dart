/// Rights management limits (lending periods, copy/print limits).
library;

class ProtectionRights {
  final DateTime? start;
  final DateTime? end;
  final int? printLimit;
  final int? copyLimit;
  final int printCount;
  final int copyCount;

  const ProtectionRights({
    this.start,
    this.end,
    this.printLimit,
    this.copyLimit,
    this.printCount = 0,
    this.copyCount = 0,
  });

  bool get isExpired {
    if (end == null) return false;
    return DateTime.now().isAfter(end!);
  }

  bool get isNotYetValid {
    if (start == null) return false;
    return DateTime.now().isBefore(start!);
  }

  bool get canPrint => printLimit == null || printCount < printLimit!;
  bool get canCopy => copyLimit == null || copyCount < copyLimit!;
}
