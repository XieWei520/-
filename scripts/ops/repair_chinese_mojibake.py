from __future__ import annotations

import codecs
from pathlib import Path


def u(value: str) -> str:
    return codecs.decode(value, "unicode_escape")


def write_if_changed(path: Path, original: str, updated: str) -> bool:
    if updated == original:
        return False
    newline = "\r\n" if "\r\n" in original else "\n"
    path.write_text(updated, encoding="utf-8", newline=newline)
    return True


def replace_all(path: Path, replacements: dict[str, str]) -> bool:
    original = path.read_text(encoding="utf-8")
    updated = original
    for source, target in replacements.items():
        updated = updated.replace(u(source), target)
    return write_if_changed(path, original, updated)


def remove_between(path: Path, start: str, end: str, replacement: str) -> bool:
    original = path.read_text(encoding="utf-8")
    start_index = original.find(start)
    end_index = original.find(end, start_index + len(start)) if start_index != -1 else -1
    if start_index == -1 or end_index == -1:
        return False
    updated = original[:start_index] + replacement + original[end_index + len(end):]
    return write_if_changed(path, original, updated)


def repair_web_entrypoint_test() -> bool:
    path = Path("test/web_entrypoint_cache_cleanup_test.dart")
    original = path.read_text(encoding="utf-8")
    lines = original.splitlines()
    updated: list[str] = []
    replaced = False
    for line in lines:
        if line.strip().startswith("const mojibakeSnippets = <String>["):
            updated.extend(
                [
                    "    final mojibakeSnippets = <String>[",
                    "      String.fromCharCodes([0x6DC7, 0x2103, 0x4F05, 0x9A9E, 0x866B, 0x6F48]),",
                    "    ];",
                ]
            )
            replaced = True
            continue
        updated.append(line)
    if not replaced:
        return False
    newline = "\r\n" if "\r\n" in original else "\n"
    return write_if_changed(path, original, newline.join(updated) + newline)


