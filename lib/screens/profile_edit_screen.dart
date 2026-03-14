import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  String _errorMessage = "";
  String? _profileImagePath;

  // Added more avatars to demonstrate horizontal scrolling
  final List<String> _preloadedAvatars = const [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
    'assets/avatars/avatar6.png',
    'assets/avatars/avatar7.png',
    'assets/avatars/avatar8.png',
    'assets/avatars/avatar9.png',
    'assets/avatars/avatar10.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text = prefs.getString(Constants.prefUserName) ?? "";
        _budgetController.text = (prefs.getDouble(Constants.prefMonthlyBudget) ?? 0).toStringAsFixed(0);
        
        // Load the saved profile image path, or default to avatar9 if none exists
        _profileImagePath = prefs.getString('pref_profile_image') ?? 'assets/avatars/avatar9.png';
        
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final String name = _nameController.text.trim();
    final String budgetStr = _budgetController.text.trim();
    final String pin = _pinController.text.trim();

    if (name.isEmpty || budgetStr.isEmpty) {
      setState(() => _errorMessage = "Name and Budget cannot be empty.");
      return;
    }

    final double? budget = double.tryParse(budgetStr);
    if (budget == null || budget <= 0) {
      setState(() => _errorMessage = "Please enter a valid budget amount.");
      return;
    }
    
    if (pin.isNotEmpty && pin.length != 4) {
      setState(() => _errorMessage = "MPIN must be exactly 4 digits.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.prefUserName, name);
    await prefs.setDouble(Constants.prefMonthlyBudget, budget);
    
    // Save image path
    if (_profileImagePath != null) {
      await prefs.setString('pref_profile_image', _profileImagePath!);
    }

    if (pin.isNotEmpty) {
      await _authService.saveMpin(pin);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profile updated successfully!", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Constants.colorPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  // --- IMAGE PICKER LOGIC ---
  Future<void> _pickCustomImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        if (mounted) Navigator.pop(context); // Close bottom sheet
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to pick image: $e");
    }
  }

  // --- AVATAR SELECTION BOTTOM SHEET ---
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: Constants.glassBlur,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Constants.colorSurface.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                
                // CENTERED TEXT
                Center(
                  child: Text("SELECT IDENTITY NODE", style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)),
                ),
                const SizedBox(height: 24),
                
                // EXACT 4 AVATARS VISIBLE DYNAMIC SIZING
                LayoutBuilder(
                  builder: (context, constraints) {
                    double spacing = 16.0;
                    // Calculate perfect width for 4 items factoring in 3 spaces between them
                    double itemSize = (constraints.maxWidth - (spacing * 3)) / 4;
                    
                    return SizedBox(
                      height: itemSize, // Keep height and width equal for perfect circles
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _preloadedAvatars.length,
                        itemBuilder: (ctx, i) {
                          return GestureDetector(
                            onTap: () {
                              setState(() => _profileImagePath = _preloadedAvatars[i]);
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: itemSize, 
                              // Only add right margin if it's not the very last item in the entire list
                              margin: EdgeInsets.only(right: i == _preloadedAvatars.length - 1 ? 0 : spacing),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _profileImagePath == _preloadedAvatars[i] ? Constants.colorPrimary : Colors.white10,
                                  width: 2
                                ),
                                image: DecorationImage(
                                  image: AssetImage(_preloadedAvatars[i]), 
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Fallback icon just in case the asset doesn't exist yet
                              child: Icon(Icons.person, color: Colors.white24, size: itemSize * 0.4),
                            ),
                          );
                        }
                      ),
                    );
                  }
                ),
                const SizedBox(height: 32),
                
                // Pick from Gallery Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Constants.colorPrimary.withValues(alpha: 0.5))
                      ),
                    ),
                    onPressed: _pickCustomImage,
                    icon: const Icon(Icons.photo_library_rounded, color: Constants.colorPrimary, size: 20),
                    label: const Text("ACCESS LOCAL DIRECTORY", style: TextStyle(letterSpacing: 1, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Constants.colorAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? counterText}) {
    return InputDecoration(
      counterText: counterText,
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 0.5),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: Colors.black26,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Constants.colorPrimary.withValues(alpha: 0.5), width: 1.5)
      ),
    );
  }

  // Helper to dynamically render the profile image
  ImageProvider? _getProfileImage() {
    if (_profileImagePath == null) return null;
    if (_profileImagePath!.startsWith('assets/')) {
      return AssetImage(_profileImagePath!);
    } else {
      return FileImage(File(_profileImagePath!));
    }
  }

  @override
  Widget build(BuildContext context) { // <-- REMOVED THE CONST HERE
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Constants.colorBackground,
        body: Center(child: CircularProgressIndicator(color: Constants.colorPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, 
        surfaceTintColor: Colors.transparent, 
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "SYSTEM PROFILE", 
            style: Constants.headerStyle.copyWith(fontSize: 16, letterSpacing: 2)
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // GLOWING AVATAR NODE
              Center(
                child: GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Constants.colorSurface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Constants.colorPrimary.withValues(alpha: 0.8), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Constants.colorPrimary.withValues(alpha: 0.2), 
                              blurRadius: 24, 
                              spreadRadius: 8
                            ),
                            BoxShadow(
                              color: Constants.colorPrimary.withValues(alpha: 0.4), 
                              blurRadius: 8, 
                              spreadRadius: 2
                            )
                          ],
                          image: _getProfileImage() != null 
                            ? DecorationImage(image: _getProfileImage()!, fit: BoxFit.cover)
                            : null,
                        ),
                        child: _getProfileImage() == null
                            ? const Icon(Icons.person_rounded, size: 50, color: Constants.colorPrimary)
                            : null,
                      ),
                      // Small Edit Badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Constants.colorPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Constants.colorBackground, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                      ).animate().scale(delay: 600.ms, curve: Curves.easeOutBack),
                    ],
                  ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
                ),
              ),
              const SizedBox(height: 48),

              // USER DETAILS SECTION
              _buildSectionHeader(Icons.badge_rounded, "USER IDENTIFICATION").animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                decoration: _buildInputDecoration("Alias / Username", Icons.person_outline_rounded),
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),
              
              const SizedBox(height: 32),

              // FINANCIALS SECTION
              _buildSectionHeader(Icons.account_balance_wallet_rounded, "FINANCIAL TARGETS").animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 16),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.none,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                decoration: _buildInputDecoration("Monthly Target Budget (₹)", Icons.data_usage_rounded),
              ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05),

              const SizedBox(height: 32),

              // SECURITY SECTION
              _buildSectionHeader(Icons.security_rounded, "SECURITY PROTOCOLS").animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.none,
                maxLength: 4,
                obscureText: true,
                style: const TextStyle(color: Constants.colorPrimary, fontSize: 18, letterSpacing: 12, fontWeight: FontWeight.bold),
                decoration: _buildInputDecoration("New MPIN (Leave blank to keep current)", Icons.lock_outline_rounded, counterText: ""),
              ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.05),

              const SizedBox(height: 32),

              // ERROR MESSAGE
              if (_errorMessage.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Constants.colorError, fontSize: 13, fontWeight: FontWeight.bold),
                    ).animate().shake(),
                  ),
                ),
                
              // UPDATE BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.colorPrimary,
                    foregroundColor: Colors.black,
                    elevation: 8,
                    shadowColor: Constants.colorPrimary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.sync_rounded, size: 20),
                  label: const Text("UPDATE REGISTRY", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ).animate().fadeIn(delay: 800.ms).scale(curve: Curves.easeOutBack),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}