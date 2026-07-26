/// C3 — one nearby place (restaurant, shop, service…).
class Place {
  final String name;
  final double? rating;
  final int? ratingCount;
  final String? price; // ₹ … ₹₹₹₹
  final bool? openNow;
  final String address;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? photoRef;
  final double? distanceKm;

  const Place({
    required this.name,
    this.rating,
    this.ratingCount,
    this.price,
    this.openNow,
    this.address = '',
    this.lat,
    this.lng,
    this.phone,
    this.photoRef,
    this.distanceKm,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: (j['name'] ?? '').toString(),
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['ratingCount'] as num?)?.toInt(),
        price: j['price']?.toString(),
        openNow: j['openNow'] as bool?,
        address: (j['address'] ?? '').toString(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        phone: j['phone']?.toString(),
        photoRef: j['photoRef']?.toString(),
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      );
}
