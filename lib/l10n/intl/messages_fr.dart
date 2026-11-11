// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
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
  String get localeName => 'fr';

  static String m0(count) =>
      "${Intl.plural(count, one: '${count} sélectionnée', other: '${count} sélectionnées')}";

  static String m1(name) => "${name} ajouté aux proxys locaux";

  static String m2(name) => "${name} est déjà dans les proxys locaux";

  static String m3(count, skipped) =>
      "${count} à ajouter, ${skipped} ignorés car déjà présents";

  static String m4(detail) => "Impossible d’effacer les données : ${detail}";

  static String m5(code) =>
      "Windows a refusé d’exécuter FlClashCore.exe (erreur ${code}). Une stratégie de contrôle des applications, telle que Smart App Control ou AppLocker, bloque les programmes non signés ; autorisez Flash dans cette stratégie ou désactivez-la, puis réessayez.";

  static String m6(name) =>
      "L’app n’a pas réussi à finir de démarrer deux fois de suite. Pour sortir de cette boucle, le profil ${name} a été désélectionné et la configuration automatique a été ignorée. Vous pouvez le sélectionner de nouveau à tout moment.";

  static String m7(url) => "Créer un profil à partir de ${url} ?";

  static String m8(count, label) =>
      "${Intl.plural(count, one: '1 règle SUB-RULE a été abandonnée, car les profils personnalisés ne prennent pas en charge les sous-règles', other: '${label} règles SUB-RULE ont été abandonnées, car les profils personnalisés ne prennent pas en charge les sous-règles')}";

  static String m9(message) =>
      "Le cœur ne peut pas analyser ce proxy : ${message}";

  static String m10(proxy, target) =>
      "${proxy} se connecte via ${target}, qui renvoie à ${proxy} ; la connexion boucle";

  static String m11(name) =>
      "Le nom ${name} est déjà utilisé par un autre proxy ou groupe de proxys";

  static String m12(path) =>
      "Les groupes de proxys se référencent mutuellement en boucle : ${path}";

  static String m13(name) =>
      "Le repli si vide doit être un proxy, mais ${name} n’existe pas ou est un groupe de proxys";

  static String m14(name, message) =>
      "${name} n’est pas une regex valide : ${message}";

  static String m15(name) => "Le proxy de connexion ${name} n’existe pas";

  static String m16(names) =>
      "Ces fournisseurs de proxys n’existent pas : ${names}";

  static String m17(names) =>
      "Ces proxys ou stratégies n’existent pas : ${names}";

  static String m18(name) =>
      "${name} est un nom de stratégie intégré et ne peut pas être utilisé ici";

  static String m19(count) =>
      "${count} éléments posent problème, et l’application de ce profil peut échouer";

  static String m20(count) =>
      "${Intl.plural(count, one: 'il y a 1 jour', other: 'il y a ${count} jours')}";

  static String m21(count) =>
      "${Intl.plural(count, other: 'il y a ${count} j')}";

  static String m22(label) =>
      "Voulez-vous vraiment supprimer les éléments sélectionnés (${label}) ?";

  static String m23(label) =>
      "Voulez-vous vraiment supprimer cet élément (${label}) ?";

  static String m24(label) => "Détails de ${label}";

  static String m25(name) =>
      "La connexion via ${name} renvoie au proxy qui l’utilise ; la connexion a donc été arrêtée";

  static String m26(label) => "${label} ne peut pas être vide";

  static String m27(label) => "${label} existe déjà";

  static String m28(count) =>
      "${count} éléments en échec. Appuyez pour afficher";

  static String m29(label, message) => "${label} : ${message}";

  static String m30(name) => "${name} est déjà à jour";

  static String m31(name) => "${name} mis à jour";

  static String m32(count) =>
      "${Intl.plural(count, one: '1 groupe', other: '${count} groupes')}";

  static String m33(count) => "${count} expirés";

  static String m34(action) =>
      "Déjà utilisé par « ${action} ». L’enregistrer le déplace ici.";

  static String m35(modifiers) =>
      "Incluez au moins l’une de ces touches : ${modifiers}";

  static String m36(count) =>
      "${Intl.plural(count, one: 'il y a 1 heure', other: 'il y a ${count} heures')}";

  static String m37(count) =>
      "${Intl.plural(count, other: 'il y a ${count} h')}";

  static String m38(encoding) =>
      "Impossible de décoder ${encoding}, les données sont affichées telles qu’envoyées.";

  static String m39(memory, body) =>
      "Les plus anciens enregistrements sont supprimés en premier une fois ce nombre atteint ou ${memory} de mémoire occupés. Seuls les premiers ${body} de chaque corps sont conservés.";

  static String m40(invalid, total) => "${invalid} sur ${total} invalides";

  static String m41(target) => "${target} n’est pas une stratégie valide";

  static String m42(proxyName) => "${proxyName} n’est pas un proxy valide";

  static String m43(providerName) =>
      "${providerName} n’est pas un fournisseur de proxys valide";

  static String m44(ruleSet) => "${ruleSet} n’est pas un jeu de règles valide";

  static String m45(subRule) => "${subRule} n’est pas un SUB_RULE valide";

  static String m46(count) =>
      "${Intl.plural(count, one: '1 élément', other: '${count} éléments')}";

  static String m47(line, message) => "Ligne ${line} : ${message}";

  static String m48(appName) =>
      "1. Ouvrez Réglages système > Confidentialité et sécurité\n2. Choisissez Service de localisation\n3. Trouvez ${appName} dans la liste et cochez-le\n\nUne fois terminé, revenez dans l’app pour continuer. Merci de votre coopération.";

  static String m49(label, max) =>
      "${label} ne doit pas dépasser ${max} caractères";

  static String m50(size) => "${size} libérés";

  static String m51(count) =>
      "${Intl.plural(count, one: 'il y a 1 minute', other: 'il y a ${count} minutes')}";

  static String m52(count) =>
      "${Intl.plural(count, other: 'il y a ${count} min')}";

  static String m53(fileName) =>
      "${fileName} est enregistré dans Téléchargements. Installez-le dans Paramètres › Sécurité › Chiffrement et identifiants › Installer un certificat › Certificat CA.";

  static String m54(command) =>
      "Chrome et Firefox ont leurs propres magasins de certificats, qui nécessitent certutil : ${command}";

  static String m55(host) =>
      "Ajouter ${host} à la liste des noms d’hôte ? Flash pourra lire ce qui lui est envoyé, cookies et mots de passe compris.";

  static String m56(host) =>
      "Ajouter -${host} en tête de la liste des noms d’hôte ? L’hôte ne sera alors plus jamais déchiffré.";

  static String m57(size) => "Le fichier dépasse ${size} Mo";

  static String m58(stores) => "Pas encore dans : ${stores}";

  static String m59(name) =>
      "Les scripts de ${name} ont changé : le module a été désactivé";

  static String m60(system) =>
      "Écrit pour ${system} ; certaines lignes peuvent ne pas correspondre aux applications de cet appareil.";

  static String m61(name) =>
      "Impossible de supprimer l’ancien certificat, ${name}. Retirez-le vous-même des racines de confiance.";

  static String m62(name) =>
      "L’ancien certificat, ${name}, figure toujours parmi les certificats de confiance du système. Autorisez l’accès root à Flash dans votre gestionnaire root puis régénérez-le, ou supprimez-y le module « FlClash MITM CA » et redémarrez.";

  static String m63(name) =>
      "Supprimez l’ancien certificat, ${name}, dans Paramètres › Sécurité › Chiffrement et identifiants › Identifiants de confiance › Utilisateur, puis installez le nouveau.";

  static String m64(section) =>
      "La section [${section}] n’est pas prise en charge";

  static String m65(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start.";

  static String m66(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start. System proxy settings were not changed.";

  static String m67(count) =>
      "${Intl.plural(count, one: 'il y a 1 mois', other: 'il y a ${count} mois')}";

  static String m68(count) =>
      "${Intl.plural(count, other: 'il y a ${count} m')}";

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
      "Le serveur a refusé l’accès (HTTP ${code}). Le lien a peut-être expiré, ou les identifiants sont incorrects";

  static String m90(code) => "Le serveur a rejeté la requête (HTTP ${code})";

  static String m91(code) =>
      "Rien n’a été trouvé à cette adresse (HTTP ${code}). Vérifiez que l’URL est correcte";

  static String m92(detail) => "Échec de la requête réseau : ${detail}";

  static String m93(code) =>
      "Le serveur a rencontré un problème (HTTP ${code}). Réessayez plus tard";

  static String m94(label) => "Aucun élément (${label}) pour le moment";

  static String m95(label, min, max) =>
      "${label} doit être compris entre ${min} et ${max}";

  static String m96(label) => "${label} doit être un nombre";

  static String m97(label) => "${label} doit être compris entre 1024 et 49151";

  static String m98(port) => "Port ${port}";

  static String m99(days) =>
      "${Intl.plural(days, one: '1 jour restant', other: '${days} jours restants')}";

  static String m100(date, days) =>
      "Expire le ${date}, ${Intl.plural(days, one: '1 jour restant', other: '${days} jours restants')}";

  static String m101(time) => "Mis à jour ${time}";

  static String m102(label, profiles) =>
      "${label} est encore utilisé par ${profiles}, qui ne fonctionneront plus correctement s’il est supprimé. Voulez-vous vraiment le supprimer ?";

  static String m103(count, label) =>
      "${Intl.plural(count, one: '1 proxy', other: '${label} proxys')}";

  static String m104(name, count) => "${name} et autres (${count} proxys)";

  static String m105(removed) =>
      "Ces proxys seront supprimés : ${removed}. Une ligne dont le nom a changé compte comme un nouveau proxy, et les profils personnalisés qui nomment les proxys supprimés les signaleront comme manquants. Appliquer quand même ?";

  static String m106(removed, added) =>
      "Ces proxys seront supprimés : ${removed}. Ceux-ci seront ajoutés : ${added}. Une ligne dont le nom a changé compte comme un nouveau proxy, et les profils personnalisés qui nomment les proxys supprimés les signaleront comme manquants. Appliquer quand même ?";

  static String m107(label) =>
      "${label} est encore nommé par des règles, des groupes de proxys, des proxys de connexion, le DNS ou le NTP de ce profil, qui cesseront de fonctionner s’il est supprimé. Voulez-vous vraiment le supprimer ?";

  static String m108(count, label) =>
      "${Intl.plural(count, one: '1 groupe de proxys', other: '${label} groupes de proxys')}";

  static String m109(count, label) =>
      "${Intl.plural(count, one: '1 règle', other: '${label} règles')}";

  static String m110(appName) => "${appName} (mode sans échec)";

  static String m111(count) =>
      "${Intl.plural(count, one: '1 seconde', other: '${count} secondes')}";

  static String m112(count) => "${count} actifs";

  static String m113(count) =>
      "${Intl.plural(count, one: '1 problème', other: '${count} problèmes')}";

  static String m114(count) =>
      "${Intl.plural(count, one: '1 réglage', other: '${count} réglages')}";

  static String m115(link) => "Aucun proxy n’a pu être lu dans ${link}";

  static String m116(label) => "${label} doit être un seul élément";

  static String m117(value) => "Pic ${value}";

  static String m118(value) => "Total ${value}";

  static String m119(transport) => "En-têtes ${transport}";

  static String m120(account) => "Assigned: ${account}";

  static String m121(account, network) => "${account} · ${network}";

  static String m122(count) => "Choose accounts for ${count} targets";

  static String m123(count) =>
      "This profile has ${count} panel-added Tailscale accounts. Deleting it removes their profile bindings, target assignments, and dedicated routing and blocking rules. Local sign-in archives are kept. Devices in the Tailscale admin console are not deleted. Other profiles are not affected.";

  static String m124(count) =>
      "${Intl.plural(count, one: '1 device · Only devices visible to this account', other: '${count} devices · Only devices visible to this account')}";

  static String m125(shown, total) =>
      "Showing ${shown}/${total} · Devices visible to this account only";

  static String m126(n) => "Showing ${n} devices";

  static String m127(node, device) =>
      "Sets the exit node of “${node}” to “${device}”. Connections through this node may drop; Flash rules stay the same.";

  static String m128(node) =>
      "Only turns off exit forwarding for “${node}”; it doesn\'t log out of Tailscale and Flash rules stay the same.";

  static String m129(time) =>
      "Authentication expires at ${time}. Log in again before then.";

  static String m130(account) => "Account: ${account}";

  static String m131(server) => "Control server: ${server}";

  static String m132(name) => "Node: ${name}";

  static String m133(name) => "Profile: ${name}";

  static String m134(name) =>
      "This logs out of “${name}” and clears the login identity this Mac keeps for it. Connections through this node may drop; other nodes are not affected.";

  static String m135(name) => "Network: ${name}";

  static String m136(name) => "Node ${name}";

  static String m137(account, node, profile) =>
      "This signs out “${account}” (node “${node}”), clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m138(node, profile) =>
      "This signs out “${node}”, clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m139(count) => "Device addresses: ${count}";

  static String m140(domain) => "Network domain: ${domain}";

  static String m141(value) => "Saved: ${value}";

  static String m142(name) => "Shared by: ${name}";

  static String m143(account, node) =>
      "This signs out “${account}” (node “${node}”) and clears its sign-in from this Mac. Its panel entry and target assignments stay saved. Connections through this account may be interrupted and will not switch to another account or a direct connection. Other accounts will not be signed out. You must choose Sign in to use this account again.";

  static String m144(label) => "Status: ${label}";

  static String m145(account, status, count) =>
      "Viewing Tailscale account: ${account}, ${status}. ${count} entries.";

  static String m146(address) => "Address: ${address}";

  static String m147(domain) => "Domain: ${domain}";

  static String m148(label) => "${label} doit être une URL";

  static String m149(date) => "Valide jusqu’au ${date}";

  static String m150(count) =>
      "${Intl.plural(count, one: 'il y a 1 an', other: 'il y a ${count} ans')}";

  static String m151(count) =>
      "${Intl.plural(count, other: 'il y a ${count} a')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("À propos"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Contrôle d’accès"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Seules les apps sélectionnées passent par le VPN",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôle d’accès des apps est désactivé",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Les apps sélectionnées sont exclues du VPN",
    ),
    "accessControlSelectedCount": m0,
    "account": MessageLookupByLibrary.simpleMessage("Compte"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Tester tous les délais",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Mode direct"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("Mode global"),
    "actionMode": MessageLookupByLibrary.simpleMessage("Changer de mode"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Proxy système"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Mode règles"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Démarrer/Arrêter"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Mettre à jour les profils",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Afficher/Masquer"),
    "add": MessageLookupByLibrary.simpleMessage("Ajouter"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Ajouter un proxy"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Ajouter des filtres"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Ajouter des nœuds"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Ajouter une entrée de remplacement",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Ajouter un profil"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Ajouter un groupe de proxys",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Ajouter une règle"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage(
      "Ajouter un réglage",
    ),
    "addSsid": MessageLookupByLibrary.simpleMessage("Ajouter un SSID"),
    "addToLocalProxies": MessageLookupByLibrary.simpleMessage(
      "Ajouter aux proxys locaux",
    ),
    "addedRules": MessageLookupByLibrary.simpleMessage("Règles ajoutées"),
    "addedToLocalProxies": m1,
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Paramètres supplémentaires",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage("Préfixe du nom"),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage("Suffixe du nom"),
    "address": MessageLookupByLibrary.simpleMessage("Adresse"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir une adresse WebDAV valide",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Configuration avancée",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Profil chiffré",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage("Clé secrète age"),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "Ce profil est chiffré avec age et nécessite une clé secrète age pour être déchiffré",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Accepter"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "Tous les proxys référencés",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Tous les fournisseurs de proxys référencés",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Autoriser les apps à contourner le VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Autoriser le LAN"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("IP autorisées"),
    "alreadyInLocalProxies": m2,
    "answers": MessageLookupByLibrary.simpleMessage("Réponses"),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Contrôle d’accès des apps",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage(
      "Conception de l’icône de l’app",
    ),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "Aucun proxy local",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Ajouter le DNS du système",
    ),
    "applied": MessageLookupByLibrary.simpleMessage("Appliqué"),
    "applyNow": MessageLookupByLibrary.simpleMessage("Appliquer maintenant"),
    "arguments": MessageLookupByLibrary.simpleMessage("Arguments"),
    "authentication": MessageLookupByLibrary.simpleMessage("Authentification"),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Le proxy système n’est pas appliqué tant que l’authentification est activée.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Autoriser"),
    "authorized": MessageLookupByLibrary.simpleMessage("Autorisé"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Rechercher les mises à jour automatiquement",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Fermer les connexions automatiquement",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage(
      "Inclure automatiquement",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Lancement automatique"),
    "autoRun": MessageLookupByLibrary.simpleMessage("Démarrage automatique"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Le démarrage automatique active le proxy à l’ouverture de l’app.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Définir automatiquement le DNS du système",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage(
      "Mise à jour automatique",
    ),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de mise à jour automatique",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Retour"),
    "backgroundBlur": MessageLookupByLibrary.simpleMessage(
      "Flou d’arrière-plan",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Sauvegarde"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde et restauration",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "Cette sauvegarde provient d’une version plus récente de l’app. Mettez l’app à jour avant de la restaurer",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Sauvegarde réussie"),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Infos de base"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Stratégies de base"),
    "batchImport": MessageLookupByLibrary.simpleMessage("Importation groupée"),
    "batchLineInputTip": MessageLookupByLibrary.simpleMessage(
      "Un élément par ligne",
    ),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "Un lien par ligne",
    ),
    "batchPreviewTip": m3,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "Une URL par ligne",
    ),
    "binaryData": MessageLookupByLibrary.simpleMessage("Données binaires"),
    "bind": MessageLookupByLibrary.simpleMessage("Lier"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Mode liste noire"),
    "blockQuic": MessageLookupByLibrary.simpleMessage("Bloquer QUIC"),
    "bodyRewrite": MessageLookupByLibrary.simpleMessage("Réécriture du corps"),
    "brightness": MessageLookupByLibrary.simpleMessage("Luminosité"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Domaines contournés"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines contournés ne s’appliquent que si le proxy système est activé.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Contourner les adresses privées",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Cache"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "Algorithme de cache",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Le cache est corrompu. Le vider ?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Taille du cache"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Autorisez l’accès à l’appareil photo dans les réglages du système pour scanner des codes QR, ou choisissez une image de code QR dans l’album.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Autorisation de l’appareil photo requise",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Appareil photo indisponible",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Annuler"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Tout désélectionner",
    ),
    "cannotSave": MessageLookupByLibrary.simpleMessage(
      "Enregistrement impossible",
    ),
    "certificate": MessageLookupByLibrary.simpleMessage("Certificat"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "Échec du changement de proxy ; la sélection précédente a été rétablie",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Changements majeurs",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Nouveautés"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage(
      "Corrections de bugs",
    ),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage(
      "Performances",
    ),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Annulations"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Vérifier les certificats TLS",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Sans vérification TLS, les abonnements et les sauvegardes sont exposés aux attaques de l’homme du milieu.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage(
      "Rechercher des mises à jour",
    ),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "L’app est déjà à jour",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Chiffrement"),
    "clearData": MessageLookupByLibrary.simpleMessage("Effacer les données"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "Cela supprime tous les profils, réglages et données locales, puis ferme l’app. Rouvrez-la pour repartir de zéro.",
    ),
    "clearDataFailed": m4,
    "clearDnsCache": MessageLookupByLibrary.simpleMessage("Vider le cache DNS"),
    "clearDnsCacheFailed": MessageLookupByLibrary.simpleMessage(
      "Échec du vidage du cache DNS",
    ),
    "clearSearch": MessageLookupByLibrary.simpleMessage("Effacer la recherche"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Empreinte client",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Exporter vers le presse-papiers",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Importer depuis le presse-papiers",
    ),
    "clipboardNoPackageNames": MessageLookupByLibrary.simpleMessage(
      "Aucun nom de package valide dans le presse-papiers",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de copier dans le presse-papiers. La sélection est peut-être trop volumineuse",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Fermer"),
    "closeConnection": MessageLookupByLibrary.simpleMessage(
      "Fermer la connexion",
    ),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Fermer les connexions",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Couleur"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Style de couleur"),
    "columns": MessageLookupByLibrary.simpleMessage("Colonnes"),
    "compact": MessageLookupByLibrary.simpleMessage("Compact"),
    "compatible": MessageLookupByLibrary.simpleMessage("Mode de compatibilité"),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirmer"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment effacer toutes les données ?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment supprimer ce groupe de proxys ?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment quitter la fenêtre actuelle ?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment forcer le plantage du cœur ?",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Contrôle de congestion",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Contrôle de congestion TCP",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôle de congestion TCP ne fonctionne qu’avec la pile mips.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Connecté"),
    "connecting": MessageLookupByLibrary.simpleMessage("Connexion…"),
    "connection": MessageLookupByLibrary.simpleMessage("Connexion"),
    "connectionStats": MessageLookupByLibrary.simpleMessage(
      "Statistiques de connexion",
    ),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Connexions en direct, requêtes récentes et requêtes DNS",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Connexions"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivité : "),
    "content": MessageLookupByLibrary.simpleMessage("Contenu"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Le contenu ne peut pas être vide",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Gérer les règles ajoutées globales",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copier"),
    "copyAsBase64": MessageLookupByLibrary.simpleMessage("Copier en Base64"),
    "copyAsCurl": MessageLookupByLibrary.simpleMessage("Copier en cURL"),
    "copyDestination": MessageLookupByLibrary.simpleMessage(
      "Copier la destination",
    ),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copier les variables d’environnement",
    ),
    "copyHost": MessageLookupByLibrary.simpleMessage("Copier l’hôte"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copier le lien"),
    "copyRequest": MessageLookupByLibrary.simpleMessage("Copier la requête"),
    "copyResponse": MessageLookupByLibrary.simpleMessage("Copier la réponse"),
    "copyResponseBody": MessageLookupByLibrary.simpleMessage(
      "Copier le corps de la réponse",
    ),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copié avec succès"),
    "core": MessageLookupByLibrary.simpleMessage("Cœur"),
    "coreBlockedByPolicyTip": m5,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Windows Smart App Control a bloqué FlClashCore.exe car il n’est pas signé. Ouvrez Sécurité Windows → Contrôle des applications et du navigateur → Paramètres de Smart App Control, choisissez Désactivé, puis relancez Flash. Smart App Control ne peut pas être réactivé sans réinstaller Windows.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("État du cœur"),
    "country": MessageLookupByLibrary.simpleMessage("Région"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Plantage détecté"),
    "crashDetectedTip": m6,
    "crashTest": MessageLookupByLibrary.simpleMessage("Test de plantage"),
    "create": MessageLookupByLibrary.simpleMessage("Créer"),
    "createProfileFromUrlTip": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("Date de création"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Contient le bouton de démarrage et ne peut pas être retiré",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Personnalisé"),
    "customColor": MessageLookupByLibrary.simpleMessage(
      "Couleur personnalisée",
    ),
    "customImportDroppedSubRules": m8,
    "customIssueCoreRejected": m9,
    "customIssueDialerLoop": m10,
    "customIssueDuplicateName": m11,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "Le nom est vide",
    ),
    "customIssueGroupLoop": m12,
    "customIssueInvalidEmptyFallback": m13,
    "customIssueInvalidFilter": m14,
    "customIssueMissingDialer": m15,
    "customIssueMissingProviders": m16,
    "customIssueMissingProxies": m17,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "Aucun proxy ni fournisseur de proxys n’est sélectionné ; le cœur rejette donc ce groupe",
    ),
    "customIssueReservedName": m18,
    "customIssuesSummary": m19,
    "customProfile": MessageLookupByLibrary.simpleMessage("Personnalisé"),
    "customResources": MessageLookupByLibrary.simpleMessage("Personnalisé"),
    "cut": MessageLookupByLibrary.simpleMessage("Couper"),
    "dark": MessageLookupByLibrary.simpleMessage("Sombre"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Tableau de bord"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Disponibles à l’ajout",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "Échec de l’enregistrement de la modification ; elle a été annulée",
    ),
    "daysAgo": m20,
    "daysAgoShort": m21,
    "decryptUntrusted": MessageLookupByLibrary.simpleMessage(
      "Déchiffrer sans confiance locale",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Résout les noms des autres serveurs DNS. Adresses IP uniquement.",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Sélection par défaut",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Par défaut"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "La configuration doit être un mappage YAML avec un nom et un type",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Délai"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Échec"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Test de délai"),
    "delayTestTimeout": MessageLookupByLibrary.simpleMessage(
      "Délai d’expiration du test de latence",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Supprimer"),
    "deleteMultipTip": m22,
    "deleteTip": m23,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Un client proxy multiplateforme basé sur ClashMeta, simple d’utilisation, open source et sans publicité.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP de destination",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN de l’IP de destination",
    ),
    "details": m24,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Repose sur une API tierce ; à titre indicatif uniquement",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Mode développeur"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Le mode développeur est activé.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("Proxy de connexion"),
    "dialerProxyLoopStopped": m25,
    "dialog": MessageLookupByLibrary.simpleMessage("Boîte de dialogue"),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Résout les domaines des connexions directes.",
    ),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Désactiver le transfert ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Avec le transfert ICMP désactivé, TUN répond lui-même au ping, qui n’indique donc plus la latence réelle.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Désactiver le keep-alive TCP",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Désactiver UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Désactivé"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "Abandonner les modifications ?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Avertissement"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "Cette déclaration explique la nature, les risques et les responsabilités liés à l\'utilisation du Logiciel. Elle n\'ajoute aucune condition à la GPL-3.0 et ne limite aucun des droits que cette licence vous accorde, notamment ceux d\'exécuter, de copier, de modifier et de distribuer le Logiciel. En cas de divergence, la GPL-3.0 prévaut.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage(
      "Rapport avec la licence open source",
    ),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "J\'ai lu et compris cette déclaration",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "Pour confirmer que vous avez compris, lisez la déclaration suivante et cochez la case ci-dessous :",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirmer la déclaration",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "Cette déclaration peut être révisée dans les versions ultérieures ; chaque version contient celle qui s\'y applique.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Modifications de cette déclaration",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Avant d\'utiliser Flash (« le Logiciel »), lisez attentivement cette déclaration et assurez-vous de bien la comprendre. Appuyer sur « Accepter » signifie que vous avez lu et compris ce qui suit. Si vous ne souhaitez pas continuer, appuyez sur « Quitter ».",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "Dans toute la mesure permise par la loi applicable, ni les développeurs ni aucun contributeur ne sauraient être tenus responsables de dommages directs, indirects, accessoires, spéciaux, punitifs ou consécutifs résultant de l’utilisation ou de l’impossibilité d’utiliser le Logiciel, y compris, sans s’y limiter, la perte de données, les dommages matériels, les pannes réseau, l’interruption d’activité, le manque à gagner ou tout litige qui en découlerait, même s’ils ont été avertis de la possibilité de tels dommages.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Limitation de responsabilité",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est open source sous licence GPL-3.0. Selon cette licence, vous pouvez l\'exécuter, l\'étudier, le modifier et le distribuer ; lorsque vous distribuez le Logiciel ou une version modifiée, vous devez également en fournir le code source sous GPL-3.0 et conserver les mentions de droits d\'auteur d\'origine.\n\nLes composants tiers du Logiciel, y compris le noyau Clash.Meta, suivent leurs propres licences. Les auteurs d\'origine ne sont pas responsables des problèmes liés aux versions modifiées ou distribuées par d\'autres.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Licence open source",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel ne fournit lui-même aucun serveur proxy, nœud, abonnement ni service d’accès au réseau, et n’a aucun partenariat, mandat ni lien de garantie avec un quelconque fournisseur de tels services.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel ne collecte ni ne transmet vos URL d’abonnement, détails de nœuds, contenus de configuration, sites visités, historiques de connexion, contenus de trafic ou journaux. Ces données restent sur votre appareil et les développeurs n’y ont pas accès.\n\nLe Logiciel n’accède au réseau que lorsque vous utilisez une fonction qui en a besoin, par exemple pour récupérer l’URL d’abonnement que vous avez fournie lors de la mise à jour d’un profil, ou pour contacter GitHub lors de la recherche de mises à jour.\n\nLe Logiciel n’inclut aucun service d’analyse ni de rapport de plantage, sur aucune plateforme.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Collecte de données et confidentialité",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "Il vous incombe de vous assurer que l’utilisation du Logiciel est licite là où vous vivez, et vous assumez seul la responsabilité juridique de tout ce que vous faites avec lui et de ses conséquences.\n\nLes abonnements, nœuds et configurations que vous importez relèvent de votre choix. La licéité de leur source, la sécurité de leur contenu et la fiabilité de leur service sont une affaire entre vous et leurs fournisseurs.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Votre responsabilité",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Saisissez la déclaration ci-dessus",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "Ne correspond pas à la déclaration",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "Pour confirmer que vous avez compris, saisissez la déclaration suivante en entier dans le champ ci-dessous :",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Recopier la déclaration",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est un client proxy réseau open source construit sur le cœur Clash.Meta (mihomo). Il se limite à fournir des outils locaux tels que la gestion de la configuration, le routage par règles et le transfert du trafic.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Nature du logiciel",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Les liens d’abonnement, fichiers de configuration, jeux de règles, scripts, ressources externes et liens externes sont tous fournis par des tiers. Les développeurs ne peuvent ni ne vont vérifier ou garantir leur légalité, leur exactitude, leur sécurité ou leur disponibilité.\n\nTout vol de données, perte financière, bannissement de compte ou autre dommage causé par un contenu tiers se règle entre vous et le tiers concerné ; les développeurs n’en assument aucune responsabilité.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Contenus tiers",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "Toute activité commerciale menée par quiconque avec le Logiciel, y compris la distribution payante, la vente groupée ou l\'utilisation au sein d\'un service commercial, est sans lien avec les développeurs du Logiciel, qui ne l\'approuvent, ne la soutiennent ni ne la garantissent.\n\nIl vous appartient de respecter les lois du pays ou de la région où vous vous trouvez, et vous assumez les conséquences de toute utilisation illégale du Logiciel.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "À propos de l\'utilisation",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "Le Logiciel est fourni « tel quel » et « selon disponibilité », sans garantie d’aucune sorte, expresse ou implicite, y compris, sans s’y limiter, les garanties de qualité marchande, d’adéquation à un usage particulier, d’absence de contrefaçon, de disponibilité ininterrompue, d’absence d’erreurs ou d’absence de failles de sécurité.\n\nLes développeurs ne garantissent pas que le Logiciel répondra à vos besoins ni qu’il fonctionnera sans interruption ni erreur.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "Absence de garantie",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Déconnecté"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Nouvelle version disponible",
    ),
    "dnsCacheCleared": MessageLookupByLibrary.simpleMessage("Cache DNS vidé"),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Sans cette entrée, TUN détourne toutes les requêtes DNS vers le port 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Détournement DNS"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Mode DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Les entrées ajoutées ici remplacent le DNS de tous les profils URL et fichier ; tout ce qui n’est pas ajouté garde le réglage du profil. Les profils personnalisés définissent leur DNS dans leur contenu.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("Requêtes DNS"),
    "docked": MessageLookupByLibrary.simpleMessage("Ancrée"),
    "domain": MessageLookupByLibrary.simpleMessage("Domaine"),
    "done": MessageLookupByLibrary.simpleMessage("Terminé"),
    "download": MessageLookupByLibrary.simpleMessage("Réception"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Bande passante de réception",
    ),
    "downloadingUpdate": MessageLookupByLibrary.simpleMessage(
      "Téléchargement de la mise à jour",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Durée"),
    "edit": MessageLookupByLibrary.simpleMessage("Modifier"),
    "editDashboard": MessageLookupByLibrary.simpleMessage(
      "Modifier le tableau de bord",
    ),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Modifier les règles globales",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Modifier le proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Modifier le groupe de proxys",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Modifier la règle"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Modifier le SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Éditeur indisponible",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Durée"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage("Repli si vide"),
    "emptyTip": m26,
    "en": MessageLookupByLibrary.simpleMessage("Anglais"),
    "enabled": MessageLookupByLibrary.simpleMessage("Activé"),
    "entries": MessageLookupByLibrary.simpleMessage(" entrées"),
    "error": MessageLookupByLibrary.simpleMessage("Erreur"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Détails de l’erreur"),
    "es": MessageLookupByLibrary.simpleMessage("Espagnol"),
    "exclude": MessageLookupByLibrary.simpleMessage(
      "Masquer des tâches récentes",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Ports de destination exclus",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage("Filtre d’exclusion"),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces exclues",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Ports source exclus",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("SSID exclus"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "Lorsque vous êtes connecté à un Wi-Fi dont le SSID est exclu, l’état d’exécution de l’app change automatiquement.",
    ),
    "excludeUid": MessageLookupByLibrary.simpleMessage("ID utilisateur exclus"),
    "existsTip": m27,
    "exit": MessageLookupByLibrary.simpleMessage("Quitter"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Quitter le plein écran",
    ),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Nœuds de sortie"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Statut attendu"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Date d’expiration"),
    "exportCertificate": MessageLookupByLibrary.simpleMessage(
      "Exporter le certificat",
    ),
    "exportFile": MessageLookupByLibrary.simpleMessage("Exporter le fichier"),
    "exportHar": MessageLookupByLibrary.simpleMessage("Exporter en HAR"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Exporter les journaux"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "Exportation réussie",
    ),
    "extend": MessageLookupByLibrary.simpleMessage("Extension"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Mode d’extension"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Script d’extension"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Contrôleur externe",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Le contrôleur externe permet de piloter le cœur via le port 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "Secret du contrôleur externe",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Lien externe"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Très grande"),
    "fade": MessageLookupByLibrary.simpleMessage("Fondu"),
    "failedCount": m28,
    "failedItem": m29,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Filtre Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Ces domaines reçoivent leur vraie IP au lieu d’une Fake-IP. En mode whitelist, eux seuls reçoivent une Fake-IP.",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Mode du filtre Fake-IP",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Plage Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Plage Fake-IP (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("TTL Fake-IP"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Utilisés à la place de Nameserver quand le filtre de repli juge sa réponse polluée.",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Filtre de repli"),
    "fallbackFilterDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Ces domaines sont résolus directement par Fallback.",
    ),
    "fallbackFilterGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines de ces catégories GeoSite sont résolus directement par Fallback.",
    ),
    "fallbackFilterIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Si Nameserver renvoie une IP de ces plages, la réponse de Fallback est utilisée.",
    ),
    "file": MessageLookupByLibrary.simpleMessage("Fichier"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "Le fichier a été modifié. Enregistrer les modifications ?",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("Filtrer"),
    "filters": MessageLookupByLibrary.simpleMessage("Filtres"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage(
      "Recherche de processus",
    ),
    "floating": MessageLookupByLibrary.simpleMessage("Flottante"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Suivre le profil"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Suivre le système"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Police"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Taille"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage(
      "Forcer le mappage DNS",
    ),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Forcer le mappage DNS analyse aussi les connexions dont le domaine provient d’un mappage DNS.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Domaines forcés"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines forcés sont aussi analysés ; les autres connexions qui ont déjà un domaine sont laissées telles quelles.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment forcer le redémarrage du cœur ?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("Français"),
    "general": MessageLookupByLibrary.simpleMessage("Général"),
    "generalOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Les entrées ajoutées ici remplacent le réglage correspondant de tous les profils ; tout ce qui n’est pas ajouté garde le réglage du profil, ou la valeur par défaut du cœur si le profil n’en a pas.",
    ),
    "generateCertificate": MessageLookupByLibrary.simpleMessage(
      "Générer le certificat",
    ),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m30,
    "geoUpdated": m31,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Mode Geo à faible mémoire",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Aller"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Télécharger"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Aller à la configuration des règles ajoutées",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Aller à la configuration du script",
    ),
    "grid": MessageLookupByLibrary.simpleMessage("Grille"),
    "groupBy": MessageLookupByLibrary.simpleMessage("Regrouper par"),
    "groupCount": m32,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("groupes"),
    "groupTimeoutCount": m33,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "Mettre les modifications en cache ?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Hachage par utilisateur entrant",
    ),
    "headerRewrite": MessageLookupByLibrary.simpleMessage(
      "Réécriture d’en-têtes",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage("Contrôle d’état"),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "Service Helper indisponible ; le mode TUN ne peut pas être activé. Réinstallez Flash pour le rétablir.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Masquer de la liste"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Masquer l’IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage(
      "Masquer le mot de passe",
    ),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Masquer les proxys expirés",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Intervalle de saut"),
    "host": MessageLookupByLibrary.simpleMessage("Hôte"),
    "hostname": MessageLookupByLibrary.simpleMessage("Nom d’hôte"),
    "hotkeyConflictWith": m34,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Les raccourcis globaux fonctionnent même lorsque la fenêtre est masquée. Appuyez sur une action pour enregistrer sa combinaison de touches.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Gestion des raccourcis",
    ),
    "hotkeyNeedsModifier": m35,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Non défini"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "Non enregistré, il est peut-être pris par une autre app",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("heures"),
    "hoursAgo": m36,
    "hoursAgoShort": m37,
    "http2": MessageLookupByLibrary.simpleMessage("HTTP/2"),
    "httpBodyNotKept": MessageLookupByLibrary.simpleMessage(
      "Non enregistré faute de mémoire.",
    ),
    "httpBodyProtobufGuess": MessageLookupByLibrary.simpleMessage(
      "Lu comme Protobuf sans schéma : numéros de champ uniquement, types supposés.",
    ),
    "httpBodyTruncated": MessageLookupByLibrary.simpleMessage(
      "Seul le début de ce corps a été enregistré.",
    ),
    "httpBodyUndecoded": m38,
    "httpCapture": MessageLookupByLibrary.simpleMessage("Capture HTTP"),
    "httpCaptureDesc": MessageLookupByLibrary.simpleMessage(
      "Enregistre les requêtes vers les hôtes listés dans Nom d’hôte, à consulter dans les détails de la connexion. Les enregistrements restent uniquement en mémoire.",
    ),
    "httpCaptureLimit": MessageLookupByLibrary.simpleMessage(
      "Nombre maximal d’enregistrements",
    ),
    "httpCaptureLimitDesc": m39,
    "httpCaptureNoHosts": MessageLookupByLibrary.simpleMessage(
      "Aucun hôte n’est listé, rien n’est donc enregistré. Ajoutez des hôtes dans Nom d’hôte sur la page MITM, ou depuis les détails d’une connexion.",
    ),
    "httpCaptureOff": MessageLookupByLibrary.simpleMessage(
      "La capture est désactivée",
    ),
    "httpExportPrivate": MessageLookupByLibrary.simpleMessage(
      "Une requête peut contenir des cookies, des jetons, des mots de passe et le contenu de formulaires. Vérifiez ce que vous partagez, et avec qui.",
    ),
    "httpExportPrivateTitle": MessageLookupByLibrary.simpleMessage(
      "Contient des données privées",
    ),
    "httpRequestCleared": MessageLookupByLibrary.simpleMessage(
      "L\'enregistrement de cette requête a été effacé",
    ),
    "httpRequests": MessageLookupByLibrary.simpleMessage("Requêtes HTTP"),
    "httpRequestsMissing": MessageLookupByLibrary.simpleMessage(
      "Les requêtes envoyées avant l\'activation de la capture, ou déjà effacées, ne sont pas listées.",
    ),
    "httpsDecryption": MessageLookupByLibrary.simpleMessage(
      "Déchiffrement HTTPS",
    ),
    "hue": MessageLookupByLibrary.simpleMessage("Teinte"),
    "icon": MessageLookupByLibrary.simpleMessage("Icône"),
    "iconRecords": MessageLookupByLibrary.simpleMessage(
      "Historique des icônes",
    ),
    "iconSets": MessageLookupByLibrary.simpleMessage("Jeux d’icônes"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Aucun jeu d’icônes pour le moment. Ajoutez-en dans Ressources des profils personnalisés → Jeux d’icônes",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Style des icônes"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("Pleines"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Masquées"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Simples"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL de l’icône"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignorer l’optimisation de la batterie",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Importer"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "Ce fichier n’est pas une configuration importable",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "L’importation remplace les groupes de proxys, les règles et les réglages actuels de ce profil",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage(
      "Importer depuis un fichier",
    ),
    "importFromLink": MessageLookupByLibrary.simpleMessage(
      "Importer depuis un lien",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage(
      "Importer depuis une URL",
    ),
    "inProgress": MessageLookupByLibrary.simpleMessage("En cours"),
    "inbound": MessageLookupByLibrary.simpleMessage("Entrant"),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces incluses",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Seul le trafic arrivant sur les interfaces incluses passe par TUN, et les interfaces exclues ne s’appliquent plus.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage("ID utilisateur inclus"),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("N’expire jamais"),
    "init": MessageLookupByLibrary.simpleMessage("Initialisation"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Échec du démarrage"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "Flash a rencontré une erreur au démarrage et ne peut pas continuer. Copiez les détails pour signaler le problème. Si cela se reproduit, effacer les données permet généralement de relancer l’app.",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("Initiateur"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("De"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Saisissez le nom du groupe de proxys",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez le contenu de la règle",
    ),
    "installCertificate": MessageLookupByLibrary.simpleMessage(
      "Installer dans le système",
    ),
    "installCertificateSuccess": MessageLookupByLibrary.simpleMessage(
      "Certificat installé",
    ),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "L’autorisation de la liste des apps a été refusée ; les apps installées ne peuvent donc pas être listées. Veuillez l’accorder manuellement dans les réglages du système.",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Ce système masque la liste des apps installées tant que l’autorisation n’est pas accordée. Accordez-la pour configurer le proxy par app.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Autorisation de la liste des apps requise",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage(
      "Polices installées",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Sélection intelligente",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Nom de l’interface"),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Interface sortante",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Aucune"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage(
      "Personnalisée",
    ),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Suivre la configuration",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Intervalle"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("IP du réseau local"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Fichier de sauvegarde non valide",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez une plage d’IP au format CIDR, par exemple 192.168.0.0/16",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "Une marque DSCP ne peut pas dépasser 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez un domaine ou une adresse IP",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "Jeu d’icônes non valide",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "Ce n’est ni un lien d’abonnement ni un lien de partage de proxy",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez une adresse et un port, par exemple 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Seuls tcp ou udp sont pris en charge",
    ),
    "invalidOfCount": m40,
    "invalidPolicy": m41,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez un port ou une plage, par exemple 443 ou 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "Ce code QR ne contient pas de lien de profil",
    ),
    "invalidProxy": m42,
    "invalidProxyProvider": m43,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Saisissez des nombres ou des plages tels que 80 ou 8000-9000, séparés par /",
    ),
    "invalidRuleSet": m44,
    "invalidSubRule": m45,
    "ipAddress": MessageLookupByLibrary.simpleMessage("Adresse IP"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Antécédents d’abus"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Indicateurs"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Organisation"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de déterminer le type de l’IP",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Bonne"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Niveau"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Normale"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage(
      "Vérifier à nouveau",
    ),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("À risque"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Qualité"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Réponse de"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Sources"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "IP sortante différente",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("Aucun type"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "Limite de débit atteinte",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("Type"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Entreprise"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Centre de données"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Réseau mobile"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Résidentielle"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Type inconnu"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("Version d’IP"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Le trafic IPv6 n’est reçu que si IPv6 est activé.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage(
      "Délai d’expiration IPv6 (ms)",
    ),
    "itemsCount": m46,
    "ja": MessageLookupByLibrary.simpleMessage("Japonais"),
    "justNow": MessageLookupByLibrary.simpleMessage("À l’instant"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "Inactivité keep-alive TCP",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Intervalle keep-alive TCP",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Clé"),
    "ko": MessageLookupByLibrary.simpleMessage("Coréen"),
    "label": MessageLookupByLibrary.simpleMessage("Libellé"),
    "language": MessageLookupByLibrary.simpleMessage("Langue"),
    "large": MessageLookupByLibrary.simpleMessage("Grande"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Dernière mise à jour"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "Démarrage inachevé",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "L’app s’est arrêtée de façon inattendue lors de son dernier démarrage. La configuration automatique a été ignorée pour ce lancement ; vous pouvez la démarrer manuellement pour réessayer.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Disposition"),
    "light": MessageLookupByLibrary.simpleMessage("Clair"),
    "lineIssueTip": m47,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Retour à la ligne"),
    "link": MessageLookupByLibrary.simpleMessage("Lien"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("Liste"),
    "listen": MessageLookupByLibrary.simpleMessage("Écoute"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Marque de routage d’écoute",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "La marque de routage d’écoute ne fonctionne que sous Linux.",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage(
      "Connexions en direct",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Chargement…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localImage": MessageLookupByLibrary.simpleMessage("Image locale"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Autorisation du réseau local refusée : la pile gvisor est utilisée, le LAN est inaccessible.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Proxys locaux"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Autorisation de localisation",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "L’autorisation de localisation a été refusée ; le nom du Wi-Fi actuel ne peut donc pas être lu. Veuillez l’activer manuellement dans les réglages du système.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Le système exige l’autorisation de localisation pour lire le nom du Wi-Fi. Sur Android, choisissez « Toujours autoriser », sinon le nom du Wi-Fi ne peut pas être lu lorsque l’app est en arrière-plan.",
    ),
    "locationPermissionGuide": m48,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Autorisation de localisation requise",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Journal"),
    "logLevel": MessageLookupByLibrary.simpleMessage(
      "Niveau de journalisation",
    ),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Désactiver Logcat masque l’entrée Journaux.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Journaux"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Journaux et diagnostic",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("Test des journaux"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Exemption de bouclage UWP",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Aérée"),
    "mapLocal": MessageLookupByLibrary.simpleMessage("Mappage local"),
    "matchCase": MessageLookupByLibrary.simpleMessage("Respecter la casse"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Faire correspondre l’IP source",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchedRules": MessageLookupByLibrary.simpleMessage("Règles appliquées"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Échecs maximum"),
    "maxLengthTip": m49,
    "maximize": MessageLookupByLibrary.simpleMessage("Agrandir"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Mémoire résidente",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("App et partagée"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("Tas inactif"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("Tas utilisé"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "Le cœur n’est pas en cours d’exécution",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Surcharge du runtime",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage(
      "Piles de goroutines",
    ),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Estimation d’après la mémoire résidente du processus ; elle peut différer de ce qu’indique le système.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "Le cœur s’exécute dans le processus de l’app. Sa part est estimée à partir des statistiques du runtime, et le reste compte comme mémoire de l’app et partagée.",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Infos mémoire"),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Mémoire utilisée par l’app et le cœur",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("Mémoire libérée"),
    "memoryReleasedSize": m50,
    "messageTest": MessageLookupByLibrary.simpleMessage("Test de message"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "Ceci est un message.",
    ),
    "method": MessageLookupByLibrary.simpleMessage("Méthode"),
    "minimize": MessageLookupByLibrary.simpleMessage("Réduire"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Réduire à la fermeture",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("minutes"),
    "minutesAgo": m51,
    "minutesAgoShort": m52,
    "mitm": MessageLookupByLibrary.simpleMessage("MITM"),
    "mitmAddLocalFile": MessageLookupByLibrary.simpleMessage(
      "Ajouter un fichier local",
    ),
    "mitmAddMapLocalRule": MessageLookupByLibrary.simpleMessage(
      "Ajouter une règle de mappage local",
    ),
    "mitmAddRejectRule": MessageLookupByLibrary.simpleMessage(
      "Ajouter une règle de rejet",
    ),
    "mitmAttachments": MessageLookupByLibrary.simpleMessage("Pièces jointes"),
    "mitmAttachmentsDesc": MessageLookupByLibrary.simpleMessage(
      "Les lignes désignent les pièces jointes par leur nom de fichier, comme script-path=a.js.",
    ),
    "mitmCertificateAndroidReadyTip": MessageLookupByLibrary.simpleMessage(
      "Seules les applications qui font confiance aux certificats utilisateur, surtout les navigateurs, sont déchiffrées.",
    ),
    "mitmCertificateExportTip": MessageLookupByLibrary.simpleMessage(
      "Exportez-le et faites-lui confiance sur les appareils à déchiffrer.",
    ),
    "mitmCertificateLinuxTip": MessageLookupByLibrary.simpleMessage(
      "Les navigateurs Flatpak nécessitent d’importer le certificat exporté à la main.",
    ),
    "mitmCertificateSavedTip": m53,
    "mitmCertutilMissing": m54,
    "mitmClientRefusedCertificate": MessageLookupByLibrary.simpleMessage(
      "Le client a refusé le certificat. Installez l’AC, ou excluez cet hôte si l’application épingle son certificat.",
    ),
    "mitmDecryptHost": MessageLookupByLibrary.simpleMessage(
      "Déchiffrer cet hôte",
    ),
    "mitmDecryptHostTip": m55,
    "mitmEnableTip": MessageLookupByLibrary.simpleMessage(
      "Flash pourra lire tout ce qui est envoyé aux hôtes déchiffrés, cookies et mots de passe compris. N’activez cette option que pour les hôtes à réécrire.",
    ),
    "mitmExcludeHost": MessageLookupByLibrary.simpleMessage(
      "Exclure du déchiffrement",
    ),
    "mitmExcludeHostTip": m56,
    "mitmFileTooLarge": m57,
    "mitmHostnameDesc": MessageLookupByLibrary.simpleMessage(
      "Un - en tête exclut un hôte, et la première correspondance l’emporte.",
    ),
    "mitmIgnoredLines": MessageLookupByLibrary.simpleMessage("Lignes ignorées"),
    "mitmInstallSystemCaTip": MessageLookupByLibrary.simpleMessage(
      "Root a été détecté : le certificat sera ajouté aux certificats de confiance du système sous forme de module Magisk, KernelSU ou APatch « FlClash MITM CA ». Toutes les applications de l’appareil lui feront alors confiance, et quiconque détient sa clé privée pourra déchiffrer le trafic HTTPS de l’appareil. Pour annuler, régénérez le certificat ou supprimez le module dans le gestionnaire root, puis redémarrez. Si root est refusé, il sera installé comme certificat utilisateur.",
    ),
    "mitmInstallUserCaTip": MessageLookupByLibrary.simpleMessage(
      "Root n’a pas été détecté : le certificat ne peut être installé que comme certificat utilisateur. Seules les applications qui font confiance aux certificats utilisateur, surtout les navigateurs, sont déchiffrées ; les autres échouent sur les hôtes listés, ne listez donc pas leurs hôtes. À partir d’Android 11, vous terminez l’installation vous-même dans les paramètres système.",
    ),
    "mitmMissingStores": m58,
    "mitmModule": MessageLookupByLibrary.simpleMessage("Module"),
    "mitmModuleInvalid": MessageLookupByLibrary.simpleMessage(
      "Ce n’est ni un module Surge, ni un plugin Loon, ni un extrait Quantumult X, ni une surcharge Stash",
    ),
    "mitmModuleRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Les règles de routage passent avant celles du profil.",
    ),
    "mitmModuleScriptsChanged": m59,
    "mitmModuleSystemTip": m60,
    "mitmModules": MessageLookupByLibrary.simpleMessage("Modules"),
    "mitmNewModule": MessageLookupByLibrary.simpleMessage("Nouveau module"),
    "mitmOldCertificateLeftTip": m61,
    "mitmOldSystemCertificateLeftTip": m62,
    "mitmRemoveOldCertificateTip": m63,
    "mitmRootPendingReboot": MessageLookupByLibrary.simpleMessage(
      "Le certificat prendra effet après le redémarrage de l’appareil.",
    ),
    "mitmRootUntilReboot": MessageLookupByLibrary.simpleMessage(
      "Aucun Magisk, KernelSU ou APatch n’a été trouvé pour conserver le certificat. Installez-le de nouveau après le redémarrage de l’appareil.",
    ),
    "mitmRoutingRules": MessageLookupByLibrary.simpleMessage(
      "Règles de routage",
    ),
    "mitmRuleCopiedForStash": MessageLookupByLibrary.simpleMessage(
      "Ce module est une surcharge Stash : la règle a été copiée pour que vous l’ajoutiez à la main.",
    ),
    "mitmRunScript": MessageLookupByLibrary.simpleMessage(
      "Exécuter maintenant",
    ),
    "mitmScriptNoOutput": MessageLookupByLibrary.simpleMessage(
      "Le script s\'est terminé sans sortie",
    ),
    "mitmScriptRisk": MessageLookupByLibrary.simpleMessage(
      "Ses scripts lisent et modifient le trafic des hôtes qu\'ils ciblent, cookies et jetons compris, et peuvent envoyer leurs propres requêtes. Ne l\'activez que si vous faites confiance à sa source.",
    ),
    "mitmScriptRiskTitle": MessageLookupByLibrary.simpleMessage(
      "Exécuter les scripts de ce module ?",
    ),
    "mitmSkipConditional": MessageLookupByLibrary.simpleMessage(
      "Les réécritures conditionnelles ne sont pas prises en charge",
    ),
    "mitmSkipDisabled": MessageLookupByLibrary.simpleMessage(
      "Désactivé par un argument",
    ),
    "mitmSkipEvent": MessageLookupByLibrary.simpleMessage(
      "Cet événement n\'est pas pris en charge",
    ),
    "mitmSkipJq": MessageLookupByLibrary.simpleMessage(
      "Les réécritures jq ne sont pas prises en charge",
    ),
    "mitmSkipJsonBody": MessageLookupByLibrary.simpleMessage(
      "Les réécritures de corps JSON ne sont pas prises en charge",
    ),
    "mitmSkipNotDownloaded": MessageLookupByLibrary.simpleMessage(
      "Son fichier n’a pas encore été téléchargé",
    ),
    "mitmSkipPolicy": MessageLookupByLibrary.simpleMessage(
      "Seules les politiques DIRECT et REJECT sont prises en charge",
    ),
    "mitmSkipRawHeader": MessageLookupByLibrary.simpleMessage(
      "La réécriture de tous les en-têtes comme un seul texte n’est pas prise en charge",
    ),
    "mitmSkipRelativeData": MessageLookupByLibrary.simpleMessage(
      "Le fichier que nomme cette ligne n’est pas joint ; utilisez une URL ou joignez-le",
    ),
    "mitmSkipRule": MessageLookupByLibrary.simpleMessage(
      "Ce type de règle n’est pas pris en charge",
    ),
    "mitmSkipScriptType": MessageLookupByLibrary.simpleMessage(
      "Ce type de script n\'est pas pris en charge",
    ),
    "mitmSkipSection": m64,
    "mitmSkipSetting": MessageLookupByLibrary.simpleMessage(
      "Ce réglage n’est pas pris en charge",
    ),
    "mitmSkipUnreadable": MessageLookupByLibrary.simpleMessage(
      "Cette ligne est illisible",
    ),
    "mitmSystemStoreFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible d’ajouter le certificat aux racines de confiance du système",
    ),
    "mitmTrustChecking": MessageLookupByLibrary.simpleMessage("Vérification…"),
    "mitmTrustNotInstalled": MessageLookupByLibrary.simpleMessage(
      "Non installé",
    ),
    "mitmTrustReady": MessageLookupByLibrary.simpleMessage("Approuvé"),
    "mitmTrustUntrusted": MessageLookupByLibrary.simpleMessage(
      "Pas entièrement approuvé",
    ),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Port mixte"),
    "mixedPortUnavailable": m65,
    "mixedPortUnavailableProxyUnchanged": m66,
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "monochromeIcon": MessageLookupByLibrary.simpleMessage("Icône monochrome"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "monthsAgo": m67,
    "monthsAgoShort": m68,
    "more": MessageLookupByLibrary.simpleMessage("Plus"),
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
    "name": MessageLookupByLibrary.simpleMessage("Nom"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Serveurs DNS utilisés par défaut, par ex. 223.5.5.5, tls://1.1.1.1 ou https://dns.google/dns-query.",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Les domaines correspondants utilisent le serveur DNS indiqué ici plutôt que Nameserver et Fallback.",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage(
      "Barre inférieure",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Réseau"),
    "networkAccessDeniedError": m89,
    "networkBadResponseError": m90,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "La requête a été annulée",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "Impossible de se connecter au serveur. Vérifiez votre connexion réseau ou vos réglages de proxy",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "Impossible de résoudre l’adresse du serveur. Vérifiez que l’URL est correcte et que le DNS fonctionne",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("Nom du réseau"),
    "networkNotFoundError": m91,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Trop de requêtes (HTTP 429). Patientez un instant puis réessayez",
    ),
    "networkRequestFailed": m92,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Secret du réseau"),
    "networkServerError": m93,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Débit réseau"),
    "networkTakeover": MessageLookupByLibrary.simpleMessage(
      "Prise en charge du trafic",
    ),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "La requête a expiré. Vérifiez votre réseau ou votre proxy, puis réessayez",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Échec de la connexion sécurisée. Le certificat du serveur est peut-être invalide, ou la connexion est interceptée",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Type de réseau"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Résultat suivant"),
    "no": MessageLookupByLibrary.simpleMessage("Non"),
    "noData": MessageLookupByLibrary.simpleMessage("Aucune donnée"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Aucune information"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Ne plus me le rappeler",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Aucun réseau"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Apps sans réseau"),
    "noResolve": MessageLookupByLibrary.simpleMessage("Ne pas résoudre l’IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "Ne pas résoudre le nom d’hôte",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage("Aucun résultat"),
    "nodes": MessageLookupByLibrary.simpleMessage("Nœuds"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "Cette ressource externe n’est pas un fichier texte",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Aucun"),
    "notRunning": MessageLookupByLibrary.simpleMessage("À l’arrêt"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "Le groupe de proxys actuel n’est pas sélectionnable",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de synchronisation (minutes)",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Ajoutez un profil pour commencer",
    ),
    "nullTip": m94,
    "numberRangeTip": m95,
    "numberTip": m96,
    "obfs": MessageLookupByLibrary.simpleMessage("Obfuscation"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Hôte d’obfuscation"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Mode d’obfuscation"),
    "obfsParam": MessageLookupByLibrary.simpleMessage(
      "Paramètre d’obfuscation",
    ),
    "obfsPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe d’obfuscation",
    ),
    "onDemand": MessageLookupByLibrary.simpleMessage("À la demande"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Ne compter que le trafic proxy",
    ),
    "openSettings": MessageLookupByLibrary.simpleMessage(
      "Ouvrir les paramètres",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("Facultatif"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "originalUrl": MessageLookupByLibrary.simpleMessage("URL d\'origine"),
    "other": MessageLookupByLibrary.simpleMessage("Autre"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Autres contributeurs",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Sortant"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Sortie"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("IP sortante"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Mode sortant"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Remplacer la destination",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "Entrées de remplacement",
    ),
    "overview": MessageLookupByLibrary.simpleMessage("Aperçu"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage(
      "Analyser les IP seules",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Mot de passe"),
    "paste": MessageLookupByLibrary.simpleMessage("Coller"),
    "peers": MessageLookupByLibrary.simpleMessage("Pairs"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage(
      "Choisir dans l’album",
    ),
    "pinWindow": MessageLookupByLibrary.simpleMessage("Épingler la fenêtre"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Veuillez lier un WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir un nom de script",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Veuillez importer un code QR valide",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Plugin"),
    "pluginCipher": MessageLookupByLibrary.simpleMessage(
      "Chiffrement du plugin",
    ),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Hôte du plugin"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Mode du plugin"),
    "pluginPassword": MessageLookupByLibrary.simpleMessage(
      "Mot de passe du plugin",
    ),
    "pluginPath": MessageLookupByLibrary.simpleMessage("Chemin du plugin"),
    "pluginUsername": MessageLookupByLibrary.simpleMessage(
      "Nom d’utilisateur du plugin",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir un autre port",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Saut de port"),
    "portTip": m97,
    "portValue": m98,
    "ports": MessageLookupByLibrary.simpleMessage("Ports"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Clé prépartagée"),
    "preferred": MessageLookupByLibrary.simpleMessage("Préféré"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prérequis"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Appuyez sur une combinaison de touches",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Aperçu"),
    "previousMatch": MessageLookupByLibrary.simpleMessage("Résultat précédent"),
    "privateKey": MessageLookupByLibrary.simpleMessage("Clé privée"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Phrase secrète de la clé privée",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Processus"),
    "profile": MessageLookupByLibrary.simpleMessage("Profil"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Veuillez saisir un intervalle valide",
        ),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Veuillez saisir l’intervalle de mise à jour automatique",
        ),
    "profileDaysLeft": m99,
    "profileExpiresIn": m100,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Le profil a été modifié. Désactiver la mise à jour automatique ?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir le nom du profil",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "S’applique uniquement à ce profil ; tout ce qui n’est pas ajouté utilise la valeur par défaut.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "S’applique uniquement à ce profil et prime sur les entrées de remplacement TUN des réglages réseau.",
    ),
    "profileUpdatedAt": m101,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir une URL de profil valide",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Veuillez saisir l’URL du profil",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profils"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Trier les profils"),
    "project": MessageLookupByLibrary.simpleMessage("Projet d’origine FlClash"),
    "protocol": MessageLookupByLibrary.simpleMessage("Protocole"),
    "protocolParam": MessageLookupByLibrary.simpleMessage(
      "Paramètre du protocole",
    ),
    "protocolVersion": MessageLookupByLibrary.simpleMessage(
      "Version du protocole",
    ),
    "providerInUse": m102,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Seuls les fournisseurs distants sont pris en charge",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Ressources externes"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxys"),
    "proxiesCount": m103,
    "proxiesProfileLabel": m104,
    "proxiesRemovedTip": m105,
    "proxiesReplacedTip": m106,
    "proxyChains": MessageLookupByLibrary.simpleMessage("Chaîne de proxys"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Groupe de proxys"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Le groupe de proxys est vide",
    ),
    "proxyGroupInUse": m107,
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Les groupes s’affichent ici une fois le cœur démarré",
    ),
    "proxyGroupsCount": m108,
    "proxyProviders": MessageLookupByLibrary.simpleMessage(
      "Fournisseurs de proxys",
    ),
    "proxyServerNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Sert uniquement à résoudre les noms des serveurs proxy.",
    ),
    "proxyServerNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Les noms de serveurs proxy correspondants utilisent le serveur DNS indiqué ici plutôt que Proxy Server Nameserver.",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Type de proxy"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Nettoyer le cache"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Clé publique"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Noir pur"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Mode noir pur"),
    "qrcode": MessageLookupByLibrary.simpleMessage("Code QR"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scannez un code QR pour obtenir un profil",
    ),
    "qrcodeTooLongTip": MessageLookupByLibrary.simpleMessage(
      "Ce lien est trop long pour un code QR. Utilisez Copier le lien.",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("Actions rapides"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Modification rapide"),
    "recentRequests": MessageLookupByLibrary.simpleMessage("Requêtes récentes"),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Suggestions"),
    "recordType": MessageLookupByLibrary.simpleMessage("Type d’enregistrement"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Port Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Rétablir"),
    "regenerateCertificate": MessageLookupByLibrary.simpleMessage(
      "Régénérer le certificat",
    ),
    "regenerateCertificateTip": MessageLookupByLibrary.simpleMessage(
      "Le nouveau certificat remplace l’actuel, que Flash retire des racines de confiance de cet appareil quand il le peut. Chaque autre appareil qui fait confiance à l’actuel doit installer le nouveau.",
    ),
    "regex": MessageLookupByLibrary.simpleMessage("Regex"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Libérer la mémoire"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de la libération de la mémoire",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Distant"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Destination distante",
    ),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Résolution DNS distante",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Retirer"),
    "rename": MessageLookupByLibrary.simpleMessage("Renommer"),
    "replace": MessageLookupByLibrary.simpleMessage("Remplacer"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Tout remplacer"),
    "request": MessageLookupByLibrary.simpleMessage("Requête"),
    "requestBody": MessageLookupByLibrary.simpleMessage("Corps de la requête"),
    "requestHeaders": MessageLookupByLibrary.simpleMessage(
      "En-têtes de requête",
    ),
    "requests": MessageLookupByLibrary.simpleMessage("Requêtes"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Requêtes et mises à jour",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Obligatoire"),
    "reset": MessageLookupByLibrary.simpleMessage("Réinitialiser"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "Cette page contient des modifications. Voulez-vous vraiment réinitialiser ?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment réinitialiser ?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalle de mise à jour automatique",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "L’intervalle de mise à jour automatique doit être supérieur à 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Ressources"),
    "respectRules": MessageLookupByLibrary.simpleMessage(
      "Respecter les règles",
    ),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Respecter les règles fait passer les connexions DNS selon les règles et nécessite un Proxy Server Nameserver.",
    ),
    "response": MessageLookupByLibrary.simpleMessage("Réponse"),
    "responseBody": MessageLookupByLibrary.simpleMessage("Corps de la réponse"),
    "responseCode": MessageLookupByLibrary.simpleMessage("Code de réponse"),
    "responseHeaders": MessageLookupByLibrary.simpleMessage(
      "En-têtes de réponse",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Redémarrer"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Voulez-vous vraiment redémarrer le cœur ?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restaurer"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Restaurer toutes les données",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restaurer uniquement les profils",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Stratégie de restauration",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage("Écraser"),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Restauration réussie",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Résultat"),
    "retry": MessageLookupByLibrary.simpleMessage("Réessayer"),
    "root": MessageLookupByLibrary.simpleMessage("Root"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Adresses de route"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Adresses de route exclues",
    ),
    "routingMark": MessageLookupByLibrary.simpleMessage("Marque de routage"),
    "ru": MessageLookupByLibrary.simpleMessage("Russe"),
    "rule": MessageLookupByLibrary.simpleMessage("Règle"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Règle logique ET",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au domaine complet",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à un mot-clé de domaine",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une regex de domaine",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à un suffixe de domaine",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Correspondance par caractères génériques ; seuls * et ? sont pris en charge",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à la marque DSCP (entrant UDP tproxy uniquement)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à la plage de ports de destination",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au code pays de l’IP",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond aux domaines de Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom entrant",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au port entrant",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au type entrant",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom d’utilisateur entrant ; séparez plusieurs noms par /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à l’ASN de l’IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage d’adresses IP ; IP-CIDR6 n’est qu’un alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage d’adresses IP",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage de suffixes d’IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à toutes les requêtes, sans condition",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à TCP ou UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Règle logique NON",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage(
      "Règle logique OU",
    ),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom du processus ; correspond au nom du paquet sur Android",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par regex au nom du processus ; correspond au nom du paquet sur Android",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par caractères génériques au nom du processus ; seuls * et ? sont pris en charge",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au chemin complet du processus",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par regex au chemin du processus",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond par caractères génériques au chemin du processus ; seuls * et ? sont pris en charge",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au nom de rematch ; séparez plusieurs noms par /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Référence un jeu de règles ; nécessite rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond au code pays de l’IP source",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à l’ASN de l’IP source",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage d’adresses IP source",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à une plage de suffixes d’IP source",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à la plage de ports source",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond vers une sous-règle ; attention aux parenthèses",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Correspond à l’ID d’utilisateur Linux",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("La règle est vide"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "Les règles doivent former une liste YAML avec une règle par élément, par exemple - DOMAIN,example.com,DIRECT",
    ),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent en direct",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Bloquer DNS over TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Bloquer le bouclage du proxy",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage("Bloquer QUIC"),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage("Bloquer STUN"),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage(
      "LAN en direct",
    ),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple et Microsoft en direct",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage(
      "Fournisseurs de règles",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Jeu de règles"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Le jeu de règles ne contient aucune entrée exploitable",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "Ce fichier mrs est illisible",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "Le jeu de règles mélange des domaines et des plages d’IP : son type est indéterminable",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Cible de la règle"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "La règle doit commencer par un type pris en charge, par exemple DOMAIN,example.com,DIRECT",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Règles"),
    "rulesCount": m109,
    "runTime": MessageLookupByLibrary.simpleMessage("Durée d’exécution"),
    "running": MessageLookupByLibrary.simpleMessage("En cours d’exécution"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Configuration d’exécution",
    ),
    "safeMode": MessageLookupByLibrary.simpleMessage("Mode sans échec"),
    "safeModeAppTitle": m110,
    "saturation": MessageLookupByLibrary.simpleMessage("Saturation"),
    "save": MessageLookupByLibrary.simpleMessage("Enregistrer"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "Enregistrer les modifications ?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Mode script : réécrit tout le profil avec un script d’extension",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Défiler jusqu’à la sélection",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Rechercher"),
    "seconds": MessageLookupByLibrary.simpleMessage("secondes"),
    "secondsCount": m111,
    "secretKey": MessageLookupByLibrary.simpleMessage("Clé"),
    "sectionsInEffect": m112,
    "select": MessageLookupByLibrary.simpleMessage("Sélectionner"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Tout sélectionner"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Veuillez sélectionner un jeu de règles",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Veuillez sélectionner une stratégie de répartition",
    ),
    "send": MessageLookupByLibrary.simpleMessage("Envoyer"),
    "sendFromPhone": MessageLookupByLibrary.simpleMessage(
      "Envoyer depuis le téléphone",
    ),
    "sendFromPhoneConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "Importer le lien envoyé depuis le téléphone ?",
    ),
    "sendFromPhoneNoNetwork": MessageLookupByLibrary.simpleMessage(
      "Cet appareil n\'est connecté à aucun réseau local",
    ),
    "sendFromPhonePageHint": MessageLookupByLibrary.simpleMessage(
      "Lien d\'abonnement ou lien de partage de proxy",
    ),
    "sendFromPhonePageSent": MessageLookupByLibrary.simpleMessage(
      "Envoyé. Confirmez l\'importation sur l\'autre appareil.",
    ),
    "sendFromPhonePageTitle": MessageLookupByLibrary.simpleMessage(
      "Envoyer un lien à Flash",
    ),
    "sendFromPhonePermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Pour recevoir un lien depuis le téléphone, Flash a besoin de l\'autorisation Appareils à proximité, qui lui donne accès au réseau local. Activez-la dans les paramètres de l\'application.",
    ),
    "sendFromPhoneTip": MessageLookupByLibrary.simpleMessage(
      "Scannez le code avec l\'appareil photo du téléphone, puis collez le lien dans la page qui s\'ouvre. Les deux appareils doivent être sur le même réseau.",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Serveur"),
    "serviceAbnormalCount": m113,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage(
      "Tout est disponible",
    ),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Disponible"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Bloqué"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Tout vérifier"),
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage(
      "Bientôt disponible",
    ),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "FAI non autorisé",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de la vérification",
    ),
    "serviceManage": MessageLookupByLibrary.simpleMessage("Gérer les services"),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Contenus originaux uniquement",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Non vérifié"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Accès restreint",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Affiché sur le tableau de bord",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage("État des services"),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("Indisponible"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Région non prise en charge",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("réglages"),
    "settings": MessageLookupByLibrary.simpleMessage("Paramètres"),
    "settingsCount": m114,
    "shareLinkUnreadable": m115,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "Aucun proxy n’a pu être lu dans les liens",
    ),
    "shareQrcodeTip": MessageLookupByLibrary.simpleMessage(
      "Scannez avec Flash sur un autre appareil pour importer ce profil.",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Afficher"),
    "showLess": MessageLookupByLibrary.simpleMessage("Réduire"),
    "showMore": MessageLookupByLibrary.simpleMessage("Développer"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Bouton Arrêter dans la notification",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage(
      "Afficher le mot de passe",
    ),
    "sidebar": MessageLookupByLibrary.simpleMessage("Barre latérale"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage(
      "Lancement silencieux",
    ),
    "singleImport": MessageLookupByLibrary.simpleMessage("Importation unique"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Saisissez un seul lien ici ; pour en modifier plusieurs, utilisez la modification rapide de la liste",
    ),
    "singleValueTip": m116,
    "size": MessageLookupByLibrary.simpleMessage("Taille"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Ignorer la vérification du certificat",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Domaines ignorés"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Adresses de destination ignorées",
    ),
    "skipServerCertVerify": MessageLookupByLibrary.simpleMessage(
      "Ignorer la vérification du certificat serveur",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Adresses sources ignorées",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Glissement"),
    "sliders": MessageLookupByLibrary.simpleMessage("Curseurs"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Protocoles"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Port SOCKS"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Doux"),
    "sort": MessageLookupByLibrary.simpleMessage("Trier"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP source"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Proxy spécial"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Règles spéciales"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Spectre"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Statistiques de débit",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Stratégie de répartition",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "La stratégie de répartition ne peut pas être vide",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("Les SSID sont vides"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Mode de pile"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Trace de pile"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Mode standard : ajoute des règles par-dessus le profil",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Démarrer"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage("Partir de zéro"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Démarrage du VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Démarrage et arrière-plan",
    ),
    "status": MessageLookupByLibrary.simpleMessage("État"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Si DNS est désactivé, le DNS du système est utilisé.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Arrêter"),
    "stopUpdateDownloadTip": MessageLookupByLibrary.simpleMessage(
      "Arrêter le téléchargement de la mise à jour ?",
    ),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Arrêt du VPN…"),
    "strategy": MessageLookupByLibrary.simpleMessage("Stratégie"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Route stricte"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "La route stricte empêche le trafic tel que le DNS de contourner TUN et, avec IPv6 désactivé, bloque les connexions IPv6 de cet appareil.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "submit": MessageLookupByLibrary.simpleMessage("Valider"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Infos d’abonnement",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Saisissez votre mot de passe pour sudo",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspendu…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Changer de profil"),
    "sync": MessageLookupByLibrary.simpleMessage("Synchroniser"),
    "system": MessageLookupByLibrary.simpleMessage("Système"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Apps système"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Proxy système"),
    "tab": MessageLookupByLibrary.simpleMessage("Onglet"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage(
      "Animation des onglets",
    ),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Appuyez sur l’icône pour réessayer",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Appuyez pour autoriser",
    ),
    "target": MessageLookupByLibrary.simpleMessage("Cible"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP simultané"),
    "testInterval": MessageLookupByLibrary.simpleMessage("Intervalle de test"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL de test"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage(
      "Tester à l’utilisation",
    ),
    "textScale": MessageLookupByLibrary.simpleMessage("Taille du texte"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Le texte de l’app ressemblera à ceci",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Thème"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Couleur du thème"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Mode du thème"),
    "tight": MessageLookupByLibrary.simpleMessage("Serrée"),
    "time": MessageLookupByLibrary.simpleMessage("Heure"),
    "timeToFirstByte": MessageLookupByLibrary.simpleMessage(
      "Délai du premier octet",
    ),
    "timeout": MessageLookupByLibrary.simpleMessage("Expiré"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Teinté"),
    "tip": MessageLookupByLibrary.simpleMessage("Astuce"),
    "toggle": MessageLookupByLibrary.simpleMessage("Basculer"),
    "tolerance": MessageLookupByLibrary.simpleMessage("Tolérance"),
    "tools": MessageLookupByLibrary.simpleMessage("Outils"),
    "torch": MessageLookupByLibrary.simpleMessage("Lampe torche"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Reçu"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Trafic total"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Envoyé"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Port TProxy"),
    "traffic": MessageLookupByLibrary.simpleMessage("Trafic"),
    "trafficPeak": m117,
    "trafficTotal": m118,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Trafic utilisé"),
    "transport": MessageLookupByLibrary.simpleMessage("Transport"),
    "transportHeaders": m119,
    "trustCertificate": MessageLookupByLibrary.simpleMessage(
      "Approuver le certificat",
    ),
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
    "tsDevicesScope": MessageLookupByLibrary.simpleMessage(
      "Devices this node can see, not every device in the admin console",
    ),
    "tsDevicesShown": m126,
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
    "tsExitChangeBody": m127,
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
    "tsExitOffBody": m128,
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
    "tsExpiryTip": m129,
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
    "tsLegacyConfirmAccount": m130,
    "tsLegacyConfirmBody": MessageLookupByLibrary.simpleMessage(
      "This copies the login record for the node above and leaves the original untouched. The same record can\'t move to another node afterwards. Check the node\'s real connection status after the move.",
    ),
    "tsLegacyConfirmControl": m131,
    "tsLegacyConfirmNode": m132,
    "tsLegacyConfirmProfile": m133,
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
    "tsLogoutBody": m134,
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
    "tsNetworkOf": m135,
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
    "tsNodeOf": m136,
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
    "tsRemoveBody": m137,
    "tsRemoveBodyNode": m138,
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
    "tsRulesAddresses": m139,
    "tsRulesDomain": m140,
    "tsRulesManaged": MessageLookupByLibrary.simpleMessage(
      "Flash updates dedicated rules using this account’s network domain and device addresses. Other traffic keeps its existing routing, and the original profile file stays unchanged.",
    ),
    "tsRulesPending": MessageLookupByLibrary.simpleMessage(
      "Once added, Tailscale addresses and ts.net domains will use dedicated rules. Other traffic will keep its existing routing.",
    ),
    "tsRulesProfileNode": MessageLookupByLibrary.simpleMessage(
      "Only traffic routed to this node by Flash rules uses Tailscale. Signing in to this node does not change existing rules or enable system proxy or TUN.",
    ),
    "tsSaveChoices": MessageLookupByLibrary.simpleMessage("Save choices"),
    "tsSavedValue": m141,
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
    "tsSharedBy": m142,
    "tsSignIn": MessageLookupByLibrary.simpleMessage("Sign in to Tailscale"),
    "tsSignInBoundary": MessageLookupByLibrary.simpleMessage(
      "System proxy and TUN will not be enabled automatically.",
    ),
    "tsSignInTip": MessageLookupByLibrary.simpleMessage(
      "After sign-in, Flash adds a Tailscale node and dedicated rules to this profile. Other traffic keeps its existing routing, and the original profile file stays unchanged.",
    ),
    "tsSignOutAccount": MessageLookupByLibrary.simpleMessage(
      "Sign out of this account",
    ),
    "tsSignOutAccountBody": m143,
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
    "tsStatusOf": m144,
    "tsStatusUnknown": MessageLookupByLibrary.simpleMessage("Status unknown"),
    "tsStoppedTip": MessageLookupByLibrary.simpleMessage(
      "This node has stopped and can\'t reach the Tailscale network for now.",
    ),
    "tsSubnetRoutes": MessageLookupByLibrary.simpleMessage("Subnet routes"),
    "tsSwitcherSemantics": m145,
    "tsSystem": MessageLookupByLibrary.simpleMessage("OS"),
    "tsSystemMissing": MessageLookupByLibrary.simpleMessage("OS not provided"),
    "tsTargetAddress": m146,
    "tsTargetDomain": m147,
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
      "TUN n’a pas pu être autorisé et a donc été désactivé.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN ne fonctionne qu’en mode administrateur.",
    ),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Les entrées ajoutées ici remplacent les réglages TUN de tous les profils ; tout ce qui n’est pas ajouté garde le réglage du profil. Les entrées qu’un profil personnalisé ajoute lui-même priment.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Désactiver"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Activer"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage("Mode de relais UDP"),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("Délai UDP"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "Le délai UDP est en secondes et ne fonctionne qu’avec les piles gvisor, system et mixed.",
    ),
    "ultra": MessageLookupByLibrary.simpleMessage("Ultra"),
    "undo": MessageLookupByLibrary.simpleMessage("Annuler"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Délai unifié"),
    "unknown": MessageLookupByLibrary.simpleMessage("Inconnu"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Erreur réseau inconnue",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Restaurer"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Sans nom"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage(
      "Désépingler la fenêtre",
    ),
    "update": MessageLookupByLibrary.simpleMessage("Mettre à jour"),
    "updateCheckFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t check for updates. Please try again.",
    ),
    "updateDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible de télécharger la mise à jour.",
    ),
    "updateDownloadStarted": MessageLookupByLibrary.simpleMessage(
      "Téléchargement de la mise à jour lancé. Suivez la progression sur le tableau de bord.",
    ),
    "updateDownloadTest": MessageLookupByLibrary.simpleMessage(
      "Test de téléchargement de mise à jour",
    ),
    "updateFailed": MessageLookupByLibrary.simpleMessage(
      "Échec de la mise à jour",
    ),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "Impossible d\'installer la mise à jour. Vous pouvez la télécharger depuis la page de publication.",
    ),
    "updateNoReleaseFound": MessageLookupByLibrary.simpleMessage(
      "No Flash release found yet",
    ),
    "updateNotVerified": MessageLookupByLibrary.simpleMessage(
      "La mise à jour téléchargée n\'a pas pu être vérifiée.",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Mise à jour prête"),
    "updateReadyTip": MessageLookupByLibrary.simpleMessage(
      "La mise à jour est téléchargée. Touchez pour l’installer.",
    ),
    "updateRestartTip": MessageLookupByLibrary.simpleMessage(
      "Flash se ferme pour installer la mise à jour et se rouvre une fois terminée.",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("Envoi"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Bande passante d’envoi",
    ),
    "upstreamTelegram": MessageLookupByLibrary.simpleMessage(
      "Telegram du projet d’origine FlClash",
    ),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlRewrite": MessageLookupByLibrary.simpleMessage("Réécriture d’URL"),
    "urlTip": m148,
    "useHosts": MessageLookupByLibrary.simpleMessage("Utiliser hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Utiliser les hosts du système",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("utilisé"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("Trafic utilisé"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Nom d’utilisateur"),
    "validUntil": m149,
    "value": MessageLookupByLibrary.simpleMessage("Valeur"),
    "view": MessageLookupByLibrary.simpleMessage("Afficher"),
    "viewAll": MessageLookupByLibrary.simpleMessage("Tout afficher"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("IPv4 virtuelle"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Vif"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "La configuration liée au VPN a changé. Appuyez pour redémarrer",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Configuration WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Mode liste blanche"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Écrire dans le système",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Écrire dans le système règle aussi l’horloge système ; Android l’ignore.",
    ),
    "yearsAgo": m150,
    "yearsAgoShort": m151,
    "yes": MessageLookupByLibrary.simpleMessage("Oui"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Chinois simplifié"),
  };
}
