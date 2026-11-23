import 'dart:math';
import '../../domain/entities/location_record.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/local_database.dart';
import '../datasources/mock_api_client.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocalDatabase localDatabase;
  final MockApiClient apiClient;

  LocationRepositoryImpl({required this.localDatabase, required this.apiClient});

  @override
  Future<void> saveLocationLocally(LocationRecord record) async {
    await localDatabase.insertLocation(record);
  }

  @override
  Future<List<LocationRecord>> getUnsyncedLocations() async {
    return await localDatabase.getUnsyncedLocations();
  }

  @override
  Future<void> markAsSynced(String id) async {
    await localDatabase.markAsSynced(id);
  }

  @override
  Future<bool> syncWithMockApi(LocationRecord record) async {
    return await apiClient.uploadLocation({
      'id': record.id,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'timestamp': record.timestamp.toIso8601String(),
    });
  }
}