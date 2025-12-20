import 'package:flutter/material.dart';
import 'package:keepup/screens/home_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/run_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _unit = 'km';
  String _theme = 'System';
  bool _notifications = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }

  void _confirmAndReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Reset"),
        content: const Text(
          "Are you sure you want to clear all your runs and profile? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await RunStorage.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("All data cleared!")),
              );
            },
            child: const Text("Reset", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _sendFeedback() async {
    final Uri emailUri = Uri.parse(
      'mailto:maleyhaf@gmail.com?subject=App Feedback',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
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
      body: Container(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                'assets/20ffe1db632b3dbc3ddfae405183188e.jpg',
                fit: BoxFit.cover,
              ),
            ),
            // Black overlay
            Positioned.fill(
              child: Container(color: const Color.fromRGBO(0, 0, 0, 0.7)),
            ),

            // Scrollable content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 70),
                    // THEME
                    ListTile(
                      leading: const Icon(
                        Icons.brightness_6,
                        color: Colors.white,
                      ),
                      title: const Text(
                        "Theme",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: DropdownButton<String>(
                        value: _theme,
                        items: const [
                          DropdownMenuItem(
                            value: "Light",
                            child: Text("Light"),
                          ),
                          DropdownMenuItem(value: "Dark", child: Text("Dark")),
                          DropdownMenuItem(
                            value: "System",
                            child: Text("System"),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _theme = val!);
                        },
                      ),
                    ),
                    // NOTIFICATIONS
                    SwitchListTile(
                      title: const Text(
                        "Reminders",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        "Receive daily run reminders",
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: _notifications,
                      onChanged: (val) {
                        setState(() => _notifications = val);
                      },
                      secondary: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // CLEAR DATA / RESET
                    ElevatedButton.icon(
                      onPressed: _confirmAndReset,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Clear Data / Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(color: Colors.white24, height: 40),
                    // APP PERFORMANCE & FEEDBACK
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                      title: const Text(
                        "App Version",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        _appVersion,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.feedback, color: Colors.white),
                      title: const Text(
                        "Send Feedback",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: _sendFeedback,
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip,
                        color: Colors.white,
                      ),
                      title: const Text(
                        "Privacy Policy",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        // open privacy link
                      },
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
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
      ),
    );
  }
}
