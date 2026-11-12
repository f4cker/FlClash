// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  static String m0(count) =>
      "${Intl.plural(count, other: '${count} selected')}";

  static String m1(name) => "Added ${name} to local proxies";

  static String m2(name) => "${name} is already in local proxies";

  static String m3(count, skipped) =>
      "${count} to add, ${skipped} skipped as existing";

  static String m4(detail) => "Couldn\'t clear the data: ${detail}";

  static String m5(code) =>
      "Windows refused to run FlClashCore.exe (error ${code}). An app control policy such as Smart App Control or AppLocker blocks unsigned programs; allow Flash in that policy or turn it off, then try again.";

  static String m6(name) =>
      "The app failed to finish launching twice in a row. To break the loop, the profile ${name} has been deselected and automatic setup was skipped. You can select it again at any time.";

  static String m7(url) => "Do you want to create a profile from ${url}?";

  static String m8(count, label) =>
      "${Intl.plural(count, one: '1 SUB-RULE rule was dropped, since custom profiles do not support sub-rules', other: '${label} SUB-RULE rules were dropped, since custom profiles do not support sub-rules')}";

  static String m9(message) => "The core cannot parse this proxy: ${message}";

  static String m10(proxy, target) =>
      "${proxy} dials through ${target}, which leads back to ${proxy}, so the dial loops";

  static String m11(name) =>
      "The name ${name} is already used by another proxy or proxy group";

  static String m12(path) =>
      "Proxy groups reference each other in a loop: ${path}";

  static String m13(name) =>
      "The empty fallback must be a proxy, but ${name} does not exist or is a proxy group";

  static String m14(name, message) =>
      "${name} is not a valid regex: ${message}";

  static String m15(name) => "The dialer proxy ${name} does not exist";

  static String m16(names) => "These proxy providers do not exist: ${names}";

  static String m17(names) =>
      "These proxies or policies do not exist: ${names}";

  static String m18(name) =>
      "${name} is a built-in policy name and cannot be used here";

  static String m19(count) =>
      "${count} items have problems, and applying this profile may fail";

  static String m20(count) =>
      "${Intl.plural(count, one: '1 day ago', other: '${count} days ago')}";

  static String m21(count) => "${Intl.plural(count, other: '${count}d ago')}";

  static String m22(label) =>
      "Are you sure you want to delete the selected ${label}?";

  static String m23(label) => "Are you sure you want to delete this ${label}?";

  static String m24(label) => "${label} details";

  static String m25(name) =>
      "Dialing through ${name} leads back to the proxy that uses it, so the connection was stopped";

  static String m26(label) => "${label} cannot be empty";

  static String m27(label) => "${label} already exists";

  static String m28(count) => "${count} items failed. Tap to view";

  static String m29(label, message) => "${label}: ${message}";

  static String m30(name) => "${name} is already up to date";

  static String m31(name) => "${name} updated";

  static String m32(count) =>
      "${Intl.plural(count, one: '1 group', other: '${count} groups')}";

  static String m33(count) => "${count} timed out";

  static String m34(action) =>
      "Already used by “${action}”. Saving moves it here.";

  static String m35(modifiers) => "Include at least one of ${modifiers}";

  static String m36(count) =>
      "${Intl.plural(count, one: '1 hour ago', other: '${count} hours ago')}";

  static String m37(count) => "${Intl.plural(count, other: '${count}h ago')}";

  static String m38(encoding) =>
      "Could not decode ${encoding}, so this is the data as it was sent.";

  static String m39(memory, body) =>
      "The oldest records go first once this many are kept or they fill ${memory} of memory. Each body keeps its first ${body}.";

  static String m40(invalid, total) => "${invalid} of ${total} invalid";

  static String m41(target) => "${target} is an invalid policy";

  static String m42(proxyName) => "${proxyName} is an invalid proxy";

  static String m43(providerName) =>
      "${providerName} is an invalid proxy provider";

  static String m44(ruleSet) => "${ruleSet} is an invalid rule set";

  static String m45(subRule) => "${subRule} is an invalid SUB_RULE";

  static String m46(count) =>
      "${Intl.plural(count, one: '1 item', other: '${count} items')}";

  static String m47(line, message) => "Line ${line}: ${message}";

  static String m48(appName) =>
      "1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check ${appName} in the list\n\nWhen you are done, return to the app to continue. Thank you for your cooperation.";

  static String m49(label, max) => "${label} must be at most ${max} characters";

  static String m50(size) => "Released ${size}";

  static String m51(count) =>
      "${Intl.plural(count, one: '1 minute ago', other: '${count} minutes ago')}";

  static String m52(count) => "${Intl.plural(count, other: '${count}m ago')}";

  static String m53(fileName) =>
      "Saved ${fileName} to Downloads. Install it in Settings under Security › Encryption & credentials › Install a certificate › CA certificate.";

  static String m54(command) =>
      "Chrome and Firefox keep their own certificate stores, which need certutil: ${command}";

  static String m55(host) =>
      "Add ${host} to the hostname list? Flash can then read what is sent to it, cookies and passwords included.";

  static String m56(host) =>
      "Add -${host} to the top of the hostname list? The host is then never decrypted.";

  static String m57(size) => "The file is larger than ${size} MB";

  static String m58(stores) => "Not yet in: ${stores}";

  static String m59(name) => "${name} changed its scripts and was turned off";

  static String m60(system) =>
      "Written for ${system}; some lines may not match apps on this device.";

  static String m61(name) =>
      "The old certificate, ${name}, could not be removed. Remove it from the trusted roots yourself.";

  static String m62(name) =>
      "The old certificate, ${name}, is still among the system\'s trusted CAs. Allow Flash root access in your root manager and regenerate, or remove the FlClash MITM CA module there and restart.";

  static String m63(name) =>
      "Remove the old certificate, ${name}, in Settings under Security › Encryption & credentials › Trusted credentials › User, then install the new one.";

  static String m64(section) => "The [${section}] section is not supported";

  static String m65(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start.";

  static String m66(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start. System proxy settings were not changed.";

  static String m67(count) =>
      "${Intl.plural(count, one: '1 month ago', other: '${count} months ago')}";

  static String m68(count) => "${Intl.plural(count, other: '${count}mo ago')}";

  static String m69(count) =>
      "This save also mounts ${Intl.plural(count, one: '1 subscription', other: '${count} subscriptions')}.";

  static String m70(target) =>
      "Empty-group handling comes from the original profile: ${target}.";

  static String m71(count) =>
      "${Intl.plural(count, one: '1 subscription update failed', other: '${count} subscription updates failed')}";

  static String m72(subscriptionName, profileCount) =>
      "“${subscriptionName}” is mounted on the following ${Intl.plural(profileCount, one: '1 profile', other: '${profileCount} profiles')}. Deleting it removes its nodes from those profiles and may interrupt connections. Other subscriptions, base profile files, and Tailscale sign-ins will not be deleted.";

  static String m73(group) =>
      "Group “${group}” has no selectable nodes. Check the subscriptions and group filters.";

  static String m74(count) =>
      "To keep Tailscale routing separate, ${Intl.plural(count, one: '1 group does not accept subscription nodes.', other: '${count} groups do not accept subscription nodes.')}";

  static String m75(groups) => "Groups: ${groups}.";

  static String m76(time) => "Last updated: ${time}";

  static String m77(count) =>
      "${Intl.plural(count, one: '1 node', other: '${count} nodes')}";

  static String m78(count) =>
      "${Intl.plural(count, one: '1 node read', other: '${count} nodes read')}";

  static String m79(time) => "Nodes read: ${time}";

  static String m80(label, profileName) =>
      "${label}, target profile ${profileName}";

  static String m81(name) =>
      "New content for “${name}” was read but did not pass the mount-isolation checks and was not applied. The previously confirmed content is still in use.";

  static String m82(name) =>
      "New content for “${name}” was read but did not pass the mount-isolation checks and was not applied. Its current use is unconfirmed. Read the status again.";

  static String m83(profileName) => "Target profile: ${profileName}";

  static String m84(subscriptionName, profileName) =>
      "This removes nodes from “${subscriptionName}” from “${profileName}”. Connections using those nodes may be interrupted. The subscription, original profile file, and other mounts are not deleted. Dedicated Tailscale routing stays unchanged.";

  static String m85(count, profileName) =>
      "This removes nodes provided by the following ${Intl.plural(count, one: '1 subscription', other: '${count} subscriptions')} from “${profileName}”. Connections using those nodes may be interrupted. The subscriptions, original profile file, and other mounts are not deleted. Dedicated Tailscale routing stays unchanged.";

  static String m86(count) =>
      "To keep Tailscale routing separate, ${Intl.plural(count, one: '1 subscription node that is not supported for mounting was excluded. Its settings were not changed.', other: '${count} subscription nodes that are not supported for mounting were excluded. Their settings were not changed.')}";

  static String m87(name) => "Update nodes of ${name}";

  static String m88(count) =>
      "${Intl.plural(count, one: '1 subscription mounted', other: '${count} subscriptions mounted')}";

  static String m89(code) =>
      "The server denied access (HTTP ${code}). The link may have expired, or the credentials are wrong";

  static String m90(code) => "The server rejected the request (HTTP ${code})";

  static String m91(code) =>
      "Nothing was found at this address (HTTP ${code}). Check that the URL is correct";

  static String m92(detail) => "Network request failed: ${detail}";

  static String m93(code) =>
      "The server ran into a problem (HTTP ${code}). Try again later";

  static String m94(label) => "No ${label} yet";

  static String m95(label, min, max) =>
      "${label} must be between ${min} and ${max}";

  static String m96(label) => "${label} must be a number";

  static String m97(label) => "${label} must be between 1024 and 49151";

  static String m98(port) => "Port ${port}";

  static String m99(days) =>
      "${Intl.plural(days, one: '1 day left', other: '${days} days left')}";

  static String m100(date, days) =>
      "Expires ${date}, ${Intl.plural(days, one: '1 day', other: '${days} days')} left";

  static String m101(time) => "Updated ${time}";

  static String m102(label, profiles) =>
      "${label} is still used by ${profiles}, which will not work properly once it is deleted. Are you sure you want to delete it?";

  static String m103(count, label) =>
      "${Intl.plural(count, one: '1 proxy', other: '${label} proxies')}";

  static String m104(name, count) => "${name} and others (${count} proxies)";

  static String m105(removed) =>
      "These proxies will be deleted: ${removed}. A line whose name changed counts as a new proxy, and custom profiles naming the deleted ones will flag them as missing. Apply anyway?";

  static String m106(removed, added) =>
      "These proxies will be deleted: ${removed}. These will be added: ${added}. A line whose name changed counts as a new proxy, and custom profiles naming the deleted ones will flag them as missing. Apply anyway?";

  static String m107(label) =>
      "${label} is still named by rules, proxy groups, dialer proxies, DNS or NTP in this profile, which stop working once it is deleted. Are you sure you want to delete it?";

  static String m108(count, label) =>
      "${Intl.plural(count, one: '1 proxy group', other: '${label} proxy groups')}";

  static String m109(count, label) =>
      "${Intl.plural(count, one: '1 rule', other: '${label} rules')}";

  static String m110(appName) => "${appName} (Safe mode)";

  static String m111(count) =>
      "${Intl.plural(count, one: '1 second', other: '${count} seconds')}";

  static String m112(count) => "${count} in effect";

  static String m113(count) =>
      "${Intl.plural(count, one: '1 issue', other: '${count} issues')}";

  static String m114(count) =>
      "${Intl.plural(count, one: '1 setting', other: '${count} settings')}";

  static String m115(link) => "No proxy could be read from ${link}";

  static String m116(label) => "${label} must be a single item";

  static String m117(value) => "Peak ${value}";

  static String m118(value) => "Total ${value}";

  static String m119(transport) => "${transport} Headers";

  static String m120(account) => "Assigned: ${account}";

  static String m121(account, network) => "${account} · ${network}";

  static String m122(count) => "Choose accounts for ${count} targets";

  static String m123(count) =>
      "This profile has ${count} panel-added Tailscale accounts. Deleting it removes their profile bindings, target assignments, and dedicated routing and blocking rules. Local sign-in archives are kept. Devices in the Tailscale admin console are not deleted. Other profiles are not affected.";

  static String m124(count) =>
      "${Intl.plural(count, one: '1 device · Only devices visible to this account', other: '${count} devices · Only devices visible to this account')}";

  static String m125(shown, total) =>
      "Showing ${shown}/${total} · Devices visible to this account only";

  static String m126(shown, total) => "Showing ${shown} / ${total}";

  static String m127(n) => "Showing ${n} devices";

  static String m128(node, device) =>
      "Sets the exit node of “${node}” to “${device}”. Connections through this node may drop; Flash rules stay the same.";

  static String m129(node) =>
      "Only turns off exit forwarding for “${node}”; it doesn\'t log out of Tailscale and Flash rules stay the same.";

  static String m130(time) =>
      "Authentication expires at ${time}. Log in again before then.";

  static String m131(account) => "Account: ${account}";

  static String m132(server) => "Control server: ${server}";

  static String m133(name) => "Node: ${name}";

  static String m134(name) => "Profile: ${name}";

  static String m135(name) =>
      "This logs out of “${name}” and clears the login identity this Mac keeps for it. Connections through this node may drop; other nodes are not affected.";

  static String m136(name) => "Network: ${name}";

  static String m137(name) => "Node ${name}";

  static String m138(account, node, profile) =>
      "This signs out “${account}” (node “${node}”), clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m139(node, profile) =>
      "This signs out “${node}”, clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m140(count) => "Device addresses: ${count}";

  static String m141(domain) => "Network domain: ${domain}";

  static String m142(count, domain) =>
      "${Intl.plural(count, one: '${domain} · 1 device address', other: '${domain} · ${count} device addresses')}";

  static String m143(value) => "Saved: ${value}";

  static String m144(name) => "Shared by: ${name}";

  static String m145(account, node) =>
      "This signs out “${account}” (node “${node}”) and clears its sign-in from this Mac. Its panel entry and target assignments stay saved. Connections through this account may be interrupted and will not switch to another account or a direct connection. Other accounts will not be signed out. You must choose Sign in to use this account again.";

  static String m146(label) => "Status: ${label}";

  static String m147(account, status, count) =>
      "Viewing Tailscale account: ${account}, ${status}. ${count} entries.";

  static String m148(address) => "Address: ${address}";

  static String m149(domain) => "Domain: ${domain}";

  static String m150(label) => "${label} must be a URL";

  static String m151(date) => "Valid until ${date}";

  static String m152(count) =>
      "${Intl.plural(count, one: '1 year ago', other: '${count} years ago')}";

  static String m153(count) => "${Intl.plural(count, other: '${count}y ago')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Access control"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Only selected apps go through the VPN",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "App access control is disabled",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Selected apps are excluded from the VPN",
    ),
    "accessControlSelectedCount": m0,
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage("Test all delays"),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Direct mode"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("Global mode"),
    "actionMode": MessageLookupByLibrary.simpleMessage("Switch mode"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Rule mode"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Start/Stop"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Update profiles",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Show/Hide"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Add proxy"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Add filters"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Add nodes"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Add override entry",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Add profile"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("Add proxy group"),
    "addRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("Add setting"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Add SSID"),
    "addToLocalProxies": MessageLookupByLibrary.simpleMessage(
      "Add to local proxies",
    ),
    "addedRules": MessageLookupByLibrary.simpleMessage("Added rules"),
    "addedToLocalProxies": m1,
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Additional parameters",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("Name prefix"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("Name suffix"),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid WebDAV address",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Advanced configuration",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Encrypted profile",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("Age secret key"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "This profile is encrypted with age and needs an age secret key to decrypt",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "All referenced proxies",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "All referenced proxy providers",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Allow apps to bypass VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Allow LAN"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("Allowed IPs"),
    "alreadyInLocalProxies": m2,
    "answers": MessageLookupByLibrary.simpleMessage("Answers"),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App access control",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage("App icon design"),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage("No local proxies"),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Append system DNS",
    ),
    "applied": MessageLookupByLibrary.simpleMessage("Applied"),
    "applyNow": MessageLookupByLibrary.simpleMessage("Apply now"),
    "arguments": MessageLookupByLibrary.simpleMessage("Arguments"),
    "authentication": MessageLookupByLibrary.simpleMessage("Authentication"),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "The system proxy is not applied while authentication is on.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Authorize"),
    "authorized": MessageLookupByLibrary.simpleMessage("Authorized"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Auto check for updates",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Auto close connections",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage("Auto-include"),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Auto launch"),
    "autoRun": MessageLookupByLibrary.simpleMessage("Auto run"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Auto run starts the proxy when the app opens.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto-set system DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto-update interval",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "backgroundBlur": MessageLookupByLibrary.simpleMessage("Background blur"),
    "backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Backup and restore",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "This backup comes from a newer version of the app. Update the app before restoring it",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Backup successful"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Basic info"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Basic strategies"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Batch import"),
    "batchLineInputTip": MessageLookupByLibrary.simpleMessage(
      "One item per line",
    ),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "One link per line",
    ),
    "batchPreviewTip": m3,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "One URL per line",
    ),
    "binaryData": MessageLookupByLibrary.simpleMessage("Binary data"),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist mode"),
    "blockQuic": MessageLookupByLibrary.simpleMessage("Block QUIC"),
    "bodyRewrite": MessageLookupByLibrary.simpleMessage("Body rewrite"),
    "brightness": MessageLookupByLibrary.simpleMessage("Brightness"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass domains"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Bypass domains apply only while the system proxy is on.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Bypass private addresses",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Cache"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("Cache algorithm"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "The cache is corrupted. Clear it?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Cache size"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Allow camera access in system settings to scan QR codes, or choose a QR code image from the album.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Camera permission required",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Camera unavailable",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Deselect all"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("Can\'t save"),
    "certificate": MessageLookupByLibrary.simpleMessage("Certificate"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Failed to switch proxy; the previous selection has been restored",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Breaking changes",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("New features"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Bug fixes"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("Performance"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Reverts"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Verify TLS certificates",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "With TLS verification off, subscriptions and backups are open to man-in-the-middle attacks.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "The app is already up to date",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Cipher"),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear data"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "This deletes all profiles, settings, and local data, then closes the app. Open it again to start fresh.",
    ),
    "clearDataFailed": m4,
    "clearDnsCache": MessageLookupByLibrary.simpleMessage("Clear DNS cache"),
    "clearDnsCacheFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to clear DNS cache",
    ),
    "clearSearch": MessageLookupByLibrary.simpleMessage("Clear search"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Client fingerprint",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Export to clipboard",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Import from clipboard",
    ),
    "clipboardNoPackageNames": MessageLookupByLibrary.simpleMessage(
      "No package names found in the clipboard",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t copy to the clipboard. The selection may be too large",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "closeConnection": MessageLookupByLibrary.simpleMessage("Close connection"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Close connections",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Color style"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "compact": MessageLookupByLibrary.simpleMessage("Compact"),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatibility mode"),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to clear all data?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to delete this proxy group?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to exit the current window?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to force crash the core?",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Congestion control",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "TCP congestion control",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "TCP congestion control works only with the mips stack.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Connected"),
    "connecting": MessageLookupByLibrary.simpleMessage("Connecting…"),
    "connection": MessageLookupByLibrary.simpleMessage("Connection"),
    "connectionStats": MessageLookupByLibrary.simpleMessage("Connection stats"),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Live connections, recent requests and DNS queries",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity: "),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Content cannot be empty",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Control global added rules",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyAsBase64": MessageLookupByLibrary.simpleMessage("Copy as Base64"),
    "copyAsCurl": MessageLookupByLibrary.simpleMessage("Copy as cURL"),
    "copyDestination": MessageLookupByLibrary.simpleMessage("Copy destination"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copy environment variables",
    ),
    "copyHost": MessageLookupByLibrary.simpleMessage("Copy host"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "copyRequest": MessageLookupByLibrary.simpleMessage("Copy request"),
    "copyResponse": MessageLookupByLibrary.simpleMessage("Copy response"),
    "copyResponseBody": MessageLookupByLibrary.simpleMessage(
      "Copy response body",
    ),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copied successfully"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "coreBlockedByPolicyTip": m5,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows Smart App Control blocked FlClashCore.exe because it is not signed. Open Windows Security → App & browser control → Smart App Control settings, choose Off, then start Flash again. Smart App Control cannot be turned back on without reinstalling Windows.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Core status"),
    "country": MessageLookupByLibrary.simpleMessage("Region"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Crash detected"),
    "crashDetectedTip": m6,
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash test"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createProfileFromUrlTip": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("Creation time"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Holds the start button and can\'t be removed",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Custom"),
    "customColor": MessageLookupByLibrary.simpleMessage("Custom color"),
    "customImportDroppedSubRules": m8,
    "customIssueCoreRejected": m9,
    "customIssueDialerLoop": m10,
    "customIssueDuplicateName": m11,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "The name is empty",
    ),
    "customIssueGroupLoop": m12,
    "customIssueInvalidEmptyFallback": m13,
    "customIssueInvalidFilter": m14,
    "customIssueMissingDialer": m15,
    "customIssueMissingProviders": m16,
    "customIssueMissingProxies": m17,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "No proxies or proxy providers are selected, so the core rejects this group",
    ),
    "customIssueReservedName": m18,
    "customIssuesSummary": m19,
    "customProfile": MessageLookupByLibrary.simpleMessage("Custom"),
    "customResources": MessageLookupByLibrary.simpleMessage("Custom"),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Dashboard"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Available to add",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Failed to save the change; it has been rolled back",
    ),
    "daysAgo": m20,
    "daysAgoShort": m21,
    "decryptUntrusted": MessageLookupByLibrary.simpleMessage(
      "Decrypt without local trust",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resolves the hostnames of the other DNS servers. Use IP addresses only.",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Default selection",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "The configuration must be a YAML mapping with a name and a type",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Failed"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Delay test"),
    "delayTestTimeout": MessageLookupByLibrary.simpleMessage(
      "Delay test timeout",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteMultipTip": m22,
    "deleteTip": m23,
    "desc": MessageLookupByLibrary.simpleMessage(
      "A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Destination GeoIP",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "Destination IP ASN",
    ),
    "details": m24,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Relies on a third-party API; for reference only",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("Dialer proxy"),
    "dialerProxyLoopStopped": m25,
    "dialog": MessageLookupByLibrary.simpleMessage("Dialog"),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resolves domains for connections that go direct.",
    ),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Disable ICMP forwarding",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "With ICMP forwarding disabled, TUN answers ping itself, so ping no longer shows the real latency.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Disable TCP keep-alive",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Disable UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "Discard the changes?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Disclaimer"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "This statement explains the nature, risks, and responsibilities of using the Software. It is not an additional term beyond GPL-3.0 and does not limit any right that license grants you, including to run, copy, modify, and distribute the Software. Where the two differ, GPL-3.0 prevails.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage(
      "Relation to the open-source license",
    ),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "I have read and understand this statement",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "To confirm you understand, read the following statement and check the box below:",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm the statement",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "This statement may be revised in later releases; each release carries the version that applies to it.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Changes to this statement",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Before using Flash (\"the Software\"), please read this statement carefully and make sure you understand it. Tapping \"Agree\" means you have read and understood what follows. If you do not want to continue, tap \"Exit\".",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "To the maximum extent permitted by applicable law, neither the developers nor any contributor shall be liable for any direct, indirect, incidental, special, punitive, or consequential damages arising from the use of or inability to use the Software, including but not limited to data loss, device damage, network failures, business interruption, lost profits, or any resulting legal dispute, even if advised of the possibility of such damages.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Limitation of liability",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "The Software is open source under the GPL-3.0 license. Under that license you may run, study, modify, and distribute it; when you distribute the Software or a modified version, you must provide its source code under GPL-3.0 as well and keep the original copyright notices.\n\nThird-party components in the Software, including the Clash.Meta core, follow their own licenses. The original authors are not responsible for any problem arising from versions modified or distributed by others.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Open-source license",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "The Software itself does not provide any proxy server, node, subscription, or network access service, and has no partnership, agency, or guarantee relationship with any provider of such services.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "The Software does not collect or upload your subscription URLs, node details, configuration content, visited websites, connection records, traffic content, or logs. This data stays on your device and the developers have no access to it.\n\nThe Software only reaches the network when you use a feature that needs it, such as fetching the subscription URL you provided when updating a profile, or contacting GitHub when checking for updates.\n\nThe Software includes no analytics or crash reporting service on any platform.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Data collection and privacy",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "You are responsible for making sure that using the Software is lawful where you live, and you alone bear the legal responsibility for everything you do with it and its consequences.\n\nThe subscriptions, nodes, and configurations you import are your own choice. Whether their source is lawful, their content is safe, and their service is reliable is a matter between you and their providers.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Your responsibility",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Enter the statement above",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "Does not match the statement",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "To confirm you understand, enter the following statement in full in the field below:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Restate the statement",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "The Software is an open-source network proxy client built on the Clash.Meta (mihomo) core. It only provides local tooling such as configuration management, rule-based routing, and traffic forwarding.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Nature of the software",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Subscription links, configuration files, rule sets, scripts, external resources, and external links are all provided by third parties. The developers cannot and do not review or guarantee their legality, accuracy, security, or availability.\n\nAny data leak, financial loss, account ban, or other loss caused by third-party content is to be settled between you and the third party; the developers bear no responsibility for it.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Third-party content",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "Any commercial activity anyone carries out with the Software, including paid distribution, bundled sales, or use as part of a commercial service, is unrelated to the Software\'s developers, who do not endorse, support, or guarantee it.\n\nYou are responsible for complying with the laws where you live, and you bear the consequences of any unlawful use of the Software.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage("About use"),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "The Software is provided \"as is\" and \"as available\", without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, non-infringement, uninterrupted availability, freedom from errors, or freedom from security vulnerabilities.\n\nThe developers do not guarantee that the Software will meet your needs or that it will run without interruption or error.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "No warranty",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Disconnected"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "New version found",
    ),
    "dnsCacheCleared": MessageLookupByLibrary.simpleMessage(
      "DNS cache cleared",
    ),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Without this entry, TUN hijacks every DNS query to port 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS hijacking"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS mode"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Entries added here replace the DNS of every URL and file profile; anything not added keeps the profile\'s own setting. Custom profiles set their DNS in their content.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS queries"),
    "docked": MessageLookupByLibrary.simpleMessage("Docked"),
    "domain": MessageLookupByLibrary.simpleMessage("Domain"),
    "done": MessageLookupByLibrary.simpleMessage("Done"),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Download bandwidth",
    ),
    "downloadingUpdate": MessageLookupByLibrary.simpleMessage(
      "Downloading update",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Duration"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("Edit dashboard"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Edit global rules",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Edit proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("Edit proxy group"),
    "editRule": MessageLookupByLibrary.simpleMessage("Edit rule"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Edit SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Editor unavailable",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Took"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("Empty fallback"),
    "emptyTip": m26,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "enabled": MessageLookupByLibrary.simpleMessage("Enabled"),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Error details"),
    "es": MessageLookupByLibrary.simpleMessage("Spanish"),
    "exclude": MessageLookupByLibrary.simpleMessage("Hide from recent tasks"),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Excluded destination ports",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("Exclude filter"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Excluded interfaces",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Excluded source ports",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "When connected to Wi-Fi with an excluded SSID, the app\'s running state switches automatically.",
    ),
    "excludeUid": MessageLookupByLibrary.simpleMessage("Excluded user IDs"),
    "existsTip": m27,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage("Exit full screen"),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Exit nodes"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Expected status"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Expiration time"),
    "exportCertificate": MessageLookupByLibrary.simpleMessage(
      "Export certificate",
    ),
    "exportFile": MessageLookupByLibrary.simpleMessage("Export file"),
    "exportHar": MessageLookupByLibrary.simpleMessage("Export HAR"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export logs"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Export successful"),
    "extend": MessageLookupByLibrary.simpleMessage("Extend"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Extend mode"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Extend script"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "External controller",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "The external controller lets you control the core on port 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "External controller secret",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("External link"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Extra large"),
    "fade": MessageLookupByLibrary.simpleMessage("Fade"),
    "failedCount": m28,
    "failedItem": m29,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fake-IP filter"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "These domains get real IPs instead of Fake-IPs. In whitelist mode, only they get Fake-IPs.",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Fake-IP filter mode",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fake-IP range"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Fake-IP range (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("Fake-IP TTL"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Used instead of Nameserver when the fallback filter treats its answer as polluted.",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback filter"),
    "fallbackFilterDomainDesc": MessageLookupByLibrary.simpleMessage(
      "These domains are resolved by Fallback directly.",
    ),
    "fallbackFilterGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Domains in these GeoSite categories are resolved by Fallback directly.",
    ),
    "fallbackFilterIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "When Nameserver returns an IP in these ranges, the Fallback answer is used.",
    ),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "The file has been modified. Save the changes?",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("Filter"),
    "filters": MessageLookupByLibrary.simpleMessage("Filters"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find process"),
    "floating": MessageLookupByLibrary.simpleMessage("Floating"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Follow profile"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Follow system"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Font family"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Size"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Force DNS mapping",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Force DNS mapping also sniffs connections whose domain came from a DNS mapping.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Force domains"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Force domains are sniffed too; other connections that already have a domain are left alone.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to force restart the core?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("French"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Entries added here replace the setting of every profile; anything not added keeps the profile\'s own setting, or the core default when the profile has none.",
    ),
    "generateCertificate": MessageLookupByLibrary.simpleMessage(
      "Generate certificate",
    ),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m30,
    "geoUpdated": m31,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo low-memory mode",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Download"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Go to added rules configuration",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Go to script configuration",
    ),
    "grid": MessageLookupByLibrary.simpleMessage("Grid"),
    "groupBy": MessageLookupByLibrary.simpleMessage("Group by"),
    "groupCount": m32,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("groups"),
    "groupTimeoutCount": m33,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Cache the changes?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Hash by inbound user",
    ),
    "headerRewrite": MessageLookupByLibrary.simpleMessage("Header rewrite"),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Health check"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Helper service unavailable; TUN mode cannot be enabled. Reinstall Flash to restore it.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Hide from list"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Hide IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Hide password"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Hide timed-out proxies",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Hop interval"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostname": MessageLookupByLibrary.simpleMessage("Hostname"),
    "hotkeyConflictWith": m34,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Global hotkeys work even while the window is hidden. Tap an action to record its key combination.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Hotkey management",
    ),
    "hotkeyNeedsModifier": m35,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Not set"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Not registered, it may be taken by another app",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("hours"),
    "hoursAgo": m36,
    "hoursAgoShort": m37,
    "http2": MessageLookupByLibrary.simpleMessage("HTTP/2"),
    "httpBodyNotKept": MessageLookupByLibrary.simpleMessage(
      "Not recorded while memory was short.",
    ),
    "httpBodyProtobufGuess": MessageLookupByLibrary.simpleMessage(
      "Read as Protobuf without its schema: field numbers only, and the types are guesses.",
    ),
    "httpBodyTruncated": MessageLookupByLibrary.simpleMessage(
      "Only the start of this body was recorded.",
    ),
    "httpBodyUndecoded": m38,
    "httpCapture": MessageLookupByLibrary.simpleMessage("HTTP capture"),
    "httpCaptureDesc": MessageLookupByLibrary.simpleMessage(
      "Records requests to the hosts listed under Hostname, to view in connection details. Records stay in memory only.",
    ),
    "httpCaptureLimit": MessageLookupByLibrary.simpleMessage("Maximum records"),
    "httpCaptureLimitDesc": m39,
    "httpCaptureNoHosts": MessageLookupByLibrary.simpleMessage(
      "No host is listed, so nothing is recorded. Add hosts under Hostname on the MITM page, or from the details of a connection.",
    ),
    "httpCaptureOff": MessageLookupByLibrary.simpleMessage("Capture is off"),
    "httpExportPrivate": MessageLookupByLibrary.simpleMessage(
      "A request can carry cookies, tokens, passwords and form contents. Check what you share, and with whom.",
    ),
    "httpExportPrivateTitle": MessageLookupByLibrary.simpleMessage(
      "Contains private data",
    ),
    "httpRequestCleared": MessageLookupByLibrary.simpleMessage(
      "This request is no longer kept",
    ),
    "httpRequests": MessageLookupByLibrary.simpleMessage("HTTP requests"),
    "httpRequestsMissing": MessageLookupByLibrary.simpleMessage(
      "Requests made before capture was on, or since cleared, are not listed.",
    ),
    "httpsDecryption": MessageLookupByLibrary.simpleMessage("HTTPS decryption"),
    "hue": MessageLookupByLibrary.simpleMessage("Hue"),
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("Icon records"),
    "iconSets": MessageLookupByLibrary.simpleMessage("Icon sets"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "No icon sets yet. Add them in Custom profile resources → Icon sets",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon style"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("Filled"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Hidden"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Plain"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("Icon URL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore battery optimization",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "This file is not a config that can be imported",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "Importing replaces the proxy groups, rules and settings this profile has now",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("Import from file"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("Import from link"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "inProgress": MessageLookupByLibrary.simpleMessage("In progress"),
    "inbound": MessageLookupByLibrary.simpleMessage("Inbound"),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Included interfaces",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Only traffic arriving on included interfaces goes through TUN, and excluded interfaces no longer apply.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("Included user IDs"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Never expires"),
    "infoAbout": MessageLookupByLibrary.simpleMessage("About"),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Startup failed"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "Flash ran into an error while starting and can\'t continue. Copy the details to report the problem. If it keeps happening, clearing the data usually lets the app start again.",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("Initiator"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("From"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Enter the proxy group name",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Enter the rule content",
    ),
    "installCertificate": MessageLookupByLibrary.simpleMessage(
      "Install to system",
    ),
    "installCertificateSuccess": MessageLookupByLibrary.simpleMessage(
      "Certificate installed",
    ),
    "installedAppsPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "The app list permission was denied, so installed apps cannot be listed. Please grant it manually in system settings.",
    ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "This system hides the installed app list until the permission is granted. Authorize it to configure the per-app proxy.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "App list permission required",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage("Installed fonts"),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Smart selection",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Interface name"),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Outbound interface",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Clear"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("Custom"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Follow config",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Intranet IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Invalid backup file",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Enter an IP range in CIDR form such as 192.168.0.0/16",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "A DSCP mark cannot exceed 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Enter a domain or an IP address",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "Not a valid icon set",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "Not a subscription link or a proxy share link",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Enter an address and port such as 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Only tcp or udp is supported",
    ),
    "invalidOfCount": m40,
    "invalidPolicy": m41,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Enter a port or a range such as 443 or 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "This QR code doesn\'t contain a profile link",
    ),
    "invalidProxy": m42,
    "invalidProxyProvider": m43,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Enter numbers or ranges such as 80 or 8000-9000, separated by /",
    ),
    "invalidRuleSet": m44,
    "invalidSubRule": m45,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP address"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Abuse history"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Flags"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Organization"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t determine the IP type",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Good"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Level"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Normal"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("Check again"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("Risky"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Quality"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Answered by"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Sources"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "Different outbound IP",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("No type"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage("Rate limited"),
    "ipType": MessageLookupByLibrary.simpleMessage("Type"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Business"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Data center"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Mobile network"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Residential"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Unknown type"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("IP version"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "IPv6 traffic is received only while IPv6 is on.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("IPv6 timeout (ms)"),
    "itemsCount": m46,
    "ja": MessageLookupByLibrary.simpleMessage("Japanese"),
    "justNow": MessageLookupByLibrary.simpleMessage("Just now"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "TCP keep-alive idle",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "TCP keep-alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "ko": MessageLookupByLibrary.simpleMessage("Korean"),
    "label": MessageLookupByLibrary.simpleMessage("Label"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "large": MessageLookupByLibrary.simpleMessage("Large"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Last updated"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "Launch did not finish",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "The app exited unexpectedly while it was starting up last time. Automatic setup was skipped for this launch; you can start it manually to retry.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "lineIssueTip": m47,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Word wrap"),
    "link": MessageLookupByLibrary.simpleMessage("Link"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Listen routing mark",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "Listen routing mark works only on Linux.",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage("Live connections"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localImage": MessageLookupByLibrary.simpleMessage("Local image"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Local network permission denied: using the gvisor stack, LAN is unreachable.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Local proxies"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Location permission was denied, so the current Wi-Fi name cannot be read. Please enable location permission manually in system settings.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "The system requires location permission to read the Wi-Fi name. On Android choose \"Allow all the time\", otherwise the Wi-Fi name cannot be read while the app is in the background.",
    ),
    "locationPermissionGuide": m48,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location permission required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Log"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Log level"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Turning off Logcat hides the logs entry.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Logs and diagnostics",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("Logs test"),
    "loopback": MessageLookupByLibrary.simpleMessage("UWP loopback exemption"),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "mapLocal": MessageLookupByLibrary.simpleMessage("Map local"),
    "matchCase": MessageLookupByLibrary.simpleMessage("Match case"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("Match source IP"),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchedRules": MessageLookupByLibrary.simpleMessage("Matched rules"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Max failures"),
    "maxLengthTip": m49,
    "maximize": MessageLookupByLibrary.simpleMessage("Maximize"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Resident memory",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("App & shared"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("Heap idle"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("Heap in use"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "Core is not running",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Runtime overhead",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("Goroutine stacks"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Estimated from process resident memory; it may differ from what the system reports.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "The Core runs inside the app process. Its share is estimated from runtime stats, and the rest counts as app and shared memory.",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory info"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Memory the app and the core use",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("Memory released"),
    "memoryReleasedSize": m50,
    "messageTest": MessageLookupByLibrary.simpleMessage("Message test"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "This is a message.",
    ),
    "method": MessageLookupByLibrary.simpleMessage("Method"),
    "minimize": MessageLookupByLibrary.simpleMessage("Minimize"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on exit"),
    "minutes": MessageLookupByLibrary.simpleMessage("minutes"),
    "minutesAgo": m51,
    "minutesAgoShort": m52,
    "mitm": MessageLookupByLibrary.simpleMessage("MITM"),
    "mitmAddLocalFile": MessageLookupByLibrary.simpleMessage(
      "Add a local file",
    ),
    "mitmAddMapLocalRule": MessageLookupByLibrary.simpleMessage(
      "Add a map local rule",
    ),
    "mitmAddRejectRule": MessageLookupByLibrary.simpleMessage(
      "Add a reject rule",
    ),
    "mitmAttachments": MessageLookupByLibrary.simpleMessage("Attachments"),
    "mitmAttachmentsDesc": MessageLookupByLibrary.simpleMessage(
      "Lines refer to attachments by file name, as in script-path=a.js.",
    ),
    "mitmCertificateAndroidReadyTip": MessageLookupByLibrary.simpleMessage(
      "Only apps that trust user certificates, mostly browsers, are decrypted.",
    ),
    "mitmCertificateExportTip": MessageLookupByLibrary.simpleMessage(
      "Export it and trust it on the devices you want to decrypt.",
    ),
    "mitmCertificateLinuxTip": MessageLookupByLibrary.simpleMessage(
      "Flatpak browsers need the exported certificate imported by hand.",
    ),
    "mitmCertificateSavedTip": m53,
    "mitmCertutilMissing": m54,
    "mitmClientRefusedCertificate": MessageLookupByLibrary.simpleMessage(
      "The client refused the certificate. Install the CA, or exclude this host if the app pins its certificate.",
    ),
    "mitmDecryptHost": MessageLookupByLibrary.simpleMessage(
      "Decrypt this host",
    ),
    "mitmDecryptHostTip": m55,
    "mitmEnableTip": MessageLookupByLibrary.simpleMessage(
      "Flash will be able to read everything sent to the decrypted hosts, cookies and passwords included. Turn this on only for hosts you mean to rewrite.",
    ),
    "mitmExcludeHost": MessageLookupByLibrary.simpleMessage(
      "Exclude from decryption",
    ),
    "mitmExcludeHostTip": m56,
    "mitmFileTooLarge": m57,
    "mitmHostnameDesc": MessageLookupByLibrary.simpleMessage(
      "A leading - excludes a host, and the first match decides.",
    ),
    "mitmIgnoredLines": MessageLookupByLibrary.simpleMessage("Ignored lines"),
    "mitmInstallSystemCaTip": MessageLookupByLibrary.simpleMessage(
      "Root was found, so the certificate goes into the system\'s trusted certificates as a FlClash MITM CA module for Magisk, KernelSU or APatch. Every app on this device will then trust it, and anyone holding its private key could decrypt this device\'s HTTPS traffic. To undo it, regenerate the certificate or remove the module in the root manager and restart. If root is denied, it is installed as a user certificate instead.",
    ),
    "mitmInstallUserCaTip": MessageLookupByLibrary.simpleMessage(
      "No root was found, so the certificate can only be installed as a user certificate. Only apps that trust user certificates, mostly browsers, are decrypted; other apps fail on the hosts you list, so leave those hosts out. On Android 11 and later you finish the install yourself in system settings.",
    ),
    "mitmMissingStores": m58,
    "mitmModule": MessageLookupByLibrary.simpleMessage("Module"),
    "mitmModuleInvalid": MessageLookupByLibrary.simpleMessage(
      "This is not a Surge module, a Loon plugin, a Quantumult X snippet or a Stash override",
    ),
    "mitmModuleRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Routing rules go in front of the profile’s own.",
    ),
    "mitmModuleScriptsChanged": m59,
    "mitmModuleSystemTip": m60,
    "mitmModules": MessageLookupByLibrary.simpleMessage("Modules"),
    "mitmNewModule": MessageLookupByLibrary.simpleMessage("New module"),
    "mitmOldCertificateLeftTip": m61,
    "mitmOldSystemCertificateLeftTip": m62,
    "mitmRemoveOldCertificateTip": m63,
    "mitmRootPendingReboot": MessageLookupByLibrary.simpleMessage(
      "The certificate takes effect after the device restarts.",
    ),
    "mitmRootUntilReboot": MessageLookupByLibrary.simpleMessage(
      "No Magisk, KernelSU or APatch was found to keep the certificate. Install it again after the device restarts.",
    ),
    "mitmRoutingRules": MessageLookupByLibrary.simpleMessage("Routing rules"),
    "mitmRuleCopiedForStash": MessageLookupByLibrary.simpleMessage(
      "This module is a Stash override, so the rule was copied for you to add by hand.",
    ),
    "mitmRunScript": MessageLookupByLibrary.simpleMessage("Run now"),
    "mitmScriptNoOutput": MessageLookupByLibrary.simpleMessage(
      "The script finished without output",
    ),
    "mitmScriptRisk": MessageLookupByLibrary.simpleMessage(
      "Its scripts read and change the traffic of the hosts they match, cookies and tokens included, and can send requests of their own. Turn it on only if you trust where it comes from.",
    ),
    "mitmScriptRiskTitle": MessageLookupByLibrary.simpleMessage(
      "Run this module\'s scripts?",
    ),
    "mitmSkipConditional": MessageLookupByLibrary.simpleMessage(
      "Conditional rewrites are not supported",
    ),
    "mitmSkipDisabled": MessageLookupByLibrary.simpleMessage(
      "Turned off by an argument",
    ),
    "mitmSkipEvent": MessageLookupByLibrary.simpleMessage(
      "This event is not supported",
    ),
    "mitmSkipJq": MessageLookupByLibrary.simpleMessage(
      "jq rewrites are not supported",
    ),
    "mitmSkipJsonBody": MessageLookupByLibrary.simpleMessage(
      "JSON body rewrites are not supported",
    ),
    "mitmSkipNotDownloaded": MessageLookupByLibrary.simpleMessage(
      "Its file has not been downloaded",
    ),
    "mitmSkipPolicy": MessageLookupByLibrary.simpleMessage(
      "Only the DIRECT and REJECT policies are supported",
    ),
    "mitmSkipRawHeader": MessageLookupByLibrary.simpleMessage(
      "Rewriting all headers as one text is not supported",
    ),
    "mitmSkipRelativeData": MessageLookupByLibrary.simpleMessage(
      "The file this line names is not attached; use a URL or attach it",
    ),
    "mitmSkipRule": MessageLookupByLibrary.simpleMessage(
      "This rule type is not supported",
    ),
    "mitmSkipScriptType": MessageLookupByLibrary.simpleMessage(
      "This script type is not supported",
    ),
    "mitmSkipSection": m64,
    "mitmSkipSetting": MessageLookupByLibrary.simpleMessage(
      "This setting is not supported",
    ),
    "mitmSkipUnreadable": MessageLookupByLibrary.simpleMessage(
      "This line cannot be read",
    ),
    "mitmSystemStoreFailed": MessageLookupByLibrary.simpleMessage(
      "Adding the certificate to the system\'s trusted roots failed",
    ),
    "mitmTrustChecking": MessageLookupByLibrary.simpleMessage("Checking…"),
    "mitmTrustNotInstalled": MessageLookupByLibrary.simpleMessage(
      "Not installed",
    ),
    "mitmTrustReady": MessageLookupByLibrary.simpleMessage("Trusted"),
    "mitmTrustUntrusted": MessageLookupByLibrary.simpleMessage(
      "Not fully trusted",
    ),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed port"),
    "mixedPortUnavailable": m65,
    "mixedPortUnavailableProxyUnchanged": m66,
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeIcon": MessageLookupByLibrary.simpleMessage("Monochrome icon"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "monthsAgo": m67,
    "monthsAgoShort": m68,
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "mountAlsoMounts": m69,
    "mountApplyBlocked": MessageLookupByLibrary.simpleMessage(
      "Mounts could not be applied. Flash currently rejects every connection routed through it. Read the status again before unmounting or reapplying the profile.",
    ),
    "mountApplyBlockedConfirmed": MessageLookupByLibrary.simpleMessage(
      "Mounts are confirmed not to have been applied. Flash still rejects every connection routed through it. You can unmount subscriptions or reapply the profile.",
    ),
    "mountApplyFailed": MessageLookupByLibrary.simpleMessage(
      "Mounts were saved but could not be applied to the running profile.",
    ),
    "mountApplyKept": MessageLookupByLibrary.simpleMessage(
      "Mounts could not be applied. The last confirmed running profile is still in use.",
    ),
    "mountApplying": MessageLookupByLibrary.simpleMessage(
      "Mounts saved. Applying…",
    ),
    "mountAutoDesc": MessageLookupByLibrary.simpleMessage(
      "These groups collect and filter subscription nodes using their existing settings. Choose additional proxy groups below if needed.",
    ),
    "mountAutoSubtitle": MessageLookupByLibrary.simpleMessage(
      "Use existing group collection settings",
    ),
    "mountBaseDirect": MessageLookupByLibrary.simpleMessage(
      "When no nodes are selectable, this group uses a direct connection as specified by the original profile.",
    ),
    "mountBaseFallback": m70,
    "mountBlockDesc": MessageLookupByLibrary.simpleMessage(
      "If this group has no selectable nodes, its connections are blocked instead of sent directly.",
    ),
    "mountBlockTag": MessageLookupByLibrary.simpleMessage("Block when empty"),
    "mountCardFailed": m71,
    "mountCardUnreadable": MessageLookupByLibrary.simpleMessage(
      "Could not read mount status",
    ),
    "mountChooseSources": MessageLookupByLibrary.simpleMessage(
      "Choose subscriptions",
    ),
    "mountDeleteSourceBlocked": MessageLookupByLibrary.simpleMessage(
      "This subscription or an affected profile has unconfirmed operations. Read the status again before deleting.",
    ),
    "mountDeleteSourceBody": m72,
    "mountDeleteSourceConfirm": MessageLookupByLibrary.simpleMessage(
      "Delete and unmount",
    ),
    "mountDeleteSourceDone": MessageLookupByLibrary.simpleMessage(
      "Subscription deleted and unmounted",
    ),
    "mountDeleteSourceProgress": MessageLookupByLibrary.simpleMessage(
      "Deleting and unmounting…",
    ),
    "mountDeleteSourceTitle": MessageLookupByLibrary.simpleMessage(
      "Delete subscription and unmount?",
    ),
    "mountDeleteSourceUnknown": MessageLookupByLibrary.simpleMessage(
      "Subscription deletion and unmounting are unconfirmed. Read the status again before deleting or mounting again.",
    ),
    "mountDescription": MessageLookupByLibrary.simpleMessage(
      "Choose imported subscriptions to add their nodes to this profile. Its rules, DNS, and group structure stay unchanged, as does dedicated Tailscale routing. Original files are not rewritten.",
    ),
    "mountEmptyDesc": MessageLookupByLibrary.simpleMessage(
      "Import a subscription from a link, then choose it as a node source for this profile.",
    ),
    "mountEmptyTitle": MessageLookupByLibrary.simpleMessage(
      "No subscriptions to mount",
    ),
    "mountEntry": MessageLookupByLibrary.simpleMessage(
      "Mount subscription nodes",
    ),
    "mountEntryMenu": MessageLookupByLibrary.simpleMessage(
      "Mount subscription nodes…",
    ),
    "mountExtraDesc": MessageLookupByLibrary.simpleMessage(
      "You can also add these subscription nodes to other proxy groups. Leave this unselected to use only the collection settings above. This choice applies to all subscriptions mounted on this profile.",
    ),
    "mountExtraTitle": MessageLookupByLibrary.simpleMessage(
      "Additional groups (optional)",
    ),
    "mountFetchFailed": MessageLookupByLibrary.simpleMessage(
      "Could not fetch nodes from this subscription. Try again.",
    ),
    "mountFilterNotice": MessageLookupByLibrary.simpleMessage(
      "This group’s existing inclusion and exclusion filters also apply to mounted nodes. The filters will not be changed.",
    ),
    "mountFormatHelp": MessageLookupByLibrary.simpleMessage(
      "You can mount imported remote Clash/mihomo subscriptions and remote subscriptions successfully converted by Flash’s existing importer. Only nodes are included, not subscription rules or DNS settings.",
    ),
    "mountGroupEmpty": m73,
    "mountGroupFiltered": MessageLookupByLibrary.simpleMessage(
      "Nodes were fetched, but the selected groups’ filters leave no selectable options. Check their filters.",
    ),
    "mountGroupNotSelected": MessageLookupByLibrary.simpleMessage(
      "Not selected",
    ),
    "mountGroupSelected": MessageLookupByLibrary.simpleMessage("Selected"),
    "mountGroupsChanged": MessageLookupByLibrary.simpleMessage(
      "Target groups have changed. Read and confirm them before saving.",
    ),
    "mountGroupsExcluded": m74,
    "mountGroupsExcludedNames": m75,
    "mountGroupsFailed": MessageLookupByLibrary.simpleMessage(
      "Could not read this profile’s groups. Read them again.",
    ),
    "mountGroupsTitle": MessageLookupByLibrary.simpleMessage(
      "Groups for these nodes",
    ),
    "mountHintCollectsAll": MessageLookupByLibrary.simpleMessage(
      "Collects nodes automatically",
    ),
    "mountHintCollectsProviders": MessageLookupByLibrary.simpleMessage(
      "Collects subscription nodes automatically",
    ),
    "mountHintFiltered": MessageLookupByLibrary.simpleMessage(
      "Auto-collected · Group filters apply",
    ),
    "mountImport": MessageLookupByLibrary.simpleMessage("Import subscription"),
    "mountImportHint": MessageLookupByLibrary.simpleMessage(
      "Return here after importing to choose the subscription. Your active profile will not change.",
    ),
    "mountLastUpdated": m76,
    "mountListFailed": MessageLookupByLibrary.simpleMessage(
      "Could not load subscriptions. Try again.",
    ),
    "mountMountedTag": MessageLookupByLibrary.simpleMessage("Mounted"),
    "mountNameSeparator": MessageLookupByLibrary.simpleMessage(", "),
    "mountNoGroupDesc": MessageLookupByLibrary.simpleMessage(
      "No group will be created and routing rules will not be changed automatically.",
    ),
    "mountNoGroupIsolatedDesc": MessageLookupByLibrary.simpleMessage(
      "None of the existing groups passed the mount-isolation checks. No group will be created, no direct-connection fallback will be added, and the original profile file will not be rewritten automatically.",
    ),
    "mountNoGroupIsolatedTitle": MessageLookupByLibrary.simpleMessage(
      "Current groups cannot receive mounts",
    ),
    "mountNoGroupTitle": MessageLookupByLibrary.simpleMessage(
      "This profile has no proxy group that can receive subscription nodes. Mounting cannot be completed yet.",
    ),
    "mountNodeCount": m77,
    "mountNodesRead": m78,
    "mountNodesReadAt": m79,
    "mountNodesUpdated": MessageLookupByLibrary.simpleMessage("Nodes updated"),
    "mountNotFetched": MessageLookupByLibrary.simpleMessage(
      "Nodes not fetched yet",
    ),
    "mountNotMounted": MessageLookupByLibrary.simpleMessage("Not mounted"),
    "mountPickDesc": MessageLookupByLibrary.simpleMessage(
      "This profile has no group that automatically collects subscription nodes. Choose the proxy groups that should receive them. Only the effective profile is updated; the original file is not rewritten.",
    ),
    "mountPickRequired": MessageLookupByLibrary.simpleMessage(
      "Choose at least one target group.",
    ),
    "mountPickTitle": MessageLookupByLibrary.simpleMessage(
      "Choose target groups",
    ),
    "mountPillFailedSemantics": MessageLookupByLibrary.simpleMessage(
      "a subscription update failed",
    ),
    "mountPillSemantics": m80,
    "mountProviderUpdateRefused": m81,
    "mountProviderUpdateRefusedUnconfirmed": m82,
    "mountReadAgain": MessageLookupByLibrary.simpleMessage("Read again"),
    "mountReadStatus": MessageLookupByLibrary.simpleMessage(
      "Read status again",
    ),
    "mountRunningBlocked": MessageLookupByLibrary.simpleMessage(
      "Flash currently rejects every connection routed through it. Read the status again.",
    ),
    "mountRunningBlockedConfirmed": MessageLookupByLibrary.simpleMessage(
      "Flash still rejects every connection routed through it.",
    ),
    "mountRunningKept": MessageLookupByLibrary.simpleMessage(
      "The last confirmed running profile is still in use.",
    ),
    "mountSameName": MessageLookupByLibrary.simpleMessage(
      "When node names conflict across sources, the subscription name is added as a suffix. This may affect exact-match or end-of-name filters. Check the group results.",
    ),
    "mountSave": MessageLookupByLibrary.simpleMessage("Save mounts"),
    "mountSavedUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Mounts saved; application is not yet confirmed.",
    ),
    "mountSaving": MessageLookupByLibrary.simpleMessage("Saving mounts…"),
    "mountSelectionLost": MessageLookupByLibrary.simpleMessage(
      "The previously selected node is no longer in this subscription. Choose another node.",
    ),
    "mountSourceEmpty": MessageLookupByLibrary.simpleMessage(
      "Subscription updated. It currently has no nodes.",
    ),
    "mountSourceGone": MessageLookupByLibrary.simpleMessage(
      "The original subscription is unavailable. Choose a node source again.",
    ),
    "mountSourceIsolatedOnly": MessageLookupByLibrary.simpleMessage(
      "All nodes in this subscription were excluded by the mount-isolation checks and cannot be mounted. Their settings were not changed.",
    ),
    "mountSourceNoNodeList": MessageLookupByLibrary.simpleMessage(
      "This subscription does not provide a mountable node list. Check its format.",
    ),
    "mountSourceRelayOnly": MessageLookupByLibrary.simpleMessage(
      "All nodes in this subscription route through Tailscale and cannot be mounted. Their routing settings were not changed.",
    ),
    "mountSourceTailscaleOnly": MessageLookupByLibrary.simpleMessage(
      "This subscription contains only Tailscale nodes and cannot be mounted.",
    ),
    "mountTailscaleExcluded": MessageLookupByLibrary.simpleMessage(
      "Tailscale nodes were excluded from ordinary mounts.",
    ),
    "mountTarget": m83,
    "mountTypeFallback": MessageLookupByLibrary.simpleMessage("Failover"),
    "mountTypeFallbackDesc": MessageLookupByLibrary.simpleMessage(
      "This group sends connectivity checks and switches nodes when needed, following the original profile settings.",
    ),
    "mountTypeLoadBalance": MessageLookupByLibrary.simpleMessage(
      "Load balancing",
    ),
    "mountTypeLoadBalanceDesc": MessageLookupByLibrary.simpleMessage(
      "This group checks nodes and distributes connections according to the original profile settings.",
    ),
    "mountTypeSelect": MessageLookupByLibrary.simpleMessage("Manual selection"),
    "mountTypeSelectDesc": MessageLookupByLibrary.simpleMessage(
      "You choose which node to use.",
    ),
    "mountTypeUnknownDesc": MessageLookupByLibrary.simpleMessage(
      "Behavior follows the original group settings",
    ),
    "mountTypeUrlTest": MessageLookupByLibrary.simpleMessage(
      "Latency selection",
    ),
    "mountTypeUrlTestDesc": MessageLookupByLibrary.simpleMessage(
      "This group sends connectivity checks and selects a node automatically based on the results.",
    ),
    "mountUnchanged": MessageLookupByLibrary.simpleMessage(
      "Mounts were not changed. Try again.",
    ),
    "mountUnknown": MessageLookupByLibrary.simpleMessage(
      "The mount result is unconfirmed. Read the status again before saving or unmounting.",
    ),
    "mountUnmount": MessageLookupByLibrary.simpleMessage("Unmount"),
    "mountUnmountBody": m84,
    "mountUnmountManyBody": m85,
    "mountUnmountManyTitle": MessageLookupByLibrary.simpleMessage(
      "Unmount these subscriptions?",
    ),
    "mountUnmountTitle": MessageLookupByLibrary.simpleMessage(
      "Unmount this subscription?",
    ),
    "mountUnmountUnknown": MessageLookupByLibrary.simpleMessage(
      "Unmounting is unconfirmed. Read the status again first.",
    ),
    "mountUnmounted": MessageLookupByLibrary.simpleMessage("Unmounted"),
    "mountUnmounting": MessageLookupByLibrary.simpleMessage("Unmounting…"),
    "mountUnsupportedExcluded": m86,
    "mountUpdateFailedInUse": MessageLookupByLibrary.simpleMessage(
      "Update failed. The last successfully fetched nodes are still in use.",
    ),
    "mountUpdateFailedKept": MessageLookupByLibrary.simpleMessage(
      "Update failed. The last successfully fetched nodes were kept, but their current use is not confirmed.",
    ),
    "mountUpdateFailedKeptBlocked": MessageLookupByLibrary.simpleMessage(
      "Update failed. The last successfully fetched nodes were kept.",
    ),
    "mountUpdateNodes": MessageLookupByLibrary.simpleMessage("Update nodes"),
    "mountUpdateNodesOf": m87,
    "mountUpdateReadEmptyNotApplied": MessageLookupByLibrary.simpleMessage(
      "Subscription read. It currently has no nodes. The new result has not been applied.",
    ),
    "mountUpdateReadNotAppliedBlocked": MessageLookupByLibrary.simpleMessage(
      "New nodes were read but have not been applied. Flash currently rejects every connection routed through it. Read the status again.",
    ),
    "mountUpdateReadNotAppliedBlockedConfirmed":
        MessageLookupByLibrary.simpleMessage(
          "New nodes were read but have not been applied. Flash still rejects every connection routed through it.",
        ),
    "mountUpdateReadNotAppliedKept": MessageLookupByLibrary.simpleMessage(
      "New nodes were read but have not been applied. The last confirmed running profile is still in use.",
    ),
    "mountUpdateTitle": MessageLookupByLibrary.simpleMessage(
      "Update subscription mounts?",
    ),
    "mountUpdated": MessageLookupByLibrary.simpleMessage(
      "Subscription node mounts updated",
    ),
    "mountUpdatingNodes": MessageLookupByLibrary.simpleMessage(
      "Updating nodes…",
    ),
    "mountedCount": m88,
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "The default DNS servers, such as 223.5.5.5, tls://1.1.1.1 or https://dns.google/dns-query.",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Matching domains use the DNS server given here instead of Nameserver and Fallback.",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("Bottom bar"),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkAccessDeniedError": m89,
    "networkBadResponseError": m90,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "The request was cancelled",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t connect to the server. Check your network connection or proxy settings",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t resolve the server address. Check that the URL is correct and DNS is working",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("Network name"),
    "networkNotFoundError": m91,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Too many requests (HTTP 429). Wait a moment and try again",
    ),
    "networkRequestFailed": m92,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Network secret"),
    "networkServerError": m93,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network speed"),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("Traffic takeover"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "The request timed out. Check your network or proxy, then try again",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Secure connection failed. The server\'s certificate may be invalid, or the connection is being intercepted",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Network type"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Next match"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "noData": MessageLookupByLibrary.simpleMessage("No data"),
    "noInfo": MessageLookupByLibrary.simpleMessage("No info"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Don\'t remind me again",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No-network apps"),
    "noResolve": MessageLookupByLibrary.simpleMessage("Don\'t resolve IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Don\'t resolve hostname",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "No matching results",
    ),
    "nodes": MessageLookupByLibrary.simpleMessage("Nodes"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "This external resource is not a text file",
    ),
    "none": MessageLookupByLibrary.simpleMessage("None"),
    "notRunning": MessageLookupByLibrary.simpleMessage("Not running"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "The current proxy group cannot be selected",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Sync interval (minutes)",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Add a profile to get started",
    ),
    "nullTip": m94,
    "numberRangeTip": m95,
    "numberTip": m96,
    "obfs": MessageLookupByLibrary.simpleMessage("Obfuscation"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Obfuscation host"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Obfuscation mode"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("Obfuscation parameter"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage(
      "Obfuscation password",
    ),
    "onDemand": MessageLookupByLibrary.simpleMessage("On demand"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Only count proxy traffic",
    ),
    "openSettings": MessageLookupByLibrary.simpleMessage("Open settings"),
    "optional": MessageLookupByLibrary.simpleMessage("Optional"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "originalUrl": MessageLookupByLibrary.simpleMessage("Original URL"),
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Other contributors",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Outbound"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Exit"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("Outbound IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound mode"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Override destination",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage("Override entries"),
    "overview": MessageLookupByLibrary.simpleMessage("Overview"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Parse pure IP"),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "peers": MessageLookupByLibrary.simpleMessage("Peers"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Choose from album"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("Pin window"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Please bind WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Please enter a script name",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Plugin"),
    "pluginCipher": MessageLookupByLibrary.simpleMessage("Plugin cipher"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Plugin host"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Plugin mode"),
    "pluginPassword": MessageLookupByLibrary.simpleMessage("Plugin password"),
    "pluginPath": MessageLookupByLibrary.simpleMessage("Plugin path"),
    "pluginUsername": MessageLookupByLibrary.simpleMessage("Plugin username"),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Port hopping"),
    "portTip": m97,
    "portValue": m98,
    "ports": MessageLookupByLibrary.simpleMessage("Ports"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Pre-shared key"),
    "preferred": MessageLookupByLibrary.simpleMessage("Preferred"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Press a key combination",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("Previous match"),
    "privateKey": MessageLookupByLibrary.simpleMessage("Private key"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Private key passphrase",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Process"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Please enter a valid interval"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Please enter the auto-update interval",
        ),
    "profileDaysLeft": m99,
    "profileExpiresIn": m100,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "The profile has been modified. Turn off auto update?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter the profile name",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Applies to this profile only; anything not added uses its default.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Applies to this profile only and takes precedence over the TUN override entries in the network settings.",
    ),
    "profileUpdatedAt": m101,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid profile URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Please enter the profile URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Sort profiles"),
    "project": MessageLookupByLibrary.simpleMessage("FlClash upstream project"),
    "protocol": MessageLookupByLibrary.simpleMessage("Protocol"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("Protocol parameter"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("Protocol version"),
    "providerInUse": m102,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Only remote providers are supported",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("External resources"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesCount": m103,
    "proxiesProfileLabel": m104,
    "proxiesRemovedTip": m105,
    "proxiesReplacedTip": m106,
    "proxyChains": MessageLookupByLibrary.simpleMessage("Proxy chain"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Proxy group"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy group is empty",
    ),
    "proxyGroupInUse": m107,
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Groups show up here once the core starts",
    ),
    "proxyGroupsCount": m108,
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy providers"),
    "proxyServerNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resolves proxy server hostnames only.",
    ),
    "proxyServerNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Matching proxy server hostnames use the DNS server given here instead of Proxy Server Nameserver.",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Proxy type"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Prune cache"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Public key"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Pure black"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure black mode"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR code"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scan a QR code to obtain a profile",
    ),
    "qrcodeTooLongTip": MessageLookupByLibrary.simpleMessage(
      "This link is too long for a QR code. Use Copy link instead.",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("Quick actions"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Quick edit"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Recent requests"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Suggested"),
    "recordType": MessageLookupByLibrary.simpleMessage("Record type"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir port"),
    "redo": MessageLookupByLibrary.simpleMessage("Redo"),
    "regenerateCertificate": MessageLookupByLibrary.simpleMessage(
      "Regenerate certificate",
    ),
    "regenerateCertificateTip": MessageLookupByLibrary.simpleMessage(
      "The new certificate replaces the current one, which Flash takes out of this device\'s trusted roots where it can. Every other device that trusts the current one has to install the new one.",
    ),
    "regex": MessageLookupByLibrary.simpleMessage("Regex"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Release memory"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to release memory",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Remote destination",
    ),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Remote DNS resolution",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "replace": MessageLookupByLibrary.simpleMessage("Replace"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Replace all"),
    "request": MessageLookupByLibrary.simpleMessage("Request"),
    "requestBody": MessageLookupByLibrary.simpleMessage("Request body"),
    "requestHeaders": MessageLookupByLibrary.simpleMessage("Request headers"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Requests and updates",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Required"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "This page has changes. Are you sure you want to reset?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to reset?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Auto-update interval",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "The auto-update interval must be greater than 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Respect rules routes DNS connections by the rules and needs a Proxy Server Nameserver.",
    ),
    "response": MessageLookupByLibrary.simpleMessage("Response"),
    "responseBody": MessageLookupByLibrary.simpleMessage("Response body"),
    "responseCode": MessageLookupByLibrary.simpleMessage("Response code"),
    "responseHeaders": MessageLookupByLibrary.simpleMessage("Response headers"),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to restart the core?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restore"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("Restore all data"),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restore profiles only",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("Restore strategy"),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("Override"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Restore successful",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Result"),
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "root": MessageLookupByLibrary.simpleMessage("Root"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Route addresses"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Route exclude addresses",
    ),
    "routingMark": MessageLookupByLibrary.simpleMessage("Routing mark"),
    "ru": MessageLookupByLibrary.simpleMessage("Russian"),
    "rule": MessageLookupByLibrary.simpleMessage("Rule"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Match the full domain",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Match a domain keyword",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match a domain regex",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match a domain suffix",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Wildcard match; only * and ? are supported",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Match the DSCP mark (tproxy UDP inbound only)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match the destination port range",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match the IP\'s country code",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Match domains in Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound name",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound port",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound type",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Match the inbound username; separate multiple usernames with /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match the IP\'s ASN",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Match an IP address range; IP-CIDR6 is just an alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match an IP address range",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match an IP suffix range",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Match all requests, no conditions needed",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Match TCP or UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("Logical rule OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process name; matches the package name on Android",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process name regex; matches the package name on Android",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process name wildcard; only * and ? are supported",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Match by the full process path",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process path regex",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Match by process path wildcard; only * and ? are supported",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match the rematch name; separate multiple names with /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Reference a rule set; requires rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match the source IP\'s country code",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match the source IP\'s ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match a source IP address range",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match a source IP suffix range",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match the source port range",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Match into a sub-rule; mind the parentheses",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Match the Linux user ID",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Rule is empty"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "The rules must be a YAML list with one rule per item, such as - DOMAIN,example.com,DIRECT",
    ),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent direct",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Block DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Block proxy loopback",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("Block QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("Block STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN direct"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple and Microsoft direct",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule providers"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Rule set"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "The rule set has no usable entries",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "This mrs file cannot be read",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "The rule set mixes domains and IP ranges, so its type cannot be told",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule target"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "The rule must start with a supported type, such as DOMAIN,example.com,DIRECT",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Rules"),
    "rulesCount": m109,
    "runTime": MessageLookupByLibrary.simpleMessage("Run time"),
    "running": MessageLookupByLibrary.simpleMessage("Running"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage("Runtime config"),
    "safeMode": MessageLookupByLibrary.simpleMessage("Safe mode"),
    "safeModeAppTitle": m110,
    "saturation": MessageLookupByLibrary.simpleMessage("Saturation"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Save the changes?"),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Script mode: rewrites the whole profile with an extension script",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Scroll to selected",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("seconds"),
    "secondsCount": m111,
    "secretKey": MessageLookupByLibrary.simpleMessage("Key"),
    "sectionsInEffect": m112,
    "select": MessageLookupByLibrary.simpleMessage("Select"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Please select a rule set",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Please select a split strategy",
    ),
    "send": MessageLookupByLibrary.simpleMessage("Send"),
    "sendFromPhone": MessageLookupByLibrary.simpleMessage("Send from phone"),
    "sendFromPhoneConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Import the link from your phone?",
    ),
    "sendFromPhoneNoNetwork": MessageLookupByLibrary.simpleMessage(
      "This device is not connected to a local network",
    ),
    "sendFromPhonePageHint": MessageLookupByLibrary.simpleMessage(
      "Subscription link or proxy share link",
    ),
    "sendFromPhonePageSent": MessageLookupByLibrary.simpleMessage(
      "Sent. Confirm the import on the other device.",
    ),
    "sendFromPhonePageTitle": MessageLookupByLibrary.simpleMessage(
      "Send a link to Flash",
    ),
    "sendFromPhonePermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Receiving a link from your phone needs the Nearby devices permission, which lets Flash reach the local network. Turn it on in the app\'s settings.",
    ),
    "sendFromPhoneTip": MessageLookupByLibrary.simpleMessage(
      "Scan the code with your phone\'s camera and paste the link on the page that opens. Both devices need to be on the same network.",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Server"),
    "serviceAbnormalCount": m113,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage(
      "All available",
    ),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Available"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Blocked"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Check all"),
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("Coming soon"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "Disallowed ISP",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("Check failed"),
    "serviceManage": MessageLookupByLibrary.simpleMessage("Manage services"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Originals only",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Not checked"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Access restricted",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Shown on the dashboard",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("Service status"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("Unavailable"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Region not supported",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("settings"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsCount": m114,
    "shareLinkUnreadable": m115,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "No proxy could be read from the links",
    ),
    "shareQrcodeTip": MessageLookupByLibrary.simpleMessage(
      "Scan with Flash on another device to import this profile.",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Show"),
    "showLess": MessageLookupByLibrary.simpleMessage("Collapse"),
    "showMore": MessageLookupByLibrary.simpleMessage("Expand"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Stop button in notification",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Show password"),
    "sidebar": MessageLookupByLibrary.simpleMessage("Sidebar"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Silent launch"),
    "singleImport": MessageLookupByLibrary.simpleMessage("Single import"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Enter one link here; edit several from the quick edit of the list",
    ),
    "singleValueTip": m116,
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Skip certificate verification",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Skip domains"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Skip destination addresses",
    ),
    "skipServerCertVerify": MessageLookupByLibrary.simpleMessage(
      "Skip server certificate verification",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Skip source addresses",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Slide"),
    "sliders": MessageLookupByLibrary.simpleMessage("Sliders"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Protocols"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "socksPort": MessageLookupByLibrary.simpleMessage("SOCKS port"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Soft"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Special proxy"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Special rules"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Spectrum"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("Speed statistics"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("Split strategy"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Split strategy cannot be empty",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs are empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack mode"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Stack trace"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Standard mode: adds rules on top of the profile",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage(
      "Start from scratch",
    ),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Startup and background",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "With DNS off, the system DNS is used.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "stopUpdateDownloadTip": MessageLookupByLibrary.simpleMessage(
      "Stop downloading the update?",
    ),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping VPN…"),
    "strategy": MessageLookupByLibrary.simpleMessage("Strategy"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Strict route"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Strict route keeps traffic such as DNS from bypassing TUN, and with IPv6 off it blocks this device\'s IPv6 connections.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Subscription info",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Enter your password for sudo",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspended…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Switch profile"),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System apps"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Tab animation"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Tap the icon to retry",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("Tap to authorize"),
    "target": MessageLookupByLibrary.simpleMessage("Target"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrent"),
    "testInterval": MessageLookupByLibrary.simpleMessage("Test interval"),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test URL"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("Test when used"),
    "textScale": MessageLookupByLibrary.simpleMessage("Text scaling"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Text in the app will look like this",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme color"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme mode"),
    "tight": MessageLookupByLibrary.simpleMessage("Tight"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "timeToFirstByte": MessageLookupByLibrary.simpleMessage(
      "Time to first byte",
    ),
    "timeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Tinted"),
    "tip": MessageLookupByLibrary.simpleMessage("Tip"),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "tolerance": MessageLookupByLibrary.simpleMessage("Tolerance"),
    "tools": MessageLookupByLibrary.simpleMessage("Tools"),
    "torch": MessageLookupByLibrary.simpleMessage("Flashlight"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Downloaded"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Total traffic"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Uploaded"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("TProxy port"),
    "traffic": MessageLookupByLibrary.simpleMessage("Traffic"),
    "trafficPeak": m117,
    "trafficTotal": m118,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Traffic usage"),
    "transport": MessageLookupByLibrary.simpleMessage("Transport"),
    "transportHeaders": m119,
    "trustCertificate": MessageLookupByLibrary.simpleMessage(
      "Trust certificate",
    ),
    "tsAboutExit": MessageLookupByLibrary.simpleMessage("About exit settings"),
    "tsAboutRoutes": MessageLookupByLibrary.simpleMessage(
      "About subnet routes",
    ),
    "tsAboutRules": MessageLookupByLibrary.simpleMessage("About rules"),
    "tsAboutTailscale": MessageLookupByLibrary.simpleMessage("About Tailscale"),
    "tsAcceptRoutes": MessageLookupByLibrary.simpleMessage(
      "Accept subnet routes",
    ),
    "tsAcceptRoutesTip": MessageLookupByLibrary.simpleMessage(
      "Lets this node use approved subnet routes in the Tailscale network. Your rules still decide whether traffic goes through them; Flash rules are not changed.",
    ),
    "tsAccount": MessageLookupByLibrary.simpleMessage("Account"),
    "tsAccountMissing": MessageLookupByLibrary.simpleMessage(
      "Account info not provided",
    ),
    "tsAccountSignedOut": MessageLookupByLibrary.simpleMessage("Signed out"),
    "tsAccountsInProfile": MessageLookupByLibrary.simpleMessage(
      "Tailscale accounts in this profile",
    ),
    "tsAddAccount": MessageLookupByLibrary.simpleMessage(
      "Add Tailscale account",
    ),
    "tsAddUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Account addition is unconfirmed. Read the status again first.",
    ),
    "tsAddedInPanel": MessageLookupByLibrary.simpleMessage("Added in panel"),
    "tsAddress": MessageLookupByLibrary.simpleMessage("Tailscale address"),
    "tsAddressConflict": MessageLookupByLibrary.simpleMessage(
      "Address conflict",
    ),
    "tsAddressCopied": MessageLookupByLibrary.simpleMessage("Address copied"),
    "tsAddressMissing": MessageLookupByLibrary.simpleMessage(
      "Address not provided",
    ),
    "tsAfterConnectSelectable": MessageLookupByLibrary.simpleMessage(
      "Connect this node to change settings.",
    ),
    "tsAfterLogin": MessageLookupByLibrary.simpleMessage(
      "Available after login",
    ),
    "tsAssignBody": MessageLookupByLibrary.simpleMessage(
      "Choose one account for each target. Unassigned targets stay blocked. Other targets are not affected. An offline account will not be replaced automatically.",
    ),
    "tsAssignTitle": MessageLookupByLibrary.simpleMessage(
      "Choose accounts for targets",
    ),
    "tsAssignedTargets": MessageLookupByLibrary.simpleMessage(
      "Assigned targets",
    ),
    "tsAssignedTo": m120,
    "tsAssignedUnavailable": MessageLookupByLibrary.simpleMessage(
      "The assigned account is unavailable. This target will not use another account.",
    ),
    "tsAttachFailed": MessageLookupByLibrary.simpleMessage(
      "Signed in, but not added to this profile. Your sign-in has been kept. Try adding it again.",
    ),
    "tsAttachLockTip": MessageLookupByLibrary.simpleMessage(
      "Adding to this profile. Settings cannot be changed yet.",
    ),
    "tsAttachUnknown": MessageLookupByLibrary.simpleMessage(
      "The profile update is unconfirmed. Read the status again before adding the node or signing in again.",
    ),
    "tsAttachUnknownLockTip": MessageLookupByLibrary.simpleMessage(
      "The profile update is unconfirmed. Read the status again first.",
    ),
    "tsAttached": MessageLookupByLibrary.simpleMessage(
      "Added to current profile",
    ),
    "tsAttachedTip": MessageLookupByLibrary.simpleMessage(
      "Tailscale traffic uses dedicated rules. Other traffic keeps its existing routing.",
    ),
    "tsAttaching": MessageLookupByLibrary.simpleMessage(
      "Adding to current profile…",
    ),
    "tsAttachingTip": MessageLookupByLibrary.simpleMessage(
      "Sign-in is complete. Adding the node and Tailscale rules.",
    ),
    "tsBoundaryTip": MessageLookupByLibrary.simpleMessage(
      "Only traffic that Flash rules send to this node uses Tailscale. Logging in does not change rules, the system proxy or TUN settings.",
    ),
    "tsBrowserFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t open the login page. Try again.",
    ),
    "tsCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "tsCandidate": m121,
    "tsChangeAfterSignIn": MessageLookupByLibrary.simpleMessage(
      "Sign in and connect to change",
    ),
    "tsCheckingAccount": MessageLookupByLibrary.simpleMessage(
      "Checking account…",
    ),
    "tsChoicesFailed": MessageLookupByLibrary.simpleMessage(
      "Choices were not saved. Try again.",
    ),
    "tsChoicesSaved": MessageLookupByLibrary.simpleMessage(
      "Choices saved; application is not yet confirmed.",
    ),
    "tsChoicesUnknown": MessageLookupByLibrary.simpleMessage(
      "The result is unconfirmed. Read the status again before saving again.",
    ),
    "tsChoicesUpdated": MessageLookupByLibrary.simpleMessage(
      "Access accounts updated",
    ),
    "tsChooseAccountFor": MessageLookupByLibrary.simpleMessage(
      "Choose account for access",
    ),
    "tsChooseAccounts": MessageLookupByLibrary.simpleMessage("Choose accounts"),
    "tsChooseExitNode": MessageLookupByLibrary.simpleMessage(
      "Choose exit node",
    ),
    "tsChooseNode": MessageLookupByLibrary.simpleMessage("Choose node"),
    "tsClearOwnerFilter": MessageLookupByLibrary.simpleMessage(
      "Clear owner filter",
    ),
    "tsConflictBody": MessageLookupByLibrary.simpleMessage(
      "These addresses or domains have multiple candidate accounts. Requests to these targets are blocked until you choose an account. They will not be sent directly.",
    ),
    "tsConflictTitle": m122,
    "tsControlServer": MessageLookupByLibrary.simpleMessage("Control server"),
    "tsCopyAddress": MessageLookupByLibrary.simpleMessage("Copy address"),
    "tsCoreStopped": MessageLookupByLibrary.simpleMessage(
      "Core is not running",
    ),
    "tsCoreStoppedTip": MessageLookupByLibrary.simpleMessage(
      "Start the core to see this node\'s Tailscale status.",
    ),
    "tsCurrentDevice": MessageLookupByLibrary.simpleMessage("This device"),
    "tsDeleteProfileManaged": m123,
    "tsDeleteProfilePending": MessageLookupByLibrary.simpleMessage(
      "This profile has unconfirmed Tailscale operations. Read the status again before deleting it.",
    ),
    "tsDeleteProfileUnbindFailed": MessageLookupByLibrary.simpleMessage(
      "Could not unlink this profile from its Tailscale accounts. The profile was not deleted. Try again.",
    ),
    "tsDeleteProfileUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Profile deletion is unconfirmed. Read the status again before deleting it again.",
    ),
    "tsDeleteProfileUnlinkUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "The account-link update is unconfirmed. The profile has not been deleted. Read the status again before deleting it again.",
    ),
    "tsDeviceName": MessageLookupByLibrary.simpleMessage("Device name"),
    "tsDevices": MessageLookupByLibrary.simpleMessage("Devices"),
    "tsDevicesCompact": m124,
    "tsDevicesCompactFiltered": m125,
    "tsDevicesEmpty": MessageLookupByLibrary.simpleMessage(
      "No visible devices",
    ),
    "tsDevicesEmptyTip": MessageLookupByLibrary.simpleMessage(
      "This node doesn\'t see any other devices yet.",
    ),
    "tsDevicesFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t load the device list. Try again.",
    ),
    "tsDevicesFiltered": m126,
    "tsDevicesScope": MessageLookupByLibrary.simpleMessage(
      "Devices this node can see, not every device in the admin console",
    ),
    "tsDevicesShown": m127,
    "tsDevicesStale": MessageLookupByLibrary.simpleMessage(
      "The device list may be out of date. Refreshing failed; this is the last list read.",
    ),
    "tsDirectMode": MessageLookupByLibrary.simpleMessage(
      "Direct mode is active. Tailscale automatic routing and blocking protection are not in effect. Switch to Rule mode before accessing Tailscale targets.",
    ),
    "tsDnsUnverified": MessageLookupByLibrary.simpleMessage(
      "The current DNS settings do not confirm that target domains are preserved for rule matching. Domain routing has not been verified. Check DNS settings.",
    ),
    "tsDuplicate": MessageLookupByLibrary.simpleMessage(
      "An entry already exists for this account. This sign-in has been kept but has not been added to routing. Review it before continuing.",
    ),
    "tsExitApplying": MessageLookupByLibrary.simpleMessage(
      "Changing exit node…",
    ),
    "tsExitCapable": MessageLookupByLibrary.simpleMessage("Exit node"),
    "tsExitChangeBody": m128,
    "tsExitChangeConfirm": MessageLookupByLibrary.simpleMessage(
      "Change exit node",
    ),
    "tsExitChangeTitle": MessageLookupByLibrary.simpleMessage(
      "Change exit node?",
    ),
    "tsExitFailed": MessageLookupByLibrary.simpleMessage(
      "Exit node not changed. Try again.",
    ),
    "tsExitNode": MessageLookupByLibrary.simpleMessage("Exit node"),
    "tsExitNodeTip": MessageLookupByLibrary.simpleMessage(
      "Only affects traffic forwarded through this Tailscale node; it doesn\'t make the whole Mac use the exit.",
    ),
    "tsExitOffBody": m129,
    "tsExitOffTitle": MessageLookupByLibrary.simpleMessage(
      "Stop using the exit node?",
    ),
    "tsExitStale": MessageLookupByLibrary.simpleMessage(
      "Refresh the device list before choosing an exit node.",
    ),
    "tsExitUnknown": MessageLookupByLibrary.simpleMessage(
      "The exit node change is unconfirmed. Read the current settings again.",
    ),
    "tsExitUpdated": MessageLookupByLibrary.simpleMessage("Exit node updated"),
    "tsExpiryTip": m130,
    "tsFilterEmpty": MessageLookupByLibrary.simpleMessage(
      "No devices match the current filters",
    ),
    "tsFromLocal": MessageLookupByLibrary.simpleMessage("Set on this Mac"),
    "tsFromProfile": MessageLookupByLibrary.simpleMessage(
      "From current profile",
    ),
    "tsFromProvider": MessageLookupByLibrary.simpleMessage(
      "From proxy provider",
    ),
    "tsFromSubscription": MessageLookupByLibrary.simpleMessage(
      "From subscription",
    ),
    "tsGlobalMode": MessageLookupByLibrary.simpleMessage(
      "Global mode is active. Tailscale automatic routing and blocking protection are not in effect. Switch to Rule mode before accessing Tailscale targets.",
    ),
    "tsGoToProfiles": MessageLookupByLibrary.simpleMessage("Go to profiles"),
    "tsGoToRules": MessageLookupByLibrary.simpleMessage("Go to rules"),
    "tsHelp": MessageLookupByLibrary.simpleMessage("More information"),
    "tsHelpBody": MessageLookupByLibrary.simpleMessage(
      "Flash appears as a separate device on the Tailscale network. It does not let other devices connect to this Mac for SSH, file sharing, or remote desktop, and does not provide Tailscale SSH or Taildrop.",
    ),
    "tsIdentityFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t load account and network info",
    ),
    "tsLegacyAccountUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Account not confirmed",
    ),
    "tsLegacyAuthKeyNote": MessageLookupByLibrary.simpleMessage(
      "This node has an auth key; logging in again registers a new device identity with it, and the earlier login record is kept.",
    ),
    "tsLegacyBody": MessageLookupByLibrary.simpleMessage(
      "You can copy this login record to this node and keep the original. It can move to only one node; make sure this is the account you want to keep using, or log in again instead.",
    ),
    "tsLegacyChanged": MessageLookupByLibrary.simpleMessage(
      "The move details have changed. Check them again before confirming.",
    ),
    "tsLegacyClaimFailed": MessageLookupByLibrary.simpleMessage(
      "The login record was not moved; the move details couldn\'t be saved. Try again, or log in again.",
    ),
    "tsLegacyConfirm": MessageLookupByLibrary.simpleMessage("Confirm move"),
    "tsLegacyConfirmAccount": m131,
    "tsLegacyConfirmBody": MessageLookupByLibrary.simpleMessage(
      "This copies the login record for the node above and leaves the original untouched. The same record can\'t move to another node afterwards. Check the node\'s real connection status after the move.",
    ),
    "tsLegacyConfirmControl": m132,
    "tsLegacyConfirmNode": m133,
    "tsLegacyConfirmProfile": m134,
    "tsLegacyConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Move the earlier login to this node?",
    ),
    "tsLegacyControlMismatch": MessageLookupByLibrary.simpleMessage(
      "The earlier login record uses another control server than this node, so it can\'t move.",
    ),
    "tsLegacyFailed": MessageLookupByLibrary.simpleMessage(
      "The login record was not moved and the original is kept. Try again, or log in again.",
    ),
    "tsLegacyHasIdentity": MessageLookupByLibrary.simpleMessage(
      "This node already has its own login record; no need to move.",
    ),
    "tsLegacyInUse": MessageLookupByLibrary.simpleMessage(
      "The earlier login record is still in use and can\'t move for now.",
    ),
    "tsLegacyMigrate": MessageLookupByLibrary.simpleMessage(
      "Move to this node",
    ),
    "tsLegacyMigrated": MessageLookupByLibrary.simpleMessage(
      "Login record moved. Reading the node status.",
    ),
    "tsLegacyMigratedElsewhere": MessageLookupByLibrary.simpleMessage(
      "This earlier login record already moved to another node and can\'t move again.",
    ),
    "tsLegacyMigrating": MessageLookupByLibrary.simpleMessage(
      "Moving login record…",
    ),
    "tsLegacyRetry": MessageLookupByLibrary.simpleMessage("Retry move"),
    "tsLegacyTitle": MessageLookupByLibrary.simpleMessage(
      "Found an earlier login record",
    ),
    "tsLegacyUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Whether the earlier login record can be used is unconfirmed. Read the status again.",
    ),
    "tsLegacyUnknown": MessageLookupByLibrary.simpleMessage(
      "The move result is unconfirmed. Read the status again first, and don\'t move or log in again until confirmed.",
    ),
    "tsLegacyUnknownArchive": MessageLookupByLibrary.simpleMessage(
      "The move result is unconfirmed, and the original login record can\'t be verified for now. Read the status again first, and don\'t move or log in again until confirmed.",
    ),
    "tsLegacyUnknownTarget": MessageLookupByLibrary.simpleMessage(
      "The move result is unconfirmed; the login record on the target node isn\'t confirmed yet. Read the status again first, and don\'t move or log in again until confirmed.",
    ),
    "tsLegacyUnknownUnsaved": MessageLookupByLibrary.simpleMessage(
      "The move result is unconfirmed; the move details couldn\'t be saved. Read the status again first, and don\'t move or log in again until confirmed.",
    ),
    "tsLegacyUnreadable": MessageLookupByLibrary.simpleMessage(
      "Can\'t read the earlier login record. Check again.",
    ),
    "tsLegacyUnreadableNotMigrated": MessageLookupByLibrary.simpleMessage(
      "The login record was not moved; the earlier login record can\'t be read. Check again.",
    ),
    "tsLoadFailedTip": MessageLookupByLibrary.simpleMessage(
      "Can\'t read this node\'s status right now. Try again.",
    ),
    "tsLoggedOutReceipt": MessageLookupByLibrary.simpleMessage(
      "Logged out of this node. It won\'t log in again until you log in.",
    ),
    "tsLoggedOutTip": MessageLookupByLibrary.simpleMessage(
      "You logged out of this node. It reconnects only after you log in.",
    ),
    "tsLoggingOut": MessageLookupByLibrary.simpleMessage("Logging out…"),
    "tsLogin": MessageLookupByLibrary.simpleMessage("Log in to Tailscale"),
    "tsLoginUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "The login result isn\'t confirmed yet. Read the node status again.",
    ),
    "tsLogout": MessageLookupByLibrary.simpleMessage("Log out of this node"),
    "tsLogoutAuthKeyNote": MessageLookupByLibrary.simpleMessage(
      "When you log in again, the auth key in the profile registers a new device identity.",
    ),
    "tsLogoutBody": m135,
    "tsLogoutFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t log out. Read the node status again, then retry.",
    ),
    "tsLogoutTitle": MessageLookupByLibrary.simpleMessage(
      "Log out of this Tailscale node?",
    ),
    "tsLogoutUnknown": MessageLookupByLibrary.simpleMessage(
      "The logout result is unconfirmed. Read the node status again and don\'t repeat it until confirmed.",
    ),
    "tsManagedPriority": MessageLookupByLibrary.simpleMessage(
      "Panel-added routing and blocking rules take priority over existing rules for those targets. Rules for other traffic stay unchanged. Assign an account here to change a target’s routing.",
    ),
    "tsMemoryTip": MessageLookupByLibrary.simpleMessage(
      "Each account runs a separate Tailscale device. Keeping more accounts online uses more memory.",
    ),
    "tsNameMissing": MessageLookupByLibrary.simpleMessage("Name not provided"),
    "tsNeedsApprovalTip": MessageLookupByLibrary.simpleMessage(
      "Browser authentication is done. Wait for your Tailscale network admin to approve this device.",
    ),
    "tsNeedsReauthTip": MessageLookupByLibrary.simpleMessage(
      "This node\'s authentication has expired. Log in again.",
    ),
    "tsNetwork": MessageLookupByLibrary.simpleMessage("Network"),
    "tsNetworkMissing": MessageLookupByLibrary.simpleMessage(
      "Network info not provided",
    ),
    "tsNetworkNameTip": MessageLookupByLibrary.simpleMessage(
      "The network name does not identify a verified network owner.",
    ),
    "tsNetworkOf": m136,
    "tsNewAccount": MessageLookupByLibrary.simpleMessage("New account"),
    "tsNoExitCandidates": MessageLookupByLibrary.simpleMessage(
      "No exit nodes available",
    ),
    "tsNoExitCandidatesTip": MessageLookupByLibrary.simpleMessage(
      "No exit node is confirmed available",
    ),
    "tsNoExitNode": MessageLookupByLibrary.simpleMessage("No exit node"),
    "tsNoExitNodeTip": MessageLookupByLibrary.simpleMessage(
      "Using no exit node doesn\'t log out of Tailscale",
    ),
    "tsNodeChanged": MessageLookupByLibrary.simpleMessage(
      "The node has changed. Start the action again on the selected node.",
    ),
    "tsNodeGone": MessageLookupByLibrary.simpleMessage(
      "This node is no longer in the current profile",
    ),
    "tsNodeGoneTip": MessageLookupByLibrary.simpleMessage(
      "Choose a node again.",
    ),
    "tsNodeOf": m137,
    "tsNotAssigned": MessageLookupByLibrary.simpleMessage("Not assigned"),
    "tsOff": MessageLookupByLibrary.simpleMessage("Off"),
    "tsOffline": MessageLookupByLibrary.simpleMessage("Offline"),
    "tsOfflineNotSelectable": MessageLookupByLibrary.simpleMessage(
      "Offline, can\'t be chosen",
    ),
    "tsOn": MessageLookupByLibrary.simpleMessage("On"),
    "tsOnline": MessageLookupByLibrary.simpleMessage("Online"),
    "tsOverrideAmbiguous": MessageLookupByLibrary.simpleMessage(
      "This profile has multiple nodes with the same name and control server, so their settings cannot be saved separately. Give them different names in the profile.",
    ),
    "tsOverrideTip": MessageLookupByLibrary.simpleMessage(
      "Settings saved here take priority over the same settings in the profile and never change the subscription file.",
    ),
    "tsOwner": MessageLookupByLibrary.simpleMessage("Owner"),
    "tsOwnerAll": MessageLookupByLibrary.simpleMessage("All"),
    "tsOwnerFilter": MessageLookupByLibrary.simpleMessage("Device owner"),
    "tsOwnerFilterEmpty": MessageLookupByLibrary.simpleMessage(
      "No devices with this owner",
    ),
    "tsOwnerMe": MessageLookupByLibrary.simpleMessage("Me"),
    "tsOwnerMine": MessageLookupByLibrary.simpleMessage("Mine"),
    "tsOwnerUnknown": MessageLookupByLibrary.simpleMessage("Owner unknown"),
    "tsPrepareAgain": MessageLookupByLibrary.simpleMessage(
      "Prepare login again",
    ),
    "tsPrepareFailed": MessageLookupByLibrary.simpleMessage(
      "Tailscale sign-in could not be prepared. Try again.",
    ),
    "tsPrepareUnknown": MessageLookupByLibrary.simpleMessage(
      "Sign-in preparation is unconfirmed. Read the status again before signing in again.",
    ),
    "tsPreparingProfile": MessageLookupByLibrary.simpleMessage(
      "Preparing a local profile…",
    ),
    "tsPreparingSignIn": MessageLookupByLibrary.simpleMessage(
      "Preparing sign-in…",
    ),
    "tsPreparingSignInTip": MessageLookupByLibrary.simpleMessage(
      "Preparing Tailscale for this profile.",
    ),
    "tsPreparingTip": MessageLookupByLibrary.simpleMessage(
      "Getting login information for this node.",
    ),
    "tsReadSettings": MessageLookupByLibrary.simpleMessage(
      "Read settings again",
    ),
    "tsReadStatus": MessageLookupByLibrary.simpleMessage("Read status again"),
    "tsReassign": MessageLookupByLibrary.simpleMessage("Reassign account"),
    "tsReconfirm": MessageLookupByLibrary.simpleMessage(
      "This target’s account needs confirmation. Requests are blocked. Choose an account again.",
    ),
    "tsRefresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "tsRefreshDevices": MessageLookupByLibrary.simpleMessage(
      "Refresh device list",
    ),
    "tsRelogin": MessageLookupByLibrary.simpleMessage("Log in again"),
    "tsRemoveBody": m138,
    "tsRemoveBodyNode": m139,
    "tsRemoveExtra": MessageLookupByLibrary.simpleMessage(
      "This does not delete the device from the Tailscale admin console or change the official client.",
    ),
    "tsRemoveIncomplete": MessageLookupByLibrary.simpleMessage(
      "Signed out, but removal is incomplete. Read the status again.",
    ),
    "tsRemoveLast": MessageLookupByLibrary.simpleMessage(
      "This is the last panel-added account in this profile. Removing it also removes panel-added routing and blocking rules. The original profile will handle this traffic again, which may use a direct connection or its original proxies. Confirm that you accept this change.",
    ),
    "tsRemoveLogoutUnknown": MessageLookupByLibrary.simpleMessage(
      "Sign-out is unconfirmed. The node has not been removed. Read the status again before removing it or signing in again.",
    ),
    "tsRemoveTargetsKept": MessageLookupByLibrary.simpleMessage(
      "Targets assigned to this account will not move to another account automatically. Blocking protection stays in place. Assign another account to access them.",
    ),
    "tsRemoveTitle": MessageLookupByLibrary.simpleMessage(
      "Sign out and remove this account?",
    ),
    "tsRemoveUnknown": MessageLookupByLibrary.simpleMessage(
      "Removal is unconfirmed. Read the status again before adding the node or signing in.",
    ),
    "tsRemoved": MessageLookupByLibrary.simpleMessage("Signed out and removed"),
    "tsRemoving": MessageLookupByLibrary.simpleMessage(
      "Signing out and removing…",
    ),
    "tsReopenLogin": MessageLookupByLibrary.simpleMessage("Reopen login page"),
    "tsRetryAttach": MessageLookupByLibrary.simpleMessage(
      "Retry adding to profile",
    ),
    "tsRoutesApplying": MessageLookupByLibrary.simpleMessage(
      "Updating subnet routes…",
    ),
    "tsRoutesFailed": MessageLookupByLibrary.simpleMessage(
      "Subnet routes not changed. Try again.",
    ),
    "tsRoutesOffBody": MessageLookupByLibrary.simpleMessage(
      "This node will stop using these subnet routes; related connections may drop. Flash rules stay the same.",
    ),
    "tsRoutesOffConfirm": MessageLookupByLibrary.simpleMessage(
      "Stop accepting",
    ),
    "tsRoutesOffTitle": MessageLookupByLibrary.simpleMessage(
      "Stop accepting subnet routes?",
    ),
    "tsRoutesOnBody": MessageLookupByLibrary.simpleMessage(
      "This node will use the network\'s approved subnet routes. Flash rules stay the same.",
    ),
    "tsRoutesOnTitle": MessageLookupByLibrary.simpleMessage(
      "Accept subnet routes?",
    ),
    "tsRoutesUnknown": MessageLookupByLibrary.simpleMessage(
      "The subnet routes change is unconfirmed. Read the current settings again.",
    ),
    "tsRoutesUpdated": MessageLookupByLibrary.simpleMessage(
      "Subnet routes updated",
    ),
    "tsRoutingConflict": MessageLookupByLibrary.simpleMessage(
      "Routing conflict",
    ),
    "tsRulesAddresses": m140,
    "tsRulesDomain": m141,
    "tsRulesManaged": MessageLookupByLibrary.simpleMessage(
      "Flash updates dedicated rules using this account’s network domain and device addresses. Other traffic keeps its existing routing, and the original profile file stays unchanged.",
    ),
    "tsRulesPending": MessageLookupByLibrary.simpleMessage(
      "Once added, Tailscale addresses and ts.net domains will use dedicated rules. Other traffic will keep its existing routing.",
    ),
    "tsRulesProfileNode": MessageLookupByLibrary.simpleMessage(
      "Only traffic routed to this node by Flash rules uses Tailscale. Signing in to this node does not change existing rules or enable system proxy or TUN.",
    ),
    "tsRulesSummary": m142,
    "tsRulesUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Domain and address details are unconfirmed.",
    ),
    "tsSaveChoices": MessageLookupByLibrary.simpleMessage("Save choices"),
    "tsSavedValue": m143,
    "tsSearchEmpty": MessageLookupByLibrary.simpleMessage(
      "No devices match the search",
    ),
    "tsSearchHint": MessageLookupByLibrary.simpleMessage(
      "Search name or address",
    ),
    "tsSettingsApplyFailed": MessageLookupByLibrary.simpleMessage(
      "Saved, but couldn\'t be applied to this node. Read the current settings again.",
    ),
    "tsSettingsSaved": MessageLookupByLibrary.simpleMessage(
      "Saved, but not yet confirmed in effect. Read the current settings again.",
    ),
    "tsShared": MessageLookupByLibrary.simpleMessage("Shared in"),
    "tsSharedBy": m144,
    "tsSignIn": MessageLookupByLibrary.simpleMessage("Sign in to Tailscale"),
    "tsSignInBoundary": MessageLookupByLibrary.simpleMessage(
      "System proxy and TUN will not be enabled automatically.",
    ),
    "tsSignInShort": MessageLookupByLibrary.simpleMessage(
      "Sign in to add a node and dedicated rules.",
    ),
    "tsSignInTip": MessageLookupByLibrary.simpleMessage(
      "After sign-in, Flash adds a Tailscale node and dedicated rules to this profile. Other traffic keeps its existing routing, and the original profile file stays unchanged.",
    ),
    "tsSignOutAccount": MessageLookupByLibrary.simpleMessage(
      "Sign out of this account",
    ),
    "tsSignOutAccountBody": m145,
    "tsSignOutAccountTitle": MessageLookupByLibrary.simpleMessage(
      "Sign out of this account?",
    ),
    "tsSignOutRemove": MessageLookupByLibrary.simpleMessage(
      "Sign out and remove",
    ),
    "tsSignOutRemoveMenu": MessageLookupByLibrary.simpleMessage(
      "Sign out and remove…",
    ),
    "tsSignedOutBanner": MessageLookupByLibrary.simpleMessage(
      "Signed out of this account. In Rule mode, its assigned targets stay blocked until you sign in or explicitly reassign them.",
    ),
    "tsSignedOutReceipt": MessageLookupByLibrary.simpleMessage(
      "Signed out of this account",
    ),
    "tsSignedOutTip": MessageLookupByLibrary.simpleMessage(
      "Log in in your browser to authenticate this node.",
    ),
    "tsStartCore": MessageLookupByLibrary.simpleMessage("Start core"),
    "tsStartFailedTip": MessageLookupByLibrary.simpleMessage(
      "This node failed to start. Try again.",
    ),
    "tsStateConnected": MessageLookupByLibrary.simpleMessage("Connected"),
    "tsStateLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t load status",
    ),
    "tsStateNeedsApproval": MessageLookupByLibrary.simpleMessage(
      "Waiting for admin approval",
    ),
    "tsStateNeedsReauth": MessageLookupByLibrary.simpleMessage(
      "Login required again",
    ),
    "tsStatePreparing": MessageLookupByLibrary.simpleMessage(
      "Preparing login…",
    ),
    "tsStateSignedOut": MessageLookupByLibrary.simpleMessage("Not logged in"),
    "tsStateStartFailed": MessageLookupByLibrary.simpleMessage(
      "Failed to start",
    ),
    "tsStateStarting": MessageLookupByLibrary.simpleMessage("Starting…"),
    "tsStateStopped": MessageLookupByLibrary.simpleMessage("Stopped"),
    "tsStateUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Status unconfirmed",
    ),
    "tsStateWaitingBrowser": MessageLookupByLibrary.simpleMessage(
      "Waiting for browser login",
    ),
    "tsStatus": MessageLookupByLibrary.simpleMessage("Status"),
    "tsStatusOf": m146,
    "tsStatusUnknown": MessageLookupByLibrary.simpleMessage("Status unknown"),
    "tsStoppedTip": MessageLookupByLibrary.simpleMessage(
      "This node has stopped and can\'t reach the Tailscale network for now.",
    ),
    "tsSubnetRoutes": MessageLookupByLibrary.simpleMessage("Subnet routes"),
    "tsSwitcherSemantics": m147,
    "tsSystem": MessageLookupByLibrary.simpleMessage("OS"),
    "tsSystemMissing": MessageLookupByLibrary.simpleMessage("OS not provided"),
    "tsTargetAddress": m148,
    "tsTargetDomain": m149,
    "tsTargetUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Target account unconfirmed",
    ),
    "tsTargetUnconfirmedTip": MessageLookupByLibrary.simpleMessage(
      "The account for this target cannot be verified yet. Requests are blocked.",
    ),
    "tsTryAgain": MessageLookupByLibrary.simpleMessage("Try again"),
    "tsUnconfirmedTip": MessageLookupByLibrary.simpleMessage(
      "Can\'t confirm whether this node is connected. Read the status again.",
    ),
    "tsUnverifiedBlocked": MessageLookupByLibrary.simpleMessage(
      "Tailscale addresses and domains without a verified account are blocked. They will not use another account or a direct connection.",
    ),
    "tsUrlMissing": MessageLookupByLibrary.simpleMessage(
      "No usable login page yet. Prepare the login again.",
    ),
    "tsUrlRejected": MessageLookupByLibrary.simpleMessage(
      "This login page can\'t be opened safely. Check the node\'s control server in the profile.",
    ),
    "tsViewExisting": MessageLookupByLibrary.simpleMessage(
      "View existing account",
    ),
    "tsWaitingBrowserTip": MessageLookupByLibrary.simpleMessage(
      "Finish logging in in your browser. This page updates from the node\'s status afterwards.",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "TUN could not be authorized, so it was turned off.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN works only in administrator mode.",
    ),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Entries added here replace the TUN settings of every profile; anything not added keeps the profile\'s own setting. Entries a custom profile adds itself take precedence.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Turn off"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Turn on"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("UDP relay mode"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("UDP timeout"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "The UDP timeout is in seconds and works only with the gvisor, system and mixed stacks.",
    ),
    "ultra": MessageLookupByLibrary.simpleMessage("Ultra"),
    "undo": MessageLookupByLibrary.simpleMessage("Undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified delay"),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Unknown network error",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Restore down"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Unpin window"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "updateCheckFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t check for updates. Please try again.",
    ),
    "updateDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "The update could not be downloaded.",
    ),
    "updateDownloadStarted": MessageLookupByLibrary.simpleMessage(
      "Downloading the update. Follow its progress on the dashboard.",
    ),
    "updateDownloadTest": MessageLookupByLibrary.simpleMessage(
      "Update download test",
    ),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Update failed"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "The update could not be installed. You can download it from the release page instead.",
    ),
    "updateNoReleaseFound": MessageLookupByLibrary.simpleMessage(
      "No Flash release found yet",
    ),
    "updateNotVerified": MessageLookupByLibrary.simpleMessage(
      "The downloaded update could not be verified.",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Update ready"),
    "updateReadyTip": MessageLookupByLibrary.simpleMessage(
      "The update has downloaded. Tap to install it.",
    ),
    "updateRestartTip": MessageLookupByLibrary.simpleMessage(
      "Flash closes to install the update and opens again when it is done.",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("Upload bandwidth"),
    "upstreamTelegram": MessageLookupByLibrary.simpleMessage(
      "FlClash upstream Telegram",
    ),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlRewrite": MessageLookupByLibrary.simpleMessage("URL rewrite"),
    "urlTip": m150,
    "useHosts": MessageLookupByLibrary.simpleMessage("Use hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use system hosts"),
    "usedShort": MessageLookupByLibrary.simpleMessage("used"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("Used traffic"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Username"),
    "validUntil": m151,
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "viewAll": MessageLookupByLibrary.simpleMessage("View all"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("Virtual IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Vivid"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN settings changed. Tap to restart",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "WebDAV configuration",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist mode"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage("Write to system"),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Write to system also sets the system clock; Android ignores it.",
    ),
    "yearsAgo": m152,
    "yearsAgoShort": m153,
    "yes": MessageLookupByLibrary.simpleMessage("Yes"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Simplified Chinese"),
  };
}
