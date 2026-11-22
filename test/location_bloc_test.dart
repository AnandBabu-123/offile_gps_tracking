import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import '../lib/domian/entities/location_record.dart';
import '../lib/domian/repositories/location_repository.dart';
import '../lib/presentation/bloc/location_bloc.dart';
import '../lib/presentation/bloc/location_event.dart';
import '../lib/presentation/bloc/location_state.dart';


class MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  late MockLocationRepository mockRepository;

  setUp(() {
    mockRepository = MockLocationRepository();
  });

  group('LocationBloc Sync Tests', () {
    blocTest<LocationBloc, LocationState>(
      'emits synced state when SyncData is added and repository returns unsynced items',
      build: () {
        when(() => mockRepository.getUnsyncedLocations()).thenAnswer((_) async => [
          LocationRecord(id: '1', latitude: 10, longitude: 20, timestamp: DateTime.now(), isSynced: false)
        ]);
        when(() => mockRepository.syncWithMockApi(any())).thenAnswer((_) async => true);
        when(() => mockRepository.markAsSynced(any())).thenAnswer((_) async {});
        return LocationBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(SyncData()),
      expect: () => [
        isA<LocationState>().having((s) => s.status, 'status', TrackingStatus.syncing),
        isA<LocationState>().having((s) => s.status, 'status', TrackingStatus.synced),
      ],
      verify: (_) {
        verify(() => mockRepository.getUnsyncedLocations()).called(1);
        verify(() => mockRepository.syncWithMockApi(any())).called(1);
        verify(() => mockRepository.markAsSynced('1')).called(1);
      },
    );
  });
}