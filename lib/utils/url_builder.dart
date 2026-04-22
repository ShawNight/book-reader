/// URL 构建工具类
/// 统一处理书源的 URL 模板替换和安全验证
class UrlBuilder {
  /// 从 URL 模板构建实际 URL
  /// [template] - URL 模板，支持 {{keyword}}, {{page}}, {{pageCount}} 等变量
  /// [params] - 替换参数
  static String build(String template, {
    String? keyword,
    int? page,
    int? pageCount,
    Map<String, String>? customParams,
  }) {
    var result = template;

    // 替换关键字（支持多种变量名）
    if (keyword != null) {
      final encodedKeyword = Uri.encodeComponent(keyword);
      result = result.replaceAll('{{keyword}}', encodedKeyword);
      result = result.replaceAll('{{Keyword}}', encodedKeyword);
      result = result.replaceAll('{{key}}', encodedKeyword);
      result = result.replaceAll('{{Key}}', encodedKeyword);
      result = result.replaceAll('{{keywordEncoded}}', encodedKeyword);
    }

    // 替换页码（从 0 开始）
    if (page != null) {
      result = result.replaceAll('{{page}}', page.toString());
      result = result.replaceAll('{{pageNum}}', page.toString());
    }

    // 替换每页数量
    if (pageCount != null) {
      result = result.replaceAll('{{pageCount}}', pageCount.toString());
      result = result.replaceAll('{{pageSize}}', pageCount.toString());
    }

    // 替换自定义参数
    if (customParams != null) {
      for (final entry in customParams.entries) {
        result = result.replaceAll('{{${entry.key}}}', Uri.encodeComponent(entry.value));
      }
    }

    return result;
  }

  /// 验证 URL 安全性
  /// 防止 javascript:, data:, vbscript: 等危险协议
  static bool isSafeUrl(String url) {
    if (url.isEmpty) return false;

    final lowerUrl = url.toLowerCase().trim();

    // 检查危险协议
    final dangerousProtocols = [
      'javascript:',
      'data:',
      'vbscript:',
      'file:',
      'blob:',
      'about:',
    ];

    for (final protocol in dangerousProtocols) {
      if (lowerUrl.startsWith(protocol)) {
        return false;
      }
    }

    // 检查是否以 // 开头（协议相对 URL）
    if (lowerUrl.startsWith('//')) {
      return false;
    }

    return true;
  }

  /// 从 URL 中提取基础域名
  static String? getBaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        return '${uri.scheme}://${uri.host}';
      }
    } catch (e) {
      // 解析失败
    }
    return null;
  }

  /// 构建搜索 URL
  /// 如果模板中没有关键字变量，则将关键字追加到 URL 末尾
  static String buildSearchUrl(String template, {
    String? keyword,
    int? page,
    int? pageCount,
    Map<String, String>? customParams,
  }) {
    var result = template;

    // 先替换页码变量
    if (page != null) {
      result = result.replaceAll('{{page}}', page.toString());
      result = result.replaceAll('{{pageNum}}', page.toString());
    }
    if (pageCount != null) {
      result = result.replaceAll('{{pageCount}}', pageCount.toString());
      result = result.replaceAll('{{pageSize}}', pageCount.toString());
    }

    // 检查是否有关键字变量
    final hasKeywordVar = result.contains('{{keyword}}') ||
        result.contains('{{Keyword}}') ||
        result.contains('{{key}}') ||
        result.contains('{{Key}}');

    if (keyword != null) {
      final encodedKeyword = Uri.encodeComponent(keyword);
      if (hasKeywordVar) {
        // 有变量，替换
        result = result.replaceAll('{{keyword}}', encodedKeyword);
        result = result.replaceAll('{{Keyword}}', encodedKeyword);
        result = result.replaceAll('{{key}}', encodedKeyword);
        result = result.replaceAll('{{Key}}', encodedKeyword);
      } else {
        // 无变量，追加到末尾
        result = '$result$encodedKeyword';
      }
    }

    // 替换自定义参数
    if (customParams != null) {
      for (final entry in customParams.entries) {
        result = result.replaceAll('{{${entry.key}}}', Uri.encodeComponent(entry.value));
      }
    }

    return result;
  }

  /// 验证 URL 格式是否合法
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      // 必须有 scheme 和 host
      return uri.hasScheme && uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
