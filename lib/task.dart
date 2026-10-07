import 'package:flutter/material.dart';

class Task extends StatelessWidget {
  const Task({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 20),
          Badge(
            label: Text('9+', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            child: Icon(Icons.notification_add_outlined, color: Colors.green),
          ),
          Chip(label: Text('data'), backgroundColor: Colors.pink),
          Card(
            color: Colors.red,
            shadowColor: Colors.green,
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(Icons.home, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
