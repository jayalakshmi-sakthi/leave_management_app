import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../main.dart'; // To get navigatorKey

// Conditional Import for Web Reload
import 'update_stub.dart' if (dart.library.html) 'update_web.dart' as reload_helper;

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  String? _currentBuildVersion;
  Timer? _pollingTimer;
  bool _isPromptShowing = false;

  /// Start the update checker
  void init() async {
    // Update checks are primarily intended for Web deployments
    if (!kIsWeb) return;

    // 1. Establish what version we are currently running
    _currentBuildVersion = await _fetchVersionFromServer();
    debugPrint("🚀 [UpdateService] Initialized. Current build: $_currentBuildVersion");

    // 2. Poll every 10 minutes for changes
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _checkForUpdate();
    });
    
    // Also check immediately once (in case a deploy happened just before the app loaded but cache served old code)
    // Actually init already fetched it.
  }

  Future<String?> _fetchVersionFromServer() async {
    try {
      // Use a timestamp to bypass browser cache
      final response = await http.get(
        Uri.parse('/version.json?t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['version']?.toString();
      }
    } catch (e) {
      debugPrint("⚠️ [UpdateService] Fetch failed: $e");
    }
    return null;
  }

  Future<void> _checkForUpdate() async {
    if (_isPromptShowing) return;

    final serverVersion = await _fetchVersionFromServer();
    
    if (serverVersion != null && _currentBuildVersion != null) {
      if (serverVersion != _currentBuildVersion) {
        debugPrint("✨ [UpdateService] Update detected! Local: $_currentBuildVersion, Server: $serverVersion");
        _showUpdateDialog();
      }
    }
  }

  void _showUpdateDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    _isPromptShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFF001C3D)),
              SizedBox(width: 12),
              Text("Update Available"),
            ],
          ),
          content: const Text(
            "A new version of LeaveX has been deployed with latest improvements. Please refresh the app to continue.",
            style: TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF001C3D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _isPromptShowing = false;
                reload_helper.reloadApp();
              },
              child: const Text("Refresh Now"),
            ),
          ],
        );
      },
    );
  }
}
