import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/channel.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/reaction.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../entity/channel.dart';
import '../entity/channel_member.dart';
import 'channel_member.dart';
import 'conversation.dart';
import 'message_performance_helpers.dart';
import 'message_search_sql.dart';
import 'wk_db_helper.dart';

Map<String, List<WKMsgReaction>> groupReactionsByMessageId(
  Iterable<WKMsgReaction> reactions,
) {
  return groupByMessageId(reactions, (reaction) => reaction.messageID);
}

class MessageBackupImportResult {
  const MessageBackupImportResult({
    this.importedCount = 0,
    this.skippedCount = 0,
    this.conversationCount = 0,
  });

  final int importedCount;
  final int skippedCount;
  final int conversationCount;
}

class MessageDB {
  MessageDB._privateConstructor();
  static final MessageDB _instance = MessageDB._privateConstructor();
  static MessageDB get shared => _instance;
  final String extraCols =
      "IFNULL(${WKDBConst.tableMessageExtra}.readed,0) as readed,IFNULL(${WKDBConst.tableMessageExtra}.readed_count,0) as readed_count,IFNULL(${WKDBConst.tableMessageExtra}.unread_count,0) as unread_count,IFNULL(${WKDBConst.tableMessageExtra}.revoke,0) as revoke,IFNULL(${WKDBConst.tableMessageExtra}.revoker,'') as revoker,IFNULL(${WKDBConst.tableMessageExtra}.extra_version,0) as extra_version,IFNULL(${WKDBConst.tableMessageExtra}.is_mutual_deleted,0) as is_mutual_deleted,IFNULL(${WKDBConst.tableMessageExtra}.need_upload,0) as need_upload,IFNULL(${WKDBConst.tableMessageExtra}.content_edit,'') as content_edit,IFNULL(${WKDBConst.tableMessageExtra}.edited_at,0) as edited_at,IFNULL(${WKDBConst.tableMessageExtra}.is_pinned,0) as is_pinned";
  final String messageCols =
      "${WKDBConst.tableMessage}.client_seq,${WKDBConst.tableMessage}.message_id,${WKDBConst.tableMessage}.server_msg_id,${WKDBConst.tableMessage}.message_seq,${WKDBConst.tableMessage}.channel_id,${WKDBConst.tableMessage}.channel_type,${WKDBConst.tableMessage}.timestamp,${WKDBConst.tableMessage}.topic_id,${WKDBConst.tableMessage}.from_uid,${WKDBConst.tableMessage}.type,${WKDBConst.tableMessage}.content,${WKDBConst.tableMessage}.status,${WKDBConst.tableMessage}.voice_status,${WKDBConst.tableMessage}.created_at,${WKDBConst.tableMessage}.updated_at,${WKDBConst.tableMessage}.searchable_word,${WKDBConst.tableMessage}.client_msg_no,${WKDBConst.tableMessage}.setting,${WKDBConst.tableMessage}.order_seq,${WKDBConst.tableMessage}.extra,${WKDBConst.tableMessage}.is_deleted,${WKDBConst.tableMessage}.flame,${WKDBConst.tableMessage}.flame_second,${WKDBConst.tableMessage}.viewed,${WKDBConst.tableMessage}.viewed_at,${WKDBConst.tableMessage}.expire_time,${WKDBConst.tableMessage}.expire_timestamp";

  Future<bool> isExist(String clientMsgNo) async {
    bool isExist = false;
    if (WKDBHelper.shared.getDB() == null) {
      return isExist;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableMessage,
        where: "client_msg_no=?",
        whereArgs: [clientMsgNo]);
    if (list.isNotEmpty) {
      isExist = true;
    }
    return isExist;
  }

  Future<int> insert(WKMsg msg) async {
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return 0;
    }
    if (msg.clientSeq != 0) {
      await updateMsg(msg);
      return msg.clientSeq;
    }
    return _upsertMessageByIdentity(database, msg);
  }

  Future<int> updateMsg(WKMsg msg) async {
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return 0;
    }
    final count = await database.update(WKDBConst.tableMessage, getMap(msg),
        where: "client_seq=?", whereArgs: [msg.clientSeq]);
    await _syncMessageFtsByClientSeq(database, msg.clientSeq);
    return count;
  }

  Future<int> updateMsgWithField(dynamic map, int clientSeq) async {
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return 0;
    }
    final count = await database.update(WKDBConst.tableMessage, map,
        where: "client_seq=?", whereArgs: [clientSeq]);
    await _syncMessageFtsByClientSeq(database, clientSeq);
    return count;
  }

  Future<int> updateMsgWithFieldAndClientMsgNo(
      dynamic map, String clientMsgNO) async {
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return 0;
    }
    final rows = await database.query(
      WKDBConst.tableMessage,
      columns: const ['client_seq'],
      where: "client_msg_no=?",
      whereArgs: [clientMsgNO],
      limit: 1,
    );
    final count = await database.update(WKDBConst.tableMessage, map,
        where: "client_msg_no=?", whereArgs: [clientMsgNO]);
    if (rows.isNotEmpty) {
      await _syncMessageFtsByClientSeq(
        database,
        WKDBConst.readInt(rows.first, 'client_seq'),
      );
    }
    return count;
  }

  Future<WKMsg?> queryWithClientMsgNo(String clientMsgNo) async {
    WKMsg? wkMsg;
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.client_msg_no=?";
    if (WKDBHelper.shared.getDB() == null) {
      return wkMsg;
    }
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB()!.rawQuery(sql, [clientMsgNo]);
    if (list.isNotEmpty) {
      wkMsg = WKDBConst.serializeWKMsg(list[0]);
    }
    if (wkMsg != null) {
      wkMsg.reactionList =
          await ReactionDB.shared.queryWithMessageId(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<List<WKMsg>> queryWithFlame() async {
    final list = <WKMsg>[];
    final sql = "select $messageCols,$extraCols from ${WKDBConst.tableMessage} "
        "LEFT JOIN ${WKDBConst.tableMessageExtra} ON "
        "${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id "
        "WHERE ${WKDBConst.tableMessage}.flame=1 AND ${WKDBConst.tableMessage}.is_deleted=0";
    if (WKDBHelper.shared.getDB() == null) {
      return list;
    }
    final results = await WKDBHelper.shared.getDB()!.rawQuery(sql);
    if (results.isNotEmpty) {
      for (final data in results) {
        list.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return list;
  }

  Future<List<WKMsg>> queryExpiredMessages({
    required int nowTimestamp,
    int limit = 50,
  }) async {
    final list = <WKMsg>[];
    if (WKDBHelper.shared.getDB() == null) {
      return list;
    }
    final effectiveLimit = limit > 0 ? limit : 50;
    final sql = "select $messageCols,$extraCols from ${WKDBConst.tableMessage} "
        "LEFT JOIN ${WKDBConst.tableMessageExtra} ON "
        "${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id "
        "WHERE ${WKDBConst.tableMessage}.is_deleted=0 "
        "AND ${WKDBConst.tableMessage}.expire_timestamp<>0 "
        "AND ${WKDBConst.tableMessage}.expire_timestamp<=? "
        "ORDER BY ${WKDBConst.tableMessage}.order_seq ASC LIMIT 0,?";
    final results = await WKDBHelper.shared.getDB()!.rawQuery(sql, [
      nowTimestamp,
      effectiveLimit,
    ]);
    if (results.isNotEmpty) {
      for (final data in results) {
        list.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return list;
  }

  Future<WKMsg?> queryWithClientSeq(int clientSeq) async {
    WKMsg? wkMsg;
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.client_seq=?";
    if (WKDBHelper.shared.getDB() == null) {
      return wkMsg;
    }
    List<Map<String, Object?>> list =
        await WKDBHelper.shared.getDB()!.rawQuery(sql, [clientSeq]);
    if (list.isNotEmpty) {
      wkMsg = WKDBConst.serializeWKMsg(list[0]);
    }
    if (wkMsg != null) {
      wkMsg.reactionList =
          await ReactionDB.shared.queryWithMessageId(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<List<WKMsg>> queryWithMessageIds(List<String> messageIds) async {
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} ON ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.message_id in (${WKDBConst.getPlaceholders(messageIds.length)})";
    List<WKMsg> list = [];
    if (WKDBHelper.shared.getDB() == null) {
      return list;
    }
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB()!.rawQuery(sql, messageIds);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return list;
  }

  Future<int> queryMaxOrderSeq(String channelID, int channelType) async {
    int maxOrderSeq = 0;
    if (WKDBHelper.shared.getDB() == null) {
      return maxOrderSeq;
    }
    String sql =
        "select max(order_seq) order_seq from ${WKDBConst.tableMessage} where channel_id =? and channel_type=? and type<>99 and type<>0 and is_deleted=0";
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      maxOrderSeq = WKDBConst.readInt(data, 'order_seq');
    }
    return maxOrderSeq;
  }

  Future<int> getMaxMessageSeq(String channelID, int channelType) async {
    String sql =
        "SELECT max(message_seq) message_seq FROM ${WKDBConst.tableMessage} WHERE channel_id=? AND channel_type=?";
    int messageSeq = 0;
    if (WKDBHelper.shared.getDB() == null) {
      return messageSeq;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      messageSeq = WKDBConst.readInt(data, 'message_seq');
    }
    return messageSeq;
  }

  Future<int> getOrderSeq(
      String channelID, int channelType, int maxOrderSeq, int limit) async {
    int minOrderSeq = 0;
    if (WKDBHelper.shared.getDB() == null) {
      return minOrderSeq;
    }
    String sql =
        "select order_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and type<>99 and order_seq <=? order by order_seq desc limit ?";
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType, maxOrderSeq, limit]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      minOrderSeq = WKDBConst.readInt(data, 'order_seq');
    }
    return minOrderSeq;
  }

  Future<List<WKMsg>> getMessages(String channelId, int channelType,
      int oldestOrderSeq, bool contain, int pullMode, int limit) async {
    List<WKMsg> msgList = [];
    String sql;
    var args = [];
    if (oldestOrderSeq <= 0) {
      sql =
          "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,?";
      args.add(channelId);
      args.add(channelType);
      args.add(limit);
    } else {
      if (pullMode == 0) {
        if (contain) {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<=?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,?";
        } else {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,?";
        }
      } else {
        if (contain) {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>=?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq asc limit 0,?";
        } else {
          sql =
              "SELECT * FROM (SELECT $messageCols,$extraCols FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq asc limit 0,?";
        }
      }
      args.add(channelId);
      args.add(channelType);
      args.add(oldestOrderSeq);
      args.add(limit);
    }
    List<String> messageIds = [];
    List<String> replyMsgIds = [];
    List<String> fromUIDs = [];
    final fromUIDSet = <String>{};
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB()!.rawQuery(sql, args);
    if (results.isNotEmpty) {
      WKChannel? wkChannel =
          await ChannelDB.shared.query(channelId, channelType);
      for (Map<String, Object?> data in results) {
        WKMsg wkMsg = WKDBConst.serializeWKMsg(data);
        wkMsg.setChannelInfo(wkChannel);
        if (wkMsg.messageID != '') {
          messageIds.add(wkMsg.messageID);
        }

        if (wkMsg.messageContent != null &&
            wkMsg.messageContent!.reply != null &&
            wkMsg.messageContent!.reply!.messageId != '') {
          replyMsgIds.add(wkMsg.messageContent!.reply!.messageId);
        }
        if (wkMsg.fromUID != '' && fromUIDSet.add(wkMsg.fromUID)) {
          fromUIDs.add(wkMsg.fromUID);
        }
        if (pullMode == 0) {
          msgList.insert(0, wkMsg);
        } else {
          msgList.add(wkMsg);
        }
      }
    }
    //扩展消息
    List<WKMsgReaction> list =
        await ReactionDB.shared.queryWithMessageIds(messageIds);
    if (list.isNotEmpty) {
      final reactionsByMessageId = groupReactionsByMessageId(list);
      for (final msg in msgList) {
        final reactions = reactionsByMessageId[msg.messageID.trim()];
        if (reactions != null && reactions.isNotEmpty) {
          msg.reactionList = <WKMsgReaction>[...reactions];
        }
      }
    }
    // 发送者成员信息
    if (channelType == WKChannelType.group) {
      List<WKChannelMember> memberList = await ChannelMemberDB.shared
          .queryMemberWithUIDs(channelId, channelType, fromUIDs);
      if (memberList.isNotEmpty) {
        final membersByUid = indexByNonEmptyKey<WKChannelMember>(
          memberList,
          (member) => member.memberUID,
        );
        for (final msg in msgList) {
          final member = membersByUid[msg.fromUID.trim()];
          if (member != null) {
            msg.setMemberOfFrom(member);
          }
        }
      }
    }
    //消息发送者信息
    List<WKChannel> wkChannels = await ChannelDB.shared
        .queryWithChannelIdsAndChannelType(fromUIDs, WKChannelType.personal);
    if (wkChannels.isNotEmpty) {
      final channelsByUid = indexByNonEmptyKey<WKChannel>(
        wkChannels,
        (channel) => channel.channelID,
      );
      for (final msg in msgList) {
        final channel = channelsByUid[msg.fromUID.trim()];
        if (channel != null) {
          msg.setFrom(channel);
        }
      }
    }
    // 查询编辑内容
    if (replyMsgIds.isNotEmpty) {
      List<WKMsgExtra> msgExtraList =
          await queryMsgExtrasWithMsgIds(replyMsgIds);
      if (msgExtraList.isNotEmpty) {
        final extrasByMessageId = indexByNonEmptyKey<WKMsgExtra>(
          msgExtraList,
          (extra) => extra.messageID,
        );
        for (final msg in msgList) {
          final reply = msg.messageContent?.reply;
          final replyMessageId = reply?.messageId.trim() ?? '';
          if (reply == null || replyMessageId.isEmpty) {
            continue;
          }
          final extra = extrasByMessageId[replyMessageId];
          if (extra == null) {
            continue;
          }
          reply.revoke = extra.revoke;
          if (extra.contentEdit != '') {
            reply.editAt = extra.editedAt;
            reply.contentEdit = extra.contentEdit;
            var json = jsonEncode(extra.contentEdit);
            var type = WKDBConst.readInt(json, 'type');
            reply.contentEditMsgModel =
                WKIM.shared.messageManager.getMessageModel(type, json);
          }
        }
      }
    }
    return msgList;
  }

  var requestCount = 0;
  void getOrSyncHistoryMessages(
      String channelId,
      int channelType,
      int oldestOrderSeq,
      bool contain,
      int pullMode,
      int limit,
      final Function(List<WKMsg>) iGetOrSyncHistoryMsgBack,
      final Function() syncBack) async {
    //获取原始数据
    List<WKMsg> list = await getMessages(
        channelId, channelType, oldestOrderSeq, contain, pullMode, limit);
    //业务判断数据
    List<WKMsg> tempList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      tempList.add(list[i]);
    }

    //先通过message_seq排序
    if (tempList.isNotEmpty) {
      tempList.sort((a, b) => a.messageSeq.compareTo(b.messageSeq));
    }
    //获取最大和最小messageSeq
    int minMessageSeq = 0;
    int maxMessageSeq = 0;
    for (int i = 0, size = tempList.length; i < size; i++) {
      if (tempList[i].messageSeq != 0) {
        if (minMessageSeq == 0) minMessageSeq = tempList[i].messageSeq;
        if (tempList[i].messageSeq > maxMessageSeq) {
          maxMessageSeq = tempList[i].messageSeq;
        }

        if (tempList[i].messageSeq < minMessageSeq) {
          minMessageSeq = tempList[i].messageSeq;
        }
      }
    }
    //是否同步消息
    bool isSyncMsg = false;
    int startMsgSeq = 0;
    int endMsgSeq = 0;
    //判断页与页之间是否连续
    int oldestMsgSeq;

    //如果获取到的messageSeq为0说明oldestOrderSeq这条消息是本地消息则获取他上一条或下一条消息的messageSeq做为判断
    if (oldestOrderSeq % 1000 != 0) {
      oldestMsgSeq =
          await getMsgSeq(channelId, channelType, oldestOrderSeq, pullMode);
    } else {
      oldestMsgSeq = oldestOrderSeq ~/ 1000;
    }

    if (pullMode == 0) {
      //下拉获取消息
      if (oldestMsgSeq == 1) {
        iGetOrSyncHistoryMsgBack([]);
        return;
      }
      if (maxMessageSeq != 0 &&
          oldestMsgSeq != 0 &&
          oldestMsgSeq - maxMessageSeq > 1) {
        isSyncMsg = true;
        if (contain) {
          startMsgSeq = oldestMsgSeq;
        } else {
          startMsgSeq = oldestMsgSeq - 1;
        }
        endMsgSeq = maxMessageSeq;
      }
    } else {
      //上拉获取消息
      if (minMessageSeq != 0 &&
          oldestMsgSeq != 0 &&
          minMessageSeq - oldestMsgSeq > 1) {
        isSyncMsg = true;
        if (contain) {
          startMsgSeq = oldestMsgSeq;
        } else {
          startMsgSeq = oldestMsgSeq + 1;
        }
        endMsgSeq = minMessageSeq;
      }
    }
    if (!isSyncMsg) {
      //判断当前页是否连续
      for (int i = 0, size = tempList.length; i < size; i++) {
        int nextIndex = i + 1;
        if (nextIndex < tempList.length) {
          if (tempList[nextIndex].messageSeq != 0 &&
              tempList[i].messageSeq != 0 &&
              tempList[nextIndex].messageSeq - tempList[i].messageSeq > 1) {
            //判断该条消息是否被删除
            int num = await getDeletedCount(tempList[i].messageSeq,
                tempList[nextIndex].messageSeq, channelId, channelType);
            if (num <
                (tempList[nextIndex].messageSeq - tempList[i].messageSeq) - 1) {
              isSyncMsg = true;
              int max = tempList[nextIndex].messageSeq;
              int min = tempList[i].messageSeq;
              if (tempList[nextIndex].messageSeq < tempList[i].messageSeq) {
                max = tempList[i].messageSeq;
                min = tempList[nextIndex].messageSeq;
              }
              if (pullMode == 0) {
                // 下拉
                if (max > startMsgSeq) {
                  startMsgSeq = max;
                }
                if (endMsgSeq == 0 || min < endMsgSeq) {
                  endMsgSeq = min;
                }
              } else {
                if (startMsgSeq == 0 || min < startMsgSeq) {
                  startMsgSeq = min;
                }
                if (max > endMsgSeq) {
                  endMsgSeq = max;
                }
              }
            }
          }
        }
      }
    }
    if (!isSyncMsg) {
      if (minMessageSeq == 1) {
        requestCount = 0;
        iGetOrSyncHistoryMsgBack(list);
        return;
      }
    }
    //计算最后一页后是否还存在消息
    int syncLimit = limit;
    if (!isSyncMsg && tempList.length < limit) {
      isSyncMsg = true;
      if (contain) {
        startMsgSeq = oldestMsgSeq;
      } else {
        if (pullMode == 0) {
          startMsgSeq = oldestMsgSeq - 1;
        } else {
          startMsgSeq = oldestMsgSeq + 1;
        }
      }
      endMsgSeq = 0;
    }
    if (startMsgSeq == 0 && endMsgSeq == 0 && tempList.length < limit) {
      isSyncMsg = true;
      endMsgSeq = oldestMsgSeq;
      startMsgSeq = 0;
    }
    if (isSyncMsg &&
        (startMsgSeq != endMsgSeq || (startMsgSeq == 0 && endMsgSeq == 0)) &&
        requestCount < 5) {
      if (requestCount == 0) {
        syncBack();
      }
      //同步消息
      requestCount++;
      WKIM.shared.messageManager.setSyncChannelMsgListener(
          channelId, channelType, startMsgSeq, endMsgSeq, syncLimit, pullMode,
          (syncChannelMsg) {
        if (syncChannelMsg != null) {
          if (oldestMsgSeq == 0 ||
              (syncChannelMsg.messages != null &&
                  syncChannelMsg.messages!.length < limit)) {
            requestCount = 5;
          }
          getOrSyncHistoryMessages(channelId, channelType, oldestOrderSeq,
              contain, pullMode, limit, iGetOrSyncHistoryMsgBack, syncBack);
        } else {
          requestCount = 0;
          iGetOrSyncHistoryMsgBack(list);
        }
      });
    } else {
      requestCount = 0;
      iGetOrSyncHistoryMsgBack(list);
    }
  }

  Future<int> getDeletedCount(int minMessageSeq, int maxMessageSeq,
      String channelID, int channelType) async {
    String sql =
        "select count(*) num from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and message_seq>? and message_seq<? and is_deleted=1";
    int num = 0;
    if (WKDBHelper.shared.getDB() == null) {
      return num;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType, minMessageSeq, maxMessageSeq]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      num = WKDBConst.readInt(data, 'num');
    }
    return num;
  }

  Future<int> getMsgSeq(String channelID, int channelType, int oldestOrderSeq,
      int pullMode) async {
    String sql;
    int messageSeq = 0;
    if (pullMode == 1) {
      sql =
          "select message_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and  order_seq>? and message_seq<>0 order by message_seq desc limit 1";
    } else {
      sql =
          "select message_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and  order_seq<? and message_seq<>0 order by message_seq asc limit 1";
    }
    if (WKDBHelper.shared.getDB() == null) {
      return messageSeq;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType, oldestOrderSeq]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      messageSeq = WKDBConst.readInt(data, 'message_seq');
    }
    return messageSeq;
  }

  Future<bool> insertMsgList(List<WKMsg> list) async {
    if (list.isEmpty) {
      return true;
    }
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return false;
    }
    await database.transaction((txn) async {
      for (final msg in list) {
        if (msg.clientSeq != 0) {
          await txn.update(WKDBConst.tableMessage, getMap(msg),
              where: "client_seq=?", whereArgs: [msg.clientSeq]);
          await _syncMessageFtsByClientSeq(txn, msg.clientSeq);
          continue;
        }
        await _upsertMessageByIdentity(txn, msg);
      }
    });
    return true;
  }

  Future<int> _upsertMessageByIdentity(DatabaseExecutor db, WKMsg msg) async {
    final existing = await _queryExistingMessageByIdentity(db, msg);
    if (existing != null) {
      _mergeIdentityWithExisting(msg, existing);
      final clientSeq = WKDBConst.readInt(existing, 'client_seq');
      if (clientSeq != 0) {
        msg.clientSeq = clientSeq;
        await db.update(WKDBConst.tableMessage, getMap(msg),
            where: "client_seq=?", whereArgs: [clientSeq]);
        await _syncMessageFtsByClientSeq(db, clientSeq);
        return clientSeq;
      }
    }
    final insertedId = await db.insert(WKDBConst.tableMessage, getMap(msg),
        conflictAlgorithm: ConflictAlgorithm.replace);
    msg.clientSeq = insertedId;
    await _syncMessageFtsByClientSeq(db, insertedId);
    return insertedId;
  }

  Future<Map<String, Object?>?> _queryExistingMessageByIdentity(
      DatabaseExecutor db, WKMsg msg) async {
    final serverMsgID = msg.serverMsgID.trim();
    if (serverMsgID.isNotEmpty) {
      final byServerMsgID = await db.query(WKDBConst.tableMessage,
          where: "channel_id=? and channel_type=? and server_msg_id=?",
          whereArgs: [msg.channelID, msg.channelType, serverMsgID],
          limit: 1);
      if (byServerMsgID.isNotEmpty) {
        return byServerMsgID.first;
      }
    }
    final clientMsgNo = msg.clientMsgNO.trim();
    if (clientMsgNo.isEmpty) {
      return null;
    }
    final byClientMsgNo = await db.query(WKDBConst.tableMessage,
        where: "client_msg_no=?", whereArgs: [clientMsgNo], limit: 1);
    if (byClientMsgNo.isNotEmpty) {
      return byClientMsgNo.first;
    }
    return null;
  }

  void _mergeIdentityWithExisting(WKMsg msg, Map<String, Object?> existing) {
    final existingClientMsgNo = WKDBConst.readString(existing, 'client_msg_no');
    if (existingClientMsgNo.isNotEmpty &&
        (msg.clientMsgNO.isEmpty || msg.clientMsgNO != existingClientMsgNo)) {
      msg.clientMsgNO = existingClientMsgNo;
    }
    final existingServerMsgID = WKDBConst.readString(existing, 'server_msg_id');
    if (msg.serverMsgID.isEmpty && existingServerMsgID.isNotEmpty) {
      msg.serverMsgID = existingServerMsgID;
    }
    final existingMessageID = WKDBConst.readString(existing, 'message_id');
    if (msg.messageID.isEmpty && existingMessageID.isNotEmpty) {
      msg.messageID = existingMessageID;
    }
  }

  Future<List<WKMsg>> queryWithClientMsgNos(List<String> clientMsgNos) async {
    List<WKMsg> msgs = [];
    if (WKDBHelper.shared.getDB() == null) {
      return msgs;
    }
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableMessage,
        where:
            "client_msg_no in (${WKDBConst.getPlaceholders(clientMsgNos.length)})",
        whereArgs: clientMsgNos);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        msgs.add(WKDBConst.serializeWKMsg(data));
      }
    }
    return msgs;
  }

  Future<MessageBackupImportResult> importBackupArchive(String rawJson) async {
    Database? database = WKDBHelper.shared.getDB();
    if (database == null) {
      await WKDBHelper.shared.init();
      database = WKDBHelper.shared.getDB();
    }
    if (database == null) {
      throw StateError('Message database is not initialized.');
    }

    final archive = _decodeArchive(rawJson);
    final schemaVersion = archive.schemaVersion;
    if (schemaVersion != 2) {
      throw FormatException(
        'Unsupported backup schema_version: $schemaVersion',
      );
    }

    final rawMessages = archive.messages;
    if (rawMessages.isEmpty) {
      return const MessageBackupImportResult();
    }

    final clientMsgNos = <String>[];
    for (final item in rawMessages) {
      if (item is! Map) {
        continue;
      }
      final record = _normalizeArchiveMap(item);
      final clientMsgNo = _readArchiveString(record, 'client_msg_no').trim();
      if (clientMsgNo.isNotEmpty) {
        clientMsgNos.add(clientMsgNo);
      }
    }

    final existingClientMsgNos = await _queryExistingClientMsgNos(clientMsgNos);
    final seenClientMsgNos = <String>{};
    final restoredMessages = <WKMsg>[];
    final restoredChannels = <WKChannel>[];
    final restoredConversations = <WKConversationMsg>[];
    final rawSettingByClientMsgNo = <String, int>{};
    var skippedCount = 0;

    for (final item in rawMessages) {
      if (item is! Map) {
        skippedCount += 1;
        continue;
      }
      final record = _normalizeArchiveMap(item);

      final channelId = _readArchiveString(record, 'channel_id').trim();
      final channelType = _readArchiveInt(record, 'channel_type');
      if (channelId.isEmpty || channelType <= 0) {
        skippedCount += 1;
        continue;
      }

      final clientMsgNo = _readArchiveString(record, 'client_msg_no').trim();
      if (clientMsgNo.isEmpty) {
        skippedCount += 1;
        continue;
      }
      if (existingClientMsgNos.contains(clientMsgNo) ||
          !seenClientMsgNos.add(clientMsgNo)) {
        skippedCount += 1;
        continue;
      }

      final messageSeq = _readArchiveInt(record, 'message_seq');
      final orderSeq = _readArchiveInt(record, 'order_seq');
      final payload = _readArchiveString(record, 'payload');
      final contentType = _readArchiveContentType(record, payload);
      final status = _hasArchiveValue(record, 'status')
          ? _readArchiveInt(record, 'status')
          : WKSendMsgResult.sendSuccess;
      final settingValue = _hasArchiveValue(record, 'setting')
          ? _readArchiveInt(record, 'setting')
          : 0;

      final channel = WKChannel(channelId, channelType)
        ..channelName = _readArchiveString(record, 'channel_name')
        ..channelRemark = _readArchiveString(record, 'channel_remark')
        ..parentChannelID = _readArchiveString(record, 'parent_channel_id')
        ..parentChannelType = _readArchiveInt(record, 'parent_channel_type');
      if (channel.channelName.isEmpty) {
        channel.channelName = channel.channelID;
      }

      final message = WKMsg()
        ..messageID = _readArchiveString(record, 'message_id')
        ..messageSeq = messageSeq
        ..orderSeq = orderSeq > 0 ? orderSeq : messageSeq * 1000
        ..clientMsgNO = clientMsgNo
        ..fromUID = _readArchiveString(record, 'from_uid')
        ..channelID = channelId
        ..channelType = channelType
        ..timestamp = _readArchiveInt(record, 'timestamp')
        ..contentType = contentType
        ..content = payload
        ..status = status
        ..isDeleted = 0;
      message.setting = message.setting.decode(settingValue);
      if (message.contentType != WkMessageContentType.contentFormatError &&
          message.content.isNotEmpty &&
          WKDBConst.isJsonString(message.content)) {
        final payloadJson = jsonDecode(message.content);
        message.messageContent = WKIM.shared.messageManager
            .getMessageModel(contentType, payloadJson);
      }
      message.setChannelInfo(channel);
      restoredMessages.add(message);
      restoredChannels.add(channel);
      if (_hasArchiveValue(record, 'setting')) {
        rawSettingByClientMsgNo[clientMsgNo] = settingValue;
      }

      final conversation = WKConversationMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..lastClientMsgNO = clientMsgNo.isNotEmpty
            ? clientMsgNo
            : _readArchiveString(record, 'message_id')
        ..lastMsgTimestamp = _readArchiveInt(record, 'timestamp')
        ..lastMsgSeq = messageSeq
        ..unreadCount = 0
        ..isDeleted = 0
        ..parentChannelID = channel.parentChannelID
        ..parentChannelType = channel.parentChannelType;
      restoredConversations.add(conversation);
    }

    final dedupedChannels = _dedupeChannels(restoredChannels);
    final dedupedConversations =
        ConversationDB.shared.dedupeByChannel(restoredConversations);

    if (dedupedChannels.isNotEmpty) {
      await ChannelDB.shared.insertOrUpdateList(dedupedChannels);
    }
    if (restoredMessages.isNotEmpty) {
      await insertMsgList(restoredMessages);
      if (rawSettingByClientMsgNo.isNotEmpty) {
        for (final entry in rawSettingByClientMsgNo.entries) {
          await updateMsgWithFieldAndClientMsgNo(
            <String, Object>{'setting': entry.value},
            entry.key,
          );
        }
      }
    }
    if (dedupedConversations.isNotEmpty) {
      await ConversationDB.shared.insertMsgList(dedupedConversations);
    }

    return MessageBackupImportResult(
      importedCount: restoredMessages.length,
      skippedCount: skippedCount,
      conversationCount: dedupedConversations.length,
    );
  }

  _DecodedBackupArchive _decodeArchive(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is List) {
      return _DecodedBackupArchive(
        schemaVersion: 2,
        messages: List<dynamic>.from(decoded),
      );
    }
    if (decoded is! Map) {
      throw const FormatException('Backup archive must be a JSON object.');
    }
    final archive = _normalizeArchiveMap(decoded);
    final rawMessages = archive['messages'];
    if (rawMessages is! List) {
      throw const FormatException('Backup archive messages must be a list.');
    }
    return _DecodedBackupArchive(
      schemaVersion: _readArchiveInt(archive, 'schema_version'),
      messages: List<dynamic>.from(rawMessages),
    );
  }

  Map<String, Object?> _normalizeArchiveMap(Map raw) {
    final record = <String, Object?>{};
    raw.forEach((Object? key, Object? value) {
      if (key == null) {
        return;
      }
      record[key.toString()] = value;
    });
    return record;
  }

  Future<Set<String>> _queryExistingClientMsgNos(
      List<String> clientMsgNos) async {
    final existingClientMsgNos = <String>{};
    if (clientMsgNos.isEmpty) {
      return existingClientMsgNos;
    }
    const chunkSize = 200;
    var start = 0;
    while (start < clientMsgNos.length) {
      var end = start + chunkSize;
      if (end > clientMsgNos.length) {
        end = clientMsgNos.length;
      }
      final chunk = clientMsgNos.sublist(start, end);
      final exist = await queryWithClientMsgNos(chunk);
      for (final msg in exist) {
        final clientMsgNo = msg.clientMsgNO.trim();
        if (clientMsgNo.isNotEmpty) {
          existingClientMsgNos.add(clientMsgNo);
        }
      }
      start = end;
    }
    return existingClientMsgNos;
  }

  List<WKChannel> _dedupeChannels(List<WKChannel> channels) {
    final deduped = <String, WKChannel>{};
    for (final channel in channels) {
      if (channel.channelID.isEmpty) {
        continue;
      }
      final key = '${channel.channelID}:${channel.channelType}';
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = channel;
        continue;
      }
      if (existing.channelName.isEmpty && channel.channelName.isNotEmpty) {
        existing.channelName = channel.channelName;
      }
      if (existing.channelRemark.isEmpty && channel.channelRemark.isNotEmpty) {
        existing.channelRemark = channel.channelRemark;
      }
      if (existing.parentChannelID.isEmpty &&
          channel.parentChannelID.isNotEmpty) {
        existing.parentChannelID = channel.parentChannelID;
        existing.parentChannelType = channel.parentChannelType;
      }
    }
    return deduped.values.toList(growable: false);
  }

  int _readArchiveInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _readArchiveString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  bool _hasArchiveValue(Map<String, Object?> map, String key) {
    return map.containsKey(key) && map[key] != null;
  }

  int _readArchiveContentType(Map<String, Object?> map, String payload) {
    if (_hasArchiveValue(map, 'content_type')) {
      return _readArchiveInt(map, 'content_type');
    }
    if (_hasArchiveValue(map, 'type')) {
      return _readArchiveInt(map, 'type');
    }
    return _readPayloadContentType(payload);
  }

  int _readPayloadContentType(String payload) {
    if (payload.isEmpty || !WKDBConst.isJsonString(payload)) {
      return 0;
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return 0;
    }
    return WKDBConst.readInt(decoded, 'type');
  }

  Future<bool> insertMsgExtras(List<WKMsgExtra> list) async {
    if (list.isEmpty) {
      return true;
    }
    List<Map<String, Object>> insertCVList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      insertCVList.add(getExtraMap(list[i]));
    }
    await WKDBHelper.shared.getDB()!.transaction((txn) async {
      if (insertCVList.isNotEmpty) {
        for (int i = 0; i < insertCVList.length; i++) {
          txn.insert(WKDBConst.tableMessageExtra, insertCVList[i],
              conflictAlgorithm: ConflictAlgorithm.replace);
          final contentEdit = insertCVList[i]['content_edit']?.toString() ?? '';
          if (contentEdit != '') {
            final searchableWord = _resolveSearchableWordFromContentEdit(
              contentEdit,
            );
            await txn.update(
              WKDBConst.tableMessage,
              <String, Object>{'searchable_word': searchableWord},
              where: "message_id=?",
              whereArgs: [insertCVList[i]['message_id']],
            );
            await _syncMessageFtsByMessageId(
              txn,
              insertCVList[i]['message_id']?.toString() ?? '',
            );
          }
        }
      }
    });
    return true;
  }

  Future<bool> insertOrUpdateMsgExtras(List<WKMsgExtra> list) async {
    List<String> msgIds = [];
    for (int i = 0, size = list.length; i < size; i++) {
      if (list[i].messageID != '') {
        msgIds.add(list[i].messageID);
      }
    }
    List<WKMsgExtra> existList = await queryMsgExtrasWithMsgIds(msgIds);
    final existingExtrasByMessageId = indexByNonEmptyKey<WKMsgExtra>(
      existList,
      (extra) => extra.messageID,
    );
    List<Map<String, Object>> insertCVList = [];
    List<Map<String, Object>> updateCVList = [];
    for (int i = 0, size = list.length; i < size; i++) {
      if (existingExtrasByMessageId.containsKey(list[i].messageID.trim())) {
        updateCVList.add(getExtraMap(list[i]));
      } else {
        insertCVList.add(getExtraMap(list[i]));
      }
    }
    if (insertCVList.isNotEmpty || updateCVList.isNotEmpty) {
      await WKDBHelper.shared.getDB()!.transaction((txn) async {
        if (insertCVList.isNotEmpty) {
          for (int i = 0; i < insertCVList.length; i++) {
            txn.insert(WKDBConst.tableMessageExtra, insertCVList[i],
                conflictAlgorithm: ConflictAlgorithm.replace);
            final contentEdit =
                insertCVList[i]['content_edit']?.toString() ?? '';
            if (contentEdit != '') {
              final searchableWord = _resolveSearchableWordFromContentEdit(
                contentEdit,
              );
              await txn.update(
                WKDBConst.tableMessage,
                <String, Object>{'searchable_word': searchableWord},
                where: "message_id=?",
                whereArgs: [insertCVList[i]['message_id']],
              );
              await _syncMessageFtsByMessageId(
                txn,
                insertCVList[i]['message_id']?.toString() ?? '',
              );
            }
          }
        }
        if (updateCVList.isNotEmpty) {
          for (int i = 0; i < updateCVList.length; i++) {
            txn.update(WKDBConst.tableMessageExtra, updateCVList[i],
                where: "message_id=?",
                whereArgs: [updateCVList[i]['message_id']]);
            final contentEdit =
                updateCVList[i]['content_edit']?.toString() ?? '';
            if (contentEdit != '') {
              final searchableWord = _resolveSearchableWordFromContentEdit(
                contentEdit,
              );
              await txn.update(
                WKDBConst.tableMessage,
                <String, Object>{'searchable_word': searchableWord},
                where: "message_id=?",
                whereArgs: [updateCVList[i]['message_id']],
              );
              await _syncMessageFtsByMessageId(
                txn,
                updateCVList[i]['message_id']?.toString() ?? '',
              );
            }
          }
        }
      });
    }
    return true;
  }

  Future<int> queryMaxExtraVersionWithChannel(
      String channelID, int channelType) async {
    int extraVersion = 0;
    String sql =
        "select max(extra_version) extra_version from ${WKDBConst.tableMessageExtra} where channel_id =? and channel_type=?";
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      extraVersion = WKDBConst.readInt(data, 'extra_version');
    }
    return extraVersion;
  }

  Future<List<WKMsgExtra>> queryMsgExtraWithNeedUpload(int needUpload) async {
    String sql =
        "select * from ${WKDBConst.tableMessageExtra}  where need_upload=?";
    List<WKMsgExtra> list = [];
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB()!.rawQuery(sql, [needUpload]);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgExtra(data));
      }
    }

    return list;
  }

  Future<WKMsgExtra?> queryMsgExtraWithMsgID(String messageID) async {
    WKMsgExtra? msgExtra;
    if (WKDBHelper.shared.getDB() == null) {
      return msgExtra;
    }
    List<Map<String, Object?>> list = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableMessageExtra,
        where: "message_id=?",
        whereArgs: [messageID]);
    if (list.isNotEmpty) {
      msgExtra = WKDBConst.serializeMsgExtra(list[0]);
    }
    return msgExtra;
  }

  Future<List<WKMsgExtra>> queryMsgExtrasWithMsgIds(List<String> msgIds) async {
    List<WKMsgExtra> list = [];
    if (WKDBHelper.shared.getDB() == null) {
      return list;
    }
    List<Map<String, Object?>> results = await WKDBHelper.shared.getDB()!.query(
        WKDBConst.tableMessageExtra,
        where: "message_id in (${WKDBConst.getPlaceholders(msgIds.length)})",
        whereArgs: msgIds);
    if (results.isNotEmpty) {
      for (Map<String, Object?> data in results) {
        list.add(WKDBConst.serializeMsgExtra(data));
      }
    }

    return list;
  }

  updateSendingMsgFail() {
    if (WKDBHelper.shared.getDB() == null) {
      return;
    }
    var map = <String, Object>{};
    map['status'] = WKSendMsgResult.sendFail;
    WKDBHelper.shared
        .getDB()!
        .update(WKDBConst.tableMessage, map, where: 'status=0');
  }

  /// P0-T02: Query messages stuck in sending state for crash recovery.
  /// Messages sent < [recentSeconds] ago are returned for resend;
  /// older ones are marked as failed.
  Future<List<WKMsg>> recoverSendingMessages({int recentSeconds = 300}) async {
    if (WKDBHelper.shared.getDB() == null) {
      return [];
    }
    final nowSec = (DateTime.now().millisecondsSinceEpoch / 1000).truncate();
    final cutoff = nowSec - recentSeconds;

    // Mark old sending messages as failed
    var failMap = <String, Object>{};
    failMap['status'] = WKSendMsgResult.sendFail;
    await WKDBHelper.shared.getDB()!.update(WKDBConst.tableMessage, failMap,
        where: 'status=? AND created_at<?',
        whereArgs: [WKSendMsgResult.sendLoading, cutoff]);

    // Query recent sending messages for resend
    String sql =
        "select $messageCols,$extraCols from ${WKDBConst.tableMessage} "
        "LEFT JOIN ${WKDBConst.tableMessageExtra} ON "
        "${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id "
        "WHERE ${WKDBConst.tableMessage}.status=? AND ${WKDBConst.tableMessage}.created_at>=? "
        "ORDER BY ${WKDBConst.tableMessage}.created_at ASC";
    List<Map<String, Object?>> results = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [WKSendMsgResult.sendLoading, cutoff]);

    List<WKMsg> list = [];
    for (Map<String, Object?> data in results) {
      list.add(WKDBConst.serializeWKMsg(data));
    }
    return list;
  }

  Future<WKMsg?> queryMaxOrderSeqMsgWithChannel(
      String channelID, int channelType) async {
    WKMsg? wkMsg;
    String sql =
        "select * from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and is_deleted=0 and type<>0 and type<>99 order by order_seq desc limit 1";
    List<Map<String, Object?>> list = await WKDBHelper.shared
        .getDB()!
        .rawQuery(sql, [channelID, channelType]);
    if (list.isNotEmpty) {
      dynamic data = list[0];
      if (data != null) {
        wkMsg = WKDBConst.serializeWKMsg(data);
      }
    }
    if (wkMsg != null) {
      wkMsg.reactionList =
          await ReactionDB.shared.queryWithMessageId(wkMsg.messageID);
    }
    return wkMsg;
  }

  Future<int> deleteWithMessageIDs(List<String> msgIds) async {
    if (WKDBHelper.shared.getDB() == null) {
      return 0;
    }
    var map = <String, Object>{};
    map['is_deleted'] = 1;
    return await WKDBHelper.shared.getDB()!.update(WKDBConst.tableMessage, map,
        where: "message_id in (${WKDBConst.getPlaceholders(msgIds.length)})",
        whereArgs: msgIds);
  }

  Future<int> deleteWithChannel(String channelId, int channelType) async {
    if (WKDBHelper.shared.getDB() == null) {
      return 0;
    }
    var map = <String, Object>{};
    map['is_deleted'] = 1;
    return await WKDBHelper.shared.getDB()!.update(WKDBConst.tableMessage, map,
        where: "channel_id=? and channel_type=?",
        whereArgs: [channelId, channelType]);
  }

  Future<bool> _messageFtsTableExists(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
      [WKDBConst.tableMessageFts],
    );
    return rows.isNotEmpty;
  }

  Future<void> _syncMessageFtsByMessageId(
    DatabaseExecutor db,
    String messageId,
  ) async {
    final normalizedMessageId = messageId.trim();
    if (normalizedMessageId.isEmpty || !await _messageFtsTableExists(db)) {
      return;
    }
    final rows = await db.query(
      WKDBConst.tableMessage,
      columns: const ['client_seq'],
      where: "message_id=?",
      whereArgs: [normalizedMessageId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }
    await _syncMessageFtsByClientSeq(
      db,
      WKDBConst.readInt(rows.first, 'client_seq'),
    );
  }

  Future<void> _syncMessageFtsByClientSeq(
    DatabaseExecutor db,
    int clientSeq,
  ) async {
    if (clientSeq <= 0 || !await _messageFtsTableExists(db)) {
      return;
    }
    final rows = await db.rawQuery(
      "SELECT m.client_seq,m.message_id,m.channel_id,m.channel_type,"
      "IFNULL(m.searchable_word,'') searchable_word,"
      "IFNULL(me.content_edit,'') content_edit "
      "FROM ${WKDBConst.tableMessage} m "
      "LEFT JOIN ${WKDBConst.tableMessageExtra} me ON m.message_id=me.message_id "
      "WHERE m.client_seq=? LIMIT 1",
      [clientSeq],
    );
    await db.delete(
      WKDBConst.tableMessageFts,
      where: "rowid=?",
      whereArgs: [clientSeq],
    );
    if (rows.isEmpty) {
      return;
    }
    final row = rows.first;
    final searchableWord = WKDBConst.readString(row, 'searchable_word');
    final contentEdit = WKDBConst.readString(row, 'content_edit');
    if (searchableWord.trim().isEmpty && contentEdit.trim().isEmpty) {
      return;
    }
    await db.insert(
      WKDBConst.tableMessageFts,
      <String, Object?>{
        'rowid': clientSeq,
        'client_seq': clientSeq,
        'message_id': WKDBConst.readString(row, 'message_id'),
        'channel_id': WKDBConst.readString(row, 'channel_id'),
        'channel_type': WKDBConst.readInt(row, 'channel_type'),
        'searchable_word': searchableWord,
        'content_edit': contentEdit,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WKMessageSearchResult>> search(String keyword) async {
    List<WKMessageSearchResult> list = [];
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return list;
    }
    final ftsQuery = buildMessageFtsQuery(keyword);
    final likeSql = buildGlobalMessageLikeSearchSql();
    final likePattern = buildMessageLikePattern(keyword);
    if (ftsQuery.isEmpty && likePattern.isEmpty) {
      return list;
    }
    List<Map<String, Object?>> results;
    if (ftsQuery.isNotEmpty && await _messageFtsTableExists(database)) {
      try {
        results = await database.rawQuery(
          buildGlobalMessageFtsSearchSql(),
          [ftsQuery],
        );
      } catch (_) {
        results = await database.rawQuery(likeSql, [likePattern, likePattern]);
      }
    } else {
      results = await database.rawQuery(likeSql, [likePattern, likePattern]);
    }
    for (Map<String, Object?> data in results) {
      var channel = WKDBConst.serializeChannel(data);
      var message = WKMessageSearchResult();
      message.channel = channel;
      message.messageCount = WKDBConst.readInt(data, 'message_count');
      message.searchableWord = WKDBConst.readString(data, 'searchable_word');
      list.add(message);
    }
    return list;
  }

  Future<List<WKMsg>> searchWithChannel(
      String keyword, String channelId, int channelType) async {
    List<WKMsg> list = [];
    final database = WKDBHelper.shared.getDB();
    if (database == null) {
      return list;
    }
    final ftsQuery = buildMessageFtsQuery(keyword);
    final likeSql = buildChannelMessageLikeSearchSql(
      messageCols: messageCols,
      extraCols: extraCols,
    );
    final likePattern = buildMessageLikePattern(keyword);
    if (ftsQuery.isEmpty && likePattern.isEmpty) {
      return list;
    }
    List<Map<String, Object?>> results;
    if (ftsQuery.isNotEmpty && await _messageFtsTableExists(database)) {
      try {
        results = await database.rawQuery(
          buildChannelMessageFtsSearchSql(
            messageCols: messageCols.replaceAll(
              '${WKDBConst.tableMessage}.',
              'm.',
            ),
            extraCols: extraCols.replaceAll(
              '${WKDBConst.tableMessageExtra}.',
              'me.',
            ),
          ),
          [ftsQuery, channelId, channelType],
        );
      } catch (_) {
        results = await database.rawQuery(
          likeSql,
          [likePattern, likePattern, channelId, channelType],
        );
      }
    } else {
      results = await database.rawQuery(
        likeSql,
        [likePattern, likePattern, channelId, channelType],
      );
    }
    List<String> fromUIDs = [];
    WKChannel? channel =
        await WKIM.shared.channelManager.getChannel(channelId, channelType);

    for (Map<String, Object?> data in results) {
      var msg = WKDBConst.serializeWKMsg(data);
      if (channel != null) {
        msg.setChannelInfo(channel);
      }
      if (msg.fromUID != '') {
        fromUIDs.add(msg.fromUID);
      }
      list.add(msg);
    }
    if (fromUIDs.isNotEmpty) {
      List<String> uniqueList = fromUIDs.toSet().toList();
      List<WKChannel> wkChannels = await ChannelDB.shared
          .queryWithChannelIdsAndChannelType(
              uniqueList, WKChannelType.personal);
      if (wkChannels.isNotEmpty) {
        final channelsByUid = indexByNonEmptyKey<WKChannel>(
          wkChannels,
          (channel) => channel.channelID,
        );
        for (final msg in list) {
          final channel = channelsByUid[msg.fromUID.trim()];
          if (channel != null) {
            msg.setFrom(channel);
          }
        }
      }

      if (channelType == WKChannelType.group) {
        List<WKChannelMember> members = await ChannelMemberDB.shared
            .queryMemberWithUIDs(channelId, channelType, uniqueList);
        if (members.isNotEmpty) {
          final membersByUid = indexByNonEmptyKey<WKChannelMember>(
            members,
            (member) => member.memberUID,
          );
          for (final msg in list) {
            final member = membersByUid[msg.fromUID.trim()];
            if (member != null) {
              msg.setMemberOfFrom(member);
            }
          }
        }
      }
    }
    return list;
  }

  Future<List<WKMsg>> searchMsgWithChannelAndContentTypes(
      String channelID,
      int channelType,
      int oldestOrderSeq,
      int limit,
      List<int> contentTypes) async {
    var sql = "";
    List<WKMsg> list = [];
    List<Object?> arguments = [];
    if (oldestOrderSeq <= 0) {
      arguments = [channelID, channelType, contentTypes];
      sql =
          "select * from (select $messageCols,$extraCols from ${WKDBConst.tableMessage} left join ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id where ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 and ${WKDBConst.tableMessage}.type in (${WKDBConst.getPlaceholders(contentTypes.length)})) where is_deleted=0 and revoke=0 order by order_seq desc limit 0,$limit";
    } else {
      arguments = [channelID, channelType, oldestOrderSeq, contentTypes];
      sql =
          "select * from (select $messageCols,$extraCols from ${WKDBConst.tableMessage} left join ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id where ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.order_seq<? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 and ${WKDBConst.tableMessage}.type in (${WKDBConst.getPlaceholders(contentTypes.length)})) where is_deleted=0 and revoke=0 order by order_seq desc limit 0,$limit";
    }
    List<Map<String, Object?>> results =
        await WKDBHelper.shared.getDB()!.rawQuery(sql, arguments);
    List<String> fromUIDs = [];
    WKChannel? channel =
        await WKIM.shared.channelManager.getChannel(channelID, channelType);

    for (Map<String, Object?> data in results) {
      var msg = WKDBConst.serializeWKMsg(data);
      if (channel != null) {
        msg.setChannelInfo(channel);
      }
      if (msg.fromUID != '') {
        fromUIDs.add(msg.fromUID);
      }
      list.add(msg);
    }
    if (fromUIDs.isNotEmpty) {
      List<String> uniqueList = fromUIDs.toSet().toList();
      List<WKChannel> wkChannels = await ChannelDB.shared
          .queryWithChannelIdsAndChannelType(
              uniqueList, WKChannelType.personal);
      if (wkChannels.isNotEmpty) {
        final channelsByUid = indexByNonEmptyKey<WKChannel>(
          wkChannels,
          (channel) => channel.channelID,
        );
        for (final msg in list) {
          final channel = channelsByUid[msg.fromUID.trim()];
          if (channel != null) {
            msg.setFrom(channel);
          }
        }
      }

      if (channelType == WKChannelType.group) {
        List<WKChannelMember> members = await ChannelMemberDB.shared
            .queryMemberWithUIDs(channelID, channelType, uniqueList);
        if (members.isNotEmpty) {
          final membersByUid = indexByNonEmptyKey<WKChannelMember>(
            members,
            (member) => member.memberUID,
          );
          for (final msg in list) {
            final member = membersByUid[msg.fromUID.trim()];
            if (member != null) {
              msg.setMemberOfFrom(member);
            }
          }
        }
      }
    }
    return list;
  }

  dynamic getMap(WKMsg msg) {
    var map = <String, Object>{};
    map['message_id'] = msg.messageID;
    map['server_msg_id'] = msg.serverMsgID;
    map['message_seq'] = msg.messageSeq;
    map['order_seq'] = msg.orderSeq;
    map['timestamp'] = msg.timestamp;
    map['from_uid'] = msg.fromUID;
    map['channel_id'] = msg.channelID;
    map['channel_type'] = msg.channelType;
    map['is_deleted'] = msg.isDeleted;
    map['type'] = msg.contentType;
    map['content'] = msg.content;
    map['status'] = msg.status;
    map['voice_status'] = msg.voiceStatus;
    map['client_msg_no'] = msg.clientMsgNO;
    map['flame'] = msg.flame;
    map['flame_second'] = msg.flameSecond;
    map['viewed'] = msg.viewed;
    map['viewed_at'] = msg.viewedAt;
    map['topic_id'] = msg.topicID;
    map['expire_time'] = msg.expireTime;
    map['expire_timestamp'] = msg.expireTimestamp;
    if (msg.messageContent != null) {
      map['searchable_word'] = msg.messageContent!.searchableWord();
    } else {
      map['searchable_word'] = '';
    }
    // 这里有错误数据，需要清理
    var len = msg.localExtraMap?.toString().length ?? 0;
    if (len < 1000000) {
      map['extra'] = msg.localExtraMap?.toString() ?? "";
    } else {
      map['extra'] = '';
    }
    map['setting'] = msg.setting.encode();
    return map;
  }

  dynamic getExtraMap(WKMsgExtra extra) {
    var map = <String, Object>{};
    map['channel_id'] = extra.channelID;
    map['channel_type'] = extra.channelType;
    map['readed'] = extra.readed;
    map['readed_count'] = extra.readedCount;
    map['unread_count'] = extra.unreadCount;
    map['revoke'] = extra.revoke;
    map['revoker'] = extra.revoker;
    map['extra_version'] = extra.extraVersion;
    map['is_mutual_deleted'] = extra.isMutualDeleted;
    map['content_edit'] = extra.contentEdit;
    map['edited_at'] = extra.editedAt;
    map['need_upload'] = extra.needUpload;
    map['message_id'] = extra.messageID;
    map['is_pinned'] = extra.isPinned;
    return map;
  }

  String _resolveSearchableWordFromContentEdit(String contentEdit) {
    final normalizedContentEdit = contentEdit.trim();
    if (normalizedContentEdit.isEmpty) {
      return '';
    }
    try {
      final decoded = jsonDecode(normalizedContentEdit);
      if (decoded is Map<String, dynamic>) {
        final type = WKDBConst.readInt(decoded, 'type');
        final contentType = type == 0 ? WkMessageContentType.text : type;
        final messageContent = WKIM.shared.messageManager.getMessageModel(
          contentType,
          decoded,
        );
        final searchableWord = messageContent?.searchableWord().trim() ?? '';
        if (searchableWord.isNotEmpty) {
          return searchableWord;
        }
        return WKDBConst.readString(decoded, 'content');
      }
    } catch (_) {}
    return '';
  }
}

class _DecodedBackupArchive {
  const _DecodedBackupArchive({
    required this.schemaVersion,
    required this.messages,
  });

  final int schemaVersion;
  final List<dynamic> messages;
}
