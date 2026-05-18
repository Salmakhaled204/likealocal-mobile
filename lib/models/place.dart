import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final GeoPoint location;
  final String address;
  final String budget;
  final String atmosphere;
  final String localTip;
  final String recommendedDish;
  final String ownerId;
  final String ownerName;
  final bool ownerIsSuperUser;
  final double averageRating;
  final int reviewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Place({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrls,
    required this.videoUrls,
    required this.location,
    required this.address,
    required this.budget,
    required this.atmosphere,
    required this.localTip,
    required this.recommendedDish,
    required this.ownerId,
    required this.ownerName,
    required this.ownerIsSuperUser,
    required this.averageRating,
    required this.reviewCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Place.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

    String readString(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value : fallback;
    }

    List<String> readStringList(String key) {
      final value = data[key];
      if (value is! List) return <String>[];
      return value.whereType<String>().toList();
    }

    double readDouble(String key) {
      final value = data[key];
      return value is num ? value.toDouble() : 0.0;
    }

    int readInt(String key) {
      final value = data[key];
      return value is num ? value.toInt() : 0;
    }

    GeoPoint readGeoPoint(String key) {
      final value = data[key];
      return value is GeoPoint ? value : const GeoPoint(0, 0);
    }

    DateTime? timestampToDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return Place(
      id: doc.id,
      title: readString('title'),
      description: readString('description'),
      category: readString('category', 'Other'),
      imageUrls: readStringList('imageUrls'),
      videoUrls: readStringList('videoUrls'),
      location: readGeoPoint('location'),
      address: readString('address'),
      budget: readString('budget'),
      atmosphere: readString('atmosphere'),
      localTip: readString('localTip'),
      recommendedDish: readString('recommendedDish'),
      ownerId: readString('ownerId'),
      ownerName: readString(
        'createdByName',
        readString('ownerName', 'Local contributor'),
      ),
      ownerIsSuperUser: data['ownerIsSuperUser'] == true,
      averageRating: readDouble('averageRating'),
      reviewCount: readInt('reviewCount'),
      createdAt: timestampToDate(data['createdAt']),
      updatedAt: timestampToDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'location': location,
      'address': address,
      'budget': budget,
      'atmosphere': atmosphere,
      'localTip': localTip,
      'recommendedDish': recommendedDish,
      'ownerId': ownerId,
      'createdByName': ownerName,
      'ownerIsSuperUser': ownerIsSuperUser,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
    };
  }
}
