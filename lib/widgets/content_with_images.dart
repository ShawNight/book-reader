import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 内容片段类型
enum ContentSegmentType { text, image }

/// 内容片段
class ContentSegment {
  final ContentSegmentType type;
  final String content; // 文本内容或图片URL

  ContentSegment({required this.type, required this.content});
}

/// 支持图片的内容渲染组件
class ContentWithImages extends StatelessWidget {
  final String content;
  final TextStyle textStyle;
  final double paragraphSpacing;
  final double indentSize;
  final String? referer; // 防盗链 Referer
  final void Function(String imageUrl)? onImageTap; // 图片点击回调

  const ContentWithImages({
    super.key,
    required this.content,
    required this.textStyle,
    required this.paragraphSpacing,
    required this.indentSize,
    this.referer,
    this.onImageTap,
  });

  /// 解析内容为片段列表
  List<ContentSegment> _parseContent() {
    final segments = <ContentSegment>[];

    // 使用正则表达式匹配 <img> 标签
    final imgRegex = RegExp(r'<img\s+src="([^"]+)"\s*/?>', caseSensitive: false);
    final matches = imgRegex.allMatches(content);

    int lastEnd = 0;
    for (final match in matches) {
      // 添加图片前的文本
      if (match.start > lastEnd) {
        final text = content.substring(lastEnd, match.start).trim();
        if (text.isNotEmpty) {
          segments.add(ContentSegment(type: ContentSegmentType.text, content: text));
        }
      }

      // 添加图片
      final imageUrl = match.group(1);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        segments.add(ContentSegment(type: ContentSegmentType.image, content: imageUrl));
      }

      lastEnd = match.end;
    }

    // 添加最后剩余的文本
    if (lastEnd < content.length) {
      final text = content.substring(lastEnd).trim();
      if (text.isNotEmpty) {
        segments.add(ContentSegment(type: ContentSegmentType.text, content: text));
      }
    }

    // 如果没有找到任何片段，返回整个内容作为文本
    if (segments.isEmpty) {
      segments.add(ContentSegment(type: ContentSegmentType.text, content: content));
    }

    return segments;
  }

  /// 添加首行缩进
  String _addIndent(String paragraph) {
    if (indentSize <= 0) return paragraph;
    if (paragraph.startsWith('　') || paragraph.startsWith(' ')) return paragraph;
    final indent = '　' * indentSize.toInt();
    return indent + paragraph;
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseContent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment.type == ContentSegmentType.image) {
          return _buildImageWidget(segment.content);
        } else {
          return _buildTextWidget(segment.content);
        }
      }).toList(),
    );
  }

  /// 构建文本组件
  Widget _buildTextWidget(String text) {
    // 按段落分割（支持多种换行符）
    final paragraphs = text
        .split(RegExp(r'\n+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        return Padding(
          padding: EdgeInsets.only(bottom: paragraphSpacing),
          child: Text(
            _addIndent(paragraph.trim()),
            style: textStyle,
          ),
        );
      }).toList(),
    );
  }

  /// 构建图片组件
  Widget _buildImageWidget(String imageUrl) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: paragraphSpacing),
      child: GestureDetector(
        onTap: () => onImageTap?.call(imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.fitWidth,
            width: double.infinity,
            httpHeaders: referer != null ? {'Referer': referer!} : null,
            placeholder: (context, url) => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 80,
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey[600]),
                    const SizedBox(height: 4),
                    Text(
                      '图片加载失败',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
