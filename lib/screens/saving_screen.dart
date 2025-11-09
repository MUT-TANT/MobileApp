import 'package:flutter/material.dart';
import 'package:stacksave/constants/colors.dart';
import 'package:stacksave/screens/add_saving_screen.dart';
import 'package:stacksave/screens/withdraw_screen.dart';

class SavingScreen extends StatefulWidget {
  const SavingScreen({super.key});

  @override
  State<SavingScreen> createState() => _SavingScreenState();
}

class _SavingScreenState extends State<SavingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Header with tabs
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Title
                  const Text(
                    'Savings',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  AddSavingScreen(showNavBar: false),
                  WithdrawScreen(showNavBar: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
