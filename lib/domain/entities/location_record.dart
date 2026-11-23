import 'package:equatable/equatable.dart';

class LocationRecord extends Equatable {
  final String id; // UUID to prevent duplicates
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isSynced;

  const LocationRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isSynced = false,
  });

  @override
  List<Object> get props => [id, latitude, longitude, timestamp, isSynced];
}