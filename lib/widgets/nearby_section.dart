import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// C3 — Nearby places: quick categories + free search, results with
/// ratings, distance, price, open-now, and one-tap CALL / DIRECTIONS.
class NearbySection extends StatefulWidget {
  const NearbySection({super.key});

  @override
  State<NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends State<NearbySection> {
  final _search = TextEditingController();

  static const _quick = [
    ('Restaurants', Icons.restaurant_rounded, 'restaurants near me'),
    ('Pharmacy', Icons.local_pharmacy_rounded, 'pharmacy near me'),
    ('Groceries', Icons.local_grocery_store_rounded, 'grocery store near me'),
    ('Petrol', Icons.local_gas_station_rounded, 'petrol bunk near me'),
    ('ATM', Icons.atm_rounded, 'atm near me'),
    ('Hospital', Icons.local_hospital_rounded, 'hospital near me'),
  ];

  void _go(String q) {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ResultsSheet(query: q.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.near_me_rounded,
                  size: 20, color: AppColors.peacock),
              const SizedBox(width: 8),
              Text('Nearby', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, icon, q) in _quick)
                  ActionChip(
                    avatar: Icon(icon, size: 17),
                    label: Text(label),
                    onPressed: () => _go(q),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _go,
              decoration: InputDecoration(
                hintText: 'Search shops & services near you…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _ResultsSheet extends StatefulWidget {
  final String query;
  const _ResultsSheet({required this.query});

  @override
  State<_ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends State<_ResultsSheet> {
  List<Place>? _places;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.fetchPlaces(widget.query).then((p) {
      if (mounted) setState(() => _places = p);
    }).catchError((_) {
      if (mounted) {
        setState(() => _error = "Couldn't search right now. Try again.");
      }
    });
  }

  Future<void> _call(Place p) async {
    final phone = p.phone;
    if (phone == null) return;
    await launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}'));
  }

  Future<void> _directions(Place p) async {
    // Universal maps URL: opens Google Maps app on Android, browser elsewhere.
    final dest = (p.lat != null && p.lng != null)
        ? '${p.lat},${p.lng}'
        : Uri.encodeComponent('${p.name} ${p.address}');
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(widget.query,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger)))
            else if (places == null)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (places.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Nothing found nearby for that.'))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _placeCard(places[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeCard(Place p) {
    final sub = [
      if (p.rating != null)
        '${p.rating!.toStringAsFixed(1)}★${p.ratingCount != null ? ' (${p.ratingCount})' : ''}',
      if (p.distanceKm != null) '${p.distanceKm} km',
      if (p.price != null) p.price!,
      if (p.openNow == true) 'Open now',
      if (p.openNow == false) 'Closed',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (p.photoRef != null)
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Image.network(
                    ApiService.placePhotoUrl(p.photoRef!),
                    headers: ApiService.imageHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.mist,
                        child: Icon(Icons.storefront_rounded,
                            color: AppColors.peacock)),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      if (sub.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(sub,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.openNow == false
                                      ? AppColors.danger
                                      : null)),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(p.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6))),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                if (p.phone != null)
                  TextButton.icon(
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call'),
                    onPressed: () => _call(p),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Directions'),
                  onPressed: () => _directions(p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
