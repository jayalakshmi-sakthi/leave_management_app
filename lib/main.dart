import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'utils/theme_controller.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/apply_leave_screen.dart';
import 'screens/leave_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/leave_detail_screen.dart';
import 'screens/request_compoff_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/employee_detail_screen.dart';
import 'screens/admin_leave_requests_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/comp_off_detail_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/pending_approval_screen.dart';

/// Detect widget-test environment
const bool kIsTest = bool.fromEnvironment('FLUTTER_TEST');

// ---------------------------------------------------
// ROUTE CONSTANTS
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String apply = '/apply';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String admin = '/admin';
  static const String detail = '/detail';
  static const String requestCompOff = '/request-compoff';
  static const String employees = '/employees';
  static const String employeeDetail = '/employee-detail';
  static const String notifications = '/notifications';
  static const String calendar = '/calendar';
  static const String compOffDetail = '/compoff-detail';
}

// Leave detail argument wrapper
class LeaveDetailArguments {
  final String leaveId;
  const LeaveDetailArguments(this.leaveId);
}

// ---------------------------------------------------

// Global navigator key for redirection
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  print("🔥 [DART] Entry point reached");
  WidgetsFlutterBinding.ensureInitialized();
  print("🔥 [DART] Widgets Binding Initialized");

  // 🛡️ Bulletproof Splash Removal Fallback
  if (kIsWeb) {
    Timer(const Duration(seconds: 4), () {
      print("🛡️ [DART] Emergency Splash Removal Triggered (Stubbed for Web)");
      // Note: dart:html cannot be imported safely in a cross-platform app
      // without conditional imports. We use index.html CSS for splash removal usually.
    });
  }

  if (!kIsTest) {
    debugPrint("🚀 [DART] Starting Firebase Init...");
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        print("❌ [DART] Firebase Init Timed Out (10s)");
        throw TimeoutException("Firebase initialization timed out");
      });
      print("✅ [DART] Firebase Initialized");
      
      // ⚡ Enable Firestore offline cache safely (Persistence is default on some platforms)
      if (!kIsWeb) {
        try {
          print("🚀 [DART] Enabling Firestore Persistence...");
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
          debugPrint("✅ [DART] Firestore Persistence Enabled");
        } catch (e) {
          debugPrint("⚠️ [DART] Firestore Persistence Failed: $e");
        }
      } else {
        print("ℹ️ [DART] Firestore Web: Using default persistence (IndexedDB)");
      }
    } catch (e) {
      debugPrint("❌ [DART] Firebase Critical Failure: $e");
    }
    
    // Initialize notification service (Non-blocking)
    print("🚀 [DART] Starting Notification Service Init...");
    NotificationService().init()
      .then((_) => print("✅ [DART] Notification Service Ready"))
      .catchError((e) {
        print("⚠️ [DART] Notification Service Failed: $e");
        return null;
      });
  }

  print("🏃 [DART] Calling runApp()");
  runApp(const LeaveXApp());
}

