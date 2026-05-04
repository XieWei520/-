import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wukong_im_app/app/app.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/contacts/contacts_page.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/modules/conversation/main_page.dart';
import 'package:wukong_im_app/modules/home/home_shell_page.dart';
import 'package:wukong_im_app/modules/moments/moments_page.dart';
import 'package:wukong_im_app/modules/user/user_page.dart';

void main() {
  test('main shell pages compile', () {
    expect(const WuKongApp(), isA<Widget>());
    expect(const MainPage(), isA<Widget>());
    expect(const HomeShellPage(), isA<Widget>());
    expect(const ConversationListPage(), isA<Widget>());
    expect(const ContactsPage(), isA<Widget>());
    expect(const FavoritesPage(), isA<Widget>());
    expect(const MomentsPage(), isA<Widget>());
    expect(const UserPage(), isA<Widget>());
    expect(const NewFriendsPage(), isA<Widget>());
  });
}
