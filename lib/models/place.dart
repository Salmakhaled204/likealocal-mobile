import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String title;
  final String description;
  final String category;
  final List<String> imageUrls;
  final GeoPoint location;
  final String ownerId;
  final bool ownerIsSuperUser;
  final double averageRating;

  Place({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrls,
    required this.location,
    required this.ownerId,
    required this.ownerIsSuperUser,
    required this.averageRating,
  });

  factory Place.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Place.fromMap(doc.id, data);
  }

  factory Place.fromMap(String id, Map<String, dynamic> data) {
    return Place(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'Other',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      location: data['location'] ?? const GeoPoint(0, 0),
      ownerId: data['ownerId'] ?? '',
      ownerIsSuperUser: data['ownerIsSuperUser'] ?? false,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'imageUrls': imageUrls,
      'location': location,
      'ownerId': ownerId,
      'ownerIsSuperUser': ownerIsSuperUser,
      'averageRating': averageRating,
    };
  }
}
