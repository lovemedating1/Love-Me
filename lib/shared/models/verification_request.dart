import 'package:equatable/equatable.dart';

/// Document types the verification flow offers — mirrors the fixed category
/// list the backend's `verification_requests.document_type` column is
/// expected to constrain to (see `BACKEND_VERIFICATION_HANDOFF.md` §1).
enum VerificationDocType {
  nationalId,
  passport,
  birthCertificate,
  drivingLicense,
}

extension VerificationDocTypeLabel on VerificationDocType {
  String get label => switch (this) {
    VerificationDocType.nationalId => 'National ID',
    VerificationDocType.passport => 'Passport',
    VerificationDocType.birthCertificate => 'Birth Certificate',
    VerificationDocType.drivingLicense => 'Driving License',
  };

  /// The exact string persisted server-side — stable even if [label] copy
  /// changes later.
  String get wireValue => switch (this) {
    VerificationDocType.nationalId => 'national_id',
    VerificationDocType.passport => 'passport',
    VerificationDocType.birthCertificate => 'birth_certificate',
    VerificationDocType.drivingLicense => 'driving_license',
  };
}

enum VerificationStatus { pending, approved, rejected }

/// The current user's identity-verification submission — mirrors the
/// (not-yet-live) `verification_requests` table proposed in
/// `BACKEND_VERIFICATION_HANDOFF.md` §1. At most one row per user matters
/// for display purposes: the most recent submission's status.
class VerificationRequest extends Equatable {
  const VerificationRequest({
    required this.id,
    required this.documentType,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String id;
  final VerificationDocType documentType;
  final VerificationStatus status;
  final DateTime createdAt;
  final String? rejectionReason;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      VerificationRequest(
        id: json['id'] as String,
        documentType: _docTypeFromWire(json['document_type'] as String?),
        status: _statusFromWire(json['status'] as String?),
        createdAt: DateTime.parse(json['created_at'] as String),
        rejectionReason: json['rejection_reason'] as String?,
      );

  static VerificationDocType _docTypeFromWire(String? v) => switch (v) {
    'passport' => VerificationDocType.passport,
    'birth_certificate' => VerificationDocType.birthCertificate,
    'driving_license' => VerificationDocType.drivingLicense,
    _ => VerificationDocType.nationalId,
  };

  static VerificationStatus _statusFromWire(String? v) => switch (v) {
    'approved' => VerificationStatus.approved,
    'rejected' => VerificationStatus.rejected,
    _ => VerificationStatus.pending,
  };

  @override
  List<Object?> get props => [id, status];
}
