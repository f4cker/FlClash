// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a zh_CN locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'zh_CN';

  static String m0(count) => "已选 ${count}";

  static String m1(name) => "已将 ${name} 添加到本地代理";

  static String m2(name) => "本地代理中已有 ${name}";

  static String m3(count, skipped) => "将添加 ${count} 项，跳过 ${skipped} 项已存在";

  static String m4(detail) => "清除数据失败：${detail}";

  static String m5(code) =>
      "Windows 拒绝运行 FlClashCore.exe（错误 ${code}）。智能应用控制、AppLocker 等应用控制策略会拦截未签名程序，请在该策略中放行 Flash 或关闭策略后重试。";

  static String m6(name) =>
      "应用连续两次未能完成启动。为打断崩溃循环，已取消选中配置 ${name}，并跳过本次自动配置，你可以随时重新选中它。";

  static String m7(url) => "是否要通过 ${url} 创建配置？";

  static String m8(count, label) =>
      "${Intl.plural(count, other: '自定义配置不支持子规则，已丢弃 ${label} 条 SUB-RULE 规则')}";

  static String m9(message) => "内核无法解析该代理：${message}";

  static String m10(proxy, target) =>
      "${proxy} 经 ${target} 拨号，而 ${target} 又会回到 ${proxy}，形成环路";

  static String m11(name) => "名称 ${name} 已被其他代理或策略组使用";

  static String m12(path) => "策略组之间存在循环引用：${path}";

  static String m13(name) => "空组兜底只能是代理，${name} 不存在或是策略组";

  static String m14(name, message) => "${name}不是有效的正则：${message}";

  static String m15(name) => "拨号代理 ${name} 不存在";

  static String m16(names) => "以下代理集不存在：${names}";

  static String m17(names) => "以下代理或策略不存在：${names}";

  static String m18(name) => "${name} 是内置策略名，不能在此使用";

  static String m19(count) => "${count} 项存在问题，应用配置可能失败";

  static String m20(count) => "${count} 天前";

  static String m21(count) => "${count} 天前";

  static String m22(label) => "确定删除选中的${label}吗？";

  static String m23(label) => "确定删除当前${label}吗？";

  static String m24(label) => "${label}详情";

  static String m25(name) => "经 ${name} 拨号会绕回使用它的代理，连接已中止";

  static String m26(label) => "${label}不能为空";

  static String m27(label) => "${label}当前已存在";

  static String m28(count) => "${count} 项失败，点击查看";

  static String m29(label, message) => "${label}：${message}";

  static String m30(name) => "${name} 已是最新版本";

  static String m31(name) => "${name} 已更新";

  static String m32(count) => "${count} 个";

  static String m33(count) => "${count} 超时";

  static String m34(action) => "已被“${action}”使用，保存后将移到这里";

  static String m35(modifiers) => "至少包含 ${modifiers} 中的一个";

  static String m36(count) => "${count} 小时前";

  static String m37(count) => "${count} 小时前";

  static String m38(encoding) => "无法解码 ${encoding}，显示的是传输时的原始数据。";

  static String m39(memory, body) =>
      "达到此条数或占满 ${memory} 内存后，先丢弃最早的记录。每段内容只保留前 ${body}。";

  static String m40(invalid, total) => "${total} 条中 ${invalid} 条无效";

  static String m41(target) => "${target} 是一个无效的策略";

  static String m42(proxyName) => "${proxyName} 是一个无效的代理";

  static String m43(providerName) => "${providerName} 是一个无效的代理集";

  static String m44(ruleSet) => "${ruleSet} 不是有效的规则集";

  static String m45(subRule) => "${subRule} 是一个无效的SUB_RULE";

  static String m46(count) => "${count} 项";

  static String m47(line, message) => "第 ${line} 行：${message}";

  static String m48(appName) =>
      "1. 打开 系统设置 > 隐私与安全性\n2. 选择 定位服务\n3. 在右侧列表中找到并勾选 ${appName}\n\n完成设置后，返回应用即可正常使用。感谢您的配合。";

  static String m49(label, max) => "${label}最多${max}个字符";

  static String m50(size) => "已释放 ${size}";

  static String m51(count) => "${count} 分钟前";

  static String m52(count) => "${count} 分钟前";

  static String m53(fileName) =>
      "已将 ${fileName} 保存到“下载”。请在系统设置的“安全 › 加密与凭据 › 安装证书 › CA 证书”中安装。";

  static String m54(command) =>
      "Chrome 和 Firefox 使用自己的证书库，需要 certutil：${command}";

  static String m55(host) =>
      "要把 ${host} 加入主机名列表吗？之后 Flash 能读取发往它的内容，包括 Cookie 和密码。";

  static String m56(host) => "要把 -${host} 加到主机名列表顶部吗？之后不再解密该主机。";

  static String m57(size) => "文件大于 ${size} MB";

  static String m58(stores) => "尚未加入：${stores}";

  static String m59(name) => "${name} 的脚本有变化，已关闭";

  static String m60(system) => "为 ${system} 编写，部分行可能不适用于本设备。";

  static String m61(name) => "无法移除旧证书 ${name}，请自行从信任的根证书中移除。";

  static String m62(name) =>
      "旧证书 ${name} 仍在系统信任的证书中。请在 root 管理器中允许 Flash 使用 root 后重新生成，或在其中移除“FlClash MITM CA”模块并重启。";

  static String m63(name) =>
      "请在系统设置的“安全 › 加密与凭据 › 信任的凭据 › 用户”中移除旧证书 ${name}，再安装新证书。";

  static String m64(section) => "不支持 [${section}] 段";

  static String m65(port) => "无法打开端口 ${port}，可能已被其他应用占用。代理服务未启动。";

  static String m66(port) => "无法打开端口 ${port}，可能已被其他应用占用。代理服务未启动。未更改系统代理设置。";

  static String m67(count) => "${count} 个月前";

  static String m68(count) => "${count} 个月前";

  static String m69(count) => "本次保存还将挂载 ${count} 份订阅。";

  static String m70(target) => "空组处理来自原配置：${target}。";

  static String m71(count) => "${count} 份订阅更新失败";

  static String m72(subscriptionName, profileCount) =>
      "“${subscriptionName}”还挂载在以下 ${profileCount} 份配置中。删除后，将从这些配置移除此订阅提供的节点，相关连接可能中断。其他订阅、基础配置文件和 Tailscale 登录记录不会删除。";

  static String m73(group) => "分组“${group}”暂无可选节点，请检查订阅和分组筛选。";

  static String m74(count) => "为保持 Tailscale 分流隔离，${count} 个分组不接收订阅节点。";

  static String m75(groups) => "涉及分组：${groups}。";

  static String m76(time) => "上次更新：${time}";

  static String m77(count) => "${count} 个节点";

  static String m78(count) => "已读取 ${count} 个节点";

  static String m79(time) => "节点读取时间：${time}";

  static String m80(label, profileName) => "${label}, 目标配置 ${profileName}";

  static String m81(name) => "“${name}”的新内容已读取，但未通过挂载隔离检查，未应用；仍使用此前确认的内容。";

  static String m82(name) =>
      "“${name}”的新内容已读取，但未通过挂载隔离检查，未应用；当前使用状态待确认，请重新读取状态。";

  static String m83(profileName) => "目标配置：${profileName}";

  static String m84(subscriptionName, profileName) =>
      "将从“${profileName}”移除“${subscriptionName}”提供的节点。使用这些节点的连接可能中断。订阅本身、原配置文件和其他挂载不会删除，Tailscale 专用分流不变。";

  static String m85(count, profileName) =>
      "将从“${profileName}”移除以下 ${count} 份订阅提供的节点。使用这些节点的连接可能中断。订阅本身、原配置文件和其他挂载不会删除，Tailscale 专用分流不变。";

  static String m86(count) =>
      "为保持 Tailscale 分流隔离，已排除 ${count} 个暂不支持挂载的订阅节点，原设置未更改。";

  static String m87(name) => "更新节点 ${name}";

  static String m88(count) => "已挂载 ${count} 份订阅";

  static String m89(code) => "服务器拒绝访问（HTTP ${code}），链接可能已过期或凭据有误";

  static String m90(code) => "服务器拒绝了请求（HTTP ${code}）";

  static String m91(code) => "该地址下没有内容（HTTP ${code}），请确认链接是否正确";

  static String m92(detail) => "网络请求失败：${detail}";

  static String m93(code) => "服务器出现问题（HTTP ${code}），请稍后再试";

  static String m94(label) => "暂无${label}";

  static String m95(label, min, max) => "${label}必须在 ${min} 到 ${max} 之间";

  static String m96(label) => "${label}必须为数字";

  static String m97(label) => "${label} 必须在 1024 到 49151 之间";

  static String m98(port) => "端口 ${port}";

  static String m99(days) => "剩余 ${days} 天";

  static String m100(date, days) => "${date} 到期，剩余 ${days} 天";

  static String m101(time) => "更新于 ${time}";

  static String m102(label, profiles) =>
      "${label} 仍被 ${profiles} 使用，删除后这些配置会异常。确定删除吗？";

  static String m103(count, label) =>
      "${Intl.plural(count, other: '${label} 个代理')}";

  static String m104(name, count) => "${name} 等 ${count} 个代理";

  static String m105(removed) =>
      "以下代理将被删除：${removed}。改了名字的行按新代理处理，自定义配置中对被删除代理的引用会标为缺失。确定应用吗？";

  static String m106(removed, added) =>
      "以下代理将被删除：${removed}。以下代理将新增：${added}。改了名字的行按新代理处理，自定义配置中对被删除代理的引用会标为缺失。确定应用吗？";

  static String m107(label) =>
      "${label} 仍被当前配置的规则、策略组、拨号代理、DNS 或 NTP 引用，删除后这些引用会失效。确定删除吗？";

  static String m108(count, label) =>
      "${Intl.plural(count, other: '${label} 个策略组')}";

  static String m109(count, label) =>
      "${Intl.plural(count, other: '${label} 条规则')}";

  static String m110(appName) => "${appName}（安全模式）";

  static String m111(count) => "${count} 秒";

  static String m112(count) => "${count} 项生效";

  static String m113(count) => "${count} 项异常";

  static String m114(count) => "${count} 项设置";

  static String m115(link) => "无法从 ${link} 中读取代理";

  static String m116(label) => "${label}只能是一项";

  static String m117(value) => "峰值 ${value}";

  static String m118(value) => "累计 ${value}";

  static String m119(transport) => "${transport} 请求头";

  static String m120(account) => "已指定：${account}";

  static String m121(account, network) => "${account} · ${network}";

  static String m122(count) => "${count} 个目标需要指定账号";

  static String m123(count) =>
      "此配置包含 ${count} 个面板添加的 Tailscale 账号。删除配置会移除这些账号与此配置的关联、目标归属及专用规则和拦截保护；本机登录存档仍会保留。不会删除 Tailscale 管理页面中的设备，其他配置不受影响。";

  static String m124(count) =>
      "${Intl.plural(count, other: '${count} 台设备 · 仅显示此账号可见的设备')}";

  static String m125(shown, total) => "显示 ${shown}/${total} 台 · 仅限此账号可见的设备";

  static String m126(n) => "当前显示 ${n} 台设备";

  static String m127(node, device) =>
      "将“${node}”的出口节点设为“${device}”。经过此节点的连接可能中断；Flash 的规则不变。";

  static String m128(node) => "仅关闭“${node}”的出口转发，不会退出 Tailscale，Flash 的规则不变。";

  static String m129(time) => "认证将于 ${time} 到期，请在到期前重新登录。";

  static String m130(account) => "登录账号：${account}";

  static String m131(server) => "控制服务器：${server}";

  static String m132(name) => "节点：${name}";

  static String m133(name) => "配置：${name}";

  static String m134(name) =>
      "将退出“${name}”，并清除本机保存的该节点登录身份。经过此节点的连接可能中断，其他节点不受影响。";

  static String m135(name) => "所在网络：${name}";

  static String m136(name) => "节点 ${name}";

  static String m137(account, node, profile) =>
      "将退出“${account}”（节点“${node}”），清除本机保存的该节点登录身份，并从“${profile}”移除面板添加的节点和专用规则。经过此节点的连接可能中断。不会退出或移除其他账号。";

  static String m138(node, profile) =>
      "将退出“${node}”，清除本机保存的该节点登录身份，并从“${profile}”移除面板添加的节点和专用规则。经过此节点的连接可能中断。不会退出或移除其他账号。";

  static String m139(count) => "设备地址：${count} 个";

  static String m140(domain) => "网络域名：${domain}";

  static String m141(value) => "已保存：${value}";

  static String m142(name) => "分享来源：${name}";

  static String m143(account, node) =>
      "将退出“${account}”（节点“${node}”），并清除本机保存的该节点登录身份。面板记录和目标归属会保留；发往此账号的连接可能中断，不会自动改用其他账号或直连。不会退出其他账号。再次使用时需由你点击登录。";

  static String m144(label) => "状态：${label}";

  static String m145(account, status, count) =>
      "当前查看的 Tailscale 账号：${account}，${status}，共 ${count} 项";

  static String m146(address) => "地址：${address}";

  static String m147(domain) => "域名：${domain}";

  static String m148(label) => "${label}必须为URL";

  static String m149(date) => "有效期至 ${date}";

  static String m150(count) => "${count} 年前";

  static String m151(count) => "${count} 年前";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("关于"),
    "accessControl": MessageLookupByLibrary.simpleMessage("访问控制"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "只允许选中应用进入VPN",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "应用访问控制已关闭",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "选中应用将会被排除在VPN之外",
    ),
    "accessControlSelectedCount": m0,
    "account": MessageLookupByLibrary.simpleMessage("账号"),
    "action": MessageLookupByLibrary.simpleMessage("操作"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("测试全部延迟"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("直连模式"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("全局模式"),
    "actionMode": MessageLookupByLibrary.simpleMessage("切换模式"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("规则模式"),
    "actionStart": MessageLookupByLibrary.simpleMessage("启动/停止"),
    "actionTun": MessageLookupByLibrary.simpleMessage("虚拟网卡"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage("更新全部配置"),
    "actionView": MessageLookupByLibrary.simpleMessage("显示/隐藏"),
    "add": MessageLookupByLibrary.simpleMessage("添加"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("添加代理"),
    "addFilters": MessageLookupByLibrary.simpleMessage("添加筛选"),
    "addNodes": MessageLookupByLibrary.simpleMessage("添加节点"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage("添加覆写项"),
    "addProfile": MessageLookupByLibrary.simpleMessage("添加配置"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("添加策略组"),
    "addRule": MessageLookupByLibrary.simpleMessage("添加规则"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("添加设置项"),
    "addSsid": MessageLookupByLibrary.simpleMessage("添加SSID"),
    "addToLocalProxies": MessageLookupByLibrary.simpleMessage("添加到本地代理"),
    "addedRules": MessageLookupByLibrary.simpleMessage("附加规则"),
    "addedToLocalProxies": m1,
    "additionalParameters": MessageLookupByLibrary.simpleMessage("附加参数"),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("名称前缀"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("名称后缀"),
    "address": MessageLookupByLibrary.simpleMessage("地址"),
    "addressTip": MessageLookupByLibrary.simpleMessage("请输入有效的WebDAV地址"),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("进阶配置"),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage("配置已加密"),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("age 私钥"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "该配置已用 age 加密，需要 age 私钥才能解密",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("同意"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage("全部被引用的代理"),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "全部被引用的代理集",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("允许应用绕过VPN"),
    "allowLan": MessageLookupByLibrary.simpleMessage("局域网代理"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("允许的 IP"),
    "alreadyInLocalProxies": m2,
    "answers": MessageLookupByLibrary.simpleMessage("应答"),
    "app": MessageLookupByLibrary.simpleMessage("应用"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage("应用访问控制"),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("应用图标设计"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("暂无本地代理"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("追加系统DNS"),
    "applied": MessageLookupByLibrary.simpleMessage("已应用"),
    "applyNow": MessageLookupByLibrary.simpleMessage("立即应用"),
    "arguments": MessageLookupByLibrary.simpleMessage("参数"),
    "authentication": MessageLookupByLibrary.simpleMessage("认证"),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "认证启用时，系统代理不生效。",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("授权"),
    "authorized": MessageLookupByLibrary.simpleMessage("已授权"),
    "auto": MessageLookupByLibrary.simpleMessage("自动"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("自动检查更新"),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage("自动关闭连接"),
    "autoInclude": MessageLookupByLibrary.simpleMessage("自动包含"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("自启动"),
    "autoRun": MessageLookupByLibrary.simpleMessage("自动运行"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage("自动运行会在打开应用时启动代理。"),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage("自动设置系统DNS"),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("自动更新"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage("自动更新间隔"),
    "back": MessageLookupByLibrary.simpleMessage("返回"),
    "backgroundBlur": MessageLookupByLibrary.simpleMessage("背景模糊"),
    "backup": MessageLookupByLibrary.simpleMessage("备份"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage("备份与恢复"),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "该备份来自更高版本的应用，请先更新应用再恢复",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("备份成功"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("基础信息"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("基础策略"),
    "batchImport": MessageLookupByLibrary.simpleMessage("批量导入"),
    "batchLineInputTip": MessageLookupByLibrary.simpleMessage("每行一项"),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage("每行一个链接"),
    "batchPreviewTip": m3,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage("每行一个URL"),
    "binaryData": MessageLookupByLibrary.simpleMessage("二进制数据"),
    "bind": MessageLookupByLibrary.simpleMessage("绑定"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("黑名单模式"),
    "blockQuic": MessageLookupByLibrary.simpleMessage("阻止 QUIC"),
    "bodyRewrite": MessageLookupByLibrary.simpleMessage("Body 重写"),
    "brightness": MessageLookupByLibrary.simpleMessage("亮度"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("排除域名"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "排除域名仅在系统代理启用时生效。",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage("绕过私有路由地址"),
    "cache": MessageLookupByLibrary.simpleMessage("缓存"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("缓存算法"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage("缓存已损坏，是否清空？"),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("缓存大小"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "请在系统设置中允许访问相机以扫描二维码，或从相册选择二维码图片。",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage("需要相机权限"),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage("相机不可用"),
    "cancel": MessageLookupByLibrary.simpleMessage("取消"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("取消全选"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("无法保存"),
    "certificate": MessageLookupByLibrary.simpleMessage("证书"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "切换代理失败，已恢复上一次的选择",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage("重大变更"),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("新功能"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("问题修复"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("性能优化"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("已回滚"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage("校验 TLS 证书"),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "关闭证书校验后，订阅和备份可能遭中间人攻击。",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("检查更新"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage("当前应用已经是最新版了"),
    "cipher": MessageLookupByLibrary.simpleMessage("加密方式"),
    "clearData": MessageLookupByLibrary.simpleMessage("清除数据"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "将删除所有配置、设置和本地数据，随后关闭应用。重新打开即可从头开始。",
    ),
    "clearDataFailed": m4,
    "clearDnsCache": MessageLookupByLibrary.simpleMessage("清除DNS缓存"),
    "clearDnsCacheFailed": MessageLookupByLibrary.simpleMessage("清除DNS缓存失败"),
    "clearSearch": MessageLookupByLibrary.simpleMessage("清除搜索"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage("客户端指纹"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("导出剪贴板"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("剪贴板导入"),
    "clipboardNoPackageNames": MessageLookupByLibrary.simpleMessage(
      "剪贴板中没有有效的包名",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "无法复制到剪贴板，所选内容可能过大",
    ),
    "close": MessageLookupByLibrary.simpleMessage("关闭"),
    "closeConnection": MessageLookupByLibrary.simpleMessage("关闭连接"),
    "closeConnections": MessageLookupByLibrary.simpleMessage("关闭连接"),
    "color": MessageLookupByLibrary.simpleMessage("颜色"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("配色风格"),
    "columns": MessageLookupByLibrary.simpleMessage("列数"),
    "compact": MessageLookupByLibrary.simpleMessage("紧凑"),
    "compatible": MessageLookupByLibrary.simpleMessage("兼容模式"),
    "confirm": MessageLookupByLibrary.simpleMessage("确定"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage("确定要清除所有数据？"),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "确定要删除当前策略组吗？",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage("确定要退出当前窗口吗？"),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage("确定要强制崩溃核心？"),
    "congestionControl": MessageLookupByLibrary.simpleMessage("拥塞控制"),
    "congestionController": MessageLookupByLibrary.simpleMessage("TCP 拥塞控制"),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP 拥塞控制仅在 mips 栈生效。",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("已连接"),
    "connecting": MessageLookupByLibrary.simpleMessage("连接中…"),
    "connection": MessageLookupByLibrary.simpleMessage("连接"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("连接统计"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "实时连接、最近请求、DNS查询",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("连接"),
    "connectivity": MessageLookupByLibrary.simpleMessage("连通性："),
    "content": MessageLookupByLibrary.simpleMessage("内容"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage("内容不能为空"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage("控制全局附加规则"),
    "copy": MessageLookupByLibrary.simpleMessage("复制"),
    "copyAsBase64": MessageLookupByLibrary.simpleMessage("复制为 Base64"),
    "copyAsCurl": MessageLookupByLibrary.simpleMessage("复制为 cURL"),
    "copyDestination": MessageLookupByLibrary.simpleMessage("复制目标地址"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage("复制环境变量"),
    "copyHost": MessageLookupByLibrary.simpleMessage("复制主机"),
    "copyLink": MessageLookupByLibrary.simpleMessage("复制链接"),
    "copyRequest": MessageLookupByLibrary.simpleMessage("复制请求"),
    "copyResponse": MessageLookupByLibrary.simpleMessage("复制响应"),
    "copyResponseBody": MessageLookupByLibrary.simpleMessage("复制响应体"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("复制成功"),
    "core": MessageLookupByLibrary.simpleMessage("内核"),
    "coreBlockedByPolicyTip": m5,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows 智能应用控制拦截了未签名的 FlClashCore.exe。请打开 Windows 安全中心 → 应用和浏览器控制 → 智能应用控制设置，选择「关闭」后重新启动 Flash。智能应用控制关闭后无法再开启，除非重装 Windows。",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("核心状态"),
    "country": MessageLookupByLibrary.simpleMessage("区域"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("检测到崩溃"),
    "crashDetectedTip": m6,
    "crashTest": MessageLookupByLibrary.simpleMessage("崩溃测试"),
    "create": MessageLookupByLibrary.simpleMessage("创建"),
    "createProfileFromUrlTip": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("创建时间"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage("含启动键，不可移除"),
    "custom": MessageLookupByLibrary.simpleMessage("自定义"),
    "customColor": MessageLookupByLibrary.simpleMessage("自定义颜色"),
    "customImportDroppedSubRules": m8,
    "customIssueCoreRejected": m9,
    "customIssueDialerLoop": m10,
    "customIssueDuplicateName": m11,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage("名称为空"),
    "customIssueGroupLoop": m12,
    "customIssueInvalidEmptyFallback": m13,
    "customIssueInvalidFilter": m14,
    "customIssueMissingDialer": m15,
    "customIssueMissingProviders": m16,
    "customIssueMissingProxies": m17,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "未选择任何代理或代理集，内核会拒绝该策略组",
    ),
    "customIssueReservedName": m18,
    "customIssuesSummary": m19,
    "customProfile": MessageLookupByLibrary.simpleMessage("自定义"),
    "customResources": MessageLookupByLibrary.simpleMessage("自定义"),
    "cut": MessageLookupByLibrary.simpleMessage("剪切"),
    "dark": MessageLookupByLibrary.simpleMessage("深色"),
    "dashboard": MessageLookupByLibrary.simpleMessage("仪表盘"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage("可添加"),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "保存更改失败，已回滚",
    ),
    "daysAgo": m20,
    "daysAgoShort": m21,
    "decryptUntrusted": MessageLookupByLibrary.simpleMessage("本机未信任时也解密"),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "用于解析其他 DNS 服务器的域名，只能填写 IP 地址。",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage("默认选中"),
    "defaultText": MessageLookupByLibrary.simpleMessage("默认"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "配置必须是包含 name 和 type 的 YAML 映射",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("延迟"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("失败"),
    "delayTest": MessageLookupByLibrary.simpleMessage("延迟测试"),
    "delayTestTimeout": MessageLookupByLibrary.simpleMessage("延迟测试超时"),
    "delete": MessageLookupByLibrary.simpleMessage("删除"),
    "deleteMultipTip": m22,
    "deleteTip": m23,
    "desc": MessageLookupByLibrary.simpleMessage(
      "基于ClashMeta的多平台代理客户端，简单易用，开源无广告。",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("目标地址"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage("目标地理定位"),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage("目标IP ASN"),
    "details": m24,
    "detectionTip": MessageLookupByLibrary.simpleMessage("依赖第三方api，仅供参考"),
    "developerMode": MessageLookupByLibrary.simpleMessage("开发者模式"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage("开发者模式已启用。"),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("拨号代理"),
    "dialerProxyLoopStopped": m25,
    "dialog": MessageLookupByLibrary.simpleMessage("对话框"),
    "direct": MessageLookupByLibrary.simpleMessage("直连"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "用于解析直连连接的域名。",
    ),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage("禁用ICMP转发"),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "禁用 ICMP 转发后由虚拟网卡直接应答 ping，ping 将不再显示真实延迟。",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage("禁用 TCP 保持活动"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("禁用UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("已关闭"),
    "discardChanges": MessageLookupByLibrary.simpleMessage("是否放弃更改？"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("免责声明"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "本声明是对软件性质、风险与责任的说明，不是 GPL-3.0 之外的附加条款，也不限制该协议授予你的运行、复制、修改和分发等任何权利；两者不一致时，以 GPL-3.0 为准。",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage("与开源协议的关系"),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "我已阅读并理解此声明",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "为确认你已知悉，请阅读以下声明并勾选下方选项：",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage("确认声明"),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "本声明可能随版本更新而修订，以每个版本附带的内容为准。",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage("声明变更"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "在使用 Flash（以下简称“本软件”）前，请仔细阅读并充分理解本声明。点击“同意”表示你已阅读并理解以下内容；如不想继续，可点击“退出”。",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "在适用法律允许的最大范围内，开发者及所有贡献者均不对因使用或无法使用本软件而产生的任何直接、间接、偶然、特殊、惩罚性或后果性损害承担责任，包括但不限于数据丢失、设备损坏、网络异常、业务中断、利润损失或因此引起的任何法律纠纷，即使已被告知发生此类损害的可能性。",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage("责任限制"),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "本软件以 GPL-3.0 协议开源，你可以依该协议运行、研究、修改和分发本软件；分发本软件或其修改版本时，须同样以 GPL-3.0 协议提供源代码并保留原有的版权声明。\n\n本软件包含的第三方组件（包括 Clash.Meta 内核）分别遵循其各自的开源协议。基于本软件修改或分发的版本所产生的任何问题，与原作者无关。",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage("开源协议"),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "本软件自身不提供任何代理服务器、节点、订阅、机场或网络接入服务，也不与任何此类服务的提供者存在合作、代理或担保关系。",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "本软件不会收集或上传你的订阅地址、节点信息、配置内容、访问的网站、连接记录、流量内容和日志，这些数据仅保存在你的设备本地，开发者无法获取。\n\n本软件只会在你使用相应功能时访问外部网络，例如更新订阅时访问你提供的订阅地址、检查更新时访问 GitHub。\n\n本软件在所有平台上均未集成任何数据统计或崩溃上报服务。",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage("数据收集与隐私"),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "你应自行确认使用本软件在你所在国家或地区是合法的，并对使用本软件的全部行为及其后果独立承担法律责任。\n\n你导入的订阅、节点与配置由你自行选择和判断，其来源是否合法、内容是否安全、服务是否稳定，均由你与相关提供者自行负责。",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "用户责任",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage("在此输入上述声明"),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "与声明内容不一致",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "为确认你已知悉，请在下方输入框中完整复述以下声明：",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage("复述声明"),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "本软件是基于 Clash.Meta（mihomo）内核的开源网络代理客户端，仅提供配置管理、规则分流与流量转发等本地工具功能。",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage("软件性质"),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "订阅链接、配置文件、规则集、脚本、外部资源及外部链接均由第三方提供，开发者无法也不会对其合法性、准确性、安全性和可用性进行审查或担保。\n\n因使用第三方内容导致的数据泄露、财产损失、账号封禁或其他任何损失，由你与第三方自行解决，开发者不承担任何责任。",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage("第三方内容"),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "任何人基于本软件开展的商业活动，包括付费分发、捆绑销售或作为商业服务的组成部分，均与本软件的开发者无关，开发者不为其提供背书、支持或担保。\n\n你须自行遵守所在国家或地区的法律法规，因违法使用本软件产生的后果由你自行承担。",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("使用说明"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "本软件按“现状”和“可用”的原则提供，不附带任何明示或默示的担保，包括但不限于适销性、特定用途适用性、不侵权以及持续可用、无错误、无安全漏洞的担保。\n\n开发者不保证本软件能满足你的需求，也不保证本软件的运行不会中断或不会出现错误。",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage("无担保声明"),
    "disconnected": MessageLookupByLibrary.simpleMessage("已断开"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage("发现新版本"),
    "dnsCacheCleared": MessageLookupByLibrary.simpleMessage("DNS缓存已清除"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "未添加时劫持所有发往 53 端口的 DNS 请求（any:53）。",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS劫持"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS模式"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "添加的项会覆写所有 URL 和文件配置的 DNS，未添加的项沿用配置自身的设置。自定义配置的 DNS 在其内容中设置。",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS查询"),
    "docked": MessageLookupByLibrary.simpleMessage("固定"),
    "domain": MessageLookupByLibrary.simpleMessage("域名"),
    "done": MessageLookupByLibrary.simpleMessage("完成"),
    "download": MessageLookupByLibrary.simpleMessage("下载"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage("下行带宽"),
    "downloadingUpdate": MessageLookupByLibrary.simpleMessage("正在下载更新"),
    "duration": MessageLookupByLibrary.simpleMessage("时长"),
    "edit": MessageLookupByLibrary.simpleMessage("编辑"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("编辑仪表盘"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage("编辑全局规则"),
    "editProxy": MessageLookupByLibrary.simpleMessage("编辑代理"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("编辑策略组"),
    "editRule": MessageLookupByLibrary.simpleMessage("编辑规则"),
    "editSsid": MessageLookupByLibrary.simpleMessage("编辑SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage("编辑器不可用"),
    "elapsed": MessageLookupByLibrary.simpleMessage("耗时"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("空组兜底"),
    "emptyTip": m26,
    "en": MessageLookupByLibrary.simpleMessage("英语"),
    "enabled": MessageLookupByLibrary.simpleMessage("已开启"),
    "entries": MessageLookupByLibrary.simpleMessage("个条目"),
    "error": MessageLookupByLibrary.simpleMessage("错误"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("错误详情"),
    "es": MessageLookupByLibrary.simpleMessage("西班牙语"),
    "exclude": MessageLookupByLibrary.simpleMessage("从最近任务中隐藏"),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage("排除目标端口"),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("排除筛选"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage("排除网卡"),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage("排除源端口"),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("排除SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "连接到被排除 SSID 的 Wi-Fi 时，将会自动切换应用运行状态。",
    ),
    "excludeUid": MessageLookupByLibrary.simpleMessage("排除用户 ID"),
    "existsTip": m27,
    "exit": MessageLookupByLibrary.simpleMessage("退出"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("退出全屏"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("出口节点"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("预期状态"),
    "expireTime": MessageLookupByLibrary.simpleMessage("到期时间"),
    "exportCertificate": MessageLookupByLibrary.simpleMessage("导出证书"),
    "exportFile": MessageLookupByLibrary.simpleMessage("导出文件"),
    "exportHar": MessageLookupByLibrary.simpleMessage("导出 HAR"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("导出日志"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("导出成功"),
    "extend": MessageLookupByLibrary.simpleMessage("扩展"),
    "extendMode": MessageLookupByLibrary.simpleMessage("扩展模式"),
    "extendScript": MessageLookupByLibrary.simpleMessage("扩展脚本"),
    "externalController": MessageLookupByLibrary.simpleMessage("外部控制器"),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "外部控制器开启后，可通过 9090 端口控制内核。",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage("外部控制器密钥"),
    "externalLink": MessageLookupByLibrary.simpleMessage("外部链接"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("超大"),
    "fade": MessageLookupByLibrary.simpleMessage("淡入"),
    "failedCount": m28,
    "failedItem": m29,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IP过滤"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "这些域名不使用 Fake-IP，返回真实 IP；过滤模式为 whitelist 时则只有它们使用 Fake-IP。",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage("Fake-IP过滤模式"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP范围"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage("Fake-IP范围（IPv6）"),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Nameserver 的结果被 Fallback 过滤判定为污染时，改用这些服务器的结果。",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback过滤"),
    "fallbackFilterDomainDesc": MessageLookupByLibrary.simpleMessage(
      "这些域名直接使用 Fallback 解析。",
    ),
    "fallbackFilterGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "属于这些 GeoSite 分类的域名直接使用 Fallback 解析。",
    ),
    "fallbackFilterIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Nameserver 返回这些网段内的 IP 时，改用 Fallback 的结果。",
    ),
    "file": MessageLookupByLibrary.simpleMessage("文件"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage("文件有修改，是否保存修改"),
    "filter": MessageLookupByLibrary.simpleMessage("筛选"),
    "filters": MessageLookupByLibrary.simpleMessage("筛选"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("查找进程"),
    "floating": MessageLookupByLibrary.simpleMessage("悬浮"),
    "followProfile": MessageLookupByLibrary.simpleMessage("跟随配置"),
    "followSystem": MessageLookupByLibrary.simpleMessage("跟随系统"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("字体"),
    "fontSize": MessageLookupByLibrary.simpleMessage("大小"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("强制DNS映射"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "强制 DNS 映射对通过 DNS 映射得到域名的连接也进行嗅探。",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("强制嗅探域名"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "强制嗅探域名中的域名同样会被嗅探，其余已有域名的连接不嗅探。",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage("您确定要强制重启核心吗？"),
    "fr": MessageLookupByLibrary.simpleMessage("法语"),
    "general": MessageLookupByLibrary.simpleMessage("常规"),
    "generalOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "添加的项会覆写所有配置的对应设置，未添加的项沿用配置自身的设置，配置未设置时使用内核默认值。",
    ),
    "generateCertificate": MessageLookupByLibrary.simpleMessage("生成证书"),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m30,
    "geoUpdated": m31,
    "geodataLoader": MessageLookupByLibrary.simpleMessage("Geo低内存模式"),
    "global": MessageLookupByLibrary.simpleMessage("全局"),
    "go": MessageLookupByLibrary.simpleMessage("前往"),
    "goDownload": MessageLookupByLibrary.simpleMessage("前往下载"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage("前往配置附加规则"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage("前往配置脚本"),
    "grid": MessageLookupByLibrary.simpleMessage("网格"),
    "groupBy": MessageLookupByLibrary.simpleMessage("分类"),
    "groupCount": m32,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("个"),
    "groupTimeoutCount": m33,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("是否缓存修改"),
    "hashByInUser": MessageLookupByLibrary.simpleMessage("按入站用户哈希"),
    "headerRewrite": MessageLookupByLibrary.simpleMessage("Header 重写"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("健康检查"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper 服务不可用，无法启用 TUN 模式，请重新安装 Flash。",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("十六进制"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("从列表中隐藏"),
    "hideIp": MessageLookupByLibrary.simpleMessage("隐藏 IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("隐藏密码"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage("隐藏超时代理"),
    "hopInterval": MessageLookupByLibrary.simpleMessage("跳跃间隔"),
    "host": MessageLookupByLibrary.simpleMessage("主机"),
    "hostname": MessageLookupByLibrary.simpleMessage("主机名"),
    "hotkeyConflictWith": m34,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "全局快捷键在窗口隐藏时依然生效，点击操作即可录制组合键。",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("快捷键管理"),
    "hotkeyNeedsModifier": m35,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("未设置"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "未能注册，可能已被其他应用占用",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("小时"),
    "hoursAgo": m36,
    "hoursAgoShort": m37,
    "http2": MessageLookupByLibrary.simpleMessage("HTTP/2"),
    "httpBodyNotKept": MessageLookupByLibrary.simpleMessage("内存紧张时未记录这段内容。"),
    "httpBodyProtobufGuess": MessageLookupByLibrary.simpleMessage(
      "按 Protobuf 解析，没有 .proto：只有字段编号，类型是推测的。",
    ),
    "httpBodyTruncated": MessageLookupByLibrary.simpleMessage("只记录了这段内容的开头部分。"),
    "httpBodyUndecoded": m38,
    "httpCapture": MessageLookupByLibrary.simpleMessage("抓包"),
    "httpCaptureDesc": MessageLookupByLibrary.simpleMessage(
      "记录“主机名”中列出的主机的请求，在连接详情中查看。记录只保存在内存中。",
    ),
    "httpCaptureLimit": MessageLookupByLibrary.simpleMessage("最多记录条数"),
    "httpCaptureLimitDesc": m39,
    "httpCaptureNoHosts": MessageLookupByLibrary.simpleMessage(
      "未列出任何主机，不会记录内容。请在 MITM 页的“主机名”中添加，或在连接详情中加入。",
    ),
    "httpCaptureOff": MessageLookupByLibrary.simpleMessage("抓包未开启"),
    "httpExportPrivate": MessageLookupByLibrary.simpleMessage(
      "请求里可能有 Cookie、令牌、密码和表单内容，分享前请确认内容和对象。",
    ),
    "httpExportPrivateTitle": MessageLookupByLibrary.simpleMessage("包含隐私信息"),
    "httpRequestCleared": MessageLookupByLibrary.simpleMessage("这条请求的记录已清除"),
    "httpRequests": MessageLookupByLibrary.simpleMessage("HTTP 请求"),
    "httpRequestsMissing": MessageLookupByLibrary.simpleMessage(
      "抓包开启前发出或已被清除的请求不在列表中。",
    ),
    "httpsDecryption": MessageLookupByLibrary.simpleMessage("HTTPS 解密"),
    "hue": MessageLookupByLibrary.simpleMessage("色相"),
    "icon": MessageLookupByLibrary.simpleMessage("图标"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("图标记录"),
    "iconSets": MessageLookupByLibrary.simpleMessage("图标集"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "暂无图标集，可在「自定义配置资源 → 图标集」中添加",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("图标样式"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("色块"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("隐藏"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("纯图标"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("图标链接"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage("忽略电池优化"),
    "import": MessageLookupByLibrary.simpleMessage("导入"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage("此文件不是可导入的配置"),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "导入会替换此配置现有的策略组、规则和设置",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("通过文件导入"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("从链接导入"),
    "importUrl": MessageLookupByLibrary.simpleMessage("通过URL导入"),
    "inProgress": MessageLookupByLibrary.simpleMessage("进行中"),
    "inbound": MessageLookupByLibrary.simpleMessage("入站"),
    "includeInterface": MessageLookupByLibrary.simpleMessage("包含网卡"),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "只有从包含网卡进入的流量经过虚拟网卡，设置后排除网卡不再生效。",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("包含用户 ID"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("长期有效"),
    "init": MessageLookupByLibrary.simpleMessage("初始化"),
    "initFailed": MessageLookupByLibrary.simpleMessage("启动失败"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "Flash 启动时出错，无法继续运行。可以复制错误详情用于反馈；如果问题反复出现，清除数据后通常可以重新启动。",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("发起方"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("发起"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage("输入策略组名称"),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage("输入规则内容"),
    "installCertificate": MessageLookupByLibrary.simpleMessage("安装到系统"),
    "installCertificateSuccess": MessageLookupByLibrary.simpleMessage("证书已安装"),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "读取应用列表权限已被拒绝，无法获取已安装的应用。请前往系统设置手动开启。",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "当前系统在授权前不会提供已安装的应用列表，授权后即可配置分应用代理。",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "需要读取应用列表权限",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("已安装字体"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("智能选择"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("网卡名称"),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage("出站网卡"),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("清空"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("自定义"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage("跟随配置"),
    "internet": MessageLookupByLibrary.simpleMessage("互联网"),
    "interval": MessageLookupByLibrary.simpleMessage("间隔"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("内网 IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage("无效备份文件"),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "请输入 CIDR 格式的 IP 段，如 192.168.0.0/16",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "DSCP 标记不能超过 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage("请输入域名或 IP 地址"),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage("不是有效的图标集"),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage("不是有效的订阅链接或代理分享链接"),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "请输入地址和端口，如 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "仅支持 tcp 或 udp",
    ),
    "invalidOfCount": m40,
    "invalidPolicy": m41,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "请输入端口或范围，如 443 或 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "该二维码不包含配置文件链接",
    ),
    "invalidProxy": m42,
    "invalidProxyProvider": m43,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "请输入数字或范围，如 80 或 8000-9000，多个用 / 分隔",
    ),
    "invalidRuleSet": m44,
    "invalidSubRule": m45,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP 地址"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("滥用记录"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("代理"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("命中标记"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("组织"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage("类型查询失败"),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("优"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("等级"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("普通"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("重新查询"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("风险"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("质量"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("采用来源"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("各来源"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage("出站 IP 不一致"),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("无法判定类型"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("限流"),
    "ipType": MessageLookupByLibrary.simpleMessage("类型"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("商业"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("机房"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("移动网络"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("住宅"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("类型未知"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP 版本"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage("开启 IPv6 后才会接收 IPv6 流量。"),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6超时（毫秒）"),
    "itemsCount": m46,
    "ja": MessageLookupByLibrary.simpleMessage("日语"),
    "justNow": MessageLookupByLibrary.simpleMessage("刚刚"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage("TCP 保持活动空闲时间"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage("TCP保持活动间隔"),
    "key": MessageLookupByLibrary.simpleMessage("键"),
    "ko": MessageLookupByLibrary.simpleMessage("韩语"),
    "label": MessageLookupByLibrary.simpleMessage("标签"),
    "language": MessageLookupByLibrary.simpleMessage("语言"),
    "large": MessageLookupByLibrary.simpleMessage("大"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("上次更新"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage("启动未完成"),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "应用上次在启动过程中意外退出。已跳过本次自动配置，你可以手动启动重试。",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("布局"),
    "light": MessageLookupByLibrary.simpleMessage("浅色"),
    "lineIssueTip": m47,
    "lineWrap": MessageLookupByLibrary.simpleMessage("自动换行"),
    "link": MessageLookupByLibrary.simpleMessage("链接"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("液态玻璃"),
    "list": MessageLookupByLibrary.simpleMessage("列表"),
    "listen": MessageLookupByLibrary.simpleMessage("监听"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage("监听路由标记"),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "监听路由标记仅在 Linux 生效。",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage("实时连接"),
    "loading": MessageLookupByLibrary.simpleMessage("加载中…"),
    "local": MessageLookupByLibrary.simpleMessage("本地"),
    "localImage": MessageLookupByLibrary.simpleMessage("本地图片"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "本地网络权限被拒绝：已改用 gvisor 栈，局域网无法访问。",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("本地代理"),
    "locationPermission": MessageLookupByLibrary.simpleMessage("位置权限"),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "位置权限已被拒绝，无法获取当前 Wi-Fi 名称。请前往系统设置手动开启位置权限。",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "根据系统要求，获取Wi-Fi名称需要您授予位置权限。Android 上请选择“始终允许”，否则应用在后台时无法获取 Wi-Fi 名称。",
    ),
    "locationPermissionGuide": m48,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "需要位置权限",
    ),
    "log": MessageLookupByLibrary.simpleMessage("日志"),
    "logLevel": MessageLookupByLibrary.simpleMessage("日志等级"),
    "logcat": MessageLookupByLibrary.simpleMessage("日志捕获"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage("关闭日志捕获会隐藏日志入口。"),
    "logs": MessageLookupByLibrary.simpleMessage("日志"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage("日志与诊断"),
    "logsTest": MessageLookupByLibrary.simpleMessage("日志测试"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP 回环解锁"),
    "loose": MessageLookupByLibrary.simpleMessage("宽松"),
    "mapLocal": MessageLookupByLibrary.simpleMessage("本地映射"),
    "matchCase": MessageLookupByLibrary.simpleMessage("区分大小写"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("匹配来源IP"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchedRules": MessageLookupByLibrary.simpleMessage("命中的规则"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("最大失败次数"),
    "maxLengthTip": m49,
    "maximize": MessageLookupByLibrary.simpleMessage("最大化"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage("常驻内存"),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("应用及共享"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("堆内存空闲"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("堆内存使用中"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage("内核未运行"),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage("运行时开销"),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("协程栈"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "基于进程常驻内存估算，可能与系统显示的数值不同。",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "内核与应用运行在同一进程，内核部分按运行时统计估算，其余计入应用及共享内存。",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("内存信息"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage("应用与内核占用的内存"),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("内存已释放"),
    "memoryReleasedSize": m50,
    "messageTest": MessageLookupByLibrary.simpleMessage("消息测试"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("这是一条消息。"),
    "method": MessageLookupByLibrary.simpleMessage("方法"),
    "minimize": MessageLookupByLibrary.simpleMessage("最小化"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("退出时最小化"),
    "minutes": MessageLookupByLibrary.simpleMessage("分钟"),
    "minutesAgo": m51,
    "minutesAgoShort": m52,
    "mitm": MessageLookupByLibrary.simpleMessage("MITM"),
    "mitmAddLocalFile": MessageLookupByLibrary.simpleMessage("添加本地文件"),
    "mitmAddMapLocalRule": MessageLookupByLibrary.simpleMessage("添加本地映射规则"),
    "mitmAddRejectRule": MessageLookupByLibrary.simpleMessage("添加拒绝规则"),
    "mitmAttachments": MessageLookupByLibrary.simpleMessage("附件"),
    "mitmAttachmentsDesc": MessageLookupByLibrary.simpleMessage(
      "行内按文件名引用附件，如 script-path=a.js。",
    ),
    "mitmCertificateAndroidReadyTip": MessageLookupByLibrary.simpleMessage(
      "只有信任用户证书的应用（多为浏览器）会被解密。",
    ),
    "mitmCertificateExportTip": MessageLookupByLibrary.simpleMessage(
      "导出后在要解密的设备上信任此证书。",
    ),
    "mitmCertificateLinuxTip": MessageLookupByLibrary.simpleMessage(
      "Flatpak 版浏览器需要手动导入导出的证书。",
    ),
    "mitmCertificateSavedTip": m53,
    "mitmCertutilMissing": m54,
    "mitmClientRefusedCertificate": MessageLookupByLibrary.simpleMessage(
      "客户端拒绝了证书。请安装证书；如果应用固定了证书，请排除此主机。",
    ),
    "mitmDecryptHost": MessageLookupByLibrary.simpleMessage("解密此主机"),
    "mitmDecryptHostTip": m55,
    "mitmEnableTip": MessageLookupByLibrary.simpleMessage(
      "开启后，Flash 能读取发往被解密主机的全部内容，包括 Cookie 和密码。请只为需要改写的主机开启。",
    ),
    "mitmExcludeHost": MessageLookupByLibrary.simpleMessage("排除解密"),
    "mitmExcludeHostTip": m56,
    "mitmFileTooLarge": m57,
    "mitmHostnameDesc": MessageLookupByLibrary.simpleMessage(
      "以 - 开头表示排除，第一条匹配的生效。",
    ),
    "mitmIgnoredLines": MessageLookupByLibrary.simpleMessage("忽略的行"),
    "mitmInstallSystemCaTip": MessageLookupByLibrary.simpleMessage(
      "检测到 root，证书将以 Magisk、KernelSU 或 APatch 模块“FlClash MITM CA”加入系统信任的根证书。之后本机所有应用都会信任它，持有其私钥的人可以解密本机的 HTTPS 流量。如需撤销，可重新生成证书，或在 root 管理器中移除该模块并重启。若拒绝 root 授权，将改为安装用户证书。",
    ),
    "mitmInstallUserCaTip": MessageLookupByLibrary.simpleMessage(
      "未检测到 root，证书只能安装为用户证书。只有信任用户证书的应用（多为浏览器）会被解密，其他应用访问列出的主机会失败，请不要列出它们的主机。Android 11 起需在系统设置中手动完成安装。",
    ),
    "mitmMissingStores": m58,
    "mitmModule": MessageLookupByLibrary.simpleMessage("模块"),
    "mitmModuleInvalid": MessageLookupByLibrary.simpleMessage(
      "这不是 Surge 模块、Loon 插件、Quantumult X 片段或 Stash 覆写",
    ),
    "mitmModuleRulesDesc": MessageLookupByLibrary.simpleMessage(
      "分流规则排在配置自身的规则之前。",
    ),
    "mitmModuleScriptsChanged": m59,
    "mitmModuleSystemTip": m60,
    "mitmModules": MessageLookupByLibrary.simpleMessage("模块"),
    "mitmNewModule": MessageLookupByLibrary.simpleMessage("新建模块"),
    "mitmOldCertificateLeftTip": m61,
    "mitmOldSystemCertificateLeftTip": m62,
    "mitmRemoveOldCertificateTip": m63,
    "mitmRootPendingReboot": MessageLookupByLibrary.simpleMessage(
      "证书将在重启手机后生效。",
    ),
    "mitmRootUntilReboot": MessageLookupByLibrary.simpleMessage(
      "未找到可保留证书的 Magisk、KernelSU 或 APatch，重启手机后需要重新安装。",
    ),
    "mitmRoutingRules": MessageLookupByLibrary.simpleMessage("分流规则"),
    "mitmRuleCopiedForStash": MessageLookupByLibrary.simpleMessage(
      "这个模块是 Stash 覆写，规则已复制，请手动添加。",
    ),
    "mitmRunScript": MessageLookupByLibrary.simpleMessage("立即运行"),
    "mitmScriptNoOutput": MessageLookupByLibrary.simpleMessage("脚本已运行完毕，没有输出"),
    "mitmScriptRisk": MessageLookupByLibrary.simpleMessage(
      "它的脚本能读取并修改所匹配主机的流量，包括 Cookie 和令牌，还能自行发送请求。只在信任其来源时开启。",
    ),
    "mitmScriptRiskTitle": MessageLookupByLibrary.simpleMessage("运行此模块的脚本？"),
    "mitmSkipConditional": MessageLookupByLibrary.simpleMessage("不支持条件重写"),
    "mitmSkipDisabled": MessageLookupByLibrary.simpleMessage("已被参数关闭"),
    "mitmSkipEvent": MessageLookupByLibrary.simpleMessage("不支持此事件"),
    "mitmSkipJq": MessageLookupByLibrary.simpleMessage("不支持 jq 重写"),
    "mitmSkipJsonBody": MessageLookupByLibrary.simpleMessage("不支持 JSON 正文重写"),
    "mitmSkipNotDownloaded": MessageLookupByLibrary.simpleMessage("其文件尚未下载"),
    "mitmSkipPolicy": MessageLookupByLibrary.simpleMessage(
      "只支持 DIRECT 和 REJECT 策略",
    ),
    "mitmSkipRawHeader": MessageLookupByLibrary.simpleMessage(
      "不支持把全部标头作为一段文本改写",
    ),
    "mitmSkipRelativeData": MessageLookupByLibrary.simpleMessage(
      "此行引用的文件不是附件，请改用 URL 或添加为附件",
    ),
    "mitmSkipRule": MessageLookupByLibrary.simpleMessage("不支持此规则类型"),
    "mitmSkipScriptType": MessageLookupByLibrary.simpleMessage("不支持此类脚本"),
    "mitmSkipSection": m64,
    "mitmSkipSetting": MessageLookupByLibrary.simpleMessage("不支持此设置"),
    "mitmSkipUnreadable": MessageLookupByLibrary.simpleMessage("无法识别此行"),
    "mitmSystemStoreFailed": MessageLookupByLibrary.simpleMessage(
      "无法把证书加入系统信任的根证书",
    ),
    "mitmTrustChecking": MessageLookupByLibrary.simpleMessage("正在检查…"),
    "mitmTrustNotInstalled": MessageLookupByLibrary.simpleMessage("未安装"),
    "mitmTrustReady": MessageLookupByLibrary.simpleMessage("已信任"),
    "mitmTrustUntrusted": MessageLookupByLibrary.simpleMessage("未完全信任"),
    "mixedPort": MessageLookupByLibrary.simpleMessage("混合端口"),
    "mixedPortUnavailable": m65,
    "mixedPortUnavailableProxyUnchanged": m66,
    "mode": MessageLookupByLibrary.simpleMessage("模式"),
    "monochromeIcon": MessageLookupByLibrary.simpleMessage("单色图标"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("单色"),
    "monthsAgo": m67,
    "monthsAgoShort": m68,
    "more": MessageLookupByLibrary.simpleMessage("更多"),
    "mountAlsoMounts": m69,
    "mountApplyBlocked": MessageLookupByLibrary.simpleMessage(
      "未能应用挂载。Flash 当前会拒绝所有经它转发的连接。请先重新读取状态，确认结果后再解除挂载或重新应用配置。",
    ),
    "mountApplyFailed": MessageLookupByLibrary.simpleMessage(
      "挂载已保存，但未能应用到当前运行配置。",
    ),
    "mountApplyKept": MessageLookupByLibrary.simpleMessage(
      "未能应用挂载，仍使用上次确认的运行配置。",
    ),
    "mountApplying": MessageLookupByLibrary.simpleMessage("挂载已保存，正在应用…"),
    "mountAutoDesc": MessageLookupByLibrary.simpleMessage(
      "以下分组会按原有设置接收和筛选订阅节点。如需加入其他普通分组，可在下方选择。",
    ),
    "mountAutoSubtitle": MessageLookupByLibrary.simpleMessage("按原分组设置接收节点"),
    "mountBaseDirect": MessageLookupByLibrary.simpleMessage(
      "没有可选节点时，此组会按原配置直连。",
    ),
    "mountBaseFallback": m70,
    "mountBlockDesc": MessageLookupByLibrary.simpleMessage(
      "此组没有可选节点时会拦截相关连接，不会自动转为直连。",
    ),
    "mountBlockTag": MessageLookupByLibrary.simpleMessage("空组时拦截"),
    "mountCardFailed": m71,
    "mountCardUnreadable": MessageLookupByLibrary.simpleMessage("挂载状态读取失败"),
    "mountChooseSources": MessageLookupByLibrary.simpleMessage("选择订阅"),
    "mountDeleteSourceBlocked": MessageLookupByLibrary.simpleMessage(
      "此订阅或受影响配置仍有待确认的操作，请先重新读取状态，确认后再删除。",
    ),
    "mountDeleteSourceBody": m72,
    "mountDeleteSourceConfirm": MessageLookupByLibrary.simpleMessage("删除并解除挂载"),
    "mountDeleteSourceDone": MessageLookupByLibrary.simpleMessage("订阅已删除并解除挂载"),
    "mountDeleteSourceProgress": MessageLookupByLibrary.simpleMessage(
      "正在删除并解除挂载…",
    ),
    "mountDeleteSourceTitle": MessageLookupByLibrary.simpleMessage(
      "删除订阅并解除挂载？",
    ),
    "mountDeleteSourceUnknown": MessageLookupByLibrary.simpleMessage(
      "订阅删除与解除挂载的结果待确认，请先重新读取状态，确认前请勿重复删除或重新挂载。",
    ),
    "mountDescription": MessageLookupByLibrary.simpleMessage(
      "选择已导入的机场订阅，只将节点加入这份配置。规则、DNS 和原有分组结构保留，Tailscale 专用分流不变。原文件不会改写。",
    ),
    "mountEmptyDesc": MessageLookupByLibrary.simpleMessage(
      "先通过链接导入机场订阅，再选择要加入此配置的节点来源。",
    ),
    "mountEmptyTitle": MessageLookupByLibrary.simpleMessage("暂无可挂载的订阅"),
    "mountEntry": MessageLookupByLibrary.simpleMessage("挂载订阅节点"),
    "mountEntryMenu": MessageLookupByLibrary.simpleMessage("挂载订阅节点…"),
    "mountExtraDesc": MessageLookupByLibrary.simpleMessage(
      "还可以将这些订阅节点加入其他普通代理组。不选择则只按上方分组的原设置收集。此选择对本配置的所有挂载订阅生效。",
    ),
    "mountExtraTitle": MessageLookupByLibrary.simpleMessage("另外加入的分组（可选）"),
    "mountFetchFailed": MessageLookupByLibrary.simpleMessage(
      "暂时无法获取此订阅的节点，请重试。",
    ),
    "mountFilterNotice": MessageLookupByLibrary.simpleMessage(
      "此组原有的筛选和排除条件也会用于挂载节点，不会更改筛选条件。",
    ),
    "mountFormatHelp": MessageLookupByLibrary.simpleMessage(
      "可挂载已导入的远程 Clash/mihomo 订阅，以及 Flash 现有导入功能成功转换的远程订阅。只引入节点，不引入订阅中的规则或 DNS。",
    ),
    "mountGroupEmpty": m73,
    "mountGroupFiltered": MessageLookupByLibrary.simpleMessage(
      "节点已获取，但所选分组的筛选条件未留下可用选项。请检查分组筛选。",
    ),
    "mountGroupNotSelected": MessageLookupByLibrary.simpleMessage("未选"),
    "mountGroupSelected": MessageLookupByLibrary.simpleMessage("已选"),
    "mountGroupsChanged": MessageLookupByLibrary.simpleMessage(
      "目标分组已变化，请重新读取并确认后保存。",
    ),
    "mountGroupsExcluded": m74,
    "mountGroupsExcludedNames": m75,
    "mountGroupsFailed": MessageLookupByLibrary.simpleMessage(
      "暂时无法读取此配置的分组，请重新读取。",
    ),
    "mountGroupsTitle": MessageLookupByLibrary.simpleMessage("节点加入哪些分组"),
    "mountHintCollectsAll": MessageLookupByLibrary.simpleMessage("自动收集节点"),
    "mountHintCollectsProviders": MessageLookupByLibrary.simpleMessage(
      "自动收集订阅节点",
    ),
    "mountHintFiltered": MessageLookupByLibrary.simpleMessage("自动收集 · 按组筛选"),
    "mountImport": MessageLookupByLibrary.simpleMessage("导入订阅"),
    "mountImportHint": MessageLookupByLibrary.simpleMessage(
      "导入后返回此处选择订阅，不会切换你正在使用的配置。",
    ),
    "mountLastUpdated": m76,
    "mountListFailed": MessageLookupByLibrary.simpleMessage("订阅列表加载失败，请重试。"),
    "mountMountedTag": MessageLookupByLibrary.simpleMessage("已挂载"),
    "mountNameSeparator": MessageLookupByLibrary.simpleMessage("、"),
    "mountNoGroupDesc": MessageLookupByLibrary.simpleMessage(
      "不会自动新建分组或更改分流规则。",
    ),
    "mountNoGroupIsolatedDesc": MessageLookupByLibrary.simpleMessage(
      "现有分组均未通过挂载隔离检查。不会自动新建分组、改成直连或改写原配置文件。",
    ),
    "mountNoGroupIsolatedTitle": MessageLookupByLibrary.simpleMessage(
      "当前分组暂不支持挂载",
    ),
    "mountNoGroupTitle": MessageLookupByLibrary.simpleMessage(
      "此配置没有可接收订阅节点的普通代理组，暂时无法完成挂载。",
    ),
    "mountNodeCount": m77,
    "mountNodesRead": m78,
    "mountNodesReadAt": m79,
    "mountNodesUpdated": MessageLookupByLibrary.simpleMessage("节点已更新"),
    "mountNotFetched": MessageLookupByLibrary.simpleMessage("尚未获取节点"),
    "mountNotMounted": MessageLookupByLibrary.simpleMessage("未挂载"),
    "mountPickDesc": MessageLookupByLibrary.simpleMessage(
      "此配置没有自动接收订阅节点的分组。请选择要加入这些节点的普通代理组，只更新运行配置，不改写原文件。",
    ),
    "mountPickRequired": MessageLookupByLibrary.simpleMessage("请至少选择一个目标分组。"),
    "mountPickTitle": MessageLookupByLibrary.simpleMessage("选择目标分组"),
    "mountPillFailedSemantics": MessageLookupByLibrary.simpleMessage("有订阅更新失败"),
    "mountPillSemantics": m80,
    "mountProviderUpdateRefused": m81,
    "mountProviderUpdateRefusedUnconfirmed": m82,
    "mountReadAgain": MessageLookupByLibrary.simpleMessage("重新读取"),
    "mountReadStatus": MessageLookupByLibrary.simpleMessage("重新读取状态"),
    "mountRunningBlocked": MessageLookupByLibrary.simpleMessage(
      "Flash 当前会拒绝所有经它转发的连接，请重新读取状态。",
    ),
    "mountRunningKept": MessageLookupByLibrary.simpleMessage("仍使用上次确认的运行配置。"),
    "mountSameName": MessageLookupByLibrary.simpleMessage(
      "不同来源有同名节点时，会在名称后加上订阅名以区分。名称变化可能影响完整匹配或按结尾筛选，请核对分组结果。",
    ),
    "mountSave": MessageLookupByLibrary.simpleMessage("保存挂载"),
    "mountSavedUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "挂载已保存，尚未确认生效。",
    ),
    "mountSaving": MessageLookupByLibrary.simpleMessage("正在保存挂载…"),
    "mountSelectionLost": MessageLookupByLibrary.simpleMessage(
      "原来选择的节点已不在此订阅中，请重新选择。",
    ),
    "mountSourceEmpty": MessageLookupByLibrary.simpleMessage("订阅已更新，目前没有节点。"),
    "mountSourceGone": MessageLookupByLibrary.simpleMessage(
      "原订阅已不可用，请重新选择节点来源。",
    ),
    "mountSourceIsolatedOnly": MessageLookupByLibrary.simpleMessage(
      "此订阅的节点均因挂载隔离要求被排除，暂不支持挂载；原设置未更改。",
    ),
    "mountSourceNoNodeList": MessageLookupByLibrary.simpleMessage(
      "此订阅未提供可挂载的节点列表，请检查订阅格式。",
    ),
    "mountSourceRelayOnly": MessageLookupByLibrary.simpleMessage(
      "此订阅的节点均需经 Tailscale 中转，暂不支持挂载。原中转设置未更改。",
    ),
    "mountSourceTailscaleOnly": MessageLookupByLibrary.simpleMessage(
      "此订阅仅包含 Tailscale 节点，暂不支持挂载。",
    ),
    "mountTailscaleExcluded": MessageLookupByLibrary.simpleMessage(
      "已从普通挂载中排除 Tailscale 节点。",
    ),
    "mountTarget": m83,
    "mountTypeFallback": MessageLookupByLibrary.simpleMessage("故障切换"),
    "mountTypeFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "此组会发起连通探测，并按原配置在节点不可用时自动切换。",
    ),
    "mountTypeLoadBalance": MessageLookupByLibrary.simpleMessage("负载均衡"),
    "mountTypeLoadBalanceDesc": MessageLookupByLibrary.simpleMessage(
      "此组会按原配置探测节点，并将连接分配到不同节点。",
    ),
    "mountTypeSelect": MessageLookupByLibrary.simpleMessage("手动选择"),
    "mountTypeSelectDesc": MessageLookupByLibrary.simpleMessage("由你选择使用的节点。"),
    "mountTypeUnknownDesc": MessageLookupByLibrary.simpleMessage("行为沿用原分组设置"),
    "mountTypeUrlTest": MessageLookupByLibrary.simpleMessage("延迟优选"),
    "mountTypeUrlTestDesc": MessageLookupByLibrary.simpleMessage(
      "此组会发起连通探测，并按检测结果自动选择节点。",
    ),
    "mountUnchanged": MessageLookupByLibrary.simpleMessage("挂载未更改，请重试。"),
    "mountUnknown": MessageLookupByLibrary.simpleMessage(
      "挂载结果待确认，请先重新读取状态，确认前请勿重复保存或解除挂载。",
    ),
    "mountUnmount": MessageLookupByLibrary.simpleMessage("解除挂载"),
    "mountUnmountBody": m84,
    "mountUnmountManyBody": m85,
    "mountUnmountManyTitle": MessageLookupByLibrary.simpleMessage("解除这些订阅的挂载？"),
    "mountUnmountTitle": MessageLookupByLibrary.simpleMessage("解除此订阅的挂载？"),
    "mountUnmountUnknown": MessageLookupByLibrary.simpleMessage(
      "解除挂载结果待确认，请先重新读取状态。",
    ),
    "mountUnmounted": MessageLookupByLibrary.simpleMessage("已解除挂载"),
    "mountUnmounting": MessageLookupByLibrary.simpleMessage("正在解除挂载…"),
    "mountUnsupportedExcluded": m86,
    "mountUpdateFailedInUse": MessageLookupByLibrary.simpleMessage(
      "更新失败，继续使用上次成功获取的节点。",
    ),
    "mountUpdateFailedKept": MessageLookupByLibrary.simpleMessage(
      "更新失败，已保留上次成功获取的节点，尚未确认当前是否生效。",
    ),
    "mountUpdateFailedKeptBlocked": MessageLookupByLibrary.simpleMessage(
      "更新失败，已保留上次成功获取的节点。",
    ),
    "mountUpdateNodes": MessageLookupByLibrary.simpleMessage("更新节点"),
    "mountUpdateNodesOf": m87,
    "mountUpdateReadEmptyNotApplied": MessageLookupByLibrary.simpleMessage(
      "订阅已读取，目前没有节点。新结果尚未应用。",
    ),
    "mountUpdateReadNotAppliedBlocked": MessageLookupByLibrary.simpleMessage(
      "新节点已读取，但尚未应用。Flash 当前会拒绝所有经它转发的连接，请重新读取状态。",
    ),
    "mountUpdateReadNotAppliedKept": MessageLookupByLibrary.simpleMessage(
      "新节点已读取，但尚未应用。仍使用上次确认的运行配置。",
    ),
    "mountUpdateTitle": MessageLookupByLibrary.simpleMessage("更新订阅挂载？"),
    "mountUpdated": MessageLookupByLibrary.simpleMessage("订阅节点挂载已更新"),
    "mountUpdatingNodes": MessageLookupByLibrary.simpleMessage("正在更新节点…"),
    "mountedCount": m88,
    "name": MessageLookupByLibrary.simpleMessage("名称"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "默认使用的 DNS 服务器，如 223.5.5.5、tls://1.1.1.1、https://dns.google/dns-query。",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "匹配的域名改用此处指定的 DNS 服务器，优先于 Nameserver 和 Fallback。",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("底栏"),
    "network": MessageLookupByLibrary.simpleMessage("网络"),
    "networkAccessDeniedError": m89,
    "networkBadResponseError": m90,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage("请求已取消"),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "无法连接到服务器，请检查网络连接或代理设置",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "无法解析服务器地址，请确认链接正确且 DNS 可用",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("网络名称"),
    "networkNotFoundError": m91,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "请求过于频繁（HTTP 429），请稍后再试",
    ),
    "networkRequestFailed": m92,
    "networkSecret": MessageLookupByLibrary.simpleMessage("网络密码"),
    "networkServerError": m93,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("网络速度"),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("网络接管"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "请求超时，请检查网络或代理后重试",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "安全连接失败，服务器证书可能无效，或连接被拦截",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("网络类型"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("下一个匹配"),
    "no": MessageLookupByLibrary.simpleMessage("否"),
    "noData": MessageLookupByLibrary.simpleMessage("暂无数据"),
    "noInfo": MessageLookupByLibrary.simpleMessage("暂无信息"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage("不再提示"),
    "noNetwork": MessageLookupByLibrary.simpleMessage("无网络"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("无网络应用"),
    "noResolve": MessageLookupByLibrary.simpleMessage("不解析IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage("不解析主机名"),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("没有匹配的结果"),
    "nodes": MessageLookupByLibrary.simpleMessage("节点"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage("该外部资源不是文本文件"),
    "none": MessageLookupByLibrary.simpleMessage("无"),
    "notRunning": MessageLookupByLibrary.simpleMessage("未运行"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage("当前代理组无法选中"),
    "ntpInterval": MessageLookupByLibrary.simpleMessage("同步间隔（分钟）"),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage("添加一个配置文件后即可开始使用"),
    "nullTip": m94,
    "numberRangeTip": m95,
    "numberTip": m96,
    "obfs": MessageLookupByLibrary.simpleMessage("混淆"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("混淆主机"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("混淆模式"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("混淆参数"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("混淆密码"),
    "onDemand": MessageLookupByLibrary.simpleMessage("按需运行"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage("仅统计代理流量"),
    "openSettings": MessageLookupByLibrary.simpleMessage("打开设置"),
    "optional": MessageLookupByLibrary.simpleMessage("可选"),
    "options": MessageLookupByLibrary.simpleMessage("选项"),
    "originalUrl": MessageLookupByLibrary.simpleMessage("原 URL"),
    "other": MessageLookupByLibrary.simpleMessage("其他"),
    "otherContributors": MessageLookupByLibrary.simpleMessage("其他贡献者"),
    "outbound": MessageLookupByLibrary.simpleMessage("出站"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("出口"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("出站 IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("出站模式"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage("覆盖目标地址"),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("覆写项"),
    "overview": MessageLookupByLibrary.simpleMessage("概览"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("解析纯IP"),
    "password": MessageLookupByLibrary.simpleMessage("密码"),
    "paste": MessageLookupByLibrary.simpleMessage("粘贴"),
    "peers": MessageLookupByLibrary.simpleMessage("初始节点"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("从相册选择"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("窗口置顶"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("请绑定WebDAV"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage("请输入脚本名称"),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "请上传有效的二维码",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("插件"),
    "pluginCipher": MessageLookupByLibrary.simpleMessage("插件加密方式"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("插件主机"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("插件模式"),
    "pluginPassword": MessageLookupByLibrary.simpleMessage("插件密码"),
    "pluginPath": MessageLookupByLibrary.simpleMessage("插件路径"),
    "pluginUsername": MessageLookupByLibrary.simpleMessage("插件用户名"),
    "port": MessageLookupByLibrary.simpleMessage("端口"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage("请输入不同的端口"),
    "portHopping": MessageLookupByLibrary.simpleMessage("端口跳跃"),
    "portTip": m97,
    "portValue": m98,
    "ports": MessageLookupByLibrary.simpleMessage("端口"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("预共享密钥"),
    "preferred": MessageLookupByLibrary.simpleMessage("首选"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("前置条件"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage("请按下组合键"),
    "preview": MessageLookupByLibrary.simpleMessage("预览"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("上一个匹配"),
    "privateKey": MessageLookupByLibrary.simpleMessage("私钥"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage("私钥密码"),
    "process": MessageLookupByLibrary.simpleMessage("进程"),
    "profile": MessageLookupByLibrary.simpleMessage("配置"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("请输入有效间隔时间格式"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("请输入自动更新间隔时间"),
    "profileDaysLeft": m99,
    "profileExpiresIn": m100,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "配置文件已经修改，是否关闭自动更新？",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入配置名称",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "仅作用于当前配置，未添加的项使用默认值。",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "仅作用于当前配置，并优先于网络设置中的虚拟网卡覆写项。",
    ),
    "profileUpdatedAt": m101,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入有效配置URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "请输入配置URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("配置"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("配置排序"),
    "project": MessageLookupByLibrary.simpleMessage("FlClash 上游项目"),
    "protocol": MessageLookupByLibrary.simpleMessage("协议"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("协议参数"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("协议版本"),
    "providerInUse": m102,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage("仅支持远程资源"),
    "providers": MessageLookupByLibrary.simpleMessage("外部资源"),
    "proxies": MessageLookupByLibrary.simpleMessage("代理"),
    "proxiesCount": m103,
    "proxiesProfileLabel": m104,
    "proxiesRemovedTip": m105,
    "proxiesReplacedTip": m106,
    "proxyChains": MessageLookupByLibrary.simpleMessage("代理链"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("策略组"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage("策略组为空"),
    "proxyGroupInUse": m107,
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "启动后在这里显示策略组",
    ),
    "proxyGroupsCount": m108,
    "proxyProviders": MessageLookupByLibrary.simpleMessage("代理集"),
    "proxyServerNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "仅用于解析代理服务器的域名。",
    ),
    "proxyServerNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "匹配的代理服务器域名改用此处指定的 DNS 服务器，优先于 Proxy Server Nameserver。",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("代理类型"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("修剪缓存"),
    "publicKey": MessageLookupByLibrary.simpleMessage("公钥"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("纯黑"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("纯黑模式"),
    "qrcode": MessageLookupByLibrary.simpleMessage("二维码"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage("扫描二维码获取配置文件"),
    "qrcodeTooLongTip": MessageLookupByLibrary.simpleMessage(
      "链接过长，无法生成二维码，请改用“复制链接”。",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("快捷操作"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("快速编辑"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("最近请求"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("推荐"),
    "recordType": MessageLookupByLibrary.simpleMessage("记录类型"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir端口"),
    "redo": MessageLookupByLibrary.simpleMessage("重做"),
    "regenerateCertificate": MessageLookupByLibrary.simpleMessage("重新生成证书"),
    "regenerateCertificateTip": MessageLookupByLibrary.simpleMessage(
      "新证书会替换当前证书，Flash 会尽量把当前证书从本机信任的根证书中移除。信任当前证书的其他设备都需要安装新证书。",
    ),
    "regex": MessageLookupByLibrary.simpleMessage("正则"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("释放内存"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage("释放内存失败"),
    "remote": MessageLookupByLibrary.simpleMessage("远程"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("远程目标"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage("远程 DNS 解析"),
    "remove": MessageLookupByLibrary.simpleMessage("移除"),
    "rename": MessageLookupByLibrary.simpleMessage("重命名"),
    "replace": MessageLookupByLibrary.simpleMessage("替换"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("全部替换"),
    "request": MessageLookupByLibrary.simpleMessage("请求"),
    "requestBody": MessageLookupByLibrary.simpleMessage("请求体"),
    "requestHeaders": MessageLookupByLibrary.simpleMessage("请求头"),
    "requests": MessageLookupByLibrary.simpleMessage("请求"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage("请求与更新"),
    "required": MessageLookupByLibrary.simpleMessage("必填"),
    "reset": MessageLookupByLibrary.simpleMessage("重置"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "当前页面存在更改，确定重置吗？",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("确定要重置吗？"),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage("自动更新间隔"),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "自动更新间隔必须大于0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("资源"),
    "respectRules": MessageLookupByLibrary.simpleMessage("遵守规则"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "遵守规则使 DNS 连接遵守规则，需配置 Proxy Server Nameserver。",
    ),
    "response": MessageLookupByLibrary.simpleMessage("响应"),
    "responseBody": MessageLookupByLibrary.simpleMessage("响应体"),
    "responseCode": MessageLookupByLibrary.simpleMessage("响应码"),
    "responseHeaders": MessageLookupByLibrary.simpleMessage("响应头"),
    "restart": MessageLookupByLibrary.simpleMessage("重启"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage("您确定要重启核心吗？"),
    "restore": MessageLookupByLibrary.simpleMessage("恢复"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("恢复所有数据"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage("仅恢复配置文件"),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("恢复策略"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage("兼容"),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("覆盖"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("恢复成功"),
    "result": MessageLookupByLibrary.simpleMessage("结果"),
    "retry": MessageLookupByLibrary.simpleMessage("重试"),
    "root": MessageLookupByLibrary.simpleMessage("Root"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("路由地址"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage("排除路由地址"),
    "routingMark": MessageLookupByLibrary.simpleMessage("路由标记"),
    "ru": MessageLookupByLibrary.simpleMessage("俄语"),
    "rule": MessageLookupByLibrary.simpleMessage("规则"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage("逻辑规则 AND"),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage("匹配完整域名"),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "匹配域名关键字",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用域名正则表达式匹配",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "匹配域名后缀",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "通配符匹配，仅支持*和?通配符",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "匹配DSCP标记（仅限 tproxy udp 入站）",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage("匹配请求目标端口范围"),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage("匹配 IP 所属国家代码"),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "匹配 Geosite 内的域名",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage("匹配入站名称"),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage("匹配入站端口"),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage("匹配入站类型"),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "匹配入站用户名，支持使用 / 分隔多个用户名",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage("匹配 IP 所属 ASN"),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "匹配 IP 地址范围，IP-CIDR6 只是一个别名",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage("匹配 IP 地址范围"),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "匹配 IP 后缀范围",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage("匹配所有请求，无需条件"),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage("匹配TCP或者UDP"),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage("逻辑规则 NOT"),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("逻辑规则 OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程匹配，在Android平台可以匹配包名",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程名称正则表达式匹配，在Android平台可以匹配包名",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程名称通配符匹配，仅支持*和?通配符",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "使用完整进程路径匹配",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程路径正则表达式匹配",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "使用进程路径通配符匹配，仅支持*和?通配符",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "匹配重匹配名称，多个名称用/分隔",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "引用规则集合，需配置rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 所属国家代码",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 所属 ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 地址范围",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "匹配来源 IP 后缀范围",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage("匹配请求来源端口范围"),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "匹配至子规则，需要注意括号的使用",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "匹配 Linux USER ID",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("规则为空"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "规则必须是 YAML 列表，每项一条规则，例如 - DOMAIN,example.com,DIRECT",
    ),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BT 下载直连",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "屏蔽 DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage("防止代理回环"),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("屏蔽 QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("屏蔽 STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("局域网直连"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple 与 Microsoft 直连",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("规则集"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("规则集"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage("规则集中没有可用的条目"),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage("无法读取该 mrs 文件"),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "规则集同时包含域名和 IP 段，无法判断类型",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("规则目标"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "规则必须以受支持的类型开头，例如 DOMAIN,example.com,DIRECT",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("规则"),
    "rulesCount": m109,
    "runTime": MessageLookupByLibrary.simpleMessage("运行时长"),
    "running": MessageLookupByLibrary.simpleMessage("运行中"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("运行时配置"),
    "safeMode": MessageLookupByLibrary.simpleMessage("安全模式"),
    "safeModeAppTitle": m110,
    "saturation": MessageLookupByLibrary.simpleMessage("饱和度"),
    "save": MessageLookupByLibrary.simpleMessage("保存"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("是否保存更改？"),
    "script": MessageLookupByLibrary.simpleMessage("脚本"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage("脚本模式，使用扩展脚本改写整个配置"),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage("滚动到已选"),
    "search": MessageLookupByLibrary.simpleMessage("搜索"),
    "seconds": MessageLookupByLibrary.simpleMessage("秒"),
    "secondsCount": m111,
    "secretKey": MessageLookupByLibrary.simpleMessage("密钥"),
    "sectionsInEffect": m112,
    "select": MessageLookupByLibrary.simpleMessage("选中"),
    "selectAll": MessageLookupByLibrary.simpleMessage("全选"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage("请选择规则集"),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage("请选择分流策略"),
    "send": MessageLookupByLibrary.simpleMessage("发送"),
    "sendFromPhone": MessageLookupByLibrary.simpleMessage("从手机发送"),
    "sendFromPhoneConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "导入手机发来的链接？",
    ),
    "sendFromPhoneNoNetwork": MessageLookupByLibrary.simpleMessage(
      "这台设备没有连接局域网",
    ),
    "sendFromPhonePageHint": MessageLookupByLibrary.simpleMessage(
      "订阅链接或代理分享链接",
    ),
    "sendFromPhonePageSent": MessageLookupByLibrary.simpleMessage(
      "已发送，请在另一台设备上确认导入。",
    ),
    "sendFromPhonePageTitle": MessageLookupByLibrary.simpleMessage(
      "把链接发送到 Flash",
    ),
    "sendFromPhonePermissionDenied": MessageLookupByLibrary.simpleMessage(
      "从手机接收链接需要「附近的设备」权限，Flash 才能访问局域网。请在应用设置中开启。",
    ),
    "sendFromPhoneTip": MessageLookupByLibrary.simpleMessage(
      "用手机相机扫描二维码，在打开的页面里粘贴链接。两台设备需要连在同一个网络。",
    ),
    "server": MessageLookupByLibrary.simpleMessage("服务器"),
    "serviceAbnormalCount": m113,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("全部可用"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("可用"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("已被封禁"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("全部检测"),
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("即将上线"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage("不允许的 ISP"),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("检测失败"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("管理服务"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage("仅限自制内容"),
    "servicePending": MessageLookupByLibrary.simpleMessage("待检测"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage("访问受限"),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage("显示在仪表盘"),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("服务状态"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("不可用"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage("地区不支持"),
    "settingEntries": MessageLookupByLibrary.simpleMessage("设置项"),
    "settings": MessageLookupByLibrary.simpleMessage("设置"),
    "settingsCount": m114,
    "shareLinkUnreadable": m115,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage("无法从链接中读取代理"),
    "shareQrcodeTip": MessageLookupByLibrary.simpleMessage(
      "在另一台设备上用 Flash 扫码即可导入此配置。",
    ),
    "show": MessageLookupByLibrary.simpleMessage("显示"),
    "showLess": MessageLookupByLibrary.simpleMessage("收起"),
    "showMore": MessageLookupByLibrary.simpleMessage("展开"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "通知栏显示停止按钮",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("显示密码"),
    "sidebar": MessageLookupByLibrary.simpleMessage("侧边栏"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("静默启动"),
    "singleImport": MessageLookupByLibrary.simpleMessage("单条导入"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "这里只能填写一条链接，多条请在列表的快速编辑中填写",
    ),
    "singleValueTip": m116,
    "size": MessageLookupByLibrary.simpleMessage("尺寸"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage("跳过证书验证"),
    "skipDomain": MessageLookupByLibrary.simpleMessage("跳过域名"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage("跳过目标地址"),
    "skipServerCertVerify": MessageLookupByLibrary.simpleMessage("跳过服务器证书验证"),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage("跳过来源地址"),
    "slide": MessageLookupByLibrary.simpleMessage("滑动"),
    "sliders": MessageLookupByLibrary.simpleMessage("滑块"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("协议"),
    "sniffer": MessageLookupByLibrary.simpleMessage("域名嗅探"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks端口"),
    "softStyle": MessageLookupByLibrary.simpleMessage("柔和"),
    "sort": MessageLookupByLibrary.simpleMessage("排序"),
    "source": MessageLookupByLibrary.simpleMessage("来源"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("源IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("特殊代理"),
    "specialRules": MessageLookupByLibrary.simpleMessage("特殊规则"),
    "spectrum": MessageLookupByLibrary.simpleMessage("光谱"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("网速统计"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("分流策略"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage("分流策略不能为空"),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs为空"),
    "stackMode": MessageLookupByLibrary.simpleMessage("栈模式"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("堆栈信息"),
    "standard": MessageLookupByLibrary.simpleMessage("标准"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "标准模式，在配置的基础上附加规则",
    ),
    "start": MessageLookupByLibrary.simpleMessage("启动"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("从零开始"),
    "startVpn": MessageLookupByLibrary.simpleMessage("正在启动VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage("启动与后台"),
    "status": MessageLookupByLibrary.simpleMessage("状态"),
    "statusDesc": MessageLookupByLibrary.simpleMessage("关闭 DNS 后将使用系统 DNS。"),
    "stop": MessageLookupByLibrary.simpleMessage("暂停"),
    "stopUpdateDownloadTip": MessageLookupByLibrary.simpleMessage("要停止下载更新吗？"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("正在停止VPN…"),
    "strategy": MessageLookupByLibrary.simpleMessage("策略"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("严格路由"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "严格路由防止 DNS 等流量绕过虚拟网卡，关闭 IPv6 时会阻断本机的 IPv6 连接。",
    ),
    "style": MessageLookupByLibrary.simpleMessage("风格"),
    "submit": MessageLookupByLibrary.simpleMessage("提交"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage("订阅信息"),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage("输入 sudo 密码"),
    "suspended": MessageLookupByLibrary.simpleMessage("挂起中…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("切换配置"),
    "sync": MessageLookupByLibrary.simpleMessage("同步"),
    "system": MessageLookupByLibrary.simpleMessage("系统"),
    "systemApp": MessageLookupByLibrary.simpleMessage("系统应用"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("系统代理"),
    "tab": MessageLookupByLibrary.simpleMessage("标签页"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("选项卡动画"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage("点击图标重试"),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("点击授权"),
    "target": MessageLookupByLibrary.simpleMessage("目标"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP并发"),
    "testInterval": MessageLookupByLibrary.simpleMessage("测试间隔"),
    "testUrl": MessageLookupByLibrary.simpleMessage("测速链接"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("使用时测试"),
    "textScale": MessageLookupByLibrary.simpleMessage("文本缩放"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage("应用内的文字将以这个大小显示"),
    "theme": MessageLookupByLibrary.simpleMessage("主题"),
    "themeColor": MessageLookupByLibrary.simpleMessage("主题色彩"),
    "themeMode": MessageLookupByLibrary.simpleMessage("主题模式"),
    "tight": MessageLookupByLibrary.simpleMessage("紧凑"),
    "time": MessageLookupByLibrary.simpleMessage("时间"),
    "timeToFirstByte": MessageLookupByLibrary.simpleMessage("首字节耗时"),
    "timeout": MessageLookupByLibrary.simpleMessage("超时"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("氛围"),
    "tip": MessageLookupByLibrary.simpleMessage("提示"),
    "toggle": MessageLookupByLibrary.simpleMessage("切换"),
    "tolerance": MessageLookupByLibrary.simpleMessage("容差"),
    "tools": MessageLookupByLibrary.simpleMessage("工具"),
    "torch": MessageLookupByLibrary.simpleMessage("手电筒"),
    "total": MessageLookupByLibrary.simpleMessage("总计"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("下载总量"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("总流量"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("上传总量"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy端口"),
    "traffic": MessageLookupByLibrary.simpleMessage("流量"),
    "trafficPeak": m117,
    "trafficTotal": m118,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("流量统计"),
    "transport": MessageLookupByLibrary.simpleMessage("传输协议"),
    "transportHeaders": m119,
    "trustCertificate": MessageLookupByLibrary.simpleMessage("信任证书"),
    "tsAcceptRoutes": MessageLookupByLibrary.simpleMessage("接受子网路由"),
    "tsAcceptRoutesTip": MessageLookupByLibrary.simpleMessage(
      "允许此节点使用 Tailscale 网络中已批准的子网路由。是否有流量经过这些路由，仍由现有规则决定；不会自动修改 Flash 的规则。",
    ),
    "tsAccount": MessageLookupByLibrary.simpleMessage("登录账号"),
    "tsAccountMissing": MessageLookupByLibrary.simpleMessage("账号信息未提供"),
    "tsAccountSignedOut": MessageLookupByLibrary.simpleMessage("已退出"),
    "tsAccountsInProfile": MessageLookupByLibrary.simpleMessage(
      "当前配置中的 Tailscale 账号",
    ),
    "tsAddAccount": MessageLookupByLibrary.simpleMessage("添加 Tailscale 账号"),
    "tsAddUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "账号添加结果待确认，请先重新读取状态。",
    ),
    "tsAddedInPanel": MessageLookupByLibrary.simpleMessage("面板添加"),
    "tsAddress": MessageLookupByLibrary.simpleMessage("Tailscale 地址"),
    "tsAddressConflict": MessageLookupByLibrary.simpleMessage("地址冲突"),
    "tsAddressCopied": MessageLookupByLibrary.simpleMessage("地址已复制"),
    "tsAddressMissing": MessageLookupByLibrary.simpleMessage("地址未提供"),
    "tsAfterConnectSelectable": MessageLookupByLibrary.simpleMessage(
      "此节点连接后可更改设置。",
    ),
    "tsAfterLogin": MessageLookupByLibrary.simpleMessage("登录后可查看"),
    "tsAssignBody": MessageLookupByLibrary.simpleMessage(
      "每个目标只能指定一个账号。未指定的目标仍会被拦截，此选择不影响其他目标。指定后不会因账号离线而自动改用其他账号。",
    ),
    "tsAssignTitle": MessageLookupByLibrary.simpleMessage("指定目标的访问账号"),
    "tsAssignedTargets": MessageLookupByLibrary.simpleMessage("已指定的目标"),
    "tsAssignedTo": m120,
    "tsAssignedUnavailable": MessageLookupByLibrary.simpleMessage(
      "指定账号暂不可用，此目标不会改用其他账号。",
    ),
    "tsAttachFailed": MessageLookupByLibrary.simpleMessage(
      "已登录，尚未接入当前配置。登录记录已保留，请重试接入。",
    ),
    "tsAttachLockTip": MessageLookupByLibrary.simpleMessage(
      "正在接入当前配置，暂时无法更改设置。",
    ),
    "tsAttachUnknown": MessageLookupByLibrary.simpleMessage(
      "配置接入结果待确认。请先重新读取状态，确认前请勿重复添加或重新登录。",
    ),
    "tsAttachUnknownLockTip": MessageLookupByLibrary.simpleMessage(
      "配置接入结果待确认，请先重新读取状态。",
    ),
    "tsAttached": MessageLookupByLibrary.simpleMessage("已接入当前配置"),
    "tsAttachedTip": MessageLookupByLibrary.simpleMessage(
      "Tailscale 流量使用专用规则，其他流量仍按原规则分流。",
    ),
    "tsAttaching": MessageLookupByLibrary.simpleMessage("正在接入当前配置…"),
    "tsAttachingTip": MessageLookupByLibrary.simpleMessage(
      "登录已完成，正在添加节点和 Tailscale 专用规则。",
    ),
    "tsBoundaryTip": MessageLookupByLibrary.simpleMessage(
      "只有由 Flash 规则转到此节点的流量才会使用 Tailscale。登录不会自动修改规则、系统代理或虚拟网卡设置。",
    ),
    "tsBrowserFailed": MessageLookupByLibrary.simpleMessage("无法打开登录页，请重试。"),
    "tsCancel": MessageLookupByLibrary.simpleMessage("取消"),
    "tsCandidate": m121,
    "tsChangeAfterSignIn": MessageLookupByLibrary.simpleMessage("登录并连接后可更改"),
    "tsCheckingAccount": MessageLookupByLibrary.simpleMessage("正在核对账号…"),
    "tsChoicesFailed": MessageLookupByLibrary.simpleMessage("选择未保存，请重试。"),
    "tsChoicesSaved": MessageLookupByLibrary.simpleMessage("选择已保存，尚未确认生效。"),
    "tsChoicesUnknown": MessageLookupByLibrary.simpleMessage(
      "选择结果待确认，请先重新读取状态，确认前请勿重复保存。",
    ),
    "tsChoicesUpdated": MessageLookupByLibrary.simpleMessage("访问账号已更新"),
    "tsChooseAccountFor": MessageLookupByLibrary.simpleMessage("指定访问账号"),
    "tsChooseAccounts": MessageLookupByLibrary.simpleMessage("指定账号"),
    "tsChooseExitNode": MessageLookupByLibrary.simpleMessage("选择出口节点"),
    "tsChooseNode": MessageLookupByLibrary.simpleMessage("选择节点"),
    "tsClearOwnerFilter": MessageLookupByLibrary.simpleMessage("清除归属筛选"),
    "tsConflictBody": MessageLookupByLibrary.simpleMessage(
      "这些地址或域名有多个候选账号。指定账号前，对这些目标的访问会被拦截，不会转为直连。",
    ),
    "tsConflictTitle": m122,
    "tsControlServer": MessageLookupByLibrary.simpleMessage("控制服务器"),
    "tsCopyAddress": MessageLookupByLibrary.simpleMessage("复制地址"),
    "tsCoreStopped": MessageLookupByLibrary.simpleMessage("内核未运行"),
    "tsCoreStoppedTip": MessageLookupByLibrary.simpleMessage(
      "启动内核后，才能查看此节点的 Tailscale 状态。",
    ),
    "tsCurrentDevice": MessageLookupByLibrary.simpleMessage("当前设备"),
    "tsDeleteProfileManaged": m123,
    "tsDeleteProfilePending": MessageLookupByLibrary.simpleMessage(
      "此配置还有待确认的 Tailscale 操作，请先重新读取状态，确认后再删除配置。",
    ),
    "tsDeleteProfileUnbindFailed": MessageLookupByLibrary.simpleMessage(
      "未能解除此配置与 Tailscale 账号的关联，配置未删除。请重试。",
    ),
    "tsDeleteProfileUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "配置删除结果待确认。请先重新读取状态，确认前请勿重复删除。",
    ),
    "tsDeleteProfileUnlinkUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "账号关联的处理结果待确认，配置尚未删除。请先重新读取状态，确认前请勿重复删除。",
    ),
    "tsDeviceName": MessageLookupByLibrary.simpleMessage("设备名称"),
    "tsDevices": MessageLookupByLibrary.simpleMessage("设备"),
    "tsDevicesCompact": m124,
    "tsDevicesCompactFiltered": m125,
    "tsDevicesEmpty": MessageLookupByLibrary.simpleMessage("暂无可见设备"),
    "tsDevicesEmptyTip": MessageLookupByLibrary.simpleMessage(
      "当前节点暂未发现其他可见设备。",
    ),
    "tsDevicesFailed": MessageLookupByLibrary.simpleMessage("设备列表加载失败，请重试。"),
    "tsDevicesScope": MessageLookupByLibrary.simpleMessage(
      "显示当前节点可见的设备，不代表管理后台中的全部设备",
    ),
    "tsDevicesShown": m126,
    "tsDevicesStale": MessageLookupByLibrary.simpleMessage(
      "设备列表可能已过期。刷新失败，以下为上次读取的结果。",
    ),
    "tsDirectMode": MessageLookupByLibrary.simpleMessage(
      "当前为直连模式，Tailscale 自动分流和拦截保护未生效。请手动切换到规则模式后再访问。",
    ),
    "tsDnsUnverified": MessageLookupByLibrary.simpleMessage(
      "当前 DNS 设置无法确认目标域名会保留到规则匹配，域名分流尚未核实。请检查 DNS 设置。",
    ),
    "tsDuplicate": MessageLookupByLibrary.simpleMessage(
      "此账号已有条目。本次登录记录已保留，尚未接入分流，请核对后处理。",
    ),
    "tsExitApplying": MessageLookupByLibrary.simpleMessage("正在更改出口节点…"),
    "tsExitCapable": MessageLookupByLibrary.simpleMessage("可作出口节点"),
    "tsExitChangeBody": m127,
    "tsExitChangeConfirm": MessageLookupByLibrary.simpleMessage("更改出口节点"),
    "tsExitChangeTitle": MessageLookupByLibrary.simpleMessage("更改出口节点？"),
    "tsExitFailed": MessageLookupByLibrary.simpleMessage("出口节点未更改，请重试。"),
    "tsExitNode": MessageLookupByLibrary.simpleMessage("出口节点"),
    "tsExitNodeTip": MessageLookupByLibrary.simpleMessage(
      "只影响经此 Tailscale 节点转发的流量，不会让整台 Mac 自动使用该出口。",
    ),
    "tsExitOffBody": m128,
    "tsExitOffTitle": MessageLookupByLibrary.simpleMessage("不再使用出口节点？"),
    "tsExitStale": MessageLookupByLibrary.simpleMessage("请先刷新设备列表，再选择出口节点。"),
    "tsExitUnknown": MessageLookupByLibrary.simpleMessage(
      "出口节点的更改结果待确认，请重新读取当前设置。",
    ),
    "tsExitUpdated": MessageLookupByLibrary.simpleMessage("出口节点已更新"),
    "tsExpiryTip": m129,
    "tsFilterEmpty": MessageLookupByLibrary.simpleMessage("没有符合当前筛选条件的设备"),
    "tsFromLocal": MessageLookupByLibrary.simpleMessage("本机设置"),
    "tsFromProfile": MessageLookupByLibrary.simpleMessage("来自当前配置"),
    "tsFromProvider": MessageLookupByLibrary.simpleMessage("来自代理集合"),
    "tsFromSubscription": MessageLookupByLibrary.simpleMessage("来自订阅"),
    "tsGlobalMode": MessageLookupByLibrary.simpleMessage(
      "当前为全局模式，Tailscale 自动分流和拦截保护未生效。请手动切换到规则模式后再访问。",
    ),
    "tsGoToProfiles": MessageLookupByLibrary.simpleMessage("前往配置"),
    "tsGoToRules": MessageLookupByLibrary.simpleMessage("前往规则"),
    "tsHelp": MessageLookupByLibrary.simpleMessage("补充说明"),
    "tsHelpBody": MessageLookupByLibrary.simpleMessage(
      "Flash 会在 Tailscale 网络中显示为独立设备。它不提供其他设备连入这台 Mac 的 SSH、文件共享或远程桌面功能，也不提供 Tailscale SSH 或 Taildrop。",
    ),
    "tsIdentityFailed": MessageLookupByLibrary.simpleMessage("账号与网络信息加载失败"),
    "tsLegacyAccountUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "账号信息未确认",
    ),
    "tsLegacyAuthKeyNote": MessageLookupByLibrary.simpleMessage(
      "此节点配置了登录密钥，重新登录将使用该密钥注册新的设备身份，旧登录记录仍保留。",
    ),
    "tsLegacyBody": MessageLookupByLibrary.simpleMessage(
      "可将这份登录记录复制给当前节点，保留原记录。它只能迁移到一个节点；请确认这是你要继续使用的账号，也可以选择重新登录。",
    ),
    "tsLegacyChanged": MessageLookupByLibrary.simpleMessage(
      "迁移信息已变化，请重新核对后确认。",
    ),
    "tsLegacyClaimFailed": MessageLookupByLibrary.simpleMessage(
      "登录记录未迁移，迁移信息未能保存。请重试，或选择重新登录。",
    ),
    "tsLegacyConfirm": MessageLookupByLibrary.simpleMessage("确认迁移"),
    "tsLegacyConfirmAccount": m130,
    "tsLegacyConfirmBody": MessageLookupByLibrary.simpleMessage(
      "将复制这份登录记录供上述节点使用，原记录保留不动。同一份旧记录不能再迁移给其他节点。迁移完成后仍需检查此节点的真实连接状态。",
    ),
    "tsLegacyConfirmControl": m131,
    "tsLegacyConfirmNode": m132,
    "tsLegacyConfirmProfile": m133,
    "tsLegacyConfirmTitle": MessageLookupByLibrary.simpleMessage("将旧登录迁移到此节点？"),
    "tsLegacyControlMismatch": MessageLookupByLibrary.simpleMessage(
      "旧登录记录的控制服务器与此节点不一致，无法迁移。",
    ),
    "tsLegacyFailed": MessageLookupByLibrary.simpleMessage(
      "登录记录未迁移，原记录仍保留。请重试，或选择重新登录。",
    ),
    "tsLegacyHasIdentity": MessageLookupByLibrary.simpleMessage(
      "此节点已有自己的登录记录，无需迁移。",
    ),
    "tsLegacyInUse": MessageLookupByLibrary.simpleMessage("旧登录记录仍在使用中，暂时无法迁移。"),
    "tsLegacyMigrate": MessageLookupByLibrary.simpleMessage("迁移到这个节点"),
    "tsLegacyMigrated": MessageLookupByLibrary.simpleMessage(
      "登录记录已迁移，正在读取节点状态。",
    ),
    "tsLegacyMigratedElsewhere": MessageLookupByLibrary.simpleMessage(
      "这份旧登录记录已迁移到其他节点，不能再次迁移。",
    ),
    "tsLegacyMigrating": MessageLookupByLibrary.simpleMessage("正在迁移登录记录…"),
    "tsLegacyRetry": MessageLookupByLibrary.simpleMessage("重试迁移"),
    "tsLegacyTitle": MessageLookupByLibrary.simpleMessage("发现旧版登录记录"),
    "tsLegacyUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "旧登录记录的可用状态尚未确认，请重新读取状态。",
    ),
    "tsLegacyUnknown": MessageLookupByLibrary.simpleMessage(
      "迁移结果待确认。请先重新读取状态，确认前请勿重复迁移或重新登录。",
    ),
    "tsLegacyUnknownArchive": MessageLookupByLibrary.simpleMessage(
      "迁移结果待确认，原登录记录暂时无法核验。请先重新读取状态，确认前请勿重复迁移或重新登录。",
    ),
    "tsLegacyUnknownTarget": MessageLookupByLibrary.simpleMessage(
      "迁移结果待确认，尚未确认目标节点的登录记录。请先重新读取状态，确认前请勿重复迁移或重新登录。",
    ),
    "tsLegacyUnknownUnsaved": MessageLookupByLibrary.simpleMessage(
      "迁移结果待确认，迁移信息未能保存。请先重新读取状态，确认前请勿重复迁移或重新登录。",
    ),
    "tsLegacyUnreadable": MessageLookupByLibrary.simpleMessage(
      "无法读取旧登录记录，请重新核对。",
    ),
    "tsLegacyUnreadableNotMigrated": MessageLookupByLibrary.simpleMessage(
      "登录记录未迁移，无法读取旧登录记录。请重新核对。",
    ),
    "tsLoadFailedTip": MessageLookupByLibrary.simpleMessage(
      "暂时无法读取此节点的状态，请重试。",
    ),
    "tsLoggedOutReceipt": MessageLookupByLibrary.simpleMessage(
      "已退出此节点。再次点击登录前，此节点不会自动登录。",
    ),
    "tsLoggedOutTip": MessageLookupByLibrary.simpleMessage(
      "你已退出此节点。点击登录后才会重新连接。",
    ),
    "tsLoggingOut": MessageLookupByLibrary.simpleMessage("正在退出…"),
    "tsLogin": MessageLookupByLibrary.simpleMessage("登录 Tailscale"),
    "tsLoginUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "尚未确认登录结果，请重新读取节点状态。",
    ),
    "tsLogout": MessageLookupByLibrary.simpleMessage("退出当前节点"),
    "tsLogoutAuthKeyNote": MessageLookupByLibrary.simpleMessage(
      "再次点击登录时，将使用配置中的登录密钥注册新的设备身份。",
    ),
    "tsLogoutBody": m134,
    "tsLogoutFailed": MessageLookupByLibrary.simpleMessage(
      "退出失败，请重新读取节点状态后重试。",
    ),
    "tsLogoutTitle": MessageLookupByLibrary.simpleMessage("退出此 Tailscale 节点？"),
    "tsLogoutUnknown": MessageLookupByLibrary.simpleMessage(
      "退出结果待确认，请重新读取节点状态，确认前请勿重复操作。",
    ),
    "tsManagedPriority": MessageLookupByLibrary.simpleMessage(
      "面板添加的专用规则和拦截保护优先于对应的现有规则。普通流量的规则不变。需要更改目标归属时，请在此指定账号。",
    ),
    "tsMemoryTip": MessageLookupByLibrary.simpleMessage(
      "每个账号都会运行独立的 Tailscale 设备，同时在线会增加内存占用。",
    ),
    "tsNameMissing": MessageLookupByLibrary.simpleMessage("设备名称未提供"),
    "tsNeedsApprovalTip": MessageLookupByLibrary.simpleMessage(
      "浏览器认证已完成。请等待 Tailscale 网络管理员批准此设备。",
    ),
    "tsNeedsReauthTip": MessageLookupByLibrary.simpleMessage(
      "此节点的认证已过期，请重新登录。",
    ),
    "tsNetwork": MessageLookupByLibrary.simpleMessage("所在网络"),
    "tsNetworkMissing": MessageLookupByLibrary.simpleMessage("网络信息未提供"),
    "tsNetworkNameTip": MessageLookupByLibrary.simpleMessage(
      "网络名称不代表已核实的网络所有者。",
    ),
    "tsNetworkOf": m135,
    "tsNewAccount": MessageLookupByLibrary.simpleMessage("新账号"),
    "tsNoExitCandidates": MessageLookupByLibrary.simpleMessage("暂无可用出口节点"),
    "tsNoExitCandidatesTip": MessageLookupByLibrary.simpleMessage(
      "当前没有已确认可用的出口节点",
    ),
    "tsNoExitNode": MessageLookupByLibrary.simpleMessage("不使用出口节点"),
    "tsNoExitNodeTip": MessageLookupByLibrary.simpleMessage(
      "不使用出口节点不会退出 Tailscale",
    ),
    "tsNodeChanged": MessageLookupByLibrary.simpleMessage(
      "当前节点已变化，请在所选节点重新发起操作。",
    ),
    "tsNodeGone": MessageLookupByLibrary.simpleMessage("此节点已不在当前配置中"),
    "tsNodeGoneTip": MessageLookupByLibrary.simpleMessage("请重新选择节点。"),
    "tsNodeOf": m136,
    "tsNotAssigned": MessageLookupByLibrary.simpleMessage("尚未指定"),
    "tsOff": MessageLookupByLibrary.simpleMessage("已关闭"),
    "tsOffline": MessageLookupByLibrary.simpleMessage("离线"),
    "tsOfflineNotSelectable": MessageLookupByLibrary.simpleMessage("离线，不可选"),
    "tsOn": MessageLookupByLibrary.simpleMessage("已开启"),
    "tsOnline": MessageLookupByLibrary.simpleMessage("在线"),
    "tsOverrideAmbiguous": MessageLookupByLibrary.simpleMessage(
      "当前配置中有多个同名节点使用同一控制服务器，暂时无法分别保存设置。请在配置中为它们使用不同名称。",
    ),
    "tsOverrideTip": MessageLookupByLibrary.simpleMessage(
      "此处保存的设置优先于当前配置中的同名设置，不会修改订阅文件。",
    ),
    "tsOwner": MessageLookupByLibrary.simpleMessage("归属"),
    "tsOwnerAll": MessageLookupByLibrary.simpleMessage("全部"),
    "tsOwnerFilter": MessageLookupByLibrary.simpleMessage("设备归属"),
    "tsOwnerFilterEmpty": MessageLookupByLibrary.simpleMessage("没有符合当前归属的设备"),
    "tsOwnerMe": MessageLookupByLibrary.simpleMessage("我"),
    "tsOwnerMine": MessageLookupByLibrary.simpleMessage("我的"),
    "tsOwnerUnknown": MessageLookupByLibrary.simpleMessage("归属未知"),
    "tsPrepareAgain": MessageLookupByLibrary.simpleMessage("重新准备登录"),
    "tsPrepareFailed": MessageLookupByLibrary.simpleMessage(
      "暂时无法准备 Tailscale 登录，请重试。",
    ),
    "tsPrepareUnknown": MessageLookupByLibrary.simpleMessage(
      "登录准备结果待确认。请先重新读取状态，确认前请勿重复登录。",
    ),
    "tsPreparingProfile": MessageLookupByLibrary.simpleMessage("正在准备本地配置…"),
    "tsPreparingSignIn": MessageLookupByLibrary.simpleMessage("正在准备登录…"),
    "tsPreparingSignInTip": MessageLookupByLibrary.simpleMessage(
      "正在为当前配置准备 Tailscale。",
    ),
    "tsPreparingTip": MessageLookupByLibrary.simpleMessage("正在获取此节点的登录信息。"),
    "tsReadSettings": MessageLookupByLibrary.simpleMessage("重新读取设置"),
    "tsReadStatus": MessageLookupByLibrary.simpleMessage("重新读取状态"),
    "tsReassign": MessageLookupByLibrary.simpleMessage("重新指定账号"),
    "tsReconfirm": MessageLookupByLibrary.simpleMessage(
      "目标归属需要重新确认，访问已拦截。请重新指定账号。",
    ),
    "tsRefresh": MessageLookupByLibrary.simpleMessage("刷新"),
    "tsRefreshDevices": MessageLookupByLibrary.simpleMessage("刷新设备列表"),
    "tsRelogin": MessageLookupByLibrary.simpleMessage("重新登录"),
    "tsRemoveBody": m137,
    "tsRemoveBodyNode": m138,
    "tsRemoveExtra": MessageLookupByLibrary.simpleMessage(
      "此操作不删除 Tailscale 管理页面中的设备，也不更改官方客户端。",
    ),
    "tsRemoveIncomplete": MessageLookupByLibrary.simpleMessage(
      "已退出，尚未完成移除。请先重新读取状态。",
    ),
    "tsRemoveLast": MessageLookupByLibrary.simpleMessage(
      "这是当前配置中最后一个面板添加的账号。移除后，面板添加的专用规则和拦截保护也会撤掉，相关流量恢复按原配置处理，可能直连或走原来的代理。请确认你接受这个变化。",
    ),
    "tsRemoveLogoutUnknown": MessageLookupByLibrary.simpleMessage(
      "退出结果待确认，暂未移除节点。请先重新读取状态，确认前请勿重复移除或重新登录。",
    ),
    "tsRemoveTargetsKept": MessageLookupByLibrary.simpleMessage(
      "原来指定给此账号的目标不会自动交给其他账号，仍会保留拦截保护。需要继续访问时，请重新指定账号。",
    ),
    "tsRemoveTitle": MessageLookupByLibrary.simpleMessage("退出并移除此账号？"),
    "tsRemoveUnknown": MessageLookupByLibrary.simpleMessage(
      "移除结果待确认。请先重新读取状态，确认前请勿重新添加或登录。",
    ),
    "tsRemoved": MessageLookupByLibrary.simpleMessage("已退出并移除"),
    "tsRemoving": MessageLookupByLibrary.simpleMessage("正在退出并移除…"),
    "tsReopenLogin": MessageLookupByLibrary.simpleMessage("重新打开登录页"),
    "tsRetryAttach": MessageLookupByLibrary.simpleMessage("重试接入"),
    "tsRoutesApplying": MessageLookupByLibrary.simpleMessage("正在更新子网路由设置…"),
    "tsRoutesFailed": MessageLookupByLibrary.simpleMessage("子网路由设置未更改，请重试。"),
    "tsRoutesOffBody": MessageLookupByLibrary.simpleMessage(
      "此节点将不再使用这些子网路由，相关连接可能中断。Flash 的规则不变。",
    ),
    "tsRoutesOffConfirm": MessageLookupByLibrary.simpleMessage("停止接受"),
    "tsRoutesOffTitle": MessageLookupByLibrary.simpleMessage("停止接受子网路由？"),
    "tsRoutesOnBody": MessageLookupByLibrary.simpleMessage(
      "此节点将允许使用网络中已批准的子网路由。Flash 的规则不变。",
    ),
    "tsRoutesOnTitle": MessageLookupByLibrary.simpleMessage("接受子网路由？"),
    "tsRoutesUnknown": MessageLookupByLibrary.simpleMessage(
      "子网路由设置的更改结果待确认，请重新读取当前设置。",
    ),
    "tsRoutesUpdated": MessageLookupByLibrary.simpleMessage("子网路由设置已更新"),
    "tsRoutingConflict": MessageLookupByLibrary.simpleMessage("归属冲突"),
    "tsRulesAddresses": m139,
    "tsRulesDomain": m140,
    "tsRulesManaged": MessageLookupByLibrary.simpleMessage(
      "Flash 会按此账号的网络域名和设备地址更新专用规则。其他流量仍按原规则分流，原配置文件保持不变。",
    ),
    "tsRulesPending": MessageLookupByLibrary.simpleMessage(
      "接入完成后，Tailscale 地址和 ts.net 域名会使用专用规则，其他流量保留原分流。",
    ),
    "tsRulesProfileNode": MessageLookupByLibrary.simpleMessage(
      "只有由 Flash 规则转到此节点的流量才会使用 Tailscale。登录此节点不会自动修改现有规则，也不会开启系统代理或虚拟网卡。",
    ),
    "tsSaveChoices": MessageLookupByLibrary.simpleMessage("保存选择"),
    "tsSavedValue": m141,
    "tsSearchEmpty": MessageLookupByLibrary.simpleMessage("没有符合搜索条件的设备"),
    "tsSearchHint": MessageLookupByLibrary.simpleMessage("搜索名称或地址"),
    "tsSettingsApplyFailed": MessageLookupByLibrary.simpleMessage(
      "设置已保存，但未能应用到当前节点。请重新读取当前设置。",
    ),
    "tsSettingsSaved": MessageLookupByLibrary.simpleMessage(
      "设置已保存，但尚未确认生效。请重新读取当前设置。",
    ),
    "tsShared": MessageLookupByLibrary.simpleMessage("来自共享"),
    "tsSharedBy": m142,
    "tsSignIn": MessageLookupByLibrary.simpleMessage("登录 Tailscale"),
    "tsSignInBoundary": MessageLookupByLibrary.simpleMessage(
      "不会自动开启系统代理或虚拟网卡。",
    ),
    "tsSignInTip": MessageLookupByLibrary.simpleMessage(
      "登录后，Flash 会为当前配置添加 Tailscale 节点和专用规则。其他流量仍按原规则分流，原配置文件保持不变。",
    ),
    "tsSignOutAccount": MessageLookupByLibrary.simpleMessage("退出此账号"),
    "tsSignOutAccountBody": m143,
    "tsSignOutAccountTitle": MessageLookupByLibrary.simpleMessage("退出此账号？"),
    "tsSignOutRemove": MessageLookupByLibrary.simpleMessage("退出并移除"),
    "tsSignOutRemoveMenu": MessageLookupByLibrary.simpleMessage("退出并移除…"),
    "tsSignedOutBanner": MessageLookupByLibrary.simpleMessage(
      "已退出此账号。在规则模式下，原来交给此账号的目标将被拦截，直到你主动登录或明确更改归属。",
    ),
    "tsSignedOutReceipt": MessageLookupByLibrary.simpleMessage("已退出此账号"),
    "tsSignedOutTip": MessageLookupByLibrary.simpleMessage("在浏览器中登录，完成此节点的认证。"),
    "tsStartCore": MessageLookupByLibrary.simpleMessage("启动内核"),
    "tsStartFailedTip": MessageLookupByLibrary.simpleMessage("此节点未能启动，请重试。"),
    "tsStateConnected": MessageLookupByLibrary.simpleMessage("已连接"),
    "tsStateLoadFailed": MessageLookupByLibrary.simpleMessage("状态加载失败"),
    "tsStateNeedsApproval": MessageLookupByLibrary.simpleMessage("等待管理员批准"),
    "tsStateNeedsReauth": MessageLookupByLibrary.simpleMessage("需要重新登录"),
    "tsStatePreparing": MessageLookupByLibrary.simpleMessage("正在准备登录…"),
    "tsStateSignedOut": MessageLookupByLibrary.simpleMessage("未登录"),
    "tsStateStartFailed": MessageLookupByLibrary.simpleMessage("启动失败"),
    "tsStateStarting": MessageLookupByLibrary.simpleMessage("正在启动…"),
    "tsStateStopped": MessageLookupByLibrary.simpleMessage("已停止"),
    "tsStateUnconfirmed": MessageLookupByLibrary.simpleMessage("状态待确认"),
    "tsStateWaitingBrowser": MessageLookupByLibrary.simpleMessage("等待浏览器登录"),
    "tsStatus": MessageLookupByLibrary.simpleMessage("状态"),
    "tsStatusOf": m144,
    "tsStatusUnknown": MessageLookupByLibrary.simpleMessage("状态未知"),
    "tsStoppedTip": MessageLookupByLibrary.simpleMessage(
      "此节点已停止，暂时无法通过它访问 Tailscale 网络。",
    ),
    "tsSubnetRoutes": MessageLookupByLibrary.simpleMessage("子网路由"),
    "tsSwitcherSemantics": m145,
    "tsSystem": MessageLookupByLibrary.simpleMessage("系统"),
    "tsSystemMissing": MessageLookupByLibrary.simpleMessage("系统未提供"),
    "tsTargetAddress": m146,
    "tsTargetDomain": m147,
    "tsTargetUnconfirmed": MessageLookupByLibrary.simpleMessage("目标归属待确认"),
    "tsTargetUnconfirmedTip": MessageLookupByLibrary.simpleMessage(
      "暂时无法确认此目标应使用哪个账号，访问已拦截。",
    ),
    "tsTryAgain": MessageLookupByLibrary.simpleMessage("重试"),
    "tsUnconfirmedTip": MessageLookupByLibrary.simpleMessage(
      "暂时无法确认此节点是否已连接，请重新读取状态。",
    ),
    "tsUnverifiedBlocked": MessageLookupByLibrary.simpleMessage(
      "未匹配到可靠归属的 Tailscale 地址和域名会被拦截，不会改用其他账号或直连。",
    ),
    "tsUrlMissing": MessageLookupByLibrary.simpleMessage(
      "尚未获取到可用的登录页，请重新准备登录。",
    ),
    "tsUrlRejected": MessageLookupByLibrary.simpleMessage(
      "无法安全打开此登录页，请检查当前节点的控制服务器配置。",
    ),
    "tsViewExisting": MessageLookupByLibrary.simpleMessage("查看已有账号"),
    "tsWaitingBrowserTip": MessageLookupByLibrary.simpleMessage(
      "请在浏览器中完成登录。完成后，这里会根据节点状态更新。",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("虚拟网卡"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "虚拟网卡授权失败，已关闭。",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage("虚拟网卡仅在管理员模式生效。"),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "添加的项会覆写所有配置的虚拟网卡设置，未添加的项沿用配置自身的设置。自定义配置自己添加的项优先。",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("关闭"),
    "turnOn": MessageLookupByLibrary.simpleMessage("开启"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP 中继模式"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP 超时"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "UDP 超时以秒为单位，仅在 gvisor、system 和 mixed 栈生效。",
    ),
    "ultra": MessageLookupByLibrary.simpleMessage("极致"),
    "undo": MessageLookupByLibrary.simpleMessage("撤销"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("统一延迟"),
    "unknown": MessageLookupByLibrary.simpleMessage("未知"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage("未知网络错误"),
    "unmaximize": MessageLookupByLibrary.simpleMessage("向下还原"),
    "unnamed": MessageLookupByLibrary.simpleMessage("未命名"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("取消置顶"),
    "update": MessageLookupByLibrary.simpleMessage("更新"),
    "updateCheckFailed": MessageLookupByLibrary.simpleMessage("暂时无法检查更新，请重试"),
    "updateDownloadFailed": MessageLookupByLibrary.simpleMessage("无法下载更新。"),
    "updateDownloadStarted": MessageLookupByLibrary.simpleMessage(
      "已开始下载更新，可在首页查看进度",
    ),
    "updateDownloadTest": MessageLookupByLibrary.simpleMessage("更新下载测试"),
    "updateFailed": MessageLookupByLibrary.simpleMessage("更新失败"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "无法安装更新，可以前往发布页手动下载。",
    ),
    "updateNoReleaseFound": MessageLookupByLibrary.simpleMessage(
      "暂未找到 Flash 发布版本",
    ),
    "updateNotVerified": MessageLookupByLibrary.simpleMessage("下载的更新未通过校验。"),
    "updateReady": MessageLookupByLibrary.simpleMessage("更新已就绪"),
    "updateReadyTip": MessageLookupByLibrary.simpleMessage("更新已下载，点击安装"),
    "updateRestartTip": MessageLookupByLibrary.simpleMessage(
      "Flash 将关闭以安装更新，完成后自动重新打开。",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("上传"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("上行带宽"),
    "upstreamTelegram": MessageLookupByLibrary.simpleMessage(
      "FlClash 上游 Telegram",
    ),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlRewrite": MessageLookupByLibrary.simpleMessage("URL 重写"),
    "urlTip": m148,
    "useHosts": MessageLookupByLibrary.simpleMessage("使用Hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("使用系统Hosts"),
    "usedShort": MessageLookupByLibrary.simpleMessage("已用"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("已用流量"),
    "userAgent": MessageLookupByLibrary.simpleMessage("用户代理"),
    "username": MessageLookupByLibrary.simpleMessage("用户名"),
    "validUntil": m149,
    "value": MessageLookupByLibrary.simpleMessage("值"),
    "view": MessageLookupByLibrary.simpleMessage("查看"),
    "viewAll": MessageLookupByLibrary.simpleMessage("查看全部"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("虚拟 IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("鲜明"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN 相关配置已改动，点击重启",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage("WebDAV配置"),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("白名单模式"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("写入系统"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "写入系统会同时设置系统时钟，Android 上不生效。",
    ),
    "yearsAgo": m150,
    "yearsAgoShort": m151,
    "yes": MessageLookupByLibrary.simpleMessage("是"),
    "zhCN": MessageLookupByLibrary.simpleMessage("中文简体"),
  };
}
