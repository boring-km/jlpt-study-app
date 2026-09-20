import 'dart:math';
import 'package:flutter/material.dart';

class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isFlipped;
  final VoidCallback onTap;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.isFlipped,
    required this.onTap,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  static const _flipDuration = Duration(milliseconds: 250);

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _flipDuration, vsync: this);
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 동작 줄이기를 켠 기기에선 뒤집기를 즉시 끝낸다.
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _flipDuration;
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 뒷면은 매 프레임 다시 감싸지 않도록 빌드 밖에서 한 번만 뒤집어 둔다.
    final back = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi),
      child: widget.back,
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: angle < pi / 2 ? widget.front : back,
          );
        },
      ),
    );
  }
}
