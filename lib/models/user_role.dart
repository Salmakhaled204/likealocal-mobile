import 'package:cloud_firestore/cloud_firestore.dart';

class AppUserRole {
  static const regular = 'regular';
  static const contributor = 'contributor';
  static const superUser = 'superUser';
  static const admin = 'admin';
}

class AppSubscriptionPlan {
  static const free = 'free';
  static const premium = 'premium';
}

class AppSubscriptionSource {
  static const demo = 'demo';
  static const admin = 'admin';
}

class UserSubscription {
  final String plan;
  final Timestamp? startedAt;
  final Timestamp? expiresAt;
  final String? source;

  const UserSubscription({
    required this.plan,
    this.startedAt,
    this.expiresAt,
    this.source,
  });

  factory UserSubscription.free() =>
      const UserSubscription(plan: AppSubscriptionPlan.free);

  factory UserSubscription.fromData(dynamic data, {bool legacyPremium = false}) {
    if (data is Map<String, dynamic>) {
      final plan = (data['plan'] ?? '').toString();
      final source = data['source']?.toString();
      return UserSubscription(
        plan: plan == AppSubscriptionPlan.premium
            ? AppSubscriptionPlan.premium
            : AppSubscriptionPlan.free,
        startedAt: data['startedAt'] as Timestamp?,
        expiresAt: data['expiresAt'] as Timestamp?,
        source: source == AppSubscriptionSource.demo ||
                source == AppSubscriptionSource.admin
            ? source
            : null,
      );
    }

    if (data == AppSubscriptionPlan.premium || legacyPremium) {
      return const UserSubscription(
        plan: AppSubscriptionPlan.premium,
        source: AppSubscriptionSource.admin,
      );
    }

    return UserSubscription.free();
  }

  Map<String, dynamic> toFirestore() => {
        'plan': plan,
        'startedAt': startedAt,
        'expiresAt': expiresAt,
        'source': source,
      };
}

class UserStats {
  final int totalContributions;
  final int approvedContributions;
  final int rejectedContributions;
  final int reputationScore;
  final int totalReviews;
  final int helpfulVotes;
  final double averageRating;
  final int reportCount;

  const UserStats({
    required this.totalContributions,
    required this.approvedContributions,
    required this.rejectedContributions,
    required this.reputationScore,
    required this.totalReviews,
    required this.helpfulVotes,
    required this.averageRating,
    required this.reportCount,
  });

  factory UserStats.empty() => const UserStats(
        totalContributions: 0,
        approvedContributions: 0,
        rejectedContributions: 0,
        reputationScore: 0,
        totalReviews: 0,
        helpfulVotes: 0,
        averageRating: 0,
        reportCount: 0,
      );

