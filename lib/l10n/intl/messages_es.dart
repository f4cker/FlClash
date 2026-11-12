// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a es locale. All the
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
  String get localeName => 'es';

  static String m0(count) =>
      "${Intl.plural(count, one: '${count} seleccionada', other: '${count} seleccionadas')}";

  static String m1(name) => "${name} añadido a proxies locales";

  static String m2(name) => "${name} ya está en proxies locales";

  static String m3(count, skipped) =>
      "${count} por añadir, ${skipped} omitidos por ya existir";

  static String m4(detail) => "No se pudieron borrar los datos: ${detail}";

  static String m5(code) =>
      "Windows se negó a ejecutar FlClashCore.exe (error ${code}). Una directiva de control de aplicaciones, como Smart App Control o AppLocker, bloquea los programas sin firmar; permite Flash en esa directiva o desactívala e inténtalo de nuevo.";

  static String m6(name) =>
      "La app no pudo terminar de iniciarse dos veces seguidas. Para romper el ciclo, se ha deseleccionado el perfil ${name} y se ha omitido la configuración automática. Puedes volver a seleccionarlo en cualquier momento.";

  static String m7(url) => "¿Quieres crear un perfil a partir de ${url}?";

  static String m8(count, label) =>
      "${Intl.plural(count, one: 'Se descartó 1 regla SUB-RULE, porque los perfiles personalizados no admiten subreglas', other: 'Se descartaron ${label} reglas SUB-RULE, porque los perfiles personalizados no admiten subreglas')}";

  static String m9(message) =>
      "El núcleo no puede interpretar este proxy: ${message}";

  static String m10(proxy, target) =>
      "${proxy} marca a través de ${target}, que lleva de vuelta a ${proxy}, por lo que la marcación entra en bucle";

  static String m11(name) =>
      "El nombre ${name} ya lo usa otro proxy o grupo de proxies";

  static String m12(path) =>
      "Los grupos de proxies se referencian entre sí en bucle: ${path}";

  static String m13(name) =>
      "El respaldo si está vacío debe ser un proxy, pero ${name} no existe o es un grupo de proxies";

  static String m14(name, message) =>
      "${name} no es una expresión regular válida: ${message}";

  static String m15(name) => "El proxy de marcación ${name} no existe";

  static String m16(names) =>
      "Estos proveedores de proxies no existen: ${names}";

  static String m17(names) => "Estos proxies o políticas no existen: ${names}";

  static String m18(name) =>
      "${name} es un nombre de política integrada y no se puede usar aquí";

  static String m19(count) =>
      "${count} elementos tienen problemas, y aplicar este perfil puede fallar";

  static String m20(count) =>
      "${Intl.plural(count, one: 'hace 1 día', other: 'hace ${count} días')}";

  static String m21(count) => "${Intl.plural(count, other: 'hace ${count} d')}";

  static String m22(label) =>
      "¿Seguro que quieres eliminar los elementos seleccionados (${label})?";

  static String m23(label) =>
      "¿Seguro que quieres eliminar este elemento (${label})?";

  static String m24(label) => "Detalles de ${label}";

  static String m25(name) =>
      "La marcación a través de ${name} lleva de vuelta al proxy que lo usa, por lo que se detuvo la conexión";

  static String m26(label) => "${label} no puede estar vacío";

  static String m27(label) => "${label} ya existe";

  static String m28(count) => "${count} elementos fallaron. Toca para ver";

  static String m29(label, message) => "${label}: ${message}";

  static String m30(name) => "${name} ya está actualizado";

  static String m31(name) => "${name} actualizado";

  static String m32(count) =>
      "${Intl.plural(count, one: '1 grupo', other: '${count} grupos')}";

  static String m33(count) => "${count} sin respuesta";

  static String m34(name) => "${name}, Oculto";

  static String m35(action) =>
      "Ya lo usa “${action}”. Al guardar, pasará a este.";

  static String m36(modifiers) =>
      "Incluye al menos una de estas teclas: ${modifiers}";

  static String m37(count) =>
      "${Intl.plural(count, one: 'hace 1 hora', other: 'hace ${count} horas')}";

  static String m38(count) => "${Intl.plural(count, other: 'hace ${count} h')}";

  static String m39(encoding) =>
      "No se pudo decodificar ${encoding}, así que se muestran los datos tal como se enviaron.";

  static String m40(memory, body) =>
      "Los registros más antiguos se eliminan primero al alcanzar este número u ocupar ${memory} de memoria. De cada cuerpo se conservan solo los primeros ${body}.";

  static String m41(invalid, total) => "${invalid} de ${total} no válidos";

  static String m42(target) => "${target} no es una política válida";

  static String m43(proxyName) => "${proxyName} no es un proxy válido";

  static String m44(providerName) =>
      "${providerName} no es un proveedor de proxies válido";

  static String m45(ruleSet) => "${ruleSet} no es un conjunto de reglas válido";

  static String m46(subRule) => "${subRule} no es una SUB_RULE válida";

  static String m47(count) =>
      "${Intl.plural(count, one: '1 elemento', other: '${count} elementos')}";

  static String m48(line, message) => "Línea ${line}: ${message}";

  static String m49(appName) =>
      "1. Abre Ajustes del sistema > Privacidad y seguridad\n2. Elige Servicios de localización\n3. Busca ${appName} en la lista y márcalo\n\nCuando termines, vuelve a la app para continuar. Gracias por tu colaboración.";

  static String m50(label, max) =>
      "${label} debe tener como máximo ${max} caracteres";

  static String m51(size) => "Liberado: ${size}";

  static String m52(count) =>
      "${Intl.plural(count, one: 'hace 1 minuto', other: 'hace ${count} minutos')}";

  static String m53(count) =>
      "${Intl.plural(count, other: 'hace ${count} min')}";

  static String m54(fileName) =>
      "Se guardó ${fileName} en Descargas. Instálalo en Ajustes › Seguridad › Cifrado y credenciales › Instalar un certificado › Certificado de CA.";

  static String m55(command) =>
      "Chrome y Firefox tienen sus propios almacenes de certificados, que necesitan certutil: ${command}";

  static String m56(host) =>
      "¿Añadir ${host} a la lista de nombres de host? Flash podrá leer lo que se le envíe, incluidas cookies y contraseñas.";

  static String m57(host) =>
      "¿Añadir -${host} al principio de la lista de nombres de host? El host ya no se descifrará nunca.";

  static String m58(size) => "El archivo supera los ${size} MB";

  static String m59(stores) => "Aún no está en: ${stores}";

  static String m60(name) =>
      "Los scripts de ${name} han cambiado y se ha desactivado";

  static String m61(system) =>
      "Escrito para ${system}; algunas líneas pueden no coincidir con las apps de este dispositivo.";

  static String m62(name) =>
      "No se pudo quitar el certificado antiguo, ${name}. Quítalo tú de las raíces de confianza.";

  static String m63(name) =>
      "El certificado antiguo, ${name}, sigue entre los certificados de confianza del sistema. Permite el acceso root a Flash en tu gestor de root y vuelve a generarlo, o elimina allí el módulo «FlClash MITM CA» y reinicia.";

  static String m64(name) =>
      "Quita el certificado antiguo, ${name}, en Ajustes › Seguridad › Cifrado y credenciales › Credenciales de confianza › Usuario, y después instala el nuevo.";

  static String m65(section) => "La sección [${section}] no es compatible";

  static String m66(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start.";

  static String m67(port) =>
      "Could not open port ${port}. Another app may be using it. The proxy service did not start. System proxy settings were not changed.";

  static String m68(count) =>
      "${Intl.plural(count, one: 'hace 1 mes', other: 'hace ${count} meses')}";

  static String m69(count) => "${Intl.plural(count, other: 'hace ${count} m')}";

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
      "El servidor denegó el acceso (HTTP ${code}). Puede que el enlace haya caducado o que las credenciales sean incorrectas";

  static String m102(code) => "El servidor rechazó la solicitud (HTTP ${code})";

  static String m103(code) =>
      "No se encontró nada en esta dirección (HTTP ${code}). Comprueba que la URL sea correcta";

  static String m104(detail) => "Falló la solicitud de red: ${detail}";

  static String m105(code) =>
      "El servidor tuvo un problema (HTTP ${code}). Inténtalo de nuevo más tarde";

  static String m106(label) => "Aún no hay ningún elemento (${label})";

  static String m107(label, min, max) =>
      "${label} debe estar entre ${min} y ${max}";

  static String m108(label) => "${label} debe ser un número";

  static String m109(label) => "${label} debe estar entre 1024 y 49151";

  static String m110(port) => "Puerto ${port}";

  static String m111(days) =>
      "${Intl.plural(days, one: 'Queda 1 día', other: 'Quedan ${days} días')}";

  static String m112(date, days) =>
      "Vence el ${date}, ${Intl.plural(days, one: 'queda 1 día', other: 'quedan ${days} días')}";

  static String m113(time) => "Actualizado ${time}";

  static String m114(label, profiles) =>
      "${label} sigue en uso en ${profiles}, que dejarán de funcionar correctamente si se elimina. ¿Seguro que quieres eliminarlo?";

  static String m115(count, label) =>
      "${Intl.plural(count, one: '1 proxy', other: '${label} proxies')}";

  static String m116(name, count) => "${name} y otros (${count} proxies)";

  static String m117(removed) =>
      "Se eliminarán estos proxies: ${removed}. Una línea cuyo nombre cambió cuenta como un proxy nuevo, y los perfiles personalizados que mencionen los eliminados los marcarán como ausentes. ¿Aplicar de todos modos?";

  static String m118(removed, added) =>
      "Se eliminarán estos proxies: ${removed}. Se añadirán estos: ${added}. Una línea cuyo nombre cambió cuenta como un proxy nuevo, y los perfiles personalizados que mencionen los eliminados los marcarán como ausentes. ¿Aplicar de todos modos?";

  static String m119(label) =>
      "${label} sigue mencionado por reglas, grupos de proxies, proxies de marcación, DNS o NTP de este perfil, que dejarán de funcionar si se elimina. ¿Seguro que quieres eliminarlo?";

  static String m120(count, label) =>
      "${Intl.plural(count, one: '1 grupo de proxies', other: '${label} grupos de proxies')}";

  static String m121(count, label) =>
      "${Intl.plural(count, one: '1 regla', other: '${label} reglas')}";

  static String m122(appName) => "${appName} (Modo seguro)";

  static String m123(count) =>
      "${Intl.plural(count, one: '1 segundo', other: '${count} segundos')}";

  static String m124(count) => "${count} en vigor";

  static String m125(count) =>
      "${Intl.plural(count, one: '1 problema', other: '${count} problemas')}";

  static String m126(count) =>
      "${Intl.plural(count, one: '1 ajuste', other: '${count} ajustes')}";

  static String m127(link) => "No se pudo leer ningún proxy de ${link}";

  static String m128(label) => "${label} debe ser un solo elemento";

  static String m129(value) => "Pico: ${value}";

  static String m130(value) => "Total: ${value}";

  static String m131(transport) => "Encabezados ${transport}";

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

  static String m150(network) => "Unknown · Network ${network}";

  static String m151(account, node, profile) =>
      "This signs out “${account}” (node “${node}”), clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m152(node, profile) =>
      "This signs out “${node}”, clears its sign-in from this Mac, and removes its panel-added node and rules from “${profile}”. Connections through this node may be interrupted. Other accounts will not be signed out or removed.";

  static String m153(count) => "Device addresses: ${count}";

  static String m154(domain) => "Network domain: ${domain}";

  static String m155(count, domain) =>
      "${Intl.plural(count, one: '${domain} · 1 device address', other: '${domain} · ${count} device addresses')}";

  static String m156(value) => "Saved: ${value}";

  static String m157(name) => "Shared by: ${name}";

  static String m158(account, node) =>
      "This signs out “${account}” (node “${node}”) and clears its sign-in from this Mac. Its panel entry and target assignments stay saved. Connections through this account may be interrupted and will not switch to another account or a direct connection. Other accounts will not be signed out. You must choose Sign in to use this account again.";

  static String m159(label) => "Status: ${label}";

  static String m160(account, status, count) =>
      "Viewing Tailscale account: ${account}, ${status}. ${count} entries.";

  static String m161(address) => "Address: ${address}";

  static String m162(domain) => "Domain: ${domain}";

  static String m163(node) => "Tailscale · Added by Flash · Node ${node}";

  static String m164(count, node) =>
      "Tailscale · Added by Flash · ${Intl.plural(count, one: '1 rule', other: '${count} rules')} → Node ${node}";

  static String m165(label) => "${label} debe ser una URL";

  static String m166(date) => "Válido hasta el ${date}";

  static String m167(count) =>
      "${Intl.plural(count, one: 'hace 1 año', other: 'hace ${count} años')}";

  static String m168(count) =>
      "${Intl.plural(count, other: 'hace ${count} a')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("Acerca de"),
    "accessControl": MessageLookupByLibrary.simpleMessage("Control de acceso"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Solo las apps seleccionadas usan la VPN",
    ),
    "accessControlDisabledDesc": MessageLookupByLibrary.simpleMessage(
      "El control de acceso de apps está desactivado",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Las apps seleccionadas quedan excluidas de la VPN",
    ),
    "accessControlSelectedCount": m0,
    "account": MessageLookupByLibrary.simpleMessage("Cuenta"),
    "action": MessageLookupByLibrary.simpleMessage("Acción"),
    "actionDelayTest": MessageLookupByLibrary.simpleMessage(
      "Probar la latencia de todos",
    ),
    "actionDirectMode": MessageLookupByLibrary.simpleMessage("Modo directo"),
    "actionGlobalMode": MessageLookupByLibrary.simpleMessage("Modo global"),
    "actionMode": MessageLookupByLibrary.simpleMessage("Cambiar modo"),
    "actionProxy": MessageLookupByLibrary.simpleMessage("Proxy del sistema"),
    "actionRuleMode": MessageLookupByLibrary.simpleMessage("Modo regla"),
    "actionStart": MessageLookupByLibrary.simpleMessage("Iniciar/Detener"),
    "actionTun": MessageLookupByLibrary.simpleMessage("TUN"),
    "actionUpdateProfiles": MessageLookupByLibrary.simpleMessage(
      "Actualizar perfiles",
    ),
    "actionView": MessageLookupByLibrary.simpleMessage("Mostrar/Ocultar"),
    "add": MessageLookupByLibrary.simpleMessage("Añadir"),
    "addCustomProxy": MessageLookupByLibrary.simpleMessage("Añadir proxy"),
    "addFilters": MessageLookupByLibrary.simpleMessage("Añadir filtros"),
    "addNodes": MessageLookupByLibrary.simpleMessage("Añadir nodos"),
    "addOverrideEntry": MessageLookupByLibrary.simpleMessage(
      "Añadir entrada de sobrescritura",
    ),
    "addProfile": MessageLookupByLibrary.simpleMessage("Añadir perfil"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Añadir grupo de proxies",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Añadir regla"),
    "addSettingEntry": MessageLookupByLibrary.simpleMessage("Añadir ajuste"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Añadir SSID"),
    "addToLocalProxies": MessageLookupByLibrary.simpleMessage(
      "Añadir a proxies locales",
    ),
    "addedRules": MessageLookupByLibrary.simpleMessage("Reglas añadidas"),
    "addedToLocalProxies": m1,
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Parámetros adicionales",
    ),
    "additionalPrefix": MessageLookupByLibrary.simpleMessage(
      "Prefijo del nombre",
    ),
    "additionalSuffix": MessageLookupByLibrary.simpleMessage(
      "Sufijo del nombre",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Dirección"),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Introduce una dirección WebDAV válida",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage(
      "Configuración avanzada",
    ),
    "ageEncryptedProfile": MessageLookupByLibrary.simpleMessage(
      "Perfil cifrado",
    ),
    "ageSecretKey": MessageLookupByLibrary.simpleMessage(
      "Clave secreta de age",
    ),
    "ageSecretKeyRequiredTip": MessageLookupByLibrary.simpleMessage(
      "Este perfil está cifrado con age y necesita una clave secreta de age para descifrarse",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Aceptar"),
    "allReferencedProxies": MessageLookupByLibrary.simpleMessage(
      "Todos los proxies referenciados",
    ),
    "allReferencedProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Todos los proveedores de proxies referenciados",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage(
      "Permitir que las apps eludan la VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Permitir LAN"),
    "allowedIps": MessageLookupByLibrary.simpleMessage("IP permitidas"),
    "alreadyInLocalProxies": m2,
    "answers": MessageLookupByLibrary.simpleMessage("Respuestas"),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "Control de acceso de apps",
    ),
    "appIconDesign": MessageLookupByLibrary.simpleMessage(
      "Diseño del icono de la app",
    ),
    "appProxiesEmpty": MessageLookupByLibrary.simpleMessage(
      "No hay proxies locales",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage(
      "Añadir DNS del sistema",
    ),
    "applied": MessageLookupByLibrary.simpleMessage("Aplicado"),
    "applyNow": MessageLookupByLibrary.simpleMessage("Aplicar ahora"),
    "arguments": MessageLookupByLibrary.simpleMessage("Argumentos"),
    "authentication": MessageLookupByLibrary.simpleMessage("Autenticación"),
    "authenticationSystemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "El proxy del sistema no se aplica mientras la autenticación esté activada.",
    ),
    "authorize": MessageLookupByLibrary.simpleMessage("Autorizar"),
    "authorized": MessageLookupByLibrary.simpleMessage("Autorizado"),
    "auto": MessageLookupByLibrary.simpleMessage("Automático"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage(
      "Buscar actualizaciones automáticamente",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Cerrar conexiones automáticamente",
    ),
    "autoInclude": MessageLookupByLibrary.simpleMessage(
      "Incluir automáticamente",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Inicio automático"),
    "autoRun": MessageLookupByLibrary.simpleMessage("Ejecución automática"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "La ejecución automática inicia el proxy al abrir la app.",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Configurar DNS del sistema automáticamente",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage(
      "Actualización automática",
    ),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización automática",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Atrás"),
    "backgroundBlur": MessageLookupByLibrary.simpleMessage(
      "Desenfoque de fondo",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Copia de seguridad"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Copia de seguridad y restauración",
    ),
    "backupFromNewerVersion": MessageLookupByLibrary.simpleMessage(
      "Esta copia de seguridad procede de una versión más reciente de la app. Actualiza la app antes de restaurarla",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage(
      "Copia de seguridad completada",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Información básica"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage(
      "Estrategias básicas",
    ),
    "batchImport": MessageLookupByLibrary.simpleMessage("Importar en lote"),
    "batchLineInputTip": MessageLookupByLibrary.simpleMessage(
      "Un elemento por línea",
    ),
    "batchLinkInputTip": MessageLookupByLibrary.simpleMessage(
      "Un enlace por línea",
    ),
    "batchPreviewTip": m3,
    "batchUrlInputTip": MessageLookupByLibrary.simpleMessage(
      "Una URL por línea",
    ),
    "binaryData": MessageLookupByLibrary.simpleMessage("Datos binarios"),
    "bind": MessageLookupByLibrary.simpleMessage("Vincular"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Modo lista negra"),
    "blockQuic": MessageLookupByLibrary.simpleMessage("Bloquear QUIC"),
    "bodyRewrite": MessageLookupByLibrary.simpleMessage(
      "Reescritura del cuerpo",
    ),
    "brightness": MessageLookupByLibrary.simpleMessage("Brillo"),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Dominios excluidos"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios excluidos solo se aplican mientras el proxy del sistema esté activado.",
    ),
    "bypassPrivateRoute": MessageLookupByLibrary.simpleMessage(
      "Omitir direcciones privadas",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Caché"),
    "cacheAlgorithm": MessageLookupByLibrary.simpleMessage(
      "Algoritmo de caché",
    ),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "La caché está dañada. ¿Borrarla?",
    ),
    "cacheMaxSize": MessageLookupByLibrary.simpleMessage("Tamaño de caché"),
    "cameraPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Permite el acceso a la cámara en los ajustes del sistema para escanear códigos QR, o elige una imagen de código QR del álbum.",
    ),
    "cameraPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de cámara",
    ),
    "cameraUnavailable": MessageLookupByLibrary.simpleMessage(
      "Cámara no disponible",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancelar"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Deseleccionar todo",
    ),
    "cannotSave": MessageLookupByLibrary.simpleMessage("No se puede guardar"),
    "certificate": MessageLookupByLibrary.simpleMessage("Certificado"),
    "changeProxyFailedTip": MessageLookupByLibrary.simpleMessage(
      "No se pudo cambiar de proxy; se ha restaurado la selección anterior",
    ),
    "changelogBreaking": MessageLookupByLibrary.simpleMessage(
      "Cambios incompatibles",
    ),
    "changelogFeatures": MessageLookupByLibrary.simpleMessage("Novedades"),
    "changelogFixes": MessageLookupByLibrary.simpleMessage("Correcciones"),
    "changelogPerformance": MessageLookupByLibrary.simpleMessage("Rendimiento"),
    "changelogReverts": MessageLookupByLibrary.simpleMessage("Reversiones"),
    "checkCertificate": MessageLookupByLibrary.simpleMessage(
      "Verificar certificados TLS",
    ),
    "checkCertificateDesc": MessageLookupByLibrary.simpleMessage(
      "Con la verificación TLS desactivada, las suscripciones y las copias de seguridad quedan expuestas a ataques de intermediario.",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage(
      "Buscar actualizaciones",
    ),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "La app ya está actualizada",
    ),
    "cipher": MessageLookupByLibrary.simpleMessage("Cifrado"),
    "clearData": MessageLookupByLibrary.simpleMessage("Borrar datos"),
    "clearDataAndExitTip": MessageLookupByLibrary.simpleMessage(
      "Esto elimina todos los perfiles, ajustes y datos locales, y luego cierra la app. Ábrela de nuevo para empezar de cero.",
    ),
    "clearDataFailed": m4,
    "clearDnsCache": MessageLookupByLibrary.simpleMessage(
      "Borrar la caché DNS",
    ),
    "clearDnsCacheFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo borrar la caché DNS",
    ),
    "clearSearch": MessageLookupByLibrary.simpleMessage("Borrar búsqueda"),
    "clientFingerprint": MessageLookupByLibrary.simpleMessage(
      "Huella del cliente",
    ),
    "clipboardExport": MessageLookupByLibrary.simpleMessage(
      "Exportar al portapapeles",
    ),
    "clipboardImport": MessageLookupByLibrary.simpleMessage(
      "Importar desde el portapapeles",
    ),
    "clipboardNoPackageNames": MessageLookupByLibrary.simpleMessage(
      "No hay nombres de paquete válidos en el portapapeles",
    ),
    "clipboardWriteFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo copiar al portapapeles. Puede que la selección sea demasiado grande",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Cerrar"),
    "closeConnection": MessageLookupByLibrary.simpleMessage("Cerrar conexión"),
    "closeConnections": MessageLookupByLibrary.simpleMessage(
      "Cerrar conexiones",
    ),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorStyle": MessageLookupByLibrary.simpleMessage("Estilo de color"),
    "columns": MessageLookupByLibrary.simpleMessage("Columnas"),
    "compact": MessageLookupByLibrary.simpleMessage("Compacto"),
    "compatible": MessageLookupByLibrary.simpleMessage(
      "Modo de compatibilidad",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirmar"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres borrar todos los datos?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres eliminar este grupo de proxies?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres salir de la ventana actual?",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres forzar el fallo del núcleo?",
    ),
    "congestionControl": MessageLookupByLibrary.simpleMessage(
      "Control de congestión",
    ),
    "congestionController": MessageLookupByLibrary.simpleMessage(
      "Control de congestión TCP",
    ),
    "congestionControllerDesc": MessageLookupByLibrary.simpleMessage(
      "El control de congestión TCP solo funciona con la pila mips.",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Conectado"),
    "connecting": MessageLookupByLibrary.simpleMessage("Conectando…"),
    "connection": MessageLookupByLibrary.simpleMessage("Conexión"),
    "connectionStats": MessageLookupByLibrary.simpleMessage(
      "Estadísticas de conexión",
    ),
    "connectionStatsDesc": MessageLookupByLibrary.simpleMessage(
      "Conexiones activas, solicitudes recientes y consultas DNS",
    ),
    "connections": MessageLookupByLibrary.simpleMessage("Conexiones"),
    "connectivity": MessageLookupByLibrary.simpleMessage("Conectividad: "),
    "content": MessageLookupByLibrary.simpleMessage("Contenido"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "El contenido no puede estar vacío",
    ),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Controlar las reglas añadidas globales",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copiar"),
    "copyAsBase64": MessageLookupByLibrary.simpleMessage("Copiar como Base64"),
    "copyAsCurl": MessageLookupByLibrary.simpleMessage("Copiar como cURL"),
    "copyDestination": MessageLookupByLibrary.simpleMessage("Copiar destino"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copiar variables de entorno",
    ),
    "copyHost": MessageLookupByLibrary.simpleMessage("Copiar host"),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copiar enlace"),
    "copyRequest": MessageLookupByLibrary.simpleMessage("Copiar solicitud"),
    "copyResponse": MessageLookupByLibrary.simpleMessage("Copiar respuesta"),
    "copyResponseBody": MessageLookupByLibrary.simpleMessage(
      "Copiar cuerpo de la respuesta",
    ),
    "copySuccess": MessageLookupByLibrary.simpleMessage(
      "Copiado correctamente",
    ),
    "core": MessageLookupByLibrary.simpleMessage("Núcleo"),
    "coreBlockedByPolicyTip": m5,
    "coreBlockedBySmartAppControlTip": MessageLookupByLibrary.simpleMessage(
      "Smart App Control de Windows bloqueó FlClashCore.exe porque no está firmado. Abre Seguridad de Windows → Control de aplicaciones y navegador → Configuración de Smart App Control, elige Desactivado y vuelve a iniciar Flash. Smart App Control no se puede volver a activar sin reinstalar Windows.",
    ),
    "coreStatus": MessageLookupByLibrary.simpleMessage("Estado del núcleo"),
    "country": MessageLookupByLibrary.simpleMessage("Región"),
    "crashDetected": MessageLookupByLibrary.simpleMessage("Fallo detectado"),
    "crashDetectedTip": m6,
    "crashTest": MessageLookupByLibrary.simpleMessage("Prueba de fallo"),
    "create": MessageLookupByLibrary.simpleMessage("Crear"),
    "createProfileFromUrlTip": m7,
    "creationTime": MessageLookupByLibrary.simpleMessage("Fecha de creación"),
    "currentOutboundDesc": MessageLookupByLibrary.simpleMessage(
      "Contiene el botón de inicio y no se puede quitar",
    ),
    "custom": MessageLookupByLibrary.simpleMessage("Personalizado"),
    "customColor": MessageLookupByLibrary.simpleMessage("Color personalizado"),
    "customImportDroppedSubRules": m8,
    "customIssueCoreRejected": m9,
    "customIssueDialerLoop": m10,
    "customIssueDuplicateName": m11,
    "customIssueEmptyName": MessageLookupByLibrary.simpleMessage(
      "El nombre está vacío",
    ),
    "customIssueGroupLoop": m12,
    "customIssueInvalidEmptyFallback": m13,
    "customIssueInvalidFilter": m14,
    "customIssueMissingDialer": m15,
    "customIssueMissingProviders": m16,
    "customIssueMissingProxies": m17,
    "customIssueNoProxySource": MessageLookupByLibrary.simpleMessage(
      "No hay proxies ni proveedores de proxies seleccionados, por lo que el núcleo rechaza este grupo",
    ),
    "customIssueReservedName": m18,
    "customIssuesSummary": m19,
    "customProfile": MessageLookupByLibrary.simpleMessage("Personalizado"),
    "customResources": MessageLookupByLibrary.simpleMessage("Personalizado"),
    "cut": MessageLookupByLibrary.simpleMessage("Cortar"),
    "dark": MessageLookupByLibrary.simpleMessage("Oscuro"),
    "dashboard": MessageLookupByLibrary.simpleMessage("Panel"),
    "dashboardAddableSection": MessageLookupByLibrary.simpleMessage(
      "Disponibles para añadir",
    ),
    "databaseWriteFailedTip": MessageLookupByLibrary.simpleMessage(
      "No se pudo guardar el cambio; se ha revertido",
    ),
    "daysAgo": m20,
    "daysAgoShort": m21,
    "decryptUntrusted": MessageLookupByLibrary.simpleMessage(
      "Descifrar sin confianza local",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resuelve los nombres de los demás servidores DNS. Solo direcciones IP.",
    ),
    "defaultSelected": MessageLookupByLibrary.simpleMessage(
      "Selección predeterminada",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Predeterminado"),
    "definitionNotMap": MessageLookupByLibrary.simpleMessage(
      "La configuración debe ser un mapa YAML con un nombre y un tipo",
    ),
    "delay": MessageLookupByLibrary.simpleMessage("Latencia"),
    "delayFailed": MessageLookupByLibrary.simpleMessage("Fallido"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Prueba de latencia"),
    "delayTestTimeout": MessageLookupByLibrary.simpleMessage(
      "Tiempo de espera de la prueba de latencia",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Eliminar"),
    "deleteMultipTip": m22,
    "deleteTip": m23,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Un cliente proxy multiplataforma basado en ClashMeta, sencillo de usar, de código abierto y sin anuncios.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Destino"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "GeoIP de destino",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "ASN de la IP de destino",
    ),
    "details": m24,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Depende de una API de terceros; solo con fines informativos",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Modo desarrollador"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "El modo desarrollador está activado.",
    ),
    "dialerProxy": MessageLookupByLibrary.simpleMessage("Proxy de marcación"),
    "dialerProxyLoopStopped": m25,
    "dialog": MessageLookupByLibrary.simpleMessage("Diálogo"),
    "direct": MessageLookupByLibrary.simpleMessage("Directo"),
    "directNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resuelve los dominios de las conexiones directas.",
    ),
    "disableIcmpForwarding": MessageLookupByLibrary.simpleMessage(
      "Desactivar reenvío ICMP",
    ),
    "disableIcmpForwardingDesc": MessageLookupByLibrary.simpleMessage(
      "Con el reenvío ICMP desactivado, TUN responde él mismo al ping, por lo que ping ya no muestra la latencia real.",
    ),
    "disableKeepAlive": MessageLookupByLibrary.simpleMessage(
      "Desactivar keep-alive TCP",
    ),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Desactivar UDP"),
    "disabled": MessageLookupByLibrary.simpleMessage("Desactivado"),
    "discardChanges": MessageLookupByLibrary.simpleMessage(
      "¿Descartar los cambios?",
    ),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Aviso legal"),
    "disclaimerAcceptContent": MessageLookupByLibrary.simpleMessage(
      "Esta declaración explica la naturaleza, los riesgos y las responsabilidades del uso del Software. No es un término adicional a la GPL-3.0 ni limita ninguno de los derechos que esa licencia te otorga, incluidos los de ejecutar, copiar, modificar y distribuir el Software. Si ambas difieren, prevalece la GPL-3.0.",
    ),
    "disclaimerAcceptTitle": MessageLookupByLibrary.simpleMessage(
      "Relación con la licencia de código abierto",
    ),
    "disclaimerAcknowledgeLabel": MessageLookupByLibrary.simpleMessage(
      "He leído y entiendo esta declaración",
    ),
    "disclaimerAcknowledgeTip": MessageLookupByLibrary.simpleMessage(
      "Para confirmar que lo entiendes, lee la siguiente declaración y marca la casilla de abajo:",
    ),
    "disclaimerAcknowledgeTitle": MessageLookupByLibrary.simpleMessage(
      "Confirma la declaración",
    ),
    "disclaimerChangesContent": MessageLookupByLibrary.simpleMessage(
      "Esta declaración puede revisarse en versiones posteriores; cada versión incluye la que le corresponde.",
    ),
    "disclaimerChangesTitle": MessageLookupByLibrary.simpleMessage(
      "Cambios en esta declaración",
    ),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "Antes de usar Flash («el Software»), lee atentamente esta declaración y asegúrate de entenderla. Tocar «Aceptar» significa que has leído y entendido lo que sigue. Si no quieres continuar, toca «Salir».",
    ),
    "disclaimerLiabilityContent": MessageLookupByLibrary.simpleMessage(
      "En la máxima medida permitida por la ley aplicable, ni los desarrolladores ni ningún colaborador serán responsables de ningún daño directo, indirecto, incidental, especial, punitivo o emergente derivado del uso o de la imposibilidad de usar el Software, incluidos, entre otros, la pérdida de datos, los daños al dispositivo, los fallos de red, la interrupción de la actividad, el lucro cesante o cualquier disputa legal resultante, incluso si se les hubiera advertido de la posibilidad de tales daños.",
    ),
    "disclaimerLiabilityTitle": MessageLookupByLibrary.simpleMessage(
      "Limitación de responsabilidad",
    ),
    "disclaimerLicenseContent": MessageLookupByLibrary.simpleMessage(
      "El Software es de código abierto bajo la licencia GPL-3.0. Según esa licencia puedes ejecutarlo, estudiarlo, modificarlo y distribuirlo; al distribuir el Software o una versión modificada, debes proporcionar también su código fuente bajo GPL-3.0 y conservar los avisos de derechos de autor originales.\n\nLos componentes de terceros del Software, incluido el núcleo Clash.Meta, siguen sus propias licencias. Los autores originales no son responsables de los problemas de las versiones modificadas o distribuidas por otros.",
    ),
    "disclaimerLicenseTitle": MessageLookupByLibrary.simpleMessage(
      "Licencia de código abierto",
    ),
    "disclaimerNoServiceStatement": MessageLookupByLibrary.simpleMessage(
      "El Software en sí no proporciona ningún servidor proxy, nodo, suscripción ni servicio de acceso a la red, y no mantiene ninguna relación de asociación, representación ni garantía con ningún proveedor de dichos servicios.",
    ),
    "disclaimerPrivacyContent": MessageLookupByLibrary.simpleMessage(
      "El Software no recopila ni sube tus URL de suscripción, los detalles de los nodos, el contenido de las configuraciones, los sitios web visitados, los registros de conexión, el contenido del tráfico ni los registros. Estos datos permanecen en tu dispositivo y los desarrolladores no tienen acceso a ellos.\n\nEl Software solo accede a la red cuando usas una función que lo necesita, como obtener la URL de suscripción que indicaste al actualizar un perfil o conectarse a GitHub al buscar actualizaciones.\n\nEl Software no incluye ningún servicio de analítica ni de informes de fallos en ninguna plataforma.",
    ),
    "disclaimerPrivacyTitle": MessageLookupByLibrary.simpleMessage(
      "Recopilación de datos y privacidad",
    ),
    "disclaimerResponsibilityContent": MessageLookupByLibrary.simpleMessage(
      "Eres responsable de asegurarte de que el uso del Software sea legal donde vives, y asumes tú solo la responsabilidad legal de todo lo que hagas con él y de sus consecuencias.\n\nLas suscripciones, los nodos y las configuraciones que importas son decisión tuya. Que su origen sea legal, su contenido seguro y su servicio fiable es un asunto entre tú y sus proveedores.",
    ),
    "disclaimerResponsibilityTitle": MessageLookupByLibrary.simpleMessage(
      "Tu responsabilidad",
    ),
    "disclaimerRestateHint": MessageLookupByLibrary.simpleMessage(
      "Escribe la declaración anterior",
    ),
    "disclaimerRestateMismatch": MessageLookupByLibrary.simpleMessage(
      "No coincide con la declaración",
    ),
    "disclaimerRestateTip": MessageLookupByLibrary.simpleMessage(
      "Para confirmar que lo entiendes, escribe la siguiente declaración completa en el campo de abajo:",
    ),
    "disclaimerRestateTitle": MessageLookupByLibrary.simpleMessage(
      "Repite la declaración",
    ),
    "disclaimerSoftwareContent": MessageLookupByLibrary.simpleMessage(
      "El Software es un cliente proxy de red de código abierto basado en el núcleo Clash.Meta (mihomo). Solo ofrece herramientas locales como la gestión de configuración, el enrutamiento basado en reglas y el reenvío de tráfico.",
    ),
    "disclaimerSoftwareTitle": MessageLookupByLibrary.simpleMessage(
      "Naturaleza del software",
    ),
    "disclaimerThirdPartyContent": MessageLookupByLibrary.simpleMessage(
      "Los enlaces de suscripción, los archivos de configuración, los conjuntos de reglas, los scripts, los recursos externos y los enlaces externos los proporcionan terceros. Los desarrolladores no pueden revisar ni garantizar, ni lo hacen, su legalidad, exactitud, seguridad o disponibilidad.\n\nCualquier fuga de datos, pérdida económica, bloqueo de cuenta u otra pérdida causada por contenido de terceros debe resolverse entre tú y el tercero; los desarrolladores no asumen ninguna responsabilidad por ello.",
    ),
    "disclaimerThirdPartyTitle": MessageLookupByLibrary.simpleMessage(
      "Contenido de terceros",
    ),
    "disclaimerUsageContent": MessageLookupByLibrary.simpleMessage(
      "Cualquier actividad comercial que alguien realice con el Software, incluida la distribución de pago, la venta en paquete o su uso como parte de un servicio comercial, no tiene relación con los desarrolladores del Software, que no la respaldan, apoyan ni garantizan.\n\nEres responsable de cumplir las leyes del país o región donde te encuentres y asumes las consecuencias de cualquier uso ilegal del Software.",
    ),
    "disclaimerUsageTitle": MessageLookupByLibrary.simpleMessage(
      "Sobre el uso",
    ),
    "disclaimerWarrantyContent": MessageLookupByLibrary.simpleMessage(
      "El Software se proporciona “tal cual” y “según disponibilidad”, sin garantía de ningún tipo, expresa o implícita, incluidas, entre otras, las garantías de comerciabilidad, idoneidad para un fin concreto, no infracción, disponibilidad ininterrumpida, ausencia de errores o ausencia de vulnerabilidades de seguridad.\n\nLos desarrolladores no garantizan que el Software satisfaga tus necesidades ni que funcione sin interrupciones ni errores.",
    ),
    "disclaimerWarrantyTitle": MessageLookupByLibrary.simpleMessage(
      "Sin garantía",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Desconectado"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "Nueva versión disponible",
    ),
    "dnsCacheCleared": MessageLookupByLibrary.simpleMessage(
      "Caché DNS borrada",
    ),
    "dnsHijackDesc": MessageLookupByLibrary.simpleMessage(
      "Sin esta entrada, TUN secuestra todas las consultas DNS al puerto 53 (any:53).",
    ),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("Secuestro de DNS"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("Modo DNS"),
    "dnsOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Las entradas añadidas aquí sustituyen el DNS de todos los perfiles de URL y de archivo; lo que no añadas conserva el ajuste del propio perfil. Los perfiles personalizados definen su DNS en su contenido.",
    ),
    "dnsQueries": MessageLookupByLibrary.simpleMessage("Consultas DNS"),
    "docked": MessageLookupByLibrary.simpleMessage("Fija"),
    "domain": MessageLookupByLibrary.simpleMessage("Dominio"),
    "done": MessageLookupByLibrary.simpleMessage("Hecho"),
    "download": MessageLookupByLibrary.simpleMessage("Descarga"),
    "downloadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Ancho de banda de descarga",
    ),
    "downloadingUpdate": MessageLookupByLibrary.simpleMessage(
      "Descargando actualización",
    ),
    "duration": MessageLookupByLibrary.simpleMessage("Duración"),
    "edit": MessageLookupByLibrary.simpleMessage("Editar"),
    "editDashboard": MessageLookupByLibrary.simpleMessage("Editar panel"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Editar reglas globales",
    ),
    "editProxy": MessageLookupByLibrary.simpleMessage("Editar proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Editar grupo de proxies",
    ),
    "editRule": MessageLookupByLibrary.simpleMessage("Editar regla"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Editar SSID"),
    "editorUnavailable": MessageLookupByLibrary.simpleMessage(
      "Editor no disponible",
    ),
    "elapsed": MessageLookupByLibrary.simpleMessage("Tardó"),
    "emptyFallback": MessageLookupByLibrary.simpleMessage(
      "Respaldo si está vacío",
    ),
    "emptyTip": m26,
    "en": MessageLookupByLibrary.simpleMessage("Inglés"),
    "enabled": MessageLookupByLibrary.simpleMessage("Activado"),
    "entries": MessageLookupByLibrary.simpleMessage(" entradas"),
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Detalles del error"),
    "es": MessageLookupByLibrary.simpleMessage("Español"),
    "exclude": MessageLookupByLibrary.simpleMessage(
      "Ocultar de aplicaciones recientes",
    ),
    "excludeDstPort": MessageLookupByLibrary.simpleMessage(
      "Puertos de destino excluidos",
    ),
    "excludeFilter": MessageLookupByLibrary.simpleMessage(
      "Filtro de exclusión",
    ),
    "excludeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces excluidas",
    ),
    "excludeSrcPort": MessageLookupByLibrary.simpleMessage(
      "Puertos de origen excluidos",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Excluir SSID"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "Al conectarte a una red Wi-Fi con un SSID excluido, el estado de ejecución de la app cambia automáticamente.",
    ),
    "excludeUid": MessageLookupByLibrary.simpleMessage(
      "ID de usuario excluidos",
    ),
    "existsTip": m27,
    "exit": MessageLookupByLibrary.simpleMessage("Salir"),
    "exitFullScreen": MessageLookupByLibrary.simpleMessage(
      "Salir de pantalla completa",
    ),
    "exitNodes": MessageLookupByLibrary.simpleMessage("Nodos de salida"),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Estado esperado"),
    "expireTime": MessageLookupByLibrary.simpleMessage("Fecha de vencimiento"),
    "exportCertificate": MessageLookupByLibrary.simpleMessage(
      "Exportar certificado",
    ),
    "exportFile": MessageLookupByLibrary.simpleMessage("Exportar archivo"),
    "exportHar": MessageLookupByLibrary.simpleMessage("Exportar HAR"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Exportar registros"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage(
      "Exportación completada",
    ),
    "extend": MessageLookupByLibrary.simpleMessage("Extensión"),
    "extendMode": MessageLookupByLibrary.simpleMessage("Modo de extensión"),
    "extendScript": MessageLookupByLibrary.simpleMessage("Script de extensión"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "Controlador externo",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "El controlador externo permite controlar el núcleo en el puerto 9090.",
    ),
    "externalControllerSecret": MessageLookupByLibrary.simpleMessage(
      "Clave del controlador externo",
    ),
    "externalLink": MessageLookupByLibrary.simpleMessage("Enlace externo"),
    "extraLarge": MessageLookupByLibrary.simpleMessage("Muy grande"),
    "fade": MessageLookupByLibrary.simpleMessage("Fundido"),
    "failedCount": m28,
    "failedItem": m29,
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Filtro Fake-IP"),
    "fakeipFilterDesc": MessageLookupByLibrary.simpleMessage(
      "Estos dominios reciben su IP real en lugar de una Fake-IP. En modo whitelist, solo ellos reciben Fake-IP.",
    ),
    "fakeipFilterMode": MessageLookupByLibrary.simpleMessage(
      "Modo de filtro Fake-IP",
    ),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Rango Fake-IP"),
    "fakeipRange6": MessageLookupByLibrary.simpleMessage(
      "Rango Fake-IP (IPv6)",
    ),
    "fakeipTtl": MessageLookupByLibrary.simpleMessage("TTL de Fake-IP"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage(
      "Se usan en lugar de Nameserver cuando el filtro de respaldo considera contaminada su respuesta.",
    ),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage(
      "Filtro de respaldo",
    ),
    "fallbackFilterDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Estos dominios se resuelven directamente con Fallback.",
    ),
    "fallbackFilterGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios de estas categorías GeoSite se resuelven directamente con Fallback.",
    ),
    "fallbackFilterIpcidrDesc": MessageLookupByLibrary.simpleMessage(
      "Si Nameserver devuelve una IP de estos rangos, se usa la respuesta de Fallback.",
    ),
    "file": MessageLookupByLibrary.simpleMessage("Archivo"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "El archivo se ha modificado. ¿Guardar los cambios?",
    ),
    "filter": MessageLookupByLibrary.simpleMessage("Filtro"),
    "filters": MessageLookupByLibrary.simpleMessage("Filtros"),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Buscar proceso"),
    "floating": MessageLookupByLibrary.simpleMessage("Flotante"),
    "followProfile": MessageLookupByLibrary.simpleMessage("Seguir perfil"),
    "followSystem": MessageLookupByLibrary.simpleMessage("Seguir el sistema"),
    "fontFamily": MessageLookupByLibrary.simpleMessage("Familia de fuente"),
    "fontSize": MessageLookupByLibrary.simpleMessage("Tamaño"),
    "forceDnsMapping": MessageLookupByLibrary.simpleMessage("Forzar mapeo DNS"),
    "forceDnsMappingDesc": MessageLookupByLibrary.simpleMessage(
      "Forzar mapeo DNS también analiza las conexiones cuyo dominio provino de un mapeo DNS.",
    ),
    "forceDomain": MessageLookupByLibrary.simpleMessage("Forzar dominios"),
    "forceDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios forzados también se analizan; las demás conexiones que ya tienen dominio se dejan como están.",
    ),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres forzar el reinicio del núcleo?",
    ),
    "fr": MessageLookupByLibrary.simpleMessage("Francés"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generalOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Las entradas añadidas aquí sustituyen el ajuste correspondiente de todos los perfiles; lo que no añadas conserva el ajuste del propio perfil, o el valor predeterminado del núcleo si el perfil no lo define.",
    ),
    "generateCertificate": MessageLookupByLibrary.simpleMessage(
      "Generar certificado",
    ),
    "geoResources": MessageLookupByLibrary.simpleMessage("Geo"),
    "geoSkipped": m30,
    "geoUpdated": m31,
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Modo geo de poca memoria",
    ),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Ir"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Descargar"),
    "goToConfigureAddedRules": MessageLookupByLibrary.simpleMessage(
      "Ir a la configuración de las reglas añadidas",
    ),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Ir a la configuración del script",
    ),
    "grid": MessageLookupByLibrary.simpleMessage("Cuadrícula"),
    "groupBy": MessageLookupByLibrary.simpleMessage("Agrupar por"),
    "groupCount": m32,
    "groupCountUnit": MessageLookupByLibrary.simpleMessage("grupos"),
    "groupTimeoutCount": m33,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage(
      "¿Guardar los cambios en la caché?",
    ),
    "hashByInUser": MessageLookupByLibrary.simpleMessage(
      "Hash por usuario de entrada",
    ),
    "headerRewrite": MessageLookupByLibrary.simpleMessage(
      "Reescritura de cabeceras",
    ),
    "healthCheck": MessageLookupByLibrary.simpleMessage(
      "Comprobación de estado",
    ),
    "helperCorruptTip": MessageLookupByLibrary.simpleMessage(
      "El servicio auxiliar (Helper) no está disponible; no se puede activar el modo TUN. Reinstala Flash para restaurarlo.",
    ),
    "hex": MessageLookupByLibrary.simpleMessage("Hex"),
    "hiddenGroupSemantics": m34,
    "hiddenGroupTag": MessageLookupByLibrary.simpleMessage("Oculto"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Ocultar de la lista"),
    "hideIp": MessageLookupByLibrary.simpleMessage("Ocultar IP"),
    "hidePassword": MessageLookupByLibrary.simpleMessage("Ocultar contraseña"),
    "hideTimeoutProxies": MessageLookupByLibrary.simpleMessage(
      "Ocultar proxies sin respuesta",
    ),
    "hopInterval": MessageLookupByLibrary.simpleMessage("Intervalo de salto"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostname": MessageLookupByLibrary.simpleMessage("Nombre de host"),
    "hotkeyConflictWith": m35,
    "hotkeyDesc": MessageLookupByLibrary.simpleMessage(
      "Los atajos globales funcionan incluso con la ventana oculta. Toca una acción para grabar su combinación de teclas.",
    ),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Gestión de atajos",
    ),
    "hotkeyNeedsModifier": m36,
    "hotkeyNotSet": MessageLookupByLibrary.simpleMessage("Sin asignar"),
    "hotkeyUnavailable": MessageLookupByLibrary.simpleMessage(
      "No registrado; puede que otra app lo esté usando",
    ),
    "hours": MessageLookupByLibrary.simpleMessage("horas"),
    "hoursAgo": m37,
    "hoursAgoShort": m38,
    "http2": MessageLookupByLibrary.simpleMessage("HTTP/2"),
    "httpBodyNotKept": MessageLookupByLibrary.simpleMessage(
      "No se registró por falta de memoria.",
    ),
    "httpBodyProtobufGuess": MessageLookupByLibrary.simpleMessage(
      "Leído como Protobuf sin esquema: solo números de campo, y los tipos son supuestos.",
    ),
    "httpBodyTruncated": MessageLookupByLibrary.simpleMessage(
      "Solo se registró el comienzo de este cuerpo.",
    ),
    "httpBodyUndecoded": m39,
    "httpCapture": MessageLookupByLibrary.simpleMessage("Captura HTTP"),
    "httpCaptureDesc": MessageLookupByLibrary.simpleMessage(
      "Registra las solicitudes a los hosts indicados en Nombre de host, para verlas en los detalles de la conexión. Los registros solo se guardan en memoria.",
    ),
    "httpCaptureLimit": MessageLookupByLibrary.simpleMessage(
      "Máximo de registros",
    ),
    "httpCaptureLimitDesc": m40,
    "httpCaptureNoHosts": MessageLookupByLibrary.simpleMessage(
      "No hay ningún host indicado, así que no se registra nada. Añade hosts en Nombre de host, en la página MITM, o desde los detalles de una conexión.",
    ),
    "httpCaptureOff": MessageLookupByLibrary.simpleMessage(
      "La captura está desactivada",
    ),
    "httpExportPrivate": MessageLookupByLibrary.simpleMessage(
      "Una solicitud puede llevar cookies, tokens, contraseñas y contenido de formularios. Revisa qué compartes y con quién.",
    ),
    "httpExportPrivateTitle": MessageLookupByLibrary.simpleMessage(
      "Contiene datos privados",
    ),
    "httpRequestCleared": MessageLookupByLibrary.simpleMessage(
      "El registro de esta solicitud se ha borrado",
    ),
    "httpRequests": MessageLookupByLibrary.simpleMessage("Solicitudes HTTP"),
    "httpRequestsMissing": MessageLookupByLibrary.simpleMessage(
      "Las solicitudes enviadas antes de activar la captura, o ya borradas, no aparecen.",
    ),
    "httpsDecryption": MessageLookupByLibrary.simpleMessage("Descifrado HTTPS"),
    "hue": MessageLookupByLibrary.simpleMessage("Tono"),
    "icon": MessageLookupByLibrary.simpleMessage("Icono"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("Registros de iconos"),
    "iconSets": MessageLookupByLibrary.simpleMessage("Conjuntos de iconos"),
    "iconSetsEmptyTip": MessageLookupByLibrary.simpleMessage(
      "Aún no hay conjuntos de iconos. Añádelos en Recursos de perfil personalizado → Conjuntos de iconos",
    ),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Estilo de icono"),
    "iconStyleFilled": MessageLookupByLibrary.simpleMessage("Relleno"),
    "iconStyleHidden": MessageLookupByLibrary.simpleMessage("Oculto"),
    "iconStylePlain": MessageLookupByLibrary.simpleMessage("Simple"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("URL del icono"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignorar optimización de batería",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Importar"),
    "importConfigInvalid": MessageLookupByLibrary.simpleMessage(
      "Este archivo no es una configuración importable",
    ),
    "importConfigReplaceTip": MessageLookupByLibrary.simpleMessage(
      "Al importar se reemplazan los grupos de proxies, las reglas y los ajustes que tiene ahora este perfil",
    ),
    "importFile": MessageLookupByLibrary.simpleMessage(
      "Importar desde archivo",
    ),
    "importFromLink": MessageLookupByLibrary.simpleMessage(
      "Importar desde enlace",
    ),
    "importUrl": MessageLookupByLibrary.simpleMessage("Importar desde URL"),
    "inProgress": MessageLookupByLibrary.simpleMessage("En curso"),
    "inbound": MessageLookupByLibrary.simpleMessage("Entrada"),
    "includeInterface": MessageLookupByLibrary.simpleMessage(
      "Interfaces incluidas",
    ),
    "includeInterfaceDesc": MessageLookupByLibrary.simpleMessage(
      "Solo el tráfico que llega por las interfaces incluidas pasa por TUN, y las interfaces excluidas dejan de aplicarse.",
    ),
    "includeUid": MessageLookupByLibrary.simpleMessage(
      "ID de usuario incluidos",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("No caduca"),
    "infoAbout": MessageLookupByLibrary.simpleMessage("About"),
    "init": MessageLookupByLibrary.simpleMessage("Inicio"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Error al iniciar"),
    "initFailedTip": MessageLookupByLibrary.simpleMessage(
      "Flash encontró un error al iniciarse y no puede continuar. Copia los detalles para informar del problema. Si sigue ocurriendo, borrar los datos suele permitir que la app vuelva a iniciarse.",
    ),
    "initiator": MessageLookupByLibrary.simpleMessage("Origen de la solicitud"),
    "initiatorShort": MessageLookupByLibrary.simpleMessage("De"),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Introduce el nombre del grupo de proxies",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Introduce el contenido de la regla",
    ),
    "installCertificate": MessageLookupByLibrary.simpleMessage(
      "Instalar en el sistema",
    ),
    "installCertificateSuccess": MessageLookupByLibrary.simpleMessage(
      "Certificado instalado",
    ),
    "installedAppsPermissionDeniedMessage":
        MessageLookupByLibrary.simpleMessage(
          "Se denegó el permiso de lista de apps, por lo que no se pueden mostrar las apps instaladas. Concédelo manualmente en los ajustes del sistema.",
        ),
    "installedAppsPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Este sistema oculta la lista de apps instaladas hasta que se concede el permiso. Autorízalo para configurar el proxy por app.",
    ),
    "installedAppsPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de lista de apps",
    ),
    "installedFonts": MessageLookupByLibrary.simpleMessage(
      "Fuentes instaladas",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Selección inteligente",
    ),
    "interfaceName": MessageLookupByLibrary.simpleMessage("Nombre de interfaz"),
    "interfaceNameMode": MessageLookupByLibrary.simpleMessage(
      "Interfaz de salida",
    ),
    "interfaceNameModeClear": MessageLookupByLibrary.simpleMessage("Ninguna"),
    "interfaceNameModeCustom": MessageLookupByLibrary.simpleMessage(
      "Personalizada",
    ),
    "interfaceNameModeFollow": MessageLookupByLibrary.simpleMessage(
      "Seguir configuración",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Intervalo"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("IP de intranet"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Archivo de copia de seguridad no válido",
    ),
    "invalidCidrContent": MessageLookupByLibrary.simpleMessage(
      "Introduce un rango de IP en formato CIDR, como 192.168.0.0/16",
    ),
    "invalidDscpContent": MessageLookupByLibrary.simpleMessage(
      "Una marca DSCP no puede superar 63",
    ),
    "invalidHostContent": MessageLookupByLibrary.simpleMessage(
      "Introduce un dominio o una dirección IP",
    ),
    "invalidIconSet": MessageLookupByLibrary.simpleMessage(
      "No es un conjunto de iconos válido",
    ),
    "invalidLinkTip": MessageLookupByLibrary.simpleMessage(
      "No es un enlace de suscripción ni un enlace para compartir proxies",
    ),
    "invalidListenContent": MessageLookupByLibrary.simpleMessage(
      "Introduce una dirección y un puerto, como 0.0.0.0:1053",
    ),
    "invalidNetworkContent": MessageLookupByLibrary.simpleMessage(
      "Solo se admite tcp o udp",
    ),
    "invalidOfCount": m41,
    "invalidPolicy": m42,
    "invalidPortRangeContent": MessageLookupByLibrary.simpleMessage(
      "Introduce un puerto o un rango como 443 u 8000-9000",
    ),
    "invalidProfileQrcode": MessageLookupByLibrary.simpleMessage(
      "Este código QR no contiene un enlace de perfil",
    ),
    "invalidProxy": m43,
    "invalidProxyProvider": m44,
    "invalidRangeContent": MessageLookupByLibrary.simpleMessage(
      "Introduce números o rangos como 80 u 8000-9000, separados por /",
    ),
    "invalidRuleSet": m45,
    "invalidSubRule": m46,
    "ipAddress": MessageLookupByLibrary.simpleMessage("Dirección IP"),
    "ipAsn": MessageLookupByLibrary.simpleMessage("ASN"),
    "ipFlagAbuser": MessageLookupByLibrary.simpleMessage("Historial de abusos"),
    "ipFlagProxy": MessageLookupByLibrary.simpleMessage("Proxy"),
    "ipFlagTor": MessageLookupByLibrary.simpleMessage("Tor"),
    "ipFlagVpn": MessageLookupByLibrary.simpleMessage("VPN"),
    "ipFlags": MessageLookupByLibrary.simpleMessage("Indicadores"),
    "ipOrganization": MessageLookupByLibrary.simpleMessage("Organización"),
    "ipQualityFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo determinar el tipo de IP",
    ),
    "ipQualityGood": MessageLookupByLibrary.simpleMessage("Buena"),
    "ipQualityLevel": MessageLookupByLibrary.simpleMessage("Nivel"),
    "ipQualityNormal": MessageLookupByLibrary.simpleMessage("Normal"),
    "ipQualityRetry": MessageLookupByLibrary.simpleMessage(
      "Comprobar de nuevo",
    ),
    "ipQualityRisky": MessageLookupByLibrary.simpleMessage("Arriesgada"),
    "ipQualityShort": MessageLookupByLibrary.simpleMessage("Calidad"),
    "ipQualitySource": MessageLookupByLibrary.simpleMessage("Respondido por"),
    "ipQualitySources": MessageLookupByLibrary.simpleMessage("Fuentes"),
    "ipSourceIpMismatch": MessageLookupByLibrary.simpleMessage(
      "IP de salida distinta",
    ),
    "ipSourceNoType": MessageLookupByLibrary.simpleMessage("Sin tipo"),
    "ipSourceRateLimited": MessageLookupByLibrary.simpleMessage(
      "Límite de solicitudes",
    ),
    "ipType": MessageLookupByLibrary.simpleMessage("Tipo"),
    "ipTypeBusiness": MessageLookupByLibrary.simpleMessage("Empresarial"),
    "ipTypeHosting": MessageLookupByLibrary.simpleMessage("Centro de datos"),
    "ipTypeMobile": MessageLookupByLibrary.simpleMessage("Red móvil"),
    "ipTypeResidential": MessageLookupByLibrary.simpleMessage("Residencial"),
    "ipTypeUnknown": MessageLookupByLibrary.simpleMessage("Tipo desconocido"),
    "ipVersion": MessageLookupByLibrary.simpleMessage("Versión de IP"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "El tráfico IPv6 solo se recibe mientras IPv6 esté activado.",
    ),
    "ipv6Timeout": MessageLookupByLibrary.simpleMessage(
      "Tiempo de espera IPv6 (ms)",
    ),
    "itemsCount": m47,
    "ja": MessageLookupByLibrary.simpleMessage("Japonés"),
    "justNow": MessageLookupByLibrary.simpleMessage("Ahora mismo"),
    "keepAliveIdle": MessageLookupByLibrary.simpleMessage(
      "Inactividad de keep-alive TCP",
    ),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Intervalo de keep-alive TCP",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Clave"),
    "ko": MessageLookupByLibrary.simpleMessage("Coreano"),
    "label": MessageLookupByLibrary.simpleMessage("Etiqueta"),
    "language": MessageLookupByLibrary.simpleMessage("Idioma"),
    "large": MessageLookupByLibrary.simpleMessage("Grande"),
    "lastUpdated": MessageLookupByLibrary.simpleMessage("Última actualización"),
    "launchInterrupted": MessageLookupByLibrary.simpleMessage(
      "El inicio no se completó",
    ),
    "launchInterruptedTip": MessageLookupByLibrary.simpleMessage(
      "La última vez, la app se cerró inesperadamente mientras se iniciaba. En este inicio se ha omitido la configuración automática; puedes iniciarla manualmente para reintentarlo.",
    ),
    "layout": MessageLookupByLibrary.simpleMessage("Diseño"),
    "light": MessageLookupByLibrary.simpleMessage("Claro"),
    "lineIssueTip": m48,
    "lineWrap": MessageLookupByLibrary.simpleMessage("Ajuste de línea"),
    "link": MessageLookupByLibrary.simpleMessage("Enlace"),
    "liquidGlass": MessageLookupByLibrary.simpleMessage("Liquid Glass"),
    "list": MessageLookupByLibrary.simpleMessage("Lista"),
    "listen": MessageLookupByLibrary.simpleMessage("Escucha"),
    "listenRoutingMark": MessageLookupByLibrary.simpleMessage(
      "Marca de enrutamiento de escucha",
    ),
    "listenRoutingMarkDesc": MessageLookupByLibrary.simpleMessage(
      "La marca de enrutamiento de escucha solo funciona en Linux.",
    ),
    "liveConnections": MessageLookupByLibrary.simpleMessage(
      "Conexiones activas",
    ),
    "loading": MessageLookupByLibrary.simpleMessage("Cargando…"),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localImage": MessageLookupByLibrary.simpleMessage("Imagen local"),
    "localNetworkDeniedTip": MessageLookupByLibrary.simpleMessage(
      "Permiso de red local denegado: con la pila gvisor, la LAN no es accesible.",
    ),
    "localProxies": MessageLookupByLibrary.simpleMessage("Proxies locales"),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Permiso de ubicación",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Se denegó el permiso de ubicación, por lo que no se puede leer el nombre de la red Wi-Fi actual. Activa el permiso de ubicación manualmente en los ajustes del sistema.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "El sistema requiere el permiso de ubicación para leer el nombre de la red Wi-Fi. En Android elige “Permitir todo el tiempo”; de lo contrario, no se podrá leer el nombre de la red Wi-Fi mientras la app esté en segundo plano.",
    ),
    "locationPermissionGuide": m49,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Se requiere permiso de ubicación",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Registro"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Nivel de registro"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Si desactivas Logcat, se oculta la entrada de registros.",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Registros"),
    "logsAndDiagnostics": MessageLookupByLibrary.simpleMessage(
      "Registros y diagnóstico",
    ),
    "logsTest": MessageLookupByLibrary.simpleMessage("Prueba de registros"),
    "loopback": MessageLookupByLibrary.simpleMessage(
      "Exención de loopback de UWP",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Amplio"),
    "mapLocal": MessageLookupByLibrary.simpleMessage("Mapeo local"),
    "matchCase": MessageLookupByLibrary.simpleMessage(
      "Coincidir mayúsculas y minúsculas",
    ),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage(
      "Coincidir con IP de origen",
    ),
    "matchTarget": MessageLookupByLibrary.simpleMessage("MATCH-TARGET"),
    "matchedRules": MessageLookupByLibrary.simpleMessage("Reglas aplicadas"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Máximo de fallos"),
    "maxLengthTip": m50,
    "maximize": MessageLookupByLibrary.simpleMessage("Maximizar"),
    "memoryAppResident": MessageLookupByLibrary.simpleMessage(
      "Memoria residente",
    ),
    "memoryAppShared": MessageLookupByLibrary.simpleMessage("App y compartida"),
    "memoryCoreHeapIdle": MessageLookupByLibrary.simpleMessage("Heap inactivo"),
    "memoryCoreHeapInuse": MessageLookupByLibrary.simpleMessage("Heap en uso"),
    "memoryCoreNotRunning": MessageLookupByLibrary.simpleMessage(
      "El núcleo no se está ejecutando",
    ),
    "memoryCoreRuntime": MessageLookupByLibrary.simpleMessage(
      "Sobrecarga del runtime",
    ),
    "memoryCoreStack": MessageLookupByLibrary.simpleMessage(
      "Pilas de goroutines",
    ),
    "memoryEstimateDesc": MessageLookupByLibrary.simpleMessage(
      "Estimado a partir de la memoria residente del proceso; puede diferir de lo que indica el sistema.",
    ),
    "memoryEstimateSharedDesc": MessageLookupByLibrary.simpleMessage(
      "El núcleo se ejecuta dentro del proceso de la app. Su parte se estima a partir de las estadísticas del runtime, y el resto cuenta como memoria de la app y compartida.",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage(
      "Información de memoria",
    ),
    "memoryInfoDesc": MessageLookupByLibrary.simpleMessage(
      "Memoria que usan la app y el núcleo",
    ),
    "memoryReleased": MessageLookupByLibrary.simpleMessage("Memoria liberada"),
    "memoryReleasedSize": m51,
    "messageTest": MessageLookupByLibrary.simpleMessage("Prueba de mensaje"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "Esto es un mensaje.",
    ),
    "method": MessageLookupByLibrary.simpleMessage("Método"),
    "minimize": MessageLookupByLibrary.simpleMessage("Minimizar"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage(
      "Minimizar al salir",
    ),
    "minutes": MessageLookupByLibrary.simpleMessage("minutos"),
    "minutesAgo": m52,
    "minutesAgoShort": m53,
    "mitm": MessageLookupByLibrary.simpleMessage("MITM"),
    "mitmAddLocalFile": MessageLookupByLibrary.simpleMessage(
      "Añadir un archivo local",
    ),
    "mitmAddMapLocalRule": MessageLookupByLibrary.simpleMessage(
      "Añadir una regla de mapeo local",
    ),
    "mitmAddRejectRule": MessageLookupByLibrary.simpleMessage(
      "Añadir una regla de rechazo",
    ),
    "mitmAttachments": MessageLookupByLibrary.simpleMessage("Adjuntos"),
    "mitmAttachmentsDesc": MessageLookupByLibrary.simpleMessage(
      "Las líneas hacen referencia a los adjuntos por nombre de archivo, como script-path=a.js.",
    ),
    "mitmCertificateAndroidReadyTip": MessageLookupByLibrary.simpleMessage(
      "Solo se descifran las apps que confían en certificados de usuario, sobre todo los navegadores.",
    ),
    "mitmCertificateExportTip": MessageLookupByLibrary.simpleMessage(
      "Expórtalo y confía en él en los dispositivos que quieras descifrar.",
    ),
    "mitmCertificateLinuxTip": MessageLookupByLibrary.simpleMessage(
      "Los navegadores Flatpak necesitan que importes el certificado exportado a mano.",
    ),
    "mitmCertificateSavedTip": m54,
    "mitmCertutilMissing": m55,
    "mitmClientRefusedCertificate": MessageLookupByLibrary.simpleMessage(
      "El cliente rechazó el certificado. Instala la CA o excluye este host si la app fija su certificado.",
    ),
    "mitmDecryptHost": MessageLookupByLibrary.simpleMessage(
      "Descifrar este host",
    ),
    "mitmDecryptHostTip": m56,
    "mitmEnableTip": MessageLookupByLibrary.simpleMessage(
      "Flash podrá leer todo lo que se envíe a los hosts descifrados, incluidas cookies y contraseñas. Actívalo solo para los hosts que quieras reescribir.",
    ),
    "mitmExcludeHost": MessageLookupByLibrary.simpleMessage(
      "Excluir del descifrado",
    ),
    "mitmExcludeHostTip": m57,
    "mitmFileTooLarge": m58,
    "mitmHostnameDesc": MessageLookupByLibrary.simpleMessage(
      "Un - al principio excluye un host, y decide la primera coincidencia.",
    ),
    "mitmIgnoredLines": MessageLookupByLibrary.simpleMessage(
      "Líneas ignoradas",
    ),
    "mitmInstallSystemCaTip": MessageLookupByLibrary.simpleMessage(
      "Se detectó root: el certificado se añadirá a los certificados de confianza del sistema como el módulo de Magisk, KernelSU o APatch «FlClash MITM CA». Todas las apps del dispositivo confiarán en él, y quien tenga su clave privada podrá descifrar el tráfico HTTPS del dispositivo. Para deshacerlo, regenera el certificado o quita el módulo en el gestor de root y reinicia. Si se deniega root, se instalará como certificado de usuario.",
    ),
    "mitmInstallUserCaTip": MessageLookupByLibrary.simpleMessage(
      "No se detectó root: el certificado solo puede instalarse como certificado de usuario. Solo se descifran las apps que confían en certificados de usuario, sobre todo los navegadores; las demás fallan en los hosts que indiques, así que no indiques sus hosts. Desde Android 11 terminas la instalación tú mismo en los ajustes del sistema.",
    ),
    "mitmMissingStores": m59,
    "mitmModule": MessageLookupByLibrary.simpleMessage("Módulo"),
    "mitmModuleInvalid": MessageLookupByLibrary.simpleMessage(
      "No es un módulo de Surge, un plugin de Loon, un fragmento de Quantumult X ni una sobrescritura de Stash",
    ),
    "mitmModuleRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Las reglas de enrutamiento van antes que las del perfil.",
    ),
    "mitmModuleScriptsChanged": m60,
    "mitmModuleSystemTip": m61,
    "mitmModules": MessageLookupByLibrary.simpleMessage("Módulos"),
    "mitmNewModule": MessageLookupByLibrary.simpleMessage("Nuevo módulo"),
    "mitmOldCertificateLeftTip": m62,
    "mitmOldSystemCertificateLeftTip": m63,
    "mitmRemoveOldCertificateTip": m64,
    "mitmRootPendingReboot": MessageLookupByLibrary.simpleMessage(
      "El certificado se aplicará después de reiniciar el dispositivo.",
    ),
    "mitmRootUntilReboot": MessageLookupByLibrary.simpleMessage(
      "No se encontró Magisk, KernelSU ni APatch para conservar el certificado. Vuelve a instalarlo después de reiniciar el dispositivo.",
    ),
    "mitmRoutingRules": MessageLookupByLibrary.simpleMessage(
      "Reglas de enrutamiento",
    ),
    "mitmRuleCopiedForStash": MessageLookupByLibrary.simpleMessage(
      "Este módulo es una sobrescritura de Stash, así que la regla se copió para que la añadas a mano.",
    ),
    "mitmRunScript": MessageLookupByLibrary.simpleMessage("Ejecutar ahora"),
    "mitmScriptNoOutput": MessageLookupByLibrary.simpleMessage(
      "El script terminó sin salida",
    ),
    "mitmScriptRisk": MessageLookupByLibrary.simpleMessage(
      "Sus scripts leen y modifican el tráfico de los hosts que coinciden, incluidas las cookies y los tokens, y pueden enviar sus propias solicitudes. Actívalo solo si confías en su origen.",
    ),
    "mitmScriptRiskTitle": MessageLookupByLibrary.simpleMessage(
      "¿Ejecutar los scripts de este módulo?",
    ),
    "mitmSkipConditional": MessageLookupByLibrary.simpleMessage(
      "Las reescrituras condicionales no son compatibles",
    ),
    "mitmSkipDisabled": MessageLookupByLibrary.simpleMessage(
      "Desactivado por un argumento",
    ),
    "mitmSkipEvent": MessageLookupByLibrary.simpleMessage(
      "Este evento no es compatible",
    ),
    "mitmSkipJq": MessageLookupByLibrary.simpleMessage(
      "Las reescrituras jq no son compatibles",
    ),
    "mitmSkipJsonBody": MessageLookupByLibrary.simpleMessage(
      "Las reescrituras del cuerpo JSON no son compatibles",
    ),
    "mitmSkipNotDownloaded": MessageLookupByLibrary.simpleMessage(
      "Su archivo aún no se ha descargado",
    ),
    "mitmSkipPolicy": MessageLookupByLibrary.simpleMessage(
      "Solo se admiten las políticas DIRECT y REJECT",
    ),
    "mitmSkipRawHeader": MessageLookupByLibrary.simpleMessage(
      "No se admite reescribir todos los encabezados como un solo texto",
    ),
    "mitmSkipRelativeData": MessageLookupByLibrary.simpleMessage(
      "El archivo que nombra esta línea no está adjunto; usa una URL o adjúntalo",
    ),
    "mitmSkipRule": MessageLookupByLibrary.simpleMessage(
      "Este tipo de regla no es compatible",
    ),
    "mitmSkipScriptType": MessageLookupByLibrary.simpleMessage(
      "Este tipo de script no es compatible",
    ),
    "mitmSkipSection": m65,
    "mitmSkipSetting": MessageLookupByLibrary.simpleMessage(
      "Este ajuste no es compatible",
    ),
    "mitmSkipUnreadable": MessageLookupByLibrary.simpleMessage(
      "No se puede leer esta línea",
    ),
    "mitmSystemStoreFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo añadir el certificado a las raíces de confianza del sistema",
    ),
    "mitmTrustChecking": MessageLookupByLibrary.simpleMessage("Comprobando…"),
    "mitmTrustNotInstalled": MessageLookupByLibrary.simpleMessage(
      "No instalado",
    ),
    "mitmTrustReady": MessageLookupByLibrary.simpleMessage("De confianza"),
    "mitmTrustUntrusted": MessageLookupByLibrary.simpleMessage(
      "Sin confianza completa",
    ),
    "mixedPort": MessageLookupByLibrary.simpleMessage("Puerto mixto"),
    "mixedPortUnavailable": m66,
    "mixedPortUnavailableProxyUnchanged": m67,
    "mode": MessageLookupByLibrary.simpleMessage("Modo"),
    "monochromeIcon": MessageLookupByLibrary.simpleMessage("Icono monocromo"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monocromo"),
    "monthsAgo": m68,
    "monthsAgoShort": m69,
    "more": MessageLookupByLibrary.simpleMessage("Más"),
    "mountAbout": MessageLookupByLibrary.simpleMessage("About mounts"),
    "mountAboutBody": MessageLookupByLibrary.simpleMessage(
      "Choose imported subscriptions to add nodes to this profile. Nodes are added only to groups already configured to accept new nodes automatically, using each group’s existing inclusion and exclusion filters. Groups with only fixed members and no automatic collection stay unchanged. Existing nodes, rules, and DNS settings stay unchanged.",
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
    "mountGroupsAllNoMatch": MessageLookupByLibrary.simpleMessage(
      "Mounted nodes match no group filters.",
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
      "Added only to groups that automatically accept new nodes, using each group’s filters.",
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
      "No groups will be created and routing rules will not be changed automatically.",
    ),
    "mountNoGroupIsolatedDesc": MessageLookupByLibrary.simpleMessage(
      "None of the existing groups passed the mount-isolation checks. No group will be created, no direct-connection fallback will be added, and the original profile file will not be rewritten automatically.",
    ),
    "mountNoGroupIsolatedTitle": MessageLookupByLibrary.simpleMessage(
      "Current groups cannot receive mounts",
    ),
    "mountNoGroupTitle": MessageLookupByLibrary.simpleMessage(
      "This profile has no groups that automatically accept new nodes. Mounted nodes have not been added to any group.",
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
    "name": MessageLookupByLibrary.simpleMessage("Nombre"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Servidores DNS predeterminados, como 223.5.5.5, tls://1.1.1.1 o https://dns.google/dns-query.",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Los dominios coincidentes usan el servidor DNS indicado aquí en lugar de Nameserver y Fallback.",
    ),
    "navigationBarStyle": MessageLookupByLibrary.simpleMessage(
      "Barra inferior",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Red"),
    "networkAccessDeniedError": m101,
    "networkBadResponseError": m102,
    "networkCancelledError": MessageLookupByLibrary.simpleMessage(
      "Se canceló la solicitud",
    ),
    "networkConnectionError": MessageLookupByLibrary.simpleMessage(
      "No se pudo conectar con el servidor. Comprueba tu conexión de red o los ajustes del proxy",
    ),
    "networkHostLookupError": MessageLookupByLibrary.simpleMessage(
      "No se pudo resolver la dirección del servidor. Comprueba que la URL sea correcta y que el DNS funcione",
    ),
    "networkName": MessageLookupByLibrary.simpleMessage("Nombre de la red"),
    "networkNotFoundError": m103,
    "networkRateLimitedError": MessageLookupByLibrary.simpleMessage(
      "Demasiadas solicitudes (HTTP 429). Espera un momento e inténtalo de nuevo",
    ),
    "networkRequestFailed": m104,
    "networkSecret": MessageLookupByLibrary.simpleMessage("Clave de la red"),
    "networkServerError": m105,
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Velocidad de red"),
    "networkTakeover": MessageLookupByLibrary.simpleMessage(
      "Control del tráfico",
    ),
    "networkTimeoutError": MessageLookupByLibrary.simpleMessage(
      "Se agotó el tiempo de espera de la solicitud. Comprueba tu red o el proxy e inténtalo de nuevo",
    ),
    "networkTlsError": MessageLookupByLibrary.simpleMessage(
      "Falló la conexión segura. Puede que el certificado del servidor no sea válido o que la conexión esté siendo interceptada",
    ),
    "networkType": MessageLookupByLibrary.simpleMessage("Tipo de red"),
    "nextMatch": MessageLookupByLibrary.simpleMessage("Coincidencia siguiente"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "noData": MessageLookupByLibrary.simpleMessage("Sin datos"),
    "noInfo": MessageLookupByLibrary.simpleMessage("Sin información"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "No volver a recordármelo",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("Sin red"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("Apps sin red"),
    "noResolve": MessageLookupByLibrary.simpleMessage("No resolver IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "No resolver nombre de host",
    ),
    "noSearchResults": MessageLookupByLibrary.simpleMessage(
      "No hay resultados",
    ),
    "nodes": MessageLookupByLibrary.simpleMessage("Nodos"),
    "nonTextProviderFile": MessageLookupByLibrary.simpleMessage(
      "Este recurso externo no es un archivo de texto",
    ),
    "none": MessageLookupByLibrary.simpleMessage("Ninguno"),
    "notRunning": MessageLookupByLibrary.simpleMessage("Detenido"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "No se puede seleccionar el grupo de proxies actual",
    ),
    "ntpInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de sincronización (minutos)",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Añade un perfil para empezar",
    ),
    "nullTip": m106,
    "numberRangeTip": m107,
    "numberTip": m108,
    "obfs": MessageLookupByLibrary.simpleMessage("Ofuscación"),
    "obfsHost": MessageLookupByLibrary.simpleMessage("Host de ofuscación"),
    "obfsMode": MessageLookupByLibrary.simpleMessage("Modo de ofuscación"),
    "obfsParam": MessageLookupByLibrary.simpleMessage(
      "Parámetro de ofuscación",
    ),
    "obfsPassword": MessageLookupByLibrary.simpleMessage(
      "Contraseña de ofuscación",
    ),
    "onDemand": MessageLookupByLibrary.simpleMessage("Bajo demanda"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Contar solo el tráfico del proxy",
    ),
    "openSettings": MessageLookupByLibrary.simpleMessage("Abrir ajustes"),
    "optional": MessageLookupByLibrary.simpleMessage("Opcional"),
    "options": MessageLookupByLibrary.simpleMessage("Opciones"),
    "originalUrl": MessageLookupByLibrary.simpleMessage("URL original"),
    "other": MessageLookupByLibrary.simpleMessage("Otros"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Otros colaboradores",
    ),
    "outbound": MessageLookupByLibrary.simpleMessage("Salida"),
    "outboundExit": MessageLookupByLibrary.simpleMessage("Salida"),
    "outboundIp": MessageLookupByLibrary.simpleMessage("IP de salida"),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Modo de salida"),
    "overrideDestination": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir destino",
    ),
    "overrideEntries": MessageLookupByLibrary.simpleMessage(
      "Entradas de sobrescritura",
    ),
    "overview": MessageLookupByLibrary.simpleMessage("Resumen"),
    "parsePureIp": MessageLookupByLibrary.simpleMessage("Analizar IP pura"),
    "password": MessageLookupByLibrary.simpleMessage("Contraseña"),
    "paste": MessageLookupByLibrary.simpleMessage("Pegar"),
    "peers": MessageLookupByLibrary.simpleMessage("Pares"),
    "pickFromAlbum": MessageLookupByLibrary.simpleMessage("Elegir del álbum"),
    "pinWindow": MessageLookupByLibrary.simpleMessage("Fijar ventana"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage("Vincula WebDAV"),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Introduce un nombre para el script",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Sube un código QR válido",
    ),
    "plugin": MessageLookupByLibrary.simpleMessage("Complemento"),
    "pluginCipher": MessageLookupByLibrary.simpleMessage(
      "Cifrado del complemento",
    ),
    "pluginHost": MessageLookupByLibrary.simpleMessage("Host del complemento"),
    "pluginMode": MessageLookupByLibrary.simpleMessage("Modo del complemento"),
    "pluginPassword": MessageLookupByLibrary.simpleMessage(
      "Contraseña del complemento",
    ),
    "pluginPath": MessageLookupByLibrary.simpleMessage("Ruta del complemento"),
    "pluginUsername": MessageLookupByLibrary.simpleMessage(
      "Usuario del complemento",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Puerto"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Introduce un puerto diferente",
    ),
    "portHopping": MessageLookupByLibrary.simpleMessage("Salto de puertos"),
    "portTip": m109,
    "portValue": m110,
    "ports": MessageLookupByLibrary.simpleMessage("Puertos"),
    "preSharedKey": MessageLookupByLibrary.simpleMessage("Clave precompartida"),
    "preferred": MessageLookupByLibrary.simpleMessage("Preferido"),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Requisitos previos"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Pulsa una combinación de teclas",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Vista previa"),
    "previousMatch": MessageLookupByLibrary.simpleMessage(
      "Coincidencia anterior",
    ),
    "privateKey": MessageLookupByLibrary.simpleMessage("Clave privada"),
    "privateKeyPassphrase": MessageLookupByLibrary.simpleMessage(
      "Frase de contraseña de la clave privada",
    ),
    "process": MessageLookupByLibrary.simpleMessage("Proceso"),
    "profile": MessageLookupByLibrary.simpleMessage("Perfil"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Introduce un intervalo válido"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage(
          "Introduce el intervalo de actualización automática",
        ),
    "profileDaysLeft": m111,
    "profileExpiresIn": m112,
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "El perfil se ha modificado. ¿Desactivar la actualización automática?",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce el nombre del perfil",
    ),
    "profileSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Se aplica solo a este perfil; lo que no añadas usa su valor predeterminado.",
    ),
    "profileTunSettingsDesc": MessageLookupByLibrary.simpleMessage(
      "Se aplica solo a este perfil y tiene prioridad sobre las entradas de sobrescritura de TUN de los ajustes de red.",
    ),
    "profileUpdatedAt": m113,
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce una URL de perfil válida",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Introduce la URL del perfil",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Perfiles"),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Ordenar perfiles"),
    "project": MessageLookupByLibrary.simpleMessage(
      "Proyecto original de FlClash",
    ),
    "protocol": MessageLookupByLibrary.simpleMessage("Protocolo"),
    "protocolParam": MessageLookupByLibrary.simpleMessage(
      "Parámetro del protocolo",
    ),
    "protocolVersion": MessageLookupByLibrary.simpleMessage(
      "Versión del protocolo",
    ),
    "providerInUse": m114,
    "providerUrlTip": MessageLookupByLibrary.simpleMessage(
      "Solo se admiten proveedores remotos",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Recursos externos"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesCount": m115,
    "proxiesProfileLabel": m116,
    "proxiesRemovedTip": m117,
    "proxiesReplacedTip": m118,
    "proxyChains": MessageLookupByLibrary.simpleMessage("Cadena de proxies"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Grupo de proxies"),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "El grupo de proxies está vacío",
    ),
    "proxyGroupInUse": m119,
    "proxyGroupsAfterStart": MessageLookupByLibrary.simpleMessage(
      "Los grupos aparecen aquí cuando se inicia el núcleo",
    ),
    "proxyGroupsCount": m120,
    "proxyProviders": MessageLookupByLibrary.simpleMessage(
      "Proveedores de proxies",
    ),
    "proxyServerNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Solo resuelve los nombres de los servidores proxy.",
    ),
    "proxyServerNameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Los nombres de servidores proxy coincidentes usan el servidor DNS indicado aquí en lugar de Proxy Server Nameserver.",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Tipo de proxy"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Depurar caché"),
    "publicKey": MessageLookupByLibrary.simpleMessage("Clave pública"),
    "pureBlack": MessageLookupByLibrary.simpleMessage("Negro puro"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Modo negro puro"),
    "qrcode": MessageLookupByLibrary.simpleMessage("Código QR"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Escanea un código QR para obtener un perfil",
    ),
    "qrcodeTooLongTip": MessageLookupByLibrary.simpleMessage(
      "Este enlace es demasiado largo para un código QR. Usa Copiar enlace.",
    ),
    "quickActions": MessageLookupByLibrary.simpleMessage("Acciones rápidas"),
    "quickEdit": MessageLookupByLibrary.simpleMessage("Edición rápida"),
    "recentRequests": MessageLookupByLibrary.simpleMessage(
      "Solicitudes recientes",
    ),
    "recommendedIcons": MessageLookupByLibrary.simpleMessage("Sugeridos"),
    "recordType": MessageLookupByLibrary.simpleMessage("Tipo de registro"),
    "redirPort": MessageLookupByLibrary.simpleMessage("Puerto Redir"),
    "redo": MessageLookupByLibrary.simpleMessage("Rehacer"),
    "regenerateCertificate": MessageLookupByLibrary.simpleMessage(
      "Regenerar certificado",
    ),
    "regenerateCertificateTip": MessageLookupByLibrary.simpleMessage(
      "El nuevo certificado sustituye al actual, que Flash quita de las raíces de confianza de este dispositivo cuando puede. Cada otro dispositivo que confía en el actual tiene que instalar el nuevo.",
    ),
    "regex": MessageLookupByLibrary.simpleMessage("Expresión regular"),
    "releaseMemory": MessageLookupByLibrary.simpleMessage("Liberar memoria"),
    "releaseMemoryFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo liberar la memoria",
    ),
    "remote": MessageLookupByLibrary.simpleMessage("Remoto"),
    "remoteDestination": MessageLookupByLibrary.simpleMessage("Destino remoto"),
    "remoteDnsResolve": MessageLookupByLibrary.simpleMessage(
      "Resolución DNS remota",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Quitar"),
    "rename": MessageLookupByLibrary.simpleMessage("Renombrar"),
    "replace": MessageLookupByLibrary.simpleMessage("Reemplazar"),
    "replaceAll": MessageLookupByLibrary.simpleMessage("Reemplazar todo"),
    "request": MessageLookupByLibrary.simpleMessage("Solicitud"),
    "requestBody": MessageLookupByLibrary.simpleMessage(
      "Cuerpo de la solicitud",
    ),
    "requestHeaders": MessageLookupByLibrary.simpleMessage(
      "Encabezados de solicitud",
    ),
    "requests": MessageLookupByLibrary.simpleMessage("Solicitudes"),
    "requestsAndUpdates": MessageLookupByLibrary.simpleMessage(
      "Solicitudes y actualizaciones",
    ),
    "required": MessageLookupByLibrary.simpleMessage("Obligatorio"),
    "reset": MessageLookupByLibrary.simpleMessage("Restablecer"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "Esta página tiene cambios. ¿Seguro que quieres restablecer?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres restablecer?",
    ),
    "resourceUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Intervalo de actualización automática",
    ),
    "resourceUpdateIntervalTip": MessageLookupByLibrary.simpleMessage(
      "El intervalo de actualización automática debe ser mayor que 0",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Recursos"),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respetar reglas"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Respetar reglas enruta las conexiones DNS según las reglas y requiere un Proxy Server Nameserver.",
    ),
    "response": MessageLookupByLibrary.simpleMessage("Respuesta"),
    "responseBody": MessageLookupByLibrary.simpleMessage(
      "Cuerpo de la respuesta",
    ),
    "responseCode": MessageLookupByLibrary.simpleMessage("Código de respuesta"),
    "responseHeaders": MessageLookupByLibrary.simpleMessage(
      "Encabezados de respuesta",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Reiniciar"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "¿Seguro que quieres reiniciar el núcleo?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restaurar"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage(
      "Restaurar todos los datos",
    ),
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restaurar solo los perfiles",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Estrategia de restauración",
    ),
    "restoreStrategyCompatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategyOverride": MessageLookupByLibrary.simpleMessage(
      "Sobrescribir",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage(
      "Restauración completada",
    ),
    "result": MessageLookupByLibrary.simpleMessage("Resultado"),
    "retry": MessageLookupByLibrary.simpleMessage("Reintentar"),
    "root": MessageLookupByLibrary.simpleMessage("Root"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Direcciones de ruta"),
    "routeExcludeAddress": MessageLookupByLibrary.simpleMessage(
      "Direcciones excluidas de la ruta",
    ),
    "routingMark": MessageLookupByLibrary.simpleMessage(
      "Marca de enrutamiento",
    ),
    "ru": MessageLookupByLibrary.simpleMessage("Ruso"),
    "rule": MessageLookupByLibrary.simpleMessage("Regla"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Regla lógica AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el dominio completo",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una palabra clave del dominio",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una expresión regular de dominio",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un sufijo de dominio",
    ),
    "ruleActionDomainWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Coincidencia con comodines; solo se admiten * y ?",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con la marca DSCP (solo entrada UDP de tproxy)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el rango de puertos de destino",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el código de país de la IP",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con los dominios de Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre de la entrada",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el puerto de entrada",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el tipo de entrada",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre de usuario de entrada; separa varios usuarios con /",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el ASN de la IP",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de direcciones IP; IP-CIDR6 es solo un alias",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de direcciones IP",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de sufijo de IP",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con todas las solicitudes, sin necesidad de condiciones",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con TCP o UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Regla lógica NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("Regla lógica OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre del proceso; en Android coincide con el nombre del paquete",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una expresión regular del nombre del proceso; en Android coincide con el nombre del paquete",
    ),
    "ruleActionProcessNameWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con comodines en el nombre del proceso; solo se admiten * y ?",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con la ruta completa del proceso",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una expresión regular de la ruta del proceso",
    ),
    "ruleActionProcessPathWildcardDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con comodines en la ruta del proceso; solo se admiten * y ?",
    ),
    "ruleActionRematchNameDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el nombre de rematch; separa varios nombres con /",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Hace referencia a un conjunto de reglas; requiere rule-providers",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el código de país de la IP de origen",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el ASN de la IP de origen",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de direcciones IP de origen",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con un rango de sufijo de IP de origen",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el rango de puertos de origen",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con una subregla; cuidado con los paréntesis",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Coincide con el ID de usuario de Linux",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("La regla está vacía"),
    "ruleListInvalid": MessageLookupByLibrary.simpleMessage(
      "Las reglas deben ser una lista YAML con una regla por elemento, por ejemplo - DOMAIN,example.com,DIRECT",
    ),
    "rulePresetBittorrentDirect": MessageLookupByLibrary.simpleMessage(
      "BitTorrent directo",
    ),
    "rulePresetBlockDot": MessageLookupByLibrary.simpleMessage(
      "Bloquear DNS sobre TLS",
    ),
    "rulePresetBlockLoopback": MessageLookupByLibrary.simpleMessage(
      "Bloquear bucle del proxy",
    ),
    "rulePresetBlockQuic": MessageLookupByLibrary.simpleMessage(
      "Bloquear QUIC",
    ),
    "rulePresetBlockStun": MessageLookupByLibrary.simpleMessage(
      "Bloquear STUN",
    ),
    "rulePresetLanDirect": MessageLookupByLibrary.simpleMessage("LAN directa"),
    "rulePresetSystemServicesDirect": MessageLookupByLibrary.simpleMessage(
      "Apple y Microsoft directos",
    ),
    "ruleProviders": MessageLookupByLibrary.simpleMessage(
      "Proveedores de reglas",
    ),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Conjunto de reglas"),
    "ruleSetEmptyTip": MessageLookupByLibrary.simpleMessage(
      "El conjunto de reglas no tiene entradas utilizables",
    ),
    "ruleSetInvalidTip": MessageLookupByLibrary.simpleMessage(
      "No se puede leer este archivo mrs",
    ),
    "ruleSetMixedTip": MessageLookupByLibrary.simpleMessage(
      "El conjunto de reglas mezcla dominios y rangos de IP, por lo que no se puede determinar su tipo",
    ),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Destino de la regla"),
    "ruleTextInvalid": MessageLookupByLibrary.simpleMessage(
      "La regla debe empezar con un tipo admitido, por ejemplo DOMAIN,example.com,DIRECT",
    ),
    "rules": MessageLookupByLibrary.simpleMessage("Reglas"),
    "rulesCount": m121,
    "runTime": MessageLookupByLibrary.simpleMessage("Tiempo de ejecución"),
    "running": MessageLookupByLibrary.simpleMessage("En ejecución"),
    "runtimeConfig": MessageLookupByLibrary.simpleMessage(
      "Configuración de ejecución",
    ),
    "safeMode": MessageLookupByLibrary.simpleMessage("Modo seguro"),
    "safeModeAppTitle": m122,
    "saturation": MessageLookupByLibrary.simpleMessage("Saturación"),
    "save": MessageLookupByLibrary.simpleMessage("Guardar"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "¿Guardar los cambios?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Modo script: reescribe todo el perfil con un script de extensión",
    ),
    "scrollToSelected": MessageLookupByLibrary.simpleMessage(
      "Ir a la selección",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Buscar"),
    "seconds": MessageLookupByLibrary.simpleMessage("segundos"),
    "secondsCount": m123,
    "secretKey": MessageLookupByLibrary.simpleMessage("Clave"),
    "sectionsInEffect": m124,
    "select": MessageLookupByLibrary.simpleMessage("Seleccionar"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Seleccionar todo"),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Selecciona un conjunto de reglas",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Selecciona una estrategia de división",
    ),
    "send": MessageLookupByLibrary.simpleMessage("Enviar"),
    "sendFromPhone": MessageLookupByLibrary.simpleMessage(
      "Enviar desde el teléfono",
    ),
    "sendFromPhoneConfirmTitle": MessageLookupByLibrary.simpleMessage(
      "¿Importar el enlace enviado desde el teléfono?",
    ),
    "sendFromPhoneNoNetwork": MessageLookupByLibrary.simpleMessage(
      "Este dispositivo no está conectado a una red local",
    ),
    "sendFromPhonePageHint": MessageLookupByLibrary.simpleMessage(
      "Enlace de suscripción o enlace para compartir un proxy",
    ),
    "sendFromPhonePageSent": MessageLookupByLibrary.simpleMessage(
      "Enviado. Confirma la importación en el otro dispositivo.",
    ),
    "sendFromPhonePageTitle": MessageLookupByLibrary.simpleMessage(
      "Enviar un enlace a Flash",
    ),
    "sendFromPhonePermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Para recibir un enlace desde el teléfono, Flash necesita el permiso Dispositivos cercanos, que le da acceso a la red local. Actívalo en los ajustes de la aplicación.",
    ),
    "sendFromPhoneTip": MessageLookupByLibrary.simpleMessage(
      "Escanea el código con la cámara del teléfono y pega el enlace en la página que se abre. Ambos dispositivos deben estar en la misma red.",
    ),
    "server": MessageLookupByLibrary.simpleMessage("Servidor"),
    "serviceAbnormalCount": m125,
    "serviceAllAvailable": MessageLookupByLibrary.simpleMessage(
      "Todo disponible",
    ),
    "serviceAvailable": MessageLookupByLibrary.simpleMessage("Disponible"),
    "serviceBlocked": MessageLookupByLibrary.simpleMessage("Bloqueado"),
    "serviceCheckAll": MessageLookupByLibrary.simpleMessage("Comprobar todo"),
    "serviceComingSoon": MessageLookupByLibrary.simpleMessage("Próximamente"),
    "serviceDisallowedIsp": MessageLookupByLibrary.simpleMessage(
      "ISP no permitido",
    ),
    "serviceFailed": MessageLookupByLibrary.simpleMessage(
      "Error en la comprobación",
    ),
    "serviceManage": MessageLookupByLibrary.simpleMessage(
      "Gestionar servicios",
    ),
    "serviceOriginalsOnly": MessageLookupByLibrary.simpleMessage(
      "Solo originales",
    ),
    "servicePending": MessageLookupByLibrary.simpleMessage("Sin comprobar"),
    "serviceRestricted": MessageLookupByLibrary.simpleMessage(
      "Acceso restringido",
    ),
    "serviceShownOnDashboard": MessageLookupByLibrary.simpleMessage(
      "Se muestra en el panel",
    ),
    "serviceStatus": MessageLookupByLibrary.simpleMessage(
      "Estado del servicio",
    ),
    "serviceUnavailable": MessageLookupByLibrary.simpleMessage("No disponible"),
    "serviceUnsupportedRegion": MessageLookupByLibrary.simpleMessage(
      "Región no compatible",
    ),
    "settingEntries": MessageLookupByLibrary.simpleMessage("ajustes"),
    "settings": MessageLookupByLibrary.simpleMessage("Ajustes"),
    "settingsCount": m126,
    "shareLinkUnreadable": m127,
    "shareLinksInvalid": MessageLookupByLibrary.simpleMessage(
      "No se pudo leer ningún proxy de los enlaces",
    ),
    "shareQrcodeTip": MessageLookupByLibrary.simpleMessage(
      "Escanea con Flash en otro dispositivo para importar este perfil.",
    ),
    "show": MessageLookupByLibrary.simpleMessage("Mostrar"),
    "showHiddenGroups": MessageLookupByLibrary.simpleMessage(
      "Mostrar grupos ocultos",
    ),
    "showLess": MessageLookupByLibrary.simpleMessage("Contraer"),
    "showMore": MessageLookupByLibrary.simpleMessage("Expandir"),
    "showNotificationStopAction": MessageLookupByLibrary.simpleMessage(
      "Botón de detener en la notificación",
    ),
    "showPassword": MessageLookupByLibrary.simpleMessage("Mostrar contraseña"),
    "sidebar": MessageLookupByLibrary.simpleMessage("Barra lateral"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Inicio silencioso"),
    "singleImport": MessageLookupByLibrary.simpleMessage("Importar uno"),
    "singleShareLinkOnly": MessageLookupByLibrary.simpleMessage(
      "Introduce aquí un solo enlace; para varios, usa la edición rápida de la lista",
    ),
    "singleValueTip": m128,
    "size": MessageLookupByLibrary.simpleMessage("Tamaño"),
    "skipCertVerify": MessageLookupByLibrary.simpleMessage(
      "Omitir verificación de certificado",
    ),
    "skipDomain": MessageLookupByLibrary.simpleMessage("Omitir dominios"),
    "skipDstAddress": MessageLookupByLibrary.simpleMessage(
      "Omitir direcciones de destino",
    ),
    "skipServerCertVerify": MessageLookupByLibrary.simpleMessage(
      "Omitir la verificación del certificado del servidor",
    ),
    "skipSrcAddress": MessageLookupByLibrary.simpleMessage(
      "Omitir direcciones de origen",
    ),
    "slide": MessageLookupByLibrary.simpleMessage("Deslizar"),
    "sliders": MessageLookupByLibrary.simpleMessage("Reguladores"),
    "sniffProtocols": MessageLookupByLibrary.simpleMessage("Protocolos"),
    "sniffer": MessageLookupByLibrary.simpleMessage("Sniffer"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Puerto SOCKS"),
    "softStyle": MessageLookupByLibrary.simpleMessage("Suave"),
    "sort": MessageLookupByLibrary.simpleMessage("Ordenar"),
    "source": MessageLookupByLibrary.simpleMessage("Origen"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("IP de origen"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Proxy especial"),
    "specialRules": MessageLookupByLibrary.simpleMessage("Reglas especiales"),
    "spectrum": MessageLookupByLibrary.simpleMessage("Espectro"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage(
      "Estadísticas de velocidad",
    ),
    "splitStrategy": MessageLookupByLibrary.simpleMessage(
      "Estrategia de división",
    ),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "La estrategia de división no puede estar vacía",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("No hay SSID"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Modo de pila"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Seguimiento de pila"),
    "standard": MessageLookupByLibrary.simpleMessage("Estándar"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Modo estándar: añade reglas sobre el perfil",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Iniciar"),
    "startFromScratch": MessageLookupByLibrary.simpleMessage(
      "Empezar desde cero",
    ),
    "startVpn": MessageLookupByLibrary.simpleMessage("Iniciando VPN…"),
    "startupAndBackground": MessageLookupByLibrary.simpleMessage(
      "Inicio y segundo plano",
    ),
    "status": MessageLookupByLibrary.simpleMessage("Estado"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "Con DNS desactivado, se usa el DNS del sistema.",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Detener"),
    "stopUpdateDownloadTip": MessageLookupByLibrary.simpleMessage(
      "¿Detener la descarga de la actualización?",
    ),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Deteniendo VPN…"),
    "strategy": MessageLookupByLibrary.simpleMessage("Estrategia"),
    "strictRoute": MessageLookupByLibrary.simpleMessage("Ruta estricta"),
    "strictRouteDesc": MessageLookupByLibrary.simpleMessage(
      "La ruta estricta evita que el tráfico, como el DNS, eluda TUN y, con IPv6 desactivado, bloquea las conexiones IPv6 de este dispositivo.",
    ),
    "style": MessageLookupByLibrary.simpleMessage("Estilo"),
    "submit": MessageLookupByLibrary.simpleMessage("Enviar"),
    "subscriptionInfo": MessageLookupByLibrary.simpleMessage(
      "Información de la suscripción",
    ),
    "sudoPasswordTitle": MessageLookupByLibrary.simpleMessage(
      "Introduce tu contraseña para sudo",
    ),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspendido…"),
    "switchProfile": MessageLookupByLibrary.simpleMessage("Cambiar de perfil"),
    "sync": MessageLookupByLibrary.simpleMessage("Sincronizar"),
    "system": MessageLookupByLibrary.simpleMessage("Sistema"),
    "systemApp": MessageLookupByLibrary.simpleMessage("Apps del sistema"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("Proxy del sistema"),
    "tab": MessageLookupByLibrary.simpleMessage("Pestaña"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage(
      "Animación de pestañas",
    ),
    "tapIconToRetry": MessageLookupByLibrary.simpleMessage(
      "Toca el icono para reintentar",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage(
      "Toca para autorizar",
    ),
    "target": MessageLookupByLibrary.simpleMessage("Destino"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrente"),
    "testInterval": MessageLookupByLibrary.simpleMessage("Intervalo de prueba"),
    "testUrl": MessageLookupByLibrary.simpleMessage("URL de prueba"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("Probar al usarse"),
    "textScale": MessageLookupByLibrary.simpleMessage("Escala del texto"),
    "textScalePreview": MessageLookupByLibrary.simpleMessage(
      "Así se verá el texto en la app",
    ),
    "theme": MessageLookupByLibrary.simpleMessage("Tema"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Color del tema"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Modo del tema"),
    "tight": MessageLookupByLibrary.simpleMessage("Ajustado"),
    "time": MessageLookupByLibrary.simpleMessage("Hora"),
    "timeToFirstByte": MessageLookupByLibrary.simpleMessage(
      "Tiempo hasta el primer byte",
    ),
    "timeout": MessageLookupByLibrary.simpleMessage("Tiempo agotado"),
    "tintedStyle": MessageLookupByLibrary.simpleMessage("Tintado"),
    "tip": MessageLookupByLibrary.simpleMessage("Consejo"),
    "toggle": MessageLookupByLibrary.simpleMessage("Alternar"),
    "tolerance": MessageLookupByLibrary.simpleMessage("Tolerancia"),
    "tools": MessageLookupByLibrary.simpleMessage("Herramientas"),
    "torch": MessageLookupByLibrary.simpleMessage("Linterna"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalDownload": MessageLookupByLibrary.simpleMessage("Descargado"),
    "totalTraffic": MessageLookupByLibrary.simpleMessage("Tráfico total"),
    "totalUpload": MessageLookupByLibrary.simpleMessage("Subido"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Puerto TProxy"),
    "traffic": MessageLookupByLibrary.simpleMessage("Tráfico"),
    "trafficPeak": m129,
    "trafficTotal": m130,
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Uso de tráfico"),
    "transport": MessageLookupByLibrary.simpleMessage("Transporte"),
    "transportHeaders": m131,
    "trustCertificate": MessageLookupByLibrary.simpleMessage(
      "Confiar en el certificado",
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
    "tsCopyName": MessageLookupByLibrary.simpleMessage("Copy name"),
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
    "tsOwnerUnknownNetwork": m150,
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
    "tsRemoveBody": m151,
    "tsRemoveBodyNode": m152,
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
    "tsRulesAddresses": m153,
    "tsRulesDomain": m154,
    "tsRulesManaged": MessageLookupByLibrary.simpleMessage(
      "Flash updates dedicated rules using this account’s network domain and device addresses. Other traffic keeps its existing routing, and the original profile file stays unchanged.",
    ),
    "tsRulesPending": MessageLookupByLibrary.simpleMessage(
      "Once added, Tailscale addresses and ts.net domains will use dedicated rules. Other traffic will keep its existing routing.",
    ),
    "tsRulesProfileNode": MessageLookupByLibrary.simpleMessage(
      "Only traffic routed to this node by Flash rules uses Tailscale. Signing in to this node does not change existing rules or enable system proxy or TUN.",
    ),
    "tsRulesSummary": m155,
    "tsRulesUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Domain and address details are unconfirmed.",
    ),
    "tsSaveChoices": MessageLookupByLibrary.simpleMessage("Save choices"),
    "tsSavedValue": m156,
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
    "tsSharedBy": m157,
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
    "tsSignOutAccountBody": m158,
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
    "tsStatusOf": m159,
    "tsStatusUnknown": MessageLookupByLibrary.simpleMessage("Status unknown"),
    "tsStoppedTip": MessageLookupByLibrary.simpleMessage(
      "This node has stopped and can\'t reach the Tailscale network for now.",
    ),
    "tsSubnetRoutes": MessageLookupByLibrary.simpleMessage("Subnet routes"),
    "tsSwitcherSemantics": m160,
    "tsSystem": MessageLookupByLibrary.simpleMessage("OS"),
    "tsSystemMissing": MessageLookupByLibrary.simpleMessage("OS not provided"),
    "tsTargetAddress": m161,
    "tsTargetDomain": m162,
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
    "tsViewerNode": m163,
    "tsViewerReadFailed": MessageLookupByLibrary.simpleMessage(
      "Tailscale · Could not read runtime information",
    ),
    "tsViewerRules": m164,
    "tsViewerUnconfirmed": MessageLookupByLibrary.simpleMessage(
      "Tailscale · Current rules and nodes are unconfirmed",
    ),
    "tsWaitingBrowserTip": MessageLookupByLibrary.simpleMessage(
      "Finish logging in in your browser. This page updates from the node\'s status afterwards.",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunAuthorizationFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo autorizar TUN, por lo que se desactivó.",
    ),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "TUN solo funciona en modo administrador.",
    ),
    "tunOverrideDesc": MessageLookupByLibrary.simpleMessage(
      "Las entradas añadidas aquí sustituyen los ajustes de TUN de todos los perfiles; lo que no añadas conserva el ajuste del propio perfil. Las entradas que añade un perfil personalizado tienen prioridad.",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Desactivar"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Activar"),
    "udpRelayMode": MessageLookupByLibrary.simpleMessage(
      "Modo de retransmisión UDP",
    ),
    "udpTimeout": MessageLookupByLibrary.simpleMessage("Tiempo de espera UDP"),
    "udpTimeoutDesc": MessageLookupByLibrary.simpleMessage(
      "El tiempo de espera UDP se indica en segundos y solo funciona con las pilas gvisor, system y mixed.",
    ),
    "ultra": MessageLookupByLibrary.simpleMessage("Ultra"),
    "undo": MessageLookupByLibrary.simpleMessage("Deshacer"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Latencia unificada"),
    "unknown": MessageLookupByLibrary.simpleMessage("Desconocido"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Error de red desconocido",
    ),
    "unmaximize": MessageLookupByLibrary.simpleMessage("Restaurar tamaño"),
    "unnamed": MessageLookupByLibrary.simpleMessage("Sin nombre"),
    "unpinWindow": MessageLookupByLibrary.simpleMessage("Desfijar ventana"),
    "update": MessageLookupByLibrary.simpleMessage("Actualizar"),
    "updateCheckFailed": MessageLookupByLibrary.simpleMessage(
      "Couldn\'t check for updates. Please try again.",
    ),
    "updateDownloadFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo descargar la actualización.",
    ),
    "updateDownloadStarted": MessageLookupByLibrary.simpleMessage(
      "Se inició la descarga de la actualización. Consulta el progreso en el panel.",
    ),
    "updateDownloadTest": MessageLookupByLibrary.simpleMessage(
      "Prueba de descarga de actualización",
    ),
    "updateFailed": MessageLookupByLibrary.simpleMessage("Error al actualizar"),
    "updateInstallFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo instalar la actualización. Puedes descargarla desde la página de la versión.",
    ),
    "updateNoReleaseFound": MessageLookupByLibrary.simpleMessage(
      "No Flash release found yet",
    ),
    "updateNotVerified": MessageLookupByLibrary.simpleMessage(
      "No se pudo verificar la actualización descargada.",
    ),
    "updateReady": MessageLookupByLibrary.simpleMessage("Actualización lista"),
    "updateReadyTip": MessageLookupByLibrary.simpleMessage(
      "La actualización se descargó. Toca para instalarla.",
    ),
    "updateRestartTip": MessageLookupByLibrary.simpleMessage(
      "Flash se cerrará para instalar la actualización y se volverá a abrir al terminar.",
    ),
    "upload": MessageLookupByLibrary.simpleMessage("Subida"),
    "uploadBandwidth": MessageLookupByLibrary.simpleMessage(
      "Ancho de banda de subida",
    ),
    "upstreamTelegram": MessageLookupByLibrary.simpleMessage(
      "Telegram del proyecto original de FlClash",
    ),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlRewrite": MessageLookupByLibrary.simpleMessage("Reescritura de URL"),
    "urlTip": m165,
    "useHosts": MessageLookupByLibrary.simpleMessage("Usar hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage(
      "Usar hosts del sistema",
    ),
    "usedShort": MessageLookupByLibrary.simpleMessage("usado"),
    "usedTraffic": MessageLookupByLibrary.simpleMessage("Tráfico usado"),
    "userAgent": MessageLookupByLibrary.simpleMessage("User-Agent"),
    "username": MessageLookupByLibrary.simpleMessage("Usuario"),
    "validUntil": m166,
    "value": MessageLookupByLibrary.simpleMessage("Valor"),
    "view": MessageLookupByLibrary.simpleMessage("Ver"),
    "viewAll": MessageLookupByLibrary.simpleMessage("Ver todo"),
    "virtualIpv4": MessageLookupByLibrary.simpleMessage("IPv4 virtual"),
    "vividStyle": MessageLookupByLibrary.simpleMessage("Vivo"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "La configuración de la VPN cambió. Toca para reiniciar",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "Configuración de WebDAV",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Modo lista blanca"),
    "writeToSystem": MessageLookupByLibrary.simpleMessage(
      "Escribir en el sistema",
    ),
    "writeToSystemDesc": MessageLookupByLibrary.simpleMessage(
      "Escribir en el sistema también ajusta el reloj del sistema; Android lo ignora.",
    ),
    "yearsAgo": m167,
    "yearsAgoShort": m168,
    "yes": MessageLookupByLibrary.simpleMessage("Sí"),
    "zhCN": MessageLookupByLibrary.simpleMessage("Chino simplificado"),
  };
}
