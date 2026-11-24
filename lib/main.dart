import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gps_tracking/presentation/bloc/location_event.dart';
import 'package:gps_tracking/presentation/pages/home_screen.dart';
import 'data/datasources/local_database.dart';
import 'data/datasources/mock_api_client.dart';
import 'data/repositories/location_repository_impl.dart';
import 'presentation/bloc/location_bloc.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDatabase();
  final apiClient = MockApiClient();

  runApp(MyApp(localDb: localDb, apiClient: apiClient));
}

class MyApp extends StatelessWidget {
  final LocalDatabase localDb;
  final MockApiClient apiClient;

  const MyApp({
    super.key,
    required this.localDb,
    required this.apiClient,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LocationBloc(
        repository: LocationRepositoryImpl(
          localDatabase: localDb,
          apiClient: apiClient,
        ),
      )..add(AppStarted()),
      child: MaterialApp(
        title: 'Location Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}