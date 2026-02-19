import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _salaryDateController = TextEditingController();

  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    // [NEW] Automatically set current day as default
    int today = DateTime.now().day;
    _salaryDateController.text = today.toString();
  }

  Future<void> _completeSetup() async {
    final String name = _nameController.text.trim();
    final String budgetStr = _budgetController.text.trim();
    final String salaryDateStr = _salaryDateController.text.trim();

    // 1. Validation
    if (name.isEmpty || budgetStr.isEmpty || salaryDateStr.isEmpty) {
      setState(() => _errorMessage = "All fields are required.");
      return;
    }

    final double? budget = double.tryParse(budgetStr);
    final int? salaryDate = int.tryParse(salaryDateStr);

    if (budget == null || budget <= 0) {
      setState(() => _errorMessage = "Please enter a valid budget.");
      return;
    }

    if (salaryDate == null || salaryDate < 1 || salaryDate > 31) {
      setState(() => _errorMessage = "Salary date must be between 1 and 31.");
      return;
    }

    // 2. Save Data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.prefUserName, name);
    await prefs.setDouble(Constants.prefMonthlyBudget, budget);
    await prefs.setInt(Constants.prefSalaryDate, salaryDate);

    // [IMPORTANT] Mark setup as complete so VerificationScreen knows next time
    await prefs.setBool(Constants.prefIsSetupComplete, true);

    // 3. Navigation
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: const Text("Profile Config"),
        backgroundColor: Constants.colorSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Initialize Vault", style: Constants.headerStyle),
            const SizedBox(height: 10),
            const Text("This data stays local on your device.",
                style: Constants.subHeaderStyle),
            const SizedBox(height: 30),

            // Name Field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "User Name",
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.person, color: Colors.grey),
                filled: true,
                fillColor: Constants.colorSurface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),

            // Budget Field
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Monthly Budget (₹)",
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.account_balance_wallet,
                    color: Colors.grey),
                filled: true,
                fillColor: Constants.colorSurface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),

            // Salary Date Field (Auto-filled)
            TextField(
              controller: _salaryDateController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Salary Cycle Start Date",
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: "Day of the month (1-31)",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon:
                    const Icon(Icons.calendar_today, color: Colors.grey),
                filled: true,
                fillColor: Constants.colorSurface,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage,
                  style: const TextStyle(color: Constants.colorError)),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.colorPrimary,
                  foregroundColor: Colors.black,
                ),
                onPressed: _completeSetup,
                child: const Text("Enter Vault",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
