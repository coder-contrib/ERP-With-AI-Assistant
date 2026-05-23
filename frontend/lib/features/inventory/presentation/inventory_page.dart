import 'package:flutter/material.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.all(24), child: Text('Inventory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)));
  }
}
