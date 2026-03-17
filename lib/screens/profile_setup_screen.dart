import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'crop_screen.dart';
import 'dart:typed_data';
import 'dart:ui'; // Tiara
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart'; // ✅ Added

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _empIdController = TextEditingController();
  final _roleController = TextEditingController(text: "Staff");
  
  String? _selectedDepartment;
  final List<String> _departments = [
    // Engineering
    'CIVIL', 'MECH', 'MTS', 'AUTO', 'CHEM', 'FT',
    'EEE', 'ECE', 'EIE', 'CSE', 'IT', 'CSD', 'AIDS', 'AIML',
    // PG
    'MBA', 'MCA',
    // Science
    'B.Sc CSD', 'B.Sc IS', 'B.Sc SS', 'M.Sc SS',
    // Others
    'Ph.D', 'General', 'Placement Cell'
  ];
  
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final _picker = ImagePicker();

  bool _isLoading = false;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Ultra Premium Palette
  static const Color primaryBlue = Color(0xFF2563EB); 
  static const Color darkText = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad));
    
    _animController.forward();
    _fetchExistingData();
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if ((user.displayName ?? "").isNotEmpty) {
        _nameController.text = user.displayName!;
      }
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 10));
      if (snap.exists) {
        final data = snap.data();
        if (data != null) {
           _nameController.text = data['name'] ?? _nameController.text;
           _empIdController.text = data['employeeId'] ?? "";
           _roleController.text = data['designation'] ?? ""; // ✅ Fetch Designation
           _selectedDepartment = data['department'];
        }
      }
    }
  }

  Future<void> _submit() async {
    debugPrint("🔵 Submit Clicked");
    
    // Check validation
    if (!_formKey.currentState!.validate()) {
       _showSnack("Please fill all required fields", isError: true);
       return;
    }

    if (_selectedDepartment == null) {
       _showSnack("Please select your Department", isError: true);
       return;
    }

    // 📸 MANDATORY IMAGE CHECK
    if (_imageFile == null && _imageBytes == null) {
       _showSnack("Profile Picture is Mandatory", isError: true);
       return;
    }
    
    debugPrint("🟢 Validation Passed");
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("🔴 User is NULL");
        return;
      }
      
      debugPrint("🔵 Updating User: ${user.uid}");

      final name = _nameController.text.trim();
      final empId = _empIdController.text.trim();
      final designation = _roleController.text.trim(); // Renamed variable for clarity

      String? photoUrl;
      if (_imageFile != null) {
          debugPrint("🔵 Uploading Image...");
          photoUrl = await FirestoreService().uploadProfileImage(_imageFile!, user.uid);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'employeeId': empId,
        'designation': designation, // ✅ Saved as designation
        'role': 'staff', // Hardcoded role for auth logic
        'department': _selectedDepartment,
        'email': user.email,
        'profilePicUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔔 NOTIFY ADMINS
      if (empId.isNotEmpty) {
         try {
           await NotificationService().notifyAdmins(
             title: 'New User Registration',
             body: '${name.toUpperCase()} ($empId) - ${designation.toUpperCase()} is awaiting approval.',
             type: 'new_user',
             relatedId: user.uid,
             targetDepartment: _selectedDepartment, // ✅ department isolation
             triggeringUserId: user.uid,
           );
         } catch (e) {
           debugPrint("Notification error: $e");
         }
      }
      
      debugPrint("🟢 Profile Updated. Navigating...");

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/pending-approval');
      }

    } catch (e) {
      debugPrint("🔴 Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) {
      final croppedXFile = await _cropImage(img);
      if (croppedXFile != null) {
        final bytes = await croppedXFile.readAsBytes();
        setState(() {
          _imageFile = croppedXFile;
          _imageBytes = bytes;
        });
      }
    }
  }

  Future<XFile?> _cropImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (!mounted) return null;

    final croppedBytes = await Navigator.push<Uint8List>(
      context, 
      MaterialPageRoute(builder: (ctx) => CropScreen(image: bytes))
    );
    
    if (croppedBytes != null) {
       return XFile.fromData(croppedBytes, name: 'cropped_image.jpg');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("", style: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.bold)), // Hidden title for clean look
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          // 1. Dynamic Background & Blobs
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                 colors: [
                   Color(0xFFF1F5F9), // Slate 100
                   Color(0xFFDBEAFE), // Blue 100
                   Colors.white,
                 ],
              ),
            ),
          ),
          
          // Blob 1
          Positioned(
            top: -100,
            right: -100,
            child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
          ),
          
           // Blob 2
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
          ),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Welcome to LeaveX", 
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: darkText, letterSpacing: -1)
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Fill in your details to get started",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 40),
                        
                        // Glass Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                   BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.08), blurRadius: 40, offset: const Offset(0, 15)),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Avatar
                                    GestureDetector(
                                      onTap: _pickImage,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                           Container(
                                             width: 120,
                                             height: 120,
                                             decoration: BoxDecoration(
                                               color: Colors.white,
                                               shape: BoxShape.circle,
                                               border: Border.all(color: Colors.white, width: 4),
                                               boxShadow: [
                                                 BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                                               ],
                                               image: _imageBytes != null 
                                                 ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                                                 : null
                                             ),
                                             child: _imageBytes == null 
                                               ? Icon(Icons.person_rounded, size: 48, color: Colors.blueGrey[200]) 
                                               : null,
                                           ),
                                           Positioned(
                                             bottom: 4,
                                             right: 4,
                                             child: Container(
                                               padding: const EdgeInsets.all(8),
                                               decoration: BoxDecoration(
                                                 gradient: const LinearGradient(colors: [primaryBlue, Color(0xFF1D4ED8)]),
                                                 shape: BoxShape.circle,
                                                 boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                                                 border: Border.all(color: Colors.white, width: 2)
                                               ),
                                               child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                             ),
                                           )
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 36),
                                    
                                    _buildInputGroup("Full Name", _nameController, "Enter your full name", Icons.person_outline_rounded,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return "Name is required";
                                        if (v.length < 3) return "Name must be at least 3 characters";
                                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v)) return "Name must contain only letters";
                                        return null;
                                      }
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInputGroup("Employee ID", _empIdController, "e.g. KEC1234", Icons.badge_outlined, isId: true,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return "Employee ID is required";
                                        if (v.length < 3) return "ID too short";
                                        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) return "ID must be alphanumeric (No special chars)";
                                        return null;
                                      }
                                    ),
                                    const SizedBox(height: 20),
                                    _buildInputGroup("Designation", _roleController, "e.g. Assistant Professor", Icons.work_outline_rounded,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return "Designation is required";
                                        if (v.length < 3) return "Designation too short";
                                        if (RegExp(r'[0-9]').hasMatch(v)) return "Designation should not contain numbers";
                                        return null;
                                      }
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // 🏢 Department Dropdown
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                                          child: Text("Department", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: darkText, fontSize: 15)),
                                        ),
                                        DropdownButtonFormField<String>(
                                          value: _selectedDepartment, // null initially
                                          validator: (v) => v == null ? "Required" : null,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: darkText),
                                          isExpanded: true, // ✅ Fix Overflow
                                          decoration: InputDecoration(
                                            hintText: "Select Department",
                                            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontWeight: FontWeight.w400),
                                            prefixIcon: const Icon(Icons.domain_rounded, color: Color(0xFF64748B), size: 22),
                                            filled: true,
                                            fillColor: Colors.grey[50], // Same as inputs
                                            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: const BorderSide(color: primaryBlue, width: 2),
                                            ),
                                          ),
                                          dropdownColor: Colors.white,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                          items: _departments.map((dept) => DropdownMenuItem(
                                            value: dept,
                                            child: Text(dept),
                                          )).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedDepartment = val);
                                          },
                                        ),
                                      ],
                                    ),
                                    
                                    
                                    const SizedBox(height: 40),
                                    
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryBlue,
                                          foregroundColor: Colors.white,
                                          elevation: 10,
                                          shadowColor: primaryBlue.withOpacity(0.4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                        child: _isLoading 
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                          : Text(
                                              "Continue",
                                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputGroup(String label, TextEditingController controller, String hint, IconData icon, {bool isId = false, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: darkText, fontSize: 15)),
        ),
        TextFormField(
          controller: controller, // ✅ Fixed
          readOnly: false,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: darkText),
          validator: validator ?? (v) => v!.isEmpty ? "Required" : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontWeight: FontWeight.w400),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 22),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
          ),
        ),
        if (isId)
           Padding(
             padding: const EdgeInsets.only(top: 8, left: 4),
             child: Row(
               children: [
                 const Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange),
                 const SizedBox(width: 4),
                 Text("This ID is permanent and official.", style: GoogleFonts.inter(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w600)),
               ],
             ),
           )
      ],
    );
  }
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      )
    );
  }
}