def main() -> int:
    changed: list[str] = []

    replacements: dict[str, dict[str, str]] = {
        "lib/data/providers/channel_provider.dart": {
            r"\u7f07\u3087\u7c8d\u6dc7\u2103\u4f05Provider": "群信息 Provider",
            r"\u7f07\u3086\u579a\u935b\u6a3a\u57aa\u741b\u2252rovider": "群成员列表 Provider",
            r"\u93b4\u621d\u59de\u934f\u30e7\u6b91\u7f07\u3085\u57aa\u741b\u2252rovider": "我加入的群列表 Provider",
            r"\u9354\u72ba\u6d47\u7f07\u3085\u57aa\u741b?": "加载群列表",
            r"\u9352\u6d98\u7f13\u7f07\u3088\u4eb0": "创建群聊",
            r"\u95ab\u20ac\u9351\u8679\u5162\u9471?": "退出群聊",
            r"\u7459\uff46\u668e\u7f07\u3088\u4eb0": "解散群聊",
        },
        "lib/modules/juliang_monitor/juliang_monitor_center_page.dart": {
            r"\u93c6\u509b\u68e4\u93c9\u30e6\u7c2e": "暂无来源",
            r"\u95b0\u5d87\u7586": "配置",
        },
        "lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart": {
            r" ||\n      normalized == '[\u9365\u5267\u5896]'": "",
        },
        "lib/service/api/conversation_draft_api.dart": {
            r"\u935a\u5c7e\ue11e\u6d7c\u6c33\u763d extra \u6fb6\u8fab\u89e6": "同步会话 extra 失败",
            r"\u93c7\u5b58\u67ca\u6d7c\u6c33\u763d extra \u6fb6\u8fab\u89e6": "保存会话 extra 失败",
        },
        "lib/service/api/file_api.dart": {
            r"\u947e\u5cf0\u5f47\u6d93\u5a41\u7d36\u9366\u677f\u6f43\u6fb6\u8fab\u89e6": "获取上传地址失败",
            r"\u6d93\u5a41\u7d36\u93c2\u56e6\u6b22\u6fb6\u8fab\u89e6": "上传文件失败",
        },
        "lib/service/api/message_api.dart": {
            r"\u93be\u3085\u6d16\u5a11\u581f\u4f05\u6fb6\u8fab\u89e6": "撤回消息失败",
            r"\u9352\u72bb\u6ace\u5a11\u581f\u4f05\u6fb6\u8fab\u89e6": "删除消息失败",
            r"\u9359\u5c7d\u609c\u9352\u72bb\u6ace\u5a11\u581f\u4f05\u6fb6\u8fab\u89e6": "双向删除消息失败",
            r"\u93bc\u6ec5\u50a8\u5a11\u581f\u4f05\u6fb6\u8fab\u89e6": "搜索消息失败",
            r"\u9359\u6226\u20ac?typing \u6fb6\u8fab\u89e6": "发送输入状态失败",
            r"\u935a\u5c7e\ue11e\u5a11\u581f\u4f05 extra \u6fb6\u8fab\u89e6": "同步消息 extra 失败",
            r"message sync ack \u6fb6\u8fab\u89e6": "消息同步确认失败",
            r"\u5a13\u546f\u2516\u5a11\u581f\u4f05\u6fb6\u8fab\u89e6": "清空消息失败",
        },
        "lib/wukong_uikit/setting/about_page.dart": {
            r"\u7eef\u8364\u7cba\u95ab\u6c31\u7161": "系统通知",
        },
        "test/modules/chat/chat_page_android_parity_test.dart": {
            r"\u6fb6\u6c36\u20ac?": "复制",
            r"\u741b\u3126\u510f\u9365\u70b2\u7c32": "表情回应",
            r"\u6d93\u5a43\u6363": "上海",
            r"\u6d93\u5a43\u6363\u752f\u509e\u7c8d\u5a34\ufe40\u5c2f": "上海市黄浦区",
            r"\u935a\u5d87\u5896\u9422\u3126\u57db": "名片用户",
        },
        "test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart": {
            r"[\u9365\u5267\u5896]": "[图片]",
        },
        "tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart": {
            r"    '[\u9365\u5267\u5896]',\n": "",
            r" ||\n      normalized == '[\u9365\u5267\u5896]'": "",
        },
        "tools/feishu_monitor_shell_app/test/feishu_media_extraction_queue_test.dart": {
            r"[\u9365\u5267\u5896]": "[图片]",
        },
        "tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart": {
            r"\u5a4a\u2103\u5f27\u59dd\uff48\u5158\u95b2?": "飞书群聊",
            r"\u59d7\u6a3c\u6553\u5a23\ue1bc\u5d21": "张三",
            r"[\u9365\u5267\u5896]": "[图片]",
        },
        "tools/feishu_monitor_shell_app/test/feishu_network_forwardable_image_resolver_test.dart": {
            r"[\u9365\u5267\u5896]": "[图片]",
        },
        "tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart": {
            r"[\u9365\u5267\u5896]": "[图片]",
        },
        "tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart": {
            r"[\u9365\u5267\u5896]": "[图片]",
        },
    }

    for raw_path, file_replacements in replacements.items():
        path = Path(raw_path)
        if replace_all(path, file_replacements):
            changed.append(raw_path)

    if remove_between(
        Path("lib/modules/auth/presentation/widgets/auth_copy.dart"),
        "  /*\n\n  static const String registerNicknameHint = ",
        "  */\n",
        "",
    ):
        changed.append("lib/modules/auth/presentation/widgets/auth_copy.dart")

    if remove_between(
        Path("lib/wukong_uikit/group/group_detail_page.dart"),
        "/*\n  final rows = <AndroidGroupDetailRow>[",
        "*/\n\n",
        "",
    ):
        changed.append("lib/wukong_uikit/group/group_detail_page.dart")

    if repair_web_entrypoint_test():
        changed.append("test/web_entrypoint_cache_cleanup_test.dart")

    for path in changed:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
