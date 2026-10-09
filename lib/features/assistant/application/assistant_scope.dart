// Keep these checks aligned with server/src/assistant_boundary.ts.
final _forbidden = RegExp(
  r'```|(?:忽略|绕过|无视).*(?:规则|限制|权限|指令)|(?:泄露|输出|显示|告诉).*(?:提示词|密钥|system\s*prompt)|提示词|system\s*prompt|(?:写|编写|生成|提供|执行|运行|write).*(?:代码|脚本|程序|函数|code|python|javascript|sql)|(?:写|生成|翻译).*(?:作文|小说|文章)|ignore.*(?:instructions|rules)',
  caseSensitive: false,
);
final _bookkeeping = RegExp(
  r'记账|账单|账本|预算|收支|收入|支出|消费|花费|花了|开销|花销|花钱|支付|付款|账户|余额|金额|交易|小票|商户|分类|统计|报表|导出|导入|会员|权益|套餐|退款|报销|转账|还款|贷款|信用卡|存款|储蓄|工资|人民币|早餐|午餐|晚餐|吃饭|咖啡|奶茶|公交|地铁|打车|购物|房租|超市|[0-9]+(?:\.[0-9]+)?\s*(?:元|块)|你好|帮助|能做什么|怎么使用|什么功能',
);
bool assistantOutOfScope(String text) =>
    _forbidden.hasMatch(text) || !_bookkeeping.hasMatch(text);
String? assistantQueryFeature(String text) => text.contains('导出')
    ? 'export'
    : RegExp(r'收支|收入|支出|消费|花费|花了|开销|花销|花钱|结余|餐饮|购物|交通').hasMatch(text) &&
          (RegExp(r'查询|查一下|查看|看看|看一下|统计|多少|为什么|总结|分析|建议|省钱|节省')
                  .hasMatch(text) ||
              RegExp(r'(?:最近|近|过去)\s*[0-9]+\s*天').hasMatch(text) ||
              (!RegExp(r'\d').hasMatch(text) &&
                  RegExp(
                    r'今天|昨天|本月|这个月|上月|上个月|本周|这周|上周|今年|最近|近期|近一个月|过去一个月|近一周|过去一周|近三个月',
                  ).hasMatch(text)))
    ? 'summary'
    : null;
