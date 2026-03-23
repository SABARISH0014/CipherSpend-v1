import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart'; // Make sure this provides your typical Constants like glassBlur, glassDecoration, colorPrimary, colorAccent, etc.

class RestrictedSettingsDialog extends StatelessWidget {
  const RestrictedSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: Constants.glassBlur,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: Constants.glassDecoration.copyWith(
            border: Border.all(color: Constants.colorError.withAlpha(128), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Constants.colorError.withAlpha(40), 
                blurRadius: 30, 
                spreadRadius: 5
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gpp_maybe_rounded, color: Constants.colorError, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "RESTRICTED SETTINGS", 
                      style: Constants.headerStyle.copyWith(
                        fontSize: 16, 
                        letterSpacing: 1.5,
                        color: Constants.colorError
                      )
                    )
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Android restricts SMS access for apps installed outside the Play Store. To unlock this feature:", 
                style: Constants.fontRegular.copyWith(height: 1.5, color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildInstructionStep("1", "Tap 'Open Settings' below."),
              const SizedBox(height: 8),
              _buildInstructionStep("2", "Tap the three dots (⋮) in the top right corner."),
              const SizedBox(height: 8),
              _buildInstructionStep("3", "Tap 'Allow restricted settings'."),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withAlpha(25)),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "CANCEL", 
                        style: Constants.fontRegular.copyWith(fontWeight: FontWeight.bold, color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Constants.colorPrimary,
                        foregroundColor: Colors.black,
                        elevation: 8,
                        shadowColor: Constants.colorPrimary.withAlpha(100),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                      },
                      child: const Text(
                        "OPEN SETTINGS",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms).fadeIn(),
      ),
    );
  }

  Widget _buildInstructionStep(String stepNumber, String instruction) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Text(
            stepNumber, 
            style: const TextStyle(color: Constants.colorPrimary, fontWeight: FontWeight.bold, fontSize: 12)
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              instruction, 
              style: Constants.fontRegular.copyWith(color: Colors.white, fontSize: 13, height: 1.4)
            ),
          ),
        ),
      ],
    );
  }
}
