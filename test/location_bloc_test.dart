import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gps_tracking/domain/entities/location_record.dart';
import 'package:gps_tracking/domain/repositories/location_repository.dart';
import 'package:gps_tracking/presentation/bloc/location_bloc.dart';
import 'package:gps_tracking/presentation/bloc/location_event.dart';
import 'package:gps_tracking/presentation/bloc/location_state.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  // 1. Initialize the binding for plugins like Connectivity
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocationRepository mockRepository;

  setUpAll(() {
    // 2. Register fallback value for mocktail
    registerFallbackValue(
      LocationRecord(
        id: 'fallback',
        latitude: 0.0,
        longitude: 0.0,
        timestamp: DateTime.now(),
      ),
    );
  });

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

        when(() => mockRepository.syncWithMockApi(any()))
            .thenThrow(Exception('Network Error'));

        return LocationBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(SyncData()),
      expect: () => [
        isA<LocationState>().having((s) => s.status, 'status', TrackingStatus.syncing),
        isA<LocationState>()
            .having((s) => s.status, 'status', TrackingStatus.stopped)
            .having((s) => s.message, 'message', contains('API Failed')),
      ],
      verify: (_) {
        verify(() => mockRepository.syncWithMockApi(any())).called(1);
        verifyNever(() => mockRepository.markAsSynced(any()));
      },
    );
  });
}