// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get rule => 'Rule';

  @override
  String get rules => 'Rules';

  @override
  String get global => 'Global';

  @override
  String get direct => 'Direct';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get proxies => 'Proxies';

  @override
  String get profile => 'Profile';

  @override
  String get profiles => 'Profiles';

  @override
  String get tools => 'Tools';

  @override
  String get logs => 'Logs';

  @override
  String get resources => 'Resources';

  @override
  String get trafficUsage => 'Traffic usage';

  @override
  String get networkSpeed => 'Network speed';

  @override
  String get outboundMode => 'Outbound mode';

  @override
  String get serviceStatus => 'Service status';

  @override
  String get serviceRestricted => 'Access restricted';

  @override
  String get serviceAvailable => 'Available';

  @override
  String get serviceUnavailable => 'Unavailable';

  @override
  String get serviceFailed => 'Check failed';

  @override
  String get serviceDisallowedIsp => 'Disallowed ISP';

  @override
  String get serviceBlocked => 'Blocked';

  @override
  String get serviceUnsupportedRegion => 'Region not supported';

  @override
  String get serviceOriginalsOnly => 'Originals only';

  @override
  String get serviceComingSoon => 'Coming soon';

  @override
  String get servicePending => 'Not checked';

  @override
  String get serviceManage => 'Manage services';

  @override
  String get serviceCheckAll => 'Check all';

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String get usedTraffic => 'Used traffic';

  @override
  String get totalTraffic => 'Total traffic';

  @override
  String get expireTime => 'Expiration time';

  @override
  String get nullProfileDesc => 'Add a profile to get started';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get defaultText => 'Default';

  @override
  String get more => 'More';

  @override
  String get other => 'Other';

  @override
  String get about => 'About';

  @override
  String get en => 'English';

  @override
  String get es => 'Spanish';

  @override
  String get fr => 'French';

  @override
  String get ja => 'Japanese';

  @override
  String get ko => 'Korean';

  @override
  String get ru => 'Russian';

  @override
  String get zhCN => 'Simplified Chinese';

  @override
  String get theme => 'Theme';

  @override
  String get extend => 'Extend';

  @override
  String get runtimeConfig => 'Runtime config';

  @override
  String get allowLan => 'Allow LAN';

  @override
  String get tun => 'TUN';

  @override
  String get tunDesc => 'TUN works only in administrator mode.';

  @override
  String get minimizeOnExit => 'Minimize on exit';

  @override
  String get autoLaunch => 'Auto launch';

  @override
  String get loginItemRequiresApproval =>
      'Allow Flash to open at login in System Settings.';

  @override
  String get loginItemNotFound =>
      'macOS couldn’t find the current Flash app to set it to open at login.';

  @override
  String get loginItemUnexpectedStatus =>
      'Couldn’t confirm that Open at Login was updated as requested.';

  @override
  String get loginItemMissingStatus =>
      'Couldn’t read the Open at Login status.';

  @override
  String get loginItemOperationFailed =>
      'Couldn’t change the Open at Login setting.';

  @override
  String get silentLaunch => 'Silent launch';

  @override
  String get autoRun => 'Auto run';

  @override
  String get autoRunDesc => 'Auto run starts the proxy when the app opens.';

  @override
  String get logcat => 'Logcat';

  @override
  String get logcatDesc => 'Turning off Logcat hides the logs entry.';

  @override
  String get autoCheckUpdate => 'Auto check for updates';

  @override
  String get checkCertificate => 'Verify TLS certificates';

  @override
  String get checkCertificateDesc =>
      'With TLS verification off, subscriptions and backups are open to man-in-the-middle attacks.';

  @override
  String get accessControl => 'Access control';

  @override
  String get edit => 'Edit';

  @override
  String get confirm => 'Confirm';

  @override
  String get update => 'Update';

  @override
  String get add => 'Add';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get seconds => 'seconds';

  @override
  String get qrcode => 'QR code';

  @override
  String get qrcodeDesc => 'Scan a QR code to obtain a profile';

  @override
  String get url => 'URL';

  @override
  String get link => 'Link';

  @override
  String get file => 'File';

  @override
  String get name => 'Name';

  @override
  String get profileNameNullValidationDesc => 'Please enter the profile name';

  @override
  String get rename => 'Rename';

  @override
  String get profileUrlNullValidationDesc => 'Please enter the profile URL';

  @override
  String get profileUrlInvalidValidationDesc =>
      'Please enter a valid profile URL';

  @override
  String get autoUpdate => 'Auto update';

  @override
  String get autoUpdateInterval => 'Auto-update interval';

  @override
  String get profileAutoUpdateIntervalNullValidationDesc =>
      'Please enter the auto-update interval';

  @override
  String get profileAutoUpdateIntervalInvalidValidationDesc =>
      'Please enter a valid interval';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeColor => 'Theme color';

  @override
  String get preview => 'Preview';

  @override
  String get auto => 'Auto';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get importFromLink => 'Import from link';

  @override
  String get sendFromPhone => 'Send from phone';

  @override
  String get sendFromPhoneTip =>
      'Scan the code with your phone\'s camera and paste the link on the page that opens. Both devices need to be on the same network.';

  @override
  String get sendFromPhoneNoNetwork =>
      'This device is not connected to a local network';

  @override
  String get sendFromPhonePermissionDenied =>
      'Receiving a link from your phone needs the Nearby devices permission, which lets Flash reach the local network. Turn it on in the app\'s settings.';

  @override
  String get sendFromPhonePageTitle => 'Send a link to Flash';

  @override
  String get sendFromPhonePageHint => 'Subscription link or proxy share link';

  @override
  String get send => 'Send';

  @override
  String get sendFromPhonePageSent =>
      'Sent. Confirm the import on the other device.';

  @override
  String get sendFromPhoneConfirmTitle => 'Import the link from your phone?';

  @override
  String get shareQrcodeTip =>
      'Scan with Flash on another device to import this profile.';

  @override
  String get qrcodeTooLongTip =>
      'This link is too long for a QR code. Use Copy link instead.';

  @override
  String get submit => 'Submit';

  @override
  String createProfileFromUrlTip(Object url) {
    return 'Do you want to create a profile from $url?';
  }

  @override
  String get create => 'Create';

  @override
  String get pleaseUploadValidQrcode => 'Please upload a valid QR code';

  @override
  String get blacklistMode => 'Blacklist mode';

  @override
  String get whitelistMode => 'Whitelist mode';

  @override
  String get selectAll => 'Select all';

  @override
  String get cancelSelectAll => 'Deselect all';

  @override
  String get appAccessControl => 'App access control';

  @override
  String get accessControlAllowDesc => 'Only selected apps go through the VPN';

  @override
  String get accessControlNotAllowDesc =>
      'Selected apps are excluded from the VPN';

  @override
  String get accessControlDisabledDesc => 'App access control is disabled';

  @override
  String accessControlSelectedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String get port => 'Port';

  @override
  String get logLevel => 'Log level';

  @override
  String get show => 'Show';

  @override
  String get exit => 'Exit';

  @override
  String get systemProxy => 'System proxy';

  @override
  String get safeMode => 'Safe mode';

  @override
  String safeModeAppTitle(Object appName) {
    return '$appName (Safe mode)';
  }

  @override
  String get project => 'FlClash upstream project';

  @override
  String get upstreamTelegram => 'FlClash upstream Telegram';

  @override
  String get core => 'Core';

  @override
  String get tabAnimation => 'Tab animation';

  @override
  String get desc =>
      'A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.';

  @override
  String get startVpn => 'Starting VPN…';

  @override
  String get stopVpn => 'Stopping VPN…';

  @override
  String get localNetworkDeniedTip =>
      'Local network permission denied: using the gvisor stack, LAN is unreachable.';

  @override
  String get compatible => 'Compatibility mode';

  @override
  String get notSelectedTip => 'The current proxy group cannot be selected';

  @override
  String get changeProxyFailedTip =>
      'Failed to switch proxy; the previous selection has been restored';

  @override
  String get databaseWriteFailedTip =>
      'Failed to save the change; it has been rolled back';

  @override
  String get tip => 'Tip';

  @override
  String get account => 'Account';

  @override
  String get backup => 'Backup';

  @override
  String get backupSuccess => 'Backup successful';

  @override
  String get noInfo => 'No info';

  @override
  String get pleaseBindWebDAV => 'Please bind WebDAV';

  @override
  String get bind => 'Bind';

  @override
  String get connectivity => 'Connectivity: ';

  @override
  String get webDAVConfiguration => 'WebDAV configuration';

  @override
  String get address => 'Address';

  @override
  String get addressTip => 'Please enter a valid WebDAV address';

  @override
  String get password => 'Password';

  @override
  String get authentication => 'Authentication';

  @override
  String get authenticationSystemProxyDesc =>
      'The system proxy is not applied while authentication is on.';

  @override
  String get checkUpdate => 'Check for updates';

  @override
  String get discoverNewVersion => 'New version found';

  @override
  String get checkUpdateError => 'The app is already up to date';

  @override
  String get updateNoReleaseFound => 'No Flash release found yet';

  @override
  String get updateCheckFailed =>
      'Couldn\'t check for updates. Please try again.';

  @override
  String get goDownload => 'Download';

  @override
  String get unknown => 'Unknown';

  @override
  String get country => 'Region';

  @override
  String get search => 'Search';

  @override
  String get allowBypass => 'Allow apps to bypass VPN';

  @override
  String get externalController => 'External controller';

  @override
  String get externalControllerDesc =>
      'The external controller lets you control the core on port 9090.';

  @override
  String get externalControllerSecret => 'External controller secret';

  @override
  String get ipv6Desc => 'IPv6 traffic is received only while IPv6 is on.';

  @override
  String get app => 'App';

  @override
  String get general => 'General';

  @override
  String get startupAndBackground => 'Startup and background';

  @override
  String get requestsAndUpdates => 'Requests and updates';

  @override
  String get logsAndDiagnostics => 'Logs and diagnostics';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get unifiedDelay => 'Unified delay';

  @override
  String get tcpConcurrent => 'TCP concurrent';

  @override
  String get geodataLoader => 'Geo low-memory mode';

  @override
  String get requests => 'Requests';

  @override
  String get recentRequests => 'Recent requests';

  @override
  String get findProcessMode => 'Find process';

  @override
  String get init => 'Init';

  @override
  String get infiniteTime => 'Never expires';

  @override
  String get connections => 'Connections';

  @override
  String get liveConnections => 'Live connections';

  @override
  String get inbound => 'Inbound';

  @override
  String get intranetIP => 'Intranet IP';

  @override
  String get view => 'View';

  @override
  String get cut => 'Cut';

  @override
  String get copy => 'Copy';

  @override
  String get clipboardWriteFailed =>
      'Couldn\'t copy to the clipboard. The selection may be too large';

  @override
  String get paste => 'Paste';

  @override
  String get testUrl => 'Test URL';

  @override
  String get delayTestTimeout => 'Delay test timeout';

  @override
  String get sync => 'Sync';

  @override
  String get exclude => 'Hide from recent tasks';

  @override
  String get compact => 'Compact';

  @override
  String get tab => 'Tab';

  @override
  String get list => 'List';

  @override
  String get delay => 'Delay';

  @override
  String get style => 'Style';

  @override
  String get size => 'Size';

  @override
  String get sort => 'Sort';

  @override
  String get columns => 'Columns';

  @override
  String get proxyGroup => 'Proxy group';

  @override
  String get go => 'Go';

  @override
  String get externalLink => 'External link';

  @override
  String get otherContributors => 'Other contributors';

  @override
  String get appIconDesign => 'App icon design';

  @override
  String get autoCloseConnections => 'Auto close connections';

  @override
  String get onlyStatisticsProxy => 'Only count proxy traffic';

  @override
  String get showNotificationStopAction => 'Stop button in notification';

  @override
  String get pureBlackMode => 'Pure black mode';

  @override
  String get sidebar => 'Sidebar';

  @override
  String get backgroundBlur => 'Background blur';

  @override
  String get liquidGlass => 'Liquid Glass';

  @override
  String get keepAliveIntervalDesc => 'TCP keep-alive interval';

  @override
  String get entries => ' entries';

  @override
  String get local => 'Local';

  @override
  String get remote => 'Remote';

  @override
  String get mode => 'Mode';

  @override
  String get time => 'Time';

  @override
  String get source => 'Source';

  @override
  String get action => 'Action';

  @override
  String get intelligentSelected => 'Smart selection';

  @override
  String get clipboardImport => 'Import from clipboard';

  @override
  String get clipboardNoPackageNames =>
      'No package names found in the clipboard';

  @override
  String get clipboardExport => 'Export to clipboard';

  @override
  String get layout => 'Layout';

  @override
  String get tight => 'Tight';

  @override
  String get standard => 'Standard';

  @override
  String get ultra => 'Ultra';

  @override
  String get loose => 'Loose';

  @override
  String get profilesSort => 'Sort profiles';

  @override
  String get start => 'Start';

  @override
  String get runTime => 'Run time';

  @override
  String get stop => 'Stop';

  @override
  String get key => 'Key';

  @override
  String get value => 'Value';

  @override
  String get options => 'Options';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get loopback => 'UWP loopback exemption';

  @override
  String get providers => 'External resources';

  @override
  String get proxyProviders => 'Proxy providers';

  @override
  String get ruleProviders => 'Rule providers';

  @override
  String get providerUrlTip => 'Only remote providers are supported';

  @override
  String get ruleSetEmptyTip => 'The rule set has no usable entries';

  @override
  String get ruleSetMixedTip =>
      'The rule set mixes domains and IP ranges, so its type cannot be told';

  @override
  String get ruleSetInvalidTip => 'This mrs file cannot be read';

  @override
  String get subscriptionInfo => 'Subscription info';

  @override
  String get server => 'Server';

  @override
  String get ntpInterval => 'Sync interval (minutes)';

  @override
  String get dialerProxy => 'Dialer proxy';

  @override
  String get writeToSystem => 'Write to system';

  @override
  String get writeToSystemDesc =>
      'Write to system also sets the system clock; Android ignores it.';

  @override
  String get sniffer => 'Sniffer';

  @override
  String get overrideDestination => 'Override destination';

  @override
  String get forceDnsMapping => 'Force DNS mapping';

  @override
  String get forceDnsMappingDesc =>
      'Force DNS mapping also sniffs connections whose domain came from a DNS mapping.';

  @override
  String get parsePureIp => 'Parse pure IP';

  @override
  String get forceDomain => 'Force domains';

  @override
  String get forceDomainDesc =>
      'Force domains are sniffed too; other connections that already have a domain are left alone.';

  @override
  String get skipDomain => 'Skip domains';

  @override
  String get skipSrcAddress => 'Skip source addresses';

  @override
  String get skipDstAddress => 'Skip destination addresses';

  @override
  String get sniffProtocols => 'Protocols';

  @override
  String get ports => 'Ports';

  @override
  String get overrideEntries => 'Override entries';

  @override
  String get addOverrideEntry => 'Add override entry';

  @override
  String get dnsOverrideDesc =>
      'Entries added here replace the DNS of every URL and file profile; anything not added keeps the profile\'s own setting. Custom profiles set their DNS in their content.';

  @override
  String get settingEntries => 'settings';

  @override
  String get addSettingEntry => 'Add setting';

  @override
  String get profileSettingsDesc =>
      'Applies to this profile only; anything not added uses its default.';

  @override
  String get healthCheck => 'Health check';

  @override
  String get discardChanges => 'Discard the changes?';

  @override
  String get quickEdit => 'Quick edit';

  @override
  String get status => 'Status';

  @override
  String get statusDesc => 'With DNS off, the system DNS is used.';

  @override
  String get respectRules => 'Respect rules';

  @override
  String get respectRulesDesc =>
      'Respect rules routes DNS connections by the rules and needs a Proxy Server Nameserver.';

  @override
  String get dnsMode => 'DNS mode';

  @override
  String get fakeipRange => 'Fake-IP range';

  @override
  String get fakeipFilter => 'Fake-IP filter';

  @override
  String get useHosts => 'Use hosts';

  @override
  String get useSystemHosts => 'Use system hosts';

  @override
  String get fallbackFilter => 'Fallback filter';

  @override
  String get domain => 'Domain';

  @override
  String get listenRoutingMark => 'Listen routing mark';

  @override
  String get listenRoutingMarkDesc =>
      'Listen routing mark works only on Linux.';

  @override
  String get ipv6Timeout => 'IPv6 timeout (ms)';

  @override
  String get cacheAlgorithm => 'Cache algorithm';

  @override
  String get cacheMaxSize => 'Cache size';

  @override
  String get fakeipRange6 => 'Fake-IP range (IPv6)';

  @override
  String get fakeipFilterMode => 'Fake-IP filter mode';

  @override
  String get fakeipTtl => 'Fake-IP TTL';

  @override
  String get reset => 'Reset';

  @override
  String get actionView => 'Show/Hide';

  @override
  String get actionStart => 'Start/Stop';

  @override
  String get actionMode => 'Switch mode';

  @override
  String get actionProxy => 'System proxy';

  @override
  String get actionTun => 'TUN';

  @override
  String get actionRuleMode => 'Rule mode';

  @override
  String get actionGlobalMode => 'Global mode';

  @override
  String get actionDirectMode => 'Direct mode';

  @override
  String get actionDelayTest => 'Test all delays';

  @override
  String get actionUpdateProfiles => 'Update profiles';

  @override
  String get disclaimer => 'Disclaimer';

  @override
  String get disclaimerDesc =>
      'Before using Flash (\"the Software\"), please read this statement carefully and make sure you understand it. Tapping \"Agree\" means you have read and understood what follows. If you do not want to continue, tap \"Exit\".';

  @override
  String get disclaimerSoftwareTitle => 'Nature of the software';

  @override
  String get disclaimerSoftwareContent =>
      'The Software is an open-source network proxy client built on the Clash.Meta (mihomo) core. It only provides local tooling such as configuration management, rule-based routing, and traffic forwarding.';

  @override
  String get disclaimerNoServiceStatement =>
      'The Software itself does not provide any proxy server, node, subscription, or network access service, and has no partnership, agency, or guarantee relationship with any provider of such services.';

  @override
  String get disclaimerUsageTitle => 'About use';

  @override
  String get disclaimerUsageContent =>
      'Any commercial activity anyone carries out with the Software, including paid distribution, bundled sales, or use as part of a commercial service, is unrelated to the Software\'s developers, who do not endorse, support, or guarantee it.\n\nYou are responsible for complying with the laws where you live, and you bear the consequences of any unlawful use of the Software.';

  @override
  String get disclaimerResponsibilityTitle => 'Your responsibility';

  @override
  String get disclaimerResponsibilityContent =>
      'You are responsible for making sure that using the Software is lawful where you live, and you alone bear the legal responsibility for everything you do with it and its consequences.\n\nThe subscriptions, nodes, and configurations you import are your own choice. Whether their source is lawful, their content is safe, and their service is reliable is a matter between you and their providers.';

  @override
  String get disclaimerThirdPartyTitle => 'Third-party content';

  @override
  String get disclaimerThirdPartyContent =>
      'Subscription links, configuration files, rule sets, scripts, external resources, and external links are all provided by third parties. The developers cannot and do not review or guarantee their legality, accuracy, security, or availability.\n\nAny data leak, financial loss, account ban, or other loss caused by third-party content is to be settled between you and the third party; the developers bear no responsibility for it.';

  @override
  String get disclaimerWarrantyTitle => 'No warranty';

  @override
  String get disclaimerWarrantyContent =>
      'The Software is provided \"as is\" and \"as available\", without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, non-infringement, uninterrupted availability, freedom from errors, or freedom from security vulnerabilities.\n\nThe developers do not guarantee that the Software will meet your needs or that it will run without interruption or error.';

  @override
  String get disclaimerLiabilityTitle => 'Limitation of liability';

  @override
  String get disclaimerLiabilityContent =>
      'To the maximum extent permitted by applicable law, neither the developers nor any contributor shall be liable for any direct, indirect, incidental, special, punitive, or consequential damages arising from the use of or inability to use the Software, including but not limited to data loss, device damage, network failures, business interruption, lost profits, or any resulting legal dispute, even if advised of the possibility of such damages.';

  @override
  String get disclaimerPrivacyTitle => 'Data collection and privacy';

  @override
  String get disclaimerPrivacyContent =>
      'The Software does not collect or upload your subscription URLs, node details, configuration content, visited websites, connection records, traffic content, or logs. This data stays on your device and the developers have no access to it.\n\nThe Software only reaches the network when you use a feature that needs it, such as fetching the subscription URL you provided when updating a profile, or contacting GitHub when checking for updates.\n\nThe Software includes no analytics or crash reporting service on any platform.';

  @override
  String get disclaimerLicenseTitle => 'Open-source license';

  @override
  String get disclaimerLicenseContent =>
      'The Software is open source under the GPL-3.0 license. Under that license you may run, study, modify, and distribute it; when you distribute the Software or a modified version, you must provide its source code under GPL-3.0 as well and keep the original copyright notices.\n\nThird-party components in the Software, including the Clash.Meta core, follow their own licenses. The original authors are not responsible for any problem arising from versions modified or distributed by others.';

  @override
  String get disclaimerChangesTitle => 'Changes to this statement';

  @override
  String get disclaimerChangesContent =>
      'This statement may be revised in later releases; each release carries the version that applies to it.';

  @override
  String get disclaimerAcceptTitle => 'Relation to the open-source license';

  @override
  String get disclaimerAcceptContent =>
      'This statement explains the nature, risks, and responsibilities of using the Software. It is not an additional term beyond GPL-3.0 and does not limit any right that license grants you, including to run, copy, modify, and distribute the Software. Where the two differ, GPL-3.0 prevails.';

  @override
  String get disclaimerRestateTitle => 'Restate the statement';

  @override
  String get disclaimerRestateTip =>
      'To confirm you understand, enter the following statement in full in the field below:';

  @override
  String get disclaimerRestateHint => 'Enter the statement above';

  @override
  String get disclaimerRestateMismatch => 'Does not match the statement';

  @override
  String get disclaimerAcknowledgeTitle => 'Confirm the statement';

  @override
  String get disclaimerAcknowledgeTip =>
      'To confirm you understand, read the following statement and check the box below:';

  @override
  String get disclaimerAcknowledgeLabel =>
      'I have read and understand this statement';

  @override
  String get agree => 'Agree';

  @override
  String get hotkeyManagement => 'Hotkey management';

  @override
  String get hotkeyDesc =>
      'Global hotkeys work even while the window is hidden. Tap an action to record its key combination.';

  @override
  String get hotkeyNotSet => 'Not set';

  @override
  String get pressKeyboard => 'Press a key combination';

  @override
  String hotkeyNeedsModifier(Object modifiers) {
    return 'Include at least one of $modifiers';
  }

  @override
  String hotkeyConflictWith(Object action) {
    return 'Already used by “$action”. Saving moves it here.';
  }

  @override
  String get hotkeyUnavailable =>
      'Not registered, it may be taken by another app';

  @override
  String get remove => 'Remove';

  @override
  String get noNetwork => 'No network';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get exportSuccess => 'Export successful';

  @override
  String get iconStyle => 'Icon style';

  @override
  String get iconStyleFilled => 'Filled';

  @override
  String get iconStylePlain => 'Plain';

  @override
  String get iconStyleHidden => 'Hidden';

  @override
  String get filter => 'Filter';

  @override
  String get groupBy => 'Group by';

  @override
  String get hideTimeoutProxies => 'Hide timed-out proxies';

  @override
  String get showHiddenGroups => 'Show hidden groups';

  @override
  String get hiddenGroupTag => 'Hidden';

  @override
  String hiddenGroupSemantics(Object name) {
    return '$name, Hidden';
  }

  @override
  String get stackMode => 'Stack mode';

  @override
  String get network => 'Network';

  @override
  String get bypassDomain => 'Bypass domains';

  @override
  String get pacMode => 'PAC mode';

  @override
  String get pacScript => 'PAC script';

  @override
  String get bypassDomainDesc =>
      'Bypass domains apply only while the system proxy is on.';

  @override
  String get bypassLocalWindowsOnly => 'Windows only: host names without a dot';

  @override
  String get resetTip => 'Are you sure you want to reset?';

  @override
  String get icon => 'Icon';

  @override
  String get noData => 'No data';

  @override
  String get fontFamily => 'Font family';

  @override
  String get installedFonts => 'Installed fonts';

  @override
  String get toggle => 'Toggle';

  @override
  String get system => 'System';

  @override
  String get routeAddress => 'Route addresses';

  @override
  String get interfaceNameMode => 'Outbound interface';

  @override
  String get interfaceNameModeClear => 'Clear';

  @override
  String get interfaceNameModeFollow => 'Follow config';

  @override
  String get interfaceNameModeCustom => 'Custom';

  @override
  String get interfaceName => 'Interface name';

  @override
  String get copyEnvVar => 'Copy environment variables';

  @override
  String get trayTunMode => 'TUN mode';

  @override
  String get trayCopyProxyCommand => 'Copy terminal proxy command';

  @override
  String get memoryInfo => 'Memory info';

  @override
  String get total => 'Total';

  @override
  String get releaseMemory => 'Release memory';

  @override
  String get memoryCoreHeapInuse => 'Heap in use';

  @override
  String get memoryCoreHeapIdle => 'Heap idle';

  @override
  String get memoryCoreStack => 'Goroutine stacks';

  @override
  String get memoryCoreRuntime => 'Runtime overhead';

  @override
  String get memoryGoRuntimeDescription =>
      'Go runtime statistics; these values are not a breakdown of process resident memory.';

  @override
  String get memoryCoreNotRunning => 'Core is not running';

  @override
  String get memoryAppResident => 'Resident memory';

  @override
  String get memoryAppShared => 'App & shared';

  @override
  String get memoryEstimateDesc =>
      'Estimated from process resident memory; it may differ from what the system reports.';

  @override
  String get memoryEstimateSharedDesc =>
      'The Core runs inside the app process. Its share is estimated from runtime stats, and the rest counts as app and shared memory.';

  @override
  String get memoryReleased => 'Memory released';

  @override
  String memoryReleasedSize(Object size) {
    return 'Released $size';
  }

  @override
  String get releaseMemoryFailed => 'Failed to release memory';

  @override
  String get dialog => 'Dialog';

  @override
  String get cancel => 'Cancel';

  @override
  String get fileIsUpdate => 'The file has been modified. Save the changes?';

  @override
  String get profileHasUpdate =>
      'The profile has been modified. Turn off auto update?';

  @override
  String get hasCacheChange => 'Cache the changes?';

  @override
  String get copySuccess => 'Copied successfully';

  @override
  String get copyLink => 'Copy link';

  @override
  String get exportFile => 'Export file';

  @override
  String get cacheCorrupt => 'The cache is corrupted. Clear it?';

  @override
  String get detectionTip => 'Relies on a third-party API; for reference only';

  @override
  String get listen => 'Listen';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get lineWrap => 'Word wrap';

  @override
  String get none => 'None';

  @override
  String get advancedConfig => 'Advanced configuration';

  @override
  String get addRule => 'Add rule';

  @override
  String get content => 'Content';

  @override
  String get ruleTarget => 'Rule target';

  @override
  String get matchTarget => 'MATCH-TARGET';

  @override
  String get followProfile => 'Follow profile';

  @override
  String get scriptFailed => 'The script failed';

  @override
  String get sourceIp => 'Source IP';

  @override
  String get noResolve => 'Don\'t resolve IP';

  @override
  String get saveChanges => 'Save the changes?';

  @override
  String get applyNow => 'Apply now';

  @override
  String get applied => 'Applied';

  @override
  String get cannotSave => 'Can\'t save';

  @override
  String get navigationBarStyle => 'Bottom bar';

  @override
  String get floating => 'Floating';

  @override
  String get docked => 'Docked';

  @override
  String get slide => 'Slide';

  @override
  String get fade => 'Fade';

  @override
  String get pureBlack => 'Pure black';

  @override
  String get customColor => 'Custom color';

  @override
  String get colorStyle => 'Color style';

  @override
  String get grid => 'Grid';

  @override
  String get spectrum => 'Spectrum';

  @override
  String get sliders => 'Sliders';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String get brightness => 'Brightness';

  @override
  String get hex => 'Hex';

  @override
  String get monochromeScheme => 'Monochrome';

  @override
  String get vividStyle => 'Vivid';

  @override
  String get tintedStyle => 'Tinted';

  @override
  String get softStyle => 'Soft';

  @override
  String get developerMode => 'Developer mode';

  @override
  String get developerModeEnableTip => 'Developer mode is enabled.';

  @override
  String get messageTest => 'Message test';

  @override
  String get messageTestTip => 'This is a message.';

  @override
  String get crashTest => 'Crash test';

  @override
  String get crashDetected => 'Crash detected';

  @override
  String crashDetectedTip(Object name) {
    return 'The app failed to finish launching twice in a row. To break the loop, the profile $name has been deselected and automatic setup was skipped. You can select it again at any time.';
  }

  @override
  String get launchInterrupted => 'Launch did not finish';

  @override
  String get launchInterruptedTip =>
      'The app exited unexpectedly while it was starting up last time. Automatic setup was skipped for this launch; you can start it manually to retry.';

  @override
  String get clearData => 'Clear data';

  @override
  String get textScale => 'Text scaling';

  @override
  String get textScalePreview => 'Text in the app will look like this';

  @override
  String get followSystem => 'Follow system';

  @override
  String get internet => 'Internet';

  @override
  String get systemApp => 'System apps';

  @override
  String get noNetworkApp => 'No-network apps';

  @override
  String get restoreStrategy => 'Restore strategy';

  @override
  String get restoreStrategyOverride => 'Override';

  @override
  String get restoreStrategyCompatible => 'Compatible';

  @override
  String get logsTest => 'Logs test';

  @override
  String emptyTip(Object label) {
    return '$label cannot be empty';
  }

  @override
  String urlTip(Object label) {
    return '$label must be a URL';
  }

  @override
  String get invalidLinkTip => 'Not a subscription link or a proxy share link';

  @override
  String numberTip(Object label) {
    return '$label must be a number';
  }

  @override
  String numberRangeTip(Object label, Object min, Object max) {
    return '$label must be between $min and $max';
  }

  @override
  String get interval => 'Interval';

  @override
  String existsTip(Object label) {
    return '$label already exists';
  }

  @override
  String maxLengthTip(Object label, Object max) {
    return '$label must be at most $max characters';
  }

  @override
  String get singleImport => 'Single import';

  @override
  String get batchImport => 'Batch import';

  @override
  String get batchUrlInputTip => 'One URL per line';

  @override
  String get batchLinkInputTip => 'One link per line';

  @override
  String batchPreviewTip(Object count, Object skipped) {
    return '$count to add, $skipped skipped as existing';
  }

  @override
  String lineIssueTip(Object line, Object message) {
    return 'Line $line: $message';
  }

  @override
  String singleValueTip(Object label) {
    return '$label must be a single item';
  }

  @override
  String deleteTip(Object label) {
    return 'Are you sure you want to delete this $label?';
  }

  @override
  String deleteMultipTip(Object label) {
    return 'Are you sure you want to delete the selected $label?';
  }

  @override
  String nullTip(Object label) {
    return 'No $label yet';
  }

  @override
  String get script => 'Script';

  @override
  String get color => 'Color';

  @override
  String get unnamed => 'Unnamed';

  @override
  String get pleaseEnterScriptName => 'Please enter a script name';

  @override
  String get mixedPort => 'Mixed port';

  @override
  String get socksPort => 'SOCKS port';

  @override
  String get redirPort => 'Redir port';

  @override
  String get tproxyPort => 'TProxy port';

  @override
  String portTip(Object label) {
    return '$label must be between 1024 and 49151';
  }

  @override
  String get portConflictTip => 'Please enter a different port';

  @override
  String get import => 'Import';

  @override
  String get importFile => 'Import from file';

  @override
  String get importUrl => 'Import from URL';

  @override
  String get startFromScratch => 'Start from scratch';

  @override
  String details(Object label) {
    return '$label details';
  }

  @override
  String get creationTime => 'Creation time';

  @override
  String get process => 'Process';

  @override
  String get host => 'Host';

  @override
  String get destination => 'Destination';

  @override
  String get destinationGeoIP => 'Destination GeoIP';

  @override
  String get destinationIPASN => 'Destination IP ASN';

  @override
  String get specialProxy => 'Special proxy';

  @override
  String get specialRules => 'Special rules';

  @override
  String get remoteDestination => 'Remote destination';

  @override
  String get networkType => 'Network type';

  @override
  String get proxyChains => 'Proxy chain';

  @override
  String get log => 'Log';

  @override
  String get connection => 'Connection';

  @override
  String get request => 'Request';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting…';

  @override
  String get restartCoreTip => 'Are you sure you want to restart the core?';

  @override
  String get forceRestartCoreTip =>
      'Are you sure you want to force restart the core?';

  @override
  String get dnsHijacking => 'DNS hijacking';

  @override
  String get coreStatus => 'Core status';

  @override
  String get appendSystemDns => 'Append system DNS';

  @override
  String get editRule => 'Edit rule';

  @override
  String get addedRules => 'Added rules';

  @override
  String get addedRulesAfterScript =>
      'Inserted after the script runs, ahead of the profile\'s rules';

  @override
  String get controlGlobalAddedRules => 'Control global added rules';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get rulePresetBlockQuic => 'Block QUIC';

  @override
  String get rulePresetBlockStun => 'Block STUN';

  @override
  String get rulePresetBlockDot => 'Block DNS over TLS';

  @override
  String get rulePresetBlockLoopback => 'Block proxy loopback';

  @override
  String get rulePresetSystemServicesDirect => 'Apple and Microsoft direct';

  @override
  String get rulePresetBittorrentDirect => 'BitTorrent direct';

  @override
  String get rulePresetLanDirect => 'LAN direct';

  @override
  String get extendScript => 'Extend script';

  @override
  String get goToConfigureScript => 'Go to script configuration';

  @override
  String get goToConfigureAddedRules => 'Go to added rules configuration';

  @override
  String get editGlobalRules => 'Edit global rules';

  @override
  String get confirmForceCrashCore =>
      'Are you sure you want to force crash the core?';

  @override
  String get confirmClearAllData => 'Are you sure you want to clear all data?';

  @override
  String get loading => 'Loading…';

  @override
  String yearsAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Just now';

  @override
  String yearsAgoShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}y ago',
    );
    return '$_temp0';
  }

  @override
  String monthsAgoShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}mo ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgoShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}d ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgoShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}h ago',
    );
    return '$_temp0';
  }

  @override
  String minutesAgoShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}m ago',
    );
    return '$_temp0';
  }

  @override
  String get noLongerRemind => 'Don\'t remind me again';

  @override
  String get turnOn => 'Turn on';

  @override
  String get turnOff => 'Turn off';

  @override
  String get vpnConfigChangeDetected => 'VPN settings changed. Tap to restart';

  @override
  String get restart => 'Restart';

  @override
  String get speedStatistics => 'Speed statistics';

  @override
  String get resetPageChangesTip =>
      'This page has changes. Are you sure you want to reset?';

  @override
  String get customProfile => 'Custom';

  @override
  String get customResources => 'Custom';

  @override
  String get unknownNetworkError => 'Unknown network error';

  @override
  String get backupFromNewerVersion =>
      'This backup comes from a newer version of the app. Update the app before restoring it';

  @override
  String get networkTimeoutError =>
      'The request timed out. Check your network or proxy, then try again';

  @override
  String get networkHostLookupError =>
      'Couldn\'t resolve the server address. Check that the URL is correct and DNS is working';

  @override
  String get monochromeIcon => 'Monochrome icon';

  @override
  String get networkConnectionError =>
      'Couldn\'t connect to the server. Check your network connection or proxy settings';

  @override
  String get networkTlsError =>
      'Secure connection failed. The server\'s certificate may be invalid, or the connection is being intercepted';

  @override
  String get networkCancelledError => 'The request was cancelled';

  @override
  String networkAccessDeniedError(Object code) {
    return 'The server denied access (HTTP $code). The link may have expired, or the credentials are wrong';
  }

  @override
  String networkNotFoundError(Object code) {
    return 'Nothing was found at this address (HTTP $code). Check that the URL is correct';
  }

  @override
  String get networkRateLimitedError =>
      'Too many requests (HTTP 429). Wait a moment and try again';

  @override
  String networkServerError(Object code) {
    return 'The server ran into a problem (HTTP $code). Try again later';
  }

  @override
  String networkBadResponseError(Object code) {
    return 'The server rejected the request (HTTP $code)';
  }

  @override
  String networkRequestFailed(Object detail) {
    return 'Network request failed: $detail';
  }

  @override
  String get invalidBackupFile => 'Invalid backup file';

  @override
  String get pruneCache => 'Prune cache';

  @override
  String get backupAndRestore => 'Backup and restore';

  @override
  String get restore => 'Restore';

  @override
  String get restoreSuccess => 'Restore successful';

  @override
  String get restoreOnlyConfig => 'Restore profiles only';

  @override
  String get restoreAllData => 'Restore all data';

  @override
  String get restoreRuleSetDownloadNotice =>
      'Backups retain rule set settings. After restoring, connect to the internet to download rule sets again; everyday restarts and profile switches do not require another download.';

  @override
  String get addProfile => 'Add profile';

  @override
  String get delayTest => 'Delay test';

  @override
  String get proxyGroupEmpty => 'Proxy group is empty';

  @override
  String get confirmExitWindow =>
      'Are you sure you want to exit the current window?';

  @override
  String get optional => 'Optional';

  @override
  String get maxFailedTimes => 'Max failures';

  @override
  String get testInterval => 'Test interval';

  @override
  String get excludeFilter => 'Exclude filter';

  @override
  String get expectedStatus => 'Expected status';

  @override
  String get strategy => 'Strategy';

  @override
  String get tolerance => 'Tolerance';

  @override
  String get inputProxyGroupName => 'Enter the proxy group name';

  @override
  String get helperCorruptTip =>
      'Helper service unavailable; TUN mode cannot be enabled. Reinstall Flash to restore it.';

  @override
  String get tunAuthorizationFailed =>
      'TUN authorization wasn’t completed. The configuration was not applied. Your in-app setting was kept.';

  @override
  String mixedPortUnavailable(Object port) {
    return 'Could not open port $port. Another app may be using it. The proxy service did not start.';
  }

  @override
  String mixedPortUnavailableProxyUnchanged(Object port) {
    return 'Could not open port $port. Another app may be using it. The proxy service did not start. System proxy settings were not changed.';
  }

  @override
  String get sudoPasswordTitle => 'Enter your password for sudo';

  @override
  String coreBlockedByPolicyTip(Object code) {
    return 'Windows refused to run FlClashCore.exe (error $code). An app control policy such as Smart App Control or AppLocker blocks unsigned programs; allow Flash in that policy or turn it off, then try again.';
  }

  @override
  String get coreBlockedBySmartAppControlTip =>
      'Windows Smart App Control blocked FlClashCore.exe because it is not signed. Open Windows Security → App & browser control → Smart App Control settings, choose Off, then start Flash again. Smart App Control cannot be turned back on without reinstalling Windows.';

  @override
  String get hideFromList => 'Hide from list';

  @override
  String get testWhenUsed => 'Test when used';

  @override
  String get disableUDP => 'Disable UDP';

  @override
  String get confirmDeleteProxyGroup =>
      'Are you sure you want to delete this proxy group?';

  @override
  String get ruleEmpty => 'Rule is empty';

  @override
  String get inputRuleContent => 'Enter the rule content';

  @override
  String get ruleSet => 'Rule set';

  @override
  String get selectRuleSet => 'Please select a rule set';

  @override
  String get splitStrategy => 'Split strategy';

  @override
  String get selectSplitStrategy => 'Please select a split strategy';

  @override
  String get noResolveHostname => 'Don\'t resolve hostname';

  @override
  String get matchSourceIp => 'Match source IP';

  @override
  String get basicInfo => 'Basic info';

  @override
  String get additionalParameters => 'Additional parameters';

  @override
  String get proxyType => 'Proxy type';

  @override
  String get basicStrategy => 'Basic strategies';

  @override
  String get editProxy => 'Edit proxy';

  @override
  String get addNodes => 'Add nodes';

  @override
  String get addProxyGroup => 'Add proxy group';

  @override
  String get editProxyGroup => 'Edit proxy group';

  @override
  String get iconUrl => 'Icon URL';

  @override
  String get iconRecords => 'Icon records';

  @override
  String get custom => 'Custom';

  @override
  String get ruleActionDomainDesc => 'Match the full domain';

  @override
  String get ruleActionDomainSuffixDesc => 'Match a domain suffix';

  @override
  String get ruleActionDomainKeywordDesc => 'Match a domain keyword';

  @override
  String get ruleActionDomainRegexDesc => 'Match a domain regex';

  @override
  String get ruleActionDomainWildcardDesc =>
      'Wildcard match; only * and ? are supported';

  @override
  String get ruleActionGeositeDesc => 'Match domains in Geosite';

  @override
  String get ruleActionIpCidrDesc => 'Match an IP address range';

  @override
  String get ruleActionIpCidr6Desc =>
      'Match an IP address range; IP-CIDR6 is just an alias';

  @override
  String get ruleActionIpSuffixDesc => 'Match an IP suffix range';

  @override
  String get ruleActionIpAsnDesc => 'Match the IP\'s ASN';

  @override
  String get ruleActionGeoipDesc => 'Match the IP\'s country code';

  @override
  String get ruleActionSrcGeoipDesc => 'Match the source IP\'s country code';

  @override
  String get ruleActionSrcIpAsnDesc => 'Match the source IP\'s ASN';

  @override
  String get ruleActionSrcIpCidrDesc => 'Match a source IP address range';

  @override
  String get ruleActionSrcIpSuffixDesc => 'Match a source IP suffix range';

  @override
  String get ruleActionDstPortDesc => 'Match the destination port range';

  @override
  String get ruleActionSrcPortDesc => 'Match the source port range';

  @override
  String get ruleActionInPortDesc => 'Match the inbound port';

  @override
  String get ruleActionInTypeDesc => 'Match the inbound type';

  @override
  String get ruleActionInUserDesc =>
      'Match the inbound username; separate multiple usernames with /';

  @override
  String get ruleActionInNameDesc => 'Match the inbound name';

  @override
  String get ruleActionRematchNameDesc =>
      'Match the rematch name; separate multiple names with /';

  @override
  String get ruleActionProcessPathDesc => 'Match by the full process path';

  @override
  String get ruleActionProcessPathRegexDesc => 'Match by process path regex';

  @override
  String get ruleActionProcessPathWildcardDesc =>
      'Match by process path wildcard; only * and ? are supported';

  @override
  String get ruleActionProcessNameDesc =>
      'Match by process name; matches the package name on Android';

  @override
  String get ruleActionProcessNameRegexDesc =>
      'Match by process name regex; matches the package name on Android';

  @override
  String get ruleActionProcessNameWildcardDesc =>
      'Match by process name wildcard; only * and ? are supported';

  @override
  String get ruleActionUidDesc => 'Match the Linux user ID';

  @override
  String get ruleActionNetworkDesc => 'Match TCP or UDP';

  @override
  String get ruleActionDscpDesc =>
      'Match the DSCP mark (tproxy UDP inbound only)';

  @override
  String get ruleActionRuleSetDesc =>
      'Reference a rule set; requires rule-providers';

  @override
  String get ruleActionAndDesc => 'Logical rule AND';

  @override
  String get ruleActionOrDesc => 'Logical rule OR';

  @override
  String get ruleActionNotDesc => 'Logical rule NOT';

  @override
  String get ruleActionSubRuleDesc =>
      'Match into a sub-rule; mind the parentheses';

  @override
  String get ruleActionMatchDesc => 'Match all requests, no conditions needed';

  @override
  String get contentNotEmpty => 'Content cannot be empty';

  @override
  String get splitStrategyNotEmpty => 'Split strategy cannot be empty';

  @override
  String get timeout => 'Timeout';

  @override
  String get delayFailed => 'Failed';

  @override
  String invalidSubRule(Object subRule) {
    return '$subRule is an invalid SUB_RULE';
  }

  @override
  String invalidPolicy(Object target) {
    return '$target is an invalid policy';
  }

  @override
  String invalidProxyProvider(Object providerName) {
    return '$providerName is an invalid proxy provider';
  }

  @override
  String invalidRuleSet(Object ruleSet) {
    return '$ruleSet is an invalid rule set';
  }

  @override
  String get invalidNetworkContent => 'Only tcp or udp is supported';

  @override
  String get invalidRangeContent =>
      'Enter numbers or ranges such as 80 or 8000-9000, separated by /';

  @override
  String get invalidDscpContent => 'A DSCP mark cannot exceed 63';

  @override
  String get invalidCidrContent =>
      'Enter an IP range in CIDR form such as 192.168.0.0/16';

  @override
  String get invalidPortRangeContent =>
      'Enter a port or a range such as 443 or 8000-9000';

  @override
  String get invalidHostContent => 'Enter a domain or an IP address';

  @override
  String get invalidListenContent =>
      'Enter an address and port such as 0.0.0.0:1053';

  @override
  String invalidProxy(Object proxyName) {
    return '$proxyName is an invalid proxy';
  }

  @override
  String get locationPermissionRequired => 'Location permission required';

  @override
  String locationPermissionGuide(Object appName) {
    return '1. Open System Settings > Privacy & Security\n2. Choose Location Services\n3. Find and check $appName in the list\n\nWhen you are done, return to the app to continue. Thank you for your cooperation.';
  }

  @override
  String get prerequisites => 'Prerequisites';

  @override
  String get ignoreBatteryOptimization => 'Ignore battery optimization';

  @override
  String get locationPermission => 'Location permission';

  @override
  String get locationPermissionDesc =>
      'The system requires location permission to read the Wi-Fi name. On Android choose \"Allow all the time\", otherwise the Wi-Fi name cannot be read while the app is in the background.';

  @override
  String get excludeSsids => 'Exclude SSIDs';

  @override
  String get excludeSsidsDesc =>
      'When connected to Wi-Fi with an excluded SSID, the app\'s running state switches automatically.';

  @override
  String get ssidsEmpty => 'SSIDs are empty';

  @override
  String get onDemand => 'On demand';

  @override
  String get locationPermissionDeniedMessage =>
      'Location permission was denied, so the current Wi-Fi name cannot be read. Please enable location permission manually in system settings.';

  @override
  String get addSsid => 'Add SSID';

  @override
  String get editSsid => 'Edit SSID';

  @override
  String get authorized => 'Authorized';

  @override
  String get tapToAuthorize => 'Tap to authorize';

  @override
  String get suspended => 'Suspended…';

  @override
  String get resourceUpdateInterval => 'Auto-update interval';

  @override
  String get resourceUpdateIntervalTip =>
      'The auto-update interval must be greater than 0';

  @override
  String get hours => 'hours';

  @override
  String get minutes => 'minutes';

  @override
  String get geoResources => 'Geo';

  @override
  String geoSkipped(Object name) {
    return '$name is already up to date';
  }

  @override
  String geoUpdated(Object name) {
    return '$name updated';
  }

  @override
  String secondsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String proxiesCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label proxies',
      one: '1 proxy',
    );
    return '$_temp0';
  }

  @override
  String rulesCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String proxyGroupsCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label proxy groups',
      one: '1 proxy group',
    );
    return '$_temp0';
  }

  @override
  String get changelogBreaking => 'Breaking changes';

  @override
  String get changelogFeatures => 'New features';

  @override
  String get changelogFixes => 'Bug fixes';

  @override
  String get changelogPerformance => 'Performance';

  @override
  String get changelogReverts => 'Reverts';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get unmaximize => 'Restore down';

  @override
  String get pinWindow => 'Pin window';

  @override
  String get unpinWindow => 'Unpin window';

  @override
  String get exitFullScreen => 'Exit full screen';

  @override
  String get torch => 'Flashlight';

  @override
  String get pickFromAlbum => 'Choose from album';

  @override
  String get closeConnections => 'Close connections';

  @override
  String get scrollToSelected => 'Scroll to selected';

  @override
  String get showMore => 'Expand';

  @override
  String get showLess => 'Collapse';

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noSearchResults => 'No matching results';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get authorize => 'Authorize';

  @override
  String get installedAppsPermissionRequired => 'App list permission required';

  @override
  String get installedAppsPermissionDesc =>
      'This system hides the installed app list until the permission is granted. Authorize it to configure the per-app proxy.';

  @override
  String get installedAppsPermissionDeniedMessage =>
      'The app list permission was denied, so installed apps cannot be listed. Please grant it manually in system settings.';

  @override
  String get outboundIp => 'Outbound IP';

  @override
  String get ipAddress => 'IP address';

  @override
  String get ipQualityLevel => 'Level';

  @override
  String get ipQualityGood => 'Good';

  @override
  String get ipQualityNormal => 'Normal';

  @override
  String get ipQualityRisky => 'Risky';

  @override
  String get ipType => 'Type';

  @override
  String get ipTypeResidential => 'Residential';

  @override
  String get ipTypeMobile => 'Mobile network';

  @override
  String get ipTypeBusiness => 'Business';

  @override
  String get ipTypeHosting => 'Data center';

  @override
  String get ipFlags => 'Flags';

  @override
  String get ipFlagProxy => 'Proxy';

  @override
  String get ipFlagVpn => 'VPN';

  @override
  String get ipFlagTor => 'Tor';

  @override
  String get ipFlagAbuser => 'Abuse history';

  @override
  String get ipOrganization => 'Organization';

  @override
  String get ipAsn => 'ASN';

  @override
  String get ipQualitySource => 'Answered by';

  @override
  String get ipQualitySources => 'Sources';

  @override
  String get ipQualityFailed => 'Couldn\'t determine the IP type';

  @override
  String get ipQualityRetry => 'Check again';

  @override
  String get ipSourceNoType => 'No type';

  @override
  String get ipSourceRateLimited => 'Rate limited';

  @override
  String get ipSourceIpMismatch => 'Different outbound IP';

  @override
  String get hideIp => 'Hide IP';

  @override
  String get editorUnavailable => 'Editor unavailable';

  @override
  String get replace => 'Replace';

  @override
  String get replaceAll => 'Replace all';

  @override
  String get cameraPermissionRequired => 'Camera permission required';

  @override
  String get cameraPermissionDesc =>
      'Allow camera access in system settings to scan QR codes, or choose a QR code image from the album.';

  @override
  String get cameraUnavailable => 'Camera unavailable';

  @override
  String get retry => 'Retry';

  @override
  String get invalidProfileQrcode =>
      'This QR code doesn\'t contain a profile link';

  @override
  String get dnsQueries => 'DNS queries';

  @override
  String get recordType => 'Record type';

  @override
  String get answers => 'Answers';

  @override
  String get responseCode => 'Response code';

  @override
  String get error => 'Error';

  @override
  String get initiator => 'Initiator';

  @override
  String get cache => 'Cache';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get nonTextProviderFile => 'This external resource is not a text file';

  @override
  String get addCustomProxy => 'Add proxy';

  @override
  String get definitionNotMap =>
      'The configuration must be a YAML mapping with a name and a type';

  @override
  String get ruleTextInvalid =>
      'The rule must start with a supported type, such as DOMAIN,example.com,DIRECT';

  @override
  String get ruleListInvalid =>
      'The rules must be a YAML list with one rule per item, such as - DOMAIN,example.com,DIRECT';

  @override
  String get shareLinksInvalid => 'No proxy could be read from the links';

  @override
  String shareLinkUnreadable(Object link) {
    return 'No proxy could be read from $link';
  }

  @override
  String proxiesProfileLabel(Object name, Object count) {
    return '$name and others ($count proxies)';
  }

  @override
  String get singleShareLinkOnly =>
      'Enter one link here; edit several from the quick edit of the list';

  @override
  String get username => 'Username';

  @override
  String get emptyFallback => 'Empty fallback';

  @override
  String get defaultSelected => 'Default selection';

  @override
  String get hashByInUser => 'Hash by inbound user';

  @override
  String get appProxiesEmpty => 'No local proxies';

  @override
  String get nodes => 'Nodes';

  @override
  String get localProxies => 'Local proxies';

  @override
  String get customIssueEmptyName => 'The name is empty';

  @override
  String customIssueReservedName(Object name) {
    return '$name is a built-in policy name and cannot be used here';
  }

  @override
  String customIssueDuplicateName(Object name) {
    return 'The name $name is already used by another proxy or proxy group';
  }

  @override
  String customIssueCoreRejected(Object message) {
    return 'The core cannot parse this proxy: $message';
  }

  @override
  String customIssueMissingProxies(Object names) {
    return 'These proxies or policies do not exist: $names';
  }

  @override
  String customIssueMissingProviders(Object names) {
    return 'These proxy providers do not exist: $names';
  }

  @override
  String get customIssueNoProxySource =>
      'No proxies or proxy providers are selected, so the core rejects this group';

  @override
  String customIssueGroupLoop(Object path) {
    return 'Proxy groups reference each other in a loop: $path';
  }

  @override
  String customIssueInvalidEmptyFallback(Object name) {
    return 'The empty fallback must be a proxy, but $name does not exist or is a proxy group';
  }

  @override
  String customIssueInvalidFilter(Object name, Object message) {
    return '$name is not a valid regex: $message';
  }

  @override
  String customIssueMissingDialer(Object name) {
    return 'The dialer proxy $name does not exist';
  }

  @override
  String customIssueDialerLoop(Object proxy, Object target) {
    return '$proxy dials through $target, which leads back to $proxy, so the dial loops';
  }

  @override
  String dialerProxyLoopStopped(Object name) {
    return 'Dialing through $name leads back to the proxy that uses it, so the connection was stopped';
  }

  @override
  String customIssuesSummary(Object count) {
    return '$count items have problems, and applying this profile may fail';
  }

  @override
  String providerInUse(Object label, Object profiles) {
    return '$label is still used by $profiles, which will not work properly once it is deleted. Are you sure you want to delete it?';
  }

  @override
  String proxyGroupInUse(Object label) {
    return '$label is still named by rules, proxy groups, dialer proxies, DNS or NTP in this profile, which stop working once it is deleted. Are you sure you want to delete it?';
  }

  @override
  String proxiesRemovedTip(Object removed) {
    return 'These proxies will be deleted: $removed. A line whose name changed counts as a new proxy, and custom profiles naming the deleted ones will flag them as missing. Apply anyway?';
  }

  @override
  String proxiesReplacedTip(Object removed, Object added) {
    return 'These proxies will be deleted: $removed. These will be added: $added. A line whose name changed counts as a new proxy, and custom profiles naming the deleted ones will flag them as missing. Apply anyway?';
  }

  @override
  String get fontSize => 'Size';

  @override
  String get large => 'Large';

  @override
  String get extraLarge => 'Extra large';

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get filters => 'Filters';

  @override
  String get label => 'Label';

  @override
  String get regex => 'Regex';

  @override
  String get matchCase => 'Match case';

  @override
  String get iconSets => 'Icon sets';

  @override
  String get invalidIconSet => 'Not a valid icon set';

  @override
  String get recommendedIcons => 'Suggested';

  @override
  String get localImage => 'Local image';

  @override
  String get iconSetsEmptyTip =>
      'No icon sets yet. Add them in Custom profile resources → Icon sets';

  @override
  String get outbound => 'Outbound';

  @override
  String get strictRoute => 'Strict route';

  @override
  String get congestionController => 'TCP congestion control';

  @override
  String get congestionControllerDesc =>
      'TCP congestion control works only with the mips stack.';

  @override
  String get routeExcludeAddress => 'Route exclude addresses';

  @override
  String get keepAliveIdle => 'TCP keep-alive idle';

  @override
  String get disableKeepAlive => 'Disable TCP keep-alive';

  @override
  String get routingMark => 'Routing mark';

  @override
  String get strictRouteDesc =>
      'Strict route keeps traffic such as DNS from bypassing TUN, and with IPv6 off it blocks this device\'s IPv6 connections.';

  @override
  String get initFailed => 'Startup failed';

  @override
  String get initFailedTip =>
      'Flash ran into an error while starting and can\'t continue. Copy the details to report the problem. If it keeps happening, clearing the data usually lets the app start again.';

  @override
  String get errorDetails => 'Error details';

  @override
  String get stackTrace => 'Stack trace';

  @override
  String get clearDataAndExitTip =>
      'This deletes all profiles, settings, and local data, then closes the app. Open it again to start fresh.';

  @override
  String clearDataFailed(Object detail) {
    return 'Couldn\'t clear the data: $detail';
  }

  @override
  String get bypassPrivateRoute => 'Bypass private addresses';

  @override
  String get disableIcmpForwarding => 'Disable ICMP forwarding';

  @override
  String get disableIcmpForwardingDesc =>
      'With ICMP forwarding disabled, TUN answers ping itself, so ping no longer shows the real latency.';

  @override
  String get excludeInterface => 'Excluded interfaces';

  @override
  String get includeInterface => 'Included interfaces';

  @override
  String get includeInterfaceDesc =>
      'Only traffic arriving on included interfaces goes through TUN, and excluded interfaces no longer apply.';

  @override
  String get includeUid => 'Included user IDs';

  @override
  String get excludeUid => 'Excluded user IDs';

  @override
  String get excludeSrcPort => 'Excluded source ports';

  @override
  String get excludeDstPort => 'Excluded destination ports';

  @override
  String get udpTimeout => 'UDP timeout';

  @override
  String get udpTimeoutDesc =>
      'The UDP timeout is in seconds and works only with the gvisor, system and mixed stacks.';

  @override
  String get dnsHijackDesc =>
      'Without this entry, TUN hijacks every DNS query to port 53 (any:53).';

  @override
  String get tunOverrideDesc =>
      'Entries added here replace the TUN settings of every profile; anything not added keeps the profile\'s own setting. Entries a custom profile adds itself take precedence.';

  @override
  String get generalOverrideDesc =>
      'Entries added here replace the setting of every profile; anything not added keeps the profile\'s own setting, or the core default when the profile has none.';

  @override
  String get profileTunSettingsDesc =>
      'Applies to this profile only and takes precedence over the TUN override entries in the network settings.';

  @override
  String settingsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settings',
      one: '1 setting',
    );
    return '$_temp0';
  }

  @override
  String sectionsInEffect(Object count) {
    return '$count in effect';
  }

  @override
  String itemsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get additionalPrefix => 'Name prefix';

  @override
  String get additionalSuffix => 'Name suffix';

  @override
  String get skipCertVerify => 'Skip certificate verification';

  @override
  String get ipVersion => 'IP version';

  @override
  String get addFilters => 'Add filters';

  @override
  String failedItem(Object label, Object message) {
    return '$label: $message';
  }

  @override
  String failedCount(Object count) {
    return '$count items failed. Tap to view';
  }

  @override
  String get importConfigInvalid =>
      'This file is not a config that can be imported';

  @override
  String get importConfigReplaceTip =>
      'Importing replaces the proxy groups, rules and settings this profile has now';

  @override
  String get networkName => 'Network name';

  @override
  String get networkSecret => 'Network secret';

  @override
  String get peers => 'Peers';

  @override
  String get virtualIpv4 => 'Virtual IPv4';

  @override
  String get hostname => 'Hostname';

  @override
  String get exitNodes => 'Exit nodes';

  @override
  String get cipher => 'Cipher';

  @override
  String get protocol => 'Protocol';

  @override
  String get protocolParam => 'Protocol parameter';

  @override
  String get obfs => 'Obfuscation';

  @override
  String get obfsParam => 'Obfuscation parameter';

  @override
  String get obfsPassword => 'Obfuscation password';

  @override
  String get obfsMode => 'Obfuscation mode';

  @override
  String get obfsHost => 'Obfuscation host';

  @override
  String get plugin => 'Plugin';

  @override
  String get pluginMode => 'Plugin mode';

  @override
  String get pluginHost => 'Plugin host';

  @override
  String get pluginPath => 'Plugin path';

  @override
  String get pluginUsername => 'Plugin username';

  @override
  String get pluginPassword => 'Plugin password';

  @override
  String get pluginCipher => 'Plugin cipher';

  @override
  String get privateKey => 'Private key';

  @override
  String get publicKey => 'Public key';

  @override
  String get privateKeyPassphrase => 'Private key passphrase';

  @override
  String get preSharedKey => 'Pre-shared key';

  @override
  String get secretKey => 'Key';

  @override
  String get transport => 'Transport';

  @override
  String get uploadBandwidth => 'Upload bandwidth';

  @override
  String get downloadBandwidth => 'Download bandwidth';

  @override
  String get protocolVersion => 'Protocol version';

  @override
  String get portHopping => 'Port hopping';

  @override
  String get hopInterval => 'Hop interval';

  @override
  String get congestionControl => 'Congestion control';

  @override
  String get udpRelayMode => 'UDP relay mode';

  @override
  String get allowedIps => 'Allowed IPs';

  @override
  String get remoteDnsResolve => 'Remote DNS resolution';

  @override
  String get clientFingerprint => 'Client fingerprint';

  @override
  String get requestHeaders => 'Request headers';

  @override
  String transportHeaders(Object transport) {
    return '$transport Headers';
  }

  @override
  String get required => 'Required';

  @override
  String get ageSecretKey => 'Age secret key';

  @override
  String get ageEncryptedProfile => 'Encrypted profile';

  @override
  String get ageSecretKeyRequiredTip =>
      'This profile is encrypted with age and needs an age secret key to decrypt';

  @override
  String get currentOutboundDesc =>
      'Holds the start button and can\'t be removed';

  @override
  String get running => 'Running';

  @override
  String get root => 'Root';

  @override
  String get notRunning => 'Not running';

  @override
  String trafficPeak(Object value) {
    return 'Peak $value';
  }

  @override
  String trafficTotal(Object value) {
    return 'Total $value';
  }

  @override
  String get ipQualityShort => 'Quality';

  @override
  String get ipTypeUnknown => 'Unknown type';

  @override
  String get tapIconToRetry => 'Tap the icon to retry';

  @override
  String get networkTakeover => 'Traffic takeover';

  @override
  String portValue(Object port) {
    return 'Port $port';
  }

  @override
  String serviceAbnormalCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0';
  }

  @override
  String get serviceAllAvailable => 'All available';

  @override
  String get serviceShownOnDashboard => 'Shown on the dashboard';

  @override
  String groupTimeoutCount(Object count) {
    return '$count timed out';
  }

  @override
  String get groupCountUnit => 'groups';

  @override
  String groupCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String get proxyGroupsAfterStart =>
      'Groups show up here once the core starts';

  @override
  String get usedShort => 'used';

  @override
  String profileUpdatedAt(Object time) {
    return 'Updated $time';
  }

  @override
  String profileExpiresIn(Object date, num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Expires $date, $_temp0 left';
  }

  @override
  String profileDaysLeft(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get target => 'Target';

  @override
  String get outboundExit => 'Exit';

  @override
  String get duration => 'Duration';

  @override
  String get traffic => 'Traffic';

  @override
  String get totalDownload => 'Downloaded';

  @override
  String get totalUpload => 'Uploaded';

  @override
  String get initiatorShort => 'From';

  @override
  String get result => 'Result';

  @override
  String get elapsed => 'Took';

  @override
  String get connectionStats => 'Connection stats';

  @override
  String get connectionStatsDesc =>
      'Live connections, recent requests and DNS queries';

  @override
  String get memoryInfoDesc => 'Memory the app and the core use';

  @override
  String get editDashboard => 'Edit dashboard';

  @override
  String get done => 'Done';

  @override
  String get dashboardAddableSection => 'Available to add';

  @override
  String customImportDroppedSubRules(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$label SUB-RULE rules were dropped, since custom profiles do not support sub-rules',
      one:
          '1 SUB-RULE rule was dropped, since custom profiles do not support sub-rules',
    );
    return '$_temp0';
  }

  @override
  String get autoInclude => 'Auto-include';

  @override
  String get allReferencedProxies => 'All referenced proxies';

  @override
  String get allReferencedProxyProviders => 'All referenced proxy providers';

  @override
  String get clearDnsCache => 'Clear DNS cache';

  @override
  String get dnsCacheCleared => 'DNS cache cleared';

  @override
  String get clearDnsCacheFailed => 'Failed to clear DNS cache';

  @override
  String get select => 'Select';

  @override
  String get preferred => 'Preferred';

  @override
  String get addToLocalProxies => 'Add to local proxies';

  @override
  String addedToLocalProxies(Object name) {
    return 'Added $name to local proxies';
  }

  @override
  String alreadyInLocalProxies(Object name) {
    return '$name is already in local proxies';
  }

  @override
  String get mitm => 'MITM';

  @override
  String get httpsDecryption => 'HTTPS decryption';

  @override
  String get httpCapture => 'HTTP capture';

  @override
  String get httpCaptureDesc =>
      'Records requests to the hosts listed under Hostname, to view in connection details. Records stay in memory only.';

  @override
  String get httpCaptureNoHosts =>
      'No host is listed, so nothing is recorded. Add hosts under Hostname on the MITM page, or from the details of a connection.';

  @override
  String get httpCaptureLimit => 'Maximum records';

  @override
  String httpCaptureLimitDesc(Object memory, Object body) {
    return 'The oldest records go first once this many are kept or they fill $memory of memory. Each body keeps its first $body.';
  }

  @override
  String get httpRequests => 'HTTP requests';

  @override
  String get httpRequestsMissing =>
      'Requests made before capture was on, or since cleared, are not listed.';

  @override
  String get httpRequestCleared => 'This request is no longer kept';

  @override
  String get httpCaptureOff => 'Capture is off';

  @override
  String get inProgress => 'In progress';

  @override
  String get method => 'Method';

  @override
  String get originalUrl => 'Original URL';

  @override
  String get timeToFirstByte => 'Time to first byte';

  @override
  String get requestBody => 'Request body';

  @override
  String get response => 'Response';

  @override
  String get responseBody => 'Response body';

  @override
  String get responseHeaders => 'Response headers';

  @override
  String get matchedRules => 'Matched rules';

  @override
  String get overview => 'Overview';

  @override
  String get viewAll => 'View all';

  @override
  String get copyAsBase64 => 'Copy as Base64';

  @override
  String get copyAsCurl => 'Copy as cURL';

  @override
  String get closeConnection => 'Close connection';

  @override
  String get copyHost => 'Copy host';

  @override
  String get copyDestination => 'Copy destination';

  @override
  String get copyRequest => 'Copy request';

  @override
  String get copyResponse => 'Copy response';

  @override
  String get copyResponseBody => 'Copy response body';

  @override
  String get httpBodyProtobufGuess =>
      'Read as Protobuf without its schema: field numbers only, and the types are guesses.';

  @override
  String get exportHar => 'Export HAR';

  @override
  String get mitmAddRejectRule => 'Add a reject rule';

  @override
  String get mitmAddMapLocalRule => 'Add a map local rule';

  @override
  String get httpExportPrivateTitle => 'Contains private data';

  @override
  String get httpExportPrivate =>
      'A request can carry cookies, tokens, passwords and form contents. Check what you share, and with whom.';

  @override
  String get mitmRuleCopiedForStash =>
      'This module is a Stash override, so the rule was copied for you to add by hand.';

  @override
  String get binaryData => 'Binary data';

  @override
  String get httpBodyNotKept => 'Not recorded while memory was short.';

  @override
  String get httpBodyTruncated => 'Only the start of this body was recorded.';

  @override
  String httpBodyUndecoded(Object encoding) {
    return 'Could not decode $encoding, so this is the data as it was sent.';
  }

  @override
  String get mitmEnableTip =>
      'Flash will be able to read everything sent to the decrypted hosts, cookies and passwords included. Turn this on only for hosts you mean to rewrite.';

  @override
  String get certificate => 'Certificate';

  @override
  String get generateCertificate => 'Generate certificate';

  @override
  String get regenerateCertificate => 'Regenerate certificate';

  @override
  String get regenerateCertificateTip =>
      'The new certificate replaces the current one, which Flash takes out of this device\'s trusted roots where it can. Every other device that trusts the current one has to install the new one.';

  @override
  String get exportCertificate => 'Export certificate';

  @override
  String get installCertificate => 'Install to system';

  @override
  String get installCertificateSuccess => 'Certificate installed';

  @override
  String validUntil(Object date) {
    return 'Valid until $date';
  }

  @override
  String get mitmCertificateExportTip =>
      'Export it and trust it on the devices you want to decrypt.';

  @override
  String get mitmTrustReady => 'Trusted';

  @override
  String get mitmTrustUntrusted => 'Not fully trusted';

  @override
  String get mitmTrustNotInstalled => 'Not installed';

  @override
  String get mitmTrustChecking => 'Checking…';

  @override
  String get trustCertificate => 'Trust certificate';

  @override
  String get mitmCertificateAndroidReadyTip =>
      'Only apps that trust user certificates, mostly browsers, are decrypted.';

  @override
  String get mitmCertificateLinuxTip =>
      'Flatpak browsers need the exported certificate imported by hand.';

  @override
  String mitmCertutilMissing(Object command) {
    return 'Chrome and Firefox keep their own certificate stores, which need certutil: $command';
  }

  @override
  String mitmMissingStores(Object stores) {
    return 'Not yet in: $stores';
  }

  @override
  String get mitmSystemStoreFailed =>
      'Adding the certificate to the system\'s trusted roots failed';

  @override
  String get mitmRootUntilReboot =>
      'No Magisk, KernelSU or APatch was found to keep the certificate. Install it again after the device restarts.';

  @override
  String get mitmRootPendingReboot =>
      'The certificate takes effect after the device restarts.';

  @override
  String get mitmInstallSystemCaTip =>
      'Root was found, so the certificate goes into the system\'s trusted certificates as a FlClash MITM CA module for Magisk, KernelSU or APatch. Every app on this device will then trust it, and anyone holding its private key could decrypt this device\'s HTTPS traffic. To undo it, regenerate the certificate or remove the module in the root manager and restart. If root is denied, it is installed as a user certificate instead.';

  @override
  String get mitmInstallUserCaTip =>
      'No root was found, so the certificate can only be installed as a user certificate. Only apps that trust user certificates, mostly browsers, are decrypted; other apps fail on the hosts you list, so leave those hosts out. On Android 11 and later you finish the install yourself in system settings.';

  @override
  String mitmCertificateSavedTip(Object fileName) {
    return 'Saved $fileName to Downloads. Install it in Settings under Security › Encryption & credentials › Install a certificate › CA certificate.';
  }

  @override
  String get openSettings => 'Open settings';

  @override
  String mitmRemoveOldCertificateTip(Object name) {
    return 'Remove the old certificate, $name, in Settings under Security › Encryption & credentials › Trusted credentials › User, then install the new one.';
  }

  @override
  String mitmOldCertificateLeftTip(Object name) {
    return 'The old certificate, $name, could not be removed. Remove it from the trusted roots yourself.';
  }

  @override
  String mitmOldSystemCertificateLeftTip(Object name) {
    return 'The old certificate, $name, is still among the system\'s trusted CAs. Allow Flash root access in your root manager and regenerate, or remove the FlClash MITM CA module there and restart.';
  }

  @override
  String get mitmDecryptHost => 'Decrypt this host';

  @override
  String mitmDecryptHostTip(Object host) {
    return 'Add $host to the hostname list? Flash can then read what is sent to it, cookies and passwords included.';
  }

  @override
  String get mitmExcludeHost => 'Exclude from decryption';

  @override
  String mitmExcludeHostTip(Object host) {
    return 'Add -$host to the top of the hostname list? The host is then never decrypted.';
  }

  @override
  String get urlRewrite => 'URL rewrite';

  @override
  String get headerRewrite => 'Header rewrite';

  @override
  String get bodyRewrite => 'Body rewrite';

  @override
  String get mapLocal => 'Map local';

  @override
  String get mitmHostnameDesc =>
      'A leading - excludes a host, and the first match decides.';

  @override
  String get mitmModules => 'Modules';

  @override
  String get mitmModule => 'Module';

  @override
  String get mitmModuleInvalid =>
      'This is not a Surge module, a Loon plugin, a Quantumult X snippet or a Stash override';

  @override
  String get arguments => 'Arguments';

  @override
  String get mitmRoutingRules => 'Routing rules';

  @override
  String get mitmIgnoredLines => 'Ignored lines';

  @override
  String get mitmModuleRulesDesc =>
      'Routing rules go in front of the profile’s own.';

  @override
  String mitmModuleSystemTip(Object system) {
    return 'Written for $system; some lines may not match apps on this device.';
  }

  @override
  String mitmSkipSection(Object section) {
    return 'The [$section] section is not supported';
  }

  @override
  String get mitmSkipSetting => 'This setting is not supported';

  @override
  String get mitmSkipScriptType => 'This script type is not supported';

  @override
  String get mitmSkipRule => 'This rule type is not supported';

  @override
  String get mitmSkipPolicy =>
      'Only the DIRECT and REJECT policies are supported';

  @override
  String get mitmSkipJq => 'jq rewrites are not supported';

  @override
  String get mitmSkipJsonBody => 'JSON body rewrites are not supported';

  @override
  String get mitmSkipRawHeader =>
      'Rewriting all headers as one text is not supported';

  @override
  String get mitmSkipConditional => 'Conditional rewrites are not supported';

  @override
  String get mitmSkipRelativeData =>
      'The file this line names is not attached; use a URL or attach it';

  @override
  String get mitmSkipNotDownloaded => 'Its file has not been downloaded';

  @override
  String get mitmSkipUnreadable => 'This line cannot be read';

  @override
  String get mitmAddLocalFile => 'Add a local file';

  @override
  String get mitmNewModule => 'New module';

  @override
  String get mitmAttachments => 'Attachments';

  @override
  String get mitmAttachmentsDesc =>
      'Lines refer to attachments by file name, as in script-path=a.js.';

  @override
  String mitmFileTooLarge(Object size) {
    return 'The file is larger than $size MB';
  }

  @override
  String get mitmSkipDisabled => 'Turned off by an argument';

  @override
  String get mitmSkipEvent => 'This event is not supported';

  @override
  String get mitmRunScript => 'Run now';

  @override
  String get mitmScriptNoOutput => 'The script finished without output';

  @override
  String get mitmScriptRiskTitle => 'Run this module\'s scripts?';

  @override
  String get mitmScriptRisk =>
      'Its scripts read and change the traffic of the hosts they match, cookies and tokens included, and can send requests of their own. Turn it on only if you trust where it comes from.';

  @override
  String mitmModuleScriptsChanged(Object name) {
    return '$name changed its scripts and was turned off';
  }

  @override
  String get skipServerCertVerify => 'Skip server certificate verification';

  @override
  String get blockQuic => 'Block QUIC';

  @override
  String get http2 => 'HTTP/2';

  @override
  String get decryptUntrusted => 'Decrypt without local trust';

  @override
  String invalidOfCount(Object invalid, Object total) {
    return '$invalid of $total invalid';
  }

  @override
  String get batchLineInputTip => 'One item per line';

  @override
  String get downloadingUpdate => 'Downloading update';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get updateDownloadTest => 'Update download test';

  @override
  String get liveStatusTest => 'Live status cards test';

  @override
  String get updateDownloadStarted =>
      'Downloading the update. Follow its progress on the dashboard.';

  @override
  String get updateReady => 'Update ready';

  @override
  String get updateReadyTip => 'The update has downloaded. Tap to install it.';

  @override
  String get stopUpdateDownloadTip => 'Stop downloading the update?';

  @override
  String get forceRestartCoreAsk => 'Force restart the core?';

  @override
  String get forceRestartCoreAskDesc => 'Connections in progress will drop';

  @override
  String get stopUpdateDownloadDesc => 'What has downloaded is deleted';

  @override
  String get stopDownload => 'Stop';

  @override
  String get updateInstallFailed =>
      'The update could not be installed. You can download it from the release page instead.';

  @override
  String get updateNotVerified =>
      'The downloaded update could not be verified.';

  @override
  String get macUpdateDownloadAndInstall => 'Download and install';

  @override
  String macUpdateSize(Object size) {
    return 'Size: $size';
  }

  @override
  String get macUpdateReadyTitle => 'Update ready';

  @override
  String macUpdateReadyMessage(Object version) {
    return 'Flash $version has been downloaded and verified. Installing quits Flash briefly and may interrupt the connection; Flash opens again when it\'s done.';
  }

  @override
  String get macUpdateRestartNow => 'Quit and install';

  @override
  String get macUpdateLater => 'Later';

  @override
  String get macUpdateInstalling => 'Installing the update…';

  @override
  String get macUpdateNotWritable =>
      'Flash in Applications can\'t be replaced automatically. The verified new version is shown in Finder: drag it into Applications and replace the old one. macOS may ask for an administrator password.';

  @override
  String get macUpdateNotInApplications =>
      'Flash is not in the Applications folder, so it can\'t be replaced automatically. The verified new version is shown in Finder: drag it into the Applications folder.';

  @override
  String get macUpdateNotConfigured =>
      'This version doesn\'t support in-app updates yet. Download the new version from the release page.';

  @override
  String get macUpdateRejected =>
      'The update did not pass the security check and was not installed. Try again, or download it from the release page.';

  @override
  String get macUpdateNotNewer =>
      'The downloaded version is not newer than this one and was not installed.';

  @override
  String get macUpdateLauncherChanged =>
      'This update must be installed by hand. Download the new Flash from the release page.';

  @override
  String get macUpdateHelperOlder =>
      'This update\'s helper is older than the version on record, so it was not installed.';

  @override
  String get macUpdateRolledBack =>
      'The update did not complete. The previous version was restored.';

  @override
  String macUpdateRollbackFailed(Object location) {
    return 'The update did not complete, and the previous version could not be restored automatically. The previous version is saved at “$location”.';
  }

  @override
  String get macUpdateRollbackFailedUnverified =>
      'The update did not complete, and the previous version could not be restored automatically. See the details.';

  @override
  String get macUpdateInstallFailed =>
      'The update did not complete. See the details.';

  @override
  String get macUpdateInstallFailedUnchanged =>
      'The update did not complete. The previous version is unchanged. See the details.';

  @override
  String get macUpdateCoreStopFailed =>
      'Flash couldn\'t confirm the core had stopped, so the update was not installed.';

  @override
  String get macUpdateRecordHint =>
      'The helper\'s version record can\'t be read or updated. Installing the update won\'t fix that record; follow the helper\'s prompts.';

  @override
  String get macUpdateDetails => 'Details';

  @override
  String get updateRestartTip =>
      'Flash closes to install the update and opens again when it is done.';

  @override
  String get updateDownloadFailed => 'The update could not be downloaded.';

  @override
  String get defaultNameserverDesc =>
      'Resolves the hostnames of the other DNS servers. Use IP addresses only.';

  @override
  String get nameserverDesc =>
      'The default DNS servers, such as 223.5.5.5, tls://1.1.1.1 or https://dns.google/dns-query.';

  @override
  String get fallbackDesc =>
      'Used instead of Nameserver when the fallback filter treats its answer as polluted.';

  @override
  String get proxyServerNameserverDesc =>
      'Resolves proxy server hostnames only.';

  @override
  String get proxyServerNameserverPolicyDesc =>
      'Matching proxy server hostnames use the DNS server given here instead of Proxy Server Nameserver.';

  @override
  String get directNameserverDesc =>
      'Resolves domains for connections that go direct.';

  @override
  String get nameserverPolicyDesc =>
      'Matching domains use the DNS server given here instead of Nameserver and Fallback.';

  @override
  String get fakeipFilterDesc =>
      'These domains get real IPs instead of Fake-IPs. In whitelist mode, only they get Fake-IPs.';

  @override
  String get fallbackFilterGeositeDesc =>
      'Domains in these GeoSite categories are resolved by Fallback directly.';

  @override
  String get fallbackFilterIpcidrDesc =>
      'When Nameserver returns an IP in these ranges, the Fallback answer is used.';

  @override
  String get fallbackFilterDomainDesc =>
      'These domains are resolved by Fallback directly.';

  @override
  String get tsCurrentDevice => 'This device';

  @override
  String tsNodeOf(Object name) {
    return 'Node $name';
  }

  @override
  String tsStatusOf(Object label) {
    return 'Status: $label';
  }

  @override
  String get tsChooseNode => 'Choose node';

  @override
  String get tsRefresh => 'Refresh';

  @override
  String get tsHelp => 'More information';

  @override
  String get tsHelpBody =>
      'Flash appears as a separate device on the Tailscale network. It does not let other devices connect to this Mac for SSH, file sharing, or remote desktop, and does not provide Tailscale SSH or Taildrop.';

  @override
  String get tsNetworkNameTip =>
      'The network name does not identify a verified network owner.';

  @override
  String get tsBoundaryTip =>
      'Only traffic that Flash rules send to this node uses Tailscale. Logging in does not change rules, the system proxy or TUN settings.';

  @override
  String get tsGoToRules => 'Go to rules';

  @override
  String get tsGoToProfiles => 'Go to profiles';

  @override
  String get tsCoreStopped => 'Core is not running';

  @override
  String get tsCoreStoppedTip =>
      'Start the core to see this node\'s Tailscale status.';

  @override
  String get tsStartCore => 'Start core';

  @override
  String get tsNodeGone => 'This node is no longer in the current profile';

  @override
  String get tsNodeGoneTip => 'Choose a node again.';

  @override
  String get tsStateSignedOut => 'Not logged in';

  @override
  String get tsStatePreparing => 'Preparing login…';

  @override
  String get tsStateStarting => 'Starting…';

  @override
  String get tsStateWaitingBrowser => 'Waiting for browser login';

  @override
  String get tsStateNeedsApproval => 'Waiting for admin approval';

  @override
  String get tsStateConnected => 'Connected';

  @override
  String get tsStateNeedsReauth => 'Login required again';

  @override
  String get tsStateStopped => 'Stopped';

  @override
  String get tsStateStartFailed => 'Failed to start';

  @override
  String get tsStateUnconfirmed => 'Status unconfirmed';

  @override
  String get tsStateLoadFailed => 'Couldn\'t load status';

  @override
  String get tsSignedOutTip =>
      'Log in in your browser to authenticate this node.';

  @override
  String get tsLoggedOutTip =>
      'You logged out of this node. It reconnects only after you log in.';

  @override
  String get tsPreparingTip => 'Getting login information for this node.';

  @override
  String get tsWaitingBrowserTip =>
      'Finish logging in in your browser. This page updates from the node\'s status afterwards.';

  @override
  String get tsNeedsApprovalTip =>
      'Browser authentication is done. Wait for your Tailscale network admin to approve this device.';

  @override
  String get tsNeedsReauthTip =>
      'This node\'s authentication has expired. Log in again.';

  @override
  String tsExpiryTip(Object time) {
    return 'Authentication expires at $time. Log in again before then.';
  }

  @override
  String get tsStoppedTip =>
      'This node has stopped and can\'t reach the Tailscale network for now.';

  @override
  String get tsStartFailedTip => 'This node failed to start. Try again.';

  @override
  String get tsUnconfirmedTip =>
      'Can\'t confirm whether this node is connected. Read the status again.';

  @override
  String get tsLoadFailedTip =>
      'Can\'t read this node\'s status right now. Try again.';

  @override
  String get tsDeviceName => 'Device name';

  @override
  String get tsAccount => 'Account';

  @override
  String get tsNetwork => 'Network';

  @override
  String get tsControlServer => 'Control server';

  @override
  String get tsAfterLogin => 'Available after login';

  @override
  String get tsAccountMissing => 'Account info not provided';

  @override
  String get tsNetworkMissing => 'Network info not provided';

  @override
  String get tsIdentityFailed => 'Couldn\'t load account and network info';

  @override
  String get tsCopyAddress => 'Copy address';

  @override
  String get tsCopyName => 'Copy name';

  @override
  String get tsAddressCopied => 'Address copied';

  @override
  String get tsLogin => 'Log in to Tailscale';

  @override
  String get tsRelogin => 'Log in again';

  @override
  String get tsReopenLogin => 'Reopen login page';

  @override
  String get tsReadStatus => 'Read status again';

  @override
  String get tsLogout => 'Log out of this node';

  @override
  String get tsLoggingOut => 'Logging out…';

  @override
  String get tsLogoutTitle => 'Log out of this Tailscale node?';

  @override
  String tsLogoutBody(Object name) {
    return 'This logs out of “$name” and clears the login identity this Mac keeps for it. Connections through this node may drop; other nodes are not affected.';
  }

  @override
  String get tsLogoutAuthKeyNote =>
      'When you log in again, the auth key in the profile registers a new device identity.';

  @override
  String get tsLoggedOutReceipt =>
      'Logged out of this node. It won\'t log in again until you log in.';

  @override
  String get tsLogoutFailed =>
      'Couldn\'t log out. Read the node status again, then retry.';

  @override
  String get tsLogoutUnknown =>
      'The logout result is unconfirmed. Read the node status again and don\'t repeat it until confirmed.';

  @override
  String get tsBrowserFailed => 'Couldn\'t open the login page. Try again.';

  @override
  String get tsUrlRejected =>
      'This login page can\'t be opened safely. Check the node\'s control server in the profile.';

  @override
  String get tsUrlMissing =>
      'No usable login page yet. Prepare the login again.';

  @override
  String get tsPrepareAgain => 'Prepare login again';

  @override
  String get tsLoginUnconfirmed =>
      'The login result isn\'t confirmed yet. Read the node status again.';

  @override
  String get tsNodeChanged =>
      'The node has changed. Start the action again on the selected node.';

  @override
  String get tsExitNode => 'Exit node';

  @override
  String get tsNoExitNode => 'No exit node';

  @override
  String get tsNoExitNodeTip =>
      'Using no exit node doesn\'t log out of Tailscale';

  @override
  String get tsExitNodeTip =>
      'Only affects traffic forwarded through this Tailscale node; it doesn\'t make the whole Mac use the exit.';

  @override
  String get tsNoExitCandidates => 'No exit nodes available';

  @override
  String get tsNoExitCandidatesTip => 'No exit node is confirmed available';

  @override
  String get tsExitStale =>
      'Refresh the device list before choosing an exit node.';

  @override
  String get tsChooseExitNode => 'Choose exit node';

  @override
  String get tsOfflineNotSelectable => 'Offline, can\'t be chosen';

  @override
  String get tsExitChangeTitle => 'Change exit node?';

  @override
  String tsExitChangeBody(Object node, Object device) {
    return 'Sets the exit node of “$node” to “$device”. Connections through this node may drop; Flash rules stay the same.';
  }

  @override
  String get tsExitChangeConfirm => 'Change exit node';

  @override
  String get tsExitOffTitle => 'Stop using the exit node?';

  @override
  String tsExitOffBody(Object node) {
    return 'Only turns off exit forwarding for “$node”; it doesn\'t log out of Tailscale and Flash rules stay the same.';
  }

  @override
  String get tsExitApplying => 'Changing exit node…';

  @override
  String get tsExitUpdated => 'Exit node updated';

  @override
  String get tsExitFailed => 'Exit node not changed. Try again.';

  @override
  String get tsExitUnknown =>
      'The exit node change is unconfirmed. Read the current settings again.';

  @override
  String get tsReadSettings => 'Read settings again';

  @override
  String get tsSettingsSaved =>
      'Saved, but not yet confirmed in effect. Read the current settings again.';

  @override
  String get tsSettingsApplyFailed =>
      'Saved, but couldn\'t be applied to this node. Read the current settings again.';

  @override
  String get tsSubnetRoutes => 'Subnet routes';

  @override
  String get tsAcceptRoutes => 'Accept subnet routes';

  @override
  String get tsAcceptRoutesTip =>
      'Lets this node use approved subnet routes in the Tailscale network. Your rules still decide whether traffic goes through them; Flash rules are not changed.';

  @override
  String get tsRoutesOnTitle => 'Accept subnet routes?';

  @override
  String get tsRoutesOnBody =>
      'This node will use the network\'s approved subnet routes. Flash rules stay the same.';

  @override
  String get tsRoutesOffTitle => 'Stop accepting subnet routes?';

  @override
  String get tsRoutesOffBody =>
      'This node will stop using these subnet routes; related connections may drop. Flash rules stay the same.';

  @override
  String get tsRoutesOffConfirm => 'Stop accepting';

  @override
  String get tsRoutesApplying => 'Updating subnet routes…';

  @override
  String get tsRoutesUpdated => 'Subnet routes updated';

  @override
  String get tsRoutesFailed => 'Subnet routes not changed. Try again.';

  @override
  String get tsRoutesUnknown =>
      'The subnet routes change is unconfirmed. Read the current settings again.';

  @override
  String get tsOn => 'On';

  @override
  String get tsOff => 'Off';

  @override
  String get tsFromSubscription => 'From subscription';

  @override
  String get tsFromProfile => 'From current profile';

  @override
  String get tsFromProvider => 'From proxy provider';

  @override
  String get tsFromLocal => 'Set on this Mac';

  @override
  String get tsOverrideAmbiguous =>
      'This profile has multiple nodes with the same name and control server, so their settings cannot be saved separately. Give them different names in the profile.';

  @override
  String get tsOverrideTip =>
      'Settings saved here take priority over the same settings in the profile and never change the subscription file.';

  @override
  String get tsChangeAfterSignIn => 'Sign in and connect to change';

  @override
  String tsSavedValue(Object value) {
    return 'Saved: $value';
  }

  @override
  String get tsAfterConnectSelectable =>
      'Connect this node to change settings.';

  @override
  String get tsDevices => 'Devices';

  @override
  String get tsDevicesScope =>
      'Devices this node can see, not every device in the admin console';

  @override
  String get tsAddress => 'Tailscale address';

  @override
  String get tsOwner => 'Owner';

  @override
  String get tsSystem => 'OS';

  @override
  String get tsStatus => 'Status';

  @override
  String get tsOnline => 'Online';

  @override
  String get tsOffline => 'Offline';

  @override
  String get tsStatusUnknown => 'Status unknown';

  @override
  String get tsExitCapable => 'Exit node';

  @override
  String get tsNameMissing => 'Name not provided';

  @override
  String get tsAddressMissing => 'Address not provided';

  @override
  String get tsSystemMissing => 'OS not provided';

  @override
  String get tsDevicesEmpty => 'No visible devices';

  @override
  String get tsDevicesEmptyTip =>
      'This node doesn\'t see any other devices yet.';

  @override
  String get tsDevicesFailed => 'Couldn\'t load the device list. Try again.';

  @override
  String get tsRefreshDevices => 'Refresh device list';

  @override
  String get tsDevicesStale =>
      'The device list may be out of date. Refreshing failed; this is the last list read.';

  @override
  String tsDevicesShown(Object n) {
    return 'Showing $n devices';
  }

  @override
  String tsDevicesCompact(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices · Only devices visible to this account',
      one: '1 device · Only devices visible to this account',
    );
    return '$_temp0';
  }

  @override
  String tsDevicesCompactFiltered(Object shown, Object total) {
    return 'Showing $shown/$total · Devices visible to this account only';
  }

  @override
  String get tsSearchHint => 'Search name or address';

  @override
  String get tsSearchEmpty => 'No devices match the search';

  @override
  String get tsOwnerFilter => 'Device owner';

  @override
  String get tsOwnerAll => 'All';

  @override
  String get tsOwnerMine => 'Mine';

  @override
  String get tsOwnerMe => 'Me';

  @override
  String get tsOwnerUnknown => 'Owner unknown';

  @override
  String tsOwnerUnknownNetwork(Object network) {
    return 'Unknown · Network $network';
  }

  @override
  String get tsOwnerFilterEmpty => 'No devices with this owner';

  @override
  String get tsFilterEmpty => 'No devices match the current filters';

  @override
  String get tsClearOwnerFilter => 'Clear owner filter';

  @override
  String get tsShared => 'Shared in';

  @override
  String tsSharedBy(Object name) {
    return 'Shared by: $name';
  }

  @override
  String get tsLegacyTitle => 'Found an earlier login record';

  @override
  String get tsLegacyAccountUnconfirmed => 'Account not confirmed';

  @override
  String get tsLegacyBody =>
      'You can copy this login record to this node and keep the original. It can move to only one node; make sure this is the account you want to keep using, or log in again instead.';

  @override
  String get tsLegacyAuthKeyNote =>
      'This node has an auth key; logging in again registers a new device identity with it, and the earlier login record is kept.';

  @override
  String get tsLegacyMigrate => 'Move to this node';

  @override
  String get tsLegacyMigrating => 'Moving login record…';

  @override
  String get tsLegacyRetry => 'Retry move';

  @override
  String get tsLegacyFailed =>
      'The login record was not moved and the original is kept. Try again, or log in again.';

  @override
  String get tsLegacyClaimFailed =>
      'The login record was not moved; the move details couldn\'t be saved. Try again, or log in again.';

  @override
  String get tsLegacyChanged =>
      'The move details have changed. Check them again before confirming.';

  @override
  String get tsLegacyUnknown =>
      'The move result is unconfirmed. Read the status again first, and don\'t move or log in again until confirmed.';

  @override
  String get tsLegacyUnknownTarget =>
      'The move result is unconfirmed; the login record on the target node isn\'t confirmed yet. Read the status again first, and don\'t move or log in again until confirmed.';

  @override
  String get tsLegacyUnknownArchive =>
      'The move result is unconfirmed, and the original login record can\'t be verified for now. Read the status again first, and don\'t move or log in again until confirmed.';

  @override
  String get tsLegacyUnknownUnsaved =>
      'The move result is unconfirmed; the move details couldn\'t be saved. Read the status again first, and don\'t move or log in again until confirmed.';

  @override
  String get tsLegacyMigrated => 'Login record moved. Reading the node status.';

  @override
  String get tsLegacyHasIdentity =>
      'This node already has its own login record; no need to move.';

  @override
  String get tsLegacyControlMismatch =>
      'The earlier login record uses another control server than this node, so it can\'t move.';

  @override
  String get tsLegacyInUse =>
      'The earlier login record is still in use and can\'t move for now.';

  @override
  String get tsLegacyMigratedElsewhere =>
      'This earlier login record already moved to another node and can\'t move again.';

  @override
  String get tsLegacyUnreadable =>
      'Can\'t read the earlier login record. Check again.';

  @override
  String get tsLegacyUnreadableNotMigrated =>
      'The login record was not moved; the earlier login record can\'t be read. Check again.';

  @override
  String get tsLegacyUnconfirmed =>
      'Whether the earlier login record can be used is unconfirmed. Read the status again.';

  @override
  String get tsLegacyConfirmTitle => 'Move the earlier login to this node?';

  @override
  String tsLegacyConfirmProfile(Object name) {
    return 'Profile: $name';
  }

  @override
  String tsLegacyConfirmNode(Object name) {
    return 'Node: $name';
  }

  @override
  String tsLegacyConfirmAccount(Object account) {
    return 'Account: $account';
  }

  @override
  String tsLegacyConfirmControl(Object server) {
    return 'Control server: $server';
  }

  @override
  String get tsLegacyConfirmBody =>
      'This copies the login record for the node above and leaves the original untouched. The same record can\'t move to another node afterwards. Check the node\'s real connection status after the move.';

  @override
  String get tsLegacyConfirm => 'Confirm move';

  @override
  String get tsSignIn => 'Sign in to Tailscale';

  @override
  String get tsSignInTip =>
      'After sign-in, Flash adds a Tailscale node and dedicated rules to this profile. Other traffic keeps its existing routing, and the original profile file stays unchanged.';

  @override
  String get tsSignInBoundary =>
      'System proxy and TUN will not be enabled automatically.';

  @override
  String get tsPreparingProfile => 'Preparing a local profile…';

  @override
  String get tsPreparingSignIn => 'Preparing sign-in…';

  @override
  String get tsPreparingSignInTip => 'Preparing Tailscale for this profile.';

  @override
  String get tsAttaching => 'Adding to current profile…';

  @override
  String get tsAttachingTip =>
      'Sign-in is complete. Adding the node and Tailscale rules.';

  @override
  String get tsAttached => 'Added to current profile';

  @override
  String get tsAttachedTip =>
      'Tailscale traffic uses dedicated rules. Other traffic keeps its existing routing.';

  @override
  String get tsPrepareFailed =>
      'Tailscale sign-in could not be prepared. Try again.';

  @override
  String get tsAttachFailed =>
      'Signed in, but not added to this profile. Your sign-in has been kept. Try adding it again.';

  @override
  String get tsRetryAttach => 'Retry adding to profile';

  @override
  String get tsAttachUnknown =>
      'The profile update is unconfirmed. Read the status again before adding the node or signing in again.';

  @override
  String get tsPrepareUnknown =>
      'Sign-in preparation is unconfirmed. Read the status again before signing in again.';

  @override
  String get tsAttachLockTip =>
      'Adding to this profile. Settings cannot be changed yet.';

  @override
  String get tsAttachUnknownLockTip =>
      'The profile update is unconfirmed. Read the status again first.';

  @override
  String get tsAddedInPanel => 'Added in panel';

  @override
  String get tsRulesManaged =>
      'Flash updates dedicated rules using this account’s network domain and device addresses. Other traffic keeps its existing routing, and the original profile file stays unchanged.';

  @override
  String tsRulesDomain(Object domain) {
    return 'Network domain: $domain';
  }

  @override
  String tsRulesAddresses(Object count) {
    return 'Device addresses: $count';
  }

  @override
  String get tsRulesPending =>
      'Once added, Tailscale addresses and ts.net domains will use dedicated rules. Other traffic will keep its existing routing.';

  @override
  String get tsRulesProfileNode =>
      'Only traffic routed to this node by Flash rules uses Tailscale. Signing in to this node does not change existing rules or enable system proxy or TUN.';

  @override
  String get tsUnverifiedBlocked =>
      'Tailscale addresses and domains without a verified account are blocked. They will not use another account or a direct connection.';

  @override
  String get tsManagedPriority =>
      'Panel-added routing and blocking rules take priority over existing rules for those targets. Rules for other traffic stay unchanged. Assign an account here to change a target’s routing.';

  @override
  String get tsSignOutRemove => 'Sign out and remove';

  @override
  String get tsSignOutRemoveMenu => 'Sign out and remove…';

  @override
  String get tsRemoveTitle => 'Sign out and remove this account?';

  @override
  String tsRemoveBody(Object account, Object node, Object profile) {
    return 'This signs out “$account” (node “$node”), clears its sign-in from this Mac, and removes its panel-added node and rules from “$profile”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.';
  }

  @override
  String tsRemoveBodyNode(Object node, Object profile) {
    return 'This signs out “$node”, clears its sign-in from this Mac, and removes its panel-added node and rules from “$profile”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.';
  }

  @override
  String get tsRemoveExtra =>
      'This does not delete the device from the Tailscale admin console or change the official client.';

  @override
  String get tsRemoveTargetsKept =>
      'Targets assigned to this account will not move to another account automatically. Blocking protection stays in place. Assign another account to access them.';

  @override
  String get tsRemoveLast =>
      'This is the last panel-added account in this profile. Removing it also removes panel-added routing and blocking rules. The original profile will handle this traffic again, which may use a direct connection or its original proxies. Confirm that you accept this change.';

  @override
  String get tsRemoving => 'Signing out and removing…';

  @override
  String get tsRemoved => 'Signed out and removed';

  @override
  String get tsRemoveLogoutUnknown =>
      'Sign-out is unconfirmed. The node has not been removed. Read the status again before removing it or signing in again.';

  @override
  String get tsRemoveIncomplete =>
      'Signed out, but removal is incomplete. Read the status again.';

  @override
  String get tsRemoveUnknown =>
      'Removal is unconfirmed. Read the status again before adding the node or signing in.';

  @override
  String get tsSignOutAccount => 'Sign out of this account';

  @override
  String get tsSignOutAccountTitle => 'Sign out of this account?';

  @override
  String tsSignOutAccountBody(Object account, Object node) {
    return 'This signs out “$account” (node “$node”) and clears its sign-in from this Mac. Its panel entry and target assignments stay saved. Connections through this account may be interrupted and will not switch to another account or a direct connection. Other accounts will not be signed out. You must choose Sign in to use this account again.';
  }

  @override
  String get tsAccountSignedOut => 'Signed out';

  @override
  String get tsSignedOutBanner =>
      'Signed out of this account. In Rule mode, its assigned targets stay blocked until you sign in or explicitly reassign them.';

  @override
  String get tsSignedOutReceipt => 'Signed out of this account';

  @override
  String get tsAccountsInProfile => 'Tailscale accounts in this profile';

  @override
  String get tsAddAccount => 'Add Tailscale account';

  @override
  String get tsNewAccount => 'New account';

  @override
  String tsNetworkOf(Object name) {
    return 'Network: $name';
  }

  @override
  String tsSwitcherSemantics(Object account, Object status, Object count) {
    return 'Viewing Tailscale account: $account, $status. $count entries.';
  }

  @override
  String get tsMemoryTip =>
      'Each account runs a separate Tailscale device. Keeping more accounts online uses more memory.';

  @override
  String get tsDuplicate =>
      'An entry already exists for this account. This sign-in has been kept but has not been added to routing. Review it before continuing.';

  @override
  String get tsViewExisting => 'View existing account';

  @override
  String get tsCheckingAccount => 'Checking account…';

  @override
  String get tsAddUnconfirmed =>
      'Account addition is unconfirmed. Read the status again first.';

  @override
  String tsConflictTitle(Object count) {
    return 'Choose accounts for $count targets';
  }

  @override
  String get tsConflictBody =>
      'These addresses or domains have multiple candidate accounts. Requests to these targets are blocked until you choose an account. They will not be sent directly.';

  @override
  String get tsChooseAccounts => 'Choose accounts';

  @override
  String get tsAddressConflict => 'Address conflict';

  @override
  String get tsRoutingConflict => 'Routing conflict';

  @override
  String get tsChooseAccountFor => 'Choose account for access';

  @override
  String get tsAssignTitle => 'Choose accounts for targets';

  @override
  String get tsAssignBody =>
      'Choose one account for each target. Unassigned targets stay blocked. Other targets are not affected. An offline account will not be replaced automatically.';

  @override
  String tsTargetAddress(Object address) {
    return 'Address: $address';
  }

  @override
  String tsTargetDomain(Object domain) {
    return 'Domain: $domain';
  }

  @override
  String tsCandidate(Object account, Object network) {
    return '$account · $network';
  }

  @override
  String get tsNotAssigned => 'Not assigned';

  @override
  String get tsSaveChoices => 'Save choices';

  @override
  String get tsChoicesUpdated => 'Access accounts updated';

  @override
  String get tsAssignedTargets => 'Assigned targets';

  @override
  String get tsChoicesSaved =>
      'Choices saved; application is not yet confirmed.';

  @override
  String get tsChoicesFailed => 'Choices were not saved. Try again.';

  @override
  String get tsChoicesUnknown =>
      'The result is unconfirmed. Read the status again before saving again.';

  @override
  String tsAssignedTo(Object account) {
    return 'Assigned: $account';
  }

  @override
  String get tsAssignedUnavailable =>
      'The assigned account is unavailable. This target will not use another account.';

  @override
  String get tsReconfirm =>
      'This target’s account needs confirmation. Requests are blocked. Choose an account again.';

  @override
  String get tsReassign => 'Reassign account';

  @override
  String get tsTargetUnconfirmed => 'Target account unconfirmed';

  @override
  String get tsTargetUnconfirmedTip =>
      'The account for this target cannot be verified yet. Requests are blocked.';

  @override
  String tsDeleteProfileManaged(Object count) {
    return 'This profile has $count panel-added Tailscale accounts. Deleting it removes their profile bindings, target assignments, and dedicated routing and blocking rules. Local sign-in archives are kept. Devices in the Tailscale admin console are not deleted. Other profiles are not affected.';
  }

  @override
  String get tsDeleteProfilePending =>
      'This profile has unconfirmed Tailscale operations. Read the status again before deleting it.';

  @override
  String get tsDeleteProfileUnbindFailed =>
      'Could not unlink this profile from its Tailscale accounts. The profile was not deleted. Try again.';

  @override
  String get tsDeleteProfileUnlinkUnconfirmed =>
      'The account-link update is unconfirmed. The profile has not been deleted. Read the status again before deleting it again.';

  @override
  String get tsDeleteProfileUnconfirmed =>
      'Profile deletion is unconfirmed. Read the status again before deleting it again.';

  @override
  String get tsTryAgain => 'Try again';

  @override
  String get tsDirectMode =>
      'Direct mode is active. Tailscale automatic routing and blocking protection are not in effect. Switch to Rule mode before accessing Tailscale targets.';

  @override
  String get tsGlobalMode =>
      'Global mode is active. Tailscale automatic routing and blocking protection are not in effect. Switch to Rule mode before accessing Tailscale targets.';

  @override
  String get tsDnsUnverified =>
      'The current DNS settings do not confirm that target domains are preserved for rule matching. Domain routing has not been verified. Check DNS settings.';

  @override
  String get tsCancel => 'Cancel';

  @override
  String get tsSignInShort => 'Sign in to add a node and dedicated rules.';

  @override
  String tsRulesSummary(num count, Object domain) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$domain · $count device addresses',
      one: '$domain · 1 device address',
    );
    return '$_temp0';
  }

  @override
  String get tsRulesUnconfirmed =>
      'Domain and address details are unconfirmed.';

  @override
  String tsDevicesFiltered(Object shown, Object total) {
    return 'Showing $shown / $total';
  }

  @override
  String get tsAboutTailscale => 'About Tailscale';

  @override
  String get tsAboutExit => 'About exit settings';

  @override
  String get tsAboutRoutes => 'About subnet routes';

  @override
  String get tsAboutRules => 'About rules';

  @override
  String get infoAbout => 'About';

  @override
  String get mountApplyKept =>
      'Mounts could not be applied. The last confirmed running profile is still in use.';

  @override
  String get mountApplyBlocked =>
      'Mounts could not be applied. Flash currently rejects every connection routed through it. Read the status again before unmounting or reapplying the profile.';

  @override
  String get mountApplyBlockedConfirmed =>
      'Mounts are confirmed not to have been applied. Flash still rejects every connection routed through it. You can unmount subscriptions or reapply the profile.';

  @override
  String get mountSourceNoNodeList =>
      'This subscription does not provide a mountable node list. Check its format.';

  @override
  String get mountDeleteSourceTitle => 'Delete subscription and unmount?';

  @override
  String mountDeleteSourceBody(Object subscriptionName, num profileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      profileCount,
      locale: localeName,
      other: '$profileCount profiles',
      one: '1 profile',
    );
    return '“$subscriptionName” is mounted on the following $_temp0. Deleting it removes its nodes from those profiles and may interrupt connections. Other subscriptions, base profile files, and Tailscale sign-ins will not be deleted.';
  }

  @override
  String get mountDeleteSourceConfirm => 'Delete and unmount';

  @override
  String get mountDeleteSourceProgress => 'Deleting and unmounting…';

  @override
  String get mountDeleteSourceDone => 'Subscription deleted and unmounted';

  @override
  String get mountDeleteSourceUnknown =>
      'Subscription deletion and unmounting are unconfirmed. Read the status again before deleting or mounting again.';

  @override
  String get mountDeleteSourceBlocked =>
      'This subscription or an affected profile has unconfirmed operations. Read the status again before deleting.';

  @override
  String get mountReadStatus => 'Read status again';

  @override
  String get mountEntry => 'Mount subscription nodes';

  @override
  String get mountEntryMenu => 'Mount subscription nodes…';

  @override
  String mountedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions mounted',
      one: '1 subscription mounted',
    );
    return '$_temp0';
  }

  @override
  String mountCardFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscription updates failed',
      one: '1 subscription update failed',
    );
    return '$_temp0';
  }

  @override
  String get mountCardUnreadable => 'Could not read mount status';

  @override
  String mountPillSemantics(Object label, Object profileName) {
    return '$label, target profile $profileName';
  }

  @override
  String get mountPillFailedSemantics => 'a subscription update failed';

  @override
  String mountTarget(Object profileName) {
    return 'Target profile: $profileName';
  }

  @override
  String get mountDescription => 'Adds nodes without changing rules or DNS.';

  @override
  String get mountChooseSources => 'Choose subscriptions';

  @override
  String get mountMountedTag => 'Mounted';

  @override
  String get mountNotMounted => 'Not mounted';

  @override
  String get mountEmptyTitle => 'No subscriptions to mount';

  @override
  String get mountEmptyDesc =>
      'Import a subscription from a link, then choose it as a node source for this profile.';

  @override
  String get mountImport => 'Import subscription';

  @override
  String get mountImportHint =>
      'Return here after importing to choose the subscription. Your active profile will not change.';

  @override
  String mountNodeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
    );
    return '$_temp0';
  }

  @override
  String mountLastUpdated(Object time) {
    return 'Last updated: $time';
  }

  @override
  String get mountNotFetched => 'Nodes not fetched yet';

  @override
  String get mountListFailed => 'Could not load subscriptions. Try again.';

  @override
  String get mountReadAgain => 'Read again';

  @override
  String get mountSave => 'Save mounts';

  @override
  String get mountSaving => 'Saving mounts…';

  @override
  String get mountApplying => 'Mounts saved. Applying…';

  @override
  String get mountUpdated => 'Subscription node mounts updated';

  @override
  String get mountSavedUnconfirmed =>
      'Mounts saved; application is not yet confirmed.';

  @override
  String get mountUnchanged => 'Mounts were not changed. Try again.';

  @override
  String get mountApplyFailed =>
      'Mounts were saved but could not be applied to the running profile.';

  @override
  String get mountUnknown =>
      'The mount result is unconfirmed. Read the status again before saving or unmounting.';

  @override
  String get mountUpdateNodes => 'Update nodes';

  @override
  String mountUpdateNodesOf(Object name) {
    return 'Update nodes of $name';
  }

  @override
  String get mountUpdatingNodes => 'Updating nodes…';

  @override
  String get mountNodesUpdated => 'Nodes updated';

  @override
  String get mountUpdateFailedInUse =>
      'Update failed. The last successfully fetched nodes are still in use.';

  @override
  String get mountUpdateFailedKept =>
      'Update failed. The last successfully fetched nodes were kept, but their current use is not confirmed.';

  @override
  String get mountUpdateFailedKeptBlocked =>
      'Update failed. The last successfully fetched nodes were kept.';

  @override
  String get mountFetchFailed =>
      'Could not fetch nodes from this subscription. Try again.';

  @override
  String get mountSourceEmpty =>
      'Subscription updated. It currently has no nodes.';

  @override
  String get mountSourceGone =>
      'The original subscription is unavailable. Choose a node source again.';

  @override
  String get mountSelectionLost =>
      'The previously selected node is no longer in this subscription. Choose another node.';

  @override
  String get mountTailscaleExcluded =>
      'Tailscale nodes were excluded from ordinary mounts.';

  @override
  String get mountSourceRelayOnly =>
      'All nodes in this subscription route through Tailscale and cannot be mounted. Their routing settings were not changed.';

  @override
  String get mountSourceIsolatedOnly =>
      'All nodes in this subscription were excluded by the mount-isolation checks and cannot be mounted. Their settings were not changed.';

  @override
  String get mountSourceTailscaleOnly =>
      'This subscription contains only Tailscale nodes and cannot be mounted.';

  @override
  String get mountSameName =>
      'When node names conflict across sources, the subscription name is added as a suffix. This may affect exact-match or end-of-name filters. Check the group results.';

  @override
  String get mountGroupsTitle => 'Groups for these nodes';

  @override
  String get mountHintFiltered => 'Auto-collected · Group filters apply';

  @override
  String get mountNoGroupTitle =>
      'This profile has no groups that automatically accept new nodes. Mounted nodes have not been added to any group.';

  @override
  String get mountNoGroupDesc =>
      'No groups will be created and routing rules will not be changed automatically.';

  @override
  String get mountGroupsFailed =>
      'Could not read this profile’s groups. Read them again.';

  @override
  String get mountTypeSelect => 'Manual selection';

  @override
  String get mountTypeUrlTest => 'Latency selection';

  @override
  String get mountTypeFallback => 'Failover';

  @override
  String get mountTypeLoadBalance => 'Load balancing';

  @override
  String get mountBlockTag => 'Block when empty';

  @override
  String get mountBlockDesc =>
      'If this group has no selectable nodes, its connections are blocked instead of sent directly.';

  @override
  String mountBaseFallback(Object target) {
    return 'Empty-group handling comes from the original profile: $target.';
  }

  @override
  String get mountBaseDirect =>
      'When no nodes are selectable, this group uses a direct connection as specified by the original profile.';

  @override
  String mountGroupEmpty(Object group) {
    return 'Group “$group” has no selectable nodes. Check the subscriptions and group filters.';
  }

  @override
  String get mountUnmountTitle => 'Unmount this subscription?';

  @override
  String mountUnmountBody(Object subscriptionName, Object profileName) {
    return 'This removes nodes from “$subscriptionName” from “$profileName”. Connections using those nodes may be interrupted. The subscription, original profile file, and other mounts are not deleted. Dedicated Tailscale routing stays unchanged.';
  }

  @override
  String get mountUnmountManyTitle => 'Unmount these subscriptions?';

  @override
  String mountUnmountManyBody(num count, Object profileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return 'This removes nodes provided by the following $_temp0 from “$profileName”. Connections using those nodes may be interrupted. The subscriptions, original profile file, and other mounts are not deleted. Dedicated Tailscale routing stays unchanged.';
  }

  @override
  String get mountUnmount => 'Unmount';

  @override
  String get mountUnmounting => 'Unmounting…';

  @override
  String get mountUnmounted => 'Unmounted';

  @override
  String get mountUnmountUnknown =>
      'Unmounting is unconfirmed. Read the status again first.';

  @override
  String get mountUpdateTitle => 'Update subscription mounts?';

  @override
  String mountAlsoMounts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return 'This save also mounts $_temp0.';
  }

  @override
  String get mountFormatHelp =>
      'You can mount imported remote Clash/mihomo subscriptions and remote subscriptions successfully converted by Flash’s existing importer. Only nodes are included, not subscription rules or DNS settings.';

  @override
  String mountGroupsExcluded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups do not accept subscription nodes.',
      one: '1 group does not accept subscription nodes.',
    );
    return 'To keep Tailscale routing separate, $_temp0';
  }

  @override
  String mountGroupsExcludedNames(Object groups) {
    return 'Groups: $groups.';
  }

  @override
  String get mountNameSeparator => ', ';

  @override
  String get mountGroupReasonRuleUnknown =>
      'Rule contents are currently unavailable';

  @override
  String get mountGroupReasonProviderUnknown =>
      'The base profile’s node list is currently unavailable';

  @override
  String get mountGroupReasonDns =>
      'DNS requests use routing rules to choose an exit';

  @override
  String get mountGroupReasonDialer =>
      'Other nodes use this group to relay traffic';

  @override
  String get mountGroupReasonMember =>
      'Restricted due to group membership; the underlying reason is unconfirmed';

  @override
  String get mountNoGroupIsolatedTitle =>
      'Current groups cannot receive mounts';

  @override
  String get mountNoGroupIsolatedDesc =>
      'None of the existing groups passed the mount-isolation checks. No group will be created, no direct-connection fallback will be added, and the original profile file will not be rewritten automatically.';

  @override
  String mountNodesRead(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes read',
      one: '1 node read',
    );
    return '$_temp0';
  }

  @override
  String mountNodesReadAt(Object time) {
    return 'Nodes read: $time';
  }

  @override
  String get mountUpdateReadNotAppliedKept =>
      'New nodes were read but have not been applied. The last confirmed running profile is still in use.';

  @override
  String get mountUpdateReadNotAppliedBlocked =>
      'New nodes were read but have not been applied. Flash currently rejects every connection routed through it. Read the status again.';

  @override
  String get mountUpdateReadNotAppliedBlockedConfirmed =>
      'New nodes were read but have not been applied. Flash still rejects every connection routed through it.';

  @override
  String get mountUpdateReadEmptyNotApplied =>
      'Subscription read. It currently has no nodes. The new result has not been applied.';

  @override
  String get mountRunningKept =>
      'The last confirmed running profile is still in use.';

  @override
  String get mountRunningBlocked =>
      'Flash currently rejects every connection routed through it. Read the status again.';

  @override
  String get mountRunningBlockedConfirmed =>
      'Flash still rejects every connection routed through it.';

  @override
  String mountProviderUpdateRefused(Object name) {
    return 'New content for “$name” was read but did not pass the mount-isolation checks and was not applied. The previously confirmed content is still in use.';
  }

  @override
  String mountProviderUpdateRefusedUnconfirmed(Object name) {
    return 'New content for “$name” was read but did not pass the mount-isolation checks and was not applied. Its current use is unconfirmed. Read the status again.';
  }

  @override
  String mountUnsupportedExcluded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count subscription nodes that are not supported for mounting were excluded. Their settings were not changed.',
      one:
          '1 subscription node that is not supported for mounting was excluded. Its settings were not changed.',
    );
    return 'To keep Tailscale routing separate, $_temp0';
  }

  @override
  String get mountAbout => 'About mounts';

  @override
  String get mountAboutBody =>
      'Choose imported subscriptions to add nodes to this profile. Nodes are added only to groups already configured to accept new nodes automatically, using each group’s existing inclusion and exclusion filters. Groups with only fixed members and no automatic collection stay unchanged. Existing nodes, rules, and DNS settings stay unchanged.';

  @override
  String get mountIsolationFirst =>
      'Tailscale and other mount-isolation requirements still take priority. Ineligible groups will not receive subscription nodes.';

  @override
  String get mountGroupsSummary =>
      'Added only to groups that automatically accept new nodes, using each group’s filters.';

  @override
  String mountGroupsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String get mountGroupPending => 'Pending application';

  @override
  String mountGroupNodes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mounted nodes',
      one: '1 mounted node',
    );
    return '$_temp0';
  }

  @override
  String get mountGroupNoMatch => 'No mounted nodes match';

  @override
  String mountGroupsNoMatch(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups have no match',
      one: '1 group has no match',
    );
    return '$_temp0';
  }

  @override
  String get mountGroupsAllNoMatch => 'Mounted nodes match no group filters.';

  @override
  String get mountGroupsUnconfirmed => 'Group additions are not confirmed';

  @override
  String mountShowAllGroups(Object count) {
    return 'Show all $count groups';
  }

  @override
  String get mountGroupsHidden =>
      'Hidden proxy groups also follow the filtering and isolation rules. They are not listed here.';

  @override
  String mountGroupsHiddenCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden groups',
      one: '1 hidden group',
    );
    return '$_temp0';
  }

  @override
  String mountGroupsHiddenBlocked(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden groups are empty and reject connections.',
      one: '1 hidden group is empty and rejects connections.',
    );
    return '$_temp0';
  }

  @override
  String mountGroupsHiddenNoMatch(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden groups have no matching mounted node.',
      one: '1 hidden group has no matching mounted node.',
    );
    return '$_temp0';
  }

  @override
  String get mountDetails => 'Details';

  @override
  String get mountShowLess => 'Show less';

  @override
  String mountViewerSource(Object name, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
    );
    return 'Mount: $name · $_temp0';
  }

  @override
  String mountViewerPending(Object name) {
    return 'Mount: $name · node list not yet confirmed';
  }

  @override
  String tsViewerRules(num count, Object node) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return 'Tailscale · Added by Flash · $_temp0 → Node $node';
  }

  @override
  String tsViewerNode(Object node) {
    return 'Tailscale · Added by Flash · Node $node';
  }

  @override
  String get tsViewerUnconfirmed =>
      'Tailscale · Current rules and nodes are unconfirmed';

  @override
  String get tsViewerReadFailed =>
      'Tailscale · Could not read runtime information';

  @override
  String get tsViewerNone =>
      'Tailscale · No rules added by Flash in this profile';

  @override
  String get mountSameNameShort =>
      'Matching node names use the subscription name';

  @override
  String mountNodesExcludedShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes excluded from mounting',
      one: '1 node excluded from mounting',
    );
    return '$_temp0';
  }

  @override
  String mountGroupsExcludedShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups exclude subscription nodes',
      one: '1 group excludes subscription nodes',
    );
    return '$_temp0';
  }

  @override
  String get mountNamesAndExclusions => 'Name conflicts and exclusions';

  @override
  String get mountSomeExcluded =>
      'Some nodes or groups are excluded from mounting';

  @override
  String get processPath => 'Process path';

  @override
  String get copyPath => 'Copy path';

  @override
  String get filterByThisApp => 'Filter by this app';

  @override
  String get filterByThisProcess => 'Filter by this process';

  @override
  String get unknownProcess => 'Unknown process';

  @override
  String get otherDevice => 'Other device';

  @override
  String get processInfoUnavailable => 'Process information is unavailable.';

  @override
  String get processUnavailable => 'Unavailable';

  @override
  String get processFromOtherDevice =>
      'This connection is from another device. Its process information cannot be obtained on this Mac.';

  @override
  String get appInfoUnreadable => 'Could not read app information';

  @override
  String get systemService => 'System service';

  @override
  String systemServiceLabel(Object feature) {
    return 'System service: $feature';
  }

  @override
  String get systemServiceFeatureHint =>
      'An Apple system process, recognized by its path';

  @override
  String get systemServiceSharedHint =>
      'Many apps go through this system service; the app behind this request is not known';

  @override
  String appViaLaunchd(Object label) {
    return 'Tied to this app by its launchd job $label';
  }

  @override
  String get svcAppStore => 'App Store';

  @override
  String get svcSoftwareUpdate => 'Software Update';

  @override
  String get svcPushNotifications => 'Push Notifications';

  @override
  String get svcICloud => 'iCloud';

  @override
  String get svcPhotos => 'Photos';

  @override
  String get svcMessages => 'Messages & FaceTime';

  @override
  String get svcMaps => 'Maps';

  @override
  String get svcWeather => 'Weather';

  @override
  String get svcSiri => 'Siri';

  @override
  String get svcSpotlight => 'Spotlight Suggestions';

  @override
  String get svcAppleAccount => 'Apple Account';

  @override
  String get svcFindMy => 'Find My';

  @override
  String get svcDateTime => 'Date & Time';

  @override
  String get svcMail => 'Mail';

  @override
  String get svcSafari => 'Safari';

  @override
  String get svcNews => 'News';

  @override
  String get svcHome => 'Home';

  @override
  String get svcGameCenter => 'Game Center';

  @override
  String get svcScreenTime => 'Screen Time';

  @override
  String get svcTips => 'Tips';

  @override
  String get svcBooks => 'Books';

  @override
  String get svcReminders => 'Reminders';

  @override
  String get svcContacts => 'Contacts';

  @override
  String get svcAnalytics => 'Analytics & Improvements';

  @override
  String get svcBackgroundDownloads => 'Background downloads';

  @override
  String get svcNameResolution => 'Name resolution';

  @override
  String get svcCertificateChecks => 'Certificate checks';

  @override
  String get svcWebContent => 'Web content';

  @override
  String get svcNetworkProxy => 'Network proxy';

  @override
  String get svcSystemAssets => 'System assets';

  @override
  String get svcLocation => 'Location';

  @override
  String get svcContinuity => 'Continuity';

  @override
  String get svcCaptivePortal => 'Network sign-in';

  @override
  String get svcAppSecurity => 'App security checks';

  @override
  String get processLookupDisabled => 'Process lookup is currently disabled.';

  @override
  String get pageSourceTitle => 'Confirm setting sources';

  @override
  String get pageSourceDesc =>
      'These settings differ between the app and profile. Choose which source to use.';

  @override
  String pageSourceCompare(Object pageValue, Object fileValue) {
    return 'App: $pageValue · Profile: $fileValue';
  }

  @override
  String get keepPageSetting => 'Keep in-app settings';

  @override
  String get followBaseProfile => 'Follow base profile';

  @override
  String get applyAction => 'Apply';

  @override
  String get notSet => 'Not set';

  @override
  String notSetDefault(Object defaultValue) {
    return 'Not set; default $defaultValue';
  }

  @override
  String pageSourceChange(Object field, Object oldValue, Object newValue) {
    return '$field: $oldValue → $newValue';
  }

  @override
  String get sourcePage => 'In-app settings';

  @override
  String get sourceBase => 'Base profile';

  @override
  String get sourceDefault => 'Default';

  @override
  String get notYetApplied => 'Not yet applied';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelWarning => 'Warning';

  @override
  String get logLevelError => 'Error';

  @override
  String get logLevelSilent => 'Silent';

  @override
  String get findProcessAlways => 'Always';

  @override
  String get findProcessOff => 'Off';

  @override
  String get findProcessStrict => 'On demand';

  @override
  String get tunMissingAuthorization =>
      'TUN did not start because system permission is missing.';

  @override
  String inboundNotListening(Object listenerName, Object port) {
    return '$listenerName did not start: port $port is not listening.';
  }

  @override
  String controllerExposedWithoutSecret(Object address) {
    return 'The controller at $address allows non-local access without a secret. This profile was not applied.';
  }

  @override
  String get systemProxyNoPort =>
      'No usable port is available for the system proxy. Check the port settings.';

  @override
  String get pageSourceHiddenTitle => 'Switch to profile values';

  @override
  String get pageSourceHiddenNote =>
      'Defaults are used for settings not present in the profile.';

  @override
  String get valueOn => 'On';

  @override
  String get valueOff => 'Off';

  @override
  String get valueEmptyList => 'Empty list';

  @override
  String get valueEmptyObject => 'Empty object';

  @override
  String get valueEmptyText => 'Empty text';

  @override
  String get valueNull => 'Null';

  @override
  String get fieldStoreSelected => 'Remember node selections';

  @override
  String get fieldTunAutoRoute => 'TUN automatic routing';

  @override
  String get fieldTunAutoDetectInterface => 'TUN interface auto-detection';

  @override
  String get fieldSkipAuthPrefixes =>
      'Source IP ranges exempt from authentication';

  @override
  String get fieldExternalUi => 'External dashboard';

  @override
  String get fieldDnsSettings => 'DNS settings';

  @override
  String get listenerMixed => 'Mixed proxy';

  @override
  String get listenerHttp => 'HTTP proxy';

  @override
  String get listenerSocks => 'SOCKS proxy';

  @override
  String get listenerRedir => 'Redir proxy';

  @override
  String get listenerTproxy => 'TProxy proxy';

  @override
  String get tsExitGroupName => 'Tailscale exit';

  @override
  String get tsExitHowTo =>
      'Enabling an exit node doesn’t change existing selections; only policies using “Tailscale exit” on the Proxies page use it.';

  @override
  String get tsExitGroupUnconfirmed => 'Exit group unconfirmed';

  @override
  String tsExitGroupJoined(num count, Object group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '“$group” added to $count manual policy groups',
      one: '“$group” added to 1 manual policy group',
    );
    return '$_temp0';
  }

  @override
  String get tsExitGroupNoParents =>
      'No manual policy groups in this profile can receive the exit group';

  @override
  String get tsExitNotAuthorized => 'This exit node is not authorized for use';

  @override
  String get tsExitDeviceOffline => 'Exit device offline';

  @override
  String get tsExitNeedsLogin => 'Sign in to this account again';

  @override
  String get tsExitRefusing =>
      'This exit node is unavailable. Connections using it will be rejected';

  @override
  String get tsExitUnavailableShort => 'Unavailable';

  @override
  String get tsExitOffAffectedTitle => 'Turn off the exit node?';

  @override
  String tsExitOffAffectedBody(Object group) {
    return 'Turning off the exit node switches policies using “$group” to the first option in each group.';
  }

  @override
  String get tsExitTurnOff => 'Turn off exit node';

  @override
  String get tsExitOffNoOption => 'No options will remain';

  @override
  String tsViewerExit(Object group, Object member, Object groups) {
    return '$group · Added by Flash · $member · Manual policy groups: $groups';
  }

  @override
  String get tsViewerExitUnconfirmed =>
      'Tailscale exit · Current exit node and groups are unconfirmed';

  @override
  String get macHelperTitle => 'Helper';

  @override
  String get macHelperOn => 'Helper ready';

  @override
  String get macHelperOpenSettings => 'Open System Settings';

  @override
  String get macHelperTryAgain => 'Try again';

  @override
  String get macHelperCheckAgain => 'Check again';

  @override
  String get macHelperRepair => 'Repair';

  @override
  String get macHelperUnavailableDetail =>
      'The helper isn’t ready, so TUN can’t start yet. Your TUN setting is saved.';

  @override
  String get trayMultipleNodes => 'Multiple nodes';

  @override
  String get trayNoAvailableMembers => 'No available members';

  @override
  String get trayCouldNotLoad => 'Couldn’t load';

  @override
  String get trayCouldNotSwitch => 'Couldn’t switch';

  @override
  String get traySwitchUnconfirmed => 'Couldn’t confirm the switch';

  @override
  String get traySelectionUnknown => 'Current selection unknown';

  @override
  String trayCurrentSelection(Object name) {
    return 'Current selection: $name';
  }

  @override
  String get trayLatencyUnknown => 'Latency unknown';

  @override
  String get trayTesting => 'Testing';

  @override
  String trayLatencyMilliseconds(Object value) {
    return 'Latency $value milliseconds';
  }

  @override
  String get trayLatencyLessThanOne => 'Latency less than 1 millisecond';

  @override
  String traySwitchingTo(Object name) {
    return 'Switching to $name';
  }

  @override
  String get traySelected => 'Selected';

  @override
  String get trayTestLatency => 'Test Latency';

  @override
  String get trayReject => 'Reject';

  @override
  String trayLatencyBadge(Object value) {
    return '$value ms';
  }

  @override
  String get compositionReviewTitle => 'Review Settings Before First Apply';

  @override
  String get compositionBaselineUnknown =>
      'The previous running values and their sources could not be confirmed. The configuration below is proposed, not a comparison with the currently running configuration.';

  @override
  String get compositionCandidateNote =>
      'Settings available in the app use their saved in-app values. Other settings use the profile values, or defaults when the profile does not specify them. The configuration below is prepared from saved data without refreshing subscriptions. Secrets and larger sections are hidden or masked. TUN shows the requested setting, not its running state. Authorization, mounted content, and Tailscale-related settings will be checked when applying.';

  @override
  String get compositionReadFailed =>
      'Couldn’t prepare or recheck the proposed configuration. It has not been applied. Check the configuration and settings, then try again.';

  @override
  String get compositionSourceUnconfirmed => 'Source unconfirmed';

  @override
  String get compositionRecordFailed =>
      'The configuration was applied, but the first confirmation record couldn’t be saved. You may be asked to confirm again after restarting the app.';

  @override
  String get macHelperChecking => 'Checking…';

  @override
  String get macHelperUpdating => 'Updating helper…';

  @override
  String get macHelperMoveDetail =>
      'Move Flash to the Applications folder, then open Flash again.';

  @override
  String get macHelperMoveTitle => 'Move Flash to Applications';

  @override
  String get macHelperStatusUnknown => 'Couldn’t confirm helper status';

  @override
  String get macHelperCoreUnconfirmed => 'Core status unconfirmed';

  @override
  String get macHelperMigrationTitle => 'Helper update required';

  @override
  String get macHelperMigrationDetail =>
      'Flash needs to remove the old helper and turn on the new one. You’ll be asked for your administrator password.';

  @override
  String get macHelperMigrationAction => 'Start update';

  @override
  String get macHelperApprovalTitle => 'Allow Flash to run in the background';

  @override
  String get macHelperApprovalStep1 => 'Open Login Items & Extensions.';

  @override
  String get macHelperApprovalStep2 =>
      'Under Allow in the Background, find Flash.';

  @override
  String get macHelperApprovalStep3 =>
      'Turn the switch next to Flash off and on again, then come back to Flash.';

  @override
  String macHelperStepLabel(Object number, Object text) {
    return 'Step $number: $text';
  }

  @override
  String get macHelperStartingTitle => 'Starting helper…';

  @override
  String get macHelperStartingDetail => 'Please wait.';

  @override
  String get macHelperStartSlowTitle => 'The helper is taking longer to start';

  @override
  String get macHelperStartSlowDetail =>
      'Flash can’t confirm yet whether the helper has started. Check again; if it’s still not ready, view the details.';

  @override
  String get macHelperViewDetails => 'View details';

  @override
  String get macHelperSignatureTitle =>
      'The helper didn’t pass the security check';

  @override
  String get macHelperSignatureDetail =>
      'Flash didn’t run the helper. Download and install Flash again.';

  @override
  String get macHelperFailedTitle => 'The helper update didn’t finish';

  @override
  String get macHelperFailedStopOld =>
      'Couldn’t stop the old helper. Try again.';

  @override
  String get macHelperFailedRemoveOld =>
      'Couldn’t remove the old helper. Try again.';

  @override
  String get macHelperFailedRegisterNew =>
      'Couldn’t register the new helper. Try again.';

  @override
  String get macHelperFailedUnknown =>
      'Something went wrong during the update. View the details, then try again.';

  @override
  String get macHelperRequiredTitle => 'Turn on the helper first';

  @override
  String get macHelperRequiredDetail =>
      'This feature needs the helper. Finish the setup, then try again.';

  @override
  String get macHelperViewSetup => 'View setup';

  @override
  String get macHelperReinstallTitle => 'The helper can’t be used';

  @override
  String get macHelperReinstallDetail =>
      'The helper inside Flash is missing or doesn’t match this version. Download and install Flash again.';

  @override
  String get macHelperUnsupportedDetail =>
      'The helper requires macOS 14 or later.';

  @override
  String macHelperVersionLine(Object version) {
    return 'Version $version';
  }

  @override
  String get macHelperBarUpdate => 'Update helper';

  @override
  String get macHelperBarAllow => 'Allow helper';

  @override
  String get macHelperWaitingCore => 'Waiting for helper';

  @override
  String get macHelperBarStarting => 'Starting…';

  @override
  String get macHelperBarNotReady => 'Helper not ready';

  @override
  String get macHelperBarFailedCheck => 'Helper failed check';

  @override
  String macHelperBarHint(Object title) {
    return '$title, press to view steps';
  }

  @override
  String get liveStatus => 'Live status';

  @override
  String get coreStopped => 'Core stopped';

  @override
  String get coreStoppedDesc => 'The app lost its connection to the core';

  @override
  String get restartCore => 'Restart core';

  @override
  String get installUpdate => 'Install update';

  @override
  String liveStatusPosition(Object index, Object count) {
    return '$index of $count';
  }

  @override
  String get coreStarting => 'Starting core';

  @override
  String get coreStartingDesc => 'Connecting to the core';

  @override
  String get coreRunning => 'Core running';

  @override
  String get coreRunningDesc => 'The app is connected to the core';

  @override
  String get forceRestartCore => 'Force restart';

  @override
  String rulesSubtitle(Object profile, Object count) {
    return 'Profile “$profile” · $count rules, in the order they apply';
  }

  @override
  String rulesSubtitleQuery(Object profile) {
    return 'Profile “$profile”';
  }

  @override
  String get rulesSearchHint => 'Search rules, or enter a URL to look it up';

  @override
  String get rulesQuerying => 'Looking up';

  @override
  String rulesQueryingHost(Object host) {
    return 'Looking up $host…';
  }

  @override
  String get ruleSourceAll => 'All';

  @override
  String get ruleSourceSubscription => 'Subscription';

  @override
  String get ruleSourceAdded => 'Added rule';

  @override
  String get ruleSourceScript => 'Extension script';

  @override
  String get ruleSourceMitm => 'MITM module';

  @override
  String get ruleSourceCustom => 'Profile rule';

  @override
  String get ruleSourceManaged => 'Tailscale';

  @override
  String rulesGroupFilter(Object name) {
    return 'Group: $name';
  }

  @override
  String get ruleReject => 'Reject';

  @override
  String ruleSetSummary(Object count, Object time) {
    return '$count · updated $time';
  }

  @override
  String ruleSetCountOnly(Object count) {
    return '$count';
  }

  @override
  String ruleSetExpired(Object days) {
    return 'Expired $days days';
  }

  @override
  String get ruleSetFailed => 'Download failed';

  @override
  String get ruleSetMissing => 'Not downloaded';

  @override
  String get ruleSetAbsent => 'Not in this profile';

  @override
  String get rulesLoadingMore => 'Loading…';

  @override
  String rulesShown(Object shown, Object total) {
    return 'Showing $shown of $total';
  }

  @override
  String ruleSetFilterMatches(Object count, Object name) {
    return '$count matches in rule set $name';
  }

  @override
  String rulesContaining(Object count) {
    return 'Matching rules $count';
  }

  @override
  String get rulesShowAll => 'Show all rules';

  @override
  String get ruleHitTag => 'Matched';

  @override
  String ruleShadowedBy(Object index) {
    return 'Rule #$index matches first';
  }

  @override
  String get rulePassTag => 'PASS, skipped';

  @override
  String get ruleNoAdapterTag => 'Target missing, skipped';

  @override
  String get ruleNoUdpTag => 'No UDP, skipped';

  @override
  String get ruleDependsOnRematch => 'Matched again after a REMATCH';

  @override
  String get hitCardTitle => 'Lookup result';

  @override
  String hitCardPosition(Object index) {
    return 'Matches rule #$index';
  }

  @override
  String get hitGoes => 'Goes';

  @override
  String get hitNoRule => 'No rule matched, goes';

  @override
  String get hitRematch =>
      'A REMATCH decides it when the connection is made; the lookup stops here.';

  @override
  String get hitRuleLabel => 'Rule';

  @override
  String get hitFromLabel => 'Source';

  @override
  String get hitEntryLabel => 'Entry';

  @override
  String ruleUpdatedAt(Object time) {
    return 'updated $time';
  }

  @override
  String get ruleJustAdded => 'just added';

  @override
  String get changeNode => 'Change node';

  @override
  String get addAddedRule => 'Add to added rules';

  @override
  String get copyRule => 'Copy rule';

  @override
  String get viewGroup => 'View group';

  @override
  String uncertainKinds(Object kinds) {
    return 'An earlier rule may match first depending on the $kinds; the actual result may differ.';
  }

  @override
  String get uncertainKindApp => 'app';

  @override
  String get uncertainKindPort => 'port';

  @override
  String get uncertainKindIp => 'IP';

  @override
  String get uncertainKindSeparator => ', ';

  @override
  String get uncertainKindLastSeparator => ' or ';

  @override
  String get uncertainOther =>
      'Earlier rules need more about the connection, so the actual result may differ.';

  @override
  String get goUpdate => 'Update';

  @override
  String get ipSourceHosts => 'hosts';

  @override
  String get ipSourceMapping => 'the fake-IP mapping';

  @override
  String get rulesCoreStopped =>
      'The core is not running, so rules cannot be looked up for now. Start the core and try again.';

  @override
  String lookupFailed(Object reason) {
    return 'Lookup failed: $reason';
  }

  @override
  String rulesLoadFailed(Object reason) {
    return 'Rules could not be read: $reason';
  }

  @override
  String get compareSame =>
      'The rule this connection matched then agrees with this lookup.';

  @override
  String compareDiffer(Object rule) {
    return 'This connection matched “$rule” then, unlike this lookup. The profile or the connection may have changed.';
  }

  @override
  String get rulesModeGlobal =>
      'Global mode is on; rules do not route traffic.';

  @override
  String get rulesModeDirect =>
      'Direct mode is on; rules do not route traffic.';

  @override
  String get addRuleTitle => 'Add to added rules';

  @override
  String addRuleSubtitle(Object profile) {
    return 'Adds to profile “$profile”.';
  }

  @override
  String get addRuleScope => 'Matches';

  @override
  String addRuleSuffix(Object domain) {
    return '$domain and all its subdomains';
  }

  @override
  String addRuleExact(Object host) {
    return 'Only $host';
  }

  @override
  String get addRuleTarget => 'Goes through';

  @override
  String get addRulePreview => 'Will add';

  @override
  String addedEffective(Object host, Object group) {
    return 'The rule was added and takes effect. $host now goes through “$group”.';
  }

  @override
  String get viewThatRule => 'View that rule';

  @override
  String get lookupRule => 'Look up rule';

  @override
  String ruleRowSemantics(
    Object index,
    Object rule,
    Object source,
    Object group,
  ) {
    return 'Rule $index, $rule, from $source, to $group';
  }

  @override
  String hitSemantics(
    Object index,
    Object rule,
    Object source,
    Object group,
    Object node,
  ) {
    return 'Matches rule $index, $rule, from $source, through $group, node $node';
  }

  @override
  String get uncertainPrefix => 'The result may differ';

  @override
  String addRuleWriteFailed(Object reason) {
    return 'Could not add: $reason';
  }

  @override
  String get rulesEmptyFiltered =>
      'No matching rules. Try other words or filters.';

  @override
  String get hitIpLabel => 'Resolved IP';

  @override
  String get lookupNoConnectNote =>
      'A lookup may resolve DNS, but never connects to the site.';

  @override
  String get ruleUncertainTag => 'May or may not match';

  @override
  String ruleSetIssuesNotice(Object issues) {
    return 'Rule sets not ready: $issues. The result may be incomplete.';
  }

  @override
  String get ruleSetIssueSeparator => ', ';

  @override
  String ruleSetIssueMissing(Object name) {
    return '“$name” is not downloaded yet';
  }

  @override
  String ruleSetIssueFailed(Object name) {
    return '“$name” failed to download';
  }

  @override
  String ruleSetIssueExpired(Object name) {
    return '“$name” has expired';
  }

  @override
  String get addRuleAdding => 'Adding…';

  @override
  String get addedNotHit =>
      'The rule was added, but this lookup does not match it.';

  @override
  String addedNotHitBy(Object index) {
    return 'Rule #$index matches first.';
  }

  @override
  String get addedUnconfirmed =>
      'The rule was added, but whether it takes effect cannot be confirmed yet.';

  @override
  String get relookup => 'Look up again';

  @override
  String get addedRulesReloadTimeout =>
      'The core did not finish reloading in 15 seconds; the change was undone.';

  @override
  String get addedRulesReloadFailed =>
      'The core did not take the new config; the change was undone.';

  @override
  String get addedRuleSetLoadFailed =>
      'The rule set could not be downloaded; the change was undone.';

  @override
  String get addedRuleSetLoadTimeout =>
      'The rule set did not finish downloading in 15 seconds; the change was undone.';

  @override
  String get ruleDeleteTitle => 'Delete this rule?';

  @override
  String ruleSetDeleteTitle(String name) {
    return 'Delete rule set “$name”?';
  }

  @override
  String ruleDeleteBody(String text) {
    return '$text\nThis takes effect right away.';
  }

  @override
  String ruleDuplicate(int number, String group) {
    return 'This rule is already there (No. $number), through $group.';
  }

  @override
  String get ruleUpdateGroup => 'Update Group';

  @override
  String get ruleEditAddTitle => 'Add Rule';

  @override
  String get ruleEditTitle => 'Edit Added Rule';

  @override
  String get ruleSetAddTitle => 'Add Rule Set';

  @override
  String get ruleSetEditTitle => 'Edit Added Rule Set';

  @override
  String get ruleEditCoreStopped => 'Takes effect once the core starts';

  @override
  String ruleEditPosition(int number) {
    return 'No. $number · Added rule';
  }

  @override
  String ruleSetEditPosition(int number) {
    return 'No. $number · Added rule set';
  }

  @override
  String get ruleEditSaving => 'Saving…';

  @override
  String get ruleTypeLabel => 'Type';

  @override
  String get ruleTypeMore => 'More';

  @override
  String get ruleTypeDomainSuffix => 'Domain Suffix';

  @override
  String get ruleTypeDomain => 'Full Domain';

  @override
  String get ruleTypeKeyword => 'Domain Keyword';

  @override
  String get ruleTypeIpCidr => 'IP Range';

  @override
  String get ruleTypeIpCidr6 => 'IPv6 Range';

  @override
  String get ruleTypeDstPort => 'Destination Port';

  @override
  String get ruleTypeProcessName => 'Process Name';

  @override
  String get ruleTypeSrcIpCidr => 'Source IP Range';

  @override
  String get ruleValueKeyword => 'Keyword';

  @override
  String get ruleHelpDomainSuffix =>
      'Matches example.com and all its subdomains. You can paste a link.';

  @override
  String get ruleHelpDomain =>
      'Matches only this domain, not its subdomains. You can paste a link.';

  @override
  String get ruleHelpKeyword => 'Matches any domain that contains this text.';

  @override
  String get ruleHelpIpCidr =>
      'Such as 10.0.0.0/8; a single address becomes /32.';

  @override
  String get ruleHelpIpCidr6 =>
      'Such as 2001:db8::/32; a single address becomes /128.';

  @override
  String get ruleHelpSrcIpCidr =>
      'The range of the devices the connections come from.';

  @override
  String get ruleHelpPort => 'Such as 443, or a range such as 8000-9000.';

  @override
  String get ruleHelpProcess =>
      'The process name of an app or program, such as Safari or curl.';

  @override
  String get ruleValueEmpty => 'Enter a value';

  @override
  String get ruleValueComma => 'Cannot contain a comma';

  @override
  String get ruleValueDomain => 'Not a valid domain';

  @override
  String get ruleValueCidr => 'Not a valid IP range';

  @override
  String get ruleValueNetwork => 'Must be tcp or udp';

  @override
  String get ruleValueNumberRange => 'Not a valid number or range';

  @override
  String get ruleValueDscp => 'DSCP takes 0 to 63';

  @override
  String get ruleValuePickCode => 'Choose a code';

  @override
  String get ruleValuePickProcess => 'Choose from running apps';

  @override
  String get ruleValueNoProcesses => 'No apps recorded lately';

  @override
  String get rulePositionLabel => 'Position';

  @override
  String get rulePositionFirst => 'First of added rules';

  @override
  String get rulePositionLast => 'Last of added rules';

  @override
  String get ruleSetUrlLabel => 'URL';

  @override
  String get ruleSetUrlHelp =>
      'Paste the link of a rule set; Flash downloads it and checks what it holds.';

  @override
  String get ruleSetUrlInvalid => 'Only http or https links';

  @override
  String get ruleSetChecking => 'Downloading and checking…';

  @override
  String ruleSetCheckOk(String kind, String format, String count) {
    return 'Downloaded: $kind rules, $format format, $count entries';
  }

  @override
  String ruleSetCheckOkUncounted(String format) {
    return 'Downloaded: $format format; its entries are counted once the core runs';
  }

  @override
  String get ruleSetCheckNotFound => 'Not found (404)';

  @override
  String get ruleSetCheckTimeout => 'The download timed out';

  @override
  String ruleSetCheckNetwork(String reason) {
    return 'Download failed: $reason';
  }

  @override
  String get ruleSetCheckNotRuleSet => 'The content is not a rule set';

  @override
  String get ruleSetCheckUnknown => 'The format cannot be recognized';

  @override
  String get ruleSetNameLabel => 'Name';

  @override
  String get ruleSetNameTaken => 'A rule set of this name already exists';

  @override
  String get ruleSetNameInvalid =>
      'A name cannot have a comma or spaces at its ends';

  @override
  String get ruleSetBehaviorLabel => 'Content';

  @override
  String get ruleSetBehaviorDomain => 'Domains';

  @override
  String get ruleSetBehaviorIpcidr => 'IP Ranges';

  @override
  String get ruleSetBehaviorClassical => 'Mixed Rules';

  @override
  String get ruleSetBehaviorDetected => 'Chosen from the downloaded content.';

  @override
  String get ruleSetBehaviorMismatch =>
      'This differs from the downloaded content; the set may not match.';

  @override
  String get ruleSetMrsNeedsKind => 'MRS holds only domains or IP ranges';

  @override
  String get ruleSetFormatText => 'Text';

  @override
  String get ruleSetIntervalLabel => 'Auto Update';

  @override
  String get ruleSetEvery6Hours => 'Every 6 hours';

  @override
  String get ruleSetDaily => 'Every day';

  @override
  String get ruleSetWeekly => 'Every week';

  @override
  String get ruleSetNeverUpdate => 'Never';

  @override
  String ruleSetEverySeconds(int seconds) {
    return 'Every $seconds s';
  }

  @override
  String get ruleSetUpdateNow => 'Update Now';

  @override
  String get ruleSetRefreshed => 'Update started.';

  @override
  String get rulesAddTooltip => 'Add';

  @override
  String get rulesAddSemantics => 'Add a rule or rule set';

  @override
  String get rulesAddRuleMenu => 'Add Rule';

  @override
  String get rulesAddSetMenu => 'Add Rule Set';

  @override
  String get rulesAddedDivider =>
      'Rules below come from the profile and scripts and can only be viewed here';

  @override
  String get ruleSourceAddedSet => 'Added rule set';

  @override
  String get ruleEditMenu => 'Edit…';

  @override
  String get ruleMoveUp => 'Move Up';

  @override
  String get ruleMoveDown => 'Move Down';

  @override
  String ruleEditSemantics(int number) {
    return 'Edit rule $number';
  }

  @override
  String ruleDeleteSemantics(int number) {
    return 'Delete rule $number';
  }

  @override
  String ruleAddedBanner(String text) {
    return 'Rule “$text” was added and is in effect.';
  }

  @override
  String ruleSavedBanner(String text) {
    return 'Rule “$text” was saved and is in effect.';
  }

  @override
  String ruleSetAddedBanner(String name) {
    return 'Rule set “$name” was added and is in effect.';
  }

  @override
  String ruleSetSavedBanner(String name) {
    return 'Rule set “$name” was saved and is in effect.';
  }

  @override
  String get ruleDeletedBanner => 'Deleted.';

  @override
  String get ruleSavedPendingBanner =>
      'Saved; takes effect once the core starts.';

  @override
  String get ruleBannerLookup => 'Look Up a URL';

  @override
  String ruleMoveFailed(String reason) {
    return 'Could not move the rule: $reason';
  }

  @override
  String processHelperLabel(Object name) {
    return '$name · Helper';
  }

  @override
  String processCoreLabel(Object name) {
    return '$name · Core';
  }

  @override
  String get processHelperTag => 'Helper';

  @override
  String get processCoreTag => 'Core';

  @override
  String get addedRulesRollbackReloadFailed =>
      'The changes were rolled back, but restoring the running configuration failed. Reapply the profile before relying on it.';

  @override
  String get addedRulesRollbackConflict =>
      'Some changes were kept because another editor changed the rule set during reload. Review the rule and provider before relying on the profile.';

  @override
  String get addedRulesRollbackReloadTimeout =>
      'Restoring the running configuration is taking too long. Its state is uncertain; further added-rule changes are paused until it finishes.';

  @override
  String get addedRulesStaleEdit =>
      'This rule or rule set changed elsewhere. Reopen it before trying again.';

  @override
  String get addedRulesApplyPending =>
      'Applying the rules is taking a while and is still in progress. Please wait.';

  @override
  String get addedRulesApplyRestored =>
      'Processing has finished, and the original rules were restored.';

  @override
  String get addedRulesApplyRestoreFailed =>
      'Processing has finished, but the original rules could not be restored. Check the current rules.';

  @override
  String get deleteCertificate => 'Delete certificate';

  @override
  String get deleteCertificateTip =>
      'Deletes the certificate\'s private key, the certificate and the trust given to it from this Mac. Decryption stops until a new certificate is generated and trusted.';

  @override
  String get mitmPausedCoreIdentity =>
      'Decryption paused: the Core\'s identity check failed';

  @override
  String mitmIgnoredProfileHostnames(Object count) {
    return 'Ignored $count from subscriptions or scripts';
  }

  @override
  String get mitmOutcomeRefused =>
      'The client sent an alert during the handshake. The cause is unknown.';

  @override
  String get mitmOutcomeUpstreamCertificate =>
      'Website certificate verification failed';

  @override
  String get mitmOutcomeHTTP1Unsupported => 'HTTP/1.1 is not supported';

  @override
  String get mitmOutcomeHelloPassthrough =>
      'TLS hello cannot be inspected; passed through';

  @override
  String get mitmOutcomeFailed => 'Decryption connection failed';

  @override
  String get mitmPausedLiveness =>
      'Decryption paused: trust or signing liveness could not be verified. Normally changes are detected within about 26 seconds; sleep or system stalls may take longer.';

  @override
  String get mitmNotApplied =>
      'Decryption not active: settings not applied to the core yet';

  @override
  String get mitmTurnOffFailed =>
      'Could not turn decryption off in the core. Restart the core.';

  @override
  String get mitmPausedIndicatorPending =>
      'Decryption paused: the required always-visible indicator is not available.';

  @override
  String get mitmPausedUnavailable =>
      'Decryption paused: the signer or connection is unavailable.';

  @override
  String get mitmIndicatorDecrypting => 'Decrypting';

  @override
  String get mitmIndicatorOn => 'Decryption on';

  @override
  String get mitmIndicatorPaused => 'Decryption paused';

  @override
  String get mitmIndicatorUnconfirmed => 'Checking decryption status';

  @override
  String mitmIndicatorPausedBecause(String reason) {
    return 'Decryption paused: $reason';
  }

  @override
  String get mitmIndicatorOpenSettings => 'Open MITM settings';

  @override
  String get mitmPauseCoreStopped => 'core is not running';

  @override
  String get mitmPauseCoreIdentity => 'core identity check failed';

  @override
  String get mitmPauseNotTrusted =>
      'root certificate is missing or not trusted';

  @override
  String get mitmPartialConnections => 'Some connections may not be decrypted';

  @override
  String get mitmPauseLiveness =>
      'trust and signing status could not be verified';

  @override
  String get mitmPauseIndicatorPending =>
      'persistent status indicator is not enabled';

  @override
  String get mitmPauseUnavailable =>
      'signing service or connection unavailable';

  @override
  String get mitmOutcomePaused =>
      'Decryption paused; connection passed through unchanged';

  @override
  String get mitmBadgeDecrypted => 'Decrypted';

  @override
  String get mitmBadgePassedThrough => 'Not decrypted · passed through';

  @override
  String get mitmBadgePassedThroughSpoken => 'Not decrypted, passed through';

  @override
  String get mitmBadgeHandshakeFailed => 'Client handshake failed';

  @override
  String get mitmBadgeFailed => 'Decryption failed';

  @override
  String get mitmExchangeNoResponse => 'No response received';

  @override
  String get mitmExchangeResponseFailed => 'Response interrupted';

  @override
  String get mitmExchangeStopped =>
      'Request stopped because decryption settings changed';

  @override
  String get mitmExchangeFailed => 'Request did not complete';

  @override
  String get macHelperAllowInSettings =>
      'In System Settings → Login Items & Extensions, turn the switch next to Flash off and on again, then come back to Flash.';

  @override
  String get macHelperNotReadyTitle => 'Helper not ready yet';

  @override
  String get macHelperRegistrationFailedDetail =>
      'Registration could not be completed for now. See details.';

  @override
  String get macHelperStaleCoreDetail =>
      'The old core is not yet confirmed stopped. See details.';

  @override
  String get macHelperStatusUnreadable =>
      'The helper status cannot be read right now. See details.';

  @override
  String get macHelperLauncherCheckTitle =>
      'Flash didn’t pass the security check';

  @override
  String get macHelperLauncherCheckDetail =>
      'The helper didn’t start. Install the latest trusted version of Flash again.';

  @override
  String get macHelperLauncherDowngradeTitle =>
      'This version of Flash is too old';

  @override
  String get macHelperLauncherDowngradeDetail =>
      'The helper didn’t start. Install the latest version of Flash.';

  @override
  String get macHelperLauncherFailedTitle => 'The helper couldn’t start';

  @override
  String get macHelperLauncherFailedDetail =>
      'The system couldn’t prepare or start the helper. See details.';

  @override
  String get macHelperRecordDamagedTitle =>
      'Can’t read or update the version record';

  @override
  String get macHelperRecordDamagedDetail =>
      'Flash needs to repair the helper’s version record. You’ll be asked for an administrator password, and the helper will be checked again.';

  @override
  String get macHelperRecordRepairAction => 'Repair record';

  @override
  String get macHelperRecordRepairing => 'Repairing the version record…';

  @override
  String get macHelperRecordRepairFailed =>
      'The version record couldn’t be repaired. See details.';

  @override
  String get ipxScore => 'Health score';

  @override
  String get ipxScoreOutOf => '/ 100';

  @override
  String ipxScoreCeiling(String value) {
    return 'Type cap $value';
  }

  @override
  String get ipxGradeExcellent => 'Excellent';

  @override
  String get ipxGradeGood => 'Good';

  @override
  String get ipxGradeFair => 'Fair';

  @override
  String get ipxGradePoor => 'Poor';

  @override
  String get ipxGradeRisky => 'High risk';

  @override
  String get ipxLocation => 'Location';

  @override
  String get ipxNativity => 'IP origin';

  @override
  String get ipxNative => 'Native IP';

  @override
  String get ipxBroadcast => 'Broadcast IP';

  @override
  String ipxNativeDetail(String registered, String used) {
    return 'Registered $registered · used in $used';
  }

  @override
  String get ipxIsp => 'ISP';

  @override
  String get ipxTypeEducation => 'Education';

  @override
  String get ipxTypePseudo => 'Likely pseudo-residential';

  @override
  String get ipxDeductions => 'Score breakdown';

  @override
  String get ipxFullReport => 'Full report on ipx.al';

  @override
  String ipxDataFrom(String source) {
    return 'Data from $source, for reference only';
  }

  @override
  String get ipxSourceSeparator => ', ';

  @override
  String get ipxReportFailed => 'Couldn’t get report';

  @override
  String get ipxRetry => 'Retry';

  @override
  String get ipxViaExit => 'Queried through the current exit';

  @override
  String get ipxUnknown => 'Unknown';

  @override
  String get mitmHttp2 => 'Decrypt HTTP/2';

  @override
  String get mitmHttp2Desc =>
      'When off, only HTTP/1.1 is decrypted; connections that use only HTTP/2 (such as gRPC) pass through undecrypted.';
}
