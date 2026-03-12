import 'package:flutter/material.dart';

class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const TapScaleWrapper({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper> with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tapDown(TapDownDetails details) => _controller.forward();
  void _tapUp(TapUpDetails details) => _controller.reverse();
  void _tapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    return GestureDetector(
      onTapDown: _tapDown,
      onTapUp: _tapUp,
      onTapCancel: _tapCancel,
      onTap: widget.onTap,
      child: Transform.scale(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}