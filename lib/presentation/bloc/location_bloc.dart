import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../domian/entities/location_record.dart';
import '../../domian/repositories/location_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository repository;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivityStream;
  final _uuid = const Uuid();

  LocationBloc({required this.repository}) : super(const LocationState()) {
    on<StartTracking>(_onStartTracking);
    on<StopTracking>(_onStopTracking);
    on<NewLocationReceived>(_onNewLocationReceived);
    on<SyncData>(_onSyncData);

    // Listen to connectivity changes
    _connectivityStream = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        add(SyncData());
      }
    });
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<LocationState> emit) async {
    emit(state.copyWith(status: TrackingStatus.loading));

    // Request Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        emit(state.copyWith(status: TrackingStatus.error, message: 'Permission denied'));
        return;
      }
    }

    emit(state.copyWith(status: TrackingStatus.tracking));

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      add(NewLocationReceived(position.latitude, position.longitude));
    });
  }

  Future<void> _onStopTracking(StopTracking event, Emitter<LocationState> emit) async {
    await _positionStream?.cancel();
    emit(state.copyWith(status: TrackingStatus.stopped));
  }

  Future<void> _onNewLocationReceived(NewLocationReceived event, Emitter<LocationState> emit) async {
    final newRecord = LocationRecord(
      id: _uuid.v4(), // Unique ID prevents duplicates
      latitude: event.lat,
      longitude: event.lng,
      timestamp: DateTime.now(),
    );

    // Save locally first (Offline-first approach)
    await repository.saveLocationLocally(newRecord);

    final updatedList = List<LocationRecord>.from(state.currentLocations)..add(newRecord);
    emit(state.copyWith(currentLocations: updatedList));

    // Try to sync if online
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      add(SyncData());
    }
  }

  Future<void> _onSyncData(SyncData event, Emitter<LocationState> emit) async {
    emit(state.copyWith(status: TrackingStatus.syncing));
    final unsynced = await repository.getUnsyncedLocations();

    for (var record in unsynced) {
      final success = await repository.syncWithMockApi(record);
      if (success) {
        await repository.markAsSynced(record.id);
      }
    }

    emit(state.copyWith(status: TrackingStatus.synced, message: 'Synced successfully'));

    // Reset status after a brief delay for UI purposes
    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(status: state.status == TrackingStatus.tracking ? TrackingStatus.tracking : TrackingStatus.stopped));
  }

  @override
  Future<void> close() {
    _positionStream?.cancel();
    _connectivityStream?.cancel();
    return super.close();
  }
}