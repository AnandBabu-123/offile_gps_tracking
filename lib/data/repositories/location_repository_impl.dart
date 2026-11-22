
import '../../domian/entities/location_record.dart';
import '../../domian/repositories/location_repository.dart';
import '../datasources/local_database.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocalDatabase localDatabase;

  LocationRepositoryImpl({required this.localDatabase});

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
    // Mock REST API call simulation
    await Future.delayed(const Duration(seconds: 1));
    // Simulate success. In reality, use http.post() here.
    return true;
  }
}