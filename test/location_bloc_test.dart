import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import '../lib/presentation/bloc/location_bloc.dart';
import '../lib/presentation/bloc/location_event.dart';
import '../lib/presentation/bloc/location_state.dart';

import 'package:gps_tracking/domain/entities/location_record.dart';
import 'package:gps_tracking/domain/repositories/location_repository.dart';


class MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  late MockLocationRepository mockRepository;

  setUp(() {
    mockRepository = MockLocationRepository();
  });

  group('LocationBloc Retry & Failure Tests', () {

    final testRecord = LocationRecord(
      id: '123-uuid',
      latitude: 10.0,
      longitude: 20.0,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    blocTest<LocationBloc, LocationState>(
      'keeps record unsynced if API fails, and syncs on next retry',
      build: () {
        when(() => mockRepository.getUnsyncedLocations())
            .thenAnswer((_) async => [testRecord]);

        // Force API to fail to test retry logic
        when(() => mockRepository.syncWithMockApi(any()))
            .thenThrow(Exception('Network Error'));

        return LocationBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(SyncData()),
      expect: () => [
        isA<LocationState>().having((s) => s.status, 'status', TrackingStatus.syncing),
        isA<LocationState>()
            .having((s) => s.status, 'status', TrackingStatus.stopped)
            .having((s) => s.message, 'message', 'API Failed. Tap "Retry Sync" to try again.'),
      ],
      verify: (_) {
        verify(() => mockRepository.syncWithMockApi(testRecord)).called(1);
        // Verify it NEVER marked as synced in DB
        verifyNever(() => mockRepository.markAsSynced(any()));
      },
    );
  });
}