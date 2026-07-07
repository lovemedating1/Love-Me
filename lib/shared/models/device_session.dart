import 'package:equatable/equatable.dart';

/// An active signed-in device session.
class DeviceSession extends Equatable {
  const DeviceSession({
    required this.id,
    required this.label,
    required this.os,
    required this.lastActive,
    this.isCurrent = false,
  });

  final String id;
  final String label; // e.g. "Pixel 8 · Chrome"
  final String os;
  final DateTime lastActive;
  final bool isCurrent;

  @override
  List<Object?> get props => [id, isCurrent];
}
