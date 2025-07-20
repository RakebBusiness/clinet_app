import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RiderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get nearby riders within specified radius
  Future<List<RiderData>> getNearbyRiders({
    required LatLng userLocation,
    double radiusKm = 10.0,
  }) async {
    try {
      print('🔍 Fetching riders from database...');

      // Fallback to direct query
      return await _getFallbackRiders(userLocation, radiusKm);
    } catch (e) {
      print('Error fetching nearby riders: $e');

      // Fallback: fetch all online riders and calculate distance manually
      return await _getFallbackRiders(userLocation, radiusKm);
    }
  }

  // Fallback method if the RPC function doesn't work
  Future<List<RiderData>> _getFallbackRiders(
    LatLng userLocation,
    double radiusKm,
  ) async {
    try {
      print('🔍 Fetching riders using fallback method...');

      final response = await _supabase
          .from('motards')
          .select('*')
          .eq('status', 'online')
          .eq('statut_bloque', false)
          .eq('is_verified', true)
          .limit(20);

      if (response == null || response.isEmpty) {
        print('⚠️ No riders found in database');
        print('💡 You need to add test riders manually to Supabase');
        return [];
      }

      print('📍 Found ${response.length} riders in database');

      List<RiderData> riders = [];

      for (var rider in response) {
        try {
          // Parse location - handle both PostGIS point and null values
          LatLng riderLocation;
          double distance;

          if (rider['current_location'] != null) {
            String locationStr = rider['current_location'].toString();
            print('📍 Parsing location: $locationStr');

            if (locationStr.startsWith('POINT(')) {
              String coords = locationStr.substring(6, locationStr.length - 1);
              List<String> parts = coords.split(' ');
              if (parts.length == 2) {
                double lng = double.tryParse(parts[0]) ?? 3.5892;
                double lat = double.tryParse(parts[1]) ?? 36.5644;
                riderLocation = LatLng(lat, lng);
              } else {
                riderLocation = const LatLng(
                  36.5644,
                  3.5892,
                ); // Default to Lakhdaria
              }
            } else {
              riderLocation = const LatLng(
                36.5644,
                3.5892,
              ); // Default to Lakhdaria
            }
          } else {
            // If no location, place near Lakhdaria with some random offset
            double latOffset = (riders.length * 0.01) - 0.02;
            double lngOffset = (riders.length * 0.01) - 0.02;
            riderLocation = LatLng(36.5644 + latOffset, 3.5892 + lngOffset);
          }

          // Calculate distance
          distance =
              Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                riderLocation.latitude,
                riderLocation.longitude,
              ) /
              1000; // Convert to km

          print(
            '📏 Distance to ${rider['nom_complet']}: ${distance.toStringAsFixed(2)}km',
          );

          if (distance <= radiusKm) {
            riders.add(
              RiderData(
                id: rider['id'],
                nomComplet: rider['nom_complet'] ?? 'Unknown',
                numTel: rider['num_tel'] ?? '',
                ratingAverage: (rider['rating_average'] ?? 4.5).toDouble(),
                currentLocation: riderLocation,
                distanceKm: distance,
                status: rider['status'] ?? 'online',
              ),
            );
          }
        } catch (parseError) {
          print('❌ Error parsing rider ${rider['nom_complet']}: $parseError');
        }
      }

      // Sort by distance
      riders.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      print('✅ Found ${riders.length} riders within ${radiusKm}km');
      return riders;
    } catch (e) {
      print('Error in fallback rider fetch: $e');
      return [];
    }
  }

  // Create test riders for Lakhdaria, Bouira area
  Future<void> createTestRiders() async {
    try {
      // Check if we have any riders already
      final existingRiders = await _supabase
          .from('motards')
          .select('id')
          .limit(1);

      if (existingRiders.isNotEmpty) {
        print('✅ Riders already exist in database');
        return;
      }

      print('🏍️ Creating test riders in Lakhdaria area...');

      // Create riders with minimal required fields
      final testRiders = [
        {
          'nom_complet': 'Test Rider 1',
          'num_tel': '+213661234567',
          'status': 'online',
          'is_verified': true,
          'rating_average': 4.5,
          'current_location': 'POINT(3.5892 36.5644)',
          'statut_bloque': false,
        },
        // Add more test riders...
      ];

      for (var rider in testRiders) {
        try {
          await _supabase.from('motards').insert(rider);
          print('✅ Created rider: ${rider['nom_complet']}');
        } catch (e) {
          print('❌ Failed to create rider ${rider['nom_complet']}: $e');
        }
      }
    } catch (e) {
      print('Error creating test riders: $e');
    }
  }

  // Get rider details by ID
  Future<RiderData?> getRiderById(String riderId) async {
    try {
      final response = await _supabase
          .from('motards')
          .select('*')
          .eq('id', riderId)
          .single();

      return RiderData.fromJson(response);
    } catch (e) {
      print('Error fetching rider details: $e');
      return null;
    }
  }

  // Update rider location (for testing purposes)
  Future<void> updateRiderLocation(String riderId, LatLng newLocation) async {
    try {
      await _supabase
          .from('motards')
          .update({
            'current_location':
                'POINT(${newLocation.longitude} ${newLocation.latitude})',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', riderId);
    } catch (e) {
      print('Error updating rider location: $e');
    }
  }
}

class RiderData {
  final String id;
  final String nomComplet;
  final String numTel;
  final double ratingAverage;
  final LatLng currentLocation;
  final double distanceKm;
  final String status;

  RiderData({
    required this.id,
    required this.nomComplet,
    required this.numTel,
    required this.ratingAverage,
    required this.currentLocation,
    required this.distanceKm,
    required this.status,
  });

  factory RiderData.fromJson(Map<String, dynamic> json) {
    // Parse location from different possible formats
    LatLng location = const LatLng(36.5644, 3.5892); // Default to Lakhdaria

    if (json['current_location'] != null) {
      String locationStr = json['current_location'].toString();
      if (locationStr.startsWith('POINT(')) {
        String coords = locationStr.substring(6, locationStr.length - 1);
        List<String> parts = coords.split(' ');
        if (parts.length == 2) {
          double lng = double.parse(parts[0]);
          double lat = double.parse(parts[1]);
          location = LatLng(lat, lng);
        }
      }
    }

    return RiderData(
      id: json['id'] ?? '',
      nomComplet: json['nom_complet'] ?? 'Unknown Rider',
      numTel: json['num_tel'] ?? '',
      ratingAverage: (json['rating_average'] ?? 0.0).toDouble(),
      currentLocation: location,
      distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'offline',
    );
  }
}
