import 'package:flutter/material.dart';

class OptionsMenu extends StatelessWidget {
  final IconData icon;
  final List<String> options;
  final List<Function()> functions;

  const OptionsMenu({
    super.key,
    this.icon = Icons.more_vert,
    required this.options,
    required this.functions,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(icon),
      onSelected: (value) {
        final index = options.indexOf(value);
        if (index >= 0 && index < functions.length) {
          functions[index]();
        } else {
          debugPrint('Fonction non implémentée pour l\'option: $value');
        }
      },
      itemBuilder: (BuildContext context) {
        return options.map((String option) {
          return PopupMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList();
      },
    );
  }
}