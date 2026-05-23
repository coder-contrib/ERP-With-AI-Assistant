import 'package:flutter/material.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.all(24), child: Text('Products', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)));
  }
}
