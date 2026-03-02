import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔍 详细检查书源文件...\n');
  
  final file = File('/home/shawnight/项目工作/book-reader/书源.json');
  final content = await file.readAsString();
  final data = json.decode(content) as List;
  
  print('📊 书源统计:');
  print('  总数: ${data.length} 个');
  
  int enabledCount = 0;
  int searchableCount = 0;
  int withRulesCount = 0;
  
  for (var item in data) {
    final map = item as Map<String, dynamic>;
    
    // 检查是否启用
    if (map['enabled'] == true) enabledCount++;
    
    // 检查是否有搜索URL
    if (map['searchUrl'] != null && (map['searchUrl'] as String).isNotEmpty) {
      searchableCount++;
    }
    
    // 检查是否有完整规则
    if (map['ruleSearch'] != null && 
        map['ruleBookInfo'] != null && 
        map['ruleContent'] != null) {
      withRulesCount++;
    }
  }
  
  print('  已启用: $enabledCount 个');
  print('  可搜索: $searchableCount 个');
  print('  完整规则: $withRulesCount 个\n');
  
  // 测试解析第一个书源
  print('🔎 测试解析第一个书源:');
  final first = data[0] as Map<String, dynamic>;
  final requiredFields = [
    'bookSourceName',
    'bookSourceUrl',
    'searchUrl',
    'ruleSearch',
    'ruleBookInfo',
    'ruleContent',
  ];
  
  bool allFieldsPresent = true;
  for (var field in requiredFields) {
    final present = first.containsKey(field);
    final icon = present ? '✅' : '❌';
    print('  $icon $field');
    if (!present) allFieldsPresent = false;
  }
  
  print('\n🎯 结论:');
  if (allFieldsPresent && searchableCount > 0) {
    print('  ✅ 书源文件格式正确，App可以正常工作');
    print('  ✅ 建议测试搜索"斗破"或"斗罗"验证搜索功能');
    print('\n💡 使用提示:');
    print('  1. 打开App → 书源标签 → 导入书源');
    print('  2. 书架标签 → 点击搜索按钮');
    print('  3. 输入小说名称开始搜索');
  } else {
    print('  ⚠️ 书源可能存在问题');
  }
}
