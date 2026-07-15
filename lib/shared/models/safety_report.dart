import 'package:equatable/equatable.dart';

enum ReportStatus { pending, resolved, dismissed }

/// Reasons the report-submission sheet offers — mirrors the fixed category
/// list the backend's `reports.reason` column is expected to constrain to
/// (see `app doctumant/BACKEND_ATIER_HANDOFF.md` §1).
enum ReportReason {
  inappropriatePhotos,
  fakeProfile,
  harassment,
  spamOrScam,
  underage,
  other,
}

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
    ReportReason.inappropriatePhotos => 'Inappropriate photos',
    ReportReason.fakeProfile => 'Fake profile',
    ReportReason.harassment => 'Harassment or abuse',
    ReportReason.spamOrScam => 'Spam / scam',
    ReportReason.underage => 'Underage user',
    ReportReason.other => 'Other',
  };

  /// The exact string persisted server-side — stable even if [label] copy
  /// changes later.
  String get wireValue => switch (this) {
    ReportReason.inappropriatePhotos => 'inappropriate_photos',
    ReportReason.fakeProfile => 'fake_profile',
    ReportReason.harassment => 'harassment',
    ReportReason.spamOrScam => 'spam_or_scam',
    ReportReason.underage => 'underage',
    ReportReason.other => 'other',
  };
}

/// A safety report the user submitted — mirrors the (not-yet-live) `reports`
/// table proposed in `BACKEND_ATIER_HANDOFF.md` §1. `reportedUserId` is the
/// real FK the backend needs; `reportedName` stays as a display-only
/// convenience resolved client-side at submit time.
class SafetyReport extends Equatable {
  const SafetyReport({
    required this.id,
    required this.reportedUserId,
    required this.reportedName,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.description,
    this.adminResponse,
  });

  final String id;
  final String reportedUserId;
  final String reportedName;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? description;
  final String? adminResponse;

  factory SafetyReport.fromJson(Map<String, dynamic> json) => SafetyReport(
    id: json['id'] as String,
    reportedUserId: json['reported_user_id'] as String,
    reportedName: json['reported_name'] as String? ?? 'Unknown user',
    reason: json['reason'] as String,
    status: _statusFromWire(json['status'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String),
    description: json['description'] as String?,
    adminResponse: json['admin_response'] as String?,
  );

  static ReportStatus _statusFromWire(String? v) => switch (v) {
    'resolved' => ReportStatus.resolved,
    'dismissed' => ReportStatus.dismissed,
    _ => ReportStatus.pending,
  };

  @override
  List<Object?> get props => [id, status];
}
