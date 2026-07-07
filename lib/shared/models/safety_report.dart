import 'package:equatable/equatable.dart';

enum ReportStatus { pending, resolved, dismissed }

/// A safety report the user submitted.
class SafetyReport extends Equatable {
  const SafetyReport({
    required this.id,
    required this.reportedName,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.description,
    this.adminResponse,
  });

  final String id;
  final String reportedName;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? description;
  final String? adminResponse;

  @override
  List<Object?> get props => [id, status];
}
