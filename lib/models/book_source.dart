import 'package:json_annotation/json_annotation.dart';

part 'book_source.g.dart';

/// 书源模型
/// 严格兼容 JSON 书源格式
@JsonSerializable(explicitToJson: true)
class BookSource {
  final String bookSourceName;
  final String bookSourceUrl;
  final String? bookSourceGroup;
  final String? bookSourceComment;
  final int? customOrder;
  final bool? enabled;
  final bool? enabledExplore;
  final String? searchUrl;
  final RuleSearch? ruleSearch;
  final RuleBookInfo? ruleBookInfo;
  final RuleToc? ruleToc;
  final RuleContent? ruleContent;
  final String? exploreUrl;
  final String? header;
  final String? concurrentRate;

  BookSource({
    required this.bookSourceName,
    required this.bookSourceUrl,
    this.bookSourceGroup,
    this.bookSourceComment,
    this.customOrder,
    this.enabled,
    this.enabledExplore,
    this.searchUrl,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.exploreUrl,
    this.header,
    this.concurrentRate,
  });

  factory BookSource.fromJson(Map<String, dynamic> json) =>
      _$BookSourceFromJson(json);

  Map<String, dynamic> toJson() => _$BookSourceToJson(this);
}

/// 搜索规则
@JsonSerializable(explicitToJson: true)
class RuleSearch {
  final String? checkKeyWord;
  final String? bookList;
  final String? name;
  final String? author;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? bookUrl;
  final String? coverUrl;
  final String? wordCount;
  final String? tocUrl;

  RuleSearch({
    this.checkKeyWord,
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
    this.tocUrl,
  });

  factory RuleSearch.fromJson(Map<String, dynamic> json) =>
      _$RuleSearchFromJson(json);

  Map<String, dynamic> toJson() => _$RuleSearchToJson(this);
}

/// 书籍信息规则
@JsonSerializable(explicitToJson: true)
class RuleBookInfo {
  final String? init;
  final String? name;
  final String? author;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? coverUrl;
  final String? tocUrl;
  final String? wordCount;
  final String? canReName;

  RuleBookInfo({
    this.init,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.coverUrl,
    this.tocUrl,
    this.wordCount,
    this.canReName,
  });

  factory RuleBookInfo.fromJson(Map<String, dynamic> json) =>
      _$RuleBookInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RuleBookInfoToJson(this);
}

/// 目录规则
@JsonSerializable(explicitToJson: true)
class RuleToc {
  final String? chapterList;
  final String? chapterName;
  final String? chapterUrl;
  final String? isVip;
  final String? isPay;
  final String? updateTime;
  final String? nextTocUrl;

  RuleToc({
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.isVip,
    this.isPay,
    this.updateTime,
    this.nextTocUrl,
  });

  factory RuleToc.fromJson(Map<String, dynamic> json) =>
      _$RuleTocFromJson(json);

  Map<String, dynamic> toJson() => _$RuleTocToJson(this);
}

/// 内容规则
@JsonSerializable(explicitToJson: true)
class RuleContent {
  final String? content;
  final String? nextContentUrl;
  final String? webJs;
  final String? sourceRegex;
  final String? replaceRegex;
  final String? imageStyle;
  final String? payAction;

  RuleContent({
    this.content,
    this.nextContentUrl,
    this.webJs,
    this.sourceRegex,
    this.replaceRegex,
    this.imageStyle,
    this.payAction,
  });

  factory RuleContent.fromJson(Map<String, dynamic> json) =>
      _$RuleContentFromJson(json);

  Map<String, dynamic> toJson() => _$RuleContentToJson(this);
}
