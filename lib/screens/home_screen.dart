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

  // --- Dynamic Data ---
  Map<String, dynamic> _leaveBalances = {}; 
  double _compGranted = 0.0;
  double _compUsed = 0.0;

  String academicYear = ""; 

  bool _loadingCounts = true;
  
  // Dynamic Style Cache (name -> {color, icon})
  Map<String, Map<String, dynamic>> _styleCache = {};

  // --- Soulful Palette ---
  static const Color primaryPurple = Color(0xFF7C3AED); // Violet 600
  static const Color accentPurple = Color(0xFF5B21B6); // Violet 800
  // static const Color scaffoldBg = Color(0xFFF8FAFC); // Use Theme
  // static const Color textMain = Color(0xFF0F172A); // Use Theme
  // static const Color textMuted = Color(0xFF64748B); // Use Theme
  // static const Color cardSurface = Colors.white; // Use Theme
  static const Color textMain = Color(0xFF0F172A);
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

      // Listen for Background FCM clicks
      notifService.navigationStream.listen((data) {
        debugPrint("🧭 Navigating from Background FCM: $data");
        final type = data['type'];
        final relatedId = data['relatedId'];
        final academicYearId = data['academicYearId'];

        if (type == 'status_change' && relatedId != null) {
          final lType = data['leaveType'];
          if (lType == 'COMP' || lType == 'Comp-Off Earn') {
            Navigator.pushNamed(
              context,
              AppRoutes.compOffDetail,
              arguments: relatedId,
            );
          } else {
            Navigator.pushNamed(
              context,
              AppRoutes.detail,
              arguments: {
                'leaveId': relatedId,
                'academicYearId': academicYearId ?? '2024-2025',
              },
            );
          }
        } else if (type == 'comp_off_request' && relatedId != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.compOffDetail,
            arguments: relatedId,
          );
        } else if (type == 'announcement') {
          Navigator.pushNamed(context, AppRoutes.notifications);
        }
      });

      _loadAll(); 
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
          .where('userId', isEqualTo: _uid)
          .where('academicYearId', isEqualTo: academicYear)
          // .where('status', isEqualTo: 'Approved') // Removed to include Pending
          .get();

      Map<String, double> usedMap = {};
      for (var doc in leaveQuery.docs) {
        final d = doc.data();
        if (d['status'] == 'Rejected') continue; // Skip Rejected only

        final type = d['leaveType'] as String? ?? 'Other';
        final days = (d['numberOfDays'] ?? 0).toDouble();
        usedMap[type] = (usedMap[type] ?? 0) + days;
      }
      
      // Separate COMP logic
      _compUsed = usedMap['COMP'] ?? 0.0;
      
      // 4. Build Balance Map
      Map<String, dynamic> balances = {};
      
      final colors = [Colors.orange, Colors.green, Colors.purple, Colors.teal, Colors.indigo];
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

      // 3. Fetch Usage (Spent Comp-Offs)
      // 3. Fetch Usage (Spent Comp-Offs)
      // Optimized: Query broader scope to use existing (UserId + Year) index, verify in-memory.
      final qUsage = await _fire
          .collection('leaveRequests')
          .where('userId', isEqualTo: _uid)
          .where('academicYearId', isEqualTo: academicYear)
          // Removed: .where('leaveType', isEqualTo: 'COMP') // Filter in memory
          // Removed: .where('status', isNotEqualTo: 'Rejected') // Filter in memory
          .get();

      double totalUsed = 0.0;
      for (var d in qUsage.docs) {
        final data = d.data();
        final type = data['leaveType'] as String?;
        final status = data['status'] as String?;
        
        if (type == 'COMP' && status != 'Rejected') {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
            ),
            const SizedBox(height: 20),
            const Text("Sign Out", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textMain)),
            const SizedBox(height: 10),
            const Text("Are you sure you want to exit LeaveX?", textAlign: TextAlign.center, style: TextStyle(color: textMuted, fontSize: 15)),
            const SizedBox(height: 35),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(
                    onPressed: () async {
                      await _auth.signOut();
                      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
              ],
            ),
            const SizedBox(height: 10),
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
        maxWidth: 600, // Reduced back to mobile size per user request
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
    return SliverAppBar(
      expandedHeight: 70, 
      pinned: true,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: primaryPurple,
      automaticallyImplyLeading: false, 
      centerTitle: false,
      titleSpacing: 20,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlacementBadgeLogo(size: 32),
          SizedBox(width: 12),
          Text(
            "LeaveX",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        // 🌓 Night Light Toggle
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController(),
          builder: (context, mode, child) {
            final isDark = mode == ThemeMode.dark;
            return IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.nightlight_round, color: Colors.white, size: 28),
              onPressed: () => ThemeController().toggleTheme(),
              tooltip: isDark ? "Day Mode" : "Night Light",
            );
          },
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            StreamBuilder<int>(
              stream: NotificationService().getUnreadCount(_uid),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                );
              },
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.power_settings_new, color: Colors.white, size: 28),
          onPressed: _showLogoutConfirmation,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProfileSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryPurple, accentPurple],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryPurple.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _buildAvatar(displayPic, displayName),
                  const SizedBox(height: 20),
                  Text(
                    "Hi, $displayName", 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 28, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -1.0
                    )
                  ),
                  const SizedBox(height: 10),
                  _buildIdBadge(displayId),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildAvatar(String? picUrl, String name) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white30, width: 2)),
      child: CircleAvatar(
        radius: 28, 
        backgroundColor: Colors.white24,
        backgroundImage: picUrl != null ? NetworkImage(picUrl) : null,
        child: picUrl == null 
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
              )
            : null,
      ),
    );
  }

  Widget _buildLogoutIcon() {
    return InkWell(
      onTap: _showLogoutConfirmation,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.power_settings_new, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildIdBadge(String? id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                "ID: ${id ?? ''}",
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 12),
              const SizedBox(width: 6),
              Text(
                "AY: $academicYear",
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
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
    // 🌍 Responsive scaling for Web vs Mobile
    final bool isWide = MediaQuery.of(context).size.width > 600;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(vertical: isWide ? 20 : 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
           BoxShadow(
             color: color.withOpacity(0.05), 
             blurRadius: 10, 
             offset: const Offset(0, 4)
           )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isWide ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), 
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: isWide ? 28 : 22),
          ),
          SizedBox(height: isWide ? 12 : 8),
          Text(
            label, 
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color, 
              fontWeight: FontWeight.w800, 
              fontSize: isWide ? 15 : 12 
            )
          ),
          SizedBox(height: isWide ? 10 : 6),
          FittedBox(
            child: Text(
              val.toStringAsFixed(1), 
              style: TextStyle(
                fontSize: isWide ? 42 : 30, 
                fontWeight: FontWeight.w900, 
                color: color, 
                letterSpacing: -1
              )
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subLabel, 
            style: TextStyle(
              fontSize: isWide ? 12 : 10, 
              color: color.withOpacity(0.7), 
              fontWeight: FontWeight.w800, 
              letterSpacing: 1.2
            )
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final bool isWide = MediaQuery.of(context).size.width > 600;

        return Column(
          children: [
            // Row 1: Apply & Earn Comp
            Row(
              children: [
                Expanded(child: _buildActionTile(Icons.add_circle_outline, "Apply Leave", () => Navigator.pushNamed(context, '/apply'), primaryPurple)),
                const SizedBox(width: 14),
                Expanded(child: _buildActionTile(Icons.star, "Earn Comp", () => Navigator.pushNamed(context, '/request-compoff'), Colors.orange)),
              ],
            ),
            const SizedBox(height: 14),
            
            // Row 2: History & Calendar
            Row(
              children: [
                Expanded(child: _buildActionTile(Icons.history, "History", () => Navigator.pushNamed(context, '/history'), Colors.indigo)),
                const SizedBox(width: 14),
                Expanded(child: _buildActionTile(Icons.calendar_month_rounded, "Dept. Calendar", () => Navigator.pushNamed(context, '/calendar'), Colors.pinkAccent)),
              ],
            ),
            const SizedBox(height: 14),
            
            // Row 3: Profile/Admin & Apply OD
            Row(
              children: [
                if (_role != 'admin')
                  Expanded(child: _buildActionTile(Icons.person, "Profile", () => Navigator.pushNamed(context, '/profile'), const Color(0xFF06B6D4)))
                else
                  Expanded(child: _buildActionTile(Icons.admin_panel_settings, "Admin", () => Navigator.pushNamed(context, '/admin'), Colors.redAccent)),
                 
                 const SizedBox(width: 14),
                 
                 // Apply OD (Moved from full width)
                 Expanded(child: _buildActionTile(
                   Icons.business_center_rounded, 
                   "Apply OD", 
                   () => Navigator.pushNamed(context, '/apply', arguments: {'type': 'OD'}), 
                   const Color(0xFF0EA5E9) // Sky Blue
                 )),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionTile(IconData icon, String label, VoidCallback onTap, Color color) {
    final bool isWide = MediaQuery.of(context).size.width > 600;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
             BoxShadow(
               color: color.withOpacity(0.05), 
               blurRadius: 10, 
               offset: const Offset(0, 4)
             )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: EdgeInsets.all(isWide ? 16 : 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1), 
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Icon(icon, color: color, size: isWide ? 34 : 28)),
            SizedBox(height: isWide ? 12 : 8),
            Text(
              label, 
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                fontSize: isWide ? 16 : 13, 
                color: theme.textTheme.titleMedium?.color
              )
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

    // --- CASE 1: COMP OFF REQUEST ---
    if (activityType == 'comp_off') { 
      // Note: Data comes from 'compOffRequests' collection
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
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.purple, size: 24),
          ),
          title: Text(
            'Comp-Off Request',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).textTheme.titleMedium?.color),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              workedDate != null
                  ? 'Worked on ${DateFormat('MMM dd').format(workedDate)} • $days day(s)' 
                  : 'Comp-Off Earn Request',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13),
            ),
          ),
          trailing: _buildStatusBadge(status, statusCol),
          onTap: () {
            Navigator.pushNamed(
              context, 
              AppRoutes.compOffDetail,
              arguments: d['id'],
            );
          },
        ),
      );
    } 
    
    // --- CASE 2: REGULAR LEAVE ---
    else {
      DateTime parseDate(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
        return DateTime.now();
      }

      final from = parseDate(d['fromDate']);
      final to = parseDate(d['toDate']);
      final leaveType = d['leaveType'].toString();
      
      // Use Cached Dynamic Style
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
             final leaveId = d['id'] ?? d['applicationId'];
             if (leaveId != null) {
               Navigator.pushNamed(
                 context, 
                 '/detail', 
                 arguments: {
                   'leaveId': leaveId, 
                   'academicYearId': d['academicYearId'] ?? academicYear
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
     final isDark = theme.brightness == Brightness.dark;
     return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(24),
      border: hasBorder ? Border.all(
        color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9), 
        width: 1.5
      ) : null,
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black26 : const Color(0xFF0F172A).withOpacity(0.04), 
          blurRadius: 20, 
          offset: const Offset(0, 8)
        )
      ],
    );
  }

  // --- NEW: Shimmer Balances Grid ---
  Widget _buildBalancesGrid() {
    if (_loadingCounts) {
       return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        padding: EdgeInsets.zero, // Padding handled by parent
        children: List.generate(4, (index) => _buildSkeletonTile()),
      );
    }

    Map<String, dynamic> items = Map.from(_leaveBalances);
    // Default Balances if empty
    if (items.isEmpty && !_loadingCounts) { // Only if not loading
      items = {
        'CL': {'limit': 12, 'balance': 0, 'color': Colors.orange},
        'VL': {'limit': 6, 'balance': 0, 'color': Colors.green},
      };
    }
    
    List<Widget> tiles = [];
    final keys = items.keys.toList();
    keys.sort((a, b) {
       if (a == 'CL') return -1;
       if (b == 'CL') return 1;
       return 0;
    });

    for (var k in keys) {
      if (k == 'OD' || k == 'SL') continue; // Hidden types

      final v = items[k]!;
      final icon = Helpers.getLeaveIcon(k);
      final color = Helpers.getLeaveColor(k);
      
      tiles.add(_buildStatTile(
          Helpers.getLeaveName(k), 
          (v['balance'] as num).toDouble(), 
          (v['color'] is int) ? Color(v['color']) : (v['color'] as Color? ?? color), // Use dynamic color if available
          v['icon'] != null ? Helpers.getIconFromCodePoint(v['icon']) : icon, // Use dynamic icon if available
          "LEFT"));
    }
    
    // Add Comp Off Balance
    final compBalance = _compGranted.clamp(0.0, 99.0);
    tiles.add(
       _buildStatTile("Comp Off", compBalance, Colors.purple, Icons.star, "LEFT")
    );
    // Add Comp Off Used
    tiles.add(
      _buildStatTile("Comp Used", _compUsed, Colors.orange, Icons.history, "USED")
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // HARDCODED to 2 columns to satisfy user request 📱
        final crossAxisCount = 2;
        final childAspectRatio = 0.85;
        
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000), 
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
          ),
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
