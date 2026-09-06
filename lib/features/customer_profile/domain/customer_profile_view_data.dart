import 'package:equatable/equatable.dart';

class CustomerProfileViewData extends Equatable {
  const CustomerProfileViewData({
    this.name,
    this.email,
    this.avatarUrl,
    this.isVerified = false,
    this.isJeeber = false,
    this.rating,
    this.ratingCount = 0,
    this.ratingUnavailable = false,
    this.activeRole,
    this.availableRoles = const <String>[],
  });

  final String? name;

  final String? email;

  final String? avatarUrl;

  final bool isVerified;

  final bool isJeeber;

  final double? rating;

  final int ratingCount;

  /// The review join failed, so this profile has no readable rating — which is
  /// NOT the same as having no reviews (UX-33).
  final bool ratingUnavailable;

  bool get hasRating => rating != null && ratingCount > 0;

  /// Nothing about this person has been read yet — the single reading the
  /// loading rung and the cold-failure branch both take (blank == absent).
  bool get isBlank =>
      (name ?? '').trim().isEmpty &&
      (email ?? '').trim().isEmpty &&
      (avatarUrl ?? '').trim().isEmpty &&
      rating == null;

  final String? activeRole;

  final List<String> availableRoles;

  bool get isDualRole =>
      availableRoles.contains('client') && availableRoles.contains('jeeber');

  CustomerProfileViewData copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    bool? isVerified,
    bool? isJeeber,
    double? rating,
    int? ratingCount,
    bool? ratingUnavailable,
    String? activeRole,
    List<String>? availableRoles,
    bool clearRating = false,
  }) {
    return CustomerProfileViewData(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isJeeber: isJeeber ?? this.isJeeber,
      rating: clearRating ? null : (rating ?? this.rating),
      ratingCount: ratingCount ?? this.ratingCount,
      ratingUnavailable: ratingUnavailable ?? this.ratingUnavailable,
      activeRole: activeRole ?? this.activeRole,
      availableRoles: availableRoles ?? this.availableRoles,
    );
  }

  @override
  List<Object?> get props => [
    name,
    email,
    avatarUrl,
    isVerified,
    isJeeber,
    rating,
    ratingCount,
    ratingUnavailable,
    activeRole,
    availableRoles,
  ];
}
