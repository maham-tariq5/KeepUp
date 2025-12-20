import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:keepup/services/location/geolocator_location_service.dart';
import 'run_screen.dart';
import 'home_screen.dart';

class SetupRunScreen extends StatefulWidget {
  const SetupRunScreen({super.key});

  @override
  State<SetupRunScreen> createState() => _SetupRunScreenState();
}

class _SetupRunScreenState extends State<SetupRunScreen> {
  double _paceGoal = 6.0; //default pace in minutes per km
  int _runDuration = 30; //default duration in minutes

  final List<int> _durationOptions = [2, 5, 10, 15, 20, 30, 45, 60];
  late FixedExtentScrollController _durationController;

  @override
  void initState() {
    super.initState();
    final initialIndex = _durationOptions
        .indexOf(_runDuration)
        .clamp(0, _durationOptions.length - 1);
    _durationController = FixedExtentScrollController(
      initialItem: initialIndex,
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final locationService = GeolocatorLocationService();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '',
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
          Positioned.fill(
            child: Image.asset(
              'assets/20ffe1db632b3dbc3ddfae405183188e.jpg',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(color: const Color.fromRGBO(0, 0, 0, 0.7)),
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setup Your Run',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Pace Goal Section
                        Text(
                          'Pace Goal (min/km)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _paceGoal,
                                min: 3.0,
                                max: 14.0,
                                divisions: 90,
                                onChanged: (value) {
                                  setState(() => _paceGoal = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _paceGoal.toStringAsFixed(1),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(color: Colors.white),
                                ),
                                Text(
                                  'min/km',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Run Duration (minutes)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Duration Picker
                        Container(
                          height: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: CupertinoPicker(
                                  scrollController: _durationController,
                                  itemExtent: 40,
                                  backgroundColor: Colors.transparent,
                                  onSelectedItemChanged: (i) {
                                    setState(
                                      () => _runDuration = _durationOptions[i],
                                    );
                                  },
                                  children: _durationOptions.map((d) {
                                    final selected = d == _runDuration;
                                    return Center(
                                      child: Text(
                                        d.toString(),
                                        style: selected
                                            ? theme.textTheme.headlineSmall
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                  )
                                            : theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: Colors.white38,
                                                  ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black54,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black54,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.white24,
                                            width: 0.5,
                                          ),
                                          bottom: BorderSide(
                                            color: Colors.white24,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Start Run Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RunScreen(
                                    locationService: locationService,
                                    runDuration: Duration(
                                      minutes: _runDuration,
                                    ),
                                    paceGoalMinPerKm:
                                        _paceGoal, //  pass goal pace into RunScreen
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                            child: const Text('Start Run'),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // close button
          Positioned(
            //top: kToolbarHeight + 50,
            bottom: 50,
            left: 25,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromRGBO(234, 53, 70, 100),
                ),
                padding: const EdgeInsets.all(7),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
