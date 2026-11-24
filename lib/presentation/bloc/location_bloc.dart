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

  // 1. ADD TIMER FOR AUTOMATIC RETRY
  Timer? _retryTimer;

  final _uuid = const Uuid();
  bool _isActuallyTracking = false;

  LocationBloc({required this.repository}) : super(const LocationState()) {
    // Handle app startup to load SQLite data
    on<AppStarted>(_onAppStarted);

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

  // 2. LOAD PERSISTED DATA FROM SQLITE ON STARTUP
  Future<void> _onAppStarted(AppStarted event, Emitter<LocationState> emit) async {
    final savedRecords = await repository.getAllLocations();
    emit(state.copyWith(currentLocations: savedRecords));

    // If there are unsynced records waiting from a previous session, try to sync them
    if (savedRecords.any((loc) => !loc.isSynced)) {
      add(SyncData());
    }
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

    // Cancel any existing retry timer so we don't stack them
    _retryTimer?.cancel();

    emit(state.copyWith(status: TrackingStatus.syncing));

    try {
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
          break; // Stop syncing the rest if one fails to prevent hammering the API
        }
      }

      // RESTORE TRACKING STATE
      final finalStatus = _isActuallyTracking ? TrackingStatus.tracking : TrackingStatus.stopped;

      if (hasFailure) {
        emit(state.copyWith(
            status: finalStatus,
            currentLocations: updatedList,
            message: 'API Failed. Auto-retrying in 10 seconds...'
        ));

        // 3. START AUTOMATIC RETRY TIMER
        _retryTimer = Timer(const Duration(seconds: 10), () {
          add(SyncData());
        });

      } else {
        emit(state.copyWith(
            status: finalStatus,
            currentLocations: updatedList,
            message: 'Sync successful!'
        ));
      }
    } catch (e) {
      // Catch unexpected errors
      final finalStatus = _isActuallyTracking ? TrackingStatus.tracking : TrackingStatus.stopped;
      emit(state.copyWith(status: finalStatus, message: 'Unexpected error occurred.'));
    }
  }

  @override
  Future<void> close() {
    _retryTimer?.cancel(); // Clean up timer memory leak
    _positionStream?.cancel();
    _connectivityStream?.cancel();
    return super.close();
  }
}