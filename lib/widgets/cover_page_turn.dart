import 'package:flutter/material.dart';

class CoverPageTurnController {
  _CoverPageTurnState? _state;

  void _attach(_CoverPageTurnState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void animateToPage(int page,
      {Duration duration = const Duration(milliseconds: 300)}) {
    _state?._animateToPage(page, duration: duration);
  }

  void nextPage({Duration duration = const Duration(milliseconds: 300)}) {
    _state?._nextPage(duration: duration);
  }

  void previousPage({Duration duration = const Duration(milliseconds: 300)}) {
    _state?._previousPage(duration: duration);
  }

  void jumpToPage(int page) {
    _state?._jumpToPage(page);
  }

  int get currentPage => _state?._currentPage ?? 0;
}

class CoverPageTurn extends StatefulWidget {
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final CoverPageTurnController? controller;
  final ValueChanged<int>? onPageChanged;

  const CoverPageTurn({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.controller,
    this.onPageChanged,
  });

  @override
  State<CoverPageTurn> createState() => _CoverPageTurnState();
}

class _CoverPageTurnState extends State<CoverPageTurn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int _currentPage = 0;
  int _targetPage = 0;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {});
      });

    _controller.addStatusListener(_onAnimationStatus);

    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    widget.controller?._detach();
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPage = _targetPage;
      });
      _controller.reset();
    }
  }

  void _animateToPage(int page, {Duration? duration}) {
    if (page < 0 || page >= widget.itemCount) return;
    if (_controller.isAnimating) return;

    if (page == _currentPage) return;

    _isForward = page > _currentPage;
    _targetPage = page.clamp(0, widget.itemCount - 1);

    if (duration != null) {
      _controller.duration = duration;
    }

    _controller.forward();
    widget.onPageChanged?.call(_targetPage);
  }

  void _jumpToPage(int page) {
    if (page < 0 || page >= widget.itemCount) return;
    _controller.reset();
    setState(() {
      _currentPage = page;
      _targetPage = page;
    });
  }

  void _nextPage({Duration? duration}) {
    if (_currentPage + 1 >= widget.itemCount) return;
    _animateToPage(_currentPage + 1, duration: duration);
  }

  void _previousPage({Duration? duration}) {
    if (_currentPage <= 0) return;
    _animateToPage(_currentPage - 1, duration: duration);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx > 0) {
          _previousPage();
        } else {
          _nextPage();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.itemBuilder(context, _targetPage),
          if (_controller.isAnimating || _animation.value > 0)
            Positioned.fill(
              child: ClipRect(
                clipper: _CoverClipper(
                  progress: _animation.value,
                  isForward: _isForward,
                ),
                child: widget.itemBuilder(context, _currentPage),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverClipper extends CustomClipper<Rect> {
  final double progress;
  final bool isForward;

  _CoverClipper({
    required this.progress,
    required this.isForward,
  });

  @override
  Rect getClip(Size size) {
    if (isForward) {
      final clipWidth = size.width * (1 - progress);
      return Rect.fromLTWH(0, 0, clipWidth, size.height);
    } else {
      final clipStart = size.width * progress;
      return Rect.fromLTWH(clipStart, 0, size.width - clipStart, size.height);
    }
  }

  @override
  bool shouldReclip(covariant _CoverClipper oldClipper) {
    return progress != oldClipper.progress || isForward != oldClipper.isForward;
  }
}
