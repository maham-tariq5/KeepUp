import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/run_stats.dart';
import 'package:keepup/theme.dart';
import 'screens/home_screen.dart';
import 'screens/run_screen.dart'; 
import 'screens/setuprun_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/friends_screen.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  // initialize Hive
  await Hive.initFlutter();

  // register adapters
  Hive.registerAdapter(RunStatsAdapter());

  // open your boxes
  var statsBox = await Hive.openBox<RunStats>('stats');   // store runs

  // create a default profile if none exists
  if (!statsBox.containsKey('profile')) {
    statsBox.put(
      'profile',
      RunStats(
        username: "Runner",
        avgPace: null,
        bestPace: null,
        paceSamples: [],
        durationSeconds: 0,
        paceGoalMinPerKm: 0,
        timestamp: DateTime.now(),
      ),
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        // '/run': (context) => const RunScreen(), 
        '/setupRun': (context) => const SetupRunScreen(),
        '/leaderboard':(context) => const LeaderboardScreen(),
        '/friends':(context) => const FriendsScreen()
      },
    );
  }
}
