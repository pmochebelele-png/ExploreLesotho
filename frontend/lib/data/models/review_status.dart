// lib/data/models/review_status.dart
enum ReviewStatus {
  pending,
  approved,
  rejected;

  @override
  String toString() {
    switch (this) {
      case ReviewStatus.pending:
        return 'Pending';
      case ReviewStatus.approved:
        return 'Approved';
      case ReviewStatus.rejected:
        return 'Rejected';
    }
  }
}