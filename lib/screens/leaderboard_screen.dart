import 'package:flutter/material.dart';
import 'package:keepup/screens/home_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Leaderboard',
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

      // background with image and overlay
      body: Stack(
        children: [
          // background image
          Positioned.fill(
            child: Image.asset(
              'assets/20ffe1db632b3dbc3ddfae405183188e.jpg', // your image path
              fit: BoxFit.cover,
            ),
          ),

          // black overlay with adjustable opacity
          Positioned.fill(
            child: Container(
              color: Color.fromRGBO(0, 0, 0, 0.7), // change opacity here (0–1)
            ),
          ),

          // close button top-right
          Positioned(
            top: kToolbarHeight + 50,
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
                child: const Icon(Icons.close, color: Colors.white, size: 35),
              ),
            ),
          ),

          // screen content
          // Positioned content including "Sort by" dropdown
          Positioned(
            top: kToolbarHeight + 130, // below cross button
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sort by row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(
                        'Sort by:',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Color.fromRGBO(255, 253, 237, 0.68),
                          fontWeight: FontWeight.bold,
                          fontSize: 23
                        ),
                      ),
                      const SizedBox(width: 35),
                      // Dropdown (hardcoded options)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(255, 253, 237, 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: 'Rank', // default value
                          dropdownColor: Color.fromRGBO(255, 253, 237, 1),
                          iconEnabledColor: Color.fromARGB(255, 0, 0, 0),
                          style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                          underline:
                              const SizedBox(), // remove default underline
                          items: <String>['Rank', 'Points'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            // no action yet, UI only
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20), // spacing before player list
                  // Player list (scrollable)
                  Expanded(
                    child: ListView.builder(
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(234, 53, 70, 100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              // player PFP
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(23, 18, 25, 0.57),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    'assets/avatar.png',
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // player name
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(23, 18, 25, 0.57),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Player ${index + 1}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              const Spacer(),

                              // player score
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(23, 18, 25, 0.57),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${(index + 1) * 100} pts',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
