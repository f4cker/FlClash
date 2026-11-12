// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ru locale. All the
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
  String get localeName => 'ru';

  static String m0(count) => "Выбрано: ${count}";

  static String m1(name) => "«${name}» добавлен в локальные прокси";

  static String m2(name) => "«${name}» уже есть в локальных прокси";

  static String m3(count, skipped) =>
      "Будет добавлено: ${count}, пропущено (уже есть): ${skipped}";

  static String m4(detail) => "Не удалось очистить данные: ${detail}";

  static String m5(code) =>
      "Windows отказалась запускать FlClashCore.exe (ошибка ${code}). Политики контроля приложений, такие как Smart App Control или AppLocker, блокируют неподписанные программы; разрешите Flash в этой политике или отключите её и повторите попытку.";

  static String m6(name) =>
      "Приложение два раза подряд не смогло завершить запуск. Чтобы разорвать цикл, профиль ${name} снят с выбора, а автоматическая настройка пропущена. Вы можете выбрать его снова в любой момент.";

  static String m7(url) => "Создать профиль по ссылке ${url}?";

  static String m8(count, label) =>
      "${Intl.plural(count, one: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правило SUB-RULE', few: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правила SUB-RULE', many: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правил SUB-RULE', other: 'Пользовательские профили не поддерживают подправила, поэтому отброшено ${label} правила SUB-RULE')}";

  static String m9(message) =>
      "Ядро не может разобрать этот прокси: ${message}";

  static String m10(proxy, target) =>
      "${proxy} подключается через ${target}, а ${target} снова ведёт к ${proxy}, поэтому подключение зацикливается";

  static String m11(name) =>
      "Имя ${name} уже занято другим прокси или группой прокси";

  static String m12(path) =>
      "Группы прокси ссылаются друг на друга по кругу: ${path}";

  static String m13(name) =>
      "Резервом для пустой группы может быть только прокси, а ${name} не существует или является группой прокси";

  static String m14(name, message) =>
      "${name}: недопустимое регулярное выражение: ${message}";

  static String m15(name) => "Прокси для подключения ${name} не существует";

  static String m16(names) => "Эти провайдеры прокси не существуют: ${names}";

  static String m17(names) => "Эти прокси или политики не существуют: ${names}";

  static String m18(name) =>
      "${name} — встроенное имя политики, его нельзя использовать";

  static String m19(count) =>
      "Проблем: ${count}, применение профиля может завершиться ошибкой";

  static String m20(count) =>
      "${Intl.plural(count, one: '${count} день назад', few: '${count} дня назад', many: '${count} дней назад', other: '${count} дня назад')}";

  static String m21(count) => "${count} дн. назад";

  static String m22(label) =>
      "Вы уверены, что хотите удалить выбранные элементы (${label})?";

  static String m23(label) => "Вы уверены, что хотите удалить «${label}»?";

  static String m24(label) => "Сведения: ${label}";

  static String m25(name) =>
      "Подключение через ${name} ведёт обратно к прокси, который его использует, поэтому соединение остановлено";

  static String m26(label) => "Поле «${label}» не может быть пустым";

  static String m27(label) => "«${label}» уже существует";

  static String m28(count) => "Ошибок: ${count}. Нажмите, чтобы посмотреть";

  static String m29(label, message) => "${label}: ${message}";

  static String m30(name) => "${name}: уже последняя версия";

  static String m31(name) => "${name}: обновлено";

  static String m32(count) => "Групп: ${count}";

  static String m33(count) => "Тайм-аут: ${count}";

  static String m34(name) => "${name}, Скрытая";

  static String m35(action) =>
      "Уже используется для «${action}». При сохранении будет перенесено сюда.";

  static String m36(modifiers) =>
      "Добавьте хотя бы одну из клавиш: ${modifiers}";

  static String m37(count) =>
      "${Intl.plural(count, one: '${count} час назад', few: '${count} часа назад', many: '${count} часов назад', other: '${count} часа назад')}";

  static String m38(count) => "${count} ч назад";

  static String m39(encoding) =>
      "Не удалось декодировать ${encoding}, показаны данные в том виде, в каком они были переданы.";

  static String m40(memory, body) =>
      "Когда записей станет столько или они займут ${memory} памяти, самые старые удаляются первыми. От каждого тела сохраняются первые ${body}.";

  static String m41(invalid, total) =>
      "Недействительно: ${invalid} из ${total}";

  static String m42(target) => "${target} — недопустимая политика";

  static String m43(proxyName) => "${proxyName} — недопустимый прокси";

  static String m44(providerName) =>
      "${providerName} — недопустимый провайдер прокси";

  static String m45(ruleSet) => "${ruleSet} — недопустимый набор правил";

  static String m46(subRule) => "${subRule} — недопустимый SUB_RULE";

  static String m47(count) =>
      "${Intl.plural(count, one: '${count} элемент', few: '${count} элемента', many: '${count} элементов', other: '${count} элемента')}";

  static String m48(line, message) => "Строка ${line}: ${message}";

  static String m49(appName) =>
      "1. Откройте Системные настройки > Конфиденциальность и безопасность\n2. Выберите Службы геолокации\n3. Найдите и отметьте ${appName} в списке\n\nПосле настройки вернитесь в приложение и продолжайте работу. Спасибо за сотрудничество.";

  static String m50(label, max) => "«${label}» — не более ${max} символов";

  static String m51(size) => "Освобождено ${size}";

  static String m52(count) =>
      "${Intl.plural(count, one: '${count} минуту назад', few: '${count} минуты назад', many: '${count} минут назад', other: '${count} минуты назад')}";

  static String m53(count) => "${count} мин назад";

  static String m54(fileName) =>
      "Файл ${fileName} сохранён в «Загрузки». Установите его в настройках: Безопасность › Шифрование и учётные данные › Установка сертификата › Сертификат ЦС.";

  static String m55(command) =>
      "Chrome и Firefox используют собственные хранилища сертификатов, для которых нужен certutil: ${command}";

  static String m56(host) =>
      "Добавить ${host} в список имён хостов? Flash сможет читать всё, что на него отправляется, включая cookie и пароли.";

  static String m57(host) =>
      "Добавить -${host} в начало списка имён хостов? После этого узел никогда не будет расшифровываться.";

  static String m58(size) => "Файл больше ${size} МБ";

  static String m59(stores) => "Ещё не добавлен в: ${stores}";

  static String m60(name) =>
      "Скрипты модуля ${name} изменились, модуль выключен";

  static String m61(system) =>
      "Написан для ${system}; некоторые строки могут не подходить к приложениям на этом устройстве.";

  static String m62(name) =>
      "Не удалось удалить старый сертификат ${name}. Удалите его из доверенных корневых сертификатов вручную.";

  static String m63(name) =>
      "Старый сертификат ${name} всё ещё среди доверенных системных сертификатов. Разрешите Flash доступ root в менеджере root и создайте сертификат заново или удалите там модуль «FlClash MITM CA» и перезагрузите устройство.";

  static String m64(name) =>
      "Удалите старый сертификат ${name} в настройках: Безопасность › Шифрование и учётные данные › Надёжные учётные данные › Пользователь, затем установите новый.";

  static String m65(section) => "Раздел [${section}] не поддерживается";

  static String m66(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start.";

  static String m67(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start. System proxy settings were not changed.";

  static String m68(count) =>
      "${Intl.plural(count, one: '${count} месяц назад', few: '${count} месяца назад', many: '${count} месяцев назад', other: '${count} месяца назад')}";

  static String m69(count) => "${count} мес. назад";

  static String m70(count) =>
      "This save also mounts ${Intl.plural(count, one: '1 subscription', other: '${count} subscriptions')}.";

  static String m71(target) =>
      "Empty-group handling comes from the original profile: ${target}.";

  static String m72(count) =>
      "${Intl.plural(count, one: '1 subscription update failed', other: '${count} subscription updates failed')}";

  static String m73(subscriptionName, profileCount) =>
      "“${subscriptionName}” is mounted on the following ${Intl.plural(profileCount, one: '1 profile', other: '${profileCount} profiles')}. Deleting it removes its nodes from those profiles and may interrupt connections. Other subscriptions, base profile files, and Tailscale sign-ins will not be deleted.";

  static String m74(group) =>
      "Group “${group}” has no selectable nodes. Check the subscriptions and group filters.";

  static String m75(count) =>
      "${Intl.plural(count, one: '1 mounted node', other: '${count} mounted nodes')}";

  static String m76(count) =>
      "${Intl.plural(count, one: '1 group', other: '${count} groups')}";

  static String m77(count) =>
      "To keep Tailscale routing separate, ${Intl.plural(count, one: '1 group does not accept subscription nodes.', other: '${count} groups do not accept subscription nodes.')}";

  static String m78(groups) => "Groups: ${groups}.";

  static String m79(count) =>
      "${Intl.plural(count, one: '1 group excludes subscription nodes', other: '${count} groups exclude subscription nodes')}";

  static String m80(count) =>
      "${Intl.plural(count, one: '1 hidden group is empty and rejects connections.', other: '${count} hidden groups are empty and reject connections.')}";

  static String m81(count) =>
      "${Intl.plural(count, one: '1 hidden group', other: '${count} hidden groups')}";

  static String m82(count) =>
      "${Intl.plural(count, one: '1 hidden group has no matching mounted node.', other: '${count} hidden groups have no matching mounted node.')}";

  static String m83(count) =>
      "${Intl.plural(count, one: '1 group has no match', other: '${count} groups have no match')}";

  static String m84(time) => "Last updated: ${time}";

  static String m85(count) =>
      "${Intl.plural(count, one: '1 node', other: '${count} nodes')}";

  static String m86(count) =>
      "${Intl.plural(count, one: '1 node excluded from mounting', other: '${count} nodes excluded from mounting')}";

  static String m87(count) =>
      "${Intl.plural(count, one: '1 node read', other: '${count} nodes read')}";

  static String m88(time) => "Nodes read: ${time}";

  static String m89(label, profileName) =>
      "${label}, target profile ${profileName}";

  static String m90(name) =>
      "New content for “${name}” was read but did not pass the mount-isolation checks and was not applied. The previously confirmed content is still in use.";

  static String m91(name) =>
      "New content for “${name}” was read but did not pass the mount-isolation checks and was not applied. Its current use is unconfirmed. Read the status again.";

  static String m92(count) => "Show all ${count} groups";

  static String m93(profileName) => "Target profile: ${profileName}";

  static String m94(subscriptionName, profileName) =>
      "This removes nodes from “${subscriptionName}” from “${profileName}”. Connections using those nodes may be interrupted. The subscription, original profile file, and other mounts are not deleted. Dedicated Tailscale routing stays unchanged.";

  static String m95(count, profileName) =>
      "This removes nodes provided by the following ${Intl.plural(count, one: '1 subscription', other: '${count} subscriptions')} from “${profileName}”. Connections using those nodes may be interrupted. The subscriptions, original profile file, and other mounts are not deleted. Dedicated Tailscale routing stays unchanged.";

  static String m96(count) =>
      "To keep Tailscale routing separate, ${Intl.plural(count, one: '1 subscription node that is not supported for mounting was excluded. Its settings were not changed.', other: '${count} subscription nodes that are not supported for mounting were excluded. Their settings were not changed.')}";

  static String m97(name) => "Update nodes of ${name}";

  static String m98(name) => "Mount: ${name} · node list not yet confirmed";

  static String m99(name, count) =>
      "Mount: ${name} · ${Intl.plural(count, one: '1 node', other: '${count} nodes')}";

  static String m100(count) =>
      "${Intl.plural(count, one: '1 subscription mounted', other: '${count} subscriptions mounted')}";

  static String m101(code) =>
      "Сервер запретил доступ (HTTP ${code}). Возможно, ссылка устарела или учётные данные неверны";

  static String m102(code) => "Сервер отклонил запрос (HTTP ${code})";

  static String m103(code) =>
      "По этому адресу ничего не найдено (HTTP ${code}). Проверьте правильность URL";

  static String m104(detail) => "Сетевой запрос не выполнен: ${detail}";

  static String m105(code) =>
      "На сервере произошла ошибка (HTTP ${code}). Повторите попытку позже";

  static String m106(label) => "Пока нет: ${label}";

  static String m107(label, min, max) =>
      "Значение «${label}» должно быть от ${min} до ${max}";

  static String m108(label) => "Значение «${label}» должно быть числом";

  static String m109(label) =>
      "Значение «${label}» должно быть от 1024 до 49151";

  static String m110(port) => "Порт ${port}";

  static String m111(days) => "Осталось дней: ${days}";

  static String m112(date, days) => "Истекает ${date}, осталось дней: ${days}";

  static String m113(time) => "Обновлено ${time}";

  static String m114(label, profiles) =>
      "«${label}» всё ещё используется профилями: ${profiles}. После удаления они будут работать неправильно. Вы уверены, что хотите удалить его?";

  static String m115(count, label) =>
      "${Intl.plural(count, other: '${label} прокси')}";

  static String m116(name, count) => "${name} и другие (${count} прокси)";

  static String m117(removed) =>
      "Будут удалены прокси: ${removed}. Строка с изменённым именем считается новым прокси, а пользовательские профили, ссылающиеся на удалённые, пометят их как отсутствующие. Применить?";

  static String m118(removed, added) =>
      "Будут удалены прокси: ${removed}. Будут добавлены: ${added}. Строка с изменённым именем считается новым прокси, а пользовательские профили, ссылающиеся на удалённые, пометят их как отсутствующие. Применить?";

  static String m119(label) =>
      "На «${label}» всё ещё ссылаются правила, группы прокси, прокси для подключения, DNS или NTP этого профиля, и после удаления эти ссылки перестанут работать. Вы уверены, что хотите удалить её?";

  static String m120(count, label) =>
      "${Intl.plural(count, one: '${label} группа прокси', few: '${label} группы прокси', many: '${label} групп прокси', other: '${label} группы прокси')}";

  static String m121(count, label) =>
      "${Intl.plural(count, one: '${label} правило', few: '${label} правила', many: '${label} правил', other: '${label} правила')}";

  static String m122(appName) => "${appName} (Безопасный режим)";

  static String m123(count) =>
      "${Intl.plural(count, one: '${count} секунда', few: '${count} секунды', many: '${count} секунд', other: '${count} секунды')}";

  static String m124(count) => "Действуют: ${count}";

  static String m125(count) => "Проблем: ${count}";

  static String m126(count) =>
      "${Intl.plural(count, one: '${count} настройка', few: '${count} настройки', many: '${count} настроек', other: '${count} настройки')}";

  static String m127(link) => "Не удалось прочитать прокси из ${link}";

  static String m128(label) => "«${label}» — только одно значение";

  static String m129(value) => "Пик ${value}";

  static String m130(value) => "Всего ${value}";

  static String m131(transport) => "Заголовки ${transport}";

  static String m132(account) => "Assigned: ${account}";

  static String m133(account, network) => "${account} · ${network}";

  static String m134(count) => "Choose accounts for ${count} targets";

  static String m135(count) =>
      "This profile has ${count} panel-added Tailscale accounts. Deleting it removes their profile bindings, target assignments, and dedicated routing and blocking rules. Local sign-in archives are kept. Devices in the Tailscale admin console are not deleted. Other profiles are not affected.";

  static String m136(count) =>
      "${Intl.plural(count, one: '1 device · Only devices visible to this account', other: '${count} devices · Only devices visible to this account')}";

  static String m137(shown, total) =>
      "Showing ${shown}/${total} · Devices visible to this account only";

  static String m138(shown, total) => "Showing ${shown} / ${total}";

  static String m139(n) => "Showing ${n} devices";

  static String m140(node, device) =>
      "Sets the exit node of “${node}” to “${device}”. Connections through this node may drop; Flash rules stay the same.";

  static String m141(node) =>
      "Only turns off exit forwarding for “${node}”; it doesn\'t log out of Tailscale and Flash rules stay the same.";

  static String m142(time) =>
      "Authentication expires at ${time}. Log in again before then.";

  static String m143(account) => "Account: ${account}";

  static String m144(server) => "Control server: ${server}";

  static String m145(name) => "Node: ${name}";

  static String m146(name) => "Profile: ${name}";

  static String m147(name) =>
      "This logs out of “${name}” and clears the login identity this Mac keeps for it. Connections through this node may drop; other nodes are not affected.";

  static String m148(name) => "Network: ${name}";

  static String m149(name) => "Node ${name}";

  static String m150(account, node, profile) =>
      "This signs out “${account}” (node “${node}”), clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m151(node, profile) =>
      "This signs out “${node}”, clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m152(count) => "Device addresses: ${count}";

  static String m153(domain) => "Network domain: ${domain}";

  static String m154(count, domain) =>
      "${Intl.plural(count, one: '${domain} · 1 device address', other: '${domain} · ${count} device addresses')}";

  static String m155(value) => "Saved: ${value}";

  static String m156(name) => "Shared by: ${name}";

  static String m157(account, node) =>
      "This signs out “${account}” (node “${node}”) and clears its sign-in from this Mac. Its panel entry and target assignments stay saved. Connections through this account may be interrupted and will not switch to another account or a direct connection. Other accounts will not be signed out. You must choose Sign in to use this account again.";

  static String m158(label) => "Status: ${label}";

  static String m159(account, status, count) =>
      "Viewing Tailscale account: ${account}, ${status}. ${count} entries.";

  static String m160(address) => "Address: ${address}";

  static String m161(domain) => "Domain: ${domain}";

  static String m162(label) => "Значение «${label}» должно быть URL";

  static String m163(date) => "Действителен до ${date}";

  static String m164(count) =>
      "${Intl.plural(count, one: '${count} год назад', few: '${count} года назад', many: '${count} лет назад', other: '${count} года назад')}";

  static String m165(count) =>
      "${Intl.plural(count, one: '${count} г. назад', few: '${count} г. назад', many: '${count} л. назад', other: '${count} г. назад')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("О программе"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Контроль доступа"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Через VPN проходят только выбранные приложения",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений отключён",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Выбранные приложения исключаются из VPN",
    ),
    "accessControlSelectedCount": m0,
    "account": MessageLookupByLibrary.simpleMessage("Аккаунт"),
    "action": MessageLookupByLibrary.simpleMessage("Действие"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Проверить все задержки",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Прямой режим"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage(
      "Глобальный режим",
    ),
    "actionMode": MessageLookupByLibrary.simpleMessage("Переключить режим"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Режим правил"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Старт/Стоп"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Обновить профили",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Показать/Скрыть"),
    "add": MessageLookupByLibrary.simpleMessage("Добавить"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Добавить прокси"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Добавить фильтры"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Добавить узлы"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Добавить параметр",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Добавить профиль"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Добавить группу прокси",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Добавить правило"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage(
      "Добавить параметр",
    ),
    "addSsid": MessageLookupByLibrary.simpleMessage("Добавить SSID"),
    "addToLocalProxies": MessageLookupByLibrary.simpleMessage(
      "Добавить в локальные прокси",
    ),
    "addedRules": MessageLookupByLibrary.simpleMessage("Добавленные правила"),
    "addedToLocalProxies": m1,
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Дополнительные параметры",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("Префикс имени"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("Суффикс имени"),
    "address": MessageLookupByLibrary.simpleMessage("Адрес"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Введите корректный адрес WebDAV",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Расширенная конфигурация",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Зашифрованный профиль",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("Секретный ключ age"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "Профиль зашифрован с помощью age, для расшифровки нужен секретный ключ age",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Согласен"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "Все используемые прокси",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Все используемые провайдеры прокси",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Разрешить приложениям обходить VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Разрешить LAN"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("Разрешённые IP"),
    "alreadyInLocalProxies": m2,
    "answers": MessageLookupByLibrary.simpleMessage("Ответы"),
    "app": MessageLookupByLibrary.simpleMessage("Приложение"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Контроль доступа приложений",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage(
      "Дизайн значка приложения",
    ),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "Нет локальных прокси",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Добавлять системный DNS",
    ),
    "applied": MessageLookupByLibrary.simpleMessage("Применено"),
    "applyNow": MessageLookupByLibrary.simpleMessage("Применить сейчас"),
    "arguments": MessageLookupByLibrary.simpleMessage("Аргументы"),
    "authentication": MessageLookupByLibrary.simpleMessage("Аутентификация"),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Пока включена аутентификация, системный прокси не применяется.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Разрешить"),
    "authorized": MessageLookupByLibrary.simpleMessage("Разрешено"),
    "auto": MessageLookupByLibrary.simpleMessage("Авто"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Автопроверка обновлений",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Автозакрытие соединений",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage(
      "Автоматическое включение",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Автозапуск"),
    "autoRun": MessageLookupByLibrary.simpleMessage("Автовключение"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Автовключение запускает прокси при открытии приложения.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Автонастройка системного DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Автообновление"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Назад"),
    "backgroundBlur": MessageLookupByLibrary.simpleMessage("Размытие фона"),
    "backup": MessageLookupByLibrary.simpleMessage("Резервное копирование"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Резервное копирование и восстановление",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "Резервная копия создана более новой версией приложения. Обновите приложение перед восстановлением",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Резервная копия создана",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Основная информация"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Базовые политики"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Массовый импорт"),
    "batchLineInputTip": MessageLookupByLibrary.simpleMessage(
      "По одному элементу в строке",
    ),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "По одной ссылке на строку",
    ),
    "batchPreviewTip": m3,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "По одному URL на строку",
    ),
    "binaryData": MessageLookupByLibrary.simpleMessage("Двоичные данные"),
    "bind": MessageLookupByLibrary.simpleMessage("Привязать"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage(
      "Режим чёрного списка",
    ),
    "blockQuic": MessageLookupByLibrary.simpleMessage("Блокировать QUIC"),
    "bodyRewrite": MessageLookupByLibrary.simpleMessage("Перезапись тела"),
    "brightness": MessageLookupByLibrary.simpleMessage("Яркость"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Исключённые домены"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Исключённые домены действуют только при включённом системном прокси.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Обходить частные адреса",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Кэш"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage("Алгоритм кэша"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Кэш повреждён. Очистить его?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Размер кэша"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешите доступ к камере в системных настройках, чтобы сканировать QR-коды, или выберите изображение QR-кода из галереи.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется доступ к камере",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Камера недоступна",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Отмена"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage("Снять выделение"),
    "cannotSave": MessageLookupByLibrary.simpleMessage("Не удалось сохранить"),
    "certificate": MessageLookupByLibrary.simpleMessage("Сертификат"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Не удалось переключить прокси; восстановлен предыдущий выбор",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Важные изменения",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Новые функции"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Исправления"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage(
      "Производительность",
    ),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Откаты"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Проверять TLS-сертификаты",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Без проверки TLS-сертификатов подписки и резервные копии уязвимы для атаки «человек посередине».",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Проверить обновления"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "У вас уже последняя версия",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Шифр"),
    "clearData": MessageLookupByLibrary.simpleMessage("Очистить данные"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "Все профили, настройки и локальные данные будут удалены, после чего приложение закроется. Откройте его снова, чтобы начать заново.",
    ),
    "clearDataFailed": m4,
    "clearDnsCache": MessageLookupByLibrary.simpleMessage("Очистить кэш DNS"),
    "clearDnsCacheFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось очистить кэш DNS",
    ),
    "clearSearch": MessageLookupByLibrary.simpleMessage("Очистить поиск"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Отпечаток клиента",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Экспорт в буфер обмена",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Импорт из буфера обмена",
    ),
    "clipboardNoPackageNames": MessageLookupByLibrary.simpleMessage(
      "В буфере обмена нет допустимых имён пакетов",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось скопировать в буфер обмена. Возможно, выделение слишком велико",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Закрыть"),
    "closeConnection": MessageLookupByLibrary.simpleMessage(
      "Закрыть соединение",
    ),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Закрыть соединения",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Цвет"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Стиль палитры"),
    "columns": MessageLookupByLibrary.simpleMessage("Столбцы"),
    "compact": MessageLookupByLibrary.simpleMessage("Компактный"),
    "compatible": MessageLookupByLibrary.simpleMessage("Режим совместимости"),
    "confirm": MessageLookupByLibrary.simpleMessage("Подтвердить"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить все данные?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите удалить эту группу прокси?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите закрыть текущее окно?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно завершить ядро со сбоем?",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой TCP",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Управление перегрузкой TCP действует только со стеком mips.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Подключено"),
    "connecting": MessageLookupByLibrary.simpleMessage("Подключение…"),
    "connection": MessageLookupByLibrary.simpleMessage("Соединение"),
    "connectionStats": MessageLookupByLibrary.simpleMessage(
      "Статистика подключений",
    ),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Подключения, запросы и DNS-запросы",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Соединения"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Подключение: "),
    "content": MessageLookupByLibrary.simpleMessage("Содержимое"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Содержимое не может быть пустым",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Управление глобальными добавленными правилами",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Копировать"),
    "copyAsBase64": MessageLookupByLibrary.simpleMessage(
      "Копировать как Base64",
    ),
    "copyAsCurl": MessageLookupByLibrary.simpleMessage("Копировать как cURL"),
    "copyDestination": MessageLookupByLibrary.simpleMessage(
      "Копировать адрес назначения",
    ),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Копировать переменные окружения",
    ),
    "copyHost": MessageLookupByLibrary.simpleMessage("Копировать хост"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Копировать ссылку"),
    "copyRequest": MessageLookupByLibrary.simpleMessage("Копировать запрос"),
    "copyResponse": MessageLookupByLibrary.simpleMessage("Копировать ответ"),
    "copyResponseBody": MessageLookupByLibrary.simpleMessage(
      "Копировать тело ответа",
    ),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Скопировано"),
    "core": MessageLookupByLibrary.simpleMessage("Ядро"),
    "coreBlockedByPolicyTip": m5,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Smart App Control в Windows заблокировал неподписанный FlClashCore.exe. Откройте Безопасность Windows → Управление приложениями и браузером → Параметры Smart App Control, выберите «Выкл.» и снова запустите Flash. Повторно включить Smart App Control без переустановки Windows нельзя.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Статус ядра"),
    "country": MessageLookupByLibrary.simpleMessage("Регион"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Обнаружен сбой"),
    "crashDetectedTip": m6,
    "crashTest": MessageLookupByLibrary.simpleMessage("Тест сбоя"),
    "create": MessageLookupByLibrary.simpleMessage("Создать"),
    "createProfileFromUrlTip": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("Время создания"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Содержит кнопку запуска, удалить нельзя",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Вручную"),
    "customColor": MessageLookupByLibrary.simpleMessage("Свой цвет"),
    "customImportDroppedSubRules": m8,
    "customIssueCoreRejected": m9,
    "customIssueDialerLoop": m10,
    "customIssueDuplicateName": m11,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "Имя не задано",
    ),
    "customIssueGroupLoop": m12,
    "customIssueInvalidEmptyFallback": m13,
    "customIssueInvalidFilter": m14,
    "customIssueMissingDialer": m15,
    "customIssueMissingProviders": m16,
    "customIssueMissingProxies": m17,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "Не выбраны ни прокси, ни провайдеры прокси, поэтому ядро отклонит эту группу",
    ),
    "customIssueReservedName": m18,
    "customIssuesSummary": m19,
    "customProfile": MessageLookupByLibrary.simpleMessage("Пользовательский"),
    "customResources": MessageLookupByLibrary.simpleMessage("Пользовательские"),
    "cut": MessageLookupByLibrary.simpleMessage("Вырезать"),
    "dark": MessageLookupByLibrary.simpleMessage("Тёмная"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Панель"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Можно добавить",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Не удалось сохранить изменение; оно отменено",
    ),
    "daysAgo": m20,
    "daysAgoShort": m21,
    "decryptUntrusted": MessageLookupByLibrary.simpleMessage(
      "Расшифровывать без локального доверия",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешает имена других DNS-серверов. Только IP-адреса.",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Выбор по умолчанию",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("По умолчанию"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "Конфигурация должна быть YAML-словарём с полями name и type",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Задержка"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Сбой"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Тест задержки"),
    "delayTestTimeout": MessageLookupByLibrary.simpleMessage(
      "Тайм-аут теста задержки",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Удалить"),
    "deleteMultipTip": m22,
    "deleteTip": m23,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Многоплатформенный прокси-клиент на основе ClashMeta: простой и удобный, с открытым исходным кодом и без рекламы.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Назначение"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP назначения",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN IP назначения",
    ),
    "details": m24,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Использует сторонний API; только для справки",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Режим разработчика"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Режим разработчика включён.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage(
      "Прокси для подключения",
    ),
    "dialerProxyLoopStopped": m25,
    "dialog": MessageLookupByLibrary.simpleMessage("Диалог"),
    "direct": MessageLookupByLibrary.simpleMessage("Прямой"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Разрешает домены прямых соединений.",
    ),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Отключить пересылку ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "При отключённой пересылке ICMP TUN сам отвечает на ping, поэтому ping больше не показывает реальную задержку.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Отключить TCP keep-alive",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Отключить UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Выключено"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "Отменить изменения?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage(
      "Отказ от ответственности",
    ),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "Это заявление описывает характер, риски и ответственность при использовании Программы. Оно не является дополнительным условием к GPL-3.0 и не ограничивает никаких прав, которые даёт вам эта лицензия, включая право запускать, копировать, изменять и распространять Программу. При расхождении действует GPL-3.0.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage(
      "Связь с открытой лицензией",
    ),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "Я прочитал(а) и понимаю это заявление",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "Чтобы подтвердить, что вы ознакомились с ним, прочитайте следующее заявление и отметьте пункт ниже:",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Подтвердите заявление",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "Это заявление может меняться в следующих версиях; к каждой версии относится заявление, поставляемое с ней.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Изменения заявления",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Перед использованием Flash («Программа») внимательно прочитайте это заявление и убедитесь, что понимаете его. Нажимая «Согласен», вы подтверждаете, что прочитали и поняли изложенное ниже. Если не хотите продолжать, нажмите «Выход».",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "В максимальной степени, допустимой применимым законодательством, ни разработчики, ни участники проекта не несут ответственности за любой прямой, косвенный, случайный, особый, штрафной или последующий ущерб, возникший в результате использования или невозможности использования Программы, включая, помимо прочего, потерю данных, повреждение устройства, сбои сети, прерывание деятельности, упущенную выгоду или связанные с этим правовые споры, даже если они были предупреждены о возможности такого ущерба.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Ограничение ответственности",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "Программа распространяется с открытым исходным кодом по лицензии GPL-3.0. По этой лицензии вы можете запускать, изучать, изменять и распространять её; распространяя Программу или её изменённую версию, вы должны также предоставить исходный код по GPL-3.0 и сохранить исходные уведомления об авторских правах.\n\nСторонние компоненты Программы, включая ядро Clash.Meta, распространяются по своим лицензиям. Исходные авторы не отвечают за проблемы версий, изменённых или распространяемых другими.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Лицензия с открытым исходным кодом",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "Сама Программа не предоставляет прокси-серверы, узлы, подписки или услуги доступа к сети и не состоит в партнёрских, агентских или гарантийных отношениях с поставщиками таких услуг.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "Программа не собирает и не отправляет адреса ваших подписок, сведения об узлах, содержимое конфигураций, посещённые сайты, записи о подключениях, содержимое трафика и журналы. Эти данные хранятся только на вашем устройстве, и у разработчиков нет к ним доступа.\n\nПрограмма обращается к сети только при использовании соответствующих функций, например загружает указанный вами адрес подписки при обновлении профиля или обращается к GitHub при проверке обновлений.\n\nПрограмма не содержит никаких сервисов статистики или отчётов о сбоях ни на одной платформе.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Сбор данных и конфиденциальность",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "Вы самостоятельно убеждаетесь, что использование Программы законно в вашей стране или регионе, и единолично несёте юридическую ответственность за все действия с ней и их последствия.\n\nПодписки, узлы и конфигурации, которые вы импортируете, выбираете вы сами. Законность их источника, безопасность содержимого и надёжность сервиса — вопрос между вами и их поставщиками.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Ваша ответственность",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Введите заявление выше",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "Не совпадает с текстом заявления",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "Чтобы подтвердить, что вы ознакомились с ним, полностью введите следующее заявление в поле ниже:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Повторите заявление",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "Программа — это клиент сетевого прокси с открытым исходным кодом на основе ядра Clash.Meta (mihomo). Она предоставляет только локальные инструменты: управление конфигурациями, маршрутизацию по правилам и пересылку трафика.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Характер программы",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Ссылки на подписки, файлы конфигурации, наборы правил, скрипты, внешние ресурсы и внешние ссылки предоставляются третьими лицами. Разработчики не могут проверять и не проверяют их законность, точность, безопасность и доступность и не дают на них никаких гарантий.\n\nУтечка данных, финансовые потери, блокировка аккаунта или иной ущерб, вызванные сторонним контентом, урегулируются между вами и третьим лицом; разработчики не несут за это никакой ответственности.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Сторонний контент",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "Любая коммерческая деятельность с использованием Программы, включая платное распространение, продажу в комплекте или использование в составе коммерческого сервиса, не связана с разработчиками Программы, которые её не одобряют, не поддерживают и не гарантируют.\n\nВы сами отвечаете за соблюдение законов страны или региона, где находитесь, и несёте последствия любого незаконного использования Программы.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "Об использовании",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "Программа предоставляется «как есть» и «по мере доступности», без каких-либо явных или подразумеваемых гарантий, включая, помимо прочего, гарантии товарной пригодности, пригодности для определённой цели, ненарушения прав, бесперебойной работы, отсутствия ошибок и уязвимостей.\n\nРазработчики не гарантируют, что Программа будет соответствовать вашим потребностям или работать без сбоев и ошибок.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "Отсутствие гарантий",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Отключено"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Доступна новая версия",
    ),
    "dnsCacheCleared": MessageLookupByLibrary.simpleMessage("Кэш DNS очищен"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Без этого параметра TUN перехватывает все DNS-запросы на порт 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Перехват DNS"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Режим DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Добавленные здесь параметры заменяют DNS всех профилей из URL и файлов; остальные остаются такими, как в профиле. DNS пользовательского профиля задаётся в его содержимом.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("DNS-запросы"),
    "docked": MessageLookupByLibrary.simpleMessage("Закреплённая"),
    "domain": MessageLookupByLibrary.simpleMessage("Домен"),
    "done": MessageLookupByLibrary.simpleMessage("Готово"),
    "download": MessageLookupByLibrary.simpleMessage("Загрузка"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Скорость загрузки",
    ),
    "downloadingUpdate": MessageLookupByLibrary.simpleMessage(
      "Загрузка обновления",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Длительность"),
    "edit": MessageLookupByLibrary.simpleMessage("Редактировать"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("Изменить панель"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Редактировать глобальные правила",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Редактировать прокси"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Редактировать группу прокси",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Редактировать правило"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Изменить SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Редактор недоступен",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Время"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage(
      "Резерв для пустой группы",
    ),
    "emptyTip": m26,
    "en": MessageLookupByLibrary.simpleMessage("Английский"),
    "enabled": MessageLookupByLibrary.simpleMessage("Включено"),
    "entries": MessageLookupByLibrary.simpleMessage(" записей"),
    "error": MessageLookupByLibrary.simpleMessage("Ошибка"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Подробности ошибки"),
    "es": MessageLookupByLibrary.simpleMessage("Испанский"),
    "exclude": MessageLookupByLibrary.simpleMessage("Скрыть из недавних задач"),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Исключённые порты назначения",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("Фильтр исключения"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Исключённые интерфейсы",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Исключённые исходные порты",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Исключённые SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "При подключении к Wi-Fi с исключённым SSID состояние работы приложения переключается автоматически.",
    ),
    "excludeUid": MessageLookupByLibrary.simpleMessage(
      "Исключённые ID пользователей",
    ),
    "existsTip": m27,
    "exit": MessageLookupByLibrary.simpleMessage("Выход"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Выйти из полноэкранного режима",
    ),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Выходные узлы"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Ожидаемый статус"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Срок действия"),
    "exportCertificate": MessageLookupByLibrary.simpleMessage(
      "Экспортировать сертификат",
    ),
    "exportFile": MessageLookupByLibrary.simpleMessage("Экспорт файла"),
    "exportHar": MessageLookupByLibrary.simpleMessage("Экспорт HAR"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Экспорт логов"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Экспорт выполнен"),
    "extend": MessageLookupByLibrary.simpleMessage("Расширение"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Режим расширения"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Скрипт расширения"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Внешний контроллер позволяет управлять ядром через порт 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "Секрет внешнего контроллера",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Внешняя ссылка"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Очень крупный"),
    "fade": MessageLookupByLibrary.simpleMessage("Растворение"),
    "failedCount": m28,
    "failedItem": m29,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Фильтр Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Эти домены получают реальные IP вместо Fake-IP. В режиме whitelist Fake-IP получают только они.",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Режим фильтра Fake-IP",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Диапазон Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Диапазон Fake-IP (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("TTL Fake-IP"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Используются вместо Nameserver, когда фильтр fallback считает его ответ подменённым.",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Фильтр fallback"),
    "fallbackFilterDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Эти домены сразу разрешаются через Fallback.",
    ),
    "fallbackFilterGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Домены из этих категорий GeoSite сразу разрешаются через Fallback.",
    ),
    "fallbackFilterIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Если Nameserver возвращает IP из этих диапазонов, используется ответ Fallback.",
    ),
    "file": MessageLookupByLibrary.simpleMessage("Файл"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Файл изменён. Сохранить изменения?",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("Фильтр"),
    "filters": MessageLookupByLibrary.simpleMessage("Фильтры"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Поиск процесса"),
    "floating": MessageLookupByLibrary.simpleMessage("Плавающая"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Как в профиле"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Как в системе"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Шрифт"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Размер"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Принудительно для DNS-сопоставлений",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "«Принудительно для DNS-сопоставлений» анализирует и соединения, домен которых получен из DNS-сопоставления.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage(
      "Принудительные домены",
    ),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Принудительные домены тоже анализируются; остальные соединения с доменом не затрагиваются.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите принудительно перезапустить ядро?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("Французский"),
    "general": MessageLookupByLibrary.simpleMessage("Общие"),
    "generalOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Добавленные здесь параметры заменяют соответствующие настройки всех профилей; остальные остаются такими, как в профиле, а если профиль их не задаёт, действуют значения ядра по умолчанию.",
    ),
    "generateCertificate": MessageLookupByLibrary.simpleMessage(
      "Создать сертификат",
    ),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m30,
    "geoUpdated": m31,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo: экономия памяти",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Глобальный"),
    "go": MessageLookupByLibrary.simpleMessage("Перейти"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Скачать"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Перейти к настройке добавленных правил",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Перейти к настройке скрипта",
    ),
    "grid": MessageLookupByLibrary.simpleMessage("Сетка"),
    "groupBy": MessageLookupByLibrary.simpleMessage("Группировка"),
    "groupCount": m32,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("групп"),
    "groupTimeoutCount": m33,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Кэшировать изменения?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Хешировать по пользователю входящего подключения",
    ),
    "headerRewrite": MessageLookupByLibrary.simpleMessage(
      "Перезапись заголовков",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Проверка состояния"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Служба Helper недоступна, поэтому TUN-режим включить нельзя. Переустановите Flash.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hiddenGroupSemantics": m34,
    "hiddenGroupTag": MessageLookupByLibrary.simpleMessage("Скрытая"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Скрыть из списка"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Скрыть IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Скрыть пароль"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Скрывать прокси с таймаутом",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Интервал перескока"),
    "host": MessageLookupByLibrary.simpleMessage("Хост"),
    "hostname": MessageLookupByLibrary.simpleMessage("Имя хоста"),
    "hotkeyConflictWith": m35,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Глобальные горячие клавиши работают, даже когда окно скрыто. Нажмите на действие, чтобы записать сочетание клавиш.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage("Горячие клавиши"),
    "hotkeyNeedsModifier": m36,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Не задано"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Не зарегистрировано: сочетание может быть занято другим приложением",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("часов"),
    "hoursAgo": m37,
    "hoursAgoShort": m38,
    "http2": MessageLookupByLibrary.simpleMessage("HTTP/2"),
    "httpBodyNotKept": MessageLookupByLibrary.simpleMessage(
      "Не записано: не хватало памяти.",
    ),
    "httpBodyProtobufGuess": MessageLookupByLibrary.simpleMessage(
      "Прочитано как Protobuf без схемы: только номера полей, типы предполагаемые.",
    ),
    "httpBodyTruncated": MessageLookupByLibrary.simpleMessage(
      "Записано только начало тела.",
    ),
    "httpBodyUndecoded": m39,
    "httpCapture": MessageLookupByLibrary.simpleMessage("Захват HTTP"),
    "httpCaptureDesc": MessageLookupByLibrary.simpleMessage(
      "Записывает запросы к хостам из списка имён хостов; их можно посмотреть в сведениях о соединении. Записи хранятся только в памяти.",
    ),
    "httpCaptureLimit": MessageLookupByLibrary.simpleMessage(
      "Максимум записей",
    ),
    "httpCaptureLimitDesc": m40,
    "httpCaptureNoHosts": MessageLookupByLibrary.simpleMessage(
      "Хосты не указаны, поэтому ничего не записывается. Добавьте их в поле «Имя хоста» на странице MITM или из сведений о соединении.",
    ),
    "httpCaptureOff": MessageLookupByLibrary.simpleMessage("Захват выключен"),
    "httpExportPrivate": MessageLookupByLibrary.simpleMessage(
      "Запрос может содержать cookie, токены, пароли и данные форм. Проверьте, что и кому вы передаёте.",
    ),
    "httpExportPrivateTitle": MessageLookupByLibrary.simpleMessage(
      "Содержит личные данные",
    ),
    "httpRequestCleared": MessageLookupByLibrary.simpleMessage(
      "Запись этого запроса удалена",
    ),
    "httpRequests": MessageLookupByLibrary.simpleMessage("HTTP-запросы"),
    "httpRequestsMissing": MessageLookupByLibrary.simpleMessage(
      "Запросы, отправленные до включения захвата или уже удалённые, не показаны.",
    ),
    "httpsDecryption": MessageLookupByLibrary.simpleMessage(
      "Расшифровка HTTPS",
    ),
    "hue": MessageLookupByLibrary.simpleMessage("Оттенок"),
    "icon": MessageLookupByLibrary.simpleMessage("Значок"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("История значков"),
    "iconSets": MessageLookupByLibrary.simpleMessage("Наборы значков"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Наборов значков пока нет. Добавьте их в разделе «Ресурсы пользовательских профилей → Наборы значков»",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Стиль значков"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("С подложкой"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Скрыто"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Без подложки"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL значка"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Игнорировать оптимизацию батареи",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Импорт"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "Этот файл не является конфигурацией, которую можно импортировать",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "Импорт заменит текущие группы прокси, правила и настройки этого профиля",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage("Импорт из файла"),
    "importFromLink": MessageLookupByLibrary.simpleMessage("Импорт по ссылке"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Импорт по URL"),
    "inProgress": MessageLookupByLibrary.simpleMessage("Выполняется"),
    "inbound": MessageLookupByLibrary.simpleMessage("Входящие"),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Включённые интерфейсы",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Через TUN идёт только трафик с включённых интерфейсов, а исключённые интерфейсы больше не действуют.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage(
      "Включённые ID пользователей",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Бессрочно"),
    "infoAbout": MessageLookupByLibrary.simpleMessage("About"),
    "init": MessageLookupByLibrary.simpleMessage("Инициализация"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Не удалось запустить"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "При запуске Flash произошла ошибка, и работа не может быть продолжена. Скопируйте подробности, чтобы сообщить о проблеме. Если ошибка повторяется, очистка данных обычно позволяет снова запустить приложение.",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("Инициатор"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("Источник"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Введите название группы прокси",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Введите содержимое правила",
    ),
    "installCertificate": MessageLookupByLibrary.simpleMessage(
      "Установить в систему",
    ),
    "installCertificateSuccess": MessageLookupByLibrary.simpleMessage(
      "Сертификат установлен",
    ),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "Разрешение на список приложений отклонено, поэтому установленные приложения недоступны. Предоставьте его вручную в системных настройках.",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Эта система не выдаёт список установленных приложений без разрешения. Предоставьте его, чтобы настроить прокси для отдельных приложений.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется разрешение на список приложений",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage(
      "Установленные шрифты",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage("Умный выбор"),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Имя интерфейса"),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Исходящий интерфейс",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Очистить"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage("Вручную"),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Как в конфигурации",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Интернет"),
    "interval": MessageLookupByLibrary.simpleMessage("Интервал"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Внутренний IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Недопустимый файл резервной копии",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Введите диапазон IP в формате CIDR, например 192.168.0.0/16",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "Метка DSCP не может превышать 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Введите домен или IP-адрес",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "Это не набор значков",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "Это не ссылка на подписку и не ссылка на прокси",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Введите адрес и порт, например 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Поддерживаются только tcp и udp",
    ),
    "invalidOfCount": m41,
    "invalidPolicy": m42,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Введите порт или диапазон, например 443 или 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "Этот QR-код не содержит ссылку на профиль",
    ),
    "invalidProxy": m43,
    "invalidProxyProvider": m44,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Введите числа или диапазоны, например 80 или 8000-9000, через /",
    ),
    "invalidRuleSet": m45,
    "invalidSubRule": m46,
    "ipAddress": MessageLookupByLibrary.simpleMessage("IP-адрес"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Злоупотребления"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Прокси"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Метки"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Организация"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось определить тип IP",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Хороший"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Уровень"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Обычный"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage("Проверить снова"),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("Рискованный"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Качество"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Источник ответа"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Источники"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "Другой исходящий IP",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("Тип не определён"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "Лимит запросов",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("Тип"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Бизнес"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Дата-центр"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Мобильная сеть"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Домашний"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Тип неизвестен"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("Версия IP"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Трафик IPv6 принимается, только когда IPv6 включён.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage("Тайм-аут IPv6 (мс)"),
    "itemsCount": m47,
    "ja": MessageLookupByLibrary.simpleMessage("Японский"),
    "justNow": MessageLookupByLibrary.simpleMessage("Только что"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "Простой TCP keep-alive",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Интервал TCP keep-alive",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Ключ"),
    "ko": MessageLookupByLibrary.simpleMessage("Корейский"),
    "label": MessageLookupByLibrary.simpleMessage("Метка"),
    "language": MessageLookupByLibrary.simpleMessage("Язык"),
    "large": MessageLookupByLibrary.simpleMessage("Крупный"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Последнее обновление"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "Запуск не завершён",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "В прошлый раз приложение неожиданно завершилось во время запуска. Автоматическая настройка для этого запуска пропущена; вы можете запустить её вручную.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Макет"),
    "light": MessageLookupByLibrary.simpleMessage("Светлая"),
    "lineIssueTip": m48,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Перенос строк"),
    "link": MessageLookupByLibrary.simpleMessage("Ссылка"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Жидкое стекло"),
    "list": MessageLookupByLibrary.simpleMessage("Список"),
    "listen": MessageLookupByLibrary.simpleMessage("Прослушивание"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Метка маршрутизации",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "Метка маршрутизации действует только в Linux.",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage(
      "Активные соединения",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Загрузка…"),
    "local": MessageLookupByLibrary.simpleMessage("Локально"),
    "localImage": MessageLookupByLibrary.simpleMessage("Локальное изображение"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Доступ к локальной сети запрещён: используется стек gvisor, локальная сеть недоступна.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Локальные прокси"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Разрешение на геолокацию отклонено, поэтому невозможно получить имя текущей сети Wi-Fi. Включите разрешение на геолокацию вручную в системных настройках.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "По требованию системы для получения имени сети Wi-Fi необходимо разрешение на геолокацию. На Android выберите «Разрешить всегда», иначе имя сети Wi-Fi нельзя получить, пока приложение в фоне.",
    ),
    "locationPermissionGuide": m49,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Требуется разрешение на геолокацию",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Лог"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Уровень логов"),
    "logcat": MessageLookupByLibrary.simpleMessage("Захват логов"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "При отключении захвата логов раздел логов скрывается.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Логи"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Логи и диагностика",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("Тест логов"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Снятие ограничения loopback для UWP",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Свободный"),
    "mapLocal": MessageLookupByLibrary.simpleMessage("Локальная подмена"),
    "matchCase": MessageLookupByLibrary.simpleMessage("Учитывать регистр"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Сопоставлять IP источника",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchedRules": MessageLookupByLibrary.simpleMessage("Сработавшие правила"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage(
      "Макс. число неудач",
    ),
    "maxLengthTip": m50,
    "maximize": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Резидентная память",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage(
      "Приложение и общая",
    ),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage(
      "Свободная куча",
    ),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage(
      "Используемая куча",
    ),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "Ядро не запущено",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Накладные расходы среды",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage("Стеки горутин"),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Оценка по резидентной памяти процессов; может отличаться от данных системы.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "Ядро работает в процессе приложения. Его доля оценивается по статистике среды выполнения, остальное относится к приложению и общей памяти.",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Память"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Память приложения и ядра",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage(
      "Память освобождена",
    ),
    "memoryReleasedSize": m51,
    "messageTest": MessageLookupByLibrary.simpleMessage("Тест сообщения"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage("Это сообщение."),
    "method": MessageLookupByLibrary.simpleMessage("Метод"),
    "minimize": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Сворачивать при выходе",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("минут"),
    "minutesAgo": m52,
    "minutesAgoShort": m53,
    "mitm": MessageLookupByLibrary.simpleMessage("MITM"),
    "mitmAddLocalFile": MessageLookupByLibrary.simpleMessage(
      "Добавить локальный файл",
    ),
    "mitmAddMapLocalRule": MessageLookupByLibrary.simpleMessage(
      "Добавить правило локальной подмены",
    ),
    "mitmAddRejectRule": MessageLookupByLibrary.simpleMessage(
      "Добавить правило блокировки",
    ),
    "mitmAttachments": MessageLookupByLibrary.simpleMessage("Вложения"),
    "mitmAttachmentsDesc": MessageLookupByLibrary.simpleMessage(
      "Строки ссылаются на вложения по имени файла, например script-path=a.js.",
    ),
    "mitmCertificateAndroidReadyTip": MessageLookupByLibrary.simpleMessage(
      "Расшифровываются только приложения, доверяющие пользовательским сертификатам, в основном браузеры.",
    ),
    "mitmCertificateExportTip": MessageLookupByLibrary.simpleMessage(
      "Экспортируйте его и добавьте в доверенные на устройствах, трафик которых нужно расшифровывать.",
    ),
    "mitmCertificateLinuxTip": MessageLookupByLibrary.simpleMessage(
      "В браузеры из Flatpak экспортированный сертификат нужно импортировать вручную.",
    ),
    "mitmCertificateSavedTip": m54,
    "mitmCertutilMissing": m55,
    "mitmClientRefusedCertificate": MessageLookupByLibrary.simpleMessage(
      "Клиент отклонил сертификат. Установите сертификат или исключите этот хост, если приложение закрепляет свой сертификат.",
    ),
    "mitmDecryptHost": MessageLookupByLibrary.simpleMessage(
      "Расшифровывать этот хост",
    ),
    "mitmDecryptHostTip": m56,
    "mitmEnableTip": MessageLookupByLibrary.simpleMessage(
      "Flash сможет читать всё, что отправляется на расшифровываемые узлы, включая cookie и пароли. Включайте только для узлов, которые нужно перезаписывать.",
    ),
    "mitmExcludeHost": MessageLookupByLibrary.simpleMessage(
      "Исключить из расшифровки",
    ),
    "mitmExcludeHostTip": m57,
    "mitmFileTooLarge": m58,
    "mitmHostnameDesc": MessageLookupByLibrary.simpleMessage(
      "Префикс - исключает хост; действует первое совпадение.",
    ),
    "mitmIgnoredLines": MessageLookupByLibrary.simpleMessage(
      "Пропущенные строки",
    ),
    "mitmInstallSystemCaTip": MessageLookupByLibrary.simpleMessage(
      "Обнаружен root: сертификат будет добавлен в доверенные сертификаты системы как модуль Magisk, KernelSU или APatch «FlClash MITM CA». После этого ему будут доверять все приложения устройства, а любой, у кого есть его закрытый ключ, сможет расшифровать HTTPS-трафик устройства. Чтобы отменить это, создайте сертификат заново или удалите модуль в root-менеджере и перезагрузите устройство. Если в root отказано, сертификат будет установлен как пользовательский.",
    ),
    "mitmInstallUserCaTip": MessageLookupByLibrary.simpleMessage(
      "Root не обнаружен: сертификат можно установить только как пользовательский. Расшифровываются только приложения, доверяющие пользовательским сертификатам, в основном браузеры; остальные не смогут подключиться к указанным узлам, поэтому не указывайте их узлы. Начиная с Android 11 установку нужно завершить вручную в настройках системы.",
    ),
    "mitmMissingStores": m59,
    "mitmModule": MessageLookupByLibrary.simpleMessage("Модуль"),
    "mitmModuleInvalid": MessageLookupByLibrary.simpleMessage(
      "Это не модуль Surge, не плагин Loon, не фрагмент Quantumult X и не переопределение Stash",
    ),
    "mitmModuleRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Правила маршрутизации идут перед правилами профиля.",
    ),
    "mitmModuleScriptsChanged": m60,
    "mitmModuleSystemTip": m61,
    "mitmModules": MessageLookupByLibrary.simpleMessage("Модули"),
    "mitmNewModule": MessageLookupByLibrary.simpleMessage("Новый модуль"),
    "mitmOldCertificateLeftTip": m62,
    "mitmOldSystemCertificateLeftTip": m63,
    "mitmRemoveOldCertificateTip": m64,
    "mitmRootPendingReboot": MessageLookupByLibrary.simpleMessage(
      "Сертификат начнёт действовать после перезагрузки устройства.",
    ),
    "mitmRootUntilReboot": MessageLookupByLibrary.simpleMessage(
      "Не найден Magisk, KernelSU или APatch, чтобы сохранить сертификат. После перезагрузки устройства установите его снова.",
    ),
    "mitmRoutingRules": MessageLookupByLibrary.simpleMessage(
      "Правила маршрутизации",
    ),
    "mitmRuleCopiedForStash": MessageLookupByLibrary.simpleMessage(
      "Этот модуль — переопределение Stash, поэтому правило скопировано, добавьте его вручную.",
    ),
    "mitmRunScript": MessageLookupByLibrary.simpleMessage("Запустить сейчас"),
    "mitmScriptNoOutput": MessageLookupByLibrary.simpleMessage(
      "Скрипт завершился без вывода",
    ),
    "mitmScriptRisk": MessageLookupByLibrary.simpleMessage(
      "Его скрипты читают и меняют трафик подходящих хостов, включая файлы cookie и токены, и могут сами отправлять запросы. Включайте, только если доверяете источнику.",
    ),
    "mitmScriptRiskTitle": MessageLookupByLibrary.simpleMessage(
      "Запускать скрипты этого модуля?",
    ),
    "mitmSkipConditional": MessageLookupByLibrary.simpleMessage(
      "Условные перезаписи не поддерживаются",
    ),
    "mitmSkipDisabled": MessageLookupByLibrary.simpleMessage(
      "Отключено аргументом",
    ),
    "mitmSkipEvent": MessageLookupByLibrary.simpleMessage(
      "Это событие не поддерживается",
    ),
    "mitmSkipJq": MessageLookupByLibrary.simpleMessage(
      "Перезаписи jq не поддерживаются",
    ),
    "mitmSkipJsonBody": MessageLookupByLibrary.simpleMessage(
      "Перезаписи тела JSON не поддерживаются",
    ),
    "mitmSkipNotDownloaded": MessageLookupByLibrary.simpleMessage(
      "Его файл ещё не загружен",
    ),
    "mitmSkipPolicy": MessageLookupByLibrary.simpleMessage(
      "Поддерживаются только политики DIRECT и REJECT",
    ),
    "mitmSkipRawHeader": MessageLookupByLibrary.simpleMessage(
      "Перезапись всех заголовков как одного текста не поддерживается",
    ),
    "mitmSkipRelativeData": MessageLookupByLibrary.simpleMessage(
      "Файл из этой строки не прикреплён; укажите URL или прикрепите его",
    ),
    "mitmSkipRule": MessageLookupByLibrary.simpleMessage(
      "Этот тип правила не поддерживается",
    ),
    "mitmSkipScriptType": MessageLookupByLibrary.simpleMessage(
      "Этот тип скриптов не поддерживается",
    ),
    "mitmSkipSection": m65,
    "mitmSkipSetting": MessageLookupByLibrary.simpleMessage(
      "Этот параметр не поддерживается",
    ),
    "mitmSkipUnreadable": MessageLookupByLibrary.simpleMessage(
      "Эту строку не удалось прочитать",
    ),
    "mitmSystemStoreFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось добавить сертификат в доверенные корневые сертификаты системы",
    ),
    "mitmTrustChecking": MessageLookupByLibrary.simpleMessage("Проверка…"),
    "mitmTrustNotInstalled": MessageLookupByLibrary.simpleMessage(
      "Не установлен",
    ),
    "mitmTrustReady": MessageLookupByLibrary.simpleMessage("Доверенный"),
    "mitmTrustUntrusted": MessageLookupByLibrary.simpleMessage(
      "Доверие неполное",
    ),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Смешанный порт"),
    "mixedPortUnavailable": m66,
    "mixedPortUnavailableProxyUnchanged": m67,
    "mode": MessageLookupByLibrary.simpleMessage("Режим"),
    "monochromeIcon": MessageLookupByLibrary.simpleMessage(
      "Монохромный значок",
    ),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Монохром"),
    "monthsAgo": m68,
    "monthsAgoShort": m69,
    "more": MessageLookupByLibrary.simpleMessage("Ещё"),
    "mountAbout": MessageLookupByLibrary.simpleMessage("About mounts"),
    "mountAboutBody": MessageLookupByLibrary.simpleMessage(
      "Choose imported subscriptions to add their nodes to this profile. All eligible proxy groups receive mounted nodes, then apply their existing inclusion and exclusion filters. Existing nodes, rules, and DNS settings are kept, and original files are not rewritten.",
    ),
    "mountAlsoMounts": m70,
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
    "mountBaseDirect": MessageLookupByLibrary.simpleMessage(
      "When no nodes are selectable, this group uses a direct connection as specified by the original profile.",
    ),
    "mountBaseFallback": m71,
    "mountBlockDesc": MessageLookupByLibrary.simpleMessage(
      "If this group has no selectable nodes, its connections are blocked instead of sent directly.",
    ),
    "mountBlockTag": MessageLookupByLibrary.simpleMessage("Block when empty"),
    "mountCardFailed": m72,
    "mountCardUnreadable": MessageLookupByLibrary.simpleMessage(
      "Could not read mount status",
    ),
    "mountChooseSources": MessageLookupByLibrary.simpleMessage(
      "Choose subscriptions",
    ),
    "mountDeleteSourceBlocked": MessageLookupByLibrary.simpleMessage(
      "This subscription or an affected profile has unconfirmed operations. Read the status again before deleting.",
    ),
    "mountDeleteSourceBody": m73,
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
      "Adds nodes without changing rules or DNS.",
    ),
    "mountDetails": MessageLookupByLibrary.simpleMessage("Details"),
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
    "mountFetchFailed": MessageLookupByLibrary.simpleMessage(
      "Could not fetch nodes from this subscription. Try again.",
    ),
    "mountFormatHelp": MessageLookupByLibrary.simpleMessage(
      "You can mount imported remote Clash/mihomo subscriptions and remote subscriptions successfully converted by Flash’s existing importer. Only nodes are included, not subscription rules or DNS settings.",
    ),
    "mountGroupEmpty": m74,
    "mountGroupNoMatch": MessageLookupByLibrary.simpleMessage(
      "No mounted nodes match",
    ),
    "mountGroupNodes": m75,
    "mountGroupPending": MessageLookupByLibrary.simpleMessage(
      "Pending application",
    ),
    "mountGroupsCount": m76,
    "mountGroupsExcluded": m77,
    "mountGroupsExcludedNames": m78,
    "mountGroupsExcludedShort": m79,
    "mountGroupsFailed": MessageLookupByLibrary.simpleMessage(
      "Could not read this profile’s groups. Read them again.",
    ),
    "mountGroupsHidden": MessageLookupByLibrary.simpleMessage(
      "Hidden proxy groups also follow the filtering and isolation rules. They are not listed here.",
    ),
    "mountGroupsHiddenBlocked": m80,
    "mountGroupsHiddenCount": m81,
    "mountGroupsHiddenNoMatch": m82,
    "mountGroupsNoMatch": m83,
    "mountGroupsSummary": MessageLookupByLibrary.simpleMessage(
      "Mounted nodes are added to all eligible proxy groups using each group’s existing filters. Existing nodes are kept.",
    ),
    "mountGroupsTitle": MessageLookupByLibrary.simpleMessage(
      "Groups for these nodes",
    ),
    "mountGroupsUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Group additions are not confirmed",
    ),
    "mountHintFiltered": MessageLookupByLibrary.simpleMessage(
      "Auto-collected · Group filters apply",
    ),
    "mountImport": MessageLookupByLibrary.simpleMessage("Import subscription"),
    "mountImportHint": MessageLookupByLibrary.simpleMessage(
      "Return here after importing to choose the subscription. Your active profile will not change.",
    ),
    "mountIsolationFirst": MessageLookupByLibrary.simpleMessage(
      "Tailscale and other mount-isolation requirements still take priority. Ineligible groups will not receive subscription nodes.",
    ),
    "mountLastUpdated": m84,
    "mountListFailed": MessageLookupByLibrary.simpleMessage(
      "Could not load subscriptions. Try again.",
    ),
    "mountMountedTag": MessageLookupByLibrary.simpleMessage("Mounted"),
    "mountNameSeparator": MessageLookupByLibrary.simpleMessage(", "),
    "mountNamesAndExclusions": MessageLookupByLibrary.simpleMessage(
      "Name conflicts and exclusions",
    ),
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
    "mountNodeCount": m85,
    "mountNodesExcludedShort": m86,
    "mountNodesRead": m87,
    "mountNodesReadAt": m88,
    "mountNodesUpdated": MessageLookupByLibrary.simpleMessage("Nodes updated"),
    "mountNotFetched": MessageLookupByLibrary.simpleMessage(
      "Nodes not fetched yet",
    ),
    "mountNotMounted": MessageLookupByLibrary.simpleMessage("Not mounted"),
    "mountPillFailedSemantics": MessageLookupByLibrary.simpleMessage(
      "a subscription update failed",
    ),
    "mountPillSemantics": m89,
    "mountProviderUpdateRefused": m90,
    "mountProviderUpdateRefusedUnconfirmed": m91,
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
    "mountSameNameShort": MessageLookupByLibrary.simpleMessage(
      "Matching node names use the subscription name",
    ),
    "mountSave": MessageLookupByLibrary.simpleMessage("Save mounts"),
    "mountSavedUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Mounts saved; application is not yet confirmed.",
    ),
    "mountSaving": MessageLookupByLibrary.simpleMessage("Saving mounts…"),
    "mountSelectionLost": MessageLookupByLibrary.simpleMessage(
      "The previously selected node is no longer in this subscription. Choose another node.",
    ),
    "mountShowAllGroups": m92,
    "mountShowLess": MessageLookupByLibrary.simpleMessage("Show less"),
    "mountSomeExcluded": MessageLookupByLibrary.simpleMessage(
      "Some nodes or groups are excluded from mounting",
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
    "mountTarget": m93,
    "mountTypeFallback": MessageLookupByLibrary.simpleMessage("Failover"),
    "mountTypeLoadBalance": MessageLookupByLibrary.simpleMessage(
      "Load balancing",
    ),
    "mountTypeSelect": MessageLookupByLibrary.simpleMessage("Manual selection"),
    "mountTypeUrlTest": MessageLookupByLibrary.simpleMessage(
      "Latency selection",
    ),
    "mountUnchanged": MessageLookupByLibrary.simpleMessage(
      "Mounts were not changed. Try again.",
    ),
    "mountUnknown": MessageLookupByLibrary.simpleMessage(
      "The mount result is unconfirmed. Read the status again before saving or unmounting.",
    ),
    "mountUnmount": MessageLookupByLibrary.simpleMessage("Unmount"),
    "mountUnmountBody": m94,
    "mountUnmountManyBody": m95,
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
    "mountUnsupportedExcluded": m96,
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
    "mountUpdateNodesOf": m97,
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
    "mountViewerPending": m98,
    "mountViewerSource": m99,
    "mountedCount": m100,
    "name": MessageLookupByLibrary.simpleMessage("Название"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "DNS-серверы по умолчанию, например 223.5.5.5, tls://1.1.1.1 или https://dns.google/dns-query.",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Совпавшие домены используют указанный здесь DNS-сервер вместо Nameserver и Fallback.",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage("Нижняя панель"),
    "network": MessageLookupByLibrary.simpleMessage("Сеть"),
    "networkAccessDeniedError": m101,
    "networkBadResponseError": m102,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "Запрос отменён",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "Не удалось подключиться к серверу. Проверьте подключение к сети или настройки прокси",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "Не удалось определить адрес сервера. Проверьте правильность URL и работу DNS",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("Имя сети"),
    "networkNotFoundError": m103,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Слишком много запросов (HTTP 429). Подождите немного и повторите попытку",
    ),
    "networkRequestFailed": m104,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Секрет сети"),
    "networkServerError": m105,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Скорость сети"),
    "networkTakeover": MessageLookupByLibrary.simpleMessage("Перехват трафика"),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "Время ожидания запроса истекло. Проверьте сеть или прокси и повторите попытку",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Не удалось установить защищённое соединение. Сертификат сервера может быть недействителен, или соединение перехватывается",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Тип сети"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Следующее совпадение"),
    "no": MessageLookupByLibrary.simpleMessage("Нет"),
    "noData": MessageLookupByLibrary.simpleMessage("Нет данных"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Нет информации"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Больше не напоминать",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Нет сети"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Приложения без сети"),
    "noResolve": MessageLookupByLibrary.simpleMessage("Не разрешать IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Не разрешать имя хоста",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "Ничего не найдено",
    ),
    "nodes": MessageLookupByLibrary.simpleMessage("Узлы"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "Этот внешний ресурс не является текстовым файлом",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Нет"),
    "notRunning": MessageLookupByLibrary.simpleMessage("Не запущено"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Текущую группу прокси нельзя выбрать",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал синхронизации (минуты)",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Добавьте профиль, чтобы начать",
    ),
    "nullTip": m106,
    "numberRangeTip": m107,
    "numberTip": m108,
    "obfs": MessageLookupByLibrary.simpleMessage("Обфускация"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Хост обфускации"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Режим обфускации"),
    "obfsParam": MessageLookupByLibrary.simpleMessage("Параметр обфускации"),
    "obfsPassword": MessageLookupByLibrary.simpleMessage("Пароль обфускации"),
    "onDemand": MessageLookupByLibrary.simpleMessage("По условию"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Учитывать только трафик прокси",
    ),
    "openSettings": MessageLookupByLibrary.simpleMessage("Открыть настройки"),
    "optional": MessageLookupByLibrary.simpleMessage("Необязательно"),
    "options": MessageLookupByLibrary.simpleMessage("Опции"),
    "originalUrl": MessageLookupByLibrary.simpleMessage("Исходный URL"),
    "other": MessageLookupByLibrary.simpleMessage("Другое"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Другие участники",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Исходящие"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Выход"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("Исходящий IP"),
    "outboundMode": MessageLookupByLibrary.simpleMessage(
      "Режим исходящего трафика",
    ),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Подменять адрес назначения",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "Переопределяемые параметры",
    ),
    "overview": MessageLookupByLibrary.simpleMessage("Обзор"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Разбирать чистые IP"),
    "password": MessageLookupByLibrary.simpleMessage("Пароль"),
    "paste": MessageLookupByLibrary.simpleMessage("Вставить"),
    "peers": MessageLookupByLibrary.simpleMessage("Пиры"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Выбрать из галереи"),
    "pinWindow": MessageLookupByLibrary.simpleMessage(
      "Закрепить поверх всех окон",
    ),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Привяжите WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Введите название скрипта",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Загрузите корректный QR-код",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Плагин"),
    "pluginCipher": MessageLookupByLibrary.simpleMessage("Шифр плагина"),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Хост плагина"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Режим плагина"),
    "pluginPassword": MessageLookupByLibrary.simpleMessage("Пароль плагина"),
    "pluginPath": MessageLookupByLibrary.simpleMessage("Путь плагина"),
    "pluginUsername": MessageLookupByLibrary.simpleMessage(
      "Имя пользователя плагина",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Порт"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Введите другой порт",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Перескок портов"),
    "portTip": m109,
    "portValue": m110,
    "ports": MessageLookupByLibrary.simpleMessage("Порты"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Общий ключ"),
    "preferred": MessageLookupByLibrary.simpleMessage("Предпочтительный"),
    "prerequisites": MessageLookupByLibrary.simpleMessage(
      "Предварительные условия",
    ),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Нажмите сочетание клавиш",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Предпросмотр"),
    "previousMatch": MessageLookupByLibrary.simpleMessage(
      "Предыдущее совпадение",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("Закрытый ключ"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Пароль закрытого ключа",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Процесс"),
    "profile": MessageLookupByLibrary.simpleMessage("Профиль"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите корректный интервал"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("Введите интервал автообновления"),
    "profileDaysLeft": m111,
    "profileExpiresIn": m112,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Профиль изменён. Отключить автообновление?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите название профиля",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только для этого профиля; не добавленные параметры используют значения по умолчанию.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Действует только для этого профиля и имеет приоритет над переопределяемыми параметрами TUN в настройках сети.",
    ),
    "profileUpdatedAt": m113,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите корректный URL профиля",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Введите URL профиля",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Профили"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Сортировка профилей"),
    "project": MessageLookupByLibrary.simpleMessage("Исходный проект FlClash"),
    "protocol": MessageLookupByLibrary.simpleMessage("Протокол"),
    "protocolParam": MessageLookupByLibrary.simpleMessage("Параметр протокола"),
    "protocolVersion": MessageLookupByLibrary.simpleMessage("Версия протокола"),
    "providerInUse": m114,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Поддерживаются только удалённые ресурсы",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Внешние ресурсы"),
    "proxies": MessageLookupByLibrary.simpleMessage("Прокси"),
    "proxiesCount": m115,
    "proxiesProfileLabel": m116,
    "proxiesRemovedTip": m117,
    "proxiesReplacedTip": m118,
    "proxyChains": MessageLookupByLibrary.simpleMessage("Цепочка прокси"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Группа прокси"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Группа прокси пуста",
    ),
    "proxyGroupInUse": m119,
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Группы появятся здесь после запуска ядра",
    ),
    "proxyGroupsCount": m120,
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Провайдеры прокси"),
    "proxyServerNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Используется только для разрешения имён прокси-серверов.",
    ),
    "proxyServerNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Совпавшие имена прокси-серверов используют указанный здесь DNS-сервер вместо Proxy Server Nameserver.",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Тип прокси"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Очистить кэш"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Открытый ключ"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Чисто чёрный"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Чисто чёрный режим"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR-код"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Сканируйте QR-код, чтобы получить профиль",
    ),
    "qrcodeTooLongTip": MessageLookupByLibrary.simpleMessage(
      "Ссылка слишком длинная для QR-кода. Используйте «Копировать ссылку».",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("Быстрые действия"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Быстрое редактирование"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Последние запросы"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Рекомендуемые"),
    "recordType": MessageLookupByLibrary.simpleMessage("Тип записи"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Порт Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Повторить"),
    "regenerateCertificate": MessageLookupByLibrary.simpleMessage(
      "Пересоздать сертификат",
    ),
    "regenerateCertificateTip": MessageLookupByLibrary.simpleMessage(
      "Новый сертификат заменит текущий; Flash по возможности удалит текущий из доверенных корневых сертификатов этого устройства. На каждое другое устройство, доверяющее текущему, нужно установить новый.",
    ),
    "regex": MessageLookupByLibrary.simpleMessage("Регулярное выражение"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Освободить память"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось освободить память",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Удалённо"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Удалённое назначение",
    ),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Удалённое разрешение DNS",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Убрать"),
    "rename": MessageLookupByLibrary.simpleMessage("Переименовать"),
    "replace": MessageLookupByLibrary.simpleMessage("Заменить"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Заменить все"),
    "request": MessageLookupByLibrary.simpleMessage("Запрос"),
    "requestBody": MessageLookupByLibrary.simpleMessage("Тело запроса"),
    "requestHeaders": MessageLookupByLibrary.simpleMessage("Заголовки запроса"),
    "requests": MessageLookupByLibrary.simpleMessage("Запросы"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Запросы и обновления",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Обязательно"),
    "reset": MessageLookupByLibrary.simpleMessage("Сброс"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "На этой странице есть изменения. Вы уверены, что хотите выполнить сброс?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите выполнить сброс?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "Интервал автообновления должен быть больше 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ресурсы"),
    "respectRules": MessageLookupByLibrary.simpleMessage("Соблюдать правила"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "«Соблюдать правила» направляет DNS-соединения по правилам; нужен Proxy Server Nameserver.",
    ),
    "response": MessageLookupByLibrary.simpleMessage("Ответ"),
    "responseBody": MessageLookupByLibrary.simpleMessage("Тело ответа"),
    "responseCode": MessageLookupByLibrary.simpleMessage("Код ответа"),
    "responseHeaders": MessageLookupByLibrary.simpleMessage("Заголовки ответа"),
    "restart": MessageLookupByLibrary.simpleMessage("Перезапустить"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Вы уверены, что хотите перезапустить ядро?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Восстановить"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Восстановить все данные",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Восстановить только профили",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия восстановления",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Совместимость",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage(
      "Перезапись",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Восстановление выполнено",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Результат"),
    "retry": MessageLookupByLibrary.simpleMessage("Повторить"),
    "root": MessageLookupByLibrary.simpleMessage("Root"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Адреса маршрутов"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Исключённые адреса маршрутов",
    ),
    "routingMark": MessageLookupByLibrary.simpleMessage("Метка маршрутизации"),
    "ru": MessageLookupByLibrary.simpleMessage("Русский"),
    "rule": MessageLookupByLibrary.simpleMessage("Правило"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить полный домен",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ключевое слово в домене",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению домена",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить суффикс домена",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставление по маске; поддерживаются только * и ?",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить метку DSCP (только для входящих tproxy UDP)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов назначения",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP-адреса",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить домены из Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя входящего подключения",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить входящий порт",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить тип входящего подключения",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя пользователя входящего подключения; несколько имён разделяются /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN, которой принадлежит IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов; IP-CIDR6 — просто псевдоним",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставляет все запросы, условия не нужны",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить TCP или UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage(
      "Логическое правило OR",
    ),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по имени процесса; на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению имени процесса; на Android соответствует имени пакета",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по маске имени процесса; поддерживаются только * и ?",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по полному пути процесса",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по регулярному выражению пути процесса",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить по маске пути процесса; поддерживаются только * и ?",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить имя повторного сопоставления; несколько имён разделяются /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Ссылка на набор правил; требуется настроить rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить код страны IP источника",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить ASN IP источника",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон IP-адресов источника",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон суффиксов IP источника",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить диапазон портов источника",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Переход к подправилу; обратите внимание на скобки",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Сопоставить Linux USER ID",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Правило пусто"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "Правила должны быть YAML-списком, по одному правилу в элементе, например - DOMAIN,example.com,DIRECT",
    ),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent напрямую",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Блокировать DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Защита от петли прокси",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage(
      "Блокировать QUIC",
    ),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage(
      "Блокировать STUN",
    ),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage(
      "Локальная сеть напрямую",
    ),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple и Microsoft напрямую",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Провайдеры правил"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Набор правил"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "В наборе правил нет пригодных записей",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Не удаётся прочитать этот файл mrs",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "Набор правил смешивает домены и диапазоны IP, поэтому его тип не определить",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Цель правила"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "Правило должно начинаться с поддерживаемого типа, например DOMAIN,example.com,DIRECT",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Правила"),
    "rulesCount": m121,
    "runTime": MessageLookupByLibrary.simpleMessage("Время работы"),
    "running": MessageLookupByLibrary.simpleMessage("Работает"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Конфигурация выполнения",
    ),
    "safeMode": MessageLookupByLibrary.simpleMessage("Безопасный режим"),
    "safeModeAppTitle": m122,
    "saturation": MessageLookupByLibrary.simpleMessage("Насыщенность"),
    "save": MessageLookupByLibrary.simpleMessage("Сохранить"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Сохранить изменения?"),
    "script": MessageLookupByLibrary.simpleMessage("Скрипт"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Режим скрипта: переписывает весь профиль скриптом расширения",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Прокрутить к выбранному",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Поиск"),
    "seconds": MessageLookupByLibrary.simpleMessage("секунд"),
    "secondsCount": m123,
    "secretKey": MessageLookupByLibrary.simpleMessage("Ключ"),
    "sectionsInEffect": m124,
    "select": MessageLookupByLibrary.simpleMessage("Выбрать"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Выбрать всё"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Выберите набор правил",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Выберите стратегию распределения",
    ),
    "send": MessageLookupByLibrary.simpleMessage("Отправить"),
    "sendFromPhone": MessageLookupByLibrary.simpleMessage(
      "Отправить с телефона",
    ),
    "sendFromPhoneConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Импортировать ссылку с телефона?",
    ),
    "sendFromPhoneNoNetwork": MessageLookupByLibrary.simpleMessage(
      "Это устройство не подключено к локальной сети",
    ),
    "sendFromPhonePageHint": MessageLookupByLibrary.simpleMessage(
      "Ссылка на подписку или ссылка на прокси",
    ),
    "sendFromPhonePageSent": MessageLookupByLibrary.simpleMessage(
      "Отправлено. Подтвердите импорт на другом устройстве.",
    ),
    "sendFromPhonePageTitle": MessageLookupByLibrary.simpleMessage(
      "Отправить ссылку в Flash",
    ),
    "sendFromPhonePermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Чтобы получить ссылку с телефона, Flash нужно разрешение «Устройства поблизости» для доступа к локальной сети. Включите его в настройках приложения.",
    ),
    "sendFromPhoneTip": MessageLookupByLibrary.simpleMessage(
      "Отсканируйте код камерой телефона и вставьте ссылку на открывшейся странице. Оба устройства должны быть в одной сети.",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Сервер"),
    "serviceAbnormalCount": m125,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage("Все доступны"),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Доступен"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Заблокировано"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Проверить все"),
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("Скоро появится"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "Недопустимый провайдер",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage("Ошибка проверки"),
    "serviceManage": MessageLookupByLibrary.simpleMessage(
      "Управление сервисами",
    ),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Только оригиналы",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Не проверено"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Доступ ограничен",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Показан на панели",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("Состояние сервисов"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("Недоступен"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Регион не поддерживается",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("параметры"),
    "settings": MessageLookupByLibrary.simpleMessage("Настройки"),
    "settingsCount": m126,
    "shareLinkUnreadable": m127,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "Не удалось прочитать прокси из ссылок",
    ),
    "shareQrcodeTip": MessageLookupByLibrary.simpleMessage(
      "Отсканируйте в Flash на другом устройстве, чтобы импортировать этот профиль.",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Показать"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Показывать скрытые группы",
    ),
    "showLess": MessageLookupByLibrary.simpleMessage("Свернуть"),
    "showMore": MessageLookupByLibrary.simpleMessage("Развернуть"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Кнопка остановки в уведомлении",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Показать пароль"),
    "sidebar": MessageLookupByLibrary.simpleMessage("Боковая панель"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Тихий запуск"),
    "singleImport": MessageLookupByLibrary.simpleMessage("По одному"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Здесь укажите одну ссылку, несколько можно задать в быстром редактировании списка",
    ),
    "singleValueTip": m128,
    "size": MessageLookupByLibrary.simpleMessage("Размер"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Пропускать проверку сертификата",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Пропускаемые домены"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Пропускаемые адреса назначения",
    ),
    "skipServerCertVerify": MessageLookupByLibrary.simpleMessage(
      "Пропускать проверку сертификата сервера",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Пропускаемые адреса источника",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Сдвиг"),
    "sliders": MessageLookupByLibrary.simpleMessage("Ползунки"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Протоколы"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Сниффер"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Порт SOCKS"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Мягкий"),
    "sort": MessageLookupByLibrary.simpleMessage("Сортировка"),
    "source": MessageLookupByLibrary.simpleMessage("Источник"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP источника"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Специальный прокси"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Специальные правила"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Спектр"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Статистика скорости",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Стратегия распределения",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Стратегия распределения не может быть пустой",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("Список SSID пуст"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Режим стека"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Трассировка стека"),
    "standard": MessageLookupByLibrary.simpleMessage("Стандартный"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Стандартный режим: добавляет правила поверх профиля",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Старт"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("С нуля"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Запуск VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Запуск и фоновая работа",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Статус"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "При отключённом DNS используется системный DNS.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Стоп"),
    "stopUpdateDownloadTip": MessageLookupByLibrary.simpleMessage(
      "Остановить загрузку обновления?",
    ),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Остановка VPN…"),
    "strategy": MessageLookupByLibrary.simpleMessage("Стратегия"),
    "strictRoute": MessageLookupByLibrary.simpleMessage(
      "Строгая маршрутизация",
    ),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "Строгая маршрутизация не даёт трафику вроде DNS обходить TUN, а при выключенном IPv6 блокирует IPv6-соединения этого устройства.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Стиль"),
    "submit": MessageLookupByLibrary.simpleMessage("Отправить"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Информация о подписке",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Введите пароль для sudo",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Приостановлено…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Сменить профиль"),
    "sync": MessageLookupByLibrary.simpleMessage("Синхронизация"),
    "system": MessageLookupByLibrary.simpleMessage("Система"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Системные приложения"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Системный прокси"),
    "tab": MessageLookupByLibrary.simpleMessage("Вкладки"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Анимация вкладок"),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Нажмите на значок, чтобы повторить",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Нажмите, чтобы разрешить",
    ),
    "target": MessageLookupByLibrary.simpleMessage("Цель"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("Параллельный TCP"),
    "testInterval": MessageLookupByLibrary.simpleMessage(
      "Интервал тестирования",
    ),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL для теста"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage(
      "Тестировать при использовании",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Масштаб текста"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Так будет выглядеть текст в приложении",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Тема"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Цвет темы"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Режим темы"),
    "tight": MessageLookupByLibrary.simpleMessage("Плотный"),
    "time": MessageLookupByLibrary.simpleMessage("Время"),
    "timeToFirstByte": MessageLookupByLibrary.simpleMessage(
      "Время до первого байта",
    ),
    "timeout": MessageLookupByLibrary.simpleMessage("Тайм-аут"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Тонированный"),
    "tip": MessageLookupByLibrary.simpleMessage("Подсказка"),
    "toggle": MessageLookupByLibrary.simpleMessage("Переключить"),
    "tolerance": MessageLookupByLibrary.simpleMessage("Допуск"),
    "tools": MessageLookupByLibrary.simpleMessage("Инструменты"),
    "torch": MessageLookupByLibrary.simpleMessage("Фонарик"),
    "total": MessageLookupByLibrary.simpleMessage("Всего"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Загружено"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Общий трафик"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Отдано"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Порт TProxy"),
    "traffic": MessageLookupByLibrary.simpleMessage("Трафик"),
    "trafficPeak": m129,
    "trafficTotal": m130,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Статистика трафика"),
    "transport": MessageLookupByLibrary.simpleMessage("Транспорт"),
    "transportHeaders": m131,
    "trustCertificate": MessageLookupByLibrary.simpleMessage(
      "Доверять сертификату",
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
    "tsAssignedTo": m132,
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
    "tsCandidate": m133,
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
    "tsConflictTitle": m134,
    "tsControlServer": MessageLookupByLibrary.simpleMessage("Control server"),
    "tsCopyAddress": MessageLookupByLibrary.simpleMessage("Copy address"),
    "tsCoreStopped": MessageLookupByLibrary.simpleMessage(
      "Core is not running",
    ),
    "tsCoreStoppedTip": MessageLookupByLibrary.simpleMessage(
      "Start the core to see this node\'s Tailscale status.",
    ),
    "tsCurrentDevice": MessageLookupByLibrary.simpleMessage("This device"),
    "tsDeleteProfileManaged": m135,
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
    "tsDevicesCompact": m136,
    "tsDevicesCompactFiltered": m137,
    "tsDevicesEmpty": MessageLookupByLibrary.simpleMessage(
      "No visible devices",
    ),
    "tsDevicesEmptyTip": MessageLookupByLibrary.simpleMessage(
      "This node doesn\'t see any other devices yet.",
    ),
    "tsDevicesFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t load the device list. Try again.",
    ),
    "tsDevicesFiltered": m138,
    "tsDevicesScope": MessageLookupByLibrary.simpleMessage(
      "Devices this node can see, not every device in the admin console",
    ),
    "tsDevicesShown": m139,
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
    "tsExitChangeBody": m140,
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
    "tsExitOffBody": m141,
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
    "tsExpiryTip": m142,
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
    "tsLegacyConfirmAccount": m143,
    "tsLegacyConfirmBody": MessageLookupByLibrary.simpleMessage(
      "This copies the login record for the node above and leaves the original untouched. The same record can\'t move to another node afterwards. Check the node\'s real connection status after the move.",
    ),
    "tsLegacyConfirmControl": m144,
    "tsLegacyConfirmNode": m145,
    "tsLegacyConfirmProfile": m146,
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
    "tsLogoutBody": m147,
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
    "tsNetworkOf": m148,
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
    "tsNodeOf": m149,
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
    "tsRemoveBody": m150,
    "tsRemoveBodyNode": m151,
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
    "tsRulesAddresses": m152,
    "tsRulesDomain": m153,
    "tsRulesManaged": MessageLookupByLibrary.simpleMessage(
      "Flash updates dedicated rules using this account’s network domain and device addresses. Other traffic keeps its existing routing, and the original profile file stays unchanged.",
    ),
    "tsRulesPending": MessageLookupByLibrary.simpleMessage(
      "Once added, Tailscale addresses and ts.net domains will use dedicated rules. Other traffic will keep its existing routing.",
    ),
    "tsRulesProfileNode": MessageLookupByLibrary.simpleMessage(
      "Only traffic routed to this node by Flash rules uses Tailscale. Signing in to this node does not change existing rules or enable system proxy or TUN.",
    ),
    "tsRulesSummary": m154,
    "tsRulesUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Domain and address details are unconfirmed.",
    ),
    "tsSaveChoices": MessageLookupByLibrary.simpleMessage("Save choices"),
    "tsSavedValue": m155,
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
    "tsSharedBy": m156,
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
    "tsSignOutAccountBody": m157,
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
    "tsStatusOf": m158,
    "tsStatusUnknown": MessageLookupByLibrary.simpleMessage("Status unknown"),
    "tsStoppedTip": MessageLookupByLibrary.simpleMessage(
      "This node has stopped and can\'t reach the Tailscale network for now.",
    ),
    "tsSubnetRoutes": MessageLookupByLibrary.simpleMessage("Subnet routes"),
    "tsSwitcherSemantics": m159,
    "tsSystem": MessageLookupByLibrary.simpleMessage("OS"),
    "tsSystemMissing": MessageLookupByLibrary.simpleMessage("OS not provided"),
    "tsTargetAddress": m160,
    "tsTargetDomain": m161,
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
      "Не удалось получить права для TUN, поэтому он выключен.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN работает только в режиме администратора.",
    ),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Добавленные здесь параметры заменяют настройки TUN всех профилей; остальные остаются такими, как в профиле. Параметры, добавленные в самом пользовательском профиле, имеют приоритет.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Выключить"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Включить"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage(
      "Режим ретрансляции UDP",
    ),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("Тайм-аут UDP"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "Тайм-аут UDP задаётся в секундах и действует только со стеками gvisor, system и mixed.",
    ),
    "ultra": MessageLookupByLibrary.simpleMessage("Максимум"),
    "undo": MessageLookupByLibrary.simpleMessage("Отменить"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Единая задержка"),
    "unknown": MessageLookupByLibrary.simpleMessage("Неизвестно"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Неизвестная сетевая ошибка",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Свернуть в окно"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Без названия"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Открепить окно"),
    "update": MessageLookupByLibrary.simpleMessage("Обновить"),
    "updateCheckFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t check for updates. Please try again.",
    ),
    "updateDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось загрузить обновление.",
    ),
    "updateDownloadStarted": MessageLookupByLibrary.simpleMessage(
      "Загрузка обновления началась. Следите за ходом на главной странице.",
    ),
    "updateDownloadTest": MessageLookupByLibrary.simpleMessage(
      "Тест загрузки обновления",
    ),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Не удалось обновить"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "Не удалось установить обновление. Его можно скачать на странице релиза.",
    ),
    "updateNoReleaseFound": MessageLookupByLibrary.simpleMessage(
      "No Flash release found yet",
    ),
    "updateNotVerified": MessageLookupByLibrary.simpleMessage(
      "Не удалось проверить загруженное обновление.",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Обновление готово"),
    "updateReadyTip": MessageLookupByLibrary.simpleMessage(
      "Обновление загружено. Нажмите, чтобы установить.",
    ),
    "updateRestartTip": MessageLookupByLibrary.simpleMessage(
      "Flash закроется для установки обновления и снова откроется после завершения.",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("Отдача"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage("Скорость отдачи"),
    "upstreamTelegram": MessageLookupByLibrary.simpleMessage(
      "Telegram исходного проекта FlClash",
    ),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlRewrite": MessageLookupByLibrary.simpleMessage("Перезапись URL"),
    "urlTip": m162,
    "useHosts": MessageLookupByLibrary.simpleMessage("Использовать hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Использовать системный hosts",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("использовано"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage(
      "Использованный трафик",
    ),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Имя пользователя"),
    "validUntil": m163,
    "value": MessageLookupByLibrary.simpleMessage("Значение"),
    "view": MessageLookupByLibrary.simpleMessage("Просмотр"),
    "viewAll": MessageLookupByLibrary.simpleMessage("Показать всё"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("Виртуальный IPv4"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Яркий"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "Настройки VPN изменены. Нажмите, чтобы перезапустить",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Настройка WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage(
      "Режим белого списка",
    ),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Записывать в систему",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "«Записывать в систему» также устанавливает системные часы; Android это игнорирует.",
    ),
    "yearsAgo": m164,
    "yearsAgoShort": m165,
    "yes": MessageLookupByLibrary.simpleMessage("Да"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Упрощённый китайский"),
  };
}
