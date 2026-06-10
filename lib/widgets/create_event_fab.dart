import 'package:flutter/material.dart';
import '../screens/create_event_screen.dart';

class CreateEventFab extends StatelessWidget {
  const CreateEventFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateEventScreen()),
        );
      },
      child: const Icon(Icons.add),
      backgroundColor: Colors.orange,
    );
  }
}
