/// 共享的规则解析工具类
///
/// 提供书源规则解析的公共方法，供 SearchService 和 SourceTestService 共用。
class RuleParser {
  // 私有构造函数，防止实例化
  RuleParser._();

  /// 获取元素列表（支持 Legado 规则格式）
  ///
  /// 支持的规则格式:
  /// - `@CSS:selector` — 原生 CSS 选择器
  /// - `tag.xxx`, `class.xxx`, `id.xxx` — XPath-like 选择器
  /// - `children` — 直接子元素
  /// - 使用 `@` 分隔的多步链式选择
  static List<dynamic> getElements(dynamic root, String rule) {
    if (rule.isEmpty) return [root];

    final elements = <dynamic>[];
    String remainingRule = rule.trim();

    // 处理 @CSS: 前缀
    if (remainingRule.toLowerCase().startsWith('@css:')) {
      remainingRule = remainingRule.substring(5).trim();
      // 使用 querySelectorAll
      if (root != null) {
        elements.addAll(root.querySelectorAll(remainingRule));
      }
      return elements;
    }

    // 按 @ 分割规则
    final parts = remainingRule.split('@');
    List<dynamic> currentElements = [root];

    for (final part in parts) {
      final trimmedPart = part.trim();
      if (trimmedPart.isEmpty) continue;

      final nextElements = <dynamic>[];
      for (final element in currentElements) {
        nextElements.addAll(getElementsBySingleRule(element, trimmedPart));
      }
      currentElements = nextElements;

      if (currentElements.isEmpty) break;
    }

    return currentElements;
  }

  /// 单个规则获取元素
  static List<dynamic> getElementsBySingleRule(dynamic element, String rule) {
    if (rule.isEmpty) return [element];

    try {
      // 处理 tag.xxx 格式
      if (rule.startsWith('tag.')) {
        final tagName = rule.substring(4);
        return element.getElementsByTagName(tagName).toList();
      }

      // 处理 class.xxx 格式
      if (rule.startsWith('class.')) {
        final className = rule.substring(6);
        return element.getElementsByClassName(className).toList();
      }

      // 处理 id.xxx 格式
      if (rule.startsWith('id.')) {
        final id = rule.substring(3);
        final found = element.querySelector('#$id');
        return found != null ? [found] : [];
      }

      // 处理 children 格式
      if (rule == 'children') {
        return element.children.toList();
      }

      // 处理带索引的选择器
      final indexPattern = RegExp(r'^(.+?)([.!])(-?\d+)$');
      final indexMatch = indexPattern.firstMatch(rule);
      if (indexMatch != null) {
        final selector = indexMatch.group(1)!;
        final splitChar = indexMatch.group(2)!;
        final indexStr = indexMatch.group(3)!;
        final index = int.parse(indexStr);

        final elements = getElementsBySingleRule(element, selector);

        if (splitChar == '.') {
          // 选择模式
          if (index >= 0 && index < elements.length) {
            return [elements[index]];
          } else if (index < 0 && elements.length + index >= 0) {
            return [elements[elements.length + index]];
          }
        } else {
          // 排除模式 (!)
          if (index >= 0 && index < elements.length) {
            elements.removeAt(index);
          } else if (index < 0 && elements.length + index >= 0) {
            elements.removeAt(elements.length + index);
          }
          return elements;
        }
        return [];
      }

      // 处理 [index] 或 [start:end] 格式
      final bracketMatch = RegExp(r'^(.+?)\[([^\]]+)\]$').firstMatch(rule);
      if (bracketMatch != null) {
        final selector = bracketMatch.group(1)!;
        final indexExpr = bracketMatch.group(2)!;
        final elements = getElementsBySingleRule(element, selector);
        return selectElementsByIndex(elements, indexExpr);
      }

      // 默认使用 CSS 选择器
      return element.querySelectorAll(rule).toList();
    } catch (e) {
      return [];
    }
  }

