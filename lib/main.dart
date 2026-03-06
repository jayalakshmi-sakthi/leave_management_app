import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ Added specific import
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added specific import
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
  print("🔥 DART ENTRY POINT REACHED");
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsTest) {
    debugPrint("🚀 Starting App Initialization...");
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // ⚡ Enable Firestore offline cache (10 MB is default, unlimited prevents reloading old data)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      debugPrint("✅ Firebase Initialized");
    } catch (e) {
      debugPrint("❌ Firebase Init Failed: $e");
    }
    
    // Initialize notification service (Non-blocking)
    Future.microtask(() => NotificationService().init().catchError((e) => debugPrint("Notification Service Init Failed: $e")));
  }

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
            colorSchemeSeed: const Color(0xFF7C3AED),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            // 🅰️ Global Typography Polish
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0),
              displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              headlineMedium: TextStyle(fontWeight: FontWeight.w700),
              titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              bodyLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14), // Readable base
              labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14), // Button text
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
          // AUTH GUARD (HANDLE STARTUP REDIRECTION)
          // -------------------------
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              
              final user = snapshot.data;
              if (user == null) {
                return const LoginScreen();
              }

              // 🔄 RELOAD USER TO GET FRESH EMAIL VERIFICATION STATUS
              return FutureBuilder(
                future: user.reload().onError((_, __) {}), // Ignore errors
                builder: (context, reloadSnapshot) {
                  if (reloadSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }
                  
                  final refreshedUser = FirebaseAuth.instance.currentUser;
                  // If reload failed or user somehow null, fallback
                  if (refreshedUser == null) return const LoginScreen();

                  // 🚫 MANDATORY CHECK 1: EMAIL VERIFICATION
                  if (!refreshedUser.emailVerified) {
                     return const LoginScreen(); 
                  }

                  // 🔍 CHECK PROFILE & APPROVAL STATUS
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(refreshedUser.uid).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const SplashScreen();
                      }

                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final data = userSnapshot.data!.data() as Map<String, dynamic>;
                        
                        // 1️⃣ CHECK PROFILE COMPLETENESS
                        final bool hasProfile = (data['designation'] != null && data['designation'].toString().isNotEmpty) &&
                                                (data['profilePicUrl'] != null && data['profilePicUrl'].toString().isNotEmpty);
                        
                        if (!hasProfile) {
                           return const ProfileSetupScreen();
                        }

                        // 2️⃣ CHECK APPROVAL
                        final bool isApproved = data['approved'] == true;

                        if (!isApproved) {
                          return const PendingApprovalScreen();
                        }
                        
                        return const HomeScreen();
                      }
                      
                      // Fallback: If doc missing, maybe fresh Google login? Go to Setup.
                      return const ProfileSetupScreen(); 
                    },
                  );
                }
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
