import 'package:flutter/material.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.all(24), child: Text('Customers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)));
  }
}
