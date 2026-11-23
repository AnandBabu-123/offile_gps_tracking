import 'package:equatable/equatable.dart';
import '../../domain/entities/location_record.dart';

enum TrackingStatus { initial, loading, tracking, stopped, syncing, error }

class LocationState extends Equatable {
  final TrackingStatus status;
  final List<LocationRecord> currentLocations;
  final String? message;

  const LocationState({
    this.status = TrackingStatus.initial,
    this.currentLocations = const [],
    this.message,
  });

  LocationState copyWith({
    TrackingStatus? status,
    List<LocationRecord>? currentLocations,
    String? message,
  }) {
    return LocationState(
      status: status ?? this.status,
      currentLocations: currentLocations ?? this.currentLocations,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, currentLocations, message];
}