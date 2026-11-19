// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get rule => '规则';

  @override
  String get rules => '规则';

  @override
  String get global => '全局';

  @override
  String get direct => '直连';

  @override
  String get dashboard => '仪表盘';

  @override
  String get proxies => '代理';

  @override
  String get profile => '配置';

  @override
  String get profiles => '配置';

  @override
  String get tools => '工具';

  @override
  String get logs => '日志';

  @override
  String get resources => '资源';

  @override
  String get trafficUsage => '流量统计';

  @override
  String get networkSpeed => '网络速度';

  @override
  String get outboundMode => '出站模式';

  @override
  String get serviceStatus => '服务状态';

  @override
  String get serviceRestricted => '访问受限';

  @override
  String get serviceAvailable => '可用';

  @override
  String get serviceUnavailable => '不可用';

  @override
  String get serviceFailed => '检测失败';

  @override
  String get serviceDisallowedIsp => '不允许的 ISP';

  @override
  String get serviceBlocked => '已被封禁';

  @override
  String get serviceUnsupportedRegion => '地区不支持';

  @override
  String get serviceOriginalsOnly => '仅限自制内容';

  @override
  String get serviceComingSoon => '即将上线';

  @override
  String get servicePending => '待检测';

  @override
  String get serviceManage => '管理服务';

  @override
  String get serviceCheckAll => '全部检测';

  @override
  String get upload => '上传';

  @override
  String get download => '下载';

  @override
  String get usedTraffic => '已用流量';

  @override
  String get totalTraffic => '总流量';

  @override
  String get expireTime => '到期时间';

  @override
  String get nullProfileDesc => '添加一个配置文件后即可开始使用';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get defaultText => '默认';

  @override
  String get more => '更多';

  @override
  String get other => '其他';

  @override
  String get about => '关于';

  @override
  String get en => '英语';

  @override
  String get es => '西班牙语';

  @override
  String get fr => '法语';

  @override
  String get ja => '日语';

  @override
  String get ko => '韩语';

  @override
  String get ru => '俄语';

  @override
  String get zhCN => '中文简体';

  @override
  String get theme => '主题';

  @override
  String get extend => '扩展';

  @override
  String get runtimeConfig => '运行时配置';

  @override
  String get allowLan => '局域网代理';

  @override
  String get tun => '虚拟网卡';

  @override
  String get tunDesc => '虚拟网卡仅在管理员模式生效。';

  @override
  String get minimizeOnExit => '退出时最小化';

  @override
  String get autoLaunch => '自启动';

  @override
  String get loginItemRequiresApproval => '需要在系统设置中允许 Flash 登录时打开。';

  @override
  String get loginItemNotFound => 'macOS 找不到当前的 Flash，无法设置登录时打开。';

  @override
  String get loginItemUnexpectedStatus => '无法确认登录时打开是否已按所选设置更新。';

  @override
  String get loginItemMissingStatus => '无法读取登录时打开的状态。';

  @override
  String get loginItemOperationFailed => '无法更改登录时打开设置。';

  @override
  String get silentLaunch => '静默启动';

  @override
  String get autoRun => '自动运行';

  @override
  String get autoRunDesc => '自动运行会在打开应用时启动代理。';

  @override
  String get logcat => '日志捕获';

  @override
  String get logcatDesc => '关闭日志捕获会隐藏日志入口。';

  @override
  String get autoCheckUpdate => '自动检查更新';

  @override
  String get checkCertificate => '校验 TLS 证书';

  @override
  String get checkCertificateDesc => '关闭证书校验后，订阅和备份可能遭中间人攻击。';

  @override
  String get accessControl => '访问控制';

  @override
  String get edit => '编辑';

  @override
  String get confirm => '确定';

  @override
  String get update => '更新';

  @override
  String get add => '添加';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get seconds => '秒';

  @override
  String get qrcode => '二维码';

  @override
  String get qrcodeDesc => '扫描二维码获取配置文件';

  @override
  String get url => 'URL';

  @override
  String get link => '链接';

  @override
  String get file => '文件';

  @override
  String get name => '名称';

  @override
  String get profileNameNullValidationDesc => '请输入配置名称';

  @override
  String get rename => '重命名';

  @override
  String get profileUrlNullValidationDesc => '请输入配置URL';

  @override
  String get profileUrlInvalidValidationDesc => '请输入有效配置URL';

  @override
  String get autoUpdate => '自动更新';

  @override
  String get autoUpdateInterval => '自动更新间隔';

  @override
  String get profileAutoUpdateIntervalNullValidationDesc => '请输入自动更新间隔时间';

  @override
  String get profileAutoUpdateIntervalInvalidValidationDesc => '请输入有效间隔时间格式';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeColor => '主题色彩';

  @override
  String get preview => '预览';

  @override
  String get auto => '自动';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get importFromLink => '从链接导入';

  @override
  String get sendFromPhone => '从手机发送';

  @override
  String get sendFromPhoneTip => '用手机相机扫描二维码，在打开的页面里粘贴链接。两台设备需要连在同一个网络。';

  @override
  String get sendFromPhoneNoNetwork => '这台设备没有连接局域网';

  @override
  String get sendFromPhonePermissionDenied =>
      '从手机接收链接需要「附近的设备」权限，Flash 才能访问局域网。请在应用设置中开启。';

  @override
  String get sendFromPhonePageTitle => '把链接发送到 Flash';

  @override
  String get sendFromPhonePageHint => '订阅链接或代理分享链接';

  @override
  String get send => '发送';

  @override
  String get sendFromPhonePageSent => '已发送，请在另一台设备上确认导入。';

  @override
  String get sendFromPhoneConfirmTitle => '导入手机发来的链接？';

  @override
  String get shareQrcodeTip => '在另一台设备上用 Flash 扫码即可导入此配置。';

  @override
  String get qrcodeTooLongTip => '链接过长，无法生成二维码，请改用“复制链接”。';

  @override
  String get submit => '提交';

  @override
  String createProfileFromUrlTip(Object url) {
    return '是否要通过 $url 创建配置？';
  }

  @override
  String get create => '创建';

  @override
  String get pleaseUploadValidQrcode => '请上传有效的二维码';

  @override
  String get blacklistMode => '黑名单模式';

  @override
  String get whitelistMode => '白名单模式';

  @override
  String get selectAll => '全选';

  @override
  String get cancelSelectAll => '取消全选';

  @override
  String get appAccessControl => '应用访问控制';

  @override
  String get accessControlAllowDesc => '只允许选中应用进入VPN';

  @override
  String get accessControlNotAllowDesc => '选中应用将会被排除在VPN之外';

  @override
  String get accessControlDisabledDesc => '应用访问控制已关闭';

  @override
  String accessControlSelectedCount(num count) {
    return '已选 $count';
  }

  @override
  String get port => '端口';

  @override
  String get logLevel => '日志等级';

  @override
  String get show => '显示';

  @override
  String get exit => '退出';

  @override
  String get systemProxy => '系统代理';

  @override
  String get safeMode => '安全模式';

  @override
  String safeModeAppTitle(Object appName) {
    return '$appName（安全模式）';
  }

  @override
  String get project => 'FlClash 上游项目';

  @override
  String get upstreamTelegram => 'FlClash 上游 Telegram';

  @override
  String get core => '内核';

  @override
  String get tabAnimation => '选项卡动画';

  @override
  String get desc => '基于ClashMeta的多平台代理客户端，简单易用，开源无广告。';

  @override
  String get startVpn => '正在启动VPN…';

  @override
  String get stopVpn => '正在停止VPN…';

  @override
  String get localNetworkDeniedTip => '本地网络权限被拒绝：已改用 gvisor 栈，局域网无法访问。';

  @override
  String get compatible => '兼容模式';

  @override
  String get notSelectedTip => '当前代理组无法选中';

  @override
  String get changeProxyFailedTip => '切换代理失败，已恢复上一次的选择';

  @override
  String get databaseWriteFailedTip => '保存更改失败，已回滚';

  @override
  String get tip => '提示';

  @override
  String get account => '账号';

  @override
  String get backup => '备份';

  @override
  String get backupSuccess => '备份成功';

  @override
  String get noInfo => '暂无信息';

  @override
  String get pleaseBindWebDAV => '请绑定WebDAV';

  @override
  String get bind => '绑定';

  @override
  String get connectivity => '连通性：';

  @override
  String get webDAVConfiguration => 'WebDAV配置';

  @override
  String get address => '地址';

  @override
  String get addressTip => '请输入有效的WebDAV地址';

  @override
  String get password => '密码';

  @override
  String get authentication => '认证';

  @override
  String get authenticationSystemProxyDesc => '认证启用时，系统代理不生效。';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get discoverNewVersion => '发现新版本';

  @override
  String get checkUpdateError => '当前应用已经是最新版了';

  @override
  String get updateNoReleaseFound => '暂未找到 Flash 发布版本';

  @override
  String get updateCheckFailed => '暂时无法检查更新，请重试';

  @override
  String get goDownload => '前往下载';

  @override
  String get unknown => '未知';

  @override
  String get country => '区域';

  @override
  String get search => '搜索';

  @override
  String get allowBypass => '允许应用绕过VPN';

  @override
  String get externalController => '外部控制器';

  @override
  String get externalControllerDesc => '外部控制器开启后，可通过 9090 端口控制内核。';

  @override
  String get externalControllerSecret => '外部控制器密钥';

  @override
  String get ipv6Desc => '开启 IPv6 后才会接收 IPv6 流量。';

  @override
  String get app => '应用';

  @override
  String get general => '常规';

  @override
  String get startupAndBackground => '启动与后台';

  @override
  String get requestsAndUpdates => '请求与更新';

  @override
  String get logsAndDiagnostics => '日志与诊断';

  @override
  String get userAgent => '用户代理';

  @override
  String get unifiedDelay => '统一延迟';

  @override
  String get tcpConcurrent => 'TCP并发';

  @override
  String get geodataLoader => 'Geo低内存模式';

  @override
  String get requests => '请求';

  @override
  String get recentRequests => '最近请求';

  @override
  String get findProcessMode => '查找进程';

  @override
  String get init => '初始化';

  @override
  String get infiniteTime => '长期有效';

  @override
  String get connections => '连接';

  @override
  String get liveConnections => '实时连接';

  @override
  String get inbound => '入站';

  @override
  String get intranetIP => '内网 IP';

  @override
  String get view => '查看';

  @override
  String get cut => '剪切';

  @override
  String get copy => '复制';

  @override
  String get clipboardWriteFailed => '无法复制到剪贴板，所选内容可能过大';

  @override
  String get paste => '粘贴';

  @override
  String get testUrl => '测速链接';

  @override
  String get delayTestTimeout => '延迟测试超时';

  @override
  String get sync => '同步';

  @override
  String get exclude => '从最近任务中隐藏';

  @override
  String get compact => '紧凑';

  @override
  String get tab => '标签页';

  @override
  String get list => '列表';

  @override
  String get delay => '延迟';

  @override
  String get style => '风格';

  @override
  String get size => '尺寸';

  @override
  String get sort => '排序';

  @override
  String get columns => '列数';

  @override
  String get proxyGroup => '策略组';

  @override
  String get go => '前往';

  @override
  String get externalLink => '外部链接';

  @override
  String get otherContributors => '其他贡献者';

  @override
  String get appIconDesign => '应用图标设计';

  @override
  String get autoCloseConnections => '自动关闭连接';

  @override
  String get onlyStatisticsProxy => '仅统计代理流量';

  @override
  String get showNotificationStopAction => '通知栏显示停止按钮';

  @override
  String get pureBlackMode => '纯黑模式';

  @override
  String get sidebar => '侧边栏';

  @override
  String get backgroundBlur => '背景模糊';

  @override
  String get liquidGlass => '液态玻璃';

  @override
  String get keepAliveIntervalDesc => 'TCP保持活动间隔';

  @override
  String get entries => '个条目';

  @override
  String get local => '本地';

  @override
  String get remote => '远程';

  @override
  String get mode => '模式';

  @override
  String get time => '时间';

  @override
  String get source => '来源';

  @override
  String get action => '操作';

  @override
  String get intelligentSelected => '智能选择';

  @override
  String get clipboardImport => '剪贴板导入';

  @override
  String get clipboardNoPackageNames => '剪贴板中没有有效的包名';

  @override
  String get clipboardExport => '导出剪贴板';

  @override
  String get layout => '布局';

  @override
  String get tight => '紧凑';

  @override
  String get standard => '标准';

  @override
  String get ultra => '极致';

  @override
  String get loose => '宽松';

  @override
  String get profilesSort => '配置排序';

  @override
  String get start => '启动';

  @override
  String get runTime => '运行时长';

  @override
  String get stop => '暂停';

  @override
  String get key => '键';

  @override
  String get value => '值';

  @override
  String get options => '选项';

  @override
  String get enabled => '已开启';

  @override
  String get disabled => '已关闭';

  @override
  String get loopback => 'UWP 回环解锁';

  @override
  String get providers => '外部资源';

  @override
  String get proxyProviders => '代理集';

  @override
  String get ruleProviders => '规则集';

  @override
  String get providerUrlTip => '仅支持远程资源';

  @override
  String get ruleSetEmptyTip => '规则集中没有可用的条目';

  @override
  String get ruleSetMixedTip => '规则集同时包含域名和 IP 段，无法判断类型';

  @override
  String get ruleSetInvalidTip => '无法读取该 mrs 文件';

  @override
  String get subscriptionInfo => '订阅信息';

  @override
  String get server => '服务器';

  @override
  String get ntpInterval => '同步间隔（分钟）';

  @override
  String get dialerProxy => '拨号代理';

  @override
  String get writeToSystem => '写入系统';

  @override
  String get writeToSystemDesc => '写入系统会同时设置系统时钟，Android 上不生效。';

  @override
  String get sniffer => '域名嗅探';

  @override
  String get overrideDestination => '覆盖目标地址';

  @override
  String get forceDnsMapping => '强制DNS映射';

  @override
  String get forceDnsMappingDesc => '强制 DNS 映射对通过 DNS 映射得到域名的连接也进行嗅探。';

  @override
  String get parsePureIp => '解析纯IP';

  @override
  String get forceDomain => '强制嗅探域名';

  @override
  String get forceDomainDesc => '强制嗅探域名中的域名同样会被嗅探，其余已有域名的连接不嗅探。';

  @override
  String get skipDomain => '跳过域名';

  @override
  String get skipSrcAddress => '跳过来源地址';

  @override
  String get skipDstAddress => '跳过目标地址';

  @override
  String get sniffProtocols => '协议';

  @override
  String get ports => '端口';

  @override
  String get overrideEntries => '覆写项';

  @override
  String get addOverrideEntry => '添加覆写项';

  @override
  String get dnsOverrideDesc =>
      '添加的项会覆写所有 URL 和文件配置的 DNS，未添加的项沿用配置自身的设置。自定义配置的 DNS 在其内容中设置。';

  @override
  String get settingEntries => '设置项';

  @override
  String get addSettingEntry => '添加设置项';

  @override
  String get profileSettingsDesc => '仅作用于当前配置，未添加的项使用默认值。';

  @override
  String get healthCheck => '健康检查';

  @override
  String get discardChanges => '是否放弃更改？';

  @override
  String get quickEdit => '快速编辑';

  @override
  String get status => '状态';

  @override
  String get statusDesc => '关闭 DNS 后将使用系统 DNS。';

  @override
  String get respectRules => '遵守规则';

  @override
  String get respectRulesDesc =>
      '遵守规则使 DNS 连接遵守规则，需配置 Proxy Server Nameserver。';

  @override
  String get dnsMode => 'DNS模式';

  @override
  String get fakeipRange => 'Fake-IP范围';

  @override
  String get fakeipFilter => 'Fake-IP过滤';

  @override
  String get useHosts => '使用Hosts';

  @override
  String get useSystemHosts => '使用系统Hosts';

  @override
  String get fallbackFilter => 'Fallback过滤';

  @override
  String get domain => '域名';

  @override
  String get listenRoutingMark => '监听路由标记';

  @override
  String get listenRoutingMarkDesc => '监听路由标记仅在 Linux 生效。';

  @override
  String get ipv6Timeout => 'IPv6超时（毫秒）';

  @override
  String get cacheAlgorithm => '缓存算法';

  @override
  String get cacheMaxSize => '缓存大小';

  @override
  String get fakeipRange6 => 'Fake-IP范围（IPv6）';

  @override
  String get fakeipFilterMode => 'Fake-IP过滤模式';

  @override
  String get fakeipTtl => 'Fake-IP TTL';

  @override
  String get reset => '重置';

  @override
  String get actionView => '显示/隐藏';

  @override
  String get actionStart => '启动/停止';

  @override
  String get actionMode => '切换模式';

  @override
  String get actionProxy => '系统代理';

  @override
  String get actionTun => '虚拟网卡';

  @override
  String get actionRuleMode => '规则模式';

  @override
  String get actionGlobalMode => '全局模式';

  @override
  String get actionDirectMode => '直连模式';

  @override
  String get actionDelayTest => '测试全部延迟';

  @override
  String get actionUpdateProfiles => '更新全部配置';

  @override
  String get disclaimer => '免责声明';

  @override
  String get disclaimerDesc =>
      '在使用 Flash（以下简称“本软件”）前，请仔细阅读并充分理解本声明。点击“同意”表示你已阅读并理解以下内容；如不想继续，可点击“退出”。';

  @override
  String get disclaimerSoftwareTitle => '软件性质';

  @override
  String get disclaimerSoftwareContent =>
      '本软件是基于 Clash.Meta（mihomo）内核的开源网络代理客户端，仅提供配置管理、规则分流与流量转发等本地工具功能。';

  @override
  String get disclaimerNoServiceStatement =>
      '本软件自身不提供任何代理服务器、节点、订阅、机场或网络接入服务，也不与任何此类服务的提供者存在合作、代理或担保关系。';

  @override
  String get disclaimerUsageTitle => '使用说明';

  @override
  String get disclaimerUsageContent =>
      '任何人基于本软件开展的商业活动，包括付费分发、捆绑销售或作为商业服务的组成部分，均与本软件的开发者无关，开发者不为其提供背书、支持或担保。\n\n你须自行遵守所在国家或地区的法律法规，因违法使用本软件产生的后果由你自行承担。';

  @override
  String get disclaimerResponsibilityTitle => '用户责任';

  @override
  String get disclaimerResponsibilityContent =>
      '你应自行确认使用本软件在你所在国家或地区是合法的，并对使用本软件的全部行为及其后果独立承担法律责任。\n\n你导入的订阅、节点与配置由你自行选择和判断，其来源是否合法、内容是否安全、服务是否稳定，均由你与相关提供者自行负责。';

  @override
  String get disclaimerThirdPartyTitle => '第三方内容';

  @override
  String get disclaimerThirdPartyContent =>
      '订阅链接、配置文件、规则集、脚本、外部资源及外部链接均由第三方提供，开发者无法也不会对其合法性、准确性、安全性和可用性进行审查或担保。\n\n因使用第三方内容导致的数据泄露、财产损失、账号封禁或其他任何损失，由你与第三方自行解决，开发者不承担任何责任。';

  @override
  String get disclaimerWarrantyTitle => '无担保声明';

  @override
  String get disclaimerWarrantyContent =>
      '本软件按“现状”和“可用”的原则提供，不附带任何明示或默示的担保，包括但不限于适销性、特定用途适用性、不侵权以及持续可用、无错误、无安全漏洞的担保。\n\n开发者不保证本软件能满足你的需求，也不保证本软件的运行不会中断或不会出现错误。';

  @override
  String get disclaimerLiabilityTitle => '责任限制';

  @override
  String get disclaimerLiabilityContent =>
      '在适用法律允许的最大范围内，开发者及所有贡献者均不对因使用或无法使用本软件而产生的任何直接、间接、偶然、特殊、惩罚性或后果性损害承担责任，包括但不限于数据丢失、设备损坏、网络异常、业务中断、利润损失或因此引起的任何法律纠纷，即使已被告知发生此类损害的可能性。';

  @override
  String get disclaimerPrivacyTitle => '数据收集与隐私';

  @override
  String get disclaimerPrivacyContent =>
      '本软件不会收集或上传你的订阅地址、节点信息、配置内容、访问的网站、连接记录、流量内容和日志，这些数据仅保存在你的设备本地，开发者无法获取。\n\n本软件只会在你使用相应功能时访问外部网络，例如更新订阅时访问你提供的订阅地址、检查更新时访问 GitHub。\n\n本软件在所有平台上均未集成任何数据统计或崩溃上报服务。';

  @override
  String get disclaimerLicenseTitle => '开源协议';

  @override
  String get disclaimerLicenseContent =>
      '本软件以 GPL-3.0 协议开源，你可以依该协议运行、研究、修改和分发本软件；分发本软件或其修改版本时，须同样以 GPL-3.0 协议提供源代码并保留原有的版权声明。\n\n本软件包含的第三方组件（包括 Clash.Meta 内核）分别遵循其各自的开源协议。基于本软件修改或分发的版本所产生的任何问题，与原作者无关。';

  @override
  String get disclaimerChangesTitle => '声明变更';

  @override
  String get disclaimerChangesContent => '本声明可能随版本更新而修订，以每个版本附带的内容为准。';

  @override
  String get disclaimerAcceptTitle => '与开源协议的关系';

  @override
  String get disclaimerAcceptContent =>
      '本声明是对软件性质、风险与责任的说明，不是 GPL-3.0 之外的附加条款，也不限制该协议授予你的运行、复制、修改和分发等任何权利；两者不一致时，以 GPL-3.0 为准。';

  @override
  String get disclaimerRestateTitle => '复述声明';

  @override
  String get disclaimerRestateTip => '为确认你已知悉，请在下方输入框中完整复述以下声明：';

  @override
  String get disclaimerRestateHint => '在此输入上述声明';

  @override
  String get disclaimerRestateMismatch => '与声明内容不一致';

  @override
  String get disclaimerAcknowledgeTitle => '确认声明';

  @override
  String get disclaimerAcknowledgeTip => '为确认你已知悉，请阅读以下声明并勾选下方选项：';

  @override
  String get disclaimerAcknowledgeLabel => '我已阅读并理解此声明';

  @override
  String get agree => '同意';

  @override
  String get hotkeyManagement => '快捷键管理';

  @override
  String get hotkeyDesc => '全局快捷键在窗口隐藏时依然生效，点击操作即可录制组合键。';

  @override
  String get hotkeyNotSet => '未设置';

  @override
  String get pressKeyboard => '请按下组合键';

  @override
  String hotkeyNeedsModifier(Object modifiers) {
    return '至少包含 $modifiers 中的一个';
  }

  @override
  String hotkeyConflictWith(Object action) {
    return '已被“$action”使用，保存后将移到这里';
  }

  @override
  String get hotkeyUnavailable => '未能注册，可能已被其他应用占用';

  @override
  String get remove => '移除';

  @override
  String get noNetwork => '无网络';

  @override
  String get exportLogs => '导出日志';

  @override
  String get exportSuccess => '导出成功';

  @override
  String get iconStyle => '图标样式';

  @override
  String get iconStyleFilled => '色块';

  @override
  String get iconStylePlain => '纯图标';

  @override
  String get iconStyleHidden => '隐藏';

  @override
  String get filter => '筛选';

  @override
  String get groupBy => '分类';

  @override
  String get hideTimeoutProxies => '隐藏超时代理';

  @override
  String get showHiddenGroups => '显示隐藏分组';

  @override
  String get hiddenGroupTag => '隐藏';

  @override
  String hiddenGroupSemantics(Object name) {
    return '$name，隐藏';
  }

  @override
  String get stackMode => '栈模式';

  @override
  String get network => '网络';

  @override
  String get bypassDomain => '排除域名';

  @override
  String get pacMode => 'PAC 模式';

  @override
  String get pacScript => 'PAC 脚本';

  @override
  String get bypassDomainDesc => '排除域名仅在系统代理启用时生效。';

  @override
  String get bypassLocalWindowsOnly => '仅 Windows：不带点的内网主机名';

  @override
  String get resetTip => '确定要重置吗？';

  @override
  String get icon => '图标';

  @override
  String get noData => '暂无数据';

  @override
  String get fontFamily => '字体';

  @override
  String get installedFonts => '已安装字体';

  @override
  String get toggle => '切换';

  @override
  String get system => '系统';

  @override
  String get routeAddress => '路由地址';

  @override
  String get interfaceNameMode => '出站网卡';

  @override
  String get interfaceNameModeClear => '清空';

  @override
  String get interfaceNameModeFollow => '跟随配置';

  @override
  String get interfaceNameModeCustom => '自定义';

  @override
  String get interfaceName => '网卡名称';

  @override
  String get copyEnvVar => '复制环境变量';

  @override
  String get trayTunMode => 'TUN 模式';

  @override
  String get trayCopyProxyCommand => '复制终端代理命令';

  @override
  String get memoryInfo => '内存信息';

  @override
  String get total => '总计';

  @override
  String get releaseMemory => '释放内存';

  @override
  String get memoryCoreHeapInuse => '堆内存使用中';

  @override
  String get memoryCoreHeapIdle => '堆内存空闲';

  @override
  String get memoryCoreStack => '协程栈';

  @override
  String get memoryCoreRuntime => '运行时开销';

  @override
  String get memoryGoRuntimeDescription => 'Go 运行时统计；各项不代表进程常驻内存的构成。';

  @override
  String get memoryCoreNotRunning => '内核未运行';

  @override
  String get memoryAppResident => '常驻内存';

  @override
  String get memoryAppShared => '应用及共享';

  @override
  String get memoryEstimateDesc => '基于进程常驻内存估算，可能与系统显示的数值不同。';

  @override
  String get memoryEstimateSharedDesc =>
      '内核与应用运行在同一进程，内核部分按运行时统计估算，其余计入应用及共享内存。';

  @override
  String get memoryReleased => '内存已释放';

  @override
  String memoryReleasedSize(Object size) {
    return '已释放 $size';
  }

  @override
  String get releaseMemoryFailed => '释放内存失败';

  @override
  String get dialog => '对话框';

  @override
  String get cancel => '取消';

  @override
  String get fileIsUpdate => '文件有修改，是否保存修改';

  @override
  String get profileHasUpdate => '配置文件已经修改，是否关闭自动更新？';

  @override
  String get hasCacheChange => '是否缓存修改';

  @override
  String get copySuccess => '复制成功';

  @override
  String get copyLink => '复制链接';

  @override
  String get exportFile => '导出文件';

  @override
  String get cacheCorrupt => '缓存已损坏，是否清空？';

  @override
  String get detectionTip => '依赖第三方api，仅供参考';

  @override
  String get listen => '监听';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get lineWrap => '自动换行';

  @override
  String get none => '无';

  @override
  String get advancedConfig => '进阶配置';

  @override
  String get addRule => '添加规则';

  @override
  String get content => '内容';

  @override
  String get ruleTarget => '规则目标';

  @override
  String get matchTarget => 'MATCH-TARGET';

  @override
  String get followProfile => '跟随配置';

  @override
  String get scriptFailed => '脚本运行失败';

  @override
  String get sourceIp => '源IP';

  @override
  String get noResolve => '不解析IP';

  @override
  String get saveChanges => '是否保存更改？';

  @override
  String get applyNow => '立即应用';

  @override
  String get applied => '已应用';

  @override
  String get cannotSave => '无法保存';

  @override
  String get navigationBarStyle => '底栏';

  @override
  String get floating => '悬浮';

  @override
  String get docked => '固定';

  @override
  String get slide => '滑动';

  @override
  String get fade => '淡入';

  @override
  String get pureBlack => '纯黑';

  @override
  String get customColor => '自定义颜色';

  @override
  String get colorStyle => '配色风格';

  @override
  String get grid => '网格';

  @override
  String get spectrum => '光谱';

  @override
  String get sliders => '滑块';

  @override
  String get hue => '色相';

  @override
  String get saturation => '饱和度';

  @override
  String get brightness => '亮度';

  @override
  String get hex => '十六进制';

  @override
  String get monochromeScheme => '单色';

  @override
  String get vividStyle => '鲜明';

  @override
  String get tintedStyle => '氛围';

  @override
  String get softStyle => '柔和';

  @override
  String get developerMode => '开发者模式';

  @override
  String get developerModeEnableTip => '开发者模式已启用。';

  @override
  String get messageTest => '消息测试';

  @override
  String get messageTestTip => '这是一条消息。';

  @override
  String get crashTest => '崩溃测试';

  @override
  String get crashDetected => '检测到崩溃';

  @override
  String crashDetectedTip(Object name) {
    return '应用连续两次未能完成启动。为打断崩溃循环，已取消选中配置 $name，并跳过本次自动配置，你可以随时重新选中它。';
  }

  @override
  String get launchInterrupted => '启动未完成';

  @override
  String get launchInterruptedTip => '应用上次在启动过程中意外退出。已跳过本次自动配置，你可以手动启动重试。';

  @override
  String get clearData => '清除数据';

  @override
  String get textScale => '文本缩放';

  @override
  String get textScalePreview => '应用内的文字将以这个大小显示';

  @override
  String get followSystem => '跟随系统';

  @override
  String get internet => '互联网';

  @override
  String get systemApp => '系统应用';

  @override
  String get noNetworkApp => '无网络应用';

  @override
  String get restoreStrategy => '恢复策略';

  @override
  String get restoreStrategyOverride => '覆盖';

  @override
  String get restoreStrategyCompatible => '兼容';

  @override
  String get logsTest => '日志测试';

  @override
  String emptyTip(Object label) {
    return '$label不能为空';
  }

  @override
  String urlTip(Object label) {
    return '$label必须为URL';
  }

  @override
  String get invalidLinkTip => '不是有效的订阅链接或代理分享链接';

  @override
  String numberTip(Object label) {
    return '$label必须为数字';
  }

  @override
  String numberRangeTip(Object label, Object min, Object max) {
    return '$label必须在 $min 到 $max 之间';
  }

  @override
  String get interval => '间隔';

  @override
  String existsTip(Object label) {
    return '$label当前已存在';
  }

  @override
  String maxLengthTip(Object label, Object max) {
    return '$label最多$max个字符';
  }

  @override
  String get singleImport => '单条导入';

  @override
  String get batchImport => '批量导入';

  @override
  String get batchUrlInputTip => '每行一个URL';

  @override
  String get batchLinkInputTip => '每行一个链接';

  @override
  String batchPreviewTip(Object count, Object skipped) {
    return '将添加 $count 项，跳过 $skipped 项已存在';
  }

  @override
  String lineIssueTip(Object line, Object message) {
    return '第 $line 行：$message';
  }

  @override
  String singleValueTip(Object label) {
    return '$label只能是一项';
  }

  @override
  String deleteTip(Object label) {
    return '确定删除当前$label吗？';
  }

  @override
  String deleteMultipTip(Object label) {
    return '确定删除选中的$label吗？';
  }

  @override
  String nullTip(Object label) {
    return '暂无$label';
  }

  @override
  String get script => '脚本';

  @override
  String get color => '颜色';

  @override
  String get unnamed => '未命名';

  @override
  String get pleaseEnterScriptName => '请输入脚本名称';

  @override
  String get mixedPort => '混合端口';

  @override
  String get socksPort => 'Socks端口';

  @override
  String get redirPort => 'Redir端口';

  @override
  String get tproxyPort => 'Tproxy端口';

  @override
  String portTip(Object label) {
    return '$label 必须在 1024 到 49151 之间';
  }

  @override
  String get portConflictTip => '请输入不同的端口';

  @override
  String get import => '导入';

  @override
  String get importFile => '通过文件导入';

  @override
  String get importUrl => '通过URL导入';

  @override
  String get startFromScratch => '从零开始';

  @override
  String details(Object label) {
    return '$label详情';
  }

  @override
  String get creationTime => '创建时间';

  @override
  String get process => '进程';

  @override
  String get host => '主机';

  @override
  String get destination => '目标地址';

  @override
  String get destinationGeoIP => '目标地理定位';

  @override
  String get destinationIPASN => '目标IP ASN';

  @override
  String get specialProxy => '特殊代理';

  @override
  String get specialRules => '特殊规则';

  @override
  String get remoteDestination => '远程目标';

  @override
  String get networkType => '网络类型';

  @override
  String get proxyChains => '代理链';

  @override
  String get log => '日志';

  @override
  String get connection => '连接';

  @override
  String get request => '请求';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get connecting => '连接中…';

  @override
  String get restartCoreTip => '您确定要重启核心吗？';

  @override
  String get forceRestartCoreTip => '您确定要强制重启核心吗？';

  @override
  String get dnsHijacking => 'DNS劫持';

  @override
  String get coreStatus => '核心状态';

  @override
  String get appendSystemDns => '追加系统DNS';

  @override
  String get editRule => '编辑规则';

  @override
  String get addedRules => '附加规则';

  @override
  String get addedRulesAfterScript => '在脚本之后插入，排在配置规则前面';

  @override
  String get controlGlobalAddedRules => '控制全局附加规则';

  @override
  String get quickActions => '快捷操作';

  @override
  String get rulePresetBlockQuic => '屏蔽 QUIC';

  @override
  String get rulePresetBlockStun => '屏蔽 STUN';

  @override
  String get rulePresetBlockDot => '屏蔽 DNS over TLS';

  @override
  String get rulePresetBlockLoopback => '防止代理回环';

  @override
  String get rulePresetSystemServicesDirect => 'Apple 与 Microsoft 直连';

  @override
  String get rulePresetBittorrentDirect => 'BT 下载直连';

  @override
  String get rulePresetLanDirect => '局域网直连';

  @override
  String get extendScript => '扩展脚本';

  @override
  String get goToConfigureScript => '前往配置脚本';

  @override
  String get goToConfigureAddedRules => '前往配置附加规则';

  @override
  String get editGlobalRules => '编辑全局规则';

  @override
  String get confirmForceCrashCore => '确定要强制崩溃核心？';

  @override
  String get confirmClearAllData => '确定要清除所有数据？';

  @override
  String get loading => '加载中…';

  @override
  String yearsAgo(num count) {
    return '$count 年前';
  }

  @override
  String monthsAgo(num count) {
    return '$count 个月前';
  }

  @override
  String daysAgo(num count) {
    return '$count 天前';
  }

  @override
  String hoursAgo(num count) {
    return '$count 小时前';
  }

  @override
  String minutesAgo(num count) {
    return '$count 分钟前';
  }

  @override
  String get justNow => '刚刚';

  @override
  String yearsAgoShort(num count) {
    return '$count 年前';
  }

  @override
  String monthsAgoShort(num count) {
    return '$count 个月前';
  }

  @override
  String daysAgoShort(num count) {
    return '$count 天前';
  }

  @override
  String hoursAgoShort(num count) {
    return '$count 小时前';
  }

  @override
  String minutesAgoShort(num count) {
    return '$count 分钟前';
  }

  @override
  String get noLongerRemind => '不再提示';

  @override
  String get turnOn => '开启';

  @override
  String get turnOff => '关闭';

  @override
  String get vpnConfigChangeDetected => 'VPN 相关配置已改动，点击重启';

  @override
  String get restart => '重启';

  @override
  String get speedStatistics => '网速统计';

  @override
  String get resetPageChangesTip => '当前页面存在更改，确定重置吗？';

  @override
  String get customProfile => '自定义';

  @override
  String get customResources => '自定义';

  @override
  String get unknownNetworkError => '未知网络错误';

  @override
  String get backupFromNewerVersion => '该备份来自更高版本的应用，请先更新应用再恢复';

  @override
  String get networkTimeoutError => '请求超时，请检查网络或代理后重试';

  @override
  String get networkHostLookupError => '无法解析服务器地址，请确认链接正确且 DNS 可用';

  @override
  String get monochromeIcon => '单色图标';

  @override
  String get networkConnectionError => '无法连接到服务器，请检查网络连接或代理设置';

  @override
  String get networkTlsError => '安全连接失败，服务器证书可能无效，或连接被拦截';

  @override
  String get networkCancelledError => '请求已取消';

  @override
  String networkAccessDeniedError(Object code) {
    return '服务器拒绝访问（HTTP $code），链接可能已过期或凭据有误';
  }

  @override
  String networkNotFoundError(Object code) {
    return '该地址下没有内容（HTTP $code），请确认链接是否正确';
  }

  @override
  String get networkRateLimitedError => '请求过于频繁（HTTP 429），请稍后再试';

  @override
  String networkServerError(Object code) {
    return '服务器出现问题（HTTP $code），请稍后再试';
  }

  @override
  String networkBadResponseError(Object code) {
    return '服务器拒绝了请求（HTTP $code）';
  }

  @override
  String networkRequestFailed(Object detail) {
    return '网络请求失败：$detail';
  }

  @override
  String get invalidBackupFile => '无效备份文件';

  @override
  String get pruneCache => '修剪缓存';

  @override
  String get backupAndRestore => '备份与恢复';

  @override
  String get restore => '恢复';

  @override
  String get restoreSuccess => '恢复成功';

  @override
  String get restoreOnlyConfig => '仅恢复配置文件';

  @override
  String get restoreAllData => '恢复所有数据';

  @override
  String get restoreRuleSetDownloadNotice =>
      '备份会保留规则集设置。恢复后，需联网重新下载规则集；日常重启或切换配置无需重新下载。';

  @override
  String get addProfile => '添加配置';

  @override
  String get delayTest => '延迟测试';

  @override
  String get proxyGroupEmpty => '策略组为空';

  @override
  String get confirmExitWindow => '确定要退出当前窗口吗？';

  @override
  String get optional => '可选';

  @override
  String get maxFailedTimes => '最大失败次数';

  @override
  String get testInterval => '测试间隔';

  @override
  String get excludeFilter => '排除筛选';

  @override
  String get expectedStatus => '预期状态';

  @override
  String get strategy => '策略';

  @override
  String get tolerance => '容差';

  @override
  String get inputProxyGroupName => '输入策略组名称';

  @override
  String get helperCorruptTip => 'Helper 服务不可用，无法启用 TUN 模式，请重新安装 Flash。';

  @override
  String get tunAuthorizationFailed => 'TUN 授权未完成，本次未应用。已保留页面上的设置。';

  @override
  String mixedPortUnavailable(Object port) {
    return '无法打开端口 $port，可能已被其他应用占用。代理服务未启动。';
  }

  @override
  String mixedPortUnavailableProxyUnchanged(Object port) {
    return '无法打开端口 $port，可能已被其他应用占用。代理服务未启动。未更改系统代理设置。';
  }

  @override
  String get sudoPasswordTitle => '输入 sudo 密码';

  @override
  String coreBlockedByPolicyTip(Object code) {
    return 'Windows 拒绝运行 FlClashCore.exe（错误 $code）。智能应用控制、AppLocker 等应用控制策略会拦截未签名程序，请在该策略中放行 Flash 或关闭策略后重试。';
  }

  @override
  String get coreBlockedBySmartAppControlTip =>
      'Windows 智能应用控制拦截了未签名的 FlClashCore.exe。请打开 Windows 安全中心 → 应用和浏览器控制 → 智能应用控制设置，选择「关闭」后重新启动 Flash。智能应用控制关闭后无法再开启，除非重装 Windows。';

  @override
  String get hideFromList => '从列表中隐藏';

  @override
  String get testWhenUsed => '使用时测试';

  @override
  String get disableUDP => '禁用UDP';

  @override
  String get confirmDeleteProxyGroup => '确定要删除当前策略组吗？';

  @override
  String get ruleEmpty => '规则为空';

  @override
  String get inputRuleContent => '输入规则内容';

  @override
  String get ruleSet => '规则集';

  @override
  String get selectRuleSet => '请选择规则集';

  @override
  String get splitStrategy => '分流策略';

  @override
  String get selectSplitStrategy => '请选择分流策略';

  @override
  String get noResolveHostname => '不解析主机名';

  @override
  String get matchSourceIp => '匹配来源IP';

  @override
  String get basicInfo => '基础信息';

  @override
  String get additionalParameters => '附加参数';

  @override
  String get proxyType => '代理类型';

  @override
  String get basicStrategy => '基础策略';

  @override
  String get editProxy => '编辑代理';

  @override
  String get addNodes => '添加节点';

  @override
  String get addProxyGroup => '添加策略组';

  @override
  String get editProxyGroup => '编辑策略组';

  @override
  String get iconUrl => '图标链接';

  @override
  String get iconRecords => '图标记录';

  @override
  String get custom => '自定义';

  @override
  String get ruleActionDomainDesc => '匹配完整域名';

  @override
  String get ruleActionDomainSuffixDesc => '匹配域名后缀';

  @override
  String get ruleActionDomainKeywordDesc => '匹配域名关键字';

  @override
  String get ruleActionDomainRegexDesc => '使用域名正则表达式匹配';

  @override
  String get ruleActionDomainWildcardDesc => '通配符匹配，仅支持*和?通配符';

  @override
  String get ruleActionGeositeDesc => '匹配 Geosite 内的域名';

  @override
  String get ruleActionIpCidrDesc => '匹配 IP 地址范围';

  @override
  String get ruleActionIpCidr6Desc => '匹配 IP 地址范围，IP-CIDR6 只是一个别名';

  @override
  String get ruleActionIpSuffixDesc => '匹配 IP 后缀范围';

  @override
  String get ruleActionIpAsnDesc => '匹配 IP 所属 ASN';

  @override
  String get ruleActionGeoipDesc => '匹配 IP 所属国家代码';

  @override
  String get ruleActionSrcGeoipDesc => '匹配来源 IP 所属国家代码';

  @override
  String get ruleActionSrcIpAsnDesc => '匹配来源 IP 所属 ASN';

  @override
  String get ruleActionSrcIpCidrDesc => '匹配来源 IP 地址范围';

  @override
  String get ruleActionSrcIpSuffixDesc => '匹配来源 IP 后缀范围';

  @override
  String get ruleActionDstPortDesc => '匹配请求目标端口范围';

  @override
  String get ruleActionSrcPortDesc => '匹配请求来源端口范围';

  @override
  String get ruleActionInPortDesc => '匹配入站端口';

  @override
  String get ruleActionInTypeDesc => '匹配入站类型';

  @override
  String get ruleActionInUserDesc => '匹配入站用户名，支持使用 / 分隔多个用户名';

  @override
  String get ruleActionInNameDesc => '匹配入站名称';

  @override
  String get ruleActionRematchNameDesc => '匹配重匹配名称，多个名称用/分隔';

  @override
  String get ruleActionProcessPathDesc => '使用完整进程路径匹配';

  @override
  String get ruleActionProcessPathRegexDesc => '使用进程路径正则表达式匹配';

  @override
  String get ruleActionProcessPathWildcardDesc => '使用进程路径通配符匹配，仅支持*和?通配符';

  @override
  String get ruleActionProcessNameDesc => '使用进程匹配，在Android平台可以匹配包名';

  @override
  String get ruleActionProcessNameRegexDesc => '使用进程名称正则表达式匹配，在Android平台可以匹配包名';

  @override
  String get ruleActionProcessNameWildcardDesc => '使用进程名称通配符匹配，仅支持*和?通配符';

  @override
  String get ruleActionUidDesc => '匹配 Linux USER ID';

  @override
  String get ruleActionNetworkDesc => '匹配TCP或者UDP';

  @override
  String get ruleActionDscpDesc => '匹配DSCP标记（仅限 tproxy udp 入站）';

  @override
  String get ruleActionRuleSetDesc => '引用规则集合，需配置rule-providers';

  @override
  String get ruleActionAndDesc => '逻辑规则 AND';

  @override
  String get ruleActionOrDesc => '逻辑规则 OR';

  @override
  String get ruleActionNotDesc => '逻辑规则 NOT';

  @override
  String get ruleActionSubRuleDesc => '匹配至子规则，需要注意括号的使用';

  @override
  String get ruleActionMatchDesc => '匹配所有请求，无需条件';

  @override
  String get contentNotEmpty => '内容不能为空';

  @override
  String get splitStrategyNotEmpty => '分流策略不能为空';

  @override
  String get timeout => '超时';

  @override
  String get delayFailed => '失败';

  @override
  String invalidSubRule(Object subRule) {
    return '$subRule 是一个无效的SUB_RULE';
  }

  @override
  String invalidPolicy(Object target) {
    return '$target 是一个无效的策略';
  }

  @override
  String invalidProxyProvider(Object providerName) {
    return '$providerName 是一个无效的代理集';
  }

  @override
  String invalidRuleSet(Object ruleSet) {
    return '$ruleSet 不是有效的规则集';
  }

  @override
  String get invalidNetworkContent => '仅支持 tcp 或 udp';

  @override
  String get invalidRangeContent => '请输入数字或范围，如 80 或 8000-9000，多个用 / 分隔';

  @override
  String get invalidDscpContent => 'DSCP 标记不能超过 63';

  @override
  String get invalidCidrContent => '请输入 CIDR 格式的 IP 段，如 192.168.0.0/16';

  @override
  String get invalidPortRangeContent => '请输入端口或范围，如 443 或 8000-9000';

  @override
  String get invalidHostContent => '请输入域名或 IP 地址';

  @override
  String get invalidListenContent => '请输入地址和端口，如 0.0.0.0:1053';

  @override
  String invalidProxy(Object proxyName) {
    return '$proxyName 是一个无效的代理';
  }

  @override
  String get locationPermissionRequired => '需要位置权限';

  @override
  String locationPermissionGuide(Object appName) {
    return '1. 打开 系统设置 > 隐私与安全性\n2. 选择 定位服务\n3. 在右侧列表中找到并勾选 $appName\n\n完成设置后，返回应用即可正常使用。感谢您的配合。';
  }

  @override
  String get prerequisites => '前置条件';

  @override
  String get ignoreBatteryOptimization => '忽略电池优化';

  @override
  String get locationPermission => '位置权限';

  @override
  String get locationPermissionDesc =>
      '根据系统要求，获取Wi-Fi名称需要您授予位置权限。Android 上请选择“始终允许”，否则应用在后台时无法获取 Wi-Fi 名称。';

  @override
  String get excludeSsids => '排除SSIDs';

  @override
  String get excludeSsidsDesc => '连接到被排除 SSID 的 Wi-Fi 时，将会自动切换应用运行状态。';

  @override
  String get ssidsEmpty => 'SSIDs为空';

  @override
  String get onDemand => '按需运行';

  @override
  String get locationPermissionDeniedMessage =>
      '位置权限已被拒绝，无法获取当前 Wi-Fi 名称。请前往系统设置手动开启位置权限。';

  @override
  String get addSsid => '添加SSID';

  @override
  String get editSsid => '编辑SSID';

  @override
  String get authorized => '已授权';

  @override
  String get tapToAuthorize => '点击授权';

  @override
  String get suspended => '挂起中…';

  @override
  String get resourceUpdateInterval => '自动更新间隔';

  @override
  String get resourceUpdateIntervalTip => '自动更新间隔必须大于0';

  @override
  String get hours => '小时';

  @override
  String get minutes => '分钟';

  @override
  String get geoResources => 'Geo';

  @override
  String geoSkipped(Object name) {
    return '$name 已是最新版本';
  }

  @override
  String geoUpdated(Object name) {
    return '$name 已更新';
  }

  @override
  String secondsCount(num count) {
    return '$count 秒';
  }

  @override
  String proxiesCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label 个代理',
    );
    return '$_temp0';
  }

  @override
  String rulesCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label 条规则',
    );
    return '$_temp0';
  }

  @override
  String proxyGroupsCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label 个策略组',
    );
    return '$_temp0';
  }

  @override
  String get changelogBreaking => '重大变更';

  @override
  String get changelogFeatures => '新功能';

  @override
  String get changelogFixes => '问题修复';

  @override
  String get changelogPerformance => '性能优化';

  @override
  String get changelogReverts => '已回滚';

  @override
  String get close => '关闭';

  @override
  String get back => '返回';

  @override
  String get minimize => '最小化';

  @override
  String get maximize => '最大化';

  @override
  String get unmaximize => '向下还原';

  @override
  String get pinWindow => '窗口置顶';

  @override
  String get unpinWindow => '取消置顶';

  @override
  String get exitFullScreen => '退出全屏';

  @override
  String get torch => '手电筒';

  @override
  String get pickFromAlbum => '从相册选择';

  @override
  String get closeConnections => '关闭连接';

  @override
  String get scrollToSelected => '滚动到已选';

  @override
  String get showMore => '展开';

  @override
  String get showLess => '收起';

  @override
  String get previousMatch => '上一个匹配';

  @override
  String get nextMatch => '下一个匹配';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get noSearchResults => '没有匹配的结果';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get authorize => '授权';

  @override
  String get installedAppsPermissionRequired => '需要读取应用列表权限';

  @override
  String get installedAppsPermissionDesc =>
      '当前系统在授权前不会提供已安装的应用列表，授权后即可配置分应用代理。';

  @override
  String get installedAppsPermissionDeniedMessage =>
      '读取应用列表权限已被拒绝，无法获取已安装的应用。请前往系统设置手动开启。';

  @override
  String get outboundIp => '出站 IP';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get ipQualityLevel => '等级';

  @override
  String get ipQualityGood => '优';

  @override
  String get ipQualityNormal => '普通';

  @override
  String get ipQualityRisky => '风险';

  @override
  String get ipType => '类型';

  @override
  String get ipTypeResidential => '住宅';

  @override
  String get ipTypeMobile => '移动网络';

  @override
  String get ipTypeBusiness => '商业';

  @override
  String get ipTypeHosting => '机房';

  @override
  String get ipFlags => '命中标记';

  @override
  String get ipFlagProxy => '代理';

  @override
  String get ipFlagVpn => 'VPN';

  @override
  String get ipFlagTor => 'Tor';

  @override
  String get ipFlagAbuser => '滥用记录';

  @override
  String get ipOrganization => '组织';

  @override
  String get ipAsn => 'ASN';

  @override
  String get ipQualitySource => '采用来源';

  @override
  String get ipQualitySources => '各来源';

  @override
  String get ipQualityFailed => '类型查询失败';

  @override
  String get ipQualityRetry => '重新查询';

  @override
  String get ipSourceNoType => '无法判定类型';

  @override
  String get ipSourceRateLimited => '限流';

  @override
  String get ipSourceIpMismatch => '出站 IP 不一致';

  @override
  String get hideIp => '隐藏 IP';

  @override
  String get editorUnavailable => '编辑器不可用';

  @override
  String get replace => '替换';

  @override
  String get replaceAll => '全部替换';

  @override
  String get cameraPermissionRequired => '需要相机权限';

  @override
  String get cameraPermissionDesc => '请在系统设置中允许访问相机以扫描二维码，或从相册选择二维码图片。';

  @override
  String get cameraUnavailable => '相机不可用';

  @override
  String get retry => '重试';

  @override
  String get invalidProfileQrcode => '该二维码不包含配置文件链接';

  @override
  String get dnsQueries => 'DNS查询';

  @override
  String get recordType => '记录类型';

  @override
  String get answers => '应答';

  @override
  String get responseCode => '响应码';

  @override
  String get error => '错误';

  @override
  String get initiator => '发起方';

  @override
  String get cache => '缓存';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get nonTextProviderFile => '该外部资源不是文本文件';

  @override
  String get addCustomProxy => '添加代理';

  @override
  String get definitionNotMap => '配置必须是包含 name 和 type 的 YAML 映射';

  @override
  String get ruleTextInvalid => '规则必须以受支持的类型开头，例如 DOMAIN,example.com,DIRECT';

  @override
  String get ruleListInvalid =>
      '规则必须是 YAML 列表，每项一条规则，例如 - DOMAIN,example.com,DIRECT';

  @override
  String get shareLinksInvalid => '无法从链接中读取代理';

  @override
  String shareLinkUnreadable(Object link) {
    return '无法从 $link 中读取代理';
  }

  @override
  String proxiesProfileLabel(Object name, Object count) {
    return '$name 等 $count 个代理';
  }

  @override
  String get singleShareLinkOnly => '这里只能填写一条链接，多条请在列表的快速编辑中填写';

  @override
  String get username => '用户名';

  @override
  String get emptyFallback => '空组兜底';

  @override
  String get defaultSelected => '默认选中';

  @override
  String get hashByInUser => '按入站用户哈希';

  @override
  String get appProxiesEmpty => '暂无本地代理';

  @override
  String get nodes => '节点';

  @override
  String get localProxies => '本地代理';

  @override
  String get customIssueEmptyName => '名称为空';

  @override
  String customIssueReservedName(Object name) {
    return '$name 是内置策略名，不能在此使用';
  }

  @override
  String customIssueDuplicateName(Object name) {
    return '名称 $name 已被其他代理或策略组使用';
  }

  @override
  String customIssueCoreRejected(Object message) {
    return '内核无法解析该代理：$message';
  }

  @override
  String customIssueMissingProxies(Object names) {
    return '以下代理或策略不存在：$names';
  }

  @override
  String customIssueMissingProviders(Object names) {
    return '以下代理集不存在：$names';
  }

  @override
  String get customIssueNoProxySource => '未选择任何代理或代理集，内核会拒绝该策略组';

  @override
  String customIssueGroupLoop(Object path) {
    return '策略组之间存在循环引用：$path';
  }

  @override
  String customIssueInvalidEmptyFallback(Object name) {
    return '空组兜底只能是代理，$name 不存在或是策略组';
  }

  @override
  String customIssueInvalidFilter(Object name, Object message) {
    return '$name不是有效的正则：$message';
  }

  @override
  String customIssueMissingDialer(Object name) {
    return '拨号代理 $name 不存在';
  }

  @override
  String customIssueDialerLoop(Object proxy, Object target) {
    return '$proxy 经 $target 拨号，而 $target 又会回到 $proxy，形成环路';
  }

  @override
  String dialerProxyLoopStopped(Object name) {
    return '经 $name 拨号会绕回使用它的代理，连接已中止';
  }

  @override
  String customIssuesSummary(Object count) {
    return '$count 项存在问题，应用配置可能失败';
  }

  @override
  String providerInUse(Object label, Object profiles) {
    return '$label 仍被 $profiles 使用，删除后这些配置会异常。确定删除吗？';
  }

  @override
  String proxyGroupInUse(Object label) {
    return '$label 仍被当前配置的规则、策略组、拨号代理、DNS 或 NTP 引用，删除后这些引用会失效。确定删除吗？';
  }

  @override
  String proxiesRemovedTip(Object removed) {
    return '以下代理将被删除：$removed。改了名字的行按新代理处理，自定义配置中对被删除代理的引用会标为缺失。确定应用吗？';
  }

  @override
  String proxiesReplacedTip(Object removed, Object added) {
    return '以下代理将被删除：$removed。以下代理将新增：$added。改了名字的行按新代理处理，自定义配置中对被删除代理的引用会标为缺失。确定应用吗？';
  }

  @override
  String get fontSize => '大小';

  @override
  String get large => '大';

  @override
  String get extraLarge => '超大';

  @override
  String get switchProfile => '切换配置';

  @override
  String get lastUpdated => '上次更新';

  @override
  String get filters => '筛选';

  @override
  String get label => '标签';

  @override
  String get regex => '正则';

  @override
  String get matchCase => '区分大小写';

  @override
  String get iconSets => '图标集';

  @override
  String get invalidIconSet => '不是有效的图标集';

  @override
  String get recommendedIcons => '推荐';

  @override
  String get localImage => '本地图片';

  @override
  String get iconSetsEmptyTip => '暂无图标集，可在「自定义配置资源 → 图标集」中添加';

  @override
  String get outbound => '出站';

  @override
  String get strictRoute => '严格路由';

  @override
  String get congestionController => 'TCP 拥塞控制';

  @override
  String get congestionControllerDesc => 'TCP 拥塞控制仅在 mips 栈生效。';

  @override
  String get routeExcludeAddress => '排除路由地址';

  @override
  String get keepAliveIdle => 'TCP 保持活动空闲时间';

  @override
  String get disableKeepAlive => '禁用 TCP 保持活动';

  @override
  String get routingMark => '路由标记';

  @override
  String get strictRouteDesc => '严格路由防止 DNS 等流量绕过虚拟网卡，关闭 IPv6 时会阻断本机的 IPv6 连接。';

  @override
  String get initFailed => '启动失败';

  @override
  String get initFailedTip =>
      'Flash 启动时出错，无法继续运行。可以复制错误详情用于反馈；如果问题反复出现，清除数据后通常可以重新启动。';

  @override
  String get errorDetails => '错误详情';

  @override
  String get stackTrace => '堆栈信息';

  @override
  String get clearDataAndExitTip => '将删除所有配置、设置和本地数据，随后关闭应用。重新打开即可从头开始。';

  @override
  String clearDataFailed(Object detail) {
    return '清除数据失败：$detail';
  }

  @override
  String get bypassPrivateRoute => '绕过私有路由地址';

  @override
  String get disableIcmpForwarding => '禁用ICMP转发';

  @override
  String get disableIcmpForwardingDesc =>
      '禁用 ICMP 转发后由虚拟网卡直接应答 ping，ping 将不再显示真实延迟。';

  @override
  String get excludeInterface => '排除网卡';

  @override
  String get includeInterface => '包含网卡';

  @override
  String get includeInterfaceDesc => '只有从包含网卡进入的流量经过虚拟网卡，设置后排除网卡不再生效。';

  @override
  String get includeUid => '包含用户 ID';

  @override
  String get excludeUid => '排除用户 ID';

  @override
  String get excludeSrcPort => '排除源端口';

  @override
  String get excludeDstPort => '排除目标端口';

  @override
  String get udpTimeout => 'UDP 超时';

  @override
  String get udpTimeoutDesc => 'UDP 超时以秒为单位，仅在 gvisor、system 和 mixed 栈生效。';

  @override
  String get dnsHijackDesc => '未添加时劫持所有发往 53 端口的 DNS 请求（any:53）。';

  @override
  String get tunOverrideDesc =>
      '添加的项会覆写所有配置的虚拟网卡设置，未添加的项沿用配置自身的设置。自定义配置自己添加的项优先。';

  @override
  String get generalOverrideDesc =>
      '添加的项会覆写所有配置的对应设置，未添加的项沿用配置自身的设置，配置未设置时使用内核默认值。';

  @override
  String get profileTunSettingsDesc => '仅作用于当前配置，并优先于网络设置中的虚拟网卡覆写项。';

  @override
  String settingsCount(num count) {
    return '$count 项设置';
  }

  @override
  String sectionsInEffect(Object count) {
    return '$count 项生效';
  }

  @override
  String itemsCount(num count) {
    return '$count 项';
  }

  @override
  String get additionalPrefix => '名称前缀';

  @override
  String get additionalSuffix => '名称后缀';

  @override
  String get skipCertVerify => '跳过证书验证';

  @override
  String get ipVersion => 'IP 版本';

  @override
  String get addFilters => '添加筛选';

  @override
  String failedItem(Object label, Object message) {
    return '$label：$message';
  }

  @override
  String failedCount(Object count) {
    return '$count 项失败，点击查看';
  }

  @override
  String get importConfigInvalid => '此文件不是可导入的配置';

  @override
  String get importConfigReplaceTip => '导入会替换此配置现有的策略组、规则和设置';

  @override
  String get networkName => '网络名称';

  @override
  String get networkSecret => '网络密码';

  @override
  String get peers => '初始节点';

  @override
  String get virtualIpv4 => '虚拟 IPv4';

  @override
  String get hostname => '主机名';

  @override
  String get exitNodes => '出口节点';

  @override
  String get cipher => '加密方式';

  @override
  String get protocol => '协议';

  @override
  String get protocolParam => '协议参数';

  @override
  String get obfs => '混淆';

  @override
  String get obfsParam => '混淆参数';

  @override
  String get obfsPassword => '混淆密码';

  @override
  String get obfsMode => '混淆模式';

  @override
  String get obfsHost => '混淆主机';

  @override
  String get plugin => '插件';

  @override
  String get pluginMode => '插件模式';

  @override
  String get pluginHost => '插件主机';

  @override
  String get pluginPath => '插件路径';

  @override
  String get pluginUsername => '插件用户名';

  @override
  String get pluginPassword => '插件密码';

  @override
  String get pluginCipher => '插件加密方式';

  @override
  String get privateKey => '私钥';

  @override
  String get publicKey => '公钥';

  @override
  String get privateKeyPassphrase => '私钥密码';

  @override
  String get preSharedKey => '预共享密钥';

  @override
  String get secretKey => '密钥';

  @override
  String get transport => '传输协议';

  @override
  String get uploadBandwidth => '上行带宽';

  @override
  String get downloadBandwidth => '下行带宽';

  @override
  String get protocolVersion => '协议版本';

  @override
  String get portHopping => '端口跳跃';

  @override
  String get hopInterval => '跳跃间隔';

  @override
  String get congestionControl => '拥塞控制';

  @override
  String get udpRelayMode => 'UDP 中继模式';

  @override
  String get allowedIps => '允许的 IP';

  @override
  String get remoteDnsResolve => '远程 DNS 解析';

  @override
  String get clientFingerprint => '客户端指纹';

  @override
  String get requestHeaders => '请求头';

  @override
  String transportHeaders(Object transport) {
    return '$transport 请求头';
  }

  @override
  String get required => '必填';

  @override
  String get ageSecretKey => 'age 私钥';

  @override
  String get ageEncryptedProfile => '配置已加密';

  @override
  String get ageSecretKeyRequiredTip => '该配置已用 age 加密，需要 age 私钥才能解密';

  @override
  String get currentOutboundDesc => '含启动键，不可移除';

  @override
  String get running => '运行中';

  @override
  String get root => 'Root';

  @override
  String get notRunning => '未运行';

  @override
  String trafficPeak(Object value) {
    return '峰值 $value';
  }

  @override
  String trafficTotal(Object value) {
    return '累计 $value';
  }

  @override
  String get ipQualityShort => '质量';

  @override
  String get ipTypeUnknown => '类型未知';

  @override
  String get tapIconToRetry => '点击图标重试';

  @override
  String get networkTakeover => '网络接管';

  @override
  String portValue(Object port) {
    return '端口 $port';
  }

  @override
  String serviceAbnormalCount(num count) {
    return '$count 项异常';
  }

  @override
  String get serviceAllAvailable => '全部可用';

  @override
  String get serviceShownOnDashboard => '显示在仪表盘';

  @override
  String groupTimeoutCount(Object count) {
    return '$count 超时';
  }

  @override
  String get groupCountUnit => '个';

  @override
  String groupCount(num count) {
    return '$count 个';
  }

  @override
  String get proxyGroupsAfterStart => '启动后在这里显示策略组';

  @override
  String get usedShort => '已用';

  @override
  String profileUpdatedAt(Object time) {
    return '更新于 $time';
  }

  @override
  String profileExpiresIn(Object date, num days) {
    return '$date 到期，剩余 $days 天';
  }

  @override
  String profileDaysLeft(num days) {
    return '剩余 $days 天';
  }

  @override
  String get target => '目标';

  @override
  String get outboundExit => '出口';

  @override
  String get duration => '时长';

  @override
  String get traffic => '流量';

  @override
  String get totalDownload => '下载总量';

  @override
  String get totalUpload => '上传总量';

  @override
  String get initiatorShort => '发起';

  @override
  String get result => '结果';

  @override
  String get elapsed => '耗时';

  @override
  String get connectionStats => '连接统计';

  @override
  String get connectionStatsDesc => '实时连接、最近请求、DNS查询';

  @override
  String get memoryInfoDesc => '应用与内核占用的内存';

  @override
  String get editDashboard => '编辑仪表盘';

  @override
  String get done => '完成';

  @override
  String get dashboardAddableSection => '可添加';

  @override
  String customImportDroppedSubRules(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '自定义配置不支持子规则，已丢弃 $label 条 SUB-RULE 规则',
    );
    return '$_temp0';
  }

  @override
  String get autoInclude => '自动包含';

  @override
  String get allReferencedProxies => '全部被引用的代理';

  @override
  String get allReferencedProxyProviders => '全部被引用的代理集';

  @override
  String get clearDnsCache => '清除DNS缓存';

  @override
  String get dnsCacheCleared => 'DNS缓存已清除';

  @override
  String get clearDnsCacheFailed => '清除DNS缓存失败';

  @override
  String get select => '选中';

  @override
  String get preferred => '首选';

  @override
  String get addToLocalProxies => '添加到本地代理';

  @override
  String addedToLocalProxies(Object name) {
    return '已将 $name 添加到本地代理';
  }

  @override
  String alreadyInLocalProxies(Object name) {
    return '本地代理中已有 $name';
  }

  @override
  String get mitm => 'MITM';

  @override
  String get httpsDecryption => 'HTTPS 解密';

  @override
  String get httpCapture => '抓包';

  @override
  String get httpCaptureDesc => '记录“主机名”中列出的主机的请求，在连接详情中查看。记录只保存在内存中。';

  @override
  String get httpCaptureNoHosts =>
      '未列出任何主机，不会记录内容。请在 MITM 页的“主机名”中添加，或在连接详情中加入。';

  @override
  String get httpCaptureLimit => '最多记录条数';

  @override
  String httpCaptureLimitDesc(Object memory, Object body) {
    return '达到此条数或占满 $memory 内存后，先丢弃最早的记录。每段内容只保留前 $body。';
  }

  @override
  String get httpRequests => 'HTTP 请求';

  @override
  String get httpRequestsMissing => '抓包开启前发出或已被清除的请求不在列表中。';

  @override
  String get httpRequestCleared => '这条请求的记录已清除';

  @override
  String get httpCaptureOff => '抓包未开启';

  @override
  String get inProgress => '进行中';

  @override
  String get method => '方法';

  @override
  String get originalUrl => '原 URL';

  @override
  String get timeToFirstByte => '首字节耗时';

  @override
  String get requestBody => '请求体';

  @override
  String get response => '响应';

  @override
  String get responseBody => '响应体';

  @override
  String get responseHeaders => '响应头';

  @override
  String get matchedRules => '命中的规则';

  @override
  String get overview => '概览';

  @override
  String get viewAll => '查看全部';

  @override
  String get copyAsBase64 => '复制为 Base64';

  @override
  String get copyAsCurl => '复制为 cURL';

  @override
  String get closeConnection => '关闭连接';

  @override
  String get copyHost => '复制主机';

  @override
  String get copyDestination => '复制目标地址';

  @override
  String get copyRequest => '复制请求';

  @override
  String get copyResponse => '复制响应';

  @override
  String get copyResponseBody => '复制响应体';

  @override
  String get httpBodyProtobufGuess => '按 Protobuf 解析，没有 .proto：只有字段编号，类型是推测的。';

  @override
  String get exportHar => '导出 HAR';

  @override
  String get mitmAddRejectRule => '添加拒绝规则';

  @override
  String get mitmAddMapLocalRule => '添加本地映射规则';

  @override
  String get httpExportPrivateTitle => '包含隐私信息';

  @override
  String get httpExportPrivate => '请求里可能有 Cookie、令牌、密码和表单内容，分享前请确认内容和对象。';

  @override
  String get mitmRuleCopiedForStash => '这个模块是 Stash 覆写，规则已复制，请手动添加。';

  @override
  String get binaryData => '二进制数据';

  @override
  String get httpBodyNotKept => '内存紧张时未记录这段内容。';

  @override
  String get httpBodyTruncated => '只记录了这段内容的开头部分。';

  @override
  String httpBodyUndecoded(Object encoding) {
    return '无法解码 $encoding，显示的是传输时的原始数据。';
  }

  @override
  String get mitmEnableTip =>
      '开启后，Flash 能读取发往被解密主机的全部内容，包括 Cookie 和密码。请只为需要改写的主机开启。';

  @override
  String get certificate => '证书';

  @override
  String get generateCertificate => '生成证书';

  @override
  String get regenerateCertificate => '重新生成证书';

  @override
  String get regenerateCertificateTip =>
      '新证书会替换当前证书，Flash 会尽量把当前证书从本机信任的根证书中移除。信任当前证书的其他设备都需要安装新证书。';

  @override
  String get exportCertificate => '导出证书';

  @override
  String get installCertificate => '安装到系统';

  @override
  String get installCertificateSuccess => '证书已安装';

  @override
  String validUntil(Object date) {
    return '有效期至 $date';
  }

  @override
  String get mitmCertificateExportTip => '导出后在要解密的设备上信任此证书。';

  @override
  String get mitmTrustReady => '已信任';

  @override
  String get mitmTrustUntrusted => '未完全信任';

  @override
  String get mitmTrustNotInstalled => '未安装';

  @override
  String get mitmTrustChecking => '正在检查…';

  @override
  String get trustCertificate => '信任证书';

  @override
  String get mitmCertificateAndroidReadyTip => '只有信任用户证书的应用（多为浏览器）会被解密。';

  @override
  String get mitmCertificateLinuxTip => 'Flatpak 版浏览器需要手动导入导出的证书。';

  @override
  String mitmCertutilMissing(Object command) {
    return 'Chrome 和 Firefox 使用自己的证书库，需要 certutil：$command';
  }

  @override
  String mitmMissingStores(Object stores) {
    return '尚未加入：$stores';
  }

  @override
  String get mitmSystemStoreFailed => '无法把证书加入系统信任的根证书';

  @override
  String get mitmRootUntilReboot =>
      '未找到可保留证书的 Magisk、KernelSU 或 APatch，重启手机后需要重新安装。';

  @override
  String get mitmRootPendingReboot => '证书将在重启手机后生效。';

  @override
  String get mitmInstallSystemCaTip =>
      '检测到 root，证书将以 Magisk、KernelSU 或 APatch 模块“FlClash MITM CA”加入系统信任的根证书。之后本机所有应用都会信任它，持有其私钥的人可以解密本机的 HTTPS 流量。如需撤销，可重新生成证书，或在 root 管理器中移除该模块并重启。若拒绝 root 授权，将改为安装用户证书。';

  @override
  String get mitmInstallUserCaTip =>
      '未检测到 root，证书只能安装为用户证书。只有信任用户证书的应用（多为浏览器）会被解密，其他应用访问列出的主机会失败，请不要列出它们的主机。Android 11 起需在系统设置中手动完成安装。';

  @override
  String mitmCertificateSavedTip(Object fileName) {
    return '已将 $fileName 保存到“下载”。请在系统设置的“安全 › 加密与凭据 › 安装证书 › CA 证书”中安装。';
  }

  @override
  String get openSettings => '打开设置';

  @override
  String mitmRemoveOldCertificateTip(Object name) {
    return '请在系统设置的“安全 › 加密与凭据 › 信任的凭据 › 用户”中移除旧证书 $name，再安装新证书。';
  }

  @override
  String mitmOldCertificateLeftTip(Object name) {
    return '无法移除旧证书 $name，请自行从信任的根证书中移除。';
  }

  @override
  String mitmOldSystemCertificateLeftTip(Object name) {
    return '旧证书 $name 仍在系统信任的证书中。请在 root 管理器中允许 Flash 使用 root 后重新生成，或在其中移除“FlClash MITM CA”模块并重启。';
  }

  @override
  String get mitmDecryptHost => '解密此主机';

  @override
  String mitmDecryptHostTip(Object host) {
    return '要把 $host 加入主机名列表吗？之后 Flash 能读取发往它的内容，包括 Cookie 和密码。';
  }

  @override
  String get mitmExcludeHost => '排除解密';

  @override
  String mitmExcludeHostTip(Object host) {
    return '要把 -$host 加到主机名列表顶部吗？之后不再解密该主机。';
  }

  @override
  String get urlRewrite => 'URL 重写';

  @override
  String get headerRewrite => 'Header 重写';

  @override
  String get bodyRewrite => 'Body 重写';

  @override
  String get mapLocal => '本地映射';

  @override
  String get mitmHostnameDesc => '以 - 开头表示排除，第一条匹配的生效。';

  @override
  String get mitmModules => '模块';

  @override
  String get mitmModule => '模块';

  @override
  String get mitmModuleInvalid =>
      '这不是 Surge 模块、Loon 插件、Quantumult X 片段或 Stash 覆写';

  @override
  String get arguments => '参数';

  @override
  String get mitmRoutingRules => '分流规则';

  @override
  String get mitmIgnoredLines => '忽略的行';

  @override
  String get mitmModuleRulesDesc => '模块分流规则排在附加规则之后、配置自身规则之前。';

  @override
  String mitmModuleSystemTip(Object system) {
    return '为 $system 编写，部分行可能不适用于本设备。';
  }

  @override
  String mitmSkipSection(Object section) {
    return '不支持 [$section] 段';
  }

  @override
  String get mitmSkipSetting => '不支持此设置';

  @override
  String get mitmSkipScriptType => '不支持此类脚本';

  @override
  String get mitmSkipRule => '不支持此规则类型';

  @override
  String get mitmSkipPolicy => '无法使用这个策略';

  @override
  String get mitmSkipJq => '不支持 jq 重写';

  @override
  String get mitmSkipJsonBody => '不支持 JSON 正文重写';

  @override
  String get mitmSkipRawHeader => '不支持把全部标头作为一段文本改写';

  @override
  String get mitmSkipConditional => '不支持条件重写';

  @override
  String get mitmSkipRelativeData => '此行引用的文件不是附件，请改用 URL 或添加为附件';

  @override
  String get mitmSkipNotDownloaded => '其文件尚未下载';

  @override
  String get mitmSkipUnreadable => '无法识别此行';

  @override
  String get mitmAddLocalFile => '添加本地文件';

  @override
  String get mitmNewModule => '新建模块';

  @override
  String get mitmAttachments => '附件';

  @override
  String get mitmAttachmentsDesc => '行内按文件名引用附件，如 script-path=a.js。';

  @override
  String mitmFileTooLarge(Object size) {
    return '文件大于 $size MB';
  }

  @override
  String get mitmSkipDisabled => '已被参数关闭';

  @override
  String get mitmSkipEvent => '不支持此事件';

  @override
  String get mitmRunScript => '立即运行';

  @override
  String get mitmScriptNoOutput => '脚本已运行完毕，没有输出';

  @override
  String get mitmScriptRiskTitle => '运行此模块的脚本？';

  @override
  String get mitmScriptRisk =>
      '它的脚本能读取并修改所匹配主机的流量，包括 Cookie 和令牌，还能自行发送请求。只在信任其来源时开启。开启后，它之后的更新会直接生效。';

  @override
  String mitmModuleScriptsChanged(Object name) {
    return '$name 的脚本有变化，已关闭';
  }

  @override
  String get skipServerCertVerify => '跳过服务器证书验证';

  @override
  String get blockQuic => '阻止 QUIC';

  @override
  String get http2 => 'HTTP/2';

  @override
  String get decryptUntrusted => '本机未信任时也解密';

  @override
  String invalidOfCount(Object invalid, Object total) {
    return '$total 条中 $invalid 条无效';
  }

  @override
  String get batchLineInputTip => '每行一项';

  @override
  String get downloadingUpdate => '正在下载更新';

  @override
  String get updateFailed => '更新失败';

  @override
  String get updateDownloadTest => '更新下载测试';

  @override
  String get liveStatusTest => '实时状态卡片测试';

  @override
  String get updateDownloadStarted => '已开始下载更新，可在首页查看进度';

  @override
  String get updateReady => '更新已就绪';

  @override
  String get updateReadyTip => '更新已下载，点击安装';

  @override
  String get stopUpdateDownloadTip => '要停止下载更新吗？';

  @override
  String get forceRestartCoreAsk => '强制重启核心？';

  @override
  String get forceRestartCoreAskDesc => '进行中的连接会断开';

  @override
  String get stopUpdateDownloadDesc => '已下载的部分会被删除';

  @override
  String get stopDownload => '停止';

  @override
  String get updateInstallFailed => '无法安装更新，可以前往发布页手动下载。';

  @override
  String get updateNotVerified => '下载的更新未通过校验。';

  @override
  String get macUpdateDownloadAndInstall => '下载并安装';

  @override
  String macUpdateSize(Object size) {
    return '大小：$size';
  }

  @override
  String get macUpdateReadyTitle => '更新已就绪';

  @override
  String macUpdateReadyMessage(Object version) {
    return 'Flash $version 已下载并通过校验。安装时 Flash 会短暂退出，连接可能中断；完成后会重新打开。';
  }

  @override
  String get macUpdateRestartNow => '退出并安装';

  @override
  String get macUpdateLater => '稍后';

  @override
  String get macUpdateInstalling => '正在安装更新…';

  @override
  String get macUpdateNotWritable =>
      '无法自动替换「应用程序」中的 Flash。已在访达中显示通过校验的新版本；请将它拖入「应用程序」并替换旧版，系统可能要求输入管理员密码。';

  @override
  String get macUpdateNotInApplications =>
      'Flash 不在「应用程序」文件夹中，无法自动替换。已在访达中显示通过校验的新版本；请将它拖入「应用程序」文件夹。';

  @override
  String get macUpdateNotConfigured => '当前版本暂不支持应用内更新，请前往发布页下载新版本。';

  @override
  String get macUpdateRejected => '更新未通过安全校验，未安装。请重试，或前往发布页下载。';

  @override
  String get macUpdateNotNewer => '下载的版本不比当前版本新，未安装。';

  @override
  String get macUpdateLauncherChanged => '此更新需要手动安装。请前往发布页下载新版 Flash。';

  @override
  String get macUpdateHelperOlder => '此更新的辅助程序版本低于已记录的版本，未安装。';

  @override
  String get macUpdateRolledBack => '更新未完成，已恢复原版本。';

  @override
  String macUpdateRollbackFailed(Object location) {
    return '更新未完成，也未能自动恢复原版本。原版本保存在「$location」。';
  }

  @override
  String get macUpdateRollbackFailedUnverified => '更新未完成，也未能自动恢复原版本。请查看详情。';

  @override
  String get macUpdateInstallFailed => '更新未完成，请查看详情。';

  @override
  String get macUpdateInstallFailedUnchanged => '更新未完成，原版本未更改。请查看详情。';

  @override
  String get macUpdateCoreStopFailed => '无法确认内核已停止，已取消安装更新。';

  @override
  String get macUpdateRecordHint => '辅助程序的版本记录无法读取或更新。安装更新不会修复这条记录；请按辅助程序提示处理。';

  @override
  String get macUpdateDetails => '详情';

  @override
  String get updateRestartTip => 'Flash 将关闭以安装更新，完成后自动重新打开。';

  @override
  String get updateDownloadFailed => '无法下载更新。';

  @override
  String get defaultNameserverDesc => '用于解析其他 DNS 服务器的域名，只能填写 IP 地址。';

  @override
  String get nameserverDesc =>
      '默认使用的 DNS 服务器，如 223.5.5.5、tls://1.1.1.1、https://dns.google/dns-query。';

  @override
  String get fallbackDesc => 'Nameserver 的结果被 Fallback 过滤判定为污染时，改用这些服务器的结果。';

  @override
  String get proxyServerNameserverDesc => '仅用于解析代理服务器的域名。';

  @override
  String get proxyServerNameserverPolicyDesc =>
      '匹配的代理服务器域名改用此处指定的 DNS 服务器，优先于 Proxy Server Nameserver。';

  @override
  String get directNameserverDesc => '用于解析直连连接的域名。';

  @override
  String get nameserverPolicyDesc =>
      '匹配的域名改用此处指定的 DNS 服务器，优先于 Nameserver 和 Fallback。';

  @override
  String get fakeipFilterDesc =>
      '这些域名不使用 Fake-IP，返回真实 IP；过滤模式为 whitelist 时则只有它们使用 Fake-IP。';

  @override
  String get fallbackFilterGeositeDesc => '属于这些 GeoSite 分类的域名直接使用 Fallback 解析。';

  @override
  String get fallbackFilterIpcidrDesc =>
      'Nameserver 返回这些网段内的 IP 时，改用 Fallback 的结果。';

  @override
  String get fallbackFilterDomainDesc => '这些域名直接使用 Fallback 解析。';

  @override
  String get tsCurrentDevice => '当前设备';

  @override
  String tsNodeOf(Object name) {
    return '节点 $name';
  }

  @override
  String tsStatusOf(Object label) {
    return '状态：$label';
  }

  @override
  String get tsChooseNode => '选择节点';

  @override
  String get tsRefresh => '刷新';

  @override
  String get tsHelp => '补充说明';

  @override
  String get tsHelpBody =>
      'Flash 会在 Tailscale 网络中显示为独立设备。它不提供其他设备连入这台 Mac 的 SSH、文件共享或远程桌面功能，也不提供 Tailscale SSH 或 Taildrop。';

  @override
  String get tsNetworkNameTip => '网络名称不代表已核实的网络所有者。';

  @override
  String get tsBoundaryTip =>
      '只有由 Flash 规则转到此节点的流量才会使用 Tailscale。登录不会自动修改规则、系统代理或虚拟网卡设置。';

  @override
  String get tsGoToRules => '前往规则';

  @override
  String get tsGoToProfiles => '前往配置';

  @override
  String get tsCoreStopped => '内核未运行';

  @override
  String get tsCoreStoppedTip => '启动内核后，才能查看此节点的 Tailscale 状态。';

  @override
  String get tsStartCore => '启动内核';

  @override
  String get tsNodeGone => '此节点已不在当前配置中';

  @override
  String get tsNodeGoneTip => '请重新选择节点。';

  @override
  String get tsStateSignedOut => '未登录';

  @override
  String get tsStatePreparing => '正在准备登录…';

  @override
  String get tsStateStarting => '正在启动…';

  @override
  String get tsStateWaitingBrowser => '等待浏览器登录';

  @override
  String get tsStateNeedsApproval => '等待管理员批准';

  @override
  String get tsStateConnected => '已连接';

  @override
  String get tsStateNeedsReauth => '需要重新登录';

  @override
  String get tsStateStopped => '已停止';

  @override
  String get tsStateStartFailed => '启动失败';

  @override
  String get tsStateUnconfirmed => '状态待确认';

  @override
  String get tsStateLoadFailed => '状态加载失败';

  @override
  String get tsSignedOutTip => '在浏览器中登录，完成此节点的认证。';

  @override
  String get tsLoggedOutTip => '你已退出此节点。点击登录后才会重新连接。';

  @override
  String get tsPreparingTip => '正在获取此节点的登录信息。';

  @override
  String get tsWaitingBrowserTip => '请在浏览器中完成登录。完成后，这里会根据节点状态更新。';

  @override
  String get tsNeedsApprovalTip => '浏览器认证已完成。请等待 Tailscale 网络管理员批准此设备。';

  @override
  String get tsNeedsReauthTip => '此节点的认证已过期，请重新登录。';

  @override
  String tsExpiryTip(Object time) {
    return '认证将于 $time 到期，请在到期前重新登录。';
  }

  @override
  String get tsStoppedTip => '此节点已停止，暂时无法通过它访问 Tailscale 网络。';

  @override
  String get tsStartFailedTip => '此节点未能启动，请重试。';

  @override
  String get tsUnconfirmedTip => '暂时无法确认此节点是否已连接，请重新读取状态。';

  @override
  String get tsLoadFailedTip => '暂时无法读取此节点的状态，请重试。';

  @override
  String get tsDeviceName => '设备名称';

  @override
  String get tsAccount => '登录账号';

  @override
  String get tsNetwork => '所在网络';

  @override
  String get tsControlServer => '控制服务器';

  @override
  String get tsAfterLogin => '登录后可查看';

  @override
  String get tsAccountMissing => '账号信息未提供';

  @override
  String get tsNetworkMissing => '网络信息未提供';

  @override
  String get tsIdentityFailed => '账号与网络信息加载失败';

  @override
  String get tsCopyAddress => '复制地址';

  @override
  String get tsCopyName => '复制名称';

  @override
  String get tsAddressCopied => '地址已复制';

  @override
  String get tsLogin => '登录 Tailscale';

  @override
  String get tsRelogin => '重新登录';

  @override
  String get tsReopenLogin => '重新打开登录页';

  @override
  String get tsReadStatus => '重新读取状态';

  @override
  String get tsLogout => '退出当前节点';

  @override
  String get tsLoggingOut => '正在退出…';

  @override
  String get tsLogoutTitle => '退出此 Tailscale 节点？';

  @override
  String tsLogoutBody(Object name) {
    return '将退出“$name”，并清除本机保存的该节点登录身份。经过此节点的连接可能中断，其他节点不受影响。';
  }

  @override
  String get tsLogoutAuthKeyNote => '再次点击登录时，将使用配置中的登录密钥注册新的设备身份。';

  @override
  String get tsLoggedOutReceipt => '已退出此节点。再次点击登录前，此节点不会自动登录。';

  @override
  String get tsLogoutFailed => '退出失败，请重新读取节点状态后重试。';

  @override
  String get tsLogoutUnknown => '退出结果待确认，请重新读取节点状态，确认前请勿重复操作。';

  @override
  String get tsBrowserFailed => '无法打开登录页，请重试。';

  @override
  String get tsUrlRejected => '无法安全打开此登录页，请检查当前节点的控制服务器配置。';

  @override
  String get tsUrlMissing => '尚未获取到可用的登录页，请重新准备登录。';

  @override
  String get tsPrepareAgain => '重新准备登录';

  @override
  String get tsLoginUnconfirmed => '尚未确认登录结果，请重新读取节点状态。';

  @override
  String get tsNodeChanged => '当前节点已变化，请在所选节点重新发起操作。';

  @override
  String get tsExitNode => '出口节点';

  @override
  String get tsNoExitNode => '不使用出口节点';

  @override
  String get tsNoExitNodeTip => '不使用出口节点不会退出 Tailscale';

  @override
  String get tsExitNodeTip => '只影响经此 Tailscale 节点转发的流量，不会让整台 Mac 自动使用该出口。';

  @override
  String get tsNoExitCandidates => '暂无可用出口节点';

  @override
  String get tsNoExitCandidatesTip => '当前没有已确认可用的出口节点';

  @override
  String get tsExitStale => '请先刷新设备列表，再选择出口节点。';

  @override
  String get tsChooseExitNode => '选择出口节点';

  @override
  String get tsOfflineNotSelectable => '离线，不可选';

  @override
  String get tsExitChangeTitle => '更改出口节点？';

  @override
  String tsExitChangeBody(Object node, Object device) {
    return '将“$node”的出口节点设为“$device”。经过此节点的连接可能中断；Flash 的规则不变。';
  }

  @override
  String get tsExitChangeConfirm => '更改出口节点';

  @override
  String get tsExitOffTitle => '不再使用出口节点？';

  @override
  String tsExitOffBody(Object node) {
    return '仅关闭“$node”的出口转发，不会退出 Tailscale，Flash 的规则不变。';
  }

  @override
  String get tsExitApplying => '正在更改出口节点…';

  @override
  String get tsExitUpdated => '出口节点已更新';

  @override
  String get tsExitFailed => '出口节点未更改，请重试。';

  @override
  String get tsExitUnknown => '出口节点的更改结果待确认，请重新读取当前设置。';

  @override
  String get tsReadSettings => '重新读取设置';

  @override
  String get tsSettingsSaved => '设置已保存，但尚未确认生效。请重新读取当前设置。';

  @override
  String get tsSettingsApplyFailed => '设置已保存，但未能应用到当前节点。请重新读取当前设置。';

  @override
  String get tsSubnetRoutes => '子网路由';

  @override
  String get tsAcceptRoutes => '接受子网路由';

  @override
  String get tsAcceptRoutesTip =>
      '允许此节点使用 Tailscale 网络中已批准的子网路由。是否有流量经过这些路由，仍由现有规则决定；不会自动修改 Flash 的规则。';

  @override
  String get tsRoutesOnTitle => '接受子网路由？';

  @override
  String get tsRoutesOnBody => '此节点将允许使用网络中已批准的子网路由。Flash 的规则不变。';

  @override
  String get tsRoutesOffTitle => '停止接受子网路由？';

  @override
  String get tsRoutesOffBody => '此节点将不再使用这些子网路由，相关连接可能中断。Flash 的规则不变。';

  @override
  String get tsRoutesOffConfirm => '停止接受';

  @override
  String get tsRoutesApplying => '正在更新子网路由设置…';

  @override
  String get tsRoutesUpdated => '子网路由设置已更新';

  @override
  String get tsRoutesFailed => '子网路由设置未更改，请重试。';

  @override
  String get tsRoutesUnknown => '子网路由设置的更改结果待确认，请重新读取当前设置。';

  @override
  String get tsOn => '已开启';

  @override
  String get tsOff => '已关闭';

  @override
  String get tsFromSubscription => '来自订阅';

  @override
  String get tsFromProfile => '来自当前配置';

  @override
  String get tsFromProvider => '来自代理集合';

  @override
  String get tsFromLocal => '本机设置';

  @override
  String get tsOverrideAmbiguous =>
      '当前配置中有多个同名节点使用同一控制服务器，暂时无法分别保存设置。请在配置中为它们使用不同名称。';

  @override
  String get tsOverrideTip => '此处保存的设置优先于当前配置中的同名设置，不会修改订阅文件。';

  @override
  String get tsChangeAfterSignIn => '登录并连接后可更改';

  @override
  String tsSavedValue(Object value) {
    return '已保存：$value';
  }

  @override
  String get tsAfterConnectSelectable => '此节点连接后可更改设置。';

  @override
  String get tsDevices => '设备';

  @override
  String get tsDevicesScope => '显示当前节点可见的设备，不代表管理后台中的全部设备';

  @override
  String get tsAddress => 'Tailscale 地址';

  @override
  String get tsOwner => '归属';

  @override
  String get tsSystem => '系统';

  @override
  String get tsStatus => '状态';

  @override
  String get tsOnline => '在线';

  @override
  String get tsOffline => '离线';

  @override
  String get tsStatusUnknown => '状态未知';

  @override
  String get tsExitCapable => '可作出口节点';

  @override
  String get tsNameMissing => '设备名称未提供';

  @override
  String get tsAddressMissing => '地址未提供';

  @override
  String get tsSystemMissing => '系统未提供';

  @override
  String get tsDevicesEmpty => '暂无可见设备';

  @override
  String get tsDevicesEmptyTip => '当前节点暂未发现其他可见设备。';

  @override
  String get tsDevicesFailed => '设备列表加载失败，请重试。';

  @override
  String get tsRefreshDevices => '刷新设备列表';

  @override
  String get tsDevicesStale => '设备列表可能已过期。刷新失败，以下为上次读取的结果。';

  @override
  String tsDevicesShown(Object n) {
    return '当前显示 $n 台设备';
  }

  @override
  String tsDevicesCompact(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台设备 · 仅显示此账号可见的设备',
    );
    return '$_temp0';
  }

  @override
  String tsDevicesCompactFiltered(Object shown, Object total) {
    return '显示 $shown/$total 台 · 仅限此账号可见的设备';
  }

  @override
  String get tsSearchHint => '搜索名称或地址';

  @override
  String get tsSearchEmpty => '没有符合搜索条件的设备';

  @override
  String get tsOwnerFilter => '设备归属';

  @override
  String get tsOwnerAll => '全部';

  @override
  String get tsOwnerMine => '我的';

  @override
  String get tsOwnerMe => '我';

  @override
  String get tsOwnerUnknown => '归属未知';

  @override
  String tsOwnerUnknownNetwork(Object network) {
    return '未知 · 网络 $network';
  }

  @override
  String get tsOwnerFilterEmpty => '没有符合当前归属的设备';

  @override
  String get tsFilterEmpty => '没有符合当前筛选条件的设备';

  @override
  String get tsClearOwnerFilter => '清除归属筛选';

  @override
  String get tsShared => '来自共享';

  @override
  String tsSharedBy(Object name) {
    return '分享来源：$name';
  }

  @override
  String get tsLegacyTitle => '发现旧版登录记录';

  @override
  String get tsLegacyAccountUnconfirmed => '账号信息未确认';

  @override
  String get tsLegacyBody =>
      '可将这份登录记录复制给当前节点，保留原记录。它只能迁移到一个节点；请确认这是你要继续使用的账号，也可以选择重新登录。';

  @override
  String get tsLegacyAuthKeyNote => '此节点配置了登录密钥，重新登录将使用该密钥注册新的设备身份，旧登录记录仍保留。';

  @override
  String get tsLegacyMigrate => '迁移到这个节点';

  @override
  String get tsLegacyMigrating => '正在迁移登录记录…';

  @override
  String get tsLegacyRetry => '重试迁移';

  @override
  String get tsLegacyFailed => '登录记录未迁移，原记录仍保留。请重试，或选择重新登录。';

  @override
  String get tsLegacyClaimFailed => '登录记录未迁移，迁移信息未能保存。请重试，或选择重新登录。';

  @override
  String get tsLegacyChanged => '迁移信息已变化，请重新核对后确认。';

  @override
  String get tsLegacyUnknown => '迁移结果待确认。请先重新读取状态，确认前请勿重复迁移或重新登录。';

  @override
  String get tsLegacyUnknownTarget =>
      '迁移结果待确认，尚未确认目标节点的登录记录。请先重新读取状态，确认前请勿重复迁移或重新登录。';

  @override
  String get tsLegacyUnknownArchive =>
      '迁移结果待确认，原登录记录暂时无法核验。请先重新读取状态，确认前请勿重复迁移或重新登录。';

  @override
  String get tsLegacyUnknownUnsaved =>
      '迁移结果待确认，迁移信息未能保存。请先重新读取状态，确认前请勿重复迁移或重新登录。';

  @override
  String get tsLegacyMigrated => '登录记录已迁移，正在读取节点状态。';

  @override
  String get tsLegacyHasIdentity => '此节点已有自己的登录记录，无需迁移。';

  @override
  String get tsLegacyControlMismatch => '旧登录记录的控制服务器与此节点不一致，无法迁移。';

  @override
  String get tsLegacyInUse => '旧登录记录仍在使用中，暂时无法迁移。';

  @override
  String get tsLegacyMigratedElsewhere => '这份旧登录记录已迁移到其他节点，不能再次迁移。';

  @override
  String get tsLegacyUnreadable => '无法读取旧登录记录，请重新核对。';

  @override
  String get tsLegacyUnreadableNotMigrated => '登录记录未迁移，无法读取旧登录记录。请重新核对。';

  @override
  String get tsLegacyUnconfirmed => '旧登录记录的可用状态尚未确认，请重新读取状态。';

  @override
  String get tsLegacyConfirmTitle => '将旧登录迁移到此节点？';

  @override
  String tsLegacyConfirmProfile(Object name) {
    return '配置：$name';
  }

  @override
  String tsLegacyConfirmNode(Object name) {
    return '节点：$name';
  }

  @override
  String tsLegacyConfirmAccount(Object account) {
    return '登录账号：$account';
  }

  @override
  String tsLegacyConfirmControl(Object server) {
    return '控制服务器：$server';
  }

  @override
  String get tsLegacyConfirmBody =>
      '将复制这份登录记录供上述节点使用，原记录保留不动。同一份旧记录不能再迁移给其他节点。迁移完成后仍需检查此节点的真实连接状态。';

  @override
  String get tsLegacyConfirm => '确认迁移';

  @override
  String get tsSignIn => '登录 Tailscale';

  @override
  String get tsSignInTip =>
      '登录后，Flash 会为当前配置添加 Tailscale 节点和专用规则。其他流量仍按原规则分流，原配置文件保持不变。';

  @override
  String get tsSignInBoundary => '不会自动开启系统代理或虚拟网卡。';

  @override
  String get tsPreparingProfile => '正在准备本地配置…';

  @override
  String get tsPreparingSignIn => '正在准备登录…';

  @override
  String get tsPreparingSignInTip => '正在为当前配置准备 Tailscale。';

  @override
  String get tsAttaching => '正在接入当前配置…';

  @override
  String get tsAttachingTip => '登录已完成，正在添加节点和 Tailscale 专用规则。';

  @override
  String get tsAttached => '已接入当前配置';

  @override
  String get tsAttachedTip => 'Tailscale 流量使用专用规则，其他流量仍按原规则分流。';

  @override
  String get tsPrepareFailed => '暂时无法准备 Tailscale 登录，请重试。';

  @override
  String get tsAttachFailed => '已登录，尚未接入当前配置。登录记录已保留，请重试接入。';

  @override
  String get tsRetryAttach => '重试接入';

  @override
  String get tsAttachUnknown => '配置接入结果待确认。请先重新读取状态，确认前请勿重复添加或重新登录。';

  @override
  String get tsPrepareUnknown => '登录准备结果待确认。请先重新读取状态，确认前请勿重复登录。';

  @override
  String get tsAttachLockTip => '正在接入当前配置，暂时无法更改设置。';

  @override
  String get tsAttachUnknownLockTip => '配置接入结果待确认，请先重新读取状态。';

  @override
  String get tsAddedInPanel => '面板添加';

  @override
  String get tsRulesManaged =>
      'Flash 会按此账号的网络域名和设备地址更新专用规则。其他流量仍按原规则分流，原配置文件保持不变。';

  @override
  String tsRulesDomain(Object domain) {
    return '网络域名：$domain';
  }

  @override
  String tsRulesAddresses(Object count) {
    return '设备地址：$count 个';
  }

  @override
  String get tsRulesPending =>
      '接入完成后，Tailscale 地址和 ts.net 域名会使用专用规则，其他流量保留原分流。';

  @override
  String get tsRulesProfileNode =>
      '只有由 Flash 规则转到此节点的流量才会使用 Tailscale。登录此节点不会自动修改现有规则，也不会开启系统代理或虚拟网卡。';

  @override
  String get tsUnverifiedBlocked =>
      '未匹配到可靠归属的 Tailscale 地址和域名会被拦截，不会改用其他账号或直连。';

  @override
  String get tsManagedPriority =>
      '面板添加的专用规则和拦截保护优先于对应的现有规则。普通流量的规则不变。需要更改目标归属时，请在此指定账号。';

  @override
  String get tsSignOutRemove => '退出并移除';

  @override
  String get tsSignOutRemoveMenu => '退出并移除…';

  @override
  String get tsRemoveTitle => '退出并移除此账号？';

  @override
  String tsRemoveBody(Object account, Object node, Object profile) {
    return '将退出“$account”（节点“$node”），清除本机保存的该节点登录身份，并从“$profile”移除面板添加的节点和专用规则。经过此节点的连接可能中断。不会退出或移除其他账号。';
  }

  @override
  String tsRemoveBodyNode(Object node, Object profile) {
    return '将退出“$node”，清除本机保存的该节点登录身份，并从“$profile”移除面板添加的节点和专用规则。经过此节点的连接可能中断。不会退出或移除其他账号。';
  }

  @override
  String get tsRemoveExtra => '此操作不删除 Tailscale 管理页面中的设备，也不更改官方客户端。';

  @override
  String get tsRemoveTargetsKept =>
      '原来指定给此账号的目标不会自动交给其他账号，仍会保留拦截保护。需要继续访问时，请重新指定账号。';

  @override
  String get tsRemoveLast =>
      '这是当前配置中最后一个面板添加的账号。移除后，面板添加的专用规则和拦截保护也会撤掉，相关流量恢复按原配置处理，可能直连或走原来的代理。请确认你接受这个变化。';

  @override
  String get tsRemoving => '正在退出并移除…';

  @override
  String get tsRemoved => '已退出并移除';

  @override
  String get tsRemoveLogoutUnknown => '退出结果待确认，暂未移除节点。请先重新读取状态，确认前请勿重复移除或重新登录。';

  @override
  String get tsRemoveIncomplete => '已退出，尚未完成移除。请先重新读取状态。';

  @override
  String get tsRemoveUnknown => '移除结果待确认。请先重新读取状态，确认前请勿重新添加或登录。';

  @override
  String get tsSignOutAccount => '退出此账号';

  @override
  String get tsSignOutAccountTitle => '退出此账号？';

  @override
  String tsSignOutAccountBody(Object account, Object node) {
    return '将退出“$account”（节点“$node”），并清除本机保存的该节点登录身份。面板记录和目标归属会保留；发往此账号的连接可能中断，不会自动改用其他账号或直连。不会退出其他账号。再次使用时需由你点击登录。';
  }

  @override
  String get tsAccountSignedOut => '已退出';

  @override
  String get tsSignedOutBanner =>
      '已退出此账号。在规则模式下，原来交给此账号的目标将被拦截，直到你主动登录或明确更改归属。';

  @override
  String get tsSignedOutReceipt => '已退出此账号';

  @override
  String get tsAccountsInProfile => '当前配置中的 Tailscale 账号';

  @override
  String get tsAddAccount => '添加 Tailscale 账号';

  @override
  String get tsNewAccount => '新账号';

  @override
  String tsNetworkOf(Object name) {
    return '所在网络：$name';
  }

  @override
  String tsSwitcherSemantics(Object account, Object status, Object count) {
    return '当前查看的 Tailscale 账号：$account，$status，共 $count 项';
  }

  @override
  String get tsMemoryTip => '每个账号都会运行独立的 Tailscale 设备，同时在线会增加内存占用。';

  @override
  String get tsDuplicate => '此账号已有条目。本次登录记录已保留，尚未接入分流，请核对后处理。';

  @override
  String get tsViewExisting => '查看已有账号';

  @override
  String get tsCheckingAccount => '正在核对账号…';

  @override
  String get tsAddUnconfirmed => '账号添加结果待确认，请先重新读取状态。';

  @override
  String tsConflictTitle(Object count) {
    return '$count 个目标需要指定账号';
  }

  @override
  String get tsConflictBody => '这些地址或域名有多个候选账号。指定账号前，对这些目标的访问会被拦截，不会转为直连。';

  @override
  String get tsChooseAccounts => '指定账号';

  @override
  String get tsAddressConflict => '地址冲突';

  @override
  String get tsRoutingConflict => '归属冲突';

  @override
  String get tsChooseAccountFor => '指定访问账号';

  @override
  String get tsAssignTitle => '指定目标的访问账号';

  @override
  String get tsAssignBody =>
      '每个目标只能指定一个账号。未指定的目标仍会被拦截，此选择不影响其他目标。指定后不会因账号离线而自动改用其他账号。';

  @override
  String tsTargetAddress(Object address) {
    return '地址：$address';
  }

  @override
  String tsTargetDomain(Object domain) {
    return '域名：$domain';
  }

  @override
  String tsCandidate(Object account, Object network) {
    return '$account · $network';
  }

  @override
  String get tsNotAssigned => '尚未指定';

  @override
  String get tsSaveChoices => '保存选择';

  @override
  String get tsChoicesUpdated => '访问账号已更新';

  @override
  String get tsAssignedTargets => '已指定的目标';

  @override
  String get tsChoicesSaved => '选择已保存，尚未确认生效。';

  @override
  String get tsChoicesFailed => '选择未保存，请重试。';

  @override
  String get tsChoicesUnknown => '选择结果待确认，请先重新读取状态，确认前请勿重复保存。';

  @override
  String tsAssignedTo(Object account) {
    return '已指定：$account';
  }

  @override
  String get tsAssignedUnavailable => '指定账号暂不可用，此目标不会改用其他账号。';

  @override
  String get tsReconfirm => '目标归属需要重新确认，访问已拦截。请重新指定账号。';

  @override
  String get tsReassign => '重新指定账号';

  @override
  String get tsTargetUnconfirmed => '目标归属待确认';

  @override
  String get tsTargetUnconfirmedTip => '暂时无法确认此目标应使用哪个账号，访问已拦截。';

  @override
  String tsDeleteProfileManaged(Object count) {
    return '此配置包含 $count 个面板添加的 Tailscale 账号。删除配置会移除这些账号与此配置的关联、目标归属及专用规则和拦截保护；本机登录存档仍会保留。不会删除 Tailscale 管理页面中的设备，其他配置不受影响。';
  }

  @override
  String get tsDeleteProfilePending =>
      '此配置还有待确认的 Tailscale 操作，请先重新读取状态，确认后再删除配置。';

  @override
  String get tsDeleteProfileUnbindFailed =>
      '未能解除此配置与 Tailscale 账号的关联，配置未删除。请重试。';

  @override
  String get tsDeleteProfileUnlinkUnconfirmed =>
      '账号关联的处理结果待确认，配置尚未删除。请先重新读取状态，确认前请勿重复删除。';

  @override
  String get tsDeleteProfileUnconfirmed => '配置删除结果待确认。请先重新读取状态，确认前请勿重复删除。';

  @override
  String get tsTryAgain => '重试';

  @override
  String get tsDirectMode => '当前为直连模式，Tailscale 自动分流和拦截保护未生效。请手动切换到规则模式后再访问。';

  @override
  String get tsGlobalMode => '当前为全局模式，Tailscale 自动分流和拦截保护未生效。请手动切换到规则模式后再访问。';

  @override
  String get tsDnsUnverified =>
      '当前 DNS 设置无法确认目标域名会保留到规则匹配，域名分流尚未核实。请检查 DNS 设置。';

  @override
  String get tsCancel => '取消';

  @override
  String get tsSignInShort => '登录后自动添加节点和专用规则。';

  @override
  String tsRulesSummary(num count, Object domain) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$domain · $count 个设备地址',
    );
    return '$_temp0';
  }

  @override
  String get tsRulesUnconfirmed => '域名和地址信息待确认';

  @override
  String tsDevicesFiltered(Object shown, Object total) {
    return '显示 $shown / $total 台';
  }

  @override
  String get tsAboutTailscale => 'Tailscale 说明';

  @override
  String get tsAboutExit => '出口设置说明';

  @override
  String get tsAboutRoutes => '子网路由说明';

  @override
  String get tsAboutRules => '规则说明';

  @override
  String get infoAbout => '说明';

  @override
  String get mountApplyKept => '未能应用挂载，仍使用上次确认的运行配置。';

  @override
  String get mountApplyBlocked =>
      '未能应用挂载。Flash 当前会拒绝所有经它转发的连接。请先重新读取状态，确认结果后再解除挂载或重新应用配置。';

  @override
  String get mountApplyBlockedConfirmed =>
      '已确认挂载未能应用。Flash 当前仍会拒绝所有经它转发的连接。你可以解除挂载或重新应用配置。';

  @override
  String get mountSourceNoNodeList => '此订阅未提供可挂载的节点列表，请检查订阅格式。';

  @override
  String get mountDeleteSourceTitle => '删除订阅并解除挂载？';

  @override
  String mountDeleteSourceBody(Object subscriptionName, num profileCount) {
    return '“$subscriptionName”还挂载在以下 $profileCount 份配置中。删除后，将从这些配置移除此订阅提供的节点，相关连接可能中断。其他订阅、基础配置文件和 Tailscale 登录记录不会删除。';
  }

  @override
  String get mountDeleteSourceConfirm => '删除并解除挂载';

  @override
  String get mountDeleteSourceProgress => '正在删除并解除挂载…';

  @override
  String get mountDeleteSourceDone => '订阅已删除并解除挂载';

  @override
  String get mountDeleteSourceUnknown =>
      '订阅删除与解除挂载的结果待确认，请先重新读取状态，确认前请勿重复删除或重新挂载。';

  @override
  String get mountDeleteSourceBlocked => '此订阅或受影响配置仍有待确认的操作，请先重新读取状态，确认后再删除。';

  @override
  String get mountReadStatus => '重新读取状态';

  @override
  String get mountEntry => '挂载订阅节点';

  @override
  String get mountEntryMenu => '挂载订阅节点…';

  @override
  String mountedCount(num count) {
    return '已挂载 $count 份订阅';
  }

  @override
  String mountCardFailed(num count) {
    return '$count 份订阅更新失败';
  }

  @override
  String get mountCardUnreadable => '挂载状态读取失败';

  @override
  String mountPillSemantics(Object label, Object profileName) {
    return '$label, 目标配置 $profileName';
  }

  @override
  String get mountPillFailedSemantics => '有订阅更新失败';

  @override
  String mountTarget(Object profileName) {
    return '目标配置：$profileName';
  }

  @override
  String get mountDescription => '只添加节点，不改规则和 DNS。';

  @override
  String get mountChooseSources => '选择订阅';

  @override
  String get mountMountedTag => '已挂载';

  @override
  String get mountNotMounted => '未挂载';

  @override
  String get mountEmptyTitle => '暂无可挂载的订阅';

  @override
  String get mountEmptyDesc => '先通过链接导入机场订阅，再选择要加入此配置的节点来源。';

  @override
  String get mountImport => '导入订阅';

  @override
  String get mountImportHint => '导入后返回此处选择订阅，不会切换你正在使用的配置。';

  @override
  String mountNodeCount(num count) {
    return '$count 个节点';
  }

  @override
  String mountLastUpdated(Object time) {
    return '上次更新：$time';
  }

  @override
  String get mountNotFetched => '尚未获取节点';

  @override
  String get mountListFailed => '订阅列表加载失败，请重试。';

  @override
  String get mountReadAgain => '重新读取';

  @override
  String get mountSave => '保存挂载';

  @override
  String get mountSaving => '正在保存挂载…';

  @override
  String get mountApplying => '挂载已保存，正在应用…';

  @override
  String get mountUpdated => '订阅节点挂载已更新';

  @override
  String get mountSavedUnconfirmed => '挂载已保存，尚未确认生效。';

  @override
  String get mountUnchanged => '挂载未更改，请重试。';

  @override
  String get mountApplyFailed => '挂载已保存，但未能应用到当前运行配置。';

  @override
  String get mountUnknown => '挂载结果待确认，请先重新读取状态，确认前请勿重复保存或解除挂载。';

  @override
  String get mountUpdateNodes => '更新节点';

  @override
  String mountUpdateNodesOf(Object name) {
    return '更新节点 $name';
  }

  @override
  String get mountUpdatingNodes => '正在更新节点…';

  @override
  String get mountNodesUpdated => '节点已更新';

  @override
  String get mountUpdateFailedInUse => '更新失败，继续使用上次成功获取的节点。';

  @override
  String get mountUpdateFailedKept => '更新失败，已保留上次成功获取的节点，尚未确认当前是否生效。';

  @override
  String get mountUpdateFailedKeptBlocked => '更新失败，已保留上次成功获取的节点。';

  @override
  String get mountFetchFailed => '暂时无法获取此订阅的节点，请重试。';

  @override
  String get mountSourceEmpty => '订阅已更新，目前没有节点。';

  @override
  String get mountSourceGone => '原订阅已不可用，请重新选择节点来源。';

  @override
  String get mountSelectionLost => '原来选择的节点已不在此订阅中，请重新选择。';

  @override
  String get mountTailscaleExcluded => '已从普通挂载中排除 Tailscale 节点。';

  @override
  String get mountSourceRelayOnly => '此订阅的节点均需经 Tailscale 中转，暂不支持挂载。原中转设置未更改。';

  @override
  String get mountSourceIsolatedOnly => '此订阅的节点均因挂载隔离要求被排除，暂不支持挂载；原设置未更改。';

  @override
  String get mountSourceTailscaleOnly => '此订阅仅包含 Tailscale 节点，暂不支持挂载。';

  @override
  String get mountSameName =>
      '不同来源有同名节点时，会在名称后加上订阅名以区分。名称变化可能影响完整匹配或按结尾筛选，请核对分组结果。';

  @override
  String get mountGroupsTitle => '节点加入哪些分组';

  @override
  String get mountHintFiltered => '自动收集 · 按组筛选';

  @override
  String get mountNoGroupTitle => '当前配置没有自动接收新节点的分组，挂载节点未加入任何分组。';

  @override
  String get mountNoGroupDesc => '不会自动新建分组或更改分流规则。';

  @override
  String get mountGroupsFailed => '暂时无法读取此配置的分组，请重新读取。';

  @override
  String get mountTypeSelect => '手动选择';

  @override
  String get mountTypeUrlTest => '延迟优选';

  @override
  String get mountTypeFallback => '故障切换';

  @override
  String get mountTypeLoadBalance => '负载均衡';

  @override
  String get mountBlockTag => '空组时拦截';

  @override
  String get mountBlockDesc => '此组没有可选节点时会拦截相关连接，不会自动转为直连。';

  @override
  String mountBaseFallback(Object target) {
    return '空组处理来自原配置：$target。';
  }

  @override
  String get mountBaseDirect => '没有可选节点时，此组会按原配置直连。';

  @override
  String mountGroupEmpty(Object group) {
    return '分组“$group”暂无可选节点，请检查订阅和分组筛选。';
  }

  @override
  String get mountUnmountTitle => '解除此订阅的挂载？';

  @override
  String mountUnmountBody(Object subscriptionName, Object profileName) {
    return '将从“$profileName”移除“$subscriptionName”提供的节点。使用这些节点的连接可能中断。订阅本身、原配置文件和其他挂载不会删除，Tailscale 专用分流不变。';
  }

  @override
  String get mountUnmountManyTitle => '解除这些订阅的挂载？';

  @override
  String mountUnmountManyBody(num count, Object profileName) {
    return '将从“$profileName”移除以下 $count 份订阅提供的节点。使用这些节点的连接可能中断。订阅本身、原配置文件和其他挂载不会删除，Tailscale 专用分流不变。';
  }

  @override
  String get mountUnmount => '解除挂载';

  @override
  String get mountUnmounting => '正在解除挂载…';

  @override
  String get mountUnmounted => '已解除挂载';

  @override
  String get mountUnmountUnknown => '解除挂载结果待确认，请先重新读取状态。';

  @override
  String get mountUpdateTitle => '更新订阅挂载？';

  @override
  String mountAlsoMounts(num count) {
    return '本次保存还将挂载 $count 份订阅。';
  }

  @override
  String get mountFormatHelp =>
      '可挂载已导入的远程 Clash/mihomo 订阅，以及 Flash 现有导入功能成功转换的远程订阅。只引入节点，不引入订阅中的规则或 DNS。';

  @override
  String mountGroupsExcluded(num count) {
    return '为保持 Tailscale 分流隔离，$count 个分组不接收订阅节点。';
  }

  @override
  String mountGroupsExcludedNames(Object groups) {
    return '涉及分组：$groups。';
  }

  @override
  String get mountNameSeparator => '、';

  @override
  String get mountGroupReasonRuleUnknown => '暂时无法读取规则内容';

  @override
  String get mountGroupReasonProviderUnknown => '暂时无法读取基础配置的节点列表';

  @override
  String get mountGroupReasonDns => 'DNS 请求会按分流规则选择出口';

  @override
  String get mountGroupReasonDialer => '此分组被其他节点用作中转出口';

  @override
  String get mountGroupReasonMember => '此分组因成员关联而受限，具体原因待确认';

  @override
  String get mountNoGroupIsolatedTitle => '当前分组暂不支持挂载';

  @override
  String get mountNoGroupIsolatedDesc =>
      '现有分组均未通过挂载隔离检查。不会自动新建分组、改成直连或改写原配置文件。';

  @override
  String mountNodesRead(num count) {
    return '已读取 $count 个节点';
  }

  @override
  String mountNodesReadAt(Object time) {
    return '节点读取时间：$time';
  }

  @override
  String get mountUpdateReadNotAppliedKept => '新节点已读取，但尚未应用。仍使用上次确认的运行配置。';

  @override
  String get mountUpdateReadNotAppliedBlocked =>
      '新节点已读取，但尚未应用。Flash 当前会拒绝所有经它转发的连接，请重新读取状态。';

  @override
  String get mountUpdateReadNotAppliedBlockedConfirmed =>
      '新节点已读取，但尚未应用。Flash 当前仍会拒绝所有经它转发的连接。';

  @override
  String get mountUpdateReadEmptyNotApplied => '订阅已读取，目前没有节点。新结果尚未应用。';

  @override
  String get mountRunningKept => '仍使用上次确认的运行配置。';

  @override
  String get mountRunningBlocked => 'Flash 当前会拒绝所有经它转发的连接，请重新读取状态。';

  @override
  String get mountRunningBlockedConfirmed => 'Flash 当前仍会拒绝所有经它转发的连接。';

  @override
  String mountProviderUpdateRefused(Object name) {
    return '“$name”的新内容已读取，但未通过挂载隔离检查，未应用；仍使用此前确认的内容。';
  }

  @override
  String mountProviderUpdateRefusedUnconfirmed(Object name) {
    return '“$name”的新内容已读取，但未通过挂载隔离检查，未应用；当前使用状态待确认，请重新读取状态。';
  }

  @override
  String mountUnsupportedExcluded(num count) {
    return '为保持 Tailscale 分流隔离，已排除 $count 个暂不支持挂载的订阅节点，原设置未更改。';
  }

  @override
  String get mountAbout => '挂载说明';

  @override
  String get mountAboutBody =>
      '选择已导入的机场订阅，为当前配置添加节点。节点只加入原配置中会自动接收新节点的分组，再按各组的筛选和排除条件过滤。只列出固定成员、且不自动接收新节点的分组保持原样。已有节点、规则和 DNS 不变。';

  @override
  String get mountIsolationFirst =>
      'Tailscale 及其他挂载隔离要求仍优先适用，不允许接入的分组不会收到订阅节点。';

  @override
  String get mountGroupsSummary => '只加入自动接收新节点的分组，再按各组条件筛选。';

  @override
  String mountGroupsCount(num count) {
    return '$count 个分组';
  }

  @override
  String get mountGroupPending => '待应用';

  @override
  String mountGroupNodes(num count) {
    return '$count 个挂载节点';
  }

  @override
  String get mountGroupNoMatch => '无匹配挂载节点';

  @override
  String mountGroupsNoMatch(num count) {
    return '$count 个分组无匹配';
  }

  @override
  String get mountGroupsAllNoMatch => '挂载节点未匹配任何分组的筛选条件。';

  @override
  String get mountGroupsUnconfirmed => '分组接入尚未确认';

  @override
  String mountShowAllGroups(Object count) {
    return '显示全部 $count 个分组';
  }

  @override
  String get mountGroupsHidden => '隐藏的普通分组也按筛选和隔离规则处理，此处不列出。';

  @override
  String mountGroupsHiddenCount(num count) {
    return '$count 个隐藏分组';
  }

  @override
  String mountGroupsHiddenBlocked(num count) {
    return '$count 个隐藏分组当前为空，连接会被拦截。';
  }

  @override
  String mountGroupsHiddenNoMatch(num count) {
    return '$count 个隐藏分组没有匹配的挂载节点。';
  }

  @override
  String get mountDetails => '详情';

  @override
  String get mountShowLess => '收起';

  @override
  String mountViewerSource(Object name, num count) {
    return '挂载：$name · $count 个节点';
  }

  @override
  String mountViewerPending(Object name) {
    return '挂载：$name · 节点列表待确认';
  }

  @override
  String tsViewerRules(num count, Object node) {
    return 'Tailscale · 由 Flash 添加 · $count 条规则 → 节点 $node';
  }

  @override
  String tsViewerNode(Object node) {
    return 'Tailscale · 由 Flash 添加 · 节点 $node';
  }

  @override
  String get tsViewerUnconfirmed => 'Tailscale · 当前运行的规则和节点待确认';

  @override
  String get tsViewerReadFailed => 'Tailscale · 运行信息读取失败';

  @override
  String get tsViewerNone => 'Tailscale · 当前配置没有 Flash 添加的规则';

  @override
  String get mountSameNameShort => '同名节点以订阅名区分';

  @override
  String mountNodesExcludedShort(num count) {
    return '$count 个节点不参与挂载';
  }

  @override
  String mountGroupsExcludedShort(num count) {
    return '$count 个分组不接收订阅节点';
  }

  @override
  String get mountNamesAndExclusions => '重名及排除说明';

  @override
  String get mountSomeExcluded => '部分节点或分组不参与挂载';

  @override
  String get processPath => '进程路径';

  @override
  String get copyPath => '复制路径';

  @override
  String get filterByThisApp => '筛选此应用';

  @override
  String get filterByThisProcess => '筛选此进程';

  @override
  String get unknownProcess => '未知进程';

  @override
  String get otherDevice => '其他设备';

  @override
  String get processInfoUnavailable => '未获取到进程信息。';

  @override
  String get processUnavailable => '无法获取';

  @override
  String get processFromOtherDevice => '此连接来自其他设备，无法在这台 Mac 上获取其进程信息。';

  @override
  String get appInfoUnreadable => '无法读取应用信息';

  @override
  String get systemService => '系统服务';

  @override
  String systemServiceLabel(Object feature) {
    return '系统服务：$feature';
  }

  @override
  String get systemServiceFeatureHint => 'Apple 系统进程，按路径识别';

  @override
  String get systemServiceSharedHint => '多个应用共用此系统服务，无法确定由哪个应用发起';

  @override
  String appViaLaunchd(Object label) {
    return '由 launchd 任务 $label 关联到此应用';
  }

  @override
  String get svcAppStore => 'App Store';

  @override
  String get svcSoftwareUpdate => '软件更新';

  @override
  String get svcPushNotifications => '推送通知';

  @override
  String get svcICloud => 'iCloud';

  @override
  String get svcPhotos => '照片';

  @override
  String get svcMessages => '信息与 FaceTime';

  @override
  String get svcMaps => '地图';

  @override
  String get svcWeather => '天气';

  @override
  String get svcSiri => 'Siri';

  @override
  String get svcSpotlight => 'Spotlight 建议';

  @override
  String get svcAppleAccount => 'Apple 账户';

  @override
  String get svcFindMy => '查找';

  @override
  String get svcDateTime => '日期与时间';

  @override
  String get svcMail => '邮件';

  @override
  String get svcSafari => 'Safari 浏览器';

  @override
  String get svcNews => '新闻';

  @override
  String get svcHome => '家庭';

  @override
  String get svcGameCenter => 'Game Center';

  @override
  String get svcScreenTime => '屏幕使用时间';

  @override
  String get svcTips => '提示';

  @override
  String get svcBooks => '图书';

  @override
  String get svcReminders => '提醒事项';

  @override
  String get svcContacts => '通讯录';

  @override
  String get svcAnalytics => '分析与改进';

  @override
  String get svcBackgroundDownloads => '后台下载';

  @override
  String get svcNameResolution => '域名解析';

  @override
  String get svcCertificateChecks => '证书校验';

  @override
  String get svcWebContent => '网页内容';

  @override
  String get svcNetworkProxy => '网络代理';

  @override
  String get svcSystemAssets => '系统资源下载';

  @override
  String get svcLocation => '定位';

  @override
  String get svcContinuity => '连续互通';

  @override
  String get svcCaptivePortal => '网络登录';

  @override
  String get svcAppSecurity => '应用安全检查';

  @override
  String get processLookupDisabled => '当前未开启进程查找。';

  @override
  String get pageSourceTitle => '确认设置来源';

  @override
  String get pageSourceDesc => '页面与文件中的以下设置不同，请选择使用的来源。';

  @override
  String pageSourceCompare(Object pageValue, Object fileValue) {
    return '页面：$pageValue · 文件：$fileValue';
  }

  @override
  String get keepPageSetting => '保留页面设置';

  @override
  String get followBaseProfile => '跟随基础配置';

  @override
  String get applyAction => '应用';

  @override
  String get notSet => '未填写';

  @override
  String notSetDefault(Object defaultValue) {
    return '未填写，默认 $defaultValue';
  }

  @override
  String pageSourceChange(Object field, Object oldValue, Object newValue) {
    return '$field：$oldValue → $newValue';
  }

  @override
  String get sourcePage => '页面设置';

  @override
  String get sourceBase => '基础配置';

  @override
  String get sourceDefault => '默认值';

  @override
  String get notYetApplied => '尚未应用';

  @override
  String get logLevelDebug => '调试';

  @override
  String get logLevelInfo => '信息';

  @override
  String get logLevelWarning => '警告';

  @override
  String get logLevelError => '错误';

  @override
  String get logLevelSilent => '静默';

  @override
  String get findProcessAlways => '总是';

  @override
  String get findProcessOff => '关闭';

  @override
  String get findProcessStrict => '按需';

  @override
  String get tunMissingAuthorization => '缺少系统授权，TUN 未启动。';

  @override
  String inboundNotListening(Object listenerName, Object port) {
    return '$listenerName 未启动：端口 $port 未在监听。';
  }

  @override
  String controllerExposedWithoutSecret(Object address) {
    return '外部控制器 $address 允许非本机访问，但未设置密钥。此配置未应用。';
  }

  @override
  String get systemProxyNoPort => '系统代理没有可用的目标端口，请检查端口配置。';

  @override
  String get pageSourceHiddenTitle => '改为跟随配置文件';

  @override
  String get pageSourceHiddenNote => '文件未填写的项使用默认值。';

  @override
  String get valueOn => '开启';

  @override
  String get valueOff => '关闭';

  @override
  String get valueEmptyList => '空列表';

  @override
  String get valueEmptyObject => '空对象';

  @override
  String get valueEmptyText => '空文本';

  @override
  String get valueNull => '空值（null）';

  @override
  String get fieldStoreSelected => '记住节点选择';

  @override
  String get fieldTunAutoRoute => 'TUN 自动路由';

  @override
  String get fieldTunAutoDetectInterface => 'TUN 自动检测网卡';

  @override
  String get fieldSkipAuthPrefixes => '免验证来源地址段';

  @override
  String get fieldExternalUi => '外部控制面板';

  @override
  String get fieldDnsSettings => 'DNS 设置';

  @override
  String get listenerMixed => '混合代理';

  @override
  String get listenerHttp => 'HTTP 代理';

  @override
  String get listenerSocks => 'SOCKS 代理';

  @override
  String get listenerRedir => 'Redir 代理';

  @override
  String get listenerTproxy => 'TProxy 代理';

  @override
  String get tsExitGroupName => 'Tailscale 出口';

  @override
  String get tsExitHowTo => '开启出口不会切换现有选择，只有在代理页选用“Tailscale 出口”的策略才经此出口。';

  @override
  String get tsExitGroupUnconfirmed => '出口分组待确认';

  @override
  String tsExitGroupJoined(num count, Object group) {
    return '已作为“$group”加入 $count 个手动策略组';
  }

  @override
  String get tsExitGroupNoParents => '当前配置没有可加入的手动策略组';

  @override
  String get tsExitNotAuthorized => '尚未获准使用此出口';

  @override
  String get tsExitDeviceOffline => '出口设备离线';

  @override
  String get tsExitNeedsLogin => '需要重新登录此账号';

  @override
  String get tsExitRefusing => '此出口不可用，选用它的连接会被拒绝';

  @override
  String get tsExitUnavailableShort => '不可用';

  @override
  String get tsExitOffAffectedTitle => '关闭出口节点？';

  @override
  String tsExitOffAffectedBody(Object group) {
    return '关闭后，正在使用“$group”的策略将改用各组的第一个选项。';
  }

  @override
  String get tsExitTurnOff => '关闭出口';

  @override
  String get tsExitOffNoOption => '关闭后无剩余选项';

  @override
  String tsViewerExit(Object group, Object member, Object groups) {
    return '$group · 由 Flash 添加 · $member · 手动策略组：$groups';
  }

  @override
  String get tsViewerExitUnconfirmed => 'Tailscale 出口 · 当前运行的出口和分组待确认';

  @override
  String get macHelperTitle => '辅助程序';

  @override
  String get macHelperOn => '辅助程序已就绪';

  @override
  String get macHelperOpenSettings => '打开系统设置';

  @override
  String get macHelperTryAgain => '重试';

  @override
  String get macHelperCheckAgain => '重新检查';

  @override
  String get macHelperRepair => '尝试修复';

  @override
  String get macHelperUnavailableDetail => '辅助程序尚未就绪，TUN 暂时无法启动。你的 TUN 设置已保留。';

  @override
  String get trayMultipleNodes => '多节点';

  @override
  String get trayNoAvailableMembers => '没有可用成员';

  @override
  String get trayCouldNotLoad => '读取失败';

  @override
  String get trayCouldNotSwitch => '切换失败';

  @override
  String get traySwitchUnconfirmed => '未能确认切换结果';

  @override
  String get traySelectionUnknown => '当前选择未知';

  @override
  String trayCurrentSelection(Object name) {
    return '当前选择：$name';
  }

  @override
  String get trayLatencyUnknown => '延迟未知';

  @override
  String get trayTesting => '测试中';

  @override
  String trayLatencyMilliseconds(Object value) {
    return '延迟 $value 毫秒';
  }

  @override
  String get trayLatencyLessThanOne => '延迟小于1毫秒';

  @override
  String traySwitchingTo(Object name) {
    return '正在切换至 $name';
  }

  @override
  String get traySelected => '已选择';

  @override
  String get trayTestLatency => '测试延迟';

  @override
  String get trayReject => '拒绝';

  @override
  String trayLatencyBadge(Object value) {
    return '$value ms';
  }

  @override
  String get compositionReviewTitle => '首次应用前确认设置';

  @override
  String get compositionBaselineUnknown =>
      '无法确认之前运行的值和来源。以下是拟应用的配置，不代表与当前运行配置的差异。';

  @override
  String get compositionCandidateNote =>
      '页面有的设置使用页面保存的值；页面没有的先使用配置文件中的值，文件未设置时使用默认值。以下内容基于已保存的配置准备，不会刷新订阅。密钥和较大的内容已隐藏或遮盖。TUN 显示的是拟开启或关闭，并非实际运行状态；授权、挂载内容和 Tailscale 相关内容将在应用时检查。';

  @override
  String get compositionReadFailed => '无法准备或重新核验拟应用的配置，本次尚未应用。请检查配置和设置后重试。';

  @override
  String get compositionSourceUnconfirmed => '来源待确认';

  @override
  String get compositionRecordFailed => '配置已应用，但无法保存首次确认记录。重启应用后可能需要再次确认。';

  @override
  String get macHelperChecking => '正在检查…';

  @override
  String get macHelperUpdating => '正在更新辅助程序…';

  @override
  String get macHelperMoveDetail => '请将 Flash 移到“应用程序”文件夹，然后重新打开 Flash。';

  @override
  String get macHelperMoveTitle => '请将 Flash 移到“应用程序”';

  @override
  String get macHelperStatusUnknown => '无法确认辅助程序状态';

  @override
  String get macHelperCoreUnconfirmed => '内核运行状态待确认';

  @override
  String get macHelperMigrationTitle => '需要更新辅助程序';

  @override
  String get macHelperMigrationDetail => 'Flash 需要移除旧版辅助程序并启用新版。更新时需要输入管理员密码。';

  @override
  String get macHelperMigrationAction => '开始更新';

  @override
  String get macHelperApprovalTitle => '请允许 Flash 在后台运行';

  @override
  String get macHelperApprovalStep1 => '打开“登录项与扩展”。';

  @override
  String get macHelperApprovalStep2 => '在“允许在后台”中找到 Flash。';

  @override
  String get macHelperApprovalStep3 => '把 Flash 旁边的开关关掉再打开，然后返回 Flash。';

  @override
  String macHelperStepLabel(Object number, Object text) {
    return '第 $number 步：$text';
  }

  @override
  String get macHelperStartingTitle => '正在启动辅助程序…';

  @override
  String get macHelperStartingDetail => '请稍候。';

  @override
  String get macHelperSwitchingTitle => '正在切换到新版辅助程序…';

  @override
  String get macHelperStartSlowTitle => '辅助程序启动时间较长';

  @override
  String get macHelperStartSlowDetail => '暂时无法确认辅助程序是否已启动。请重新检查；如果仍未就绪，请查看详情。';

  @override
  String get macHelperViewDetails => '查看详情';

  @override
  String get macHelperSignatureTitle => '辅助程序未通过安全检查';

  @override
  String get macHelperSignatureDetail => 'Flash 未运行辅助程序。请重新下载安装 Flash。';

  @override
  String get macHelperFailedTitle => '辅助程序更新未完成';

  @override
  String get macHelperFailedStopOld => '无法停止旧版辅助程序，请重试。';

  @override
  String get macHelperFailedRemoveOld => '无法移除旧版辅助程序，请重试。';

  @override
  String get macHelperFailedRegisterNew => '无法注册新版辅助程序，请重试。';

  @override
  String get macHelperFailedUnknown => '更新时遇到问题，请查看详情后重试。';

  @override
  String get macHelperRequiredTitle => '请先启用辅助程序';

  @override
  String get macHelperRequiredDetail => '此功能需要辅助程序。请按提示完成设置后再试。';

  @override
  String get macHelperViewSetup => '查看设置';

  @override
  String get macHelperReinstallTitle => '无法使用辅助程序';

  @override
  String get macHelperReinstallDetail =>
      'Flash 中的辅助程序缺失或与此版本不匹配。请重新下载安装 Flash。';

  @override
  String get macHelperUnsupportedDetail => '辅助程序需要 macOS 14 或更高版本。';

  @override
  String macHelperVersionLine(Object version) {
    return '版本 $version';
  }

  @override
  String get macHelperBarUpdate => '更新辅助程序';

  @override
  String get macHelperBarAllow => '允许辅助程序';

  @override
  String get macHelperWaitingCore => '等待辅助程序';

  @override
  String get macHelperBarStarting => '正在启动…';

  @override
  String get macHelperBarNotReady => '辅助程序未就绪';

  @override
  String get macHelperBarFailedCheck => '辅助程序未通过检查';

  @override
  String macHelperBarHint(Object title) {
    return '$title，按下查看步骤';
  }

  @override
  String get liveStatus => '实时状态';

  @override
  String get coreStopped => '核心已停止';

  @override
  String get coreStoppedDesc => '应用与核心的连接已断开';

  @override
  String get restartCore => '重启核心';

  @override
  String get installUpdate => '安装更新';

  @override
  String liveStatusPosition(Object index, Object count) {
    return '第 $index 项，共 $count 项';
  }

  @override
  String get coreStarting => '正在启动核心';

  @override
  String get coreStartingDesc => '正在连接核心';

  @override
  String get coreRunning => '核心运行中';

  @override
  String get coreRunningDesc => '应用已连接到核心';

  @override
  String get forceRestartCore => '强制重启';

  @override
  String rulesSubtitle(Object profile, Object count) {
    return '当前配置「$profile」· $count 条，按生效顺序';
  }

  @override
  String rulesSubtitleQuery(Object profile) {
    return '当前配置「$profile」';
  }

  @override
  String get rulesSearchHint => '搜索规则，或输入网址查询';

  @override
  String get rulesQuerying => '正在查询';

  @override
  String rulesQueryingHost(Object host) {
    return '正在查询 $host…';
  }

  @override
  String get ruleSourceAll => '全部';

  @override
  String get ruleSourceSubscription => '订阅配置';

  @override
  String get ruleSourceAdded => '附加规则';

  @override
  String get ruleSourceScript => '扩展脚本';

  @override
  String get ruleSourceMitm => '模块';

  @override
  String get ruleSourceCustom => '配置规则';

  @override
  String get ruleSourceManaged => 'Tailscale';

  @override
  String rulesGroupFilter(Object name) {
    return '策略组：$name';
  }

  @override
  String get ruleReject => '拒绝';

  @override
  String ruleSetSummary(Object count, Object time) {
    return '$count 条 · $time更新';
  }

  @override
  String ruleSetCountOnly(Object count) {
    return '$count 条';
  }

  @override
  String ruleSetExpired(Object days) {
    return '已过期 $days 天';
  }

  @override
  String get ruleSetFailed => '下载失败';

  @override
  String get ruleSetMissing => '还没下载';

  @override
  String get ruleSetAbsent => '配置里没有这个规则集';

  @override
  String get rulesLoadingMore => '正在加载…';

  @override
  String rulesShown(Object shown, Object total) {
    return '已显示 $shown / $total 条';
  }

  @override
  String ruleSetFilterMatches(Object count, Object name) {
    return '规则集 · $name 里有 $count 条匹配';
  }

  @override
  String rulesContaining(Object count) {
    return '匹配的规则 $count';
  }

  @override
  String get rulesShowAll => '显示全部规则';

  @override
  String get ruleHitTag => '命中';

  @override
  String ruleShadowedBy(Object index) {
    return '被第 $index 条规则优先匹配';
  }

  @override
  String get rulePassTag => 'PASS，跳过';

  @override
  String get ruleNoAdapterTag => '目标不存在，已跳过';

  @override
  String get ruleNoUdpTag => '不支持 UDP，已跳过';

  @override
  String get ruleDependsOnRematch => 'REMATCH 后重新匹配';

  @override
  String get hitCardTitle => '查询结果';

  @override
  String hitCardPosition(Object index) {
    return '命中第 $index 条';
  }

  @override
  String get hitGoes => '走';

  @override
  String get hitNoRule => '没有规则命中，走';

  @override
  String get hitRematch => '这条规则交给 REMATCH 在连接时重新判断，查询到这里为止。';

  @override
  String get hitRuleLabel => '规则';

  @override
  String get hitFromLabel => '来源';

  @override
  String get hitEntryLabel => '条目';

  @override
  String ruleUpdatedAt(Object time) {
    return '更新于 $time';
  }

  @override
  String get ruleJustAdded => '刚刚添加';

  @override
  String get changeNode => '换节点';

  @override
  String get addAddedRule => '添加附加规则';

  @override
  String get copyRule => '复制规则';

  @override
  String get viewGroup => '查看策略组';

  @override
  String uncertainKinds(Object kinds) {
    return '前面的规则可能因 $kinds 而优先匹配，实际结果可能不同。';
  }

  @override
  String get uncertainKindApp => 'App';

  @override
  String get uncertainKindPort => '端口';

  @override
  String get uncertainKindIp => 'IP';

  @override
  String get uncertainKindSeparator => '、';

  @override
  String get uncertainKindLastSeparator => '或';

  @override
  String get uncertainOther => '前面的规则需要更多连接信息，实际结果可能不同。';

  @override
  String get goUpdate => '去更新';

  @override
  String get ipSourceHosts => 'hosts';

  @override
  String get ipSourceMapping => 'Fake-IP 映射';

  @override
  String get rulesCoreStopped => '内核未运行，暂时无法查询规则。启动内核后再试。';

  @override
  String lookupFailed(Object reason) {
    return '查询失败：$reason';
  }

  @override
  String rulesLoadFailed(Object reason) {
    return '读取规则失败：$reason';
  }

  @override
  String get compareSame => '这次连接当时命中的规则与当前查询一致。';

  @override
  String compareDiffer(Object rule) {
    return '这次连接当时命中「$rule」，与当前查询结果不同。配置或连接条件可能已变化。';
  }

  @override
  String get rulesModeGlobal => '当前为全局模式，规则不参与分流。';

  @override
  String get rulesModeDirect => '当前为直连模式，规则不参与分流。';

  @override
  String get addRuleTitle => '添加附加规则';

  @override
  String addRuleSubtitle(Object profile) {
    return '添加到当前配置「$profile」。';
  }

  @override
  String get addRuleScope => '匹配范围';

  @override
  String addRuleSuffix(Object domain) {
    return '$domain及其所有子域名';
  }

  @override
  String addRuleExact(Object host) {
    return '仅 $host';
  }

  @override
  String get addRuleTarget => '走哪个策略组';

  @override
  String get addRulePreview => '将添加';

  @override
  String addedEffective(Object host, Object group) {
    return '规则已添加并生效。$host现在走「$group」。';
  }

  @override
  String get viewThatRule => '查看该规则';

  @override
  String get lookupRule => '查规则';

  @override
  String ruleRowSemantics(
    Object index,
    Object rule,
    Object source,
    Object group,
  ) {
    return '第 $index 条，$rule，来自$source，去$group';
  }

  @override
  String hitSemantics(
    Object index,
    Object rule,
    Object source,
    Object group,
    Object node,
  ) {
    return '命中第 $index 条，$rule，来源$source，走$group，节点$node';
  }

  @override
  String get uncertainPrefix => '结果可能不同';

  @override
  String addRuleWriteFailed(Object reason) {
    return '添加失败：$reason';
  }

  @override
  String get rulesEmptyFiltered => '没有找到匹配的规则。试试其他关键词或筛选条件。';

  @override
  String get hitIpLabel => '解析出的 IP';

  @override
  String get lookupNoConnectNote => '查询可能进行 DNS 解析，不会连接目标网站。';

  @override
  String get ruleUncertainTag => '无法确定是否匹配';

  @override
  String ruleSetIssuesNotice(Object issues) {
    return '规则集$issues，结果可能不完整。';
  }

  @override
  String get ruleSetIssueSeparator => '，';

  @override
  String ruleSetIssueMissing(Object name) {
    return '「$name」还没下载';
  }

  @override
  String ruleSetIssueFailed(Object name) {
    return '「$name」下载失败';
  }

  @override
  String ruleSetIssueExpired(Object name) {
    return '「$name」已过期';
  }

  @override
  String get addRuleAdding => '正在添加…';

  @override
  String get addedNotHit => '规则已添加，但当前查询未命中它。';

  @override
  String addedNotHitBy(Object index) {
    return '第 $index 条规则优先匹配。';
  }

  @override
  String get addedUnconfirmed => '规则已添加，但暂时无法确认是否生效。';

  @override
  String get relookup => '重新查询';

  @override
  String get addedRulesReloadTimeout => '内核 15 秒内没有完成重新加载，这次修改已撤销。';

  @override
  String get addedRulesReloadFailed => '内核没有接受新的配置，这次修改已撤销。';

  @override
  String get addedRuleSetLoadFailed => '规则集下载失败，这次修改已撤销。';

  @override
  String get addedRuleSetLoadTimeout => '规则集 15 秒内没有下载完成，这次修改已撤销。';

  @override
  String get ruleDeleteTitle => '删除这条规则？';

  @override
  String ruleSetDeleteTitle(String name) {
    return '删除规则集「$name」？';
  }

  @override
  String ruleDeleteBody(String text) {
    return '$text\n删除后立刻生效。';
  }

  @override
  String ruleDuplicate(int number, String group) {
    return '已有这条规则（第 $number 条），走 $group。';
  }

  @override
  String get ruleUpdateGroup => '更新策略组';

  @override
  String get ruleEditAddTitle => '添加规则';

  @override
  String get ruleEditTitle => '编辑附加规则';

  @override
  String get ruleSetAddTitle => '添加规则集';

  @override
  String get ruleSetEditTitle => '编辑附加规则集';

  @override
  String get ruleEditCoreStopped => '内核启动后生效';

  @override
  String ruleEditPosition(int number) {
    return '第 $number 条 · 附加规则';
  }

  @override
  String ruleSetEditPosition(int number) {
    return '第 $number 条 · 附加规则集';
  }

  @override
  String get ruleEditSaving => '正在保存…';

  @override
  String get ruleTypeLabel => '类型';

  @override
  String get ruleTypeMore => '更多';

  @override
  String get ruleTypeDomainSuffix => '域名后缀';

  @override
  String get ruleTypeDomain => '完整域名';

  @override
  String get ruleTypeKeyword => '域名关键词';

  @override
  String get ruleTypeIpCidr => 'IP 段';

  @override
  String get ruleTypeIpCidr6 => 'IPv6 段';

  @override
  String get ruleTypeDstPort => '目标端口';

  @override
  String get ruleTypeProcessName => '进程名';

  @override
  String get ruleTypeSrcIpCidr => '来源 IP 段';

  @override
  String get ruleValueKeyword => '关键词';

  @override
  String get ruleHelpDomainSuffix => '会同时匹配 example.com 和它的所有子域名。可以直接粘贴网址。';

  @override
  String get ruleHelpDomain => '只匹配这个域名本身，不含子域名。可以直接粘贴网址。';

  @override
  String get ruleHelpKeyword => '域名里含有这段文字就匹配。';

  @override
  String get ruleHelpIpCidr => '如 10.0.0.0/8；填单个 IP 会自动补 /32。';

  @override
  String get ruleHelpIpCidr6 => '如 2001:db8::/32；填单个地址会自动补 /128。';

  @override
  String get ruleHelpSrcIpCidr => '发起连接的设备所在的地址段。';

  @override
  String get ruleHelpPort => '如 443，或范围 8000-9000。';

  @override
  String get ruleHelpProcess => 'App 或程序的进程名，如 Safari、curl。';

  @override
  String get ruleValueEmpty => '请填写内容';

  @override
  String get ruleValueComma => '不能包含逗号';

  @override
  String get ruleValueDomain => '不是有效的域名';

  @override
  String get ruleValueCidr => '不是有效的 IP 段';

  @override
  String get ruleValueNetwork => '只能是 tcp 或 udp';

  @override
  String get ruleValueNumberRange => '不是有效的数字或范围';

  @override
  String get ruleValueDscp => 'DSCP 取值 0–63';

  @override
  String get ruleValuePickCode => '选择代码';

  @override
  String get ruleValuePickProcess => '从正在运行的 App 选择';

  @override
  String get ruleValueNoProcesses => '最近没有记录到 App';

  @override
  String get rulePositionLabel => '位置';

  @override
  String get rulePositionFirst => '附加规则最前面';

  @override
  String get rulePositionLast => '附加规则最后面';

  @override
  String get ruleSetUrlLabel => '网址';

  @override
  String get ruleSetUrlHelp => '粘贴规则集的网址，Flash 会下载并检查内容。';

  @override
  String get ruleSetUrlInvalid => '只能填 http 或 https 网址';

  @override
  String get ruleSetChecking => '正在下载，检查内容…';

  @override
  String ruleSetCheckOk(String kind, String format, String count) {
    return '已下载并识别：$kind规则，$format 格式，$count 条';
  }

  @override
  String ruleSetCheckOkUncounted(String format) {
    return '已下载：$format 格式，内核运行后可识别条数';
  }

  @override
  String get ruleSetCheckNotFound => '网址不存在（404）';

  @override
  String get ruleSetCheckTimeout => '下载超时';

  @override
  String ruleSetCheckNetwork(String reason) {
    return '下载失败：$reason';
  }

  @override
  String get ruleSetCheckNotRuleSet => '内容不是规则集';

  @override
  String get ruleSetCheckUnknown => '格式无法识别';

  @override
  String get ruleSetNameLabel => '名称';

  @override
  String get ruleSetNameTaken => '已有同名规则集';

  @override
  String get ruleSetNameInvalid => '名称不能含逗号，首尾不能有空格';

  @override
  String get ruleSetBehaviorLabel => '内容类型';

  @override
  String get ruleSetBehaviorDomain => '域名';

  @override
  String get ruleSetBehaviorIpcidr => 'IP 段';

  @override
  String get ruleSetBehaviorClassical => '混合规则';

  @override
  String get ruleSetBehaviorDetected => '已按下载的内容自动选好。';

  @override
  String get ruleSetBehaviorMismatch => '和下载的内容不一致，规则集可能不生效。';

  @override
  String get ruleSetMrsNeedsKind => 'MRS 格式只支持域名或 IP 段';

  @override
  String get ruleSetFormatText => '文本';

  @override
  String get ruleSetIntervalLabel => '自动更新';

  @override
  String get ruleSetEvery6Hours => '每 6 小时';

  @override
  String get ruleSetDaily => '每天';

  @override
  String get ruleSetWeekly => '每周';

  @override
  String get ruleSetNeverUpdate => '不自动更新';

  @override
  String ruleSetEverySeconds(int seconds) {
    return '每 $seconds 秒';
  }

  @override
  String get ruleSetUpdateNow => '立即更新';

  @override
  String get ruleSetRefreshed => '已开始更新。';

  @override
  String get rulesAddTooltip => '添加';

  @override
  String get rulesAddSemantics => '添加规则或规则集';

  @override
  String get rulesAddRuleMenu => '添加规则';

  @override
  String get rulesAddSetMenu => '添加规则集';

  @override
  String rulesAddedDivider(String sources) {
    return '以下是$sources的规则。';
  }

  @override
  String get ruleSourceAddedSet => '附加规则集';

  @override
  String get ruleEditMenu => '编辑…';

  @override
  String get ruleMoveUp => '上移';

  @override
  String get ruleMoveDown => '下移';

  @override
  String ruleEditSemantics(int number) {
    return '编辑第 $number 条规则';
  }

  @override
  String ruleDeleteSemantics(int number) {
    return '删除第 $number 条规则';
  }

  @override
  String ruleAddedBanner(String text) {
    return '规则「$text」已添加并生效。';
  }

  @override
  String ruleSavedBanner(String text) {
    return '规则「$text」已保存并生效。';
  }

  @override
  String ruleSetAddedBanner(String name) {
    return '规则集「$name」已添加并生效。';
  }

  @override
  String ruleSetSavedBanner(String name) {
    return '规则集「$name」已保存并生效。';
  }

  @override
  String get ruleDeletedBanner => '已删除。';

  @override
  String get ruleSavedPendingBanner => '已保存，内核启动后生效。';

  @override
  String get ruleBannerLookup => '查询一个网址';

  @override
  String ruleMoveFailed(String reason) {
    return '调整顺序失败：$reason';
  }

  @override
  String processHelperLabel(Object name) {
    return '$name · 辅助进程';
  }

  @override
  String processCoreLabel(Object name) {
    return '$name · 内核';
  }

  @override
  String get processHelperTag => '辅助进程';

  @override
  String get processCoreTag => '内核';

  @override
  String get addedRulesRollbackReloadFailed => '更改已回滚，但恢复运行中的配置失败。请重新应用配置后再使用。';

  @override
  String get addedRulesRollbackConflict =>
      '重载期间其他编辑器更改了规则集，因此保留了部分更改。使用配置前请检查规则和提供者。';

  @override
  String get addedRulesRollbackReloadTimeout =>
      '恢复运行中的配置耗时过长，当前状态不确定；在完成前暂停更改新增规则。';

  @override
  String get addedRulesStaleEdit => '此规则或规则集已在其他位置更改，请重新打开后再试。';

  @override
  String get addedRulesApplyPending => '规则应用时间较长，仍在处理中，请稍候。';

  @override
  String get addedRulesApplyRestored => '处理已结束，已恢复原规则。';

  @override
  String get addedRulesApplyRestoreFailed => '处理已结束，但未能恢复原规则。请检查当前规则。';

  @override
  String get deleteCertificate => '删除证书';

  @override
  String get deleteCertificateTip => '从本机删除证书私钥、证书本身和对它的信任。之后需重新生成并信任新证书才能解密。';

  @override
  String get mitmPausedCoreIdentity => '解密已暂停：内核身份核对失败';

  @override
  String mitmIgnoredProfileHostnames(Object count) {
    return '已忽略来自订阅/脚本的 $count 条';
  }

  @override
  String get mitmOutcomeRefused => '客户端在握手时发出了警报，原因无法确定。';

  @override
  String get mitmOutcomeUpstreamCertificate => '网站证书校验失败';

  @override
  String get mitmOutcomeHTTP1Unsupported => '当前连接使用的协议不支持解密。';

  @override
  String get mitmOutcomeHelloPassthrough => '无法检查 TLS 握手，已原样放行';

  @override
  String get mitmOutcomeFailed => '解密连接失败';

  @override
  String get mitmPausedLiveness =>
      '解密已暂停：无法验证信任或签名器状态。正常情况下约 26 秒内检测到变化；睡眠或系统卡顿可能更久。';

  @override
  String get mitmNotApplied => '解密未生效：设置还没应用到内核';

  @override
  String get mitmTurnOffFailed => '没能在内核中关闭解密，请重启内核';

  @override
  String get mitmPausedIndicatorPending => '解密已暂停：尚未提供必需的常驻解密指示。';

  @override
  String get mitmIndicatorDecrypting => '正在解密';

  @override
  String get mitmIndicatorOn => '解密已开启';

  @override
  String get mitmIndicatorPaused => '解密已暂停';

  @override
  String get mitmIndicatorUnconfirmed => '正在确认解密状态';

  @override
  String mitmIndicatorPausedBecause(String reason) {
    return '解密已暂停：$reason';
  }

  @override
  String get mitmIndicatorOpenSettings => '打开 MITM 设置';

  @override
  String get mitmPauseCoreStopped => '内核未运行';

  @override
  String get mitmPauseCoreIdentity => '内核身份核对失败';

  @override
  String get mitmPauseNotTrusted => '根证书未生成或未受信任';

  @override
  String get mitmPartialConnections => '部分连接可能未解密';

  @override
  String get mitmPauseLiveness => '无法确认信任和签名状态';

  @override
  String get mitmPauseIndicatorPending => '常驻状态提示尚未启用';

  @override
  String get mitmPauseUnavailable => '无法确认原因';

  @override
  String get mitmOutcomePaused => '解密暂停中，已原样放行';

  @override
  String get mitmBadgeDecrypted => '已解密';

  @override
  String get mitmBadgePassedThrough => '未解密 · 原样放行';

  @override
  String get mitmBadgePassedThroughSpoken => '未解密，原样放行';

  @override
  String get mitmBadgeHandshakeFailed => '客户端握手失败';

  @override
  String get mitmBadgeFailed => '解密失败';

  @override
  String get mitmExchangeNoResponse => '未收到响应';

  @override
  String get mitmExchangeResponseFailed => '响应中途中断';

  @override
  String get mitmExchangeStopped => '解密设置已更改，请求已中止';

  @override
  String get mitmExchangeFailed => '请求未完成';

  @override
  String get macHelperAllowInSettings =>
      '请在系统设置的“登录项与扩展”里，把 Flash 的开关关掉再打开，然后返回 Flash。';

  @override
  String get macHelperNotReadyTitle => '辅助程序暂未就绪';

  @override
  String get macHelperRegistrationFailedDetail => '暂时无法完成登记，请查看详情。';

  @override
  String get macHelperStaleCoreDetail => '旧内核尚未确认停止，请查看详情。';

  @override
  String get macHelperStatusUnreadable => '暂时无法读取辅助程序状态，请查看详情。';

  @override
  String get macHelperLauncherCheckTitle => 'Flash 未通过安全检查';

  @override
  String get macHelperLauncherCheckDetail => '辅助程序未启动，请重新安装最新的可信版本。';

  @override
  String get macHelperLauncherDowngradeTitle => 'Flash 版本过旧';

  @override
  String get macHelperLauncherDowngradeDetail => '辅助程序未启动，请安装最新版本的 Flash。';

  @override
  String get macHelperLauncherFailedTitle => '辅助程序未能启动';

  @override
  String get macHelperLauncherFailedDetail => '系统未能完成辅助程序的准备或启动，请查看详情。';

  @override
  String get macHelperRecordDamagedTitle => '无法读取或更新版本记录';

  @override
  String get macHelperRecordDamagedDetail =>
      'Flash 需要修复辅助程序的版本记录。修复时需要输入管理员密码，并会重新检查辅助程序。';

  @override
  String get macHelperRecordRepairAction => '修复版本记录';

  @override
  String get macHelperRecordRepairing => '正在修复版本记录…';

  @override
  String get macHelperRecordRepairFailed => '版本记录未能修复，请查看详情。';

  @override
  String get macHelperServiceNotFoundTitle => '辅助程序需要修复';

  @override
  String get macHelperServiceNotFoundDetail =>
      'macOS 暂时无法识别 Flash 的辅助程序。点按“修复”重新登记；系统可能会要求你在设置中允许后台运行。';

  @override
  String get macHelperServiceNotFoundAction => '修复';

  @override
  String get macHelperServiceRepairFailedDetail =>
      '修复未完成，macOS 仍无法识别辅助程序。请查看详情。';

  @override
  String get ipxScore => '健康分';

  @override
  String get ipxScoreOutOf => '/ 100';

  @override
  String ipxScoreCeiling(String value) {
    return '类型上限 $value';
  }

  @override
  String get ipxGradeExcellent => '极佳';

  @override
  String get ipxGradeGood => '良好';

  @override
  String get ipxGradeFair => '一般';

  @override
  String get ipxGradePoor => '较差';

  @override
  String get ipxGradeRisky => '高风险';

  @override
  String get ipxLocation => '位置';

  @override
  String get ipxNativity => '原生 / 广播';

  @override
  String get ipxNative => '原生 IP';

  @override
  String get ipxBroadcast => '广播 IP';

  @override
  String ipxNativeDetail(String registered, String used) {
    return '注册 $registered · 使用 $used';
  }

  @override
  String get ipxIsp => '运营商';

  @override
  String get ipxTypeEducation => '教育网';

  @override
  String get ipxTypePseudo => '疑似伪家宽';

  @override
  String get ipxDeductions => '扣分明细';

  @override
  String get ipxFullReport => 'ipx.al 查看完整报告';

  @override
  String ipxDataFrom(String source) {
    return '数据来自 $source，仅供参考';
  }

  @override
  String get ipxSourceSeparator => '、';

  @override
  String get ipxReportFailed => '报告获取失败';

  @override
  String get ipxRetry => '重试';

  @override
  String get ipxViaExit => '经当前出口查询';

  @override
  String get ipxUnknown => '未知';

  @override
  String get mitmHttp2 => 'HTTP/2 解密';

  @override
  String get mitmHttp2Desc => '关闭后，仅解密 HTTP/1.1 连接；仅支持 HTTP/2 的连接不会解密。';

  @override
  String get mitmRewriteAndScripts => '改写与脚本';

  @override
  String get mitmRewrite => '改写';

  @override
  String mitmRewriteRuleCount(int count) {
    return '$count 条规则';
  }

  @override
  String mitmRewriteInvalidCount(int count) {
    return '$count 条有误';
  }

  @override
  String get mitmRewriteNoneAdded => '未添加';

  @override
  String mitmRewriteSubtitle(Object profile, int count, int enabled) {
    return '当前配置「$profile」· $count 条改写规则，$enabled 条开启';
  }

  @override
  String get mitmRewriteGroupReject => 'URL 拦截';

  @override
  String get mitmRewriteGroupRedirect => 'URL 重定向';

  @override
  String get mitmRewriteGroupHeader => '请求头与响应头';

  @override
  String get mitmRewriteGroupBody => '请求体与响应体';

  @override
  String get mitmRewriteActReject => '拦截';

  @override
  String mitmRewriteActRedirect(Object code) {
    return '$code 重定向';
  }

  @override
  String get mitmRewriteActUrl => '直接改写 URL';

  @override
  String get mitmRewriteActRequestHeader => '请求头';

  @override
  String get mitmRewriteActResponseHeader => '响应头';

  @override
  String get mitmRewriteActRequestBody => '请求体';

  @override
  String get mitmRewriteActResponseBody => '响应体';

  @override
  String get mitmRewriteActMapLocal => '本地返回';

  @override
  String get mitmRewriteRejectError => '返回错误';

  @override
  String get mitmRewriteReject200 => '返回空白页';

  @override
  String get mitmRewriteRejectImage => '返回空白图片';

  @override
  String get mitmRewriteRejectDict => '返回空 JSON 对象';

  @override
  String get mitmRewriteRejectArray => '返回空 JSON 数组';

  @override
  String get mitmRewriteRejectDrop => '直接断开';

  @override
  String mitmRewriteHeaderAdd(Object name) {
    return '添加 $name';
  }

  @override
  String mitmRewriteHeaderDel(Object name) {
    return '删除 $name';
  }

  @override
  String mitmRewriteHeaderReplace(Object name) {
    return '替换 $name';
  }

  @override
  String mitmRewriteHeaderReplaceRegex(Object name) {
    return '正则替换 $name';
  }

  @override
  String mitmRewriteBodyReplace(int count) {
    return '替换 $count 处';
  }

  @override
  String mitmRewriteBodyLimit(Object size) {
    return '上限 $size';
  }

  @override
  String mitmRewriteInvalid(Object reason) {
    return '规则有误：$reason';
  }

  @override
  String mitmRewriteInvalidSpoken(Object reason) {
    return '规则有误，$reason';
  }

  @override
  String mitmRewriteToggleLabel(Object action, Object url) {
    return '$action，$url';
  }

  @override
  String mitmRewriteNotApplied(Object reason) {
    return '未能生效：$reason';
  }

  @override
  String get mitmRewriteEnableAll => '全部开启';

  @override
  String get mitmRewriteDisableAll => '全部关闭';

  @override
  String get mitmRewriteCopyAll => '复制全部规则';

  @override
  String get mitmRewriteDeleteInvalid => '删除有误的规则';

  @override
  String mitmRewriteDeleteInvalidConfirm(int count) {
    return '删除 $count 条有误的规则？';
  }

  @override
  String get mitmRewriteOff => '解密已关闭，改写规则不会生效。';

  @override
  String get mitmRewriteGoTurnOn => '去开启';

  @override
  String get mitmRewriteEmptyTitle => '还没有改写规则';

  @override
  String get mitmRewriteEmptyDesc => '粘贴规则后即可导入。';

  @override
  String get mitmRewritePaste => '粘贴导入';

  @override
  String get mitmRewriteSearchHint => '搜索改写规则';

  @override
  String get mitmRewriteImportTitle => '导入改写规则';

  @override
  String get mitmRewriteImportDesc =>
      '粘贴改写规则，每行一条。支持 Surge 的 [URL Rewrite]、[Header Rewrite]、[Body Rewrite]、[Map Local] 四个段落，段落标题自动识别。';

  @override
  String mitmRewriteImportReady(int count, Object detail) {
    return '可以导入 $count 条：$detail';
  }

  @override
  String mitmRewriteImportLineError(int line, Object reason) {
    return '第 $line 行无法导入：$reason';
  }

  @override
  String mitmRewriteImportMoreErrors(int count) {
    return '另有 $count 行有误';
  }

  @override
  String mitmRewriteImportDuplicate(int line) {
    return '第 $line 行已存在，会跳过';
  }

  @override
  String get mitmRewritePlace => '放在';

  @override
  String get mitmRewritePlaceEnd => '各分组最后';

  @override
  String get mitmRewritePlaceStart => '各分组最前';

  @override
  String mitmRewriteImportButton(int count) {
    return '导入 $count 条';
  }

  @override
  String get mitmRewriteImporting => '正在导入…';

  @override
  String mitmRewriteImported(int count) {
    return '已导入 $count 条规则';
  }

  @override
  String get mitmRewriteEditTitle => '编辑改写规则';

  @override
  String mitmRewriteEditSubtitle(Object group, int number) {
    return '$group · 第 $number 条';
  }

  @override
  String get mitmRewritePreviewType => '类型';

  @override
  String get mitmRewritePreviewMatch => '匹配网址';

  @override
  String get mitmRewritePreviewAction => '操作';

  @override
  String get mitmRewriteUnparsable => '无法解析';

  @override
  String mitmRewriteSectionChanged(Object group) {
    return '这一行属于「$group」，保存后会移到那里。';
  }

  @override
  String mitmRewriteBadgeApplied(Object type) {
    return '已改写 · $type';
  }

  @override
  String mitmRewriteBadgeFailed(Object reason) {
    return '改写失败 · $reason';
  }

  @override
  String get mitmRewriteRewritten => '已改写';

  @override
  String get mitmRewriteFailedShort => '改写失败';

  @override
  String get mitmRewriteAppliedTitle => '改写已应用';

  @override
  String mitmRewriteHitCount(int count) {
    return '$count 条';
  }

  @override
  String mitmRewriteFailedTitle(Object reason) {
    return '改写失败：$reason';
  }

  @override
  String get mitmRewritePassedThrough => '未改写，已原样放行';

  @override
  String mitmRewriteRuleRef(Object rule) {
    return '规则 $rule';
  }

  @override
  String get mitmRewriteViewInList => '在改写中查看';

  @override
  String get mitmRewriteBefore => '改写前';

  @override
  String get mitmRewriteAfter => '改写后';

  @override
  String get mitmRewriteRuleRemoved => '规则已不在当前配置中';

  @override
  String get mitmRewriteSkipOversize => '内容超过大小上限';

  @override
  String get mitmRewriteSkipDecode => '无法解压内容';

  @override
  String get mitmRewriteSkipNotText => '内容不是受支持的文本格式';

  @override
  String get mitmRewriteSkipEncoding => '不支持的内容编码';

  @override
  String get mitmRewriteSkipTimeout => '匹配超时';

  @override
  String get mitmRewriteSkipCrossHost => '不能改写到其他主机';

  @override
  String get mitmRewriteSkipInvalidUrl => '改写后的网址无效';

  @override
  String get mitmRewriteSkipStreaming => '内容是持续传输的流';

  @override
  String get mitmRewriteSkipUploading => '请求仍在上传';

  @override
  String get mitmRewriteSkipRead => '读取内容失败';

  @override
  String get mitmRewriteSkipOther => '未应用改写';

  @override
  String mitmRewriteRejectDetail(Object text, Object type) {
    return '$text（$type）';
  }

  @override
  String mitmRewriteErrorFramingHeader(String value) {
    return '$value 控制消息传输，不能改写。';
  }

  @override
  String mitmRewriteErrorNeedsValue(String value) {
    return '$value 缺少值。';
  }

  @override
  String get mitmRewriteErrorBodyHead =>
      '内容改写规则须以 http-request 或 http-response 开头。';

  @override
  String get mitmRewriteErrorHeaderLineBreak => '请求头或响应头的值不能包含换行。';

  @override
  String get mitmRewriteErrorNeedsReplacementUrl => '重定向或 URL 直接改写缺少目标 URL。';

  @override
  String get mitmRewriteErrorDataUrl => '远程内容需要先下载，才能用于本地映射。';

  @override
  String get mitmRewriteErrorDataBase64 => '内容不是有效的 Base64。';

  @override
  String mitmRewriteErrorDataFileName(String value) {
    return '内容须指定资源目录中的文件；当前值为 $value。';
  }

  @override
  String get mitmRewriteErrorFileNeedsData => '使用文件类型时，须指定文件。';

  @override
  String get mitmRewriteErrorBodyTooLarge => '解码后的内容超过改写大小上限。';

  @override
  String get mitmRewriteErrorEmptyRegex => '正则表达式不能为空。';

  @override
  String get mitmRewriteErrorEmptyRule => '规则不能为空。';

  @override
  String mitmRewriteErrorUrlFieldCount(String value) {
    return '应填写正则表达式、替换内容和类型；当前有 $value 项。';
  }

  @override
  String get mitmRewriteErrorBodyPairs => 'URL 正则表达式后应成对填写匹配表达式和替换内容。';

  @override
  String get mitmRewriteErrorHeaderFields =>
      '请依次填写请求或响应类型、正则表达式、操作和头字段；需要时还须填写值。';

  @override
  String mitmRewriteErrorKeyValue(String value) {
    return '应使用 key=value 格式；当前为 $value。';
  }

  @override
  String get mitmRewriteErrorHeaderFormat => '头字段格式无效，应使用 a:b|c:d 或 Base64。';

  @override
  String get mitmRewriteErrorHeaderReplaceRegex =>
      'header-replace-regex 需要正则表达式和替换内容。';

  @override
  String get mitmRewriteErrorUrlRegex => 'URL 正则表达式无效。';

  @override
  String mitmRewriteErrorBodyRegex(String value) {
    return '内容正则表达式 $value 无效。';
  }

  @override
  String mitmRewriteErrorInvalidHeader(String value) {
    return '头字段 $value 无效。';
  }

  @override
  String mitmRewriteErrorHeaderName(String value) {
    return '头字段名称 $value 无效。';
  }

  @override
  String get mitmRewriteErrorHeaderRegex => '头字段正则表达式无效。';

  @override
  String get mitmRewriteErrorJq => '暂不支持使用 jq 改写内容。';

  @override
  String mitmRewriteErrorLocalUnreadable(String value) {
    return '无法读取本地映射文件 $value。';
  }

  @override
  String mitmRewriteErrorLocalTooLarge(String value) {
    return '本地映射文件 $value 超过 16 MiB。';
  }

  @override
  String get mitmRewriteErrorRegexTimeout => '正则表达式匹配超时。';

  @override
  String mitmRewriteErrorStatusCode(String value) {
    return '状态码须在 200–999 之间；当前为 $value。';
  }

  @override
  String mitmRewriteErrorUrlType(String value) {
    return '不支持的 URL 改写类型：$value。';
  }

  @override
  String mitmRewriteErrorDataType(String value) {
    return '不支持的内容类型：$value。';
  }

  @override
  String mitmRewriteErrorHeaderAction(String value) {
    return '不支持的头字段操作：$value。';
  }

  @override
  String mitmRewriteErrorParameter(String value) {
    return '不支持的参数：$value。';
  }

  @override
  String mitmRewriteErrorSection(String value) {
    return '不支持的配置段：$value。';
  }

  @override
  String mitmRewriteErrorUnterminatedQuote(String value) {
    return '$value 中的引号未闭合。';
  }

  @override
  String get mitmRewriteErrorOutsideSection =>
      '这一行不在 [URL Rewrite]、[Header Rewrite]、[Body Rewrite] 或 [Map Local] 段落中。';

  @override
  String get mitmRewriteErrorGeneric => '规则格式无效。';

  @override
  String get mitmRewriteErrorDetails => '查看详情';

  @override
  String get mitmRewriteFailureGeneric => '出现错误，规则保持不变。';

  @override
  String get mitmRewriteMatchedTitle => '命中规则';

  @override
  String mitmRewriteNotAppliedTitle(String value) {
    return '未应用改写：$value';
  }

  @override
  String get mitmScripts => '脚本';

  @override
  String mitmScriptCount(int count) {
    return '$count 个脚本';
  }

  @override
  String mitmUpdateCount(int count) {
    return '$count 个有更新';
  }

  @override
  String mitmScriptInvalidCount(int count) {
    return '$count 个有误';
  }

  @override
  String mitmModuleCount(int count, int enabled) {
    return '$count 个模块，$enabled 个开启';
  }

  @override
  String mitmScriptSubtitle(Object profile, int count, int enabled) {
    return '当前配置「$profile」· $count 个脚本，$enabled 个开启';
  }

  @override
  String get mitmScriptGroupRequest => '请求脚本';

  @override
  String get mitmScriptGroupResponse => '响应脚本';

  @override
  String get mitmScriptKindRequest => '请求';

  @override
  String get mitmScriptKindResponse => '响应';

  @override
  String get mitmScriptNeedsBody => '需要内容';

  @override
  String mitmScriptRemoteSource(Object source, Object time) {
    return '$source · $time检查';
  }

  @override
  String mitmScriptLocalSource(Object file) {
    return '本地文件 · $file';
  }

  @override
  String get mitmScriptHasUpdate => '有更新';

  @override
  String get mitmHasUpdate => '有更新';

  @override
  String get mitmViewUpdate => '查看更新';

  @override
  String mitmScriptsFromModules(int count) {
    return '另有 $count 个脚本来自模块';
  }

  @override
  String get mitmScriptsOff => 'HTTPS 解密已关闭，脚本暂不运行。';

  @override
  String get mitmScriptHostNotDecrypted => '这个域名没有解密，脚本不会运行';

  @override
  String get mitmAddToDecryption => '加入解密';

  @override
  String get mitmScriptsEmptyTitle => '还没有脚本';

  @override
  String get mitmScriptsEmptyBody => '添加脚本后，可在符合条件的请求或响应上运行。';

  @override
  String get mitmAddScript => '添加脚本';

  @override
  String get mitmCheckAllUpdates => '检查全部更新';

  @override
  String get mitmScriptCopyAll => '复制全部配置行';

  @override
  String get mitmScriptDeleteInvalid => '删除有误的脚本';

  @override
  String mitmScriptDeleteInvalidConfirm(int count) {
    return '删除 $count 个有误的脚本？';
  }

  @override
  String get mitmCheckUpdate => '检查更新';

  @override
  String get mitmCopyLine => '复制配置行';

  @override
  String get mitmAddScriptHint =>
      '粘贴 Surge 配置里 [Script] 段的行，每行一个脚本；也可以只粘贴脚本地址。';

  @override
  String get mitmScriptType => '类型';

  @override
  String get mitmScriptPattern => '匹配网址';

  @override
  String get mitmScriptTimeout => '超时';

  @override
  String mitmScriptPasteOk(int count, int requests, int responses) {
    return '可以添加 $count 个：请求脚本 $requests、响应脚本 $responses';
  }

  @override
  String mitmScriptPasteLineError(int line, Object reason) {
    return '第 $line 行无法添加：$reason';
  }

  @override
  String get mitmScriptUnsupportedType => '暂不支持这类脚本';

  @override
  String get mitmScriptUnreadable => '不是脚本配置行';

  @override
  String get mitmScriptNoPattern => '缺少匹配网址';

  @override
  String get mitmScriptNoPath => 'script-path 需要是网址；本地脚本请用「从文件添加…」';

  @override
  String get mitmAddFromFile => '从文件添加…';

  @override
  String get mitmContinue => '继续';

  @override
  String get mitmScriptConfirmTitle => '确认启用脚本';

  @override
  String get mitmScriptConfirmBody =>
      '脚本可能读取和修改匹配域名的明文请求与响应，其中可能包含账号、密码等敏感信息。请只启用你信任的脚本。';

  @override
  String get mitmCapabilityRead => '查看和修改匹配域名的明文请求与响应';

  @override
  String get mitmCapabilitySend => '通过 Flash 发出网络请求';

  @override
  String get mitmCapabilityStore => '在本机保存数据；所有脚本共用这份数据，彼此可以读取';

  @override
  String get mitmCapabilityLimits => '不能读写本机文件或执行命令；每次运行最长 10 秒。';

  @override
  String mitmHostNotDecrypted(Object host) {
    return '$host 没有解密';
  }

  @override
  String get mitmAlsoDecryptHosts => '同时把这些域名加入解密';

  @override
  String get mitmAddAndEnable => '添加并启用';

  @override
  String get mitmScriptDownloading => '正在下载并检查…';

  @override
  String mitmScriptsAdded(int count) {
    return '已添加 $count 个脚本';
  }

  @override
  String get mitmScriptEmpty => '脚本是空的';

  @override
  String mitmScriptDownloadFailed(Object name, Object reason) {
    return '无法下载 $name：$reason';
  }

  @override
  String mitmScriptCannotLoad(Object name, Object reason) {
    return '$name 无法加载：$reason';
  }

  @override
  String mitmScriptCheckFailed(Object reason) {
    return '无法检查脚本更新：$reason';
  }

  @override
  String mitmUpdateTitle(Object name) {
    return '$name 有更新';
  }

  @override
  String mitmDiffFolded(int count) {
    return '… $count 行未改动';
  }

  @override
  String get mitmNotNow => '暂不更新';

  @override
  String get mitmAdoptUpdate => '采用新版';

  @override
  String get mitmChangeHosts => '解密域名';

  @override
  String get mitmChangeScripts => '脚本';

  @override
  String get mitmChangeRewrites => '改写';

  @override
  String get mitmNoChange => '无变化';

  @override
  String get mitmModuleConfirmTitle => '确认导入模块';

  @override
  String get mitmModuleHostsHint => '请确认此模块包含的解密域名，再决定是否导入。';

  @override
  String get mitmModuleNoHosts => '此模块未添加解密域名。';

  @override
  String get mitmAlreadyListed => '已在名单';

  @override
  String get mitmNewHost => '新增';

  @override
  String mitmExcludedCount(int count) {
    return '排除 $count 个';
  }

  @override
  String mitmMoreHosts(int count) {
    return '另外 $count 个';
  }

  @override
  String get mitmModuleRewrites => '改写规则';

  @override
  String get mitmModuleRoutingRules => '分流规则';

  @override
  String get mitmModuleUnsupported => '暂不支持';

  @override
  String mitmModuleUnsupportedCount(int count) {
    return '$count 行不会导入。';
  }

  @override
  String get mitmImportOnly => '仅导入';

  @override
  String get mitmImportAndEnable => '导入并启用';

  @override
  String get mitmImportModule => '导入模块';

  @override
  String get mitmModuleImported => '模块已导入';

  @override
  String mitmModuleHostCount(int count) {
    return '$count 个解密域名';
  }

  @override
  String mitmModuleRewriteCount(int count) {
    return '$count 条改写';
  }

  @override
  String mitmModuleUnsupportedLines(int count) {
    return '$count 行暂不支持';
  }

  @override
  String mitmModuleRemoteSource(Object time) {
    return '远程 · $time更新';
  }

  @override
  String get mitmModuleLocalSource => '本地';

  @override
  String get mitmModulesEmptyTitle => '还没有模块';

  @override
  String get mitmModulesEmptyBody => '导入模块后，可以查看其中的设置。';

  @override
  String mitmScriptsRan(int count) {
    return '脚本已运行 · $count 个';
  }

  @override
  String mitmScriptsPassed(int count) {
    return '$count 个脚本未完成，已原样放行。';
  }

  @override
  String mitmScriptDone(Object took) {
    return '脚本执行完成 · $took';
  }

  @override
  String get mitmScriptTimedOut => '脚本执行超时';

  @override
  String mitmScriptFailed(Object reason) {
    return '脚本执行出错：$reason';
  }

  @override
  String mitmScriptNotRun(Object reason) {
    return '脚本未运行：$reason';
  }

  @override
  String get mitmScriptMemory => '超出内存上限';

  @override
  String get mitmScriptBusy => '同时运行的脚本过多';

  @override
  String get mitmScriptNoDone => '脚本没有调用 \$done';

  @override
  String mitmScriptLogExpand(int count) {
    return '展开全部（$count 行）';
  }

  @override
  String mitmScriptRequestsSent(int count) {
    return '发出 $count 个请求';
  }

  @override
  String get mitmViewInScripts => '在脚本中查看';

  @override
  String get mitmViewInModule => '在模块中查看';

  @override
  String mitmFromModule(Object name) {
    return '模块 · $name';
  }

  @override
  String get mitmUpdateCheckFailedKept => '更新检查失败，当前版本仍可使用。';

  @override
  String get mitmUpdateDownloadFailedKept => '新版下载失败，当前版本仍可使用。';

  @override
  String get mitmUpdateInvalidKept => '新版无法加载，当前版本仍可使用。';

  @override
  String mitmScriptLoadFailed(Object reason) {
    return '脚本无法加载：$reason。';
  }

  @override
  String mitmModuleLoadFailed(Object reason) {
    return '模块无法加载：$reason。';
  }

  @override
  String get mitmPendingKept => '新版待采用，当前版本继续运行。';

  @override
  String mitmScriptFoundUpdate(Object time) {
    return '$time检查到新版';
  }

  @override
  String mitmAlsoDecryptHost(Object host) {
    return '同时把 $host 加入解密';
  }

  @override
  String mitmDiffAdded(int count) {
    return '+$count 行';
  }

  @override
  String mitmDiffRemoved(int count) {
    return '−$count 行';
  }

  @override
  String get mitmPauseAppUnavailable => 'Flash 未响应证书签名请求';

  @override
  String get mitmPauseSignTimeout => '证书签名超时';

  @override
  String get mitmPauseSignRefused => '证书签名未完成';

  @override
  String get mitmPauseAppUnavailableHint => '请稍候，暂停结束后新连接会重新尝试解密。';

  @override
  String get mitmPauseSignTimeoutHint => '请稍候，暂停结束后新连接会重新尝试解密。';

  @override
  String get mitmPauseSignRefusedHint => '请确认 HTTPS 解密已开启；暂停结束后新连接会重新尝试解密。';

  @override
  String get mitmPauseUnavailableHint => '请稍候，暂停结束后新连接会重新尝试解密。';

  @override
  String get mitmCapabilityNotify => '发送系统通知（实际是否显示取决于系统权限及限频）';

  @override
  String mitmModuleRuleCount(int count) {
    return '$count 条分流规则';
  }

  @override
  String mitmRulePolicyMissing(String policy) {
    return '当前配置没有「$policy」，这条规则不会生效';
  }

  @override
  String rulesFromModule(String name) {
    return '来自模块 · $name';
  }

  @override
  String get rulesViewInModule => '在模块中查看';

  @override
  String get mitmRoutingRulesNotApplied => '分流规则未能应用，已恢复原来的设置。';

  @override
  String get mitmRoutingRulesRevertFailed => '分流规则未能应用，也未能恢复原来的设置。请检查当前规则。';

  @override
  String get mitmPauseLeafUnusable => '证书未能使用';

  @override
  String get mitmPauseLeafUnusableHint => '请稍候，暂停结束后新连接会重新尝试解密。';

  @override
  String get mitmChecking => '检查中…';

  @override
  String rulesBelowListLast(String head, String last) {
    return '$head和$last';
  }

  @override
  String get rulesBelowSubscription => '订阅配置';

  @override
  String get rulesBelowScript => '扩展脚本';

  @override
  String get rulesBelowModule => '模块';

  @override
  String get navGroupRouting => '分流';

  @override
  String get navGroupDecryption => '解密与改写';

  @override
  String get navGroupDebug => '调试';

  @override
  String navGroupExpanded(Object group) {
    return '$group，分组，已展开';
  }

  @override
  String navGroupCollapsed(Object group) {
    return '$group，分组，已收起';
  }

  @override
  String navBadgeUpdates(Object count) {
    return '$count 个更新';
  }

  @override
  String get navBadgeError => '有错误';

  @override
  String get exitIpRow => '出口';

  @override
  String get exitIp => '出口 IP';

  @override
  String get localPublicIpRow => '本地公网';

  @override
  String get localPublicIp => '本地公网 IP';

  @override
  String get copyLocalPublicIp => '复制本地公网 IP';

  @override
  String get sameAsExit => '与出口相同';

  @override
  String get querying => '查询中';

  @override
  String get queryFailed => '查询失败';

  @override
  String get exitNotRunning => 'Flash 未运行，暂无出口信息';

  @override
  String get exitIpLookupFailed => '未能查询出口 IP';

  @override
  String get ipxNoResponse => '报告获取失败';

  @override
  String get ipxNativeShort => '原生';

  @override
  String get ipxBroadcastShort => '广播';

  @override
  String ipxScoreSemantics(String score, String grade) {
    return '健康分 $score，等级 $grade';
  }

  @override
  String get exitIpOpenHint => '按下查看出口 IP 详情';

  @override
  String get semanticsSeparator => '，';

  @override
  String get alwaysFindProcess => '始终查找进程';

  @override
  String get exitDefault => '默认';

  @override
  String get customExit => '自定义出口';

  @override
  String get inputExitName => '输入出口名称';

  @override
  String get mitmAndroidRootDesc =>
      '未 root 时只能解密信任用户证书的应用，多为浏览器；root 后可解密所有应用。';

  @override
  String get httpRequestsReadFailed => '无法读取请求';

  @override
  String get requestBodyReadFailed => '无法读取请求体';

  @override
  String get responseBodyReadFailed => '无法读取响应体';

  @override
  String mitmGrpcOverLimit(Object size) {
    return '解压后超过 $size MB，显示压缩数据';
  }

  @override
  String mitmUntrustedStores(Object stores) {
    return '已安装但未信任：$stores';
  }

  @override
  String get removeCertificate => '移除证书';

  @override
  String get removeCertificateSuccess => '已移除证书';

  @override
  String get mitmSystemStoreRemoveFailed => '无法把证书从系统信任的根证书中移除';

  @override
  String get mitmRemoveInSettings => '在系统设置中移除';

  @override
  String mitmRemoveUserCertificateTip(Object name) {
    return 'Android 不允许应用移除用户证书。请在“安全 › 加密与凭据 › 信任的凭据 › 用户”中移除 $name。';
  }

  @override
  String get mitmCannotRemove => '无法移除';

  @override
  String get mitmRemoveSystemCertificateTip =>
      '证书由 root 模块“FlClash MITM CA”加入系统。请在 root 管理器中允许 FlClash 使用 root 后再试，或在其中移除该模块并重启手机。';

  @override
  String get mitmClientRefusedCertificate => '客户端拒绝了证书。请安装证书；如果应用固定了证书，请排除此主机。';

  @override
  String get requestBodyMock => '请求体替换';

  @override
  String get clientSourceAddress => '客户端地址';

  @override
  String get skipVerifyHostname => '不校验证书的主机';

  @override
  String get mitmRequestRulesDesc =>
      '模块里的 URL-REGEX 和 USER-AGENT 规则已改成 URL 重写，逐个请求判断：明文 HTTP 请求都会判断，HTTPS 只在 MITM 主机名里的连接上判断。';

  @override
  String mitmModuleRequirementTip(Object requirement) {
    return '模块要求 $requirement，本设备不满足，可能无法按预期工作。';
  }

  @override
  String mitmExitModules(Object modules) {
    return '来自模块：$modules';
  }

  @override
  String get mitmModuleRiskTitle => '启用此模块？';

  @override
  String get mitmNetworkRisk =>
      '生成配置时，它会修改下列网络设置，并优先于你在 FlClash 中对同一项的设置。关闭或删除模块后即恢复。';

  @override
  String mitmSkipVerifyRisk(Object hosts) {
    return '开启后，将不再校验下列主机的服务器证书，冒充这些服务器的连接不会被发现：$hosts';
  }

  @override
  String mitmClientSourceRisk(Object addresses) {
    return '它只为这些客户端解密：$addresses。开启 TUN 时，本机应用经 TUN 地址连入 FlClash，可能因此不再解密。';
  }

  @override
  String get mitmClientSourceTunTip =>
      '开启 TUN 时，本机应用的来源是 TUN 地址；列表不包含它时，本机应用的流量不会被解密。';

  @override
  String get mitmNetworkChanges => '网络设置';

  @override
  String mitmChangeReplace(Object values) {
    return '替换为 $values';
  }

  @override
  String mitmChangeInsert(Object values) {
    return '在前面添加 $values';
  }

  @override
  String mitmChangeAppend(Object values) {
    return '添加 $values';
  }

  @override
  String get mitmChangeOverridesYours => '会盖过你的设置';

  @override
  String mitmChangeReplacedBy(Object module) {
    return '已被模块 $module 覆盖';
  }

  @override
  String get mitmSkipHttpRulePolicy =>
      'URL-REGEX 和 USER-AGENT 规则只能用 REJECT 类策略';

  @override
  String get mitmSkipFinalRule => '模块的规则排在最前面，兜底规则会盖住后面的所有规则';

  @override
  String get mitmSkipDeviceRule => '这类规则依赖 FlClash 读不到的设备或网络信息';

  @override
  String get mitmSkipRequirement => '这一行的使用条件在本设备上不满足';

  @override
  String get mitmSkipManagedCa => 'CA 证书由 FlClash 管理，模块不能更改';

  @override
  String get mitmSkipProxies => '模块不能修改节点和策略组';

  @override
  String get mitmSkipAppOnly => '这是原 App 独有的功能，FlClash 没有对应项';

  @override
  String get mitmSkipReflect => 'FlClash 不能把数据包原路弹回';

  @override
  String get mitmSkipSkipVerifyAll => '不会对全部主机关闭证书校验';

  @override
  String get mitmScriptCron => '定时';

  @override
  String get mitmScriptEvent => '事件';

  @override
  String get mitmScriptGeneric => '通用';

  @override
  String get mitmExcluded => '排除';

  @override
  String get mitmModulesTurnedOff => '模块已关闭';

  @override
  String mitmModuleTurnedOffDesc(Object name) {
    return '$name 的更新带来了你未同意过的脚本或网络改动';
  }

  @override
  String mitmModulesTurnedOffDesc(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模块的更新带来了你未同意过的脚本或网络改动',
    );
    return '$_temp0';
  }

  @override
  String get mitmModuleUnreadableRisk => '无法读取模块文件，不清楚它会改动什么。只在信任其来源时开启。';

  @override
  String coreStoppedWithReason(Object reason) {
    return '应用与核心的连接已断开：$reason';
  }

  @override
  String mixedPortReset(Object value, Object port) {
    return '混合端口不能是 $value，已恢复为 $port';
  }

  @override
  String get vpnPermissionNotGranted =>
      '未获得 VPN 权限，VPN 没有启动。其他应用设为始终开启的 VPN 时也会如此。';

  @override
  String get vpnServiceStartFailed => 'VPN 服务无法启动。';

  @override
  String updateVersionSummary(String current, String available) {
    return '当前版本：$current\n可更新版本：$available';
  }

  @override
  String get updateImmediately => '立即更新';

  @override
  String updateMenuVersion(String available) {
    return 'NEW $available';
  }

  @override
  String get viewUpdate => '查看更新';

  @override
  String get trayStartCore => '启动核心';

  @override
  String get trayStopCore => '停止核心';

  @override
  String get trayCoreProcessing => '处理中';

  @override
  String trayUpdateAvailable(Object version) {
    return '可用更新：$version';
  }
}
