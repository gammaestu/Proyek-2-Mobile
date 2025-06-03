import 'package:flutter/material.dart';

class AppBarDosen extends StatelessWidget implements PreferredSizeWidget {
  final Map<String, dynamic>? userData;

  const AppBarDosen({
    super.key,
    this.userData,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "SIGNIX",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Text(
                userData?['namaDosen'] ?? "Dosen",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: Text(
                  (userData?['namaDosen'] as String?)?.isNotEmpty == true
                      ? (userData!['namaDosen'] as String)[0].toUpperCase()
                      : 'D',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}