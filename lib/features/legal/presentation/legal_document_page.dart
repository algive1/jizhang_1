import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';

enum LegalDocumentKind { membership, privacy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.kind});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context) {
    final document = kind == LegalDocumentKind.membership
        ? _membershipDocument
        : _privacyDocument;
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text(document.title),
        backgroundColor: context.appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
        children: [
          Text(
            '好好记账 · ${document.updatedAt}',
            style: TextStyle(color: context.appSecondaryText, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            document.intro,
            style: TextStyle(color: context.appPrimaryText, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 16),
          for (final section in document.sections) ...[
            _LegalSectionCard(section: section),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class LegalDocumentsPage extends StatelessWidget {
  const LegalDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appBackground,
    appBar: AppBar(
      title: const Text('服务协议'),
      backgroundColor: context.appBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
      children: [
        Text(
          '请点击查看对应协议内容，阅读后点击“确定”关闭。',
          style: TextStyle(
            color: context.appSecondaryText,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _AgreementMenuCard(
          document: _userDocument,
          onTap: () => _showDocument(context, _userDocument),
        ),
        const SizedBox(height: 10),
        _AgreementMenuCard(
          document: _privacyDocument,
          onTap: () => _showDocument(context, _privacyDocument),
        ),
        const SizedBox(height: 10),
        _AgreementMenuCard(
          document: _membershipDocument,
          onTap: () => _showDocument(context, _membershipDocument),
        ),
      ],
    ),
  );

  static Future<void> _showDocument(
    BuildContext context,
    _LegalDocument document,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(document.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.intro,
              style: TextStyle(color: context.appPrimaryText, height: 1.55),
            ),
            const SizedBox(height: 14),
            for (final section in document.sections) ...[
              Text(
                section.title,
                style: TextStyle(
                  color: context.appPrimaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section.body,
                style: TextStyle(color: context.appSecondaryText, height: 1.55),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

class _AgreementMenuCard extends StatelessWidget {
  const _AgreementMenuCard({required this.document, required this.onTap});

  final _LegalDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.appSurface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: context.appPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: TextStyle(
                      color: context.appPrimaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    document.updatedAt,
                    style: TextStyle(color: context.appSecondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appSecondaryText),
          ],
        ),
      ),
    ),
  );
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
    decoration: BoxDecoration(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appDivider),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C283D27),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: TextStyle(
            color: context.appPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          section.body,
          style: TextStyle(
            color: context.appSecondaryText,
            fontSize: 13,
            height: 1.65,
          ),
        ),
      ],
    ),
  );
}

class _LegalDocument {
  const _LegalDocument({
    required this.title,
    required this.updatedAt,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final String intro;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}

const _membershipDocument = _LegalDocument(
  title: '会员服务协议',
  updatedAt: '会员服务协议 · 2026 年 9 月更新',
  intro: '感谢你使用好好记账会员服务。本协议说明会员权益、订单支付、有效期和使用规则。购买或使用会员服务前，请阅读并理解以下内容。',
  sections: [
    _LegalSection(
      '一、服务内容',
      '会员服务以你购买的商品周期为有效期，具体套餐、价格和权益范围以开通页面及服务端订单记录为准。会员权益与账号绑定，登录同一账号后可在支持的设备上使用已开放的权益。',
    ),
    _LegalSection(
      '二、订单与支付',
      '订单金额由服务端商品目录确认，应用不会在客户端自行修改价格。你选择微信支付或支付宝支付后，将跳转至对应支付客户端完成付款；支付结果以支付渠道和服务端验签结果为准。',
    ),
    _LegalSection(
      '三、退款与到期',
      '退款申请需要提供订单号，并遵循实际支付渠道及适用法律法规的处理规则。会员到期不会主动删除已有记账数据，会员功能按届时开放范围处理；建议定期导出数据备份。',
    ),
    _LegalSection(
      '四、权益使用',
      '会员权益仅限本人账号使用。不得通过转让账号、破解、批量请求或其他影响服务安全的方式获取权益。发现异常使用时，我们可能先暂停相关服务并联系你核实。',
    ),
    _LegalSection(
      '五、服务变更',
      '我们会根据产品迭代、系统能力和法律法规调整服务内容。涉及价格、有效期或核心权益的变化，会在开通页面或应用内以适当方式说明；已生效订单按下单时确认的商品规则处理。',
    ),
    _LegalSection(
      '六、联系我们',
      '如需查询订单、申请退款或反馈会员问题，请在应用内提交订单号、发生时间和问题描述。当前版本尚未接入在线客服，具体处理进度以应用内后续通知为准。',
    ),
  ],
);

const _userDocument = _LegalDocument(
  title: '用户协议',
  updatedAt: '用户协议 · 2026 年 9 月更新',
  intro: '使用好好记账前，请确认你会遵守适用法律法规，并对自己创建、保存和分享的内容负责。',
  sections: [
    _LegalSection(
      '一、账号与设备',
      '你可以在本地使用基础记账功能。登录后应妥善保管账号信息，不得冒用他人身份或通过自动化方式干扰服务。',
    ),
    _LegalSection(
      '二、内容与数据',
      '你创建的账本、分类、流水和附件归你管理。请定期导出备份，并确保分享内容不侵犯他人隐私、知识产权或其他合法权益。',
    ),
    _LegalSection(
      '三、服务使用',
      '不得利用本应用从事违法活动、传播恶意内容、攻击服务或绕过权限校验。违反规则时，我们会在必要范围内限制相关功能并保留处理记录。',
    ),
    _LegalSection('四、服务更新', '应用会持续修复问题和更新功能。页面展示的功能范围、系统要求和第三方服务可用性可能随版本变化。'),
  ],
);

const _privacyDocument = _LegalDocument(
  title: '隐私协议',
  updatedAt: '隐私协议 · 2026 年 9 月更新',
  intro: '好好记账坚持本地优先。我们只在提供登录、同步、会员支付和应用功能所必需的范围内处理信息，并尽量让数据留在你的设备上。',
  sections: [
    _LegalSection(
      '一、我们处理哪些信息',
      '本地记账数据、账本、分类和附件默认保存在设备本地。使用登录、共享账本、云同步或会员服务时，我们会处理账号标识、订单信息、商品和支付状态，以及完成服务所需的设备和网络日志。',
    ),
    _LegalSection(
      '二、信息如何使用',
      '我们使用上述信息提供记账、同步、订单查询、会员权益校验、风险控制和故障排查服务。不会把你的记账内容用于与这些目的无关的广告画像。',
    ),
    _LegalSection(
      '三、支付与第三方服务',
      '支付由你选择的微信支付或支付宝支付处理。应用只接收创建订单、支付结果和服务端验签所需的结果信息，不保存支付账户的密码或完整银行卡信息。',
    ),
    _LegalSection(
      '四、保存与删除',
      '本地数据由你通过应用管理。云端账号和订单信息会在提供服务、处理争议及履行法定义务所需的期限内保存；你可以通过应用反馈申请查询或删除可删除的信息。',
    ),
    _LegalSection(
      '五、你的权利',
      '你可以查看、导出和管理本地账本数据，也可以在支持的功能中管理登录、同步及通知权限。关闭系统权限后，对应功能可能无法继续工作，但不会影响已保存在本机的数据。',
    ),
    _LegalSection(
      '六、可选使用情况统计',
      '使用情况统计默认关闭。只有你在“数据与安全”中主动开启后，我们才会使用随机生成的匿名安装标识记录应用打开、页面访问和功能是否成功使用等非财务事件。统计不会包含金额、商户、备注、分类名称、附件路径、账户信息或具体流水内容；你可以随时关闭，关闭后不再上传新的使用事件。',
    ),
    _LegalSection(
      '七、联系我们',
      '如果你对隐私处理有疑问，请在应用内反馈时注明“隐私问题”，并提供必要的账号或订单信息。我们会在核实身份后处理相关请求。',
    ),
  ],
);