  /// 根据索引表达式选择元素
  ///
  /// 支持单个索引、负索引以及 `[start:end:step]` 区间格式。
  static List<dynamic> selectElementsByIndex(
      List<dynamic> elements, String indexExpr) {
    if (elements.isEmpty) return [];

    // 单个索引
    final singleIndex = int.tryParse(indexExpr);
    if (singleIndex != null) {
      final idx =
          singleIndex >= 0 ? singleIndex : elements.length + singleIndex;
      if (idx >= 0 && idx < elements.length) {
        return [elements[idx]];
      }
      return [];
    }

    // 区间 [start:end] 或 [start:end:step]
    final rangeMatch =
        RegExp(r'^(-?\d*):(-?\d*)(?::(-?\d*))?$').firstMatch(indexExpr);
    if (rangeMatch != null) {
      int? start =
          rangeMatch.group(1)!.isNotEmpty ? int.parse(rangeMatch.group(1)!) : null;
      int? end =
          rangeMatch.group(2)!.isNotEmpty ? int.parse(rangeMatch.group(2)!) : null;
      int step = rangeMatch.group(3) != null && rangeMatch.group(3)!.isNotEmpty
          ? int.parse(rangeMatch.group(3)!)
          : 1;

      start = start != null ? (start >= 0 ? start : elements.length + start) : 0;
      end = end != null ? (end >= 0 ? end : elements.length + end) : elements.length - 1;

      start = start.clamp(0, elements.length - 1);
      end = end.clamp(0, elements.length - 1);

      final result = <dynamic>[];
      if (step > 0 && start <= end) {
        for (int i = start; i <= end; i += step) {
          if (i < elements.length) result.add(elements[i]);
        }
      } else if (step < 0 && start >= end) {
        for (int i = start; i >= end; i += step) {
          if (i >= 0 && i < elements.length) result.add(elements[i]);
        }
      }
      return result;
    }

    return elements;
  }

  /// 从 JSON 对象中获取值（支持 dot-notation 路径）
  static dynamic getJsonValue(dynamic json, String path) {
    if (path.isEmpty) return json;

    final parts = path.split('.');
    dynamic current = json;

    for (final part in parts) {
      if (part.isEmpty) continue;
      if (current is Map) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final index = int.parse(part);
        current = index < current.length ? current[index] : null;
      } else {
        return null;
      }
    }

    return current;
  }

  /// 清理 baseUrl，移除 `##` 或 `#` 后面的标记
  static String cleanBaseUrl(String url) {
    if (url.contains('##')) {
      return url.split('##')[0];
    } else if (url.contains('#')) {
      return url.split('#')[0];
    }
    return url;
  }

  /// 解析相对URL，将其拼接到 baseUrl 上
  /// [url] - 要解析的 URL
  /// [baseUrl] - 基础 URL
  /// 返回解析后的完整 URL
  static String resolveUrl(String url, String baseUrl) {
    // 安全检查：拒绝危险协议
    final lowerUrl = url.toLowerCase().trim();
    if (lowerUrl.startsWith('javascript:') ||
        lowerUrl.startsWith('data:') ||
        lowerUrl.startsWith('vbscript:') ||
        lowerUrl.startsWith('blob:') ||
        lowerUrl.startsWith('file:')) {
      return baseUrl; // 返回 baseUrl 作为安全替代
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final base = Uri.parse(baseUrl);
    if (url.startsWith('//')) {
      return '${base.scheme}:$url';
    } else if (url.startsWith('/')) {
      return '${base.scheme}://${base.host}$url';
    } else {
      final path = base.path.endsWith('/')
          ? base.path
          : base.path.substring(0, base.path.lastIndexOf('/') + 1);
      return '${base.scheme}://${base.host}$path$url';
    }
  }

  /// 解析 header 字符串
  ///
  /// 支持 JSON 格式 `{"key": "value"}` 和行格式 `Key: Value\n...`。
  static Map<String, String> parseHeader(String header) {
    final map = <String, String>{};
    final trimmed = header.trim();

    // 尝试解析为 JSON 格式
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final content = trimmed.substring(1, trimmed.length - 1).replaceAllMapped(
              RegExp(r'"([^"]+)"\s*:\s*"([^"]*)"'),
              (match) => '${match.group(1)}:${match.group(2)}',
            );
        for (final pair in content.split(',')) {
          final kv = pair.split(':');
          if (kv.length >= 2) {
            final key = kv[0].trim().replaceAll('"', '');
            final value = kv.sublist(1).join(':').trim().replaceAll('"', '');
            if (key.isNotEmpty) {
              map[key] = value;
            }
          }
        }
        return map;
      } catch (e) {
        // JSON 解析失败，尝试行格式
      }
    }

    // 行格式: Key: Value
    for (final line in header.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        map[parts[0].trim()] = parts.sublist(1).join(':').trim();
      }
    }
    return map;
  }
}
