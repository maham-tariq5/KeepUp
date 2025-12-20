import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepup/services/run_storage.dart';
import 'package:keepup/screens/home_screen.dart';
import '../models/run_stats.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();

  bool _loading = true;

  // Stats
  int _totalRuns = 0;
  int _totalTimeSec = 0;
  String _bestPaceFormatted = "--";

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // load profile username
    final profile = await RunStorage.getProfile();
    _usernameController.text = profile.username ?? '';

    // compute stats
    await _loadStats();

    setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    final runs = await RunStorage.getAllRuns();

    int totalTime = 0;
    double? fastest;

    for (final r in runs) {
      totalTime += r.durationSeconds ?? 0;

      if (r.bestPace != null) {
        if (fastest == null || r.bestPace! < fastest) {
          fastest = r.bestPace!;
        }
      }
    }

    setState(() {
      _totalRuns = runs.length;
      _totalTimeSec = totalTime;
      _bestPaceFormatted = fastest == null ? "--" : _formatPace(fastest);
    });
  }

  // Converts 5.25 pace to 5'15"
  String _formatPace(double pace) {
    int minutes = pace.floor();
    int seconds = ((pace - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}";
  }

  Future<void> _saveUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isNotEmpty) {
      await RunStorage.updateUsername(newName);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username updated!')));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(0.0, 0.5),
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(50, 50, 50, 0.7),
                Color.fromRGBO(50, 50, 50, 0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/20ffe1db632b3dbc3ddfae405183188e.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.7)),
          ),

          if (!_loading)
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: kToolbarHeight + MediaQuery.of(context).padding.top + 20,
                left: 30,
                right: 30,
                bottom: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 120,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 20),

                  // Username TextField
                  TextField(
                    controller: _usernameController,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: GoogleFonts.montserrat(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white12,
                      filled: true,
                    ),
                    onSubmitted: (_) => _saveUsername(),
                  ),

                  const SizedBox(height: 10),

                  // Save button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _saveUsername,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Stats card
                  _buildStatsCard(),
                  const SizedBox(height: 20),

                  // Recent Runs
                  Text(
                    "Recent Runs",
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Recent runs list
                  FutureBuilder<List<RunStats>>(
                    future: RunStorage.getAllRuns(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      final runs = snapshot.data!;
                      if (runs.isEmpty) {
                        return const Text(
                          "No runs recorded yet.",
                          style: TextStyle(color: Colors.white70),
                        );
                      }

                      return Column(
                        children: runs.reversed.take(5).map((run) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "-.- km",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${run.timestamp.month}/${run.timestamp.day}/${run.timestamp.year}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      run.bestPace == null
                                          ? "--"
                                          : _formatPace(run.bestPace!),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "${(run.durationSeconds / 60).floor()}m ${run.durationSeconds % 60}s",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

          // Close button
          Positioned(
            top: kToolbarHeight + 50,
            left: 25,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromRGBO(234, 53, 70, 100),
                ),
                padding: const EdgeInsets.all(7),
                child: const Icon(Icons.close, color: Colors.white, size: 35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UI for the stats card
  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
      child: Column(
        children: [
          Text(
            "Lifetime Stats",
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat("Runs", _totalRuns.toString()),
              _stat("Distance", "-.- km"),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat("Time", _formatTime(_totalTimeSec)),
              _stat("Best Pace", _bestPaceFormatted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;

    if (h > 0) {
      return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    } else {
      return "$m:${s.toString().padLeft(2, '0')}";
    }
  }
}
