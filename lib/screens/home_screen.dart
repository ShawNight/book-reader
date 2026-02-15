import 'package:flutter/material.dart';

/// 首页 - 书架页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _BookshelfPage(),
          _BookSourcePage(),
          _SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.source),
            label: '书源',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 书架页面
class _BookshelfPage extends StatelessWidget {
  const _BookshelfPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 实现搜索功能
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('书架为空，请先导入书源'),
      ),
    );
  }
}

/// 书源管理页面
class _BookSourcePage extends StatelessWidget {
  const _BookSourcePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: 实现导入书源功能
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('暂无书源，点击右上角导入'),
      ),
    );
  }
}

/// 设置页面
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('主题模式'),
            subtitle: const Text('跟随系统'),
            onTap: () {
              // TODO: 实现主题切换
            },
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: const Text('字体大小'),
            subtitle: const Text('中'),
            onTap: () {
              // TODO: 实现字体大小设置
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            subtitle: const Text('YueDu Flutter v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '悦读',
                applicationVersion: '1.0.0',
                applicationLegalese: '开源阅读器',
              );
            },
          ),
        ],
      ),
    );
  }
}
