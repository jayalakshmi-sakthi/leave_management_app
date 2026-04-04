import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart'; // Added Shimmer
import '../widgets/responsive_wrapper.dart'; // ✅ Added
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/helpers.dart';
import '../widgets/responsive_wrapper.dart';
import '../utils/theme_controller.dart'; // ✅ Added
import '../models/user_model.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  String _uid = "";
  String _name = "";
  String _employeeId = "";
  String _role = "";
  String _userDept = "General"; // ✅ Added

  // --- Dynamic Data ---
  Map<String, dynamic> _leaveBalances = {}; 
  double _compGranted = 0.0;
  double _compUsed = 0.0;

  String academicYear = ""; 

  bool _loadingCounts = true;
  
  // Dynamic Style Cache (name -> {color, icon})
  Map<String, Map<String, dynamic>> _styleCache = {};

  // --- Soulful Palette ---
  static const Color primaryNavy = Color(0xFF001C3D); // KEC Navy
  static const Color accentNavy = Color(0xFF003366);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color cardSurface = Colors.white;
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      // Lower threshold to ensure visibility on mobile
      final collapsed = _scrollController.offset > 120;
      if (collapsed != _isCollapsed) {
        setState(() => _isCollapsed = collapsed);
      }
    });
    // Initial basic state
    final user = _auth.currentUser;
    if (user != null) {
      _uid = user.uid;
      
      // Initialize Local Notifications & Listen
      final notifService = NotificationService();
      notifService.init();
      notifService.setUserId(_uid); // ✅ ADDED
      notifService.listenForNewNotifications(_uid);

      // 🛡️ Handle "Terminated State" clicks (clicked while app was closed)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
         final pending = notifService.pendingNavigation;
         if (pending != null) {
            debugPrint("🚀 [Management] Processing Terminated-State Click: $pending");
            // Small delay to ensure the screen is ready
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              _handleNotificationClick(pending);
              notifService.clearPendingNavigation();
            }
         }
      });

      // 🧭 Listen for real-time and background clicks
      notifService.navigationStream.listen((data) {
        if (!mounted) return;
        debugPrint("🧭 Notification Navigation Triggered: $data");
        _handleNotificationClick(data);
      });

      _loadAll(); 
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint("🧭 Redirecting: $data");
    final type = data['type'];
    final relatedId = data['relatedId'];
    final academicYearId = data['academicYearId'];
    final String? lType = data['leaveType']?.toString().toUpperCase();

    if ((type == 'status_change' || type == 'comp_off_request' || type == 'comp_off') && relatedId != null) {
      // 🏰 Navigation Rule:
      // - Comp-Off EARN/CREDIT (activityType: comp_off) -> CompOffDetailScreen
      // - Comp-Off LEAVE/USAGE (leaveType: COMP) -> LeaveDetailScreen
      
      if (lType == 'COMP-OFF EARN' || lType == 'COMP-OFF CREDIT' || type == 'comp_off_request' || type == 'comp_off') {
        Navigator.pushNamed(
          context,
          AppRoutes.compOffDetail,
          arguments: {
            'docId': relatedId,
            'department': data['targetDepartment'] ?? _userDept,
          },
        );
      } else {
        Navigator.pushNamed(
          context,
          AppRoutes.detail,
          arguments: {
            'leaveId': relatedId,
            'academicYearId': academicYearId ?? '2024-2025',
            'department': data['targetDepartment'] ?? _userDept,
          },
        );
      }
    } else if (type == 'announcement' || type == 'info') {
      Navigator.pushNamed(context, AppRoutes.notifications);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loadingCounts = true);
    try {
      // 1. Fetch User Info FIRST (Need department for settings)
      await _loadUserInfo();

      // Get user's department from Firestore (needed for scoped settings)
      final userSnap = await _fire.collection('users').doc(_uid).get();
      final userDept = userSnap.data()?['department'] ?? 'General';

      // 2. Fetch Admin Config (Academic Year & Leave Types - Scoped to Department)
      final fs = FirestoreService(); 
      final acSettings = await fs.getAcademicYearSettings(department: userDept);
      final typesList = await fs.getLeaveTypes(department: userDept);

      // Ensure we use the label from settings, OR fallback to local algo if null
      academicYear = acSettings['label'] ?? fs.getCurrentAcademicYearString();
      
      // 3. Fetch User Activity (Leaves & Comps)
      final leaveQuery = await _fire
          .collection("leaveRequests")
          .doc(userDept)
          .collection('records')
          .where('userId', isEqualTo: _uid)
          .where('academicYearId', isEqualTo: academicYear)
          // .where('status', isEqualTo: 'Approved') // Removed to include Pending
          .get();

      Map<String, double> usedMap = {};
      for (var doc in leaveQuery.docs) {
        final d = doc.data();
        if (d['status'] != 'Approved') continue; // Only deduct Approved leaves

        final type = d['leaveType'] as String? ?? 'Other';
        final days = (d['numberOfDays'] ?? 0).toDouble();
        usedMap[type] = (usedMap[type] ?? 0) + days;
      }
      
      // Separate COMP logic
      _compUsed = usedMap['COMP'] ?? 0.0;
      
      // 4. Build Balance Map
      Map<String, dynamic> balances = {};
      
      final colors = [const Color(0xFF4F46E5), const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFF003366), const Color(0xFF0EA5E9)];
      int cIdx = 0;

      for (var type in typesList) {
        final name = type['name'] as String;
        if (name == 'COMP') continue; 

        // Cache Style
        final colorVal = type['color'];
        final iconVal = type['icon'];
        _styleCache[name] = {
          'color': colorVal != null ? Color(colorVal) : Helpers.getLeaveColor(name),
          'icon': iconVal != null ? Helpers.getIconFromCodePoint(iconVal) : Helpers.getLeaveIcon(name),
        };

        final limit = (type['days'] as num).toDouble();
        final used = usedMap[name] ?? 0.0;
        final balance = (limit - used).clamp(0.0, 999.0);
        
        balances[name] = {
          'limit': limit,
          'used': used,
          'balance': balance,
          'color': _styleCache[name]!['color'] 
        };
      }
      
      // 5. Comp Off Grants
      await _loadCompOffGrants();

      if (mounted) {
        setState(() {
          _leaveBalances = balances;
        });
      }

    } catch (e) {
      debugPrint("Error loading dashboard: $e");
    } finally {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }



  Future<void> _loadUserInfo() async {
    final snap = await _fire.collection('users').doc(_uid).get();
    if (snap.exists && mounted) {
      String empId = snap.data()?['employeeId'] ?? "";
      
      // 2. CHECK IF ID IS MISSING -> REDIRECT TO PROFILE SETUP
      if (empId.isEmpty || empId == "EMP-TEMP" || empId == "0000") {
         // Stop loading and Redirect
         if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/profile-setup', (_) => false);
         }
         return; // Stop further loading
      }

      String manualId = snap.data()?['manualEmployeeId'] ?? "";
      
      setState(() {
        _name = snap.data()?['name'] ?? 'Employee';
        _employeeId = manualId.isNotEmpty ? manualId : empId;
        _role = snap.data()?['role'] ?? 'staff';
        _userDept = snap.data()?['department'] ?? 'General'; // ✅ Added
      });
    }
  }

  Future<void> _loadCompOffGrants() async {
    try {
      // 1. Fetch from Subcollection (New Standard)
      final qSub = await _fire
          .collection('users')
          .doc(_uid)
          .collection('compOffGrants')
          .get();

      // 2. Fetch from Root Collection (Legacy / Fallback)
      final qRoot = await _fire
          .collection('compOffGrants')
          .where('userId', isEqualTo: _uid)
          .where('academicYearId', isEqualTo: academicYear)
          .get();

      double totalGranted = 0.0;
      
      // Sum both sources
      // Helper for safe parsing
      double safeParse(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }

      for (var d in qSub.docs) totalGranted += safeParse(d.data()['days']);
      for (var d in qRoot.docs) totalGranted += safeParse(d.data()['days']);

      // 3. Fetch Usage (Spent Comp-Offs) — use department-scoped path
      final userSnapForComp = await _fire.collection('users').doc(_uid).get();
      final userDeptForComp = userSnapForComp.data()?['department'] ?? 'General';
      final qUsage = await _fire
          .collection('leaveRequests')
          .doc(userDeptForComp)
          .collection('records')
          .where('userId', isEqualTo: _uid)
          .where('academicYearId', isEqualTo: academicYear)
          .get();

      double totalUsed = 0.0;
      for (var d in qUsage.docs) {
        final data = d.data();
        final type = data['leaveType'] as String?;
        final status = data['status'] as String?;
        
        if (type == 'COMP' && status == 'Approved') {
           totalUsed += safeParse(data['numberOfDays']);
        }
      }
      
      final balance = (totalGranted - totalUsed).clamp(0.0, 999.0);

      if (mounted) setState(() => _compGranted = balance);
      debugPrint("DEBUG: Granted: $totalGranted, Used: $totalUsed, Balance: $balance");
    } catch (e) {
      debugPrint("Error loading Comp-Off Grants: $e");
      if (mounted) {
        // Show visible error if permission denied, so user knows 'Part 1' of instructions is needed.
        if (e.toString().contains('permission-denied')) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Error: Database Permission Denied. Please update Firestore Rules."), backgroundColor: Colors.red),
           );
        }
      }
    }
  }

  // --- Real-Time Logout Experience ---
  void _showLogoutConfirmation() {
    HapticFeedback.mediumImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            
            // Icon Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            
            // Text
            Text(
              "Sign Out",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Are you sure you want to end your session?",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 40),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: theme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _auth.signOut();
                      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Logout",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ResponsiveWrapper(
        maxWidth: 800, // Increased for a better look on wider screens, still looks great on mobile
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: CustomScrollView(
          controller: _scrollController, // ✅ Added
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            const SliverToBoxAdapter(child: SizedBox(height: 6)), // ✅ Added small gap
            _buildProfileSection(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     _buildHeaderRow("Leave Balance", "Overview"),
                    const SizedBox(height: 16),
                    
                    // DYNAMIC STAT CARDS
                    // DYNAMIC STAT CARDS (SKELETON ENABLED)
                    _buildBalancesGrid(),
                    
                    const SizedBox(height: 35),
                    _buildHeaderRow("Quick Actions", "Management"),
                    const SizedBox(height: 16),
                    _buildActionGrid(),
                    const SizedBox(height: 35),
                    _buildHeaderRow("Recent Activity", "History"),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildRecentLeavesList(),
          ],
        ),
      ),
      ),
    );
  }
  


  Widget _buildSliverAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 80,
      pinned: true,
      elevation: 0,
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      backgroundColor: primaryNavy,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const _PlacementBadgeLogo(size: 24),
          ),
          const SizedBox(width: 14),
          const Text(
            "LeaveX",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
      actions: [
        // 🌓 Theme Toggle
        _buildAppBarAction(
          onTap: () => ThemeController().toggleTheme(),
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController(),
            builder: (context, mode, child) {
              final isDarkNow = mode == ThemeMode.dark;
              return Icon(
                isDarkNow ? Icons.light_mode_rounded : Icons.nightlight_round,
                color: Colors.white,
                size: 22,
              );
            },
          ),
        ),
        
        // 🔔 Notifications
        _buildAppBarAction(
          onTap: () => Navigator.pushNamed(context, '/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
              StreamBuilder<int>(
                stream: NotificationService().getUnreadCount(_uid),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent, 
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryNavy, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 🚪 Logout
        _buildAppBarAction(
          onTap: _showLogoutConfirmation,
          child: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildAppBarAction({required VoidCallback onTap, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverToBoxAdapter(
        child: StreamBuilder<UserModel?>(
          stream: FirestoreService().getUserStream(_uid),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final displayName = user?.name.isNotEmpty == true ? user!.name : _name;
            final displayId = user?.manualEmployeeId?.isNotEmpty == true 
                ? user!.manualEmployeeId 
                : (user?.employeeId ?? _employeeId);
            final displayPic = user?.profilePicUrl;

            return Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                   Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAvatar(displayPic, displayName),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hi, $displayName", 
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: isDark ? Colors.white : primaryNavy, 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: -0.8
                              )
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.designation ?? "Faculty Member",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(child: _buildBadgeItem(Icons.badge_rounded, "EMPLOYEE ID", displayId ?? '')),
                          VerticalDivider(color: theme.dividerColor.withOpacity(0.3), thickness: 1, indent: 4, endIndent: 4),
                          Expanded(child: _buildBadgeItem(Icons.calendar_today_rounded, "ACADEMIC YEAR", academicYear)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDark ? Colors.blueAccent : primaryNavy, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? picUrl, String name) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: (isDark ? Colors.blueAccent : primaryNavy).withOpacity(0.2),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.blueAccent : primaryNavy).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: CircleAvatar(
        radius: 32, 
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
        child: picUrl == null 
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: isDark ? Colors.blueAccent : primaryNavy, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 24
                )
              )
            : null,
      ),
    );
  }

  Widget _buildHeaderRow(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitle.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: theme.textTheme.titleLarge?.color)),
      ],
    );
  }

  Widget _buildStatTile(String label, double val, Color color, IconData icon, String subLabel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label, 
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                val.toStringAsFixed(val % 1 == 0 ? 0 : 1).replaceAll('.0', ''), 
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : primaryNavy,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subLabel, 
              style: TextStyle(
                fontSize: 8, 
                color: color, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 0.8
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // 3 columns if wide, 2 if narrow
        int crossAxisCount = width > 500 ? 3 : 2;
        
        // Define action items
        final List<Map<String, dynamic>> items = [
          {'icon': Icons.add_circle_outline, 'label': "Apply Leave", 'color': const Color(0xFF001C3D), 'tap': () => Navigator.pushNamed(context, '/apply')},
          {'icon': Icons.star_rounded, 'label': "Earn Comp", 'color': const Color(0xFF003366), 'tap': () => Navigator.pushNamed(context, '/request-compoff')},
          {'icon': Icons.history_rounded, 'label': "History", 'color': primaryNavy, 'tap': () => Navigator.pushNamed(context, '/history')},
          {'icon': Icons.calendar_month_rounded, 'label': "Dept. Calendar", 'color': const Color(0xFF003366), 'tap': () => Navigator.pushNamed(context, '/calendar')},
          {
            'icon': _role != 'admin' ? Icons.person_outline_rounded : Icons.admin_panel_settings_outlined, 
            'label': _role != 'admin' ? "Profile" : "Admin", 
            'color': primaryNavy, 
            'tap': () => Navigator.pushNamed(context, _role != 'admin' ? '/profile' : '/admin')
          },
          {'icon': Icons.business_center_outlined, 'label': "Apply OD", 'color': primaryNavy, 'tap': () => Navigator.pushNamed(context, '/apply', arguments: {'type': 'OD'})},
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: width > 500 ? 1.4 : 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final it = items[index];
            return _buildActionTile(it['icon'], it['label'], it['tap'], it['color']);
          },
        );
      },
    );
  }

  Widget _buildActionTile(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24)
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label, 
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textMain),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLeavesList() {
    // Need reliable year. If empty, stream might fail or show nothing.
    if (academicYear.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getCombinedActivityStream(_uid), // ✅ Use centralized Service stream
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildActivitySkeleton(),
                childCount: 3,
              ),
            ),
          );
        }
        
        if (snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  "No recent records found",
                  style: TextStyle(color: textMuted),
                ),
              ),
            ),
          );
        }

        // Take only the 3 most recent items
        final recentItems = snapshot.data!.take(3).toList();

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildActivityCard(recentItems[index]);
              },
              childCount: recentItems.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> d) {
    final activityType = d['activityType'] ?? 'leave';
    final status = (d['status'] ?? 'Pending').toString();
    final statusCol = Helpers.getStatusColor(status);
    final id = d['id'] ?? d['applicationId'] ?? '';

    // --- CASE 1: COMP OFF EARN REQUEST ---
    if (activityType == 'comp_off') { 
      final workedDateStr = d['workedDate'];
      DateTime? workedDate;
      if (workedDateStr != null) {
         try { workedDate = DateTime.parse(workedDateStr); } catch (_) {}
      }
      final days = (d['days'] ?? 1.0).toDouble();

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _neatCard(hasBorder: true),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_rounded, color: primaryNavy, size: 24),
          ),
          title: Text(
            'Comp-Off Credit',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).textTheme.titleMedium?.color),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              workedDate != null
                  ? 'Worked on ${DateFormat('MMM dd').format(workedDate)} • $days Day(s)' 
                  : 'Comp-Off Earn Request',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
            ),
          ),
          trailing: _buildStatusBadge(status, statusCol),
          onTap: () {
            Navigator.pushNamed(
              context, 
              AppRoutes.compOffDetail,
              arguments: {'docId': id, 'department': d['department'] ?? _userDept},
            );
          },
        ),
      );
    } 
    
    // --- CASE 2: REGULAR LEAVE / OD / COMP-OFF USAGE ---
    else {
      DateTime parseDate(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
        return DateTime.now();
      }

      final from = parseDate(d['fromDate']);
      final to = parseDate(d['toDate']);
      final leaveType = d['leaveType']?.toString() ?? 'Leave';
      
      final style = _styleCache[leaveType] ?? {
        'color': Helpers.getLeaveColor(leaveType),
        'icon': Helpers.getLeaveIcon(leaveType)
      };
      
      final icon = style['icon'] as IconData;
      final color = style['color'] as Color;
      final displayType = Helpers.getLeaveName(leaveType);

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: _neatCard(hasBorder: true),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48, 
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            displayType,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).textTheme.titleMedium?.color),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${DateFormat('MMM dd').format(from)} - ${DateFormat('MMM dd').format(to)}',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
            ),
          ),
          trailing: _buildStatusBadge(status, statusCol),
          onTap: () {
             if (id.isNotEmpty) {
               Navigator.pushNamed(
                 context, 
                 '/detail', 
                 arguments: {
                   'leaveId': id, 
                   'academicYearId': d['academicYearId'] ?? academicYear,
                   'department': d['department'] ?? _userDept,
                 }
               );
             }
          },
        ),
      );
    }
  }

  Widget _buildActivitySkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _neatCard(hasBorder: true),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          title: Container(
            width: 100,
            height: 12,
            color: Theme.of(context).cardColor,
          ),
          subtitle: Container(
            width: 150,
            height: 10,
            margin: const EdgeInsets.only(top: 8),
            color: Theme.of(context).cardColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  BoxDecoration _neatCard({bool hasBorder = false}) {
     final theme = Theme.of(context);
     return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: hasBorder ? Border.all(color: const Color(0xFFE2E8F0), width: 1) : null,
    );
  }

  // --- NEW: Shimmer Balances Grid ---
  Widget _buildBalancesGrid() {
    if (academicYear.isEmpty) {
       return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }

    final fs = FirestoreService();
    
    return StreamBuilder<Map<String, double>>(
      stream: fs.streamDynamicUserBalances(_uid, _userDept),
      builder: (context, leaveSnap) {
        return StreamBuilder<Map<String, double>>(
          stream: fs.streamCompOffStats(_uid, academicYear),
          builder: (context, compSnap) {
             final leaveBalances = leaveSnap.data;
             final compStats = compSnap.data;
             
             if (leaveSnap.connectionState == ConnectionState.waiting || compSnap.connectionState == ConnectionState.waiting) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: width > 500 ? (width > 800 ? 4 : 3) : 2,
                      childAspectRatio: width > 500 ? 1.0 : 0.85,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 16,
                      padding: EdgeInsets.zero,
                      children: List.generate(4, (index) => _buildSkeletonTile()),
                    );
                  }
                );
             }

             final stats = compStats ?? {'limit': 0.0, 'used': 0.0};
             final double compBalance = (stats['limit']! - stats['used']!).clamp(0.0, 99.0);
             final double compUsed = stats['used']!;

             // Merge real-time counts into a list of tiles
             List<Widget> tiles = [];
             
             // 1. Regular Leave Types
             _leaveBalances.forEach((name, data) {
                 final bal = (leaveBalances ?? {})[name] ?? 0.0;
                 final style = _styleCache[name] ?? {};
                 tiles.add(_buildStatTile(
                    Helpers.getLeaveName(name),
                    bal,
                    style['color'] ?? Helpers.getLeaveColor(name),
                    style['icon'] ?? Helpers.getLeaveIcon(name),
                    "LEFT"
                 ));
             });

             // 2. Comp Off Balance
             tiles.add(_buildStatTile("Comp Off", compBalance, const Color(0xFF8B5CF6), Icons.star_rounded, "LEFT"));
             
             // 3. Comp Used
             tiles.add(_buildStatTile("Comp Used", compUsed, const Color(0xFF003366), Icons.history_rounded, "USED"));

             return LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                int crossAxisCount = width > 500 ? (width > 800 ? 4 : 3) : 2;
                double childAspectRatio = width > 500 ? 1.0 : 0.85;
                
                return Center(
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    padding: EdgeInsets.zero,
                    children: tiles,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _PlacementBadgeLogo extends StatelessWidget {
  final double size;
  const _PlacementBadgeLogo({this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
