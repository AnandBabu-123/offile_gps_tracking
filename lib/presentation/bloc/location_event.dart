import 'package:equatable/equatable.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();
  @override
  List<Object> get props => [];
}

class StartTracking extends LocationEvent {}
class StopTracking extends LocationEvent {}
class NewLocationReceived extends LocationEvent {
  final double lat;
  final double lng;
  const NewLocationReceived(this.lat, this.lng);
  @override
  List<Object> get props => [lat, lng];
}
class SyncData extends LocationEvent {}