import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:keepup/services/location/i_location_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart'; // scary audio
import 'package:flutter_svg/flutter_svg.dart';
import '../services/pace/pace_smoother.dart';
import 'package:hive/hive.dart';
import '../models/run_stats.dart'; // stats model for saving run data
import '../services/run_storage.dart'; // service to save run data

class RunScreen extends StatefulWidget {
  final ILocationService locationService;

  // Duration for the run (used by countdown)
  final Duration runDuration;

  // Target pace (min/km), e.g. 6.0 = 6:00 per km
  final double paceGoalMinPerKm;

  const RunScreen({
    super.key,
    required this.locationService,
    required this.runDuration,
    required this.paceGoalMinPerKm,
  });

  @override
  State<RunScreen> createState() => _RunScreenState();

  static LatLng? getCurrentPosition(BuildContext context) {
    final state = context.findAncestorStateOfType<State<RunScreen>>();
    // Access _current via dynamic since _RunScreenState is private
    return (state as dynamic)?._current as LatLng?;
  }
}

class _RunScreenState extends State<RunScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late StreamSubscription<LocationPosition> _posSub;
  LatLng? _current;
  LatLng? _prev;
  LatLng? _animatedMarkerPosition;
  bool _initialMapCentered = false;
  bool _followUser = true; // auto-center on user as they move

  // Animation for smooth map movement
  AnimationController? _mapAnimationController;
  Animation<double>? _mapLatAnimation;
  Animation<double>? _mapLngAnimation;

  // Animation for smooth marker movement
  AnimationController? _markerAnimationController;
  Animation<double>? _markerLatAnimation;
  Animation<double>? _markerLngAnimation;

  // ========== Countdown ==========
  // Counts DOWN from runDuration.inSeconds to 0.
  late int _remainingSeconds;
  Timer? _ticker;
  bool _isPaused = false;

  // ========== Pace tracking ==========
  late final PaceSmoother _paceSmoother;
  double _paceMinPerKm = 0.0; // current smoothed pace (min/km) for UI
  StreamSubscription? _paceSub;

  // Collect pace samples for avg/best stats at end.
  final List<double> _paceSamples = [];
  double? _avgPace;
  double? _bestPace;

  // ========== Scary music ==========
  late final AudioPlayer _audioPlayer;
  bool _isScaryPlaying = false;

  // ========== Scary hands death mechanic ==========
  AnimationController? _scaryHandsController;
  DateTime? _slowPaceStartTime;
  bool _isGameOver = false;
  static const Duration _deathGracePeriod = Duration(seconds: 10);

  // ========== Movement / pause detection ==========
  // We treat user as “moving” if speed > threshold, with a grace window
  // before we consider them paused/stopped.
  static const double _movementSpeedThreshold = 0.5; // m/s ~ slow walk
  static const Duration _movementPauseGrace = Duration(seconds: 10);

  DateTime? _lastMovementTime;
  bool _isMoving = false;
  bool _pausePromptShown = false;

  @override
  void initState() {
    super.initState();

    // Seed current position from last known fix (if available)
    final last = widget.locationService.lastPosition;
    if (last != null) {
      _current = LatLng(last.latitude, last.longitude);
    }

    debugPrint('locationService is ${widget.locationService}');
    debugPrint('positionStream is ${widget.locationService.positionStream}');

    widget.locationService.start();

    // Pace smoother for more stable pace values
    _paceSmoother = PaceSmoother(windowSize: 3);
    _paceSmoother.attach(widget.locationService.positionStream);

    // Init audio player
    _audioPlayer = AudioPlayer();

    // Init scary hands animation controller
    _scaryHandsController = AnimationController(
      vsync: this,
      duration: _deathGracePeriod,
    );

    _lastMovementTime = DateTime.now();

    try {
      // Listen for pace updates
      _paceSub = _paceSmoother.paceStream.listen((result) {
        if (!mounted) return;

        double pace = result.paceMinutesPerKm; // already min/km
        debugPrint('Received smoothed pace: $pace min/km');
        setState(() {
          _paceMinPerKm = result.paceMinutesPerKm;
        });

        if (pace.isFinite && pace > 0) {
          _paceSamples.add(pace);
          _updateScaryMusicForPace(pace); // trigger scary music logic
        }
      });

      // Listen for GPS position updates for map marker + movement detection
      _posSub = widget.locationService.positionStream.listen((pos) {
        final newLatLng = LatLng(pos.latitude, pos.longitude);
        debugPrint(
          'Received position: $newLatLng, speed: ${pos.speedMetersPerSecond} m/s',
        );

        setState(() {
          _prev = _current;
          _current = newLatLng;
        });

        // Animate marker if we have a previous position
        if (_prev != null && _current != null) {
          _animateMarkerToPosition(_prev!, _current!);
        }

        // --- Movement / no-movement detection ---
        final now = DateTime.now();
        final currentSpeed = pos.speedMetersPerSecond ?? 0.0;
        final isMovingNow = currentSpeed > _movementSpeedThreshold;

        if (isMovingNow) {
          _lastMovementTime = now;
          if (!_isMoving) {
            setState(() {
              _isMoving = true;
            });
          }
        } else {
          final lastMove = _lastMovementTime;
          if (lastMove == null) {
            _lastMovementTime = now;
          } else if (now.difference(lastMove) >= _movementPauseGrace) {
            if (_isMoving) {
              setState(() {
                _isMoving = false;
              });
            }
            _onPossiblePauseDetected(); //  instead of “death”, offer pause
          }
        }

        // Map following logic
        if (!_initialMapCentered && _current != null) {
          _mapController.move(_current!, 18);
          _initialMapCentered = true;
        }

        if (_followUser && _initialMapCentered && _current != null) {
          _animateMapToPosition(_current!);
        }
      });
    } catch (e, st) {
      developer.log(
        'Failed to listen to positionStream: $e',
        name: 'RunScreen',
        error: e,
        stackTrace: st,
      );
    }

    // Countdown from runDuration to 0
    _remainingSeconds = widget.runDuration.inSeconds;
    _startCountdown();

    // Center map after first frame if we already know a location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current != null && !_initialMapCentered) {
        _mapController.move(_current!, 18);
        _initialMapCentered = true;
      }
    });
  }

  @override
  void dispose() {
    try {
      _posSub.cancel();
    } catch (_) {}
    _paceSub?.cancel();
    try {
      _paceSmoother.dispose();
    } catch (_) {}

    _ticker?.cancel();
    _mapAnimationController?.dispose();
    _markerAnimationController?.dispose();
    _scaryHandsController?.dispose();

    _stopScaryMusicNow();
    _audioPlayer.dispose();

    super.dispose();
  }

  void _animateMarkerToPosition(LatLng prev, LatLng current) {
    // Cancel any ongoing animation
    _markerAnimationController?.stop();
    _markerAnimationController?.dispose();

    // Create new animation controller
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create animations for latitude and longitude
    _markerLatAnimation =
        Tween<double>(begin: prev.latitude, end: current.latitude).animate(
          CurvedAnimation(
            parent: _markerAnimationController!,
            curve: Curves.easeInOut,
          ),
        );

    _markerLngAnimation =
        Tween<double>(begin: prev.longitude, end: current.longitude).animate(
          CurvedAnimation(
            parent: _markerAnimationController!,
            curve: Curves.easeInOut,
          ),
        );

    // Listen to animation updates
    _markerAnimationController!.addListener(() {
      if (_markerLatAnimation != null &&
          _markerLngAnimation != null &&
          mounted) {
        setState(() {
          _animatedMarkerPosition = LatLng(
            _markerLatAnimation!.value,
            _markerLngAnimation!.value,
          );
        });
      }
    });

    _markerAnimationController!.forward();
  }

  // ========== Map animation helper ==========

  void _animateMapToPosition(LatLng target) {
    final currentCenter = _mapController.camera.center;

    // Cancel any ongoing animation
    _mapAnimationController?.stop();
    _mapAnimationController?.dispose();

    // Create new animation controller
    _mapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Create animations for latitude and longitude
    _mapLatAnimation =
        Tween<double>(
          begin: currentCenter.latitude,
          end: target.latitude,
        ).animate(
          CurvedAnimation(
            parent: _mapAnimationController!,
            curve: Curves.easeInOut,
          ),
        );

    _mapLngAnimation =
        Tween<double>(
          begin: currentCenter.longitude,
          end: target.longitude,
        ).animate(
          CurvedAnimation(
            parent: _mapAnimationController!,
            curve: Curves.easeInOut,
          ),
        );

    // Listen to animation updates
    _mapAnimationController!.addListener(() {
      if (_mapLatAnimation != null && _mapLngAnimation != null && mounted) {
        _mapController.move(
          LatLng(_mapLatAnimation!.value, _mapLngAnimation!.value),
          18,
        );
      }
    });

    // Start the animation
    _mapAnimationController!.forward();
  }

  // ========== Countdown helpers ==========

  void _startCountdown() {
    if (_remainingSeconds <= 0) return;
    // avoid multiple timers
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _ticker = null;
        return;
      }

      if (_isPaused) {
        // If paused, just stop ticking; we'll restart on resume.
        timer.cancel();
        _ticker = null;
        return;
      }

      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds == 0) {
          timer.cancel();
          _ticker = null;
          _onRunDurationFinished();
        }
      } else {
        timer.cancel();
        _ticker = null;
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _ticker?.cancel();
      _ticker = null;
      _stopScaryMusicNow();
    } else {
      _startCountdown();
    }
  }

  // ========== Helpers ==========

  // Format remaining countdown seconds as mm:ss or hh:mm:ss
  String _formatRemaining(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  // Format a pace value (min/km) as mm:ss
  String _formatPace(double? pace) {
    if (pace == null || !pace.isFinite || pace <= 0) return "--:--";
    final mins = pace.floor();
    final secs = ((pace - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // Compute avg & best pace from collected samples
  void _computePaceStats() {
    if (_paceSamples.isEmpty) {
      _avgPace = null;
      _bestPace = null;
      return;
    }

    double sum = 0;
    double best = _paceSamples.first;
    for (final p in _paceSamples) {
      sum += p;
      if (p < best) best = p; // smaller = faster
    }
    _avgPace = sum / _paceSamples.length;
    _bestPace = best;
  }

  // ========== Scary music & hands logic ==========

  // If current pace is SLOWER than goal (bigger min/km), play scary music and start hands rising.
  // If back on/under goal, or paused, stop it.
  Future<void> _updateScaryMusicForPace(double pace) async {
    // Don’t play scary music while paused or after run finished
    if (_isGameOver || _isPaused || _remainingSeconds <= 0) {
      if (_isScaryPlaying) await _stopScaryMusicNow();
      _slowPaceStartTime = null;
      _scaryHandsController?.stop();
      _scaryHandsController?.reset();
      return;
    }

    if (pace > widget.paceGoalMinPerKm) {
      if (!_isScaryPlaying) {
        _isScaryPlaying = true;
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('audio/ScaryMusic.mp3'));
      }

      // Start countdown and hands animation
      if (_slowPaceStartTime == null) {
        _slowPaceStartTime = DateTime.now();
        _scaryHandsController?.forward();
        
        // Check if 10 seconds elapsed for game over
        Future.delayed(_deathGracePeriod, () {
          if (_slowPaceStartTime != null && !_isGameOver && mounted) {
            final elapsed = DateTime.now().difference(_slowPaceStartTime!);
            if (elapsed >= _deathGracePeriod) {
              _triggerGameOver();
            }
          }
        });
      }
    } else {
      // Pace is good - reset everything
      if (_isScaryPlaying) {
        await _stopScaryMusicNow();
      }
      _slowPaceStartTime = null;
      _scaryHandsController?.stop();
      _scaryHandsController?.reset();
    }
  }

  Future<void> _stopScaryMusicNow() async {
    if (_isScaryPlaying) {
      _isScaryPlaying = false;
      try {
        await _audioPlayer.stop();
      } catch (_) {}
    }
  }

  void _triggerGameOver() {
    if (_isGameOver) return;
    setState(() {
      _isGameOver = true;
    });
    _ticker?.cancel();
    _stopScaryMusicNow();
    Future.microtask(_showGameOverScreen);
  }

  Future<void> _showGameOverScreen() async {
    if (!mounted) return;

    // calculate final pace stats for display
    // count this as a run as well
    _computePaceStats();
    // getting the username from the profile stored in Hive
    final _username = Hive.box<RunStats>('stats').get('profile')?.username ?? "Runner";
    final stats = RunStats(
      username: _username,
      avgPace: _avgPace,
      bestPace: _bestPace,
      paceSamples: List<double>.from(_paceSamples),
      durationSeconds: widget.runDuration.inSeconds - _remainingSeconds,
      paceGoalMinPerKm: widget.paceGoalMinPerKm,
      timestamp: DateTime.now(),
    ); 

    // Save to Hive
    try {
      await RunStorage.saveRun(stats);
      debugPrint('Saved RunStats to Hive box "runsBox".');
    } catch (e) {
      // Log and continue — don't block UI
      debugPrint('Error saving run: $e');
    }

    debugPrint('Saved RunStats to Hive box "runsBox".');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'GAME OVER',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            color: Colors.redAccent,
            fontSize: 32,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You couldn\'t keep up the pace!',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Goal: ${_formatPace(widget.paceGoalMinPerKm)} min/km',
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            Text(
              'Your pace: ${_formatPace(_paceMinPerKm)} min/km',
              style: GoogleFonts.montserrat(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Exit Run'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ========== Movement-based pause suggestion ==========

  Future<void> _onPossiblePauseDetected() async {
    if (!mounted || _isPaused || _pausePromptShown || _remainingSeconds <= 0)
      return;

    _pausePromptShown = true;
    final cs = Theme.of(context).colorScheme;

    final bool? pause = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(
          'Pause run?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'We noticed you haven\'t been moving for a bit.\nDo you want to pause your run?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pause'),
          ),
        ],
      ),
    );

    _pausePromptShown = false;

    if (pause == true && !_isPaused && mounted) {
      _togglePause();
    }
  }

  // ========== Run end flows ==========

  // When countdown naturally reaches 0
  void _onRunDurationFinished() {
    _stopScaryMusicNow();
    _computePaceStats();
    Future.microtask(_showRunSummaryAndExit);
  }

  Future<void> _showRunSummaryAndExit() async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    debugPrint(
      'Run complete! Avg pace: $_avgPace min/km, Best pace: $_bestPace min/km',
    );

    // getting the username from the profile stored in Hive
    final _username = Hive.box<RunStats>('stats').get('profile')?.username ?? "Runner";
    final stats = RunStats(
      username: _username,
      avgPace: _avgPace,
      bestPace: _bestPace,
      paceSamples: List<double>.from(_paceSamples),
      durationSeconds: widget.runDuration.inSeconds,
      paceGoalMinPerKm: widget.paceGoalMinPerKm,
      timestamp: DateTime.now(),
    ); 

    // Save to Hive
    try {
      await RunStorage.saveRun(stats);
      debugPrint('Saved RunStats to Hive box "runsBox".');
    } catch (e) {
      // Log and continue — don't block UI
      debugPrint('Error saving run: $e');
    }

    debugPrint('Saved RunStats to Hive box "runsBox".');

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(
          'Run complete!',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nice work! Here are your stats:',
              style: GoogleFonts.montserrat(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Avg pace',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_formatPace(_avgPace)} min/km',
                  style: GoogleFonts.montserrat(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Best pace',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_formatPace(_bestPace)} min/km',
                  style: GoogleFonts.montserrat(),
                ),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.of(context).pop(); // back to previous screen
    }
  }

  Future<void> _confirmEndRun() async {
    final cs = Theme.of(context).colorScheme;
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(
          'End run?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to quit this run?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Run'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _ticker?.cancel();
      await _stopScaryMusicNow();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _current ?? const LatLng(50, 5),
                initialZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.keepup',
                ),
                MarkerLayer(
                  markers: _current == null
                      ? const []
                      : [
                          Marker(
                            point: _animatedMarkerPosition ?? _current!,
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Container(
                              key: const Key('user_marker_wrap'),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    key: const Key('user_marker_ring'),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const ui.Color.fromARGB(
                                        255,
                                        255,
                                        68,
                                        68,
                                      ).withOpacity(0.25),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  //replaced the user dot marker with an animated sprite icon!
                                  AnimatedSprite(
                                    assetPath: 'assets/player_walk_strip6.png',
                                    frameCount: 6,
                                    frameDuration: const Duration(
                                      milliseconds: 100,
                                    ),
                                    scale: 0.6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                ),
              ],
            ),

            // Top overlay arc
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(120),
                  ),
                ),
              ),
            ),

            // Pace bubble
            Positioned(
              top: 18,
              left: 18,
              child: _PaceBubble(
                label: 'Pace',
                value: _paceMinPerKm.isInfinite || _paceMinPerKm <= 0
                    ? "--:--"
                    : "${_paceMinPerKm.floor()}:${((_paceMinPerKm - _paceMinPerKm.floor()) * 60).round().toString().padLeft(2, '0')}",
                sub: "min / km",
              ),
            ),

            // Time panel with pause/resume + end buttons
            Align(
              alignment: Alignment.bottomCenter,
              child: _TimePanel(
                title: 'Time left:',
                timeText: _formatRemaining(_remainingSeconds),
                onEndRun: _confirmEndRun,
                isPaused: _isPaused,
                onTogglePause: _togglePause,
              ),
            ),

            // Scary hands rising from bottom
            if (_scaryHandsController != null && _slowPaceStartTime != null)
              AnimatedBuilder(
                animation: _scaryHandsController!,
                builder: (context, child) {
                  final progress = _scaryHandsController!.value;
                  final screenHeight = MediaQuery.of(context).size.height;
                  final handHeight = screenHeight * 0.6;
                  final bottomOffset = -handHeight + (handHeight * progress);

                  return Positioned(
                    bottom: bottomOffset,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 0.9,
                      child: SvgPicture.asset(
                        'assets/scaryhands.svg',
                        height: handHeight,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () {
          // Simulated movement for testing
          final testPos = LatLng(
            (_current?.latitude ?? 40.7128) + 0.0002,
            (_current?.longitude ?? -74.0060) - 0.0001,
          );

          final speed = 2.5 + (DateTime.now().millisecond % 10) / 10.0;
          final accuracy = 8.0 + (DateTime.now().millisecond % 100) / 10.0;

          final testPosition = LocationPosition(
            latitude: testPos.latitude,
            longitude: testPos.longitude,
            speedMetersPerSecond: speed,
            accuracyMeters: accuracy,
            timestamp: DateTime.now(),
          );
          widget.locationService.injectTestPosition(testPosition);
          debugPrint(
            'Test GPS: $testPos, speed: ${speed.toStringAsFixed(2)} m/s, acc: ${accuracy.toStringAsFixed(1)}m',
          );
        },
        child: const Icon(Icons.add_location),
      ),
    );
  }
}

// ========== Widgets ==========

class _PaceBubble extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _PaceBubble({
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 34,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: cs.onPrimary,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -6,
          top: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$label:',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimePanel extends StatelessWidget {
  final String title;
  final String timeText;
  final VoidCallback onEndRun;

  final bool isPaused;
  final VoidCallback onTogglePause;

  const _TimePanel({
    required this.title,
    required this.timeText,
    required this.onEndRun,
    required this.isPaused,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final display = Theme.of(context).textTheme.displayLarge!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(120)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 15),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),

              // Pause / Resume button
              Tooltip(
                message: isPaused ? 'Resume' : 'Pause',
                child: InkResponse(
                  onTap: onTogglePause,
                  radius: 24,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // End run button
              Tooltip(
                message: 'End Run',
                child: InkResponse(
                  onTap: onEndRun,
                  radius: 24,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            timeText.length == 5
                ? '00 : $timeText'
                : timeText.replaceAll(':', ' : '),
            style: display.copyWith(color: Colors.redAccent, letterSpacing: 3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ========== Animated Sprite Widget ==========
//The animation component!
class AnimatedSprite extends StatefulWidget {
  final String assetPath;
  final int frameCount;
  final Duration frameDuration;
  final double
  scale; //this value can be changed to make the avatar bigger or smaller

  const AnimatedSprite({
    super.key,
    required this.assetPath,
    this.frameCount = 6,
    this.frameDuration = const Duration(milliseconds: 100),
    this.scale = 1.0,
  });

  @override
  State<AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<AnimatedSprite>
    with SingleTickerProviderStateMixin {
  ui.Image?
  _image; //this is so it caches and doesn't have empty frames in between rendering
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
    //loops the entire spprite strip sheet
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.frameDuration * widget.frameCount,
    )..repeat();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final fi = await codec.getNextFrame();
    setState(() => _image = fi.image);
    debugPrint(
      'AnimatedSprite loaded: ${fi.image.width}x${fi.image.height}, frameCount=${widget.frameCount}',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return SizedBox(width: 40 * widget.scale, height: 40 * widget.scale);
    }

    final img = _image!;
    final frameWidth = img.width / widget.frameCount;
    final frameHeight = img.height.toDouble();
    final displayW = frameWidth * widget.scale;
    final displayH = frameHeight * widget.scale;

    debugPrint(
      'AnimatedSprite: frameWidth=$frameWidth, frameHeight=$frameHeight, displayW=$displayW, displayH=$displayH',
    );

    return SizedBox(
      width: displayW,
      height: displayH,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final frame =
              (_ctrl.value * widget.frameCount).floor() % widget.frameCount;
          return CustomPaint(
            painter: _SpriteFramePainter(
              image: img,
              frameIndex: frame,
              frameCount: widget.frameCount,
              scale: widget.scale,
            ),
            size: Size(displayW, displayH),
          );
        },
      ),
    );
  }
}

// ========== CustomPainter for drawing sprite frames ==========
//this is where it handles the actual drawing of a single frame from the sprite strip
class _SpriteFramePainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;
  final int frameCount;
  final double scale;

  _SpriteFramePainter({
    required this.image,
    required this.frameIndex,
    required this.frameCount,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = image.width / frameCount;
    final frameHeight = image.height.toDouble();

    // Source rect: the portion of the sprite to draw
    final src = Rect.fromLTWH(
      frameIndex * frameWidth,
      0,
      frameWidth,
      frameHeight,
    );

    // Destination rect: where to draw it on the canvas
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_SpriteFramePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex;
  }
}
