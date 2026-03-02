import 'dart:async';

import 'package:flutter/material.dart';

import '../models/book_source.dart';
import '../models/source_test_result.dart';
import '../services/book_source_service.dart';
import '../services/source_test_service.dart';

/// 书源净化筛选类型
enum PurifyFilterType {
  all,
  valid,
  invalid,
  pending,
}

/// 书源净化界面
class SourcePurifyScreen extends StatefulWidget {
  final List<BookSource> sources;

  const SourcePurifyScreen({
    super.key,
    required this.sources,
  });

  @override
  State<SourcePurifyScreen> createState() => _SourcePurifyScreenState();
}

class _SourcePurifyScreenState extends State<SourcePurifyScreen> {
  final SourceTestService _testService = SourceTestService();
  final BookSourceService _sourceService = BookSourceService();

  /// 测试结果列表
  List<SourceTestResult> _results = [];

  /// 当前筛选类型
  PurifyFilterType _filterType = PurifyFilterType.all;

  /// 是否正在测试
  bool _isTesting = false;

  /// 已完成数量
  int _completed = 0;

  /// 当前测试的书源名称
  String? _currentSourceName;

  /// 流订阅
  StreamSubscription<SourceTestProgress>? _subscription;

  @override
  void initState() {
    super.initState();
    // 初始化所有书源为待测试状态
    _results = widget.sources
        .map((source) => SourceTestResult(
              source: source,
              status: SourceTestStatus.pending,
            ))
        .toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _testService.cancelTest();
    super.dispose();
  }

  /// 开始测试
  void _startTest() {
    if (_isTesting) return;

    setState(() {
      _isTesting = true;
      _completed = 0;
      _currentSourceName = null;
      // 重置所有状态为待测试
      _results = widget.sources
          .map((source) => SourceTestResult(
                source: source,
                status: SourceTestStatus.pending,
              ))
          .toList();
    });

    _subscription = _testService.testSourcesStream(widget.sources).listen(
      (progress) {
        if (mounted) {
          setState(() {
            _completed = progress.completed;
            _currentSourceName = progress.currentSourceName;
            if (progress.lastResult != null) {
              // 更新对应书源的结果
              final index = _results.indexWhere(
                (r) => r.source.bookSourceUrl == progress.lastResult!.source.bookSourceUrl,
              );
              if (index >= 0) {
                _results[index] = progress.lastResult!;
              }
            }
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isTesting = false;
            _currentSourceName = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isTesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('测试出错：$error')),
          );
        }
      },
    );
  }

  /// 取消测试
  void _cancelTest() {
    _testService.cancelTest();
    _subscription?.cancel();
    setState(() {
      _isTesting = false;
      _currentSourceName = null;
    });
  }

