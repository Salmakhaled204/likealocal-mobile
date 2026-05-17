import 'package:cloud_firestore/cloud_firestore.dart';

class AppUserRole {
  static const regular = 'regular';
  static const contributor = 'contributor';
  static const superUser = 'super_user';
  static const admin = 'admin';
}

class AppSubscription {
  static const free = 'free';
  static const premium = 'premium';
}

class UserStats {
  final int totalContributions;
  final int totalReviews;
  final int helpfulVotes;
  final double averageRating;
  final int reportCount;

  const UserStats({
    required this.totalContributions,
    required this.totalReviews,
    required this.helpfulVotes,
    required this.averageRating,
    required this.reportCount,
  });

  factory UserStats.fromData(Map<String, dynamic>? data) {
    return UserStats(
      totalContributions: (data?['totalContributions'] as num?)?.toInt() ?? 0,
      totalReviews: (data?['totalReviews'] as num?)?.toInt() ?? 0,
      helpfulVotes: (data?['helpfulVotes'] as num?)?.toInt() ?? 0,
      averageRating: (data?['averageRating'] as num?)?.toDouble() ?? 0,
      reportCount: (data?['reportCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'totalContributions': totalContributions,
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

  const UsageLimits({
    required this.pinsUsed,
    required this.remindersUsed,
    required this.aiRequestsToday,
  });

  factory UsageLimits.fromData(Map<String, dynamic>? data) {
    return UsageLimits(
      pinsUsed: (data?['pinsUsed'] as num?)?.toInt() ?? 0,
      remindersUsed: (data?['remindersUsed'] as num?)?.toInt() ?? 0,
      aiRequestsToday: (data?['aiRequestsToday'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'pinsUsed': pinsUsed,
    'remindersUsed': remindersUsed,
    'aiRequestsToday': aiRequestsToday,
  };
}

class UserRole {
  final String role;
  final String subscription;
  final UserStats stats;
  final UsageLimits limits;

  const UserRole({
    required this.role,
    required this.subscription,
    required this.stats,
    required this.limits,
  });

  factory UserRole.regularFree() => const UserRole(
    role: AppUserRole.regular,
    subscription: AppSubscription.free,
    stats: UserStats(
      totalContributions: 0,
      totalReviews: 0,
      helpfulVotes: 0,
      averageRating: 0,
      reportCount: 0,
    ),
    limits: UsageLimits(pinsUsed: 0, remindersUsed: 0, aiRequestsToday: 0),
  );

  factory UserRole.fromData(Map<String, dynamic>? data) {
    final legacyType = (data?['userType'] ?? '').toString();
    final resolvedRole = _resolveRole(
      (data?['role'] ?? '').toString(),
      legacyType,
      data?['isSuperUser'] == true,
    );
    final resolvedSubscription = _resolveSubscription(
      (data?['subscription'] ?? '').toString(),
      data?['isPremium'] == true || legacyType == 'premium',
    );

    final statsData = data?['stats'] is Map<String, dynamic>
        ? data!['stats'] as Map<String, dynamic>
        : <String, dynamic>{
            'totalContributions':
                data?['contributionCount'] ?? data?['totalContributions'] ?? 0,
            'totalReviews': data?['totalReviews'] ?? 0,
            'helpfulVotes': data?['helpfulVotes'] ?? 0,
            'averageRating': data?['averageRating'] ?? 0,
            'reportCount': data?['reportCount'] ?? 0,
          };

    return UserRole(
      role: resolvedRole,
      subscription: resolvedSubscription,
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
    if (legacySuper || legacyType == 'super') return AppUserRole.superUser;
    if (legacyType == 'contributor') return AppUserRole.contributor;
    return AppUserRole.regular;
  }

  static String _resolveSubscription(String subscription, bool legacyPremium) {
    if (subscription == AppSubscription.premium ||
        subscription == AppSubscription.free) {
      return subscription;
    }
    return legacyPremium ? AppSubscription.premium : AppSubscription.free;
  }

  bool get isRegular => role == AppUserRole.regular;
  bool get isContributor => role == AppUserRole.contributor;
  bool get isSuperUser => role == AppUserRole.superUser;
  bool get isAdmin => role == AppUserRole.admin;
  bool get isPremium => subscription == AppSubscription.premium;

  bool get canAddPlaces => isContributor || isSuperUser || isAdmin;
  bool canManagePlace(String ownerId, String uid) => isAdmin || ownerId == uid;
  bool get canModerate => isAdmin;
  bool get canBePublicTrusted => isSuperUser;

  int get maxPins => isPremium
      ? 100
      : isSuperUser
      ? 20
      : 5;
  int get maxReminders => isPremium
      ? 50
      : isSuperUser
      ? 10
      : 3;
  int get maxAiRequestsPerDay => isPremium
      ? 100
      : isSuperUser
      ? 25
      : 10;
  int get maxUploadsPerPlace => isPremium
      ? 15
      : isSuperUser
      ? 8
      : 3;

  bool get qualifiesForSuperUser {
    return stats.totalContributions >= 10 &&
        stats.averageRating >= 4.3 &&
        stats.reportCount <= 2 &&
        stats.helpfulVotes >= 20;
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
        'Trusted local: higher visibility, badge, and higher free limits.',
      AppUserRole.contributor =>
        'Can add places, upload media, and manage only their own posts.',
      _ => 'Can explore, save places, set reminders, chat, and review places.',
    };
    final premiumText = isPremium
        ? ' Premium unlocks higher pins, reminders, AI usage, and uploads.'
        : ' Free limits apply until Premium is enabled.';
    return '$roleText$premiumText';
  }

  Map<String, dynamic> toFirestore() => {
    'role': role,
    'subscription': subscription,
    'isSuperUser': isSuperUser,
    'isPremium': isPremium,
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
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  return UserRole.fromData(doc.data());
}
