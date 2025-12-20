import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:keepup/screens/friends_screen.dart';
import 'package:keepup/screens/profile_screen.dart';
import 'leaderboard_screen.dart';
//import 'run_screen.dart';
import 'setuprun_screen.dart';
import 'settings_screen.dart ';
import 'package:hive/hive.dart';
import '../models/run_stats.dart'; // stats model for saving run data
import '../services/run_storage.dart'; // service to save run data

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentPageIndex = 0;
  String _username = '';
  String _bestPace = '--:--'; // formatted pace string

  // loading in the profile data
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // loads profile data from Hive
  Future<void> _loadProfile() async {
    // Load the profile (username)
    final profile = await RunStorage.getProfile();

    // get all saved runs (excluding profile)
    final runs = await RunStorage.getAllRuns();

    double? fastest;
    // find best pace across all runs
    for (final run in runs) {
      final p = run.bestPace;
      if (p != null) {
        if (fastest == null || p < fastest) {
          fastest = p;
        }
      }
    }
    setState(() {
      _username = profile.username ?? 'unknown';
      _bestPace = _formatPace(fastest);
      debugPrint('Loaded profile: username=$_username, bestPace=$_bestPace');
    });
  }

  // Format pace (min/km) as mm:ss string
  String _formatPace(double? pace) {
    if (pace == null || !pace.isFinite || pace <= 0) return "--:--";
    final mins = pace.floor();
    final secs = ((pace - mins) * 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // get theme once for convenience
    final size = MediaQuery.of(context).size;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (context) => const SetupRunScreen()),
              )
              .then((_) => _loadProfile());
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: const CircleBorder(),

        child: FittedBox(
          child: SizedBox(
            width: 50, // fills the FAB
            height: 50,
            child: Image.asset('assets/run2.png'),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        notchMargin: 9,
        color: theme.colorScheme.primary,
        shape: const CircularNotchedRectangle(),
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    )
                    .then((_) => _loadProfile());
              },
              icon: Icon(Icons.settings, color: theme.colorScheme.onPrimary),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FriendsScreen(),
                  ),
                );
              },
              icon: Icon(Icons.group, color: theme.colorScheme.onPrimary),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
              icon: Icon(Icons.leaderboard, color: theme.colorScheme.onPrimary),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    )
                    .then((_) => _loadProfile());
              },
              icon: Icon(Icons.person, color: theme.colorScheme.onPrimary),
            ),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Home',
          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,

        // subtle gray fade blending with background
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0.0, 0.5),
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(50, 50, 50, 0.7), // slightly darker at top
                Color.fromRGBO(50, 50, 50, 0.4), // lighter in middle
                Colors.transparent, // fade out to fully transparent
              ],
            ),
          ),
        ),

        // the track icon
        leading: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Image.asset('assets/run.png', height: 50, width: 50),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
        ),
      ),

      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/20ffe1db632b3dbc3ddfae405183188e.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.7)),
          ),

          //  existing UI on top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 400,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: SvgPicture.asset(
                            'assets/username_banner.svg',
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                        Positioned(
                          top: 20,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _username,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  height: 0.9,
                                ),
                              ),
                              const Text(
                                'running since: 10/10/2025',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 300,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -150,
                            bottom: -150,
                            child: Image.asset(
                              'assets/SPLATTER.png',
                              width: 400,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            left: -50,
                            bottom: 125,
                            child: Text(
                              'best pace',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                height: 0.9,
                              ),
                            ),
                          ),
                          Positioned(
                            left: -50,
                            bottom: 100,
                            child: Text(
                              '$_bestPace min/km',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.normal,
                                height: 0.9,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -200,
                            bottom: -400,
                            child: Image.asset(
                              'assets/avatar.png',
                              width: 400,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