// ---------------------------------------------------
// APP ROOT
class LeaveXApp extends StatelessWidget {
  const LeaveXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController(),
      builder: (context, mode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: "LeaveX",
          debugShowCheckedModeBanner: false,

          // -------------------------
          // THEME
          // -------------------------
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF001C3D),
              primary: const Color(0xFF001C3D),
              secondary: const Color(0xFF003366),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Color(0xFF001C3D),
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
            ),
            cardTheme: CardTheme(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              color: Colors.white,
            ),
            // 🅰️ Global Typography Polish
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0),
              displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              headlineMedium: TextStyle(fontWeight: FontWeight.w700),
              titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              bodyLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF7C3AED),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            cardColor: const Color(0xFF1E293B),
            canvasColor: const Color(0xFF0F172A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E293B),
              foregroundColor: Colors.white,
            ),
            // 🅰️ Global Typography Polish (Dark)
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Colors.white),
              displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
              headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
              bodyLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xFFE2E8F0)),
              bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14, color: Color(0xFFCBD5E1)),
              labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          themeMode: mode,

          // -------------------------
          // 🚀 CONSOLIDATED STARTUP GATE
          // -------------------------
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              // 1️⃣ Initial Auth Wait
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              final user = authSnapshot.data;

              // 2️⃣ Not Logged In -> Login
              if (user == null) {
                return const LoginScreen();
              }

              // 3️⃣ Logged In -> Single Combined Fetch (Data + Verification)
              return FutureBuilder<Map<String, dynamic>?>(
                future: _fetchStartupData(user),
                builder: (context, dataSnapshot) {
                  // While fetching, stay on the SAME SplashScreen
                  if (dataSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }

                  // Handle critical fetch errors (e.g. no internet)
                  if (dataSnapshot.hasError || dataSnapshot.data == null) {
                    return const LoginScreen(); // Fallback to login if data is missing
                  }

                  final data = dataSnapshot.data!;

                  // 🛡️ Guard 1: Email Verification
                  if (user.emailVerified == false) {
                     return const LoginScreen();
                  }

                  // 🛡️ Guard 2: Profile Completeness
                  final bool hasProfile = (data['designation'] != null && data['designation'].toString().isNotEmpty) &&
                                          (data['profilePicUrl'] != null && data['profilePicUrl'].toString().isNotEmpty);
                  
                  if (!hasProfile) {
                    return const ProfileSetupScreen();
                  }

                  // 🛡️ Guard 3: Approval Status
                  if (data['approved'] != true) {
                    return const PendingApprovalScreen();
                  }

                  // 🎉 All Clear -> Home
                  return const HomeScreen();
                },
              );
            },
          ),

          // -------------------------
          // ROUTES (DISABLED DURING TESTS)
          // -------------------------
          routes: kIsTest
              ? const {}
              : {
                  AppRoutes.login: (_) => const LoginScreen(),
                  AppRoutes.register: (_) => const RegisterScreen(),
                  AppRoutes.home: (_) => const HomeScreen(),
                  AppRoutes.apply: (_) => const ApplyLeaveScreen(),
                  AppRoutes.history: (_) => const LeaveHistoryScreen(),
                  AppRoutes.profile: (_) => const ProfileScreen(),
                  AppRoutes.admin: (_) => const AdminDashboard(),
                  AppRoutes.requestCompOff: (_) =>
                      const RequestCompOffScreen(),
                  AppRoutes.employees: (_) => const EmployeesScreen(),
                  AppRoutes.notifications: (_) => const NotificationsScreen(),
                  AppRoutes.calendar: (_) => const CalendarScreen(),
                  '/profile-setup': (_) => const ProfileSetupScreen(),
                  '/pending-approval': (_) => const PendingApprovalScreen(),
                },

          // -------------------------
          // DYNAMIC ROUTE
          // -------------------------
          onGenerateRoute: kIsTest
              ? null
              : (settings) {
                  if (settings.name == AppRoutes.detail) {
                    String? leaveId;
                    String? academicYear;

                    if (settings.arguments is LeaveDetailArguments) {
                      leaveId = (settings.arguments as LeaveDetailArguments).leaveId;
                    } else if (settings.arguments is Map) {
                      final map = settings.arguments as Map;
                      leaveId = map['leaveId'] as String?;
                      academicYear = map['academicYear'] as String?;
                    }

                    if (leaveId != null) {
                      return MaterialPageRoute(
                        builder: (_) => LeaveDetailScreen(
                          leaveId: leaveId!,
                          academicYearId: academicYear ?? '2024-2025',
                        ),
                      );
                    }
                  } else if (settings.name == AppRoutes.employeeDetail) {
                    final args = settings.arguments as Map<String, dynamic>;
                    return MaterialPageRoute(
                      builder: (_) => EmployeeDetailScreen(
                        userName: args['name'],
                        userId: args['uid'],
                      ),
                    );
                  } else if (settings.name == AppRoutes.compOffDetail) {
                    final docId = settings.arguments as String;
                    return MaterialPageRoute(
                      builder: (_) => CompOffDetailScreen(docId: docId),
                    );
                  }

                  return null;
                },
        );
      },
    );
  }
}

/// 🚀 Combined Startup Data Fetch
Future<Map<String, dynamic>?> _fetchStartupData(User user) async {
  try {
    // 1. Fetch user doc with timeout
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 8));

    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;

    // 2. Proactively reload user to get latest emailVerified status
    // (This helps if they just verified but haven't re-logged)
    await user.reload();
    
    return data;
  } catch (e) {
    debugPrint("❌ Startup Fetch Error: $e");
    return null;
  }
}
