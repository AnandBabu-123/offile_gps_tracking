import '../entities/location_record.dart';

abstract class LocationRepository {
  Future<void> saveLocationLocally(LocationRecord record);
  Future<List<LocationRecord>> getUnsyncedLocations();
  Future<List<LocationRecord>> getAllLocations(); // ADD THIS
  Future<void> markAsSynced(String id);
  Future<bool> syncWithMockApi(LocationRecord record);
}