import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/wk_colors.dart';
import '../contacts/contacts_page.dart';
import '../user/user_page.dart';
import 'conversation_list_page.dart';

/// 主页面（底部导航）
/// 基于 TangSengDaoDao 主界面结构复刻
class WKMainPage extends ConsumerStatefulWidget {
  const WKMainPage({super.key});

  @override
  ConsumerState<WKMainPage> createState() => _WKMainPageState();
}

class _WKMainPageState extends ConsumerState<WKMainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ConversationListPage(),
    WKContactsPage(),
    WKUserPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WKColors.homeBg,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: WKColors.white,
        selectedItemColor: WKColors.primary,
        unselectedItemColor: WKColors.color999,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: '会话',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: '通讯录',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// 通讯录页面包装器
class WKContactsPage extends StatelessWidget {
  const WKContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContactsPage();
  }
}

/// 用户中心页面包装器
class WKUserPage extends StatelessWidget {
  const WKUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserPage();
  }
}