  factory UserStats.fromData(Map<String, dynamic>? data) {
    return UserStats(
      totalContributions: (data?['totalContributions'] as num?)?.toInt() ?? 0,
      approvedContributions:
          (data?['approvedContributions'] as num?)?.toInt() ??
              (data?['totalContributions'] as num?)?.toInt() ??
              0,
      rejectedContributions:
          (data?['rejectedContributions'] as num?)?.toInt() ?? 0,
      reputationScore: (data?['reputationScore'] as num?)?.toInt() ?? 0,
      totalReviews: (data?['totalReviews'] as num?)?.toInt() ?? 0,
      helpfulVotes: (data?['helpfulVotes'] as num?)?.toInt() ?? 0,
      averageRating: (data?['averageRating'] as num?)?.toDouble() ?? 0,
      reportCount: (data?['reportCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'totalContributions': totalContributions,
        'approvedContributions': approvedContributions,
        'rejectedContributions': rejectedContributions,
        'reputationScore': reputationScore,
        'totalReviews': totalReviews,
        'helpfulVotes': helpfulVotes,
        'averageRating': averageRating,
        'reportCount': reportCount,
      };
}

class UsageLimits {
  final int pinsUsed;
  final int remindersUsed;
  final int aiRequestsToday;
  final int reviewsToday;

  const UsageLimits({
    required this.pinsUsed,
    required this.remindersUsed,
    required this.aiRequestsToday,
    required this.reviewsToday,
  });

  factory UsageLimits.fromData(Map<String, dynamic>? data) {
    return UsageLimits(
      pinsUsed: (data?['pinsUsed'] as num?)?.toInt() ?? 0,
      remindersUsed: (data?['remindersUsed'] as num?)?.toInt() ?? 0,
      aiRequestsToday: (data?['aiRequestsToday'] as num?)?.toInt() ?? 0,
      reviewsToday: (data?['reviewsToday'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'pinsUsed': pinsUsed,
        'remindersUsed': remindersUsed,
        'aiRequestsToday': aiRequestsToday,
        'reviewsToday': reviewsToday,
      };
}

class UserRole {
  final String role;
  final bool isPremium;
  final UserSubscription subscription;
  final UserStats stats;
  final UsageLimits limits;

  const UserRole({
    required this.role,
    required this.isPremium,
    required this.subscription,
    required this.stats,
    required this.limits,
  });

  factory UserRole.regularFree() => UserRole(
        role: AppUserRole.regular,
        isPremium: false,
        subscription: UserSubscription.free(),
        stats: UserStats.empty(),
        limits: const UsageLimits(
          pinsUsed: 0,
          remindersUsed: 0,
          aiRequestsToday: 0,
          reviewsToday: 0,
        ),
      );

  factory UserRole.fromData(Map<String, dynamic>? data) {
    final legacyType = (data?['userType'] ?? '').toString();
    final legacyPremium =
        data?['isPremium'] == true || legacyType == AppSubscriptionPlan.premium;
    final subscription = UserSubscription.fromData(
      data?['subscription'],
      legacyPremium: legacyPremium,
    );
    final resolvedRole = _resolveRole(
      (data?['role'] ?? '').toString(),
      legacyType,
      data?['isSuperUser'] == true,
    );

    final statsData = data?['stats'] is Map<String, dynamic>
        ? data!['stats'] as Map<String, dynamic>
        : <String, dynamic>{
            'totalContributions':
                data?['contributionCount'] ?? data?['totalContributions'] ?? 0,
            'approvedContributions': data?['approvedContributions'],
            'rejectedContributions': data?['rejectedContributions'],
            'reputationScore': data?['reputationScore'],
            'totalReviews': data?['totalReviews'] ?? 0,
            'helpfulVotes': data?['helpfulVotes'] ?? 0,
            'averageRating': data?['averageRating'] ?? 0,
            'reportCount': data?['reportCount'] ?? 0,
          };

    return UserRole(
      role: resolvedRole,
      isPremium:
          data?['isPremium'] == true ||
          subscription.plan == AppSubscriptionPlan.premium,
      subscription: subscription,
      stats: UserStats.fromData(statsData),
      limits: UsageLimits.fromData(data?['limits'] as Map<String, dynamic>?),
    );
  }

  static String _resolveRole(String role, String legacyType, bool legacySuper) {
    if (role == AppUserRole.admin ||
        role == AppUserRole.contributor ||
        role == AppUserRole.superUser ||
        role == AppUserRole.regular) {
      return role;
    }
    if (legacySuper || legacyType == 'super' || role == 'super_user') {
      return AppUserRole.superUser;
    }
    if (legacyType == AppUserRole.contributor) return AppUserRole.contributor;
    return AppUserRole.regular;
  }

  bool get isRegular => role == AppUserRole.regular;
  bool get isContributor => role == AppUserRole.contributor;
  bool get isSuperUser => role == AppUserRole.superUser;
  bool get isAdmin => role == AppUserRole.admin;

  bool get canAddPlaces => isRegular || isContributor || isSuperUser || isAdmin;
  bool canManagePlace(String ownerId, String uid) => isAdmin || ownerId == uid;
  bool get canModerate => isAdmin;
  bool get canBePublicTrusted => isSuperUser;

  int get maxPlacesPerMonth {
    if (isPremium) return 999;
    if (isAdmin) return 999;
    if (isSuperUser) return 30;
    if (isContributor) return 10;
    return 1;
  }

  int get maxFavorites {
    if (isPremium) return 999;
    if (isSuperUser) return 100;
    if (isContributor) return 30;
    return 10;
  }

  int get maxPins => maxFavorites;

  int get maxReviewsPerDay {
    if (isPremium) return 50;
    if (isSuperUser) return 20;
    if (isContributor) return 10;
    return 3;
  }

  int get maxReminders {
    if (isPremium) return 50;
    if (isSuperUser) return 10;
    return 3;
  }

  int get maxAiRequestsPerDay {
    if (isPremium) return 100;
    if (isSuperUser) return 25;
    if (isContributor) return 10;
    return 3;
  }

  int get maxUploadsPerPlace {
    if (isPremium) return 15;
    if (isSuperUser) return 8;
    if (isContributor) return 5;
    return 3;
  }

  bool get advancedFilters => isPremium || isSuperUser;
  bool get premiumRecommendations => isPremium;
  bool get exclusivePlaces => isPremium;
  bool get customTripPlans => isPremium;

  bool get qualifiesForSuperUser {
    return stats.approvedContributions >= 10 &&
        stats.rejectedContributions <= 2;
  }

  String get roleLabel {
    switch (role) {
      case AppUserRole.admin:
        return 'Admin';
      case AppUserRole.superUser:
        return 'Super User';
      case AppUserRole.contributor:
        return 'Contributor';
      default:
        return 'Regular User';
    }
  }

  String get subscriptionLabel => isPremium ? 'Premium' : 'Free';
  String get label => '$roleLabel / $subscriptionLabel';

  String get benefitText {
    final roleText = switch (role) {
      AppUserRole.admin => 'Can moderate posts, reviews, reports, and users.',
      AppUserRole.superUser =>
        'Trusted local: badges, higher limits, and advanced community tools.',
      AppUserRole.contributor =>
        'Can add more places, build reputation, and earn Super User status.',
      _ =>
        'Browse, review, save favorites, and post your first place to become a Contributor.',
    };
    final premiumText = isPremium
        ? ' Premium unlocks the full LikeALocal experience.'
        : ' Upgrade to demo Premium for advanced filters, recommendations, and bigger limits.';
    return '$roleText$premiumText';
  }

  Map<String, dynamic> toFirestore() => {
        'role': role,
        'isPremium': isPremium,
        'subscription': subscription.toFirestore(),
        'isSuperUser': isSuperUser,
        'contributionCount': stats.totalContributions,
        'stats': stats.toFirestore(),
        'limits': limits.toFirestore(),
      };

  static Map<String, dynamic> defaultFirestoreData({
    required String uid,
    required String email,
    required String name,
    String photoUrl = '',
  }) {
    return {
      'uid': uid,
      'email': email,
      'displayName': name,
      'name': name,
      'bio': '',
      'photoUrl': photoUrl,
      'preferences': <String>[],
      'budgetPreference': '',
      'atmospherePreference': '',
      'areaPreference': '',
      'chatEnabled': true,
      'chatSchedule': {
        'enabled': false,
        'startTime': '10:00',
        'endTime': '18:00',
      },
      'publicProfile': true,
      'aiRecommendationsEnabled': true,
      ...UserRole.regularFree().toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

Future<UserRole> fetchUserRole(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return UserRole.fromData(doc.data());
}
