String buildMessageFtsQuery(String keyword) {
  final terms = keyword
      .trim()
      .split(RegExp(r'\s+'))
      .map((term) => term.replaceAll('"', '').trim())
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
  if (terms.isEmpty) {
    return '';
  }
  return terms.asMap().entries.map((entry) {
    final quoted = '"${entry.value}"';
    return entry.key == terms.length - 1 ? '$quoted*' : quoted;
  }).join(' ');
}

String buildMessageLikePattern(String keyword) {
  final escaped = keyword
      .trim()
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  if (escaped.isEmpty) {
    return '';
  }
  return '%$escaped%';
}

String buildGlobalMessageFtsSearchSql() {
  return "select distinct c.*, count(*) message_count, "
      "case count(*) WHEN 1 then m.client_seq else '' END client_seq, "
      "CASE count(*) WHEN 1 THEN m.searchable_word else '' end searchable_word "
      "from message_fts "
      "JOIN message m ON m.client_seq = message_fts.client_seq "
      "LEFT JOIN channel c ON m.channel_id = c.channel_id "
      "and m.channel_type = c.channel_type "
      "LEFT JOIN message_extra me ON m.message_id = me.message_id "
      "WHERE m.is_deleted=0 and message_fts MATCH ? "
      "GROUP BY c.channel_id, c.channel_type "
      "ORDER BY m.created_at DESC limit 100";
}

String buildGlobalMessageLikeSearchSql() {
  return "select distinct c.*, count(*) message_count, "
      "case count(*) WHEN 1 then m.client_seq else ''END client_seq, "
      "CASE count(*) WHEN 1 THEN m.searchable_word else '' end searchable_word "
      "from channel c "
      "LEFT JOIN message m ON m.channel_id = c.channel_id "
      "and m.channel_type = c.channel_type "
      "LEFT JOIN message_extra me ON m.message_id = me.message_id "
      "WHERE m.is_deleted=0 and "
      "(m.searchable_word LIKE ? ESCAPE '\\' "
      "or IFNULL(me.content_edit,'') LIKE ? ESCAPE '\\') "
      "GROUP BY c.channel_id, c.channel_type "
      "ORDER BY m.created_at DESC limit 100";
}

String buildChannelMessageFtsSearchSql({
  String messageCols = 'm.*',
  String extraCols =
      "IFNULL(me.readed,0) as readed,IFNULL(me.readed_count,0) as readed_count,"
          "IFNULL(me.unread_count,0) as unread_count,IFNULL(me.revoke,0) as revoke",
}) {
  final cols =
      extraCols.trim().isEmpty ? messageCols : '$messageCols,$extraCols';
  return "select * from (select $cols "
      "from message_fts "
      "JOIN message m ON m.client_seq = message_fts.client_seq "
      "LEFT JOIN message_extra me ON m.message_id = me.message_id "
      "where message_fts MATCH ? and m.channel_id=? and m.channel_type=?) "
      "where is_deleted=0 and revoke=0";
}

String buildChannelMessageLikeSearchSql({
  String messageCols = 'message.*',
  String extraCols = "IFNULL(message_extra.readed,0) as readed,"
      "IFNULL(message_extra.readed_count,0) as readed_count,"
      "IFNULL(message_extra.unread_count,0) as unread_count,"
      "IFNULL(message_extra.revoke,0) as revoke",
}) {
  final cols =
      extraCols.trim().isEmpty ? messageCols : '$messageCols,$extraCols';
  return "select * from (select $cols "
      "from message left join message_extra "
      "on message.message_id= message_extra.message_id "
      "where (message.searchable_word like ? ESCAPE '\\' "
      "or IFNULL(message_extra.content_edit,'') like ? ESCAPE '\\') "
      "and message.channel_id=? and message.channel_type=?) "
      "where is_deleted=0 and revoke=0";
}
