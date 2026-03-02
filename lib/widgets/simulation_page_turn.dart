import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页控制器
class SimulationPageTurnController {
  _SimulationPageTurnState? _state;

  void _attach(_SimulationPageTurnState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// 跳转到指定页面
  void animateToPage(int page, {Duration duration = const Duration(milliseconds: 600)}) {
    _state?._animateToPage(page, duration: duration);
  }

  /// 下一页
  void nextPage({Duration duration = const Duration(milliseconds: 600)}) {
    _state?._nextPage(duration: duration);
  }

  /// 上一页
  void previousPage({Duration duration = const Duration(milliseconds: 600)}) {
    _state?._previousPage(duration: duration);
  }

  /// 跳转到指定页面（无动画）
  void jumpToPage(int page) {
    _state?._jumpToPage(page);
  }

  /// 获取当前页码
  int get currentPage => _state?._currentPage ?? 0;
}

/// 仿真翻页视图
class SimulationPageTurn extends StatefulWidget {
  /// 页面构建器
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 总页数
  final int itemCount;

  /// 控制器
  final SimulationPageTurnController? controller;

  /// 当前页面变化回调
  final ValueChanged<int>? onPageChanged;

  /// 背景色（用于页面背面）
  final Color? backgroundColor;

  const SimulationPageTurn({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.controller,
    this.onPageChanged,
    this.backgroundColor,
  });

  @override
  State<SimulationPageTurn> createState() => _SimulationPageTurnState();
}

class _SimulationPageTurnState extends State<SimulationPageTurn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int _currentPage = 0;
  int _targetPage = 0;
  bool _isForward = true;

  double _dragStartX = 0;
  double _dragDelta = 0;
  bool _isDragging = false;

  // 页面截图缓存
  final Map<int, ui.Image> _pageImages = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
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
    _clearCachedImages();
    super.dispose();
  }

  void _clearCachedImages() {
    for (final image in _pageImages.values) {
      image.dispose();
    }
    _pageImages.clear();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPage = _targetPage;
      });
      _controller.reset();
    } else if (status == AnimationStatus.dismissed) {
      setState(() {
        _dragDelta = 0;
      });
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
      _dragDelta = 0;
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

  void _handleDragStart(DragStartDetails details) {
    if (_controller.isAnimating) return;

    _dragStartX = details.localPosition.dx;
    _dragDelta = 0;
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _controller.isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _dragDelta = (details.localPosition.dx - _dragStartX) / screenWidth;

      _isForward = _dragDelta < 0;

      if (_isForward && _currentPage + 1 >= widget.itemCount) {
        _dragDelta = 0;
      } else if (!_isForward && _currentPage <= 0) {
        _dragDelta = 0;
      }

      _dragDelta = _dragDelta.clamp(-1.0, 1.0);
      _controller.value = _dragDelta.abs();
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    const threshold = 0.2;
    final velocity = details.velocity.pixelsPerSecond.dx;

    final shouldComplete = _dragDelta.abs() > threshold ||
        (velocity.abs() > 500 && _dragDelta.abs() > 0.05);

    if (shouldComplete) {
      if (_isForward && _currentPage + 1 < widget.itemCount) {
        _targetPage = _currentPage + 1;
        _controller.forward();
        widget.onPageChanged?.call(_targetPage);
      } else if (!_isForward && _currentPage > 0) {
        _targetPage = _currentPage - 1;
        _controller.forward();
        widget.onPageChanged?.call(_targetPage);
      } else {
        _controller.reverse();
      }
    } else {
      _controller.reverse();
    }

    _dragDelta = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底层页面
            _buildBottomPage(),

            // 当前页面（带翻页效果）
            _buildCurrentPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPage() {
    // 根据翻页方向决定显示哪个页面
    int bottomPageIndex;
    if (_controller.value > 0 || _dragDelta != 0) {
      bottomPageIndex = _isForward ? _currentPage + 1 : _currentPage - 1;
    } else {
      bottomPageIndex = _currentPage;
    }

    if (bottomPageIndex < 0 || bottomPageIndex >= widget.itemCount) {
      bottomPageIndex = _currentPage;
    }

    return Positioned.fill(
      child: widget.itemBuilder(context, bottomPageIndex),
    );
  }

  Widget _buildCurrentPage() {
    final progress = _controller.value > 0 ? _animation.value : _dragDelta.abs();

    if (progress == 0) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: CustomPaint(
        painter: _SimulationPagePainter(
          progress: progress,
          isForward: _isForward,
          backgroundColor: widget.backgroundColor ?? Colors.white,
        ),
        child: ClipRect(
          clipper: _PageClipper(
            progress: progress,
            isForward: _isForward,
          ),
          child: widget.itemBuilder(context, _currentPage),
        ),
      ),
    );
  }
}

/// 仿真翻页绘制器 - 绘制阴影和翻页效果
class _SimulationPagePainter extends CustomPainter {
  final double progress;
  final bool isForward;
  final Color backgroundColor;

  _SimulationPagePainter({
    required this.progress,
    required this.isForward,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final pageWidth = size.width;

    // 计算翻页位置
    final turnX = isForward
        ? pageWidth * (1 - progress)
        : pageWidth * progress;

    // 绘制页面阴影
    _drawPageShadow(canvas, size, turnX);

    // 绘制翻页边缘效果
    _drawPageEdge(canvas, size, turnX);

    // 绘制页面背面（可选）
    _drawPageBack(canvas, size, turnX);
  }

  void _drawPageShadow(Canvas canvas, Size size, double turnX) {
    final pageHeight = size.height;

    // 页面阴影 - 使用渐变
    final shadowWidth = 40.0 * progress;
    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(turnX, 0),
        Offset(turnX + shadowWidth, 0),
        [
          Colors.black.withOpacity(0.4 * progress),
          Colors.black.withOpacity(0.1 * progress),
          Colors.transparent,
        ],
      );

    final shadowRect = Rect.fromLTWH(
      turnX,
      0,
      shadowWidth,
      pageHeight,
    );
    canvas.drawRect(shadowRect, shadowPaint);

    // 边缘阴影
    final edgeShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3 * progress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final edgePath = Path()
      ..moveTo(turnX, 0)
      ..lineTo(turnX + 3, 0)
      ..lineTo(turnX + 3, pageHeight)
      ..lineTo(turnX, pageHeight);

    canvas.drawPath(edgePath, edgeShadowPaint);
  }

  void _drawPageEdge(Canvas canvas, Size size, double turnX) {
    final pageHeight = size.height;

    // 绘制页面边缘的高光效果
    final edgeHighlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(turnX, 0),
        Offset(turnX + 15, 0),
        [
          backgroundColor.withOpacity(0.9),
          backgroundColor,
        ],
      );

    final edgeRect = Rect.fromLTWH(turnX, 0, 15, pageHeight);
    canvas.drawRect(edgeRect, edgeHighlightPaint);

    // 绘制折叠效果
    final foldPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(turnX, 0),
        Offset(turnX + 8, 0),
        [
          backgroundColor.withOpacity(0.7 * progress),
          backgroundColor,
        ],
      );

    final foldPath = Path()
      ..moveTo(turnX, 0)
      ..quadraticBezierTo(
        turnX + 4,
        pageHeight / 2,
        turnX,
        pageHeight,
      )
      ..lineTo(turnX + 8, pageHeight)
      ..quadraticBezierTo(
        turnX + 4,
        pageHeight / 2,
        turnX + 8,
        0,
      )
      ..close();

    canvas.drawPath(foldPath, foldPaint);
  }

  void _drawPageBack(Canvas canvas, Size size, double turnX) {
    // 简化版本：不绘制复杂的背面效果
    // 只绘制一个简单的半透明遮罩表示页面厚度
    final pageHeight = size.height;
    final backPaint = Paint()
      ..color = backgroundColor.withOpacity(0.3 * progress);

    final backRect = Rect.fromLTWH(
      isForward ? turnX - 5 : turnX,
      0,
      5,
      pageHeight,
    );
    canvas.drawRect(backRect, backPaint);
  }

  @override
  bool shouldRepaint(covariant _SimulationPagePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        isForward != oldDelegate.isForward ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

/// 页面裁剪器 - 裁剪当前显示的页面部分
class _PageClipper extends CustomClipper<Rect> {
  final double progress;
  final bool isForward;

  _PageClipper({
    required this.progress,
    required this.isForward,
  });

  @override
  Rect getClip(Size size) {
    final pageWidth = size.width;
    final pageHeight = size.height;

    if (isForward) {
      // 向后翻页：显示左侧部分
      final clipWidth = pageWidth * (1 - progress);
      return Rect.fromLTWH(0, 0, clipWidth, pageHeight);
    } else {
      // 向前翻页：显示右侧部分
      final clipStart = pageWidth * progress;
      return Rect.fromLTWH(clipStart, 0, pageWidth - clipStart, pageHeight);
    }
  }

  @override
  bool shouldReclip(covariant _PageClipper oldClipper) {
    return progress != oldClipper.progress || isForward != oldClipper.isForward;
  }
}