  /// 净化无效书源
  Future<void> _purifyInvalidSources() async {
    final invalidSources = _results
        .where((r) => r.status != SourceTestStatus.success &&
                      r.status != SourceTestStatus.pending &&
                      r.status != SourceTestStatus.testing)
        .toList();

    if (invalidSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有无效书源需要删除')),
      );
      return;
    }

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认净化'),
        content: Text('将删除 ${invalidSources.length} 个无效书源，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 执行删除
    final urls = invalidSources.map((r) => r.source.bookSourceUrl).toList();
    final removedCount = await _sourceService.removeBookSources(urls);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $removedCount 个无效书源')),
      );
      // 返回上一页并刷新
      Navigator.pop(context, true);
    }
  }

  /// 获取筛选后的结果
  List<SourceTestResult> get _filteredResults {
    switch (_filterType) {
      case PurifyFilterType.valid:
        return _results.where((r) => r.isValid).toList();
      case PurifyFilterType.invalid:
        return _results.where((r) =>
          r.status == SourceTestStatus.failed ||
          r.status == SourceTestStatus.timeout
        ).toList();
      case PurifyFilterType.pending:
        return _results.where((r) =>
          r.status == SourceTestStatus.pending ||
          r.status == SourceTestStatus.testing
        ).toList();
      case PurifyFilterType.all:
      default:
        return _results;
    }
  }

  /// 获取统计信息
  Map<String, int> get _statistics {
    int valid = 0;
    int invalid = 0;
    int pending = 0;

    for (final result in _results) {
      switch (result.status) {
        case SourceTestStatus.success:
          valid++;
          break;
        case SourceTestStatus.failed:
        case SourceTestStatus.timeout:
          invalid++;
          break;
        case SourceTestStatus.pending:
        case SourceTestStatus.testing:
          pending++;
          break;
      }
    }

    return {
      'valid': valid,
      'invalid': invalid,
      'pending': pending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;
    final total = widget.sources.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源净化'),
        actions: [
          if (!_isTesting && stats['invalid']! > 0)
            TextButton.icon(
              onPressed: _purifyInvalidSources,
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              label: const Text('净化', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 进度区域
          _buildProgressArea(stats, total),

          // 筛选器
          _buildFilterChips(stats),

          // 列表
          Expanded(
            child: _buildResultList(),
          ),
        ],
      ),
      floatingActionButton: _isTesting
          ? FloatingActionButton.extended(
              onPressed: _cancelTest,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.stop),
              label: const Text('取消测试'),
            )
          : FloatingActionButton.extended(
              onPressed: _startTest,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始测试'),
            ),
    );
  }

  /// 构建进度区域
  Widget _buildProgressArea(Map<String, int> stats, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          // 统计行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('总计', total, Colors.grey),
              _buildStatItem('有效', stats['valid']!, Colors.green),
              _buildStatItem('无效', stats['invalid']!, Colors.red),
              _buildStatItem('待测', stats['pending']!, Colors.orange),
            ],
          ),

          const SizedBox(height: 12),

          // 进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '进度: $_completed / $total',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${total > 0 ? ((_completed / total) * 100).toStringAsFixed(0) : 0}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: total > 0 ? _completed / total : 0,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),

          // 当前测试的书源
          if (_currentSourceName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '正在测试: $_currentSourceName',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建筛选器
  Widget _buildFilterChips(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('全部', PurifyFilterType.all, _results.length),
            const SizedBox(width: 8),
            _buildFilterChip('有效', PurifyFilterType.valid, stats['valid']!),
            const SizedBox(width: 8),
            _buildFilterChip('无效', PurifyFilterType.invalid, stats['invalid']!),
            const SizedBox(width: 8),
            _buildFilterChip('待测试', PurifyFilterType.pending, stats['pending']!),
          ],
        ),
      ),
    );
  }

  /// 构建筛选芯片
  Widget _buildFilterChip(String label, PurifyFilterType type, int count) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterType = type;
        });
      },
    );
  }

  /// 构建结果列表
  Widget _buildResultList() {
    final filtered = _filteredResults;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filterType == PurifyFilterType.all
                  ? Icons.source
                  : Icons.filter_list,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _filterType == PurifyFilterType.all
                  ? '暂无书源'
                  : '没有符合条件的结果',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final result = filtered[index];
        return _buildResultItem(result);
      },
    );
  }

  /// 构建结果项
  Widget _buildResultItem(SourceTestResult result) {
    final (icon, color, statusText) = _getStatusDisplay(result.status);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(result.source.bookSourceName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.source.bookSourceUrl,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ),
              if (result.responseTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  '耗时: ${result.responseTime!.inMilliseconds}ms',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
              if (result.resultCount != null && result.isValid) ...[
                const SizedBox(width: 8),
                Text(
                  '结果: ${result.resultCount}条',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
          if (result.errorMessage != null && !result.isValid) ...[
            const SizedBox(height: 2),
            Text(
              '错误: ${result.errorMessage}',
              style: TextStyle(fontSize: 11, color: Colors.red[400]),
            ),
          ],
        ],
      ),
      isThreeLine: result.errorMessage != null && !result.isValid,
    );
  }

  /// 获取状态显示
  (IconData, Color, String) _getStatusDisplay(SourceTestStatus status) {
    switch (status) {
      case SourceTestStatus.pending:
        return (Icons.hourglass_empty, Colors.grey, '待测试');
      case SourceTestStatus.testing:
        return (Icons.sync, Colors.blue, '测试中');
      case SourceTestStatus.success:
        return (Icons.check_circle, Colors.green, '有效');
      case SourceTestStatus.failed:
        return (Icons.cancel, Colors.red, '失败');
      case SourceTestStatus.timeout:
        return (Icons.schedule, Colors.orange, '超时');
    }
  }
}
