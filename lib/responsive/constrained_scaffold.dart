import 'package:flutter/material.dart';

class ConstrainedScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Color? backgroundColor; // Added this property
  final Widget? bottomNavigationBar; // Added this property for future use

  const ConstrainedScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.backgroundColor,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      backgroundColor: backgroundColor, // Pass the color to the underlying Scaffold
      bottomNavigationBar: bottomNavigationBar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 450, // Screen size limit for web/desktop responsiveness
          ),
          child: body,
        ),
      ),
    );
  }
}
