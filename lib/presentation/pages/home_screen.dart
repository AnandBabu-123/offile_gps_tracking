import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message!)),
            );
          }
        },
        builder: (context, state) {
          final hasUnsynced = state.currentLocations.any((loc) => !loc.isSynced);

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(state),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: state.status == TrackingStatus.tracking
                          ? null
                          : () => context.read<LocationBloc>().add(StartTracking()),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                    ),
                    ElevatedButton.icon(
                      onPressed: state.status != TrackingStatus.tracking
                          ? null
                          : () => context.read<LocationBloc>().add(StopTracking()),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                    ),
                  ],
                ),
                if (hasUnsynced)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: state.status == TrackingStatus.syncing
                          ? null
                          : () => context.read<LocationBloc>().add(SyncData()),
                      icon: state.status == TrackingStatus.syncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync),
                      label: Text(state.status == TrackingStatus.syncing ? 'Syncing...' : 'Retry Sync'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        foregroundColor: Colors.orange.shade900,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text("Recorded Locations:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.currentLocations.length,
                    itemBuilder: (context, index) {
                      final loc = state.currentLocations[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            loc.isSynced ? Icons.cloud_done : Icons.cloud_off,
                            color: loc.isSynced ? Colors.green : Colors.red,
                          ),
                          title: Text('Lat: ${loc.latitude.toStringAsFixed(4)}, Lng: ${loc.longitude.toStringAsFixed(4)}'),
                          subtitle: Text(
                            loc.isSynced ? 'Synced' : 'Not Synced (Pending Upload)',
                            style: TextStyle(color: loc.isSynced ? Colors.grey : Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(LocationState state) {
    Color color;
    String text;
    IconData icon;

    switch (state.status) {
      case TrackingStatus.tracking:
        color = Colors.green;
        text = 'Tracking Active';
        icon = Icons.gps_fixed;
        break;
      case TrackingStatus.syncing:
        color = Colors.orange;
        text = 'Syncing...';
        icon = Icons.sync;
        break;
      case TrackingStatus.error:
        color = Colors.red;
        text = state.message ?? 'Error';
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        text = 'Tracking Stopped';
        icon = Icons.gps_off;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text('Total records: ${state.currentLocations.length}'),
        ],
      ),
    );
  }
}