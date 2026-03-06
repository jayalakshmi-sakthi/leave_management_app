import 'package:flutter/material.dart';
import '../utils/helpers.dart'; // Provides getStatusColor and getStatusLabel
// Assuming the file below now correctly defines AppColors:
import '../utils/theme.dart';
import '../models/leave_model.dart';

class LeaveCard extends StatelessWidget {
  final LeaveModel leave;
  final VoidCallback? onTap;

  const LeaveCard({super.key, required this.leave, this.onTap});

  // 🎯 Note: The redundant _getStatusColor function has been removed from here.

  @override
  Widget build(BuildContext context) {
    // 1. Centralize color retrieval using the Helpers class
    final statusColor = Helpers.getStatusColor(leave.status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              const Icon(Icons.calendar_month,
                  size: 32, color: AppColors.primary),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leave Type
                    Text(
                      Helpers.capitalize(leave.leaveType),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Date Range
                    Text(
                      "${Helpers.formatDate(leave.fromDate)} → ${Helpers.formatDate(leave.toDate)}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Number of Days
                    Text(
                      Helpers.daysLabel(leave.numberOfDays),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  // Use the centralized statusColor for the background
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  // 🎯 Enhancement: Use Helpers.getStatusLabel for consistent capitalization
                  Helpers.getStatusLabel(leave.status),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    // Use the centralized statusColor for text color
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
