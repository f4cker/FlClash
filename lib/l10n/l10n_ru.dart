// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get rule => 'Правило';

  @override
  String get rules => 'Правила';

  @override
  String get global => 'Глобальный';

  @override
  String get direct => 'Прямой';

  @override
  String get dashboard => 'Панель';

  @override
  String get proxies => 'Прокси';

  @override
  String get profile => 'Профиль';

  @override
  String get profiles => 'Профили';

  @override
  String get tools => 'Инструменты';

  @override
  String get logs => 'Логи';

  @override
  String get resources => 'Ресурсы';

  @override
  String get trafficUsage => 'Статистика трафика';

  @override
  String get networkSpeed => 'Скорость сети';

  @override
  String get outboundMode => 'Режим исходящего трафика';

  @override
  String get serviceStatus => 'Состояние сервисов';

  @override
  String get serviceRestricted => 'Доступ ограничен';

  @override
  String get serviceAvailable => 'Доступен';

  @override
  String get serviceUnavailable => 'Недоступен';

  @override
  String get serviceFailed => 'Ошибка проверки';

  @override
  String get serviceDisallowedIsp => 'Недопустимый провайдер';

  @override
  String get serviceBlocked => 'Заблокировано';

  @override
  String get serviceUnsupportedRegion => 'Регион не поддерживается';

  @override
  String get serviceOriginalsOnly => 'Только оригиналы';

  @override
  String get serviceComingSoon => 'Скоро появится';

  @override
  String get servicePending => 'Не проверено';

  @override
  String get serviceManage => 'Управление сервисами';

  @override
  String get serviceCheckAll => 'Проверить все';

  @override
  String get upload => 'Отдача';

  @override
  String get download => 'Загрузка';

  @override
  String get usedTraffic => 'Использованный трафик';

  @override
  String get totalTraffic => 'Общий трафик';

  @override
  String get expireTime => 'Срок действия';

  @override
  String get nullProfileDesc => 'Добавьте профиль, чтобы начать';

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык';

  @override
  String get defaultText => 'По умолчанию';

  @override
  String get more => 'Ещё';

  @override
  String get other => 'Другое';

  @override
  String get about => 'О программе';

  @override
  String get en => 'Английский';

  @override
  String get es => 'Испанский';

  @override
  String get fr => 'Французский';

  @override
  String get ja => 'Японский';

  @override
  String get ko => 'Корейский';

  @override
  String get ru => 'Русский';

  @override
  String get zhCN => 'Упрощённый китайский';

  @override
  String get theme => 'Тема';

  @override
  String get extend => 'Расширение';

  @override
  String get runtimeConfig => 'Конфигурация выполнения';

  @override
  String get allowLan => 'Разрешить LAN';

  @override
  String get tun => 'TUN';

  @override
  String get tunDesc => 'TUN работает только в режиме администратора.';

  @override
  String get minimizeOnExit => 'Сворачивать при выходе';

  @override
  String get autoLaunch => 'Автозапуск';

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
  String get silentLaunch => 'Тихий запуск';

  @override
  String get autoRun => 'Автовключение';

  @override
  String get autoRunDesc =>
      'Автовключение запускает прокси при открытии приложения.';

  @override
  String get logcat => 'Захват логов';

  @override
  String get logcatDesc =>
      'При отключении захвата логов раздел логов скрывается.';

  @override
  String get autoCheckUpdate => 'Автопроверка обновлений';

  @override
  String get checkCertificate => 'Проверять TLS-сертификаты';

  @override
  String get checkCertificateDesc =>
      'Без проверки TLS-сертификатов подписки и резервные копии уязвимы для атаки «человек посередине».';

  @override
  String get accessControl => 'Контроль доступа';

  @override
  String get edit => 'Редактировать';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get update => 'Обновить';

  @override
  String get add => 'Добавить';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get seconds => 'секунд';

  @override
  String get qrcode => 'QR-код';

  @override
  String get qrcodeDesc => 'Сканируйте QR-код, чтобы получить профиль';

  @override
  String get url => 'URL';

  @override
  String get link => 'Ссылка';

  @override
  String get file => 'Файл';

  @override
  String get name => 'Название';

  @override
  String get profileNameNullValidationDesc => 'Введите название профиля';

  @override
  String get rename => 'Переименовать';

  @override
  String get profileUrlNullValidationDesc => 'Введите URL профиля';

  @override
  String get profileUrlInvalidValidationDesc =>
      'Введите корректный URL профиля';

  @override
  String get autoUpdate => 'Автообновление';

  @override
  String get autoUpdateInterval => 'Интервал автообновления';

  @override
  String get profileAutoUpdateIntervalNullValidationDesc =>
      'Введите интервал автообновления';

  @override
  String get profileAutoUpdateIntervalInvalidValidationDesc =>
      'Введите корректный интервал';

  @override
  String get themeMode => 'Режим темы';

  @override
  String get themeColor => 'Цвет темы';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get auto => 'Авто';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Тёмная';

  @override
  String get importFromLink => 'Импорт по ссылке';

  @override
  String get sendFromPhone => 'Отправить с телефона';

  @override
  String get sendFromPhoneTip =>
      'Отсканируйте код камерой телефона и вставьте ссылку на открывшейся странице. Оба устройства должны быть в одной сети.';

  @override
  String get sendFromPhoneNoNetwork =>
      'Это устройство не подключено к локальной сети';

  @override
  String get sendFromPhonePermissionDenied =>
      'Чтобы получить ссылку с телефона, Flash нужно разрешение «Устройства поблизости» для доступа к локальной сети. Включите его в настройках приложения.';

  @override
  String get sendFromPhonePageTitle => 'Отправить ссылку в Flash';

  @override
  String get sendFromPhonePageHint => 'Ссылка на подписку или ссылка на прокси';

  @override
  String get send => 'Отправить';

  @override
  String get sendFromPhonePageSent =>
      'Отправлено. Подтвердите импорт на другом устройстве.';

  @override
  String get sendFromPhoneConfirmTitle => 'Импортировать ссылку с телефона?';

  @override
  String get shareQrcodeTip =>
      'Отсканируйте в Flash на другом устройстве, чтобы импортировать этот профиль.';

  @override
  String get qrcodeTooLongTip =>
      'Ссылка слишком длинная для QR-кода. Используйте «Копировать ссылку».';

  @override
  String get submit => 'Отправить';

  @override
  String createProfileFromUrlTip(Object url) {
    return 'Создать профиль по ссылке $url?';
  }

  @override
  String get create => 'Создать';

  @override
  String get pleaseUploadValidQrcode => 'Загрузите корректный QR-код';

  @override
  String get blacklistMode => 'Режим чёрного списка';

  @override
  String get whitelistMode => 'Режим белого списка';

  @override
  String get selectAll => 'Выбрать всё';

  @override
  String get cancelSelectAll => 'Снять выделение';

  @override
  String get appAccessControl => 'Контроль доступа приложений';

  @override
  String get accessControlAllowDesc =>
      'Через VPN проходят только выбранные приложения';

  @override
  String get accessControlNotAllowDesc =>
      'Выбранные приложения исключаются из VPN';

  @override
  String get accessControlDisabledDesc =>
      'Контроль доступа приложений отключён';

  @override
  String accessControlSelectedCount(num count) {
    return 'Выбрано: $count';
  }

  @override
  String get port => 'Порт';

  @override
  String get logLevel => 'Уровень логов';

  @override
  String get show => 'Показать';

  @override
  String get exit => 'Выход';

  @override
  String get systemProxy => 'Системный прокси';

  @override
  String get safeMode => 'Безопасный режим';

  @override
  String safeModeAppTitle(Object appName) {
    return '$appName (Безопасный режим)';
  }

  @override
  String get project => 'Исходный проект FlClash';

  @override
  String get upstreamTelegram => 'Telegram исходного проекта FlClash';

  @override
  String get core => 'Ядро';

  @override
  String get tabAnimation => 'Анимация вкладок';

  @override
  String get desc =>
      'Многоплатформенный прокси-клиент на основе ClashMeta: простой и удобный, с открытым исходным кодом и без рекламы.';

  @override
  String get startVpn => 'Запуск VPN…';

  @override
  String get stopVpn => 'Остановка VPN…';

  @override
  String get localNetworkDeniedTip =>
      'Доступ к локальной сети запрещён: используется стек gvisor, локальная сеть недоступна.';

  @override
  String get compatible => 'Режим совместимости';

  @override
  String get notSelectedTip => 'Текущую группу прокси нельзя выбрать';

  @override
  String get changeProxyFailedTip =>
      'Не удалось переключить прокси; восстановлен предыдущий выбор';

  @override
  String get databaseWriteFailedTip =>
      'Не удалось сохранить изменение; оно отменено';

  @override
  String get tip => 'Подсказка';

  @override
  String get account => 'Аккаунт';

  @override
  String get backup => 'Резервное копирование';

  @override
  String get backupSuccess => 'Резервная копия создана';

  @override
  String get noInfo => 'Нет информации';

  @override
  String get pleaseBindWebDAV => 'Привяжите WebDAV';

  @override
  String get bind => 'Привязать';

  @override
  String get connectivity => 'Подключение: ';

  @override
  String get webDAVConfiguration => 'Настройка WebDAV';

  @override
  String get address => 'Адрес';

  @override
  String get addressTip => 'Введите корректный адрес WebDAV';

  @override
  String get password => 'Пароль';

  @override
  String get authentication => 'Аутентификация';

  @override
  String get authenticationSystemProxyDesc =>
      'Пока включена аутентификация, системный прокси не применяется.';

  @override
  String get checkUpdate => 'Проверить обновления';

  @override
  String get discoverNewVersion => 'Доступна новая версия';

  @override
  String get checkUpdateError => 'У вас уже последняя версия';

  @override
  String get updateNoReleaseFound => 'No Flash release found yet';

  @override
  String get updateCheckFailed =>
      'Couldn\'t check for updates. Please try again.';

  @override
  String get goDownload => 'Скачать';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get country => 'Регион';

  @override
  String get search => 'Поиск';

  @override
  String get allowBypass => 'Разрешить приложениям обходить VPN';

  @override
  String get externalController => 'Внешний контроллер';

  @override
  String get externalControllerDesc =>
      'Внешний контроллер позволяет управлять ядром через порт 9090.';

  @override
  String get externalControllerSecret => 'Секрет внешнего контроллера';

  @override
  String get ipv6Desc => 'Трафик IPv6 принимается, только когда IPv6 включён.';

  @override
  String get app => 'Приложение';

  @override
  String get general => 'Общие';

  @override
  String get startupAndBackground => 'Запуск и фоновая работа';

  @override
  String get requestsAndUpdates => 'Запросы и обновления';

  @override
  String get logsAndDiagnostics => 'Логи и диагностика';

  @override
  String get userAgent => 'User-Agent';

  @override
  String get unifiedDelay => 'Единая задержка';

  @override
  String get tcpConcurrent => 'Параллельный TCP';

  @override
  String get geodataLoader => 'Geo: экономия памяти';

  @override
  String get requests => 'Запросы';

  @override
  String get recentRequests => 'Последние запросы';

  @override
  String get findProcessMode => 'Поиск процесса';

  @override
  String get init => 'Инициализация';

  @override
  String get infiniteTime => 'Бессрочно';

  @override
  String get connections => 'Соединения';

  @override
  String get liveConnections => 'Активные соединения';

  @override
  String get inbound => 'Входящие';

  @override
  String get intranetIP => 'Внутренний IP';

  @override
  String get view => 'Просмотр';

  @override
  String get cut => 'Вырезать';

  @override
  String get copy => 'Копировать';

  @override
  String get clipboardWriteFailed =>
      'Не удалось скопировать в буфер обмена. Возможно, выделение слишком велико';

  @override
  String get paste => 'Вставить';

  @override
  String get testUrl => 'URL для теста';

  @override
  String get delayTestTimeout => 'Тайм-аут теста задержки';

  @override
  String get sync => 'Синхронизация';

  @override
  String get exclude => 'Скрыть из недавних задач';

  @override
  String get compact => 'Компактный';

  @override
  String get tab => 'Вкладки';

  @override
  String get list => 'Список';

  @override
  String get delay => 'Задержка';

  @override
  String get style => 'Стиль';

  @override
  String get size => 'Размер';

  @override
  String get sort => 'Сортировка';

  @override
  String get columns => 'Столбцы';

  @override
  String get proxyGroup => 'Группа прокси';

  @override
  String get go => 'Перейти';

  @override
  String get externalLink => 'Внешняя ссылка';

  @override
  String get otherContributors => 'Другие участники';

  @override
  String get appIconDesign => 'Дизайн значка приложения';

  @override
  String get autoCloseConnections => 'Автозакрытие соединений';

  @override
  String get onlyStatisticsProxy => 'Учитывать только трафик прокси';

  @override
  String get showNotificationStopAction => 'Кнопка остановки в уведомлении';

  @override
  String get pureBlackMode => 'Чисто чёрный режим';

  @override
  String get sidebar => 'Боковая панель';

  @override
  String get backgroundBlur => 'Размытие фона';

  @override
  String get liquidGlass => 'Жидкое стекло';

  @override
  String get keepAliveIntervalDesc => 'Интервал TCP keep-alive';

  @override
  String get entries => ' записей';

  @override
  String get local => 'Локально';

  @override
  String get remote => 'Удалённо';

  @override
  String get mode => 'Режим';

  @override
  String get time => 'Время';

  @override
  String get source => 'Источник';

  @override
  String get action => 'Действие';

  @override
  String get intelligentSelected => 'Умный выбор';

  @override
  String get clipboardImport => 'Импорт из буфера обмена';

  @override
  String get clipboardNoPackageNames =>
      'В буфере обмена нет допустимых имён пакетов';

  @override
  String get clipboardExport => 'Экспорт в буфер обмена';

  @override
  String get layout => 'Макет';

  @override
  String get tight => 'Плотный';

  @override
  String get standard => 'Стандартный';

  @override
  String get ultra => 'Максимум';

  @override
  String get loose => 'Свободный';

  @override
  String get profilesSort => 'Сортировка профилей';

  @override
  String get start => 'Старт';

  @override
  String get runTime => 'Время работы';

  @override
  String get stop => 'Стоп';

  @override
  String get key => 'Ключ';

  @override
  String get value => 'Значение';

  @override
  String get options => 'Опции';

  @override
  String get enabled => 'Включено';

  @override
  String get disabled => 'Выключено';

  @override
  String get loopback => 'Снятие ограничения loopback для UWP';

  @override
  String get providers => 'Внешние ресурсы';

  @override
  String get proxyProviders => 'Провайдеры прокси';

  @override
  String get ruleProviders => 'Провайдеры правил';

  @override
  String get providerUrlTip => 'Поддерживаются только удалённые ресурсы';

  @override
  String get ruleSetEmptyTip => 'В наборе правил нет пригодных записей';

  @override
  String get ruleSetMixedTip =>
      'Набор правил смешивает домены и диапазоны IP, поэтому его тип не определить';

  @override
  String get ruleSetInvalidTip => 'Не удаётся прочитать этот файл mrs';

  @override
  String get subscriptionInfo => 'Информация о подписке';

  @override
  String get server => 'Сервер';

  @override
  String get ntpInterval => 'Интервал синхронизации (минуты)';

  @override
  String get dialerProxy => 'Прокси для подключения';

  @override
  String get writeToSystem => 'Записывать в систему';

  @override
  String get writeToSystemDesc =>
      '«Записывать в систему» также устанавливает системные часы; Android это игнорирует.';

  @override
  String get sniffer => 'Сниффер';

  @override
  String get overrideDestination => 'Подменять адрес назначения';

  @override
  String get forceDnsMapping => 'Принудительно для DNS-сопоставлений';

  @override
  String get forceDnsMappingDesc =>
      '«Принудительно для DNS-сопоставлений» анализирует и соединения, домен которых получен из DNS-сопоставления.';

  @override
  String get parsePureIp => 'Разбирать чистые IP';

  @override
  String get forceDomain => 'Принудительные домены';

  @override
  String get forceDomainDesc =>
      'Принудительные домены тоже анализируются; остальные соединения с доменом не затрагиваются.';

  @override
  String get skipDomain => 'Пропускаемые домены';

  @override
  String get skipSrcAddress => 'Пропускаемые адреса источника';

  @override
  String get skipDstAddress => 'Пропускаемые адреса назначения';

  @override
  String get sniffProtocols => 'Протоколы';

  @override
  String get ports => 'Порты';

  @override
  String get overrideEntries => 'Переопределяемые параметры';

  @override
  String get addOverrideEntry => 'Добавить параметр';

  @override
  String get dnsOverrideDesc =>
      'Добавленные здесь параметры заменяют DNS всех профилей из URL и файлов; остальные остаются такими, как в профиле. DNS пользовательского профиля задаётся в его содержимом.';

  @override
  String get settingEntries => 'параметры';

  @override
  String get addSettingEntry => 'Добавить параметр';

  @override
  String get profileSettingsDesc =>
      'Действует только для этого профиля; не добавленные параметры используют значения по умолчанию.';

  @override
  String get healthCheck => 'Проверка состояния';

  @override
  String get discardChanges => 'Отменить изменения?';

  @override
  String get quickEdit => 'Быстрое редактирование';

  @override
  String get status => 'Статус';

  @override
  String get statusDesc => 'При отключённом DNS используется системный DNS.';

  @override
  String get respectRules => 'Соблюдать правила';

  @override
  String get respectRulesDesc =>
      '«Соблюдать правила» направляет DNS-соединения по правилам; нужен Proxy Server Nameserver.';

  @override
  String get dnsMode => 'Режим DNS';

  @override
  String get fakeipRange => 'Диапазон Fake-IP';

  @override
  String get fakeipFilter => 'Фильтр Fake-IP';

  @override
  String get useHosts => 'Использовать hosts';

  @override
  String get useSystemHosts => 'Использовать системный hosts';

  @override
  String get fallbackFilter => 'Фильтр fallback';

  @override
  String get domain => 'Домен';

  @override
  String get listenRoutingMark => 'Метка маршрутизации';

  @override
  String get listenRoutingMarkDesc =>
      'Метка маршрутизации действует только в Linux.';

  @override
  String get ipv6Timeout => 'Тайм-аут IPv6 (мс)';

  @override
  String get cacheAlgorithm => 'Алгоритм кэша';

  @override
  String get cacheMaxSize => 'Размер кэша';

  @override
  String get fakeipRange6 => 'Диапазон Fake-IP (IPv6)';

  @override
  String get fakeipFilterMode => 'Режим фильтра Fake-IP';

  @override
  String get fakeipTtl => 'TTL Fake-IP';

  @override
  String get reset => 'Сброс';

  @override
  String get actionView => 'Показать/Скрыть';

  @override
  String get actionStart => 'Старт/Стоп';

  @override
  String get actionMode => 'Переключить режим';

  @override
  String get actionProxy => 'Системный прокси';

  @override
  String get actionTun => 'TUN';

  @override
  String get actionRuleMode => 'Режим правил';

  @override
  String get actionGlobalMode => 'Глобальный режим';

  @override
  String get actionDirectMode => 'Прямой режим';

  @override
  String get actionDelayTest => 'Проверить все задержки';

  @override
  String get actionUpdateProfiles => 'Обновить профили';

  @override
  String get disclaimer => 'Отказ от ответственности';

  @override
  String get disclaimerDesc =>
      'Перед использованием Flash («Программа») внимательно прочитайте это заявление и убедитесь, что понимаете его. Нажимая «Согласен», вы подтверждаете, что прочитали и поняли изложенное ниже. Если не хотите продолжать, нажмите «Выход».';

  @override
  String get disclaimerSoftwareTitle => 'Характер программы';

  @override
  String get disclaimerSoftwareContent =>
      'Программа — это клиент сетевого прокси с открытым исходным кодом на основе ядра Clash.Meta (mihomo). Она предоставляет только локальные инструменты: управление конфигурациями, маршрутизацию по правилам и пересылку трафика.';

  @override
  String get disclaimerNoServiceStatement =>
      'Сама Программа не предоставляет прокси-серверы, узлы, подписки или услуги доступа к сети и не состоит в партнёрских, агентских или гарантийных отношениях с поставщиками таких услуг.';

  @override
  String get disclaimerUsageTitle => 'Об использовании';

  @override
  String get disclaimerUsageContent =>
      'Любая коммерческая деятельность с использованием Программы, включая платное распространение, продажу в комплекте или использование в составе коммерческого сервиса, не связана с разработчиками Программы, которые её не одобряют, не поддерживают и не гарантируют.\n\nВы сами отвечаете за соблюдение законов страны или региона, где находитесь, и несёте последствия любого незаконного использования Программы.';

  @override
  String get disclaimerResponsibilityTitle => 'Ваша ответственность';

  @override
  String get disclaimerResponsibilityContent =>
      'Вы самостоятельно убеждаетесь, что использование Программы законно в вашей стране или регионе, и единолично несёте юридическую ответственность за все действия с ней и их последствия.\n\nПодписки, узлы и конфигурации, которые вы импортируете, выбираете вы сами. Законность их источника, безопасность содержимого и надёжность сервиса — вопрос между вами и их поставщиками.';

  @override
  String get disclaimerThirdPartyTitle => 'Сторонний контент';

  @override
  String get disclaimerThirdPartyContent =>
      'Ссылки на подписки, файлы конфигурации, наборы правил, скрипты, внешние ресурсы и внешние ссылки предоставляются третьими лицами. Разработчики не могут проверять и не проверяют их законность, точность, безопасность и доступность и не дают на них никаких гарантий.\n\nУтечка данных, финансовые потери, блокировка аккаунта или иной ущерб, вызванные сторонним контентом, урегулируются между вами и третьим лицом; разработчики не несут за это никакой ответственности.';

  @override
  String get disclaimerWarrantyTitle => 'Отсутствие гарантий';

  @override
  String get disclaimerWarrantyContent =>
      'Программа предоставляется «как есть» и «по мере доступности», без каких-либо явных или подразумеваемых гарантий, включая, помимо прочего, гарантии товарной пригодности, пригодности для определённой цели, ненарушения прав, бесперебойной работы, отсутствия ошибок и уязвимостей.\n\nРазработчики не гарантируют, что Программа будет соответствовать вашим потребностям или работать без сбоев и ошибок.';

  @override
  String get disclaimerLiabilityTitle => 'Ограничение ответственности';

  @override
  String get disclaimerLiabilityContent =>
      'В максимальной степени, допустимой применимым законодательством, ни разработчики, ни участники проекта не несут ответственности за любой прямой, косвенный, случайный, особый, штрафной или последующий ущерб, возникший в результате использования или невозможности использования Программы, включая, помимо прочего, потерю данных, повреждение устройства, сбои сети, прерывание деятельности, упущенную выгоду или связанные с этим правовые споры, даже если они были предупреждены о возможности такого ущерба.';

  @override
  String get disclaimerPrivacyTitle => 'Сбор данных и конфиденциальность';

  @override
  String get disclaimerPrivacyContent =>
      'Программа не собирает и не отправляет адреса ваших подписок, сведения об узлах, содержимое конфигураций, посещённые сайты, записи о подключениях, содержимое трафика и журналы. Эти данные хранятся только на вашем устройстве, и у разработчиков нет к ним доступа.\n\nПрограмма обращается к сети только при использовании соответствующих функций, например загружает указанный вами адрес подписки при обновлении профиля или обращается к GitHub при проверке обновлений.\n\nПрограмма не содержит никаких сервисов статистики или отчётов о сбоях ни на одной платформе.';

  @override
  String get disclaimerLicenseTitle => 'Лицензия с открытым исходным кодом';

  @override
  String get disclaimerLicenseContent =>
      'Программа распространяется с открытым исходным кодом по лицензии GPL-3.0. По этой лицензии вы можете запускать, изучать, изменять и распространять её; распространяя Программу или её изменённую версию, вы должны также предоставить исходный код по GPL-3.0 и сохранить исходные уведомления об авторских правах.\n\nСторонние компоненты Программы, включая ядро Clash.Meta, распространяются по своим лицензиям. Исходные авторы не отвечают за проблемы версий, изменённых или распространяемых другими.';

  @override
  String get disclaimerChangesTitle => 'Изменения заявления';

  @override
  String get disclaimerChangesContent =>
      'Это заявление может меняться в следующих версиях; к каждой версии относится заявление, поставляемое с ней.';

  @override
  String get disclaimerAcceptTitle => 'Связь с открытой лицензией';

  @override
  String get disclaimerAcceptContent =>
      'Это заявление описывает характер, риски и ответственность при использовании Программы. Оно не является дополнительным условием к GPL-3.0 и не ограничивает никаких прав, которые даёт вам эта лицензия, включая право запускать, копировать, изменять и распространять Программу. При расхождении действует GPL-3.0.';

  @override
  String get disclaimerRestateTitle => 'Повторите заявление';

  @override
  String get disclaimerRestateTip =>
      'Чтобы подтвердить, что вы ознакомились с ним, полностью введите следующее заявление в поле ниже:';

  @override
  String get disclaimerRestateHint => 'Введите заявление выше';

  @override
  String get disclaimerRestateMismatch => 'Не совпадает с текстом заявления';

  @override
  String get disclaimerAcknowledgeTitle => 'Подтвердите заявление';

  @override
  String get disclaimerAcknowledgeTip =>
      'Чтобы подтвердить, что вы ознакомились с ним, прочитайте следующее заявление и отметьте пункт ниже:';

  @override
  String get disclaimerAcknowledgeLabel =>
      'Я прочитал(а) и понимаю это заявление';

  @override
  String get agree => 'Согласен';

  @override
  String get hotkeyManagement => 'Горячие клавиши';

  @override
  String get hotkeyDesc =>
      'Глобальные горячие клавиши работают, даже когда окно скрыто. Нажмите на действие, чтобы записать сочетание клавиш.';

  @override
  String get hotkeyNotSet => 'Не задано';

  @override
  String get pressKeyboard => 'Нажмите сочетание клавиш';

  @override
  String hotkeyNeedsModifier(Object modifiers) {
    return 'Добавьте хотя бы одну из клавиш: $modifiers';
  }

  @override
  String hotkeyConflictWith(Object action) {
    return 'Уже используется для «$action». При сохранении будет перенесено сюда.';
  }

  @override
  String get hotkeyUnavailable =>
      'Не зарегистрировано: сочетание может быть занято другим приложением';

  @override
  String get remove => 'Убрать';

  @override
  String get noNetwork => 'Нет сети';

  @override
  String get exportLogs => 'Экспорт логов';

  @override
  String get exportSuccess => 'Экспорт выполнен';

  @override
  String get iconStyle => 'Стиль значков';

  @override
  String get iconStyleFilled => 'С подложкой';

  @override
  String get iconStylePlain => 'Без подложки';

  @override
  String get iconStyleHidden => 'Скрыто';

  @override
  String get filter => 'Фильтр';

  @override
  String get groupBy => 'Группировка';

  @override
  String get hideTimeoutProxies => 'Скрывать прокси с таймаутом';

  @override
  String get showHiddenGroups => 'Показывать скрытые группы';

  @override
  String get hiddenGroupTag => 'Скрытая';

  @override
  String hiddenGroupSemantics(Object name) {
    return '$name, Скрытая';
  }

  @override
  String get stackMode => 'Режим стека';

  @override
  String get network => 'Сеть';

  @override
  String get bypassDomain => 'Исключённые домены';

  @override
  String get pacMode => 'Режим PAC';

  @override
  String get pacScript => 'Скрипт PAC';

  @override
  String get bypassDomainDesc =>
      'Исключённые домены действуют только при включённом системном прокси.';

  @override
  String get bypassLocalWindowsOnly => 'Только Windows: имена хостов без точки';

  @override
  String get resetTip => 'Вы уверены, что хотите выполнить сброс?';

  @override
  String get icon => 'Значок';

  @override
  String get noData => 'Нет данных';

  @override
  String get fontFamily => 'Шрифт';

  @override
  String get installedFonts => 'Установленные шрифты';

  @override
  String get toggle => 'Переключить';

  @override
  String get system => 'Система';

  @override
  String get routeAddress => 'Адреса маршрутов';

  @override
  String get interfaceNameMode => 'Исходящий интерфейс';

  @override
  String get interfaceNameModeClear => 'Очистить';

  @override
  String get interfaceNameModeFollow => 'Как в конфигурации';

  @override
  String get interfaceNameModeCustom => 'Вручную';

  @override
  String get interfaceName => 'Имя интерфейса';

  @override
  String get copyEnvVar => 'Копировать переменные окружения';

  @override
  String get trayTunMode => 'Режим TUN';

  @override
  String get trayCopyProxyCommand => 'Копировать команду прокси для терминала';

  @override
  String get memoryInfo => 'Память';

  @override
  String get total => 'Всего';

  @override
  String get releaseMemory => 'Освободить память';

  @override
  String get memoryCoreHeapInuse => 'Используемая куча';

  @override
  String get memoryCoreHeapIdle => 'Свободная куча';

  @override
  String get memoryCoreStack => 'Стеки горутин';

  @override
  String get memoryCoreRuntime => 'Накладные расходы среды';

  @override
  String get memoryGoRuntimeDescription =>
      'Статистика среды выполнения Go; эти значения не являются составляющими резидентной памяти процесса.';

  @override
  String get memoryCoreNotRunning => 'Ядро не запущено';

  @override
  String get memoryAppResident => 'Резидентная память';

  @override
  String get memoryAppShared => 'Приложение и общая';

  @override
  String get memoryEstimateDesc =>
      'Оценка по резидентной памяти процессов; может отличаться от данных системы.';

  @override
  String get memoryEstimateSharedDesc =>
      'Ядро работает в процессе приложения. Его доля оценивается по статистике среды выполнения, остальное относится к приложению и общей памяти.';

  @override
  String get memoryReleased => 'Память освобождена';

  @override
  String memoryReleasedSize(Object size) {
    return 'Освобождено $size';
  }

  @override
  String get releaseMemoryFailed => 'Не удалось освободить память';

  @override
  String get dialog => 'Диалог';

  @override
  String get cancel => 'Отмена';

  @override
  String get fileIsUpdate => 'Файл изменён. Сохранить изменения?';

  @override
  String get profileHasUpdate => 'Профиль изменён. Отключить автообновление?';

  @override
  String get hasCacheChange => 'Кэшировать изменения?';

  @override
  String get copySuccess => 'Скопировано';

  @override
  String get copyLink => 'Копировать ссылку';

  @override
  String get exportFile => 'Экспорт файла';

  @override
  String get cacheCorrupt => 'Кэш повреждён. Очистить его?';

  @override
  String get detectionTip => 'Использует сторонний API; только для справки';

  @override
  String get listen => 'Прослушивание';

  @override
  String get undo => 'Отменить';

  @override
  String get redo => 'Повторить';

  @override
  String get lineWrap => 'Перенос строк';

  @override
  String get none => 'Нет';

  @override
  String get advancedConfig => 'Расширенная конфигурация';

  @override
  String get addRule => 'Добавить правило';

  @override
  String get content => 'Содержимое';

  @override
  String get ruleTarget => 'Цель правила';

  @override
  String get matchTarget => 'MATCH-TARGET';

  @override
  String get followProfile => 'Как в профиле';

  @override
  String get scriptFailed => 'Не удалось выполнить скрипт';

  @override
  String get sourceIp => 'IP источника';

  @override
  String get noResolve => 'Не разрешать IP';

  @override
  String get saveChanges => 'Сохранить изменения?';

  @override
  String get applyNow => 'Применить сейчас';

  @override
  String get applied => 'Применено';

  @override
  String get cannotSave => 'Не удалось сохранить';

  @override
  String get navigationBarStyle => 'Нижняя панель';

  @override
  String get floating => 'Плавающая';

  @override
  String get docked => 'Закреплённая';

  @override
  String get slide => 'Сдвиг';

  @override
  String get fade => 'Растворение';

  @override
  String get pureBlack => 'Чисто чёрный';

  @override
  String get customColor => 'Свой цвет';

  @override
  String get colorStyle => 'Стиль палитры';

  @override
  String get grid => 'Сетка';

  @override
  String get spectrum => 'Спектр';

  @override
  String get sliders => 'Ползунки';

  @override
  String get hue => 'Оттенок';

  @override
  String get saturation => 'Насыщенность';

  @override
  String get brightness => 'Яркость';

  @override
  String get hex => 'Hex';

  @override
  String get monochromeScheme => 'Монохром';

  @override
  String get vividStyle => 'Яркий';

  @override
  String get tintedStyle => 'Тонированный';

  @override
  String get softStyle => 'Мягкий';

  @override
  String get developerMode => 'Режим разработчика';

  @override
  String get developerModeEnableTip => 'Режим разработчика включён.';

  @override
  String get messageTest => 'Тест сообщения';

  @override
  String get messageTestTip => 'Это сообщение.';

  @override
  String get crashTest => 'Тест сбоя';

  @override
  String get crashDetected => 'Обнаружен сбой';

  @override
  String crashDetectedTip(Object name) {
    return 'Приложение два раза подряд не смогло завершить запуск. Чтобы разорвать цикл, профиль $name снят с выбора, а автоматическая настройка пропущена. Вы можете выбрать его снова в любой момент.';
  }

  @override
  String get launchInterrupted => 'Запуск не завершён';

  @override
  String get launchInterruptedTip =>
      'В прошлый раз приложение неожиданно завершилось во время запуска. Автоматическая настройка для этого запуска пропущена; вы можете запустить её вручную.';

  @override
  String get clearData => 'Очистить данные';

  @override
  String get textScale => 'Масштаб текста';

  @override
  String get textScalePreview => 'Так будет выглядеть текст в приложении';

  @override
  String get followSystem => 'Как в системе';

  @override
  String get internet => 'Интернет';

  @override
  String get systemApp => 'Системные приложения';

  @override
  String get noNetworkApp => 'Приложения без сети';

  @override
  String get restoreStrategy => 'Стратегия восстановления';

  @override
  String get restoreStrategyOverride => 'Перезапись';

  @override
  String get restoreStrategyCompatible => 'Совместимость';

  @override
  String get logsTest => 'Тест логов';

  @override
  String emptyTip(Object label) {
    return 'Поле «$label» не может быть пустым';
  }

  @override
  String urlTip(Object label) {
    return 'Значение «$label» должно быть URL';
  }

  @override
  String get invalidLinkTip =>
      'Это не ссылка на подписку и не ссылка на прокси';

  @override
  String numberTip(Object label) {
    return 'Значение «$label» должно быть числом';
  }

  @override
  String numberRangeTip(Object label, Object min, Object max) {
    return 'Значение «$label» должно быть от $min до $max';
  }

  @override
  String get interval => 'Интервал';

  @override
  String existsTip(Object label) {
    return '«$label» уже существует';
  }

  @override
  String maxLengthTip(Object label, Object max) {
    return '«$label» — не более $max символов';
  }

  @override
  String get singleImport => 'По одному';

  @override
  String get batchImport => 'Массовый импорт';

  @override
  String get batchUrlInputTip => 'По одному URL на строку';

  @override
  String get batchLinkInputTip => 'По одной ссылке на строку';

  @override
  String batchPreviewTip(Object count, Object skipped) {
    return 'Будет добавлено: $count, пропущено (уже есть): $skipped';
  }

  @override
  String lineIssueTip(Object line, Object message) {
    return 'Строка $line: $message';
  }

  @override
  String singleValueTip(Object label) {
    return '«$label» — только одно значение';
  }

  @override
  String deleteTip(Object label) {
    return 'Вы уверены, что хотите удалить «$label»?';
  }

  @override
  String deleteMultipTip(Object label) {
    return 'Вы уверены, что хотите удалить выбранные элементы ($label)?';
  }

  @override
  String nullTip(Object label) {
    return 'Пока нет: $label';
  }

  @override
  String get script => 'Скрипт';

  @override
  String get color => 'Цвет';

  @override
  String get unnamed => 'Без названия';

  @override
  String get pleaseEnterScriptName => 'Введите название скрипта';

  @override
  String get mixedPort => 'Смешанный порт';

  @override
  String get socksPort => 'Порт SOCKS';

  @override
  String get redirPort => 'Порт Redir';

  @override
  String get tproxyPort => 'Порт TProxy';

  @override
  String portTip(Object label) {
    return 'Значение «$label» должно быть от 1024 до 49151';
  }

  @override
  String get portConflictTip => 'Введите другой порт';

  @override
  String get import => 'Импорт';

  @override
  String get importFile => 'Импорт из файла';

  @override
  String get importUrl => 'Импорт по URL';

  @override
  String get startFromScratch => 'С нуля';

  @override
  String details(Object label) {
    return 'Сведения: $label';
  }

  @override
  String get creationTime => 'Время создания';

  @override
  String get process => 'Процесс';

  @override
  String get host => 'Хост';

  @override
  String get destination => 'Назначение';

  @override
  String get destinationGeoIP => 'GeoIP назначения';

  @override
  String get destinationIPASN => 'ASN IP назначения';

  @override
  String get specialProxy => 'Специальный прокси';

  @override
  String get specialRules => 'Специальные правила';

  @override
  String get remoteDestination => 'Удалённое назначение';

  @override
  String get networkType => 'Тип сети';

  @override
  String get proxyChains => 'Цепочка прокси';

  @override
  String get log => 'Лог';

  @override
  String get connection => 'Соединение';

  @override
  String get request => 'Запрос';

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get connecting => 'Подключение…';

  @override
  String get restartCoreTip => 'Вы уверены, что хотите перезапустить ядро?';

  @override
  String get forceRestartCoreTip =>
      'Вы уверены, что хотите принудительно перезапустить ядро?';

  @override
  String get dnsHijacking => 'Перехват DNS';

  @override
  String get coreStatus => 'Статус ядра';

  @override
  String get appendSystemDns => 'Добавлять системный DNS';

  @override
  String get editRule => 'Редактировать правило';

  @override
  String get addedRules => 'Добавленные правила';

  @override
  String get addedRulesAfterScript =>
      'Добавляются после выполнения скрипта, перед правилами профиля';

  @override
  String get controlGlobalAddedRules =>
      'Управление глобальными добавленными правилами';

  @override
  String get quickActions => 'Быстрые действия';

  @override
  String get rulePresetBlockQuic => 'Блокировать QUIC';

  @override
  String get rulePresetBlockStun => 'Блокировать STUN';

  @override
  String get rulePresetBlockDot => 'Блокировать DNS over TLS';

  @override
  String get rulePresetBlockLoopback => 'Защита от петли прокси';

  @override
  String get rulePresetSystemServicesDirect => 'Apple и Microsoft напрямую';

  @override
  String get rulePresetBittorrentDirect => 'BitTorrent напрямую';

  @override
  String get rulePresetLanDirect => 'Локальная сеть напрямую';

  @override
  String get extendScript => 'Скрипт расширения';

  @override
  String get goToConfigureScript => 'Перейти к настройке скрипта';

  @override
  String get goToConfigureAddedRules =>
      'Перейти к настройке добавленных правил';

  @override
  String get editGlobalRules => 'Редактировать глобальные правила';

  @override
  String get confirmForceCrashCore =>
      'Вы уверены, что хотите принудительно завершить ядро со сбоем?';

  @override
  String get confirmClearAllData =>
      'Вы уверены, что хотите удалить все данные?';

  @override
  String get loading => 'Загрузка…';

  @override
  String yearsAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года назад',
      many: '$count лет назад',
      few: '$count года назад',
      one: '$count год назад',
    );
    return '$_temp0';
  }

  @override
  String monthsAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца назад',
      many: '$count месяцев назад',
      few: '$count месяца назад',
      one: '$count месяц назад',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня назад',
      many: '$count дней назад',
      few: '$count дня назад',
      one: '$count день назад',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часа назад',
      many: '$count часов назад',
      few: '$count часа назад',
      one: '$count час назад',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты назад',
      many: '$count минут назад',
      few: '$count минуты назад',
      one: '$count минуту назад',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Только что';

  @override
  String yearsAgoShort(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count г. назад',
      many: '$count л. назад',
      few: '$count г. назад',
      one: '$count г. назад',
    );
    return '$_temp0';
  }

  @override
  String monthsAgoShort(num count) {
    return '$count мес. назад';
  }

  @override
  String daysAgoShort(num count) {
    return '$count дн. назад';
  }

  @override
  String hoursAgoShort(num count) {
    return '$count ч назад';
  }

  @override
  String minutesAgoShort(num count) {
    return '$count мин назад';
  }

  @override
  String get noLongerRemind => 'Больше не напоминать';

  @override
  String get turnOn => 'Включить';

  @override
  String get turnOff => 'Выключить';

  @override
  String get vpnConfigChangeDetected =>
      'Настройки VPN изменены. Нажмите, чтобы перезапустить';

  @override
  String get restart => 'Перезапустить';

  @override
  String get speedStatistics => 'Статистика скорости';

  @override
  String get resetPageChangesTip =>
      'На этой странице есть изменения. Вы уверены, что хотите выполнить сброс?';

  @override
  String get customProfile => 'Пользовательский';

  @override
  String get customResources => 'Пользовательские';

  @override
  String get unknownNetworkError => 'Неизвестная сетевая ошибка';

  @override
  String get backupFromNewerVersion =>
      'Резервная копия создана более новой версией приложения. Обновите приложение перед восстановлением';

  @override
  String get networkTimeoutError =>
      'Время ожидания запроса истекло. Проверьте сеть или прокси и повторите попытку';

  @override
  String get networkHostLookupError =>
      'Не удалось определить адрес сервера. Проверьте правильность URL и работу DNS';

  @override
  String get monochromeIcon => 'Монохромный значок';

  @override
  String get networkConnectionError =>
      'Не удалось подключиться к серверу. Проверьте подключение к сети или настройки прокси';

  @override
  String get networkTlsError =>
      'Не удалось установить защищённое соединение. Сертификат сервера может быть недействителен, или соединение перехватывается';

  @override
  String get networkCancelledError => 'Запрос отменён';

  @override
  String networkAccessDeniedError(Object code) {
    return 'Сервер запретил доступ (HTTP $code). Возможно, ссылка устарела или учётные данные неверны';
  }

  @override
  String networkNotFoundError(Object code) {
    return 'По этому адресу ничего не найдено (HTTP $code). Проверьте правильность URL';
  }

  @override
  String get networkRateLimitedError =>
      'Слишком много запросов (HTTP 429). Подождите немного и повторите попытку';

  @override
  String networkServerError(Object code) {
    return 'На сервере произошла ошибка (HTTP $code). Повторите попытку позже';
  }

  @override
  String networkBadResponseError(Object code) {
    return 'Сервер отклонил запрос (HTTP $code)';
  }

  @override
  String networkRequestFailed(Object detail) {
    return 'Сетевой запрос не выполнен: $detail';
  }

  @override
  String get invalidBackupFile => 'Недопустимый файл резервной копии';

  @override
  String get pruneCache => 'Очистить кэш';

  @override
  String get backupAndRestore => 'Резервное копирование и восстановление';

  @override
  String get restore => 'Восстановить';

  @override
  String get restoreSuccess => 'Восстановление выполнено';

  @override
  String get restoreOnlyConfig => 'Восстановить только профили';

  @override
  String get restoreAllData => 'Восстановить все данные';

  @override
  String get addProfile => 'Добавить профиль';

  @override
  String get delayTest => 'Тест задержки';

  @override
  String get proxyGroupEmpty => 'Группа прокси пуста';

  @override
  String get confirmExitWindow =>
      'Вы уверены, что хотите закрыть текущее окно?';

  @override
  String get optional => 'Необязательно';

  @override
  String get maxFailedTimes => 'Макс. число неудач';

  @override
  String get testInterval => 'Интервал тестирования';

  @override
  String get excludeFilter => 'Фильтр исключения';

  @override
  String get expectedStatus => 'Ожидаемый статус';

  @override
  String get strategy => 'Стратегия';

  @override
  String get tolerance => 'Допуск';

  @override
  String get inputProxyGroupName => 'Введите название группы прокси';

  @override
  String get helperCorruptTip =>
      'Служба Helper недоступна, поэтому TUN-режим включить нельзя. Переустановите Flash.';

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
  String get sudoPasswordTitle => 'Введите пароль для sudo';

  @override
  String coreBlockedByPolicyTip(Object code) {
    return 'Windows отказалась запускать FlClashCore.exe (ошибка $code). Политики контроля приложений, такие как Smart App Control или AppLocker, блокируют неподписанные программы; разрешите Flash в этой политике или отключите её и повторите попытку.';
  }

  @override
  String get coreBlockedBySmartAppControlTip =>
      'Smart App Control в Windows заблокировал неподписанный FlClashCore.exe. Откройте Безопасность Windows → Управление приложениями и браузером → Параметры Smart App Control, выберите «Выкл.» и снова запустите Flash. Повторно включить Smart App Control без переустановки Windows нельзя.';

  @override
  String get hideFromList => 'Скрыть из списка';

  @override
  String get testWhenUsed => 'Тестировать при использовании';

  @override
  String get disableUDP => 'Отключить UDP';

  @override
  String get confirmDeleteProxyGroup =>
      'Вы уверены, что хотите удалить эту группу прокси?';

  @override
  String get ruleEmpty => 'Правило пусто';

  @override
  String get inputRuleContent => 'Введите содержимое правила';

  @override
  String get ruleSet => 'Набор правил';

  @override
  String get selectRuleSet => 'Выберите набор правил';

  @override
  String get splitStrategy => 'Стратегия распределения';

  @override
  String get selectSplitStrategy => 'Выберите стратегию распределения';

  @override
  String get noResolveHostname => 'Не разрешать имя хоста';

  @override
  String get matchSourceIp => 'Сопоставлять IP источника';

  @override
  String get basicInfo => 'Основная информация';

  @override
  String get additionalParameters => 'Дополнительные параметры';

  @override
  String get proxyType => 'Тип прокси';

  @override
  String get basicStrategy => 'Базовые политики';

  @override
  String get editProxy => 'Редактировать прокси';

  @override
  String get addNodes => 'Добавить узлы';

  @override
  String get addProxyGroup => 'Добавить группу прокси';

  @override
  String get editProxyGroup => 'Редактировать группу прокси';

  @override
  String get iconUrl => 'URL значка';

  @override
  String get iconRecords => 'История значков';

  @override
  String get custom => 'Вручную';

  @override
  String get ruleActionDomainDesc => 'Сопоставить полный домен';

  @override
  String get ruleActionDomainSuffixDesc => 'Сопоставить суффикс домена';

  @override
  String get ruleActionDomainKeywordDesc =>
      'Сопоставить ключевое слово в домене';

  @override
  String get ruleActionDomainRegexDesc =>
      'Сопоставить по регулярному выражению домена';

  @override
  String get ruleActionDomainWildcardDesc =>
      'Сопоставление по маске; поддерживаются только * и ?';

  @override
  String get ruleActionGeositeDesc => 'Сопоставить домены из Geosite';

  @override
  String get ruleActionIpCidrDesc => 'Сопоставить диапазон IP-адресов';

  @override
  String get ruleActionIpCidr6Desc =>
      'Сопоставить диапазон IP-адресов; IP-CIDR6 — просто псевдоним';

  @override
  String get ruleActionIpSuffixDesc => 'Сопоставить диапазон суффиксов IP';

  @override
  String get ruleActionIpAsnDesc => 'Сопоставить ASN, которой принадлежит IP';

  @override
  String get ruleActionGeoipDesc => 'Сопоставить код страны IP-адреса';

  @override
  String get ruleActionSrcGeoipDesc => 'Сопоставить код страны IP источника';

  @override
  String get ruleActionSrcIpAsnDesc => 'Сопоставить ASN IP источника';

  @override
  String get ruleActionSrcIpCidrDesc =>
      'Сопоставить диапазон IP-адресов источника';

  @override
  String get ruleActionSrcIpSuffixDesc =>
      'Сопоставить диапазон суффиксов IP источника';

  @override
  String get ruleActionDstPortDesc => 'Сопоставить диапазон портов назначения';

  @override
  String get ruleActionSrcPortDesc => 'Сопоставить диапазон портов источника';

  @override
  String get ruleActionInPortDesc => 'Сопоставить входящий порт';

  @override
  String get ruleActionInTypeDesc => 'Сопоставить тип входящего подключения';

  @override
  String get ruleActionInUserDesc =>
      'Сопоставить имя пользователя входящего подключения; несколько имён разделяются /';

  @override
  String get ruleActionInNameDesc => 'Сопоставить имя входящего подключения';

  @override
  String get ruleActionRematchNameDesc =>
      'Сопоставить имя повторного сопоставления; несколько имён разделяются /';

  @override
  String get ruleActionProcessPathDesc =>
      'Сопоставить по полному пути процесса';

  @override
  String get ruleActionProcessPathRegexDesc =>
      'Сопоставить по регулярному выражению пути процесса';

  @override
  String get ruleActionProcessPathWildcardDesc =>
      'Сопоставить по маске пути процесса; поддерживаются только * и ?';

  @override
  String get ruleActionProcessNameDesc =>
      'Сопоставить по имени процесса; на Android соответствует имени пакета';

  @override
  String get ruleActionProcessNameRegexDesc =>
      'Сопоставить по регулярному выражению имени процесса; на Android соответствует имени пакета';

  @override
  String get ruleActionProcessNameWildcardDesc =>
      'Сопоставить по маске имени процесса; поддерживаются только * и ?';

  @override
  String get ruleActionUidDesc => 'Сопоставить Linux USER ID';

  @override
  String get ruleActionNetworkDesc => 'Сопоставить TCP или UDP';

  @override
  String get ruleActionDscpDesc =>
      'Сопоставить метку DSCP (только для входящих tproxy UDP)';

  @override
  String get ruleActionRuleSetDesc =>
      'Ссылка на набор правил; требуется настроить rule-providers';

  @override
  String get ruleActionAndDesc => 'Логическое правило AND';

  @override
  String get ruleActionOrDesc => 'Логическое правило OR';

  @override
  String get ruleActionNotDesc => 'Логическое правило NOT';

  @override
  String get ruleActionSubRuleDesc =>
      'Переход к подправилу; обратите внимание на скобки';

  @override
  String get ruleActionMatchDesc =>
      'Сопоставляет все запросы, условия не нужны';

  @override
  String get contentNotEmpty => 'Содержимое не может быть пустым';

  @override
  String get splitStrategyNotEmpty =>
      'Стратегия распределения не может быть пустой';

  @override
  String get timeout => 'Тайм-аут';

  @override
  String get delayFailed => 'Сбой';

  @override
  String invalidSubRule(Object subRule) {
    return '$subRule — недопустимый SUB_RULE';
  }

  @override
  String invalidPolicy(Object target) {
    return '$target — недопустимая политика';
  }

  @override
  String invalidProxyProvider(Object providerName) {
    return '$providerName — недопустимый провайдер прокси';
  }

  @override
  String invalidRuleSet(Object ruleSet) {
    return '$ruleSet — недопустимый набор правил';
  }

  @override
  String get invalidNetworkContent => 'Поддерживаются только tcp и udp';

  @override
  String get invalidRangeContent =>
      'Введите числа или диапазоны, например 80 или 8000-9000, через /';

  @override
  String get invalidDscpContent => 'Метка DSCP не может превышать 63';

  @override
  String get invalidCidrContent =>
      'Введите диапазон IP в формате CIDR, например 192.168.0.0/16';

  @override
  String get invalidPortRangeContent =>
      'Введите порт или диапазон, например 443 или 8000-9000';

  @override
  String get invalidHostContent => 'Введите домен или IP-адрес';

  @override
  String get invalidListenContent =>
      'Введите адрес и порт, например 0.0.0.0:1053';

  @override
  String invalidProxy(Object proxyName) {
    return '$proxyName — недопустимый прокси';
  }

  @override
  String get locationPermissionRequired => 'Требуется разрешение на геолокацию';

  @override
  String locationPermissionGuide(Object appName) {
    return '1. Откройте Системные настройки > Конфиденциальность и безопасность\n2. Выберите Службы геолокации\n3. Найдите и отметьте $appName в списке\n\nПосле настройки вернитесь в приложение и продолжайте работу. Спасибо за сотрудничество.';
  }

  @override
  String get prerequisites => 'Предварительные условия';

  @override
  String get ignoreBatteryOptimization => 'Игнорировать оптимизацию батареи';

  @override
  String get locationPermission => 'Разрешение на геолокацию';

  @override
  String get locationPermissionDesc =>
      'По требованию системы для получения имени сети Wi-Fi необходимо разрешение на геолокацию. На Android выберите «Разрешить всегда», иначе имя сети Wi-Fi нельзя получить, пока приложение в фоне.';

  @override
  String get excludeSsids => 'Исключённые SSID';

  @override
  String get excludeSsidsDesc =>
      'При подключении к Wi-Fi с исключённым SSID состояние работы приложения переключается автоматически.';

  @override
  String get ssidsEmpty => 'Список SSID пуст';

  @override
  String get onDemand => 'По условию';

  @override
  String get locationPermissionDeniedMessage =>
      'Разрешение на геолокацию отклонено, поэтому невозможно получить имя текущей сети Wi-Fi. Включите разрешение на геолокацию вручную в системных настройках.';

  @override
  String get addSsid => 'Добавить SSID';

  @override
  String get editSsid => 'Изменить SSID';

  @override
  String get authorized => 'Разрешено';

  @override
  String get tapToAuthorize => 'Нажмите, чтобы разрешить';

  @override
  String get suspended => 'Приостановлено…';

  @override
  String get resourceUpdateInterval => 'Интервал автообновления';

  @override
  String get resourceUpdateIntervalTip =>
      'Интервал автообновления должен быть больше 0';

  @override
  String get hours => 'часов';

  @override
  String get minutes => 'минут';

  @override
  String get geoResources => 'Geo';

  @override
  String geoSkipped(Object name) {
    return '$name: уже последняя версия';
  }

  @override
  String geoUpdated(Object name) {
    return '$name: обновлено';
  }

  @override
  String secondsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунды',
      many: '$count секунд',
      few: '$count секунды',
      one: '$count секунда',
    );
    return '$_temp0';
  }

  @override
  String proxiesCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label прокси',
    );
    return '$_temp0';
  }

  @override
  String rulesCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label правила',
      many: '$label правил',
      few: '$label правила',
      one: '$label правило',
    );
    return '$_temp0';
  }

  @override
  String proxyGroupsCount(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label группы прокси',
      many: '$label групп прокси',
      few: '$label группы прокси',
      one: '$label группа прокси',
    );
    return '$_temp0';
  }

  @override
  String get changelogBreaking => 'Важные изменения';

  @override
  String get changelogFeatures => 'Новые функции';

  @override
  String get changelogFixes => 'Исправления';

  @override
  String get changelogPerformance => 'Производительность';

  @override
  String get changelogReverts => 'Откаты';

  @override
  String get close => 'Закрыть';

  @override
  String get back => 'Назад';

  @override
  String get minimize => 'Свернуть';

  @override
  String get maximize => 'Развернуть';

  @override
  String get unmaximize => 'Свернуть в окно';

  @override
  String get pinWindow => 'Закрепить поверх всех окон';

  @override
  String get unpinWindow => 'Открепить окно';

  @override
  String get exitFullScreen => 'Выйти из полноэкранного режима';

  @override
  String get torch => 'Фонарик';

  @override
  String get pickFromAlbum => 'Выбрать из галереи';

  @override
  String get closeConnections => 'Закрыть соединения';

  @override
  String get scrollToSelected => 'Прокрутить к выбранному';

  @override
  String get showMore => 'Развернуть';

  @override
  String get showLess => 'Свернуть';

  @override
  String get previousMatch => 'Предыдущее совпадение';

  @override
  String get nextMatch => 'Следующее совпадение';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get noSearchResults => 'Ничего не найдено';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get authorize => 'Разрешить';

  @override
  String get installedAppsPermissionRequired =>
      'Требуется разрешение на список приложений';

  @override
  String get installedAppsPermissionDesc =>
      'Эта система не выдаёт список установленных приложений без разрешения. Предоставьте его, чтобы настроить прокси для отдельных приложений.';

  @override
  String get installedAppsPermissionDeniedMessage =>
      'Разрешение на список приложений отклонено, поэтому установленные приложения недоступны. Предоставьте его вручную в системных настройках.';

  @override
  String get outboundIp => 'Исходящий IP';

  @override
  String get ipAddress => 'IP-адрес';

  @override
  String get ipQualityLevel => 'Уровень';

  @override
  String get ipQualityGood => 'Хороший';

  @override
  String get ipQualityNormal => 'Обычный';

  @override
  String get ipQualityRisky => 'Рискованный';

  @override
  String get ipType => 'Тип';

  @override
  String get ipTypeResidential => 'Домашний';

  @override
  String get ipTypeMobile => 'Мобильная сеть';

  @override
  String get ipTypeBusiness => 'Бизнес';

  @override
  String get ipTypeHosting => 'Дата-центр';

  @override
  String get ipFlags => 'Метки';

  @override
  String get ipFlagProxy => 'Прокси';

  @override
  String get ipFlagVpn => 'VPN';

  @override
  String get ipFlagTor => 'Tor';

  @override
  String get ipFlagAbuser => 'Злоупотребления';

  @override
  String get ipOrganization => 'Организация';

  @override
  String get ipAsn => 'ASN';

  @override
  String get ipQualitySource => 'Источник ответа';

  @override
  String get ipQualitySources => 'Источники';

  @override
  String get ipQualityFailed => 'Не удалось определить тип IP';

  @override
  String get ipQualityRetry => 'Проверить снова';

  @override
  String get ipSourceNoType => 'Тип не определён';

  @override
  String get ipSourceRateLimited => 'Лимит запросов';

  @override
  String get ipSourceIpMismatch => 'Другой исходящий IP';

  @override
  String get hideIp => 'Скрыть IP';

  @override
  String get editorUnavailable => 'Редактор недоступен';

  @override
  String get replace => 'Заменить';

  @override
  String get replaceAll => 'Заменить все';

  @override
  String get cameraPermissionRequired => 'Требуется доступ к камере';

  @override
  String get cameraPermissionDesc =>
      'Разрешите доступ к камере в системных настройках, чтобы сканировать QR-коды, или выберите изображение QR-кода из галереи.';

  @override
  String get cameraUnavailable => 'Камера недоступна';

  @override
  String get retry => 'Повторить';

  @override
  String get invalidProfileQrcode =>
      'Этот QR-код не содержит ссылку на профиль';

  @override
  String get dnsQueries => 'DNS-запросы';

  @override
  String get recordType => 'Тип записи';

  @override
  String get answers => 'Ответы';

  @override
  String get responseCode => 'Код ответа';

  @override
  String get error => 'Ошибка';

  @override
  String get initiator => 'Инициатор';

  @override
  String get cache => 'Кэш';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get nonTextProviderFile =>
      'Этот внешний ресурс не является текстовым файлом';

  @override
  String get addCustomProxy => 'Добавить прокси';

  @override
  String get definitionNotMap =>
      'Конфигурация должна быть YAML-словарём с полями name и type';

  @override
  String get ruleTextInvalid =>
      'Правило должно начинаться с поддерживаемого типа, например DOMAIN,example.com,DIRECT';

  @override
  String get ruleListInvalid =>
      'Правила должны быть YAML-списком, по одному правилу в элементе, например - DOMAIN,example.com,DIRECT';

  @override
  String get shareLinksInvalid => 'Не удалось прочитать прокси из ссылок';

  @override
  String shareLinkUnreadable(Object link) {
    return 'Не удалось прочитать прокси из $link';
  }

  @override
  String proxiesProfileLabel(Object name, Object count) {
    return '$name и другие ($count прокси)';
  }

  @override
  String get singleShareLinkOnly =>
      'Здесь укажите одну ссылку, несколько можно задать в быстром редактировании списка';

  @override
  String get username => 'Имя пользователя';

  @override
  String get emptyFallback => 'Резерв для пустой группы';

  @override
  String get defaultSelected => 'Выбор по умолчанию';

  @override
  String get hashByInUser => 'Хешировать по пользователю входящего подключения';

  @override
  String get appProxiesEmpty => 'Нет локальных прокси';

  @override
  String get nodes => 'Узлы';

  @override
  String get localProxies => 'Локальные прокси';

  @override
  String get customIssueEmptyName => 'Имя не задано';

  @override
  String customIssueReservedName(Object name) {
    return '$name — встроенное имя политики, его нельзя использовать';
  }

  @override
  String customIssueDuplicateName(Object name) {
    return 'Имя $name уже занято другим прокси или группой прокси';
  }

  @override
  String customIssueCoreRejected(Object message) {
    return 'Ядро не может разобрать этот прокси: $message';
  }

  @override
  String customIssueMissingProxies(Object names) {
    return 'Эти прокси или политики не существуют: $names';
  }

  @override
  String customIssueMissingProviders(Object names) {
    return 'Эти провайдеры прокси не существуют: $names';
  }

  @override
  String get customIssueNoProxySource =>
      'Не выбраны ни прокси, ни провайдеры прокси, поэтому ядро отклонит эту группу';

  @override
  String customIssueGroupLoop(Object path) {
    return 'Группы прокси ссылаются друг на друга по кругу: $path';
  }

  @override
  String customIssueInvalidEmptyFallback(Object name) {
    return 'Резервом для пустой группы может быть только прокси, а $name не существует или является группой прокси';
  }

  @override
  String customIssueInvalidFilter(Object name, Object message) {
    return '$name: недопустимое регулярное выражение: $message';
  }

  @override
  String customIssueMissingDialer(Object name) {
    return 'Прокси для подключения $name не существует';
  }

  @override
  String customIssueDialerLoop(Object proxy, Object target) {
    return '$proxy подключается через $target, а $target снова ведёт к $proxy, поэтому подключение зацикливается';
  }

  @override
  String dialerProxyLoopStopped(Object name) {
    return 'Подключение через $name ведёт обратно к прокси, который его использует, поэтому соединение остановлено';
  }

  @override
  String customIssuesSummary(Object count) {
    return 'Проблем: $count, применение профиля может завершиться ошибкой';
  }

  @override
  String providerInUse(Object label, Object profiles) {
    return '«$label» всё ещё используется профилями: $profiles. После удаления они будут работать неправильно. Вы уверены, что хотите удалить его?';
  }

  @override
  String proxyGroupInUse(Object label) {
    return 'На «$label» всё ещё ссылаются правила, группы прокси, прокси для подключения, DNS или NTP этого профиля, и после удаления эти ссылки перестанут работать. Вы уверены, что хотите удалить её?';
  }

  @override
  String proxiesRemovedTip(Object removed) {
    return 'Будут удалены прокси: $removed. Строка с изменённым именем считается новым прокси, а пользовательские профили, ссылающиеся на удалённые, пометят их как отсутствующие. Применить?';
  }

  @override
  String proxiesReplacedTip(Object removed, Object added) {
    return 'Будут удалены прокси: $removed. Будут добавлены: $added. Строка с изменённым именем считается новым прокси, а пользовательские профили, ссылающиеся на удалённые, пометят их как отсутствующие. Применить?';
  }

  @override
  String get fontSize => 'Размер';

  @override
  String get large => 'Крупный';

  @override
  String get extraLarge => 'Очень крупный';

  @override
  String get switchProfile => 'Сменить профиль';

  @override
  String get lastUpdated => 'Последнее обновление';

  @override
  String get filters => 'Фильтры';

  @override
  String get label => 'Метка';

  @override
  String get regex => 'Регулярное выражение';

  @override
  String get matchCase => 'Учитывать регистр';

  @override
  String get iconSets => 'Наборы значков';

  @override
  String get invalidIconSet => 'Это не набор значков';

  @override
  String get recommendedIcons => 'Рекомендуемые';

  @override
  String get localImage => 'Локальное изображение';

  @override
  String get iconSetsEmptyTip =>
      'Наборов значков пока нет. Добавьте их в разделе «Ресурсы пользовательских профилей → Наборы значков»';

  @override
  String get outbound => 'Исходящие';

  @override
  String get strictRoute => 'Строгая маршрутизация';

  @override
  String get congestionController => 'Управление перегрузкой TCP';

  @override
  String get congestionControllerDesc =>
      'Управление перегрузкой TCP действует только со стеком mips.';

  @override
  String get routeExcludeAddress => 'Исключённые адреса маршрутов';

  @override
  String get keepAliveIdle => 'Простой TCP keep-alive';

  @override
  String get disableKeepAlive => 'Отключить TCP keep-alive';

  @override
  String get routingMark => 'Метка маршрутизации';

  @override
  String get strictRouteDesc =>
      'Строгая маршрутизация не даёт трафику вроде DNS обходить TUN, а при выключенном IPv6 блокирует IPv6-соединения этого устройства.';

  @override
  String get initFailed => 'Не удалось запустить';

  @override
  String get initFailedTip =>
      'При запуске Flash произошла ошибка, и работа не может быть продолжена. Скопируйте подробности, чтобы сообщить о проблеме. Если ошибка повторяется, очистка данных обычно позволяет снова запустить приложение.';

  @override
  String get errorDetails => 'Подробности ошибки';

  @override
  String get stackTrace => 'Трассировка стека';

  @override
  String get clearDataAndExitTip =>
      'Все профили, настройки и локальные данные будут удалены, после чего приложение закроется. Откройте его снова, чтобы начать заново.';

  @override
  String clearDataFailed(Object detail) {
    return 'Не удалось очистить данные: $detail';
  }

  @override
  String get bypassPrivateRoute => 'Обходить частные адреса';

  @override
  String get disableIcmpForwarding => 'Отключить пересылку ICMP';

  @override
  String get disableIcmpForwardingDesc =>
      'При отключённой пересылке ICMP TUN сам отвечает на ping, поэтому ping больше не показывает реальную задержку.';

  @override
  String get excludeInterface => 'Исключённые интерфейсы';

  @override
  String get includeInterface => 'Включённые интерфейсы';

  @override
  String get includeInterfaceDesc =>
      'Через TUN идёт только трафик с включённых интерфейсов, а исключённые интерфейсы больше не действуют.';

  @override
  String get includeUid => 'Включённые ID пользователей';

  @override
  String get excludeUid => 'Исключённые ID пользователей';

  @override
  String get excludeSrcPort => 'Исключённые исходные порты';

  @override
  String get excludeDstPort => 'Исключённые порты назначения';

  @override
  String get udpTimeout => 'Тайм-аут UDP';

  @override
  String get udpTimeoutDesc =>
      'Тайм-аут UDP задаётся в секундах и действует только со стеками gvisor, system и mixed.';

  @override
  String get dnsHijackDesc =>
      'Без этого параметра TUN перехватывает все DNS-запросы на порт 53 (any:53).';

  @override
  String get tunOverrideDesc =>
      'Добавленные здесь параметры заменяют настройки TUN всех профилей; остальные остаются такими, как в профиле. Параметры, добавленные в самом пользовательском профиле, имеют приоритет.';

  @override
  String get generalOverrideDesc =>
      'Добавленные здесь параметры заменяют соответствующие настройки всех профилей; остальные остаются такими, как в профиле, а если профиль их не задаёт, действуют значения ядра по умолчанию.';

  @override
  String get profileTunSettingsDesc =>
      'Действует только для этого профиля и имеет приоритет над переопределяемыми параметрами TUN в настройках сети.';

  @override
  String settingsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count настройки',
      many: '$count настроек',
      few: '$count настройки',
      one: '$count настройка',
    );
    return '$_temp0';
  }

  @override
  String sectionsInEffect(Object count) {
    return 'Действуют: $count';
  }

  @override
  String itemsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String get additionalPrefix => 'Префикс имени';

  @override
  String get additionalSuffix => 'Суффикс имени';

  @override
  String get skipCertVerify => 'Пропускать проверку сертификата';

  @override
  String get ipVersion => 'Версия IP';

  @override
  String get addFilters => 'Добавить фильтры';

  @override
  String failedItem(Object label, Object message) {
    return '$label: $message';
  }

  @override
  String failedCount(Object count) {
    return 'Ошибок: $count. Нажмите, чтобы посмотреть';
  }

  @override
  String get importConfigInvalid =>
      'Этот файл не является конфигурацией, которую можно импортировать';

  @override
  String get importConfigReplaceTip =>
      'Импорт заменит текущие группы прокси, правила и настройки этого профиля';

  @override
  String get networkName => 'Имя сети';

  @override
  String get networkSecret => 'Секрет сети';

  @override
  String get peers => 'Пиры';

  @override
  String get virtualIpv4 => 'Виртуальный IPv4';

  @override
  String get hostname => 'Имя хоста';

  @override
  String get exitNodes => 'Выходные узлы';

  @override
  String get cipher => 'Шифр';

  @override
  String get protocol => 'Протокол';

  @override
  String get protocolParam => 'Параметр протокола';

  @override
  String get obfs => 'Обфускация';

  @override
  String get obfsParam => 'Параметр обфускации';

  @override
  String get obfsPassword => 'Пароль обфускации';

  @override
  String get obfsMode => 'Режим обфускации';

  @override
  String get obfsHost => 'Хост обфускации';

  @override
  String get plugin => 'Плагин';

  @override
  String get pluginMode => 'Режим плагина';

  @override
  String get pluginHost => 'Хост плагина';

  @override
  String get pluginPath => 'Путь плагина';

  @override
  String get pluginUsername => 'Имя пользователя плагина';

  @override
  String get pluginPassword => 'Пароль плагина';

  @override
  String get pluginCipher => 'Шифр плагина';

  @override
  String get privateKey => 'Закрытый ключ';

  @override
  String get publicKey => 'Открытый ключ';

  @override
  String get privateKeyPassphrase => 'Пароль закрытого ключа';

  @override
  String get preSharedKey => 'Общий ключ';

  @override
  String get secretKey => 'Ключ';

  @override
  String get transport => 'Транспорт';

  @override
  String get uploadBandwidth => 'Скорость отдачи';

  @override
  String get downloadBandwidth => 'Скорость загрузки';

  @override
  String get protocolVersion => 'Версия протокола';

  @override
  String get portHopping => 'Перескок портов';

  @override
  String get hopInterval => 'Интервал перескока';

  @override
  String get congestionControl => 'Управление перегрузкой';

  @override
  String get udpRelayMode => 'Режим ретрансляции UDP';

  @override
  String get allowedIps => 'Разрешённые IP';

  @override
  String get remoteDnsResolve => 'Удалённое разрешение DNS';

  @override
  String get clientFingerprint => 'Отпечаток клиента';

  @override
  String get requestHeaders => 'Заголовки запроса';

  @override
  String transportHeaders(Object transport) {
    return 'Заголовки $transport';
  }

  @override
  String get required => 'Обязательно';

  @override
  String get ageSecretKey => 'Секретный ключ age';

  @override
  String get ageEncryptedProfile => 'Зашифрованный профиль';

  @override
  String get ageSecretKeyRequiredTip =>
      'Профиль зашифрован с помощью age, для расшифровки нужен секретный ключ age';

  @override
  String get currentOutboundDesc => 'Содержит кнопку запуска, удалить нельзя';

  @override
  String get running => 'Работает';

  @override
  String get root => 'Root';

  @override
  String get notRunning => 'Не запущено';

  @override
  String trafficPeak(Object value) {
    return 'Пик $value';
  }

  @override
  String trafficTotal(Object value) {
    return 'Всего $value';
  }

  @override
  String get ipQualityShort => 'Качество';

  @override
  String get ipTypeUnknown => 'Тип неизвестен';

  @override
  String get tapIconToRetry => 'Нажмите на значок, чтобы повторить';

  @override
  String get networkTakeover => 'Перехват трафика';

  @override
  String portValue(Object port) {
    return 'Порт $port';
  }

  @override
  String serviceAbnormalCount(num count) {
    return 'Проблем: $count';
  }

  @override
  String get serviceAllAvailable => 'Все доступны';

  @override
  String get serviceShownOnDashboard => 'Показан на панели';

  @override
  String groupTimeoutCount(Object count) {
    return 'Тайм-аут: $count';
  }

  @override
  String get groupCountUnit => 'групп';

  @override
  String groupCount(num count) {
    return 'Групп: $count';
  }

  @override
  String get proxyGroupsAfterStart =>
      'Группы появятся здесь после запуска ядра';

  @override
  String get usedShort => 'использовано';

  @override
  String profileUpdatedAt(Object time) {
    return 'Обновлено $time';
  }

  @override
  String profileExpiresIn(Object date, num days) {
    return 'Истекает $date, осталось дней: $days';
  }

  @override
  String profileDaysLeft(num days) {
    return 'Осталось дней: $days';
  }

  @override
  String get target => 'Цель';

  @override
  String get outboundExit => 'Выход';

  @override
  String get duration => 'Длительность';

  @override
  String get traffic => 'Трафик';

  @override
  String get totalDownload => 'Загружено';

  @override
  String get totalUpload => 'Отдано';

  @override
  String get initiatorShort => 'Источник';

  @override
  String get result => 'Результат';

  @override
  String get elapsed => 'Время';

  @override
  String get connectionStats => 'Статистика подключений';

  @override
  String get connectionStatsDesc => 'Подключения, запросы и DNS-запросы';

  @override
  String get memoryInfoDesc => 'Память приложения и ядра';

  @override
  String get editDashboard => 'Изменить панель';

  @override
  String get done => 'Готово';

  @override
  String get dashboardAddableSection => 'Можно добавить';

  @override
  String customImportDroppedSubRules(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Пользовательские профили не поддерживают подправила, поэтому отброшено $label правила SUB-RULE',
      many:
          'Пользовательские профили не поддерживают подправила, поэтому отброшено $label правил SUB-RULE',
      few:
          'Пользовательские профили не поддерживают подправила, поэтому отброшено $label правила SUB-RULE',
      one:
          'Пользовательские профили не поддерживают подправила, поэтому отброшено $label правило SUB-RULE',
    );
    return '$_temp0';
  }

  @override
  String get autoInclude => 'Автоматическое включение';

  @override
  String get allReferencedProxies => 'Все используемые прокси';

  @override
  String get allReferencedProxyProviders =>
      'Все используемые провайдеры прокси';

  @override
  String get clearDnsCache => 'Очистить кэш DNS';

  @override
  String get dnsCacheCleared => 'Кэш DNS очищен';

  @override
  String get clearDnsCacheFailed => 'Не удалось очистить кэш DNS';

  @override
  String get select => 'Выбрать';

  @override
  String get preferred => 'Предпочтительный';

  @override
  String get addToLocalProxies => 'Добавить в локальные прокси';

  @override
  String addedToLocalProxies(Object name) {
    return '«$name» добавлен в локальные прокси';
  }

  @override
  String alreadyInLocalProxies(Object name) {
    return '«$name» уже есть в локальных прокси';
  }

  @override
  String get mitm => 'MITM';

  @override
  String get httpsDecryption => 'Расшифровка HTTPS';

  @override
  String get httpCapture => 'Захват HTTP';

  @override
  String get httpCaptureDesc =>
      'Записывает запросы к хостам из списка имён хостов; их можно посмотреть в сведениях о соединении. Записи хранятся только в памяти.';

  @override
  String get httpCaptureNoHosts =>
      'Хосты не указаны, поэтому ничего не записывается. Добавьте их в поле «Имя хоста» на странице MITM или из сведений о соединении.';

  @override
  String get httpCaptureLimit => 'Максимум записей';

  @override
  String httpCaptureLimitDesc(Object memory, Object body) {
    return 'Когда записей станет столько или они займут $memory памяти, самые старые удаляются первыми. От каждого тела сохраняются первые $body.';
  }

  @override
  String get httpRequests => 'HTTP-запросы';

  @override
  String get httpRequestsMissing =>
      'Запросы, отправленные до включения захвата или уже удалённые, не показаны.';

  @override
  String get httpRequestCleared => 'Запись этого запроса удалена';

  @override
  String get httpCaptureOff => 'Захват выключен';

  @override
  String get inProgress => 'Выполняется';

  @override
  String get method => 'Метод';

  @override
  String get originalUrl => 'Исходный URL';

  @override
  String get timeToFirstByte => 'Время до первого байта';

  @override
  String get requestBody => 'Тело запроса';

  @override
  String get response => 'Ответ';

  @override
  String get responseBody => 'Тело ответа';

  @override
  String get responseHeaders => 'Заголовки ответа';

  @override
  String get matchedRules => 'Сработавшие правила';

  @override
  String get overview => 'Обзор';

  @override
  String get viewAll => 'Показать всё';

  @override
  String get copyAsBase64 => 'Копировать как Base64';

  @override
  String get copyAsCurl => 'Копировать как cURL';

  @override
  String get closeConnection => 'Закрыть соединение';

  @override
  String get copyHost => 'Копировать хост';

  @override
  String get copyDestination => 'Копировать адрес назначения';

  @override
  String get copyRequest => 'Копировать запрос';

  @override
  String get copyResponse => 'Копировать ответ';

  @override
  String get copyResponseBody => 'Копировать тело ответа';

  @override
  String get httpBodyProtobufGuess =>
      'Прочитано как Protobuf без схемы: только номера полей, типы предполагаемые.';

  @override
  String get exportHar => 'Экспорт HAR';

  @override
  String get mitmAddRejectRule => 'Добавить правило блокировки';

  @override
  String get mitmAddMapLocalRule => 'Добавить правило локальной подмены';

  @override
  String get httpExportPrivateTitle => 'Содержит личные данные';

  @override
  String get httpExportPrivate =>
      'Запрос может содержать cookie, токены, пароли и данные форм. Проверьте, что и кому вы передаёте.';

  @override
  String get mitmRuleCopiedForStash =>
      'Этот модуль — переопределение Stash, поэтому правило скопировано, добавьте его вручную.';

  @override
  String get binaryData => 'Двоичные данные';

  @override
  String get httpBodyNotKept => 'Не записано: не хватало памяти.';

  @override
  String get httpBodyTruncated => 'Записано только начало тела.';

  @override
  String httpBodyUndecoded(Object encoding) {
    return 'Не удалось декодировать $encoding, показаны данные в том виде, в каком они были переданы.';
  }

  @override
  String get mitmEnableTip =>
      'Flash сможет читать всё, что отправляется на расшифровываемые узлы, включая cookie и пароли. Включайте только для узлов, которые нужно перезаписывать.';

  @override
  String get certificate => 'Сертификат';

  @override
  String get generateCertificate => 'Создать сертификат';

  @override
  String get regenerateCertificate => 'Пересоздать сертификат';

  @override
  String get regenerateCertificateTip =>
      'Новый сертификат заменит текущий; Flash по возможности удалит текущий из доверенных корневых сертификатов этого устройства. На каждое другое устройство, доверяющее текущему, нужно установить новый.';

  @override
  String get exportCertificate => 'Экспортировать сертификат';

  @override
  String get installCertificate => 'Установить в систему';

  @override
  String get installCertificateSuccess => 'Сертификат установлен';

  @override
  String validUntil(Object date) {
    return 'Действителен до $date';
  }

  @override
  String get mitmCertificateExportTip =>
      'Экспортируйте его и добавьте в доверенные на устройствах, трафик которых нужно расшифровывать.';

  @override
  String get mitmTrustReady => 'Доверенный';

  @override
  String get mitmTrustUntrusted => 'Доверие неполное';

  @override
  String get mitmTrustNotInstalled => 'Не установлен';

  @override
  String get mitmTrustChecking => 'Проверка…';

  @override
  String get trustCertificate => 'Доверять сертификату';

  @override
  String get mitmCertificateAndroidReadyTip =>
      'Расшифровываются только приложения, доверяющие пользовательским сертификатам, в основном браузеры.';

  @override
  String get mitmCertificateLinuxTip =>
      'В браузеры из Flatpak экспортированный сертификат нужно импортировать вручную.';

  @override
  String mitmCertutilMissing(Object command) {
    return 'Chrome и Firefox используют собственные хранилища сертификатов, для которых нужен certutil: $command';
  }

  @override
  String mitmMissingStores(Object stores) {
    return 'Ещё не добавлен в: $stores';
  }

  @override
  String get mitmSystemStoreFailed =>
      'Не удалось добавить сертификат в доверенные корневые сертификаты системы';

  @override
  String get mitmRootUntilReboot =>
      'Не найден Magisk, KernelSU или APatch, чтобы сохранить сертификат. После перезагрузки устройства установите его снова.';

  @override
  String get mitmRootPendingReboot =>
      'Сертификат начнёт действовать после перезагрузки устройства.';

  @override
  String get mitmInstallSystemCaTip =>
      'Обнаружен root: сертификат будет добавлен в доверенные сертификаты системы как модуль Magisk, KernelSU или APatch «FlClash MITM CA». После этого ему будут доверять все приложения устройства, а любой, у кого есть его закрытый ключ, сможет расшифровать HTTPS-трафик устройства. Чтобы отменить это, создайте сертификат заново или удалите модуль в root-менеджере и перезагрузите устройство. Если в root отказано, сертификат будет установлен как пользовательский.';

  @override
  String get mitmInstallUserCaTip =>
      'Root не обнаружен: сертификат можно установить только как пользовательский. Расшифровываются только приложения, доверяющие пользовательским сертификатам, в основном браузеры; остальные не смогут подключиться к указанным узлам, поэтому не указывайте их узлы. Начиная с Android 11 установку нужно завершить вручную в настройках системы.';

  @override
  String mitmCertificateSavedTip(Object fileName) {
    return 'Файл $fileName сохранён в «Загрузки». Установите его в настройках: Безопасность › Шифрование и учётные данные › Установка сертификата › Сертификат ЦС.';
  }

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String mitmRemoveOldCertificateTip(Object name) {
    return 'Удалите старый сертификат $name в настройках: Безопасность › Шифрование и учётные данные › Надёжные учётные данные › Пользователь, затем установите новый.';
  }

  @override
  String mitmOldCertificateLeftTip(Object name) {
    return 'Не удалось удалить старый сертификат $name. Удалите его из доверенных корневых сертификатов вручную.';
  }

  @override
  String mitmOldSystemCertificateLeftTip(Object name) {
    return 'Старый сертификат $name всё ещё среди доверенных системных сертификатов. Разрешите Flash доступ root в менеджере root и создайте сертификат заново или удалите там модуль «FlClash MITM CA» и перезагрузите устройство.';
  }

  @override
  String get mitmDecryptHost => 'Расшифровывать этот хост';

  @override
  String mitmDecryptHostTip(Object host) {
    return 'Добавить $host в список имён хостов? Flash сможет читать всё, что на него отправляется, включая cookie и пароли.';
  }

  @override
  String get mitmExcludeHost => 'Исключить из расшифровки';

  @override
  String mitmExcludeHostTip(Object host) {
    return 'Добавить -$host в начало списка имён хостов? После этого узел никогда не будет расшифровываться.';
  }

  @override
  String get urlRewrite => 'Перезапись URL';

  @override
  String get headerRewrite => 'Перезапись заголовков';

  @override
  String get bodyRewrite => 'Перезапись тела';

  @override
  String get mapLocal => 'Локальная подмена';

  @override
  String get mitmHostnameDesc =>
      'Префикс - исключает хост; действует первое совпадение.';

  @override
  String get deleteCertificate => 'Удалить сертификат';

  @override
  String get deleteCertificateTip =>
      'Удаляет с этого Mac закрытый ключ сертификата, сам сертификат и доверие к нему. Расшифровка остановится, пока не будет создан и подтверждён новый сертификат.';

  @override
  String get mitmPausedCoreIdentity =>
      'Расшифровка приостановлена: проверка подлинности ядра не пройдена';

  @override
  String mitmIgnoredProfileHostnames(Object count) {
    return 'Пропущено из подписок или скриптов: $count';
  }

  @override
  String get mitmModules => 'Модули';

  @override
  String get mitmModule => 'Модуль';

  @override
  String get mitmModuleInvalid =>
      'Это не модуль Surge, не плагин Loon, не фрагмент Quantumult X и не переопределение Stash';

  @override
  String get arguments => 'Аргументы';

  @override
  String get mitmRoutingRules => 'Правила маршрутизации';

  @override
  String get mitmIgnoredLines => 'Пропущенные строки';

  @override
  String get mitmModuleRulesDesc =>
      'Правила маршрутизации идут перед правилами профиля.';

  @override
  String mitmModuleSystemTip(Object system) {
    return 'Написан для $system; некоторые строки могут не подходить к приложениям на этом устройстве.';
  }

  @override
  String mitmSkipSection(Object section) {
    return 'Раздел [$section] не поддерживается';
  }

  @override
  String get mitmSkipSetting => 'Этот параметр не поддерживается';

  @override
  String get mitmSkipScriptType => 'Этот тип скриптов не поддерживается';

  @override
  String get mitmSkipRule => 'Этот тип правила не поддерживается';

  @override
  String get mitmSkipPolicy => 'Поддерживаются только политики DIRECT и REJECT';

  @override
  String get mitmSkipJq => 'Перезаписи jq не поддерживаются';

  @override
  String get mitmSkipJsonBody => 'Перезаписи тела JSON не поддерживаются';

  @override
  String get mitmSkipRawHeader =>
      'Перезапись всех заголовков как одного текста не поддерживается';

  @override
  String get mitmSkipConditional => 'Условные перезаписи не поддерживаются';

  @override
  String get mitmSkipRelativeData =>
      'Файл из этой строки не прикреплён; укажите URL или прикрепите его';

  @override
  String get mitmSkipNotDownloaded => 'Его файл ещё не загружен';

  @override
  String get mitmSkipUnreadable => 'Эту строку не удалось прочитать';

  @override
  String get mitmAddLocalFile => 'Добавить локальный файл';

  @override
  String get mitmNewModule => 'Новый модуль';

  @override
  String get mitmAttachments => 'Вложения';

  @override
  String get mitmAttachmentsDesc =>
      'Строки ссылаются на вложения по имени файла, например script-path=a.js.';

  @override
  String mitmFileTooLarge(Object size) {
    return 'Файл больше $size МБ';
  }

  @override
  String get mitmSkipDisabled => 'Отключено аргументом';

  @override
  String get mitmSkipEvent => 'Это событие не поддерживается';

  @override
  String get mitmRunScript => 'Запустить сейчас';

  @override
  String get mitmScriptNoOutput => 'Скрипт завершился без вывода';

  @override
  String get mitmScriptRiskTitle => 'Запускать скрипты этого модуля?';

  @override
  String get mitmScriptRisk =>
      'Его скрипты читают и меняют трафик подходящих хостов, включая файлы cookie и токены, и могут сами отправлять запросы. Включайте, только если доверяете источнику.';

  @override
  String mitmModuleScriptsChanged(Object name) {
    return 'Скрипты модуля $name изменились, модуль выключен';
  }

  @override
  String get skipServerCertVerify => 'Пропускать проверку сертификата сервера';

  @override
  String get blockQuic => 'Блокировать QUIC';

  @override
  String get http2 => 'HTTP/2';

  @override
  String get decryptUntrusted => 'Расшифровывать без локального доверия';

  @override
  String invalidOfCount(Object invalid, Object total) {
    return 'Недействительно: $invalid из $total';
  }

  @override
  String get batchLineInputTip => 'По одному элементу в строке';

  @override
  String get downloadingUpdate => 'Загрузка обновления';

  @override
  String get updateFailed => 'Не удалось обновить';

  @override
  String get updateDownloadTest => 'Тест загрузки обновления';

  @override
  String get liveStatusTest => 'Тест карточек текущего состояния';

  @override
  String get updateDownloadStarted =>
      'Загрузка обновления началась. Следите за ходом на главной странице.';

  @override
  String get updateReady => 'Обновление готово';

  @override
  String get updateReadyTip =>
      'Обновление загружено. Нажмите, чтобы установить.';

  @override
  String get stopUpdateDownloadTip => 'Остановить загрузку обновления?';

  @override
  String get forceRestartCoreAsk => 'Принудительно перезапустить ядро?';

  @override
  String get forceRestartCoreAskDesc => 'Текущие соединения будут разорваны';

  @override
  String get stopUpdateDownloadDesc => 'Уже загруженная часть будет удалена';

  @override
  String get stopDownload => 'Стоп';

  @override
  String get updateInstallFailed =>
      'Не удалось установить обновление. Его можно скачать на странице релиза.';

  @override
  String get updateNotVerified =>
      'Не удалось проверить загруженное обновление.';

  @override
  String get updateRestartTip =>
      'Flash закроется для установки обновления и снова откроется после завершения.';

  @override
  String get updateDownloadFailed => 'Не удалось загрузить обновление.';

  @override
  String get defaultNameserverDesc =>
      'Разрешает имена других DNS-серверов. Только IP-адреса.';

  @override
  String get nameserverDesc =>
      'DNS-серверы по умолчанию, например 223.5.5.5, tls://1.1.1.1 или https://dns.google/dns-query.';

  @override
  String get fallbackDesc =>
      'Используются вместо Nameserver, когда фильтр fallback считает его ответ подменённым.';

  @override
  String get proxyServerNameserverDesc =>
      'Используется только для разрешения имён прокси-серверов.';

  @override
  String get proxyServerNameserverPolicyDesc =>
      'Совпавшие имена прокси-серверов используют указанный здесь DNS-сервер вместо Proxy Server Nameserver.';

  @override
  String get directNameserverDesc => 'Разрешает домены прямых соединений.';

  @override
  String get nameserverPolicyDesc =>
      'Совпавшие домены используют указанный здесь DNS-сервер вместо Nameserver и Fallback.';

  @override
  String get fakeipFilterDesc =>
      'Эти домены получают реальные IP вместо Fake-IP. В режиме whitelist Fake-IP получают только они.';

  @override
  String get fallbackFilterGeositeDesc =>
      'Домены из этих категорий GeoSite сразу разрешаются через Fallback.';

  @override
  String get fallbackFilterIpcidrDesc =>
      'Если Nameserver возвращает IP из этих диапазонов, используется ответ Fallback.';

  @override
  String get fallbackFilterDomainDesc =>
      'Эти домены сразу разрешаются через Fallback.';

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
  String get macHelperTitle => 'Помощник Flash';

  @override
  String get macHelperOn => 'Помощник готов';

  @override
  String get macHelperOpenSettings => 'Открыть настройки macOS';

  @override
  String get macHelperTryAgain => 'Повторить';

  @override
  String get macHelperCheckAgain => 'Проверить снова';

  @override
  String get macHelperUnavailableDetail =>
      'Сейчас Flash не может подключиться к помощнику, поэтому TUN не запускается. Настройка TUN сохранена.';

  @override
  String get trayMultipleNodes => 'Несколько узлов';

  @override
  String get trayNoAvailableMembers => 'Нет доступных участников';

  @override
  String get trayCouldNotLoad => 'Не удалось загрузить';

  @override
  String get trayCouldNotSwitch => 'Не удалось переключить';

  @override
  String get traySwitchUnconfirmed => 'Не удалось подтвердить переключение';

  @override
  String get traySelectionUnknown => 'Текущий выбор неизвестен';

  @override
  String trayCurrentSelection(Object name) {
    return 'Текущий выбор: $name';
  }

  @override
  String get trayLatencyUnknown => 'Задержка неизвестна';

  @override
  String get trayTesting => 'Проверка';

  @override
  String trayLatencyMilliseconds(Object value) {
    return 'Задержка: $value мс';
  }

  @override
  String get trayLatencyLessThanOne => 'Задержка менее 1 миллисекунды';

  @override
  String traySwitchingTo(Object name) {
    return 'Переключение на $name';
  }

  @override
  String get traySelected => 'Выбрано';

  @override
  String get trayTestLatency => 'Проверить задержку';

  @override
  String get trayReject => 'Отклонить';

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
  String get macHelperChecking => 'Проверка помощника…';

  @override
  String get macHelperUpdating => 'Обновление помощника…';

  @override
  String get macHelperMoveDetail =>
      'Переместите Flash в папку «Программы» и откройте снова для установки помощника.';

  @override
  String get macHelperApprovalDetail =>
      'Разрешите помощник Flash в Системных настройках macOS, затем вернитесь и проверьте снова.';

  @override
  String get macHelperMoveTitle => 'Переместите Flash в «Программы»';

  @override
  String get macHelperStatusUnknown =>
      'Не удалось подтвердить состояние помощника';

  @override
  String get macHelperCoreUnconfirmed => 'Состояние ядра не подтверждено';

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
      'Turn on the switch next to Flash, then come back to Flash.';

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
  String get macHelperDisabledTitle => 'The helper is turned off';

  @override
  String get macHelperDisabledDetail =>
      'In System Settings, go to Login Items & Extensions, turn on Flash’s background switch, then come back to Flash.';

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
    return 'Версия $version';
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
  String get liveStatus => 'Текущее состояние';

  @override
  String get coreStopped => 'Ядро остановлено';

  @override
  String get coreStoppedDesc => 'Приложение потеряло связь с ядром';

  @override
  String get restartCore => 'Перезапустить ядро';

  @override
  String get installUpdate => 'Установить обновление';

  @override
  String liveStatusPosition(Object index, Object count) {
    return '$index из $count';
  }

  @override
  String get coreStarting => 'Запуск ядра';

  @override
  String get coreStartingDesc => 'Подключение к ядру';

  @override
  String get coreRunning => 'Ядро работает';

  @override
  String get coreRunningDesc => 'Приложение подключено к ядру';

  @override
  String get forceRestartCore => 'Принудительный перезапуск';

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
  String get rulesSearchLabel => 'Search rules or URLs';

  @override
  String rulesLookupSuggestion(Object host) {
    return 'Look up which rule $host takes';
  }

  @override
  String rulesLookupSuggestionLabel(Object host) {
    return 'Look up which rule $host takes';
  }

  @override
  String rulesFilterOnly(Object count) {
    return 'Only filter rules by text · $count';
  }

  @override
  String get rulesQuerying => 'Looking up';

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
  String get hitCardTitleUncertain => 'The result may differ';

  @override
  String hitCardPosition(Object index) {
    return 'Matches rule #$index';
  }

  @override
  String get hitGoes => 'Goes';

  @override
  String get hitFallback => 'No earlier rule matches, so the last rule applies';

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
  String get uncertainProcess =>
      'An earlier rule depends on the app making the request. The actual result may change with the app.';

  @override
  String get uncertainPort =>
      'An earlier rule depends on the port. The actual result may change with the port.';

  @override
  String get uncertainIp =>
      'An earlier rule depends on the IP, which could not be resolved, so whether it matches first is unknown.';

  @override
  String get uncertainOther =>
      'Earlier rules need more about the connection, so the actual result may differ.';

  @override
  String get goUpdate => 'Update';

  @override
  String get lookupResolveFailed =>
      'The IP could not be resolved. Whether rules by IP match is unknown.';

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
  String ruleSetMissingNotice(Object name) {
    return 'Rule set “$name” is not downloaded yet, so the result may be incomplete.';
  }

  @override
  String ruleSetFailedNotice(Object name) {
    return 'Rule set “$name” failed to download, so the result may be incomplete.';
  }

  @override
  String ruleSetExpiredNotice(Object name) {
    return 'Rule set “$name” has expired, so the result may be incomplete.';
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
  String get mitmOutcomeRefused =>
      'Клиент отправил предупреждение (alert) во время рукопожатия. Причина неизвестна.';

  @override
  String get mitmOutcomeUpstreamCertificate =>
      'Не удалось проверить сертификат сайта';

  @override
  String get mitmOutcomeHTTP1Unsupported => 'HTTP/1.1 не поддерживается';

  @override
  String get mitmOutcomeHelloPassthrough =>
      'TLS не проверен; соединение передано без расшифровки';

  @override
  String get mitmOutcomeFailed => 'Ошибка расшифрованного соединения';

  @override
  String get mitmPausedLiveness =>
      'Расшифровка приостановлена: не удалось проверить доверие или подпись. Обычно изменения обнаруживаются примерно за 26 секунд; сон или задержки системы могут увеличить время.';

  @override
  String get mitmPausedIndicatorPending =>
      'Расшифровка приостановлена: обязательный постоянный индикатор недоступен.';

  @override
  String get mitmPausedUnavailable =>
      'Расшифровка приостановлена: подписывающий компонент или соединение недоступно.';

  @override
  String get mitmIndicatorDecrypting => 'Идёт расшифровка';

  @override
  String get mitmIndicatorOn => 'Расшифровка включена';

  @override
  String get mitmIndicatorPaused => 'Расшифровка приостановлена';

  @override
  String get mitmIndicatorUnconfirmed => 'Проверка состояния расшифровки';

  @override
  String mitmIndicatorPausedBecause(String reason) {
    return 'Расшифровка приостановлена: $reason';
  }

  @override
  String get mitmIndicatorOpenSettings => 'Открыть настройки MITM';

  @override
  String get mitmPauseCoreStopped => 'ядро не запущено';

  @override
  String get mitmPauseCoreIdentity => 'проверка подлинности ядра не пройдена';

  @override
  String get mitmPauseNotTrusted =>
      'корневой сертификат отсутствует или не доверен';

  @override
  String get mitmPauseLiveness =>
      'не удалось проверить состояние доверия и подписи';

  @override
  String get mitmPauseIndicatorPending =>
      'постоянный индикатор состояния не включён';

  @override
  String get mitmPauseUnavailable => 'служба подписи или соединение недоступны';

  @override
  String get mitmOutcomePaused =>
      'Расшифровка приостановлена; соединение пропущено без изменений';

  @override
  String get mitmBadgeDecrypted => 'Расшифровано';

  @override
  String get mitmBadgePassedThrough => 'Не расшифровано · пропущено';

  @override
  String get mitmBadgePassedThroughSpoken => 'Не расшифровано, пропущено';

  @override
  String get mitmBadgeHandshakeFailed => 'Сбой рукопожатия клиента';

  @override
  String get mitmBadgeFailed => 'Ошибка расшифровки';

  @override
  String get mitmExchangeNoResponse => 'Ответ не получен';

  @override
  String get mitmExchangeResponseFailed => 'Ответ прерван';

  @override
  String get mitmExchangeStopped =>
      'Запрос остановлен: изменены настройки расшифровки';

  @override
  String get mitmExchangeFailed => 'Запрос не завершён';
}
