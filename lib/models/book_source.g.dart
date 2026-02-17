// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookSource _$BookSourceFromJson(Map<String, dynamic> json) => BookSource(
      bookSourceName: json['bookSourceName'] as String,
      bookSourceUrl: json['bookSourceUrl'] as String,
      bookSourceGroup: json['bookSourceGroup'] as String?,
      bookSourceComment: json['bookSourceComment'] as String?,
      customOrder: json['customOrder'] as int?,
      enabled: json['enabled'] as bool?,
      enabledExplore: json['enabledExplore'] as bool?,
      searchUrl: json['searchUrl'] as String?,
      ruleSearch: json['ruleSearch'] == null
          ? null
          : RuleSearch.fromJson(
              json['ruleSearch'] as Map<String, dynamic>),
      ruleBookInfo: json['ruleBookInfo'] == null
          ? null
          : RuleBookInfo.fromJson(
              json['ruleBookInfo'] as Map<String, dynamic>),
      ruleToc: json['ruleToc'] == null
          ? null
          : RuleToc.fromJson(json['ruleToc'] as Map<String, dynamic>),
      ruleContent: json['ruleContent'] == null
          ? null
          : RuleContent.fromJson(
              json['ruleContent'] as Map<String, dynamic>),
      exploreUrl: json['exploreUrl'] as String?,
      header: json['header'] as String?,
      concurrentRate: json['concurrentRate'] as String?,
    );

Map<String, dynamic> _$BookSourceToJson(BookSource instance) {
  final val = <String, dynamic>{
    'bookSourceName': instance.bookSourceName,
    'bookSourceUrl': instance.bookSourceUrl,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('bookSourceGroup', instance.bookSourceGroup);
  writeNotNull('bookSourceComment', instance.bookSourceComment);
  writeNotNull('customOrder', instance.customOrder);
  writeNotNull('enabled', instance.enabled);
  writeNotNull('enabledExplore', instance.enabledExplore);
  writeNotNull('searchUrl', instance.searchUrl);
  writeNotNull('ruleSearch', instance.ruleSearch?.toJson());
  writeNotNull('ruleBookInfo', instance.ruleBookInfo?.toJson());
  writeNotNull('ruleToc', instance.ruleToc?.toJson());
  writeNotNull('ruleContent', instance.ruleContent?.toJson());
  writeNotNull('exploreUrl', instance.exploreUrl);
  writeNotNull('header', instance.header);
  writeNotNull('concurrentRate', instance.concurrentRate);

  return val;
}

RuleSearch _$RuleSearchFromJson(Map<String, dynamic> json) => RuleSearch(
      checkKeyWord: json['checkKeyWord'] as String?,
      bookList: json['bookList'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      updateTime: json['updateTime'] as String?,
      bookUrl: json['bookUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      wordCount: json['wordCount'] as String?,
      tocUrl: json['tocUrl'] as String?,
    );

Map<String, dynamic> _$RuleSearchToJson(RuleSearch instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('checkKeyWord', instance.checkKeyWord);
  writeNotNull('bookList', instance.bookList);
  writeNotNull('name', instance.name);
  writeNotNull('author', instance.author);
  writeNotNull('intro', instance.intro);
  writeNotNull('kind', instance.kind);
  writeNotNull('lastChapter', instance.lastChapter);
  writeNotNull('updateTime', instance.updateTime);
  writeNotNull('bookUrl', instance.bookUrl);
  writeNotNull('coverUrl', instance.coverUrl);
  writeNotNull('wordCount', instance.wordCount);
  writeNotNull('tocUrl', instance.tocUrl);

  return val;
}

RuleBookInfo _$RuleBookInfoFromJson(Map<String, dynamic> json) => RuleBookInfo(
      init: json['init'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      updateTime: json['updateTime'] as String?,
      coverUrl: json['coverUrl'] as String?,
      tocUrl: json['tocUrl'] as String?,
      wordCount: json['wordCount'] as String?,
      canReName: json['canReName'] as String?,
    );

Map<String, dynamic> _$RuleBookInfoToJson(RuleBookInfo instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('init', instance.init);
  writeNotNull('name', instance.name);
  writeNotNull('author', instance.author);
  writeNotNull('intro', instance.intro);
  writeNotNull('kind', instance.kind);
  writeNotNull('lastChapter', instance.lastChapter);
  writeNotNull('updateTime', instance.updateTime);
  writeNotNull('coverUrl', instance.coverUrl);
  writeNotNull('tocUrl', instance.tocUrl);
  writeNotNull('wordCount', instance.wordCount);
  writeNotNull('canReName', instance.canReName);

  return val;
}

RuleToc _$RuleTocFromJson(Map<String, dynamic> json) => RuleToc(
      chapterList: json['chapterList'] as String?,
      chapterName: json['chapterName'] as String?,
      chapterUrl: json['chapterUrl'] as String?,
      isVip: json['isVip'] as String?,
      isPay: json['isPay'] as String?,
      updateTime: json['updateTime'] as String?,
      nextTocUrl: json['nextTocUrl'] as String?,
    );

Map<String, dynamic> _$RuleTocToJson(RuleToc instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('chapterList', instance.chapterList);
  writeNotNull('chapterName', instance.chapterName);
  writeNotNull('chapterUrl', instance.chapterUrl);
  writeNotNull('isVip', instance.isVip);
  writeNotNull('isPay', instance.isPay);
  writeNotNull('updateTime', instance.updateTime);
  writeNotNull('nextTocUrl', instance.nextTocUrl);

  return val;
}

RuleContent _$RuleContentFromJson(Map<String, dynamic> json) => RuleContent(
      content: json['content'] as String?,
      nextContentUrl: json['nextContentUrl'] as String?,
      webJs: json['webJs'] as String?,
      sourceRegex: json['sourceRegex'] as String?,
      replaceRegex: json['replaceRegex'] as String?,
      imageStyle: json['imageStyle'] as String?,
      payAction: json['payAction'] as String?,
    );

Map<String, dynamic> _$RuleContentToJson(RuleContent instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('content', instance.content);
  writeNotNull('nextContentUrl', instance.nextContentUrl);
  writeNotNull('webJs', instance.webJs);
  writeNotNull('sourceRegex', instance.sourceRegex);
  writeNotNull('replaceRegex', instance.replaceRegex);
  writeNotNull('imageStyle', instance.imageStyle);
  writeNotNull('payAction', instance.payAction);

  return val;
}
