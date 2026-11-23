import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'location_event.dart';
import 'location_state.dart';
import '../../domain/entities/location_record.dart';
import '../../domain/repositories/location_repository.dart';


class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository repository;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivityStream;
  final _uuid = const Uuid();

  // Track internal tracking status to prevent sync from stopping it
  bool _isActuallyTracking = false;

  LocationBloc({required this.repository}) : super(const LocationState()) {
    on<StartTracking>(_onStartTracking);
    on<StopTracking>(_onStopTracking);
    on<NewLocationReceived>(_onNewLocationReceived);
    on<SyncData>(_onSyncData);

    // Auto-sync when internet returns
    _connectivityStream = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        add(SyncData());
      }
    });
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<LocationState> emit) async {
    emit(state.copyWith(status: TrackingStatus.loading));

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        emit(state.copyWith(status: TrackingStatus.error, message: 'Permission denied'));
        return;
      }
    }

    _isActuallyTracking = true;
    emit(state.copyWith(status: TrackingStatus.tracking));

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      add(NewLocationReceived(position.latitude, position.longitude));
    });
  }

  Future<void> _onStopTracking(StopTracking event, Emitter<LocationState> emit) async {
    await _positionStream?.cancel();
    _isActuallyTracking = false;
    emit(state.copyWith(status: TrackingStatus.stopped));
  }

  Future<void> _onNewLocationReceived(NewLocationReceived event, Emitter<LocationState> emit) async {
    final newRecord = LocationRecord(
      id: _uuid.v4(), // UUID prevents duplicates
      latitude: event.lat,
      longitude: event.lng,
      timestamp: DateTime.now(),
    );

    await repository.saveLocationLocally(newRecord);
    final updatedList = List<LocationRecord>.from(state.currentLocations)..add(newRecord);
    emit(state.copyWith(currentLocations: updatedList));

    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      add(SyncData());
    } else {
      emit(state.copyWith(message: 'Offline: Saved locally. Waiting for internet.'));
    }
  }

  Future<void> _onSyncData(SyncData event, Emitter<LocationState> emit) async {
    if (state.status == TrackingStatus.syncing) return; // Prevent concurrent syncs

    emit(state.copyWith(status: TrackingStatus.syncing));
    final unsynced = await repository.getUnsyncedLocations();

    if (unsynced.isEmpty) {
      final resetStatus = _isActuallyTracking ? TrackingStatus.tracking : TrackingStatus.stopped;
      emit(state.copyWith(status: resetStatus));
      return;
    }

    bool hasFailure = false;
    List<LocationRecord> updatedList = List.from(state.currentLocations);

    for (var record in unsynced) {
      try {
        final success = await repository.syncWithMockApi(record);
        if (success) {
          await repository.markAsSynced(record.id);

          final index = updatedList.indexWhere((element) => element.id == record.id);
          if (index != -1) {
            updatedList[index] = LocationRecord(
              id: record.id,
              latitude: record.latitude,
              longitude: record.longitude,
              timestamp: record.timestamp,
              isSynced: true, // Update UI to show green cloud
            );
          }
        }
      } catch (e) {
        hasFailure = true;
        break; // Break on failure to trigger retry later
      }
    }

    // RESTORE TRACKING STATE (Fixes Issue #4)
    final finalStatus = _isActuallyTracking ? TrackingStatus.tracking : TrackingStatus.stopped;

    if (hasFailure) {
      emit(state.copyWith(
          status: finalStatus,
          currentLocations: updatedList,
          message: 'API Failed. Tap "Retry Sync" to try again.'
      ));
    } else {
      emit(state.copyWith(
          status: finalStatus,
          currentLocations: updatedList,
          message: 'Sync successful!'
      ));
    }
  }

  @override
  Future<void> close() {
    _positionStream?.cancel();
    _connectivityStream?.cancel();
    return super.close();
  }
}