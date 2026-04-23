/// Provides Chinese character to Pinyin conversion for sorting and searching.
class PinyinUtils {
  /// Convert Chinese text to Pinyin
  /// 
  /// Returns the pinyin representation of the Chinese text.
  /// Falls back to original text for non-Chinese characters.
  static String toPinyin(String text) {
    if (text.isEmpty) return '';
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final pinyin = _getPinyin(char);
      buffer.write(pinyin);
    }
    return buffer.toString();
  }

  /// Get the first letter of pinyin
  static String getFirstLetter(String text) {
    if (text.isEmpty) return '';
    
    final char = text[0];
    final pinyin = _getPinyin(char);
    if (pinyin.isEmpty) return char.toUpperCase();
    return pinyin[0].toUpperCase();
  }

  /// Get initials (first letters) of all words
  static String getInitials(String text) {
    if (text.isEmpty) return '';
    
    final buffer = StringBuffer();
    bool lastIsChinese = false;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final isChinese = _isChinese(char);
      
      if (isChinese) {
        if (!lastIsChinese || i == 0) {
          buffer.write(getFirstLetter(char));
        }
      } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        if (!lastIsChinese || i == 0) {
          buffer.write(char.toUpperCase());
        }
      }
      
      lastIsChinese = isChinese;
    }
    
    return buffer.toString();
  }

  /// Check if a character is Chinese
  static bool _isChinese(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  /// Get pinyin for a single Chinese character
  /// 
  /// This is a simplified implementation. For production,
  /// use a proper pinyin library.
  static String _getPinyin(String char) {
    // Simplified pinyin lookup table for common characters
    // In production, use a proper Chinese pinyin library
    final pinyinMap = <String, String>{
      // Common characters
      '啊': 'a', '阿': 'a', '爱': 'ai', '安': 'an', '暗': 'an',
      '八': 'ba', '把': 'ba', '吧': 'ba', '白': 'bai', '百': 'bai',
      '班': 'ban', '半': 'ban', '办': 'ban', '帮': 'bang',
      '包': 'bao', '保': 'bao', '报': 'bao', '北': 'bei',
      '被': 'bei', '比': 'bi', '笔': 'bi', '必': 'bi',
      '边': 'bian', '变': 'bian', '别': 'bie', '病': 'bing',
      '不': 'bu', '步': 'bu', '部': 'bu', '布': 'bu',
      '才': 'cai', '菜': 'cai', '参': 'can', '操': 'cao',
      '测': 'ce', '层': 'ceng', '查': 'cha', '茶': 'cha',
      '差': 'cha', '常': 'chang', '场': 'chang', '唱': 'chang',
      '车': 'che', '陈': 'chen', '城': 'cheng', '成': 'cheng',
      '吃': 'chi', '持': 'chi', '出': 'chu', '初': 'chu',
      '除': 'chu', '楚': 'chu', '传': 'chuan', '创': 'chuang',
      '春': 'chun', '词': 'ci', '此': 'ci', '次': 'ci',
      '从': 'cong', '村': 'cun', '错': 'cuo', '打': 'da',
      '大': 'da', '带': 'dai', '代': 'dai', '单': 'dan',
      '但': 'dan', '蛋': 'dan', '道': 'dao', '到': 'dao',
      '得': 'de', '灯': 'deng', '等': 'deng', '低': 'di',
      '底': 'di', '点': 'dian', '电': 'dian', '店': 'dian',
      '调': 'diao', '掉': 'diao', '顶': 'ding', '定': 'ding',
      '丢': 'diu', '东': 'dong', '冬': 'dong', '懂': 'dong',
      '动': 'dong', '都': 'dou', '读': 'du', '短': 'duan',
      '段': 'duan', '对': 'dui', '队': 'dui', '多': 'duo',
      '夺': 'duo', '饿': 'e', '儿': 'er', '耳': 'er',
      '二': 'er', '发': 'fa', '法': 'fa', '翻': 'fan',
      '反': 'fan', '返': 'fan', '犯': 'fan', '饭': 'fan',
      '方': 'fang', '房': 'fang', '放': 'fang', '非': 'fei',
      '飞': 'fei', '费': 'fei', '分': 'fen', '份': 'fen',
      '风': 'feng', '封': 'feng', '服': 'fu', '福': 'fu',
      '父': 'fu', '付': 'fu', '附': 'fu', '复': 'fu',
      '该': 'gai', '改': 'gai', '干': 'gan', '感': 'gan',
      '刚': 'gang', '高': 'gao', '告': 'gao', '哥': 'ge',
      '歌': 'ge', '个': 'ge', '给': 'gei', '跟': 'gen',
      '更': 'geng', '工': 'gong', '公': 'gong', '共': 'gong',
      '够': 'gou', '古': 'gu', '故': 'gu', '瓜': 'gua',
      '挂': 'gua', '关': 'guan', '管': 'guan', '光': 'guang',
      '广': 'guang', '贵': 'gui', '国': 'guo', '果': 'guo',
      '过': 'guo', '还': 'hai', '孩': 'hai', '海': 'hai',
      '害': 'hai', '汉': 'han', '好': 'hao',
      '喝': 'he', '合': 'he', '何': 'he',
      '和': 'he', '河': 'he', '黑': 'hei', '很': 'hen',
      '红': 'hong', '后': 'hou', '候': 'hou', '呼': 'hu',
      '忽': 'hu', '湖': 'hu', '虎': 'hu', '护': 'hu',
      '互': 'hu', '户': 'hu', '花': 'hua', '化': 'hua',
      '话': 'hua', '华': 'hua', '划': 'hua', '画': 'hua',
      '怀': 'huai', '坏': 'huai', '欢': 'huan', '换': 'huan',
      '黄': 'huang', '回': 'hui', '会': 'hui',
      '汇': 'hui', '活': 'huo', '火': 'huo', '或': 'huo',
      '货': 'huo', '机': 'ji', '鸡': 'ji', '级': 'ji',
      '极': 'ji', '几': 'ji', '己': 'ji', '记': 'ji',
      '纪': 'ji', '季': 'ji', '继': 'ji', '济': 'ji',
      '家': 'jia', '加': 'jia', '价': 'jia', '架': 'jia',
      '假': 'jia', '嫁': 'jia', '件': 'jian', '建': 'jian',
      '键': 'jian', '江': 'jiang', '讲': 'jiang', '交': 'jiao',
      '脚': 'jiao', '叫': 'jiao', '街': 'jie', '节': 'jie',
      '姐': 'jie', '今': 'jin', '金': 'jin', '近': 'jin',
      '进': 'jin', '劲': 'jin', '京': 'jing', '经': 'jing',
      '精': 'jing', '井': 'jing', '静': 'jing', '九': 'jiu',
      '久': 'jiu', '酒': 'jiu', '旧': 'jiu', '就': 'jiu',
      '举': 'ju', '句': 'ju', '剧': 'ju', '聚': 'ju',
      '觉': 'jue', '绝': 'jue', '开': 'kai', '看': 'kan',
      '康': 'kang', '考': 'kao', '靠': 'kao', '科': 'ke',
      '可': 'ke', '刻': 'ke', '客': 'ke', '空': 'kong', '恐': 'kong', '口': 'kou',
      '哭': 'ku', '苦': 'ku', '快': 'kuai', '块': 'kuai',
      '宽': 'kuan', '况': 'kuang', '矿': 'kuang', '亏': 'kui',
      '愧': 'kui', '昆': 'kun', '困': 'kun', '拉': 'la',
      '落': 'la', '来': 'lai', '兰': 'lan', '蓝': 'lan',
      '老': 'lao', '乐': 'le', '雷': 'lei', '累': 'lei',
      '冷': 'leng', '离': 'li', '里': 'li', '理': 'li',
      '礼': 'li', '力': 'li', '历': 'li', '立': 'li',
      '利': 'li', '连': 'lian', '脸': 'lian', '练': 'lian',
      '凉': 'liang', '两': 'liang', '亮': 'liang', '量': 'liang',
      '林': 'lin', '临': 'lin', '灵': 'ling', '零': 'ling',
      '领': 'ling', '另': 'ling', '留': 'liu', '流': 'liu',
      '六': 'liu', '龙': 'long', '楼': 'lou', '路': 'lu',
      '旅': 'lv', '绿': 'lv', '妈': 'ma', '马': 'ma',
      '吗': 'ma', '买': 'mai', '卖': 'mai', '慢': 'man',
      '满': 'man', '忙': 'mang', '毛': 'mao', '没': 'mei',
      '每': 'mei', '美': 'mei', '妹': 'mei', '门': 'men',
      '们': 'men', '迷': 'mi', '米': 'mi', '面': 'mian',
      '民': 'min', '明': 'ming', '名': 'ming', '命': 'ming',
      '母': 'mu', '木': 'mu', '目': 'mu', '拿': 'na',
      '哪': 'na', '那': 'na', '奶': 'nai', '男': 'nan',
      '南': 'nan', '呢': 'ne', '内': 'nei', '能': 'neng',
      '你': 'ni', '年': 'nian', '念': 'nian', '娘': 'niang',
      '鸟': 'niao', '您': 'nin', '牛': 'niu', '农': 'nong',
      '弄': 'nong', '女': 'nv', '暖': 'nuan', '欧': 'ou',
      '怕': 'pa', '拍': 'pai', '排': 'pai', '派': 'pai',
      '盘': 'pan', '旁': 'pang', '跑': 'pao', '朋': 'peng',
      '皮': 'pi', '偏': 'pian', '片': 'pian', '票': 'piao',
      '漂': 'piao', '品': 'pin', '平': 'ping', '苹': 'ping',
      '凭': 'ping', '破': 'po', '迫': 'po', '铺': 'pu',
      '葡': 'pu', '普': 'pu', '七': 'qi', '期': 'qi',
      '其': 'qi', '奇': 'qi', '骑': 'qi', '起': 'qi',
      '气': 'qi', '汽': 'qi', '器': 'qi', '恰': 'qia',
      '千': 'qian', '前': 'qian', '钱': 'qian', '浅': 'qian',
      '强': 'qiang', '墙': 'qiang', '桥': 'qiao', '巧': 'qiao',
      '青': 'qing', '轻': 'qing', '清': 'qing', '晴': 'qing',
      '情': 'qing', '请': 'qing', '秋': 'qiu', '球': 'qiu',
      '求': 'qiu', '区': 'qu', '去': 'qu', '全': 'quan',
      '却': 'que', '群': 'qun', '然': 'ran', '让': 'rang',
      '热': 're', '人': 'ren', '认': 'ren', '日': 'ri',
      '容': 'rong', '肉': 'rou', '如': 'ru', '入': 'ru',
      '软': 'ruan', '锐': 'rui', '润': 'run', '若': 'ruo',
      '三': 'san', '散': 'san', '色': 'se', '山': 'shan',
      '上': 'shang', '少': 'shao', '社': 'she', '身': 'shen',
      '深': 'shen', '什': 'shen', '生': 'sheng', '声': 'sheng',
      '省': 'sheng', '胜': 'sheng', '师': 'shi', '失': 'shi',
      '施': 'shi', '湿': 'shi', '十': 'shi', '时': 'shi',
      '实': 'shi', '食': 'shi', '始': 'shi', '使': 'shi',
      '世': 'shi', '市': 'shi', '事': 'shi', '是': 'shi',
      '室': 'shi', '试': 'shi', '视': 'shi', '收': 'shou',
      '手': 'shou', '首': 'shou', '受': 'shou', '书': 'shu',
      '树': 'shu', '双': 'shuang', '水': 'shui', '睡': 'shui',
      '顺': 'shun', '思': 'si', '死': 'si', '四': 'si',
      '送': 'song', '诉': 'su', '速': 'su', '虽': 'sui',
      '岁': 'sui', '所': 'suo', '他': 'ta', '她': 'ta',
      '它': 'ta', '太': 'tai', '态': 'tai', '台': 'tai',
      '抬': 'tai', '谈': 'tan', '汤': 'tang', '糖': 'tang',
      '特': 'te', '疼': 'teng', '提': 'ti', '题': 'ti',
      '体': 'ti', '替': 'ti', '天': 'tian', '田': 'tian',
      '甜': 'tian', '填': 'tian', '跳': 'tiao', '贴': 'tie',
      '铁': 'tie', '听': 'ting', '停': 'ting', '通': 'tong',
      '同': 'tong', '头': 'tou', '透': 'tou', '突': 'tu',
      '图': 'tu', '土': 'tu', '团': 'tuan', '推': 'tui',
      '腿': 'tui', '外': 'wai', '玩': 'wan', '完': 'wan',
      '晚': 'wan', '万': 'wan', '王': 'wang', '往': 'wang',
      '网': 'wang', '望': 'wang', '危': 'wei', '微': 'wei',
      '为': 'wei', '未': 'wei', '位': 'wei', '文': 'wen',
      '问': 'wen', '我': 'wo', '握': 'wo', '屋': 'wu',
      '五': 'wu', '午': 'wu', '物': 'wu', '务': 'wu',
      '误': 'wu', '西': 'xi', '息': 'xi', '希': 'xi',
      '习': 'xi', '洗': 'xi', '喜': 'xi', '系': 'xi',
      '细': 'xi', '下': 'xia', '夏': 'xia', '先': 'xian',
      '现': 'xian', '线': 'xian', '想': 'xiang', '向': 'xiang',
      '象': 'xiang', '像': 'xiang', '小': 'xiao', '校': 'xiao',
      '笑': 'xiao', '些': 'xie', '写': 'xie', '谢': 'xie',
      '心': 'xin', '新': 'xin', '信': 'xin', '星': 'xing',
      '行': 'xing', '形': 'xing', '醒': 'xing', '姓': 'xing',
      '休': 'xiu', '修': 'xiu', '需': 'xu', '许': 'xu',
      '学': 'xue', '雪': 'xue', '讯': 'xun', '迅': 'xun',
      '压': 'ya', '牙': 'ya', '言': 'yan', '研': 'yan',
      '眼': 'yan', '演': 'yan', '阳': 'yang', '养': 'yang',
      '样': 'yang', '药': 'yao', '要': 'yao', '爷': 'ye',
      '也': 'ye', '页': 'ye', '业': 'ye', '夜': 'ye',
      '叶': 'ye', '一': 'yi', '医': 'yi', '衣': 'yi',
      '以': 'yi', '已': 'yi', '意': 'yi', '易': 'yi',
      '因': 'yin', '音': 'yin', '银': 'yin', '印': 'yin',
      '应': 'ying', '英': 'ying', '影': 'ying', '用': 'yong',
      '永': 'yong', '泳': 'yong', '勇': 'yong', '涌': 'yong',
      '由': 'you', '油': 'you', '游': 'you', '友': 'you',
      '有': 'you', '又': 'you', '右': 'you', '鱼': 'yu',
      '雨': 'yu', '语': 'yu', '元': 'yuan', '原': 'yuan',
      '园': 'yuan', '远': 'yuan', '院': 'yuan', '愿': 'yuan',
      '月': 'yue', '越': 'yue', '云': 'yun', '运': 'yun',
      '杂': 'za', '再': 'zai', '在': 'zai', '咱': 'zan',
      '早': 'zao', '怎': 'zen', '增': 'zeng', '扎': 'zha',
      '炸': 'zha', '张': 'zhang', '掌': 'zhang', '找': 'zhao',
      '照': 'zhao', '者': 'zhe', '这': 'zhe', '真': 'zhen',
      '正': 'zheng', '政': 'zheng', '知': 'zhi', '之': 'zhi',
      '只': 'zhi', '纸': 'zhi', '指': 'zhi', '至': 'zhi',
      '治': 'zhi', '中': 'zhong', '钟': 'zhong', '终': 'zhong',
      '种': 'zhong', '重': 'zhong', '周': 'zhou', '洲': 'zhou',
      '主': 'zhu', '住': 'zhu', '注': 'zhu', '祝': 'zhu',
      '猪': 'zhu', '专': 'zhuan', '转': 'zhuan', '装': 'zhuang',
      '准': 'zhun', '桌': 'zhuo', '着': 'zhuo', '字': 'zi',
      '自': 'zi', '宗': 'zong', '走': 'zou', '租': 'zu',
      '足': 'zu', '组': 'zu', '祖': 'zu', '最': 'zui',
      '昨': 'zuo', '左': 'zuo', '作': 'zuo', '坐': 'zuo',
      '做': 'zuo', '座': 'zuo',
    };

    return pinyinMap[char] ?? char;
  }
}
