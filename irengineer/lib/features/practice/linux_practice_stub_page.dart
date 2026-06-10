import 'package:flutter/material.dart';

/// Placeholder for live coaching on non-Windows desktops (Linux review builds).
class LinuxPracticeStubPage extends StatelessWidget {
  const LinuxPracticeStubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '练车模式',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '实时 iRacing SDK 教练仅在 Windows 上可用。\n'
              '请使用「复盘」标签查看圈速分析。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
