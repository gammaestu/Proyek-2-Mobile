import 'package:flutter/material.dart';

class AppBarDosen extends StatelessWidget implements PreferredSizeWidget {
  final String? namaDosen;
  final String? title;
  final List<Widget>? actions;

  const AppBarDosen({
    Key? key,
    this.namaDosen,
    this.title,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.blue,
      elevation: 2,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title ?? "SIGNIX",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            children: [
              Text(
                namaDosen ?? "Dosen",
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: Icon(Icons.person, color: Colors.blue, size: 20),
              ),
            ],
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}