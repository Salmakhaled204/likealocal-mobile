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
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    DateTime? timestampToDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return Place(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'Other',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      location: data['location'] ?? const GeoPoint(0, 0),
      address: data['address'] ?? '',
      budget: data['budget'] ?? '',
      atmosphere: data['atmosphere'] ?? '',
      localTip: data['localTip'] ?? '',
      recommendedDish: data['recommendedDish'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerName:
          data['createdByName'] ?? data['ownerName'] ?? 'Local contributor',
      ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
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
