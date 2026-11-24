package core

import (
	"time"

	"github.com/metacubex/mihomo/adapter/provider"
	P "github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

type CoreMethod string

// Named area.verb. A method's arguments are an object or nothing, and a
// command answers null: whatever goes wrong is a MethodError.
const (
	coreInitMethod        CoreMethod = "core.init"
	coreInitializedMethod CoreMethod = "core.initialized"
	coreGCMethod          CoreMethod = "core.gc"
	coreMemoryMethod      CoreMethod = "core.memory"
	coreCrashMethod       CoreMethod = "core.crash"

	configSetupMethod    CoreMethod = "config.setup"
	configUpdateMethod   CoreMethod = "config.update"
	configValidateMethod CoreMethod = "config.validate"
	configDecryptMethod  CoreMethod = "config.decrypt"
	configReadMethod     CoreMethod = "config.read"

	profileBaseMethod        CoreMethod = "profile.base"
	profileOutboundsMethod   CoreMethod = "profile.outbounds"
	profileBuildMethod       CoreMethod = "profile.build"
	profileClearEffectMethod CoreMethod = "profile.clearEffect"

	mountInspectSourceMethod  CoreMethod = "mount.inspectSource"
	mountInspectTargetMethod  CoreMethod = "mount.inspectTarget"
	mountPreflightMethod      CoreMethod = "mount.preflight"
	mountStateMethod          CoreMethod = "mount.state"
	mountRefreshSourcesMethod CoreMethod = "mount.refreshSources"

	proxyListMethod       CoreMethod = "proxy.list"
	proxySelectMethod     CoreMethod = "proxy.select"
	proxyDefinitionMethod CoreMethod = "proxy.definition"
	proxyTestDelayMethod  CoreMethod = "proxy.testDelay"
	proxyValidateMethod   CoreMethod = "proxy.validate"
	proxyConvertMethod    CoreMethod = "proxy.convert"
	shareLinkEncodeMethod CoreMethod = "shareLink.encode"
	shareLinkDecodeMethod CoreMethod = "shareLink.decode"
	filterValidateMethod  CoreMethod = "filter.validate"

	providerListMethod     CoreMethod = "provider.list"
	providerGetMethod      CoreMethod = "provider.get"
	providerUpdateMethod   CoreMethod = "provider.update"
	providerSideLoadMethod CoreMethod = "provider.sideLoad"
	ruleSetDumpMethod      CoreMethod = "ruleSet.dump"
	ruleSetCompileMethod   CoreMethod = "ruleSet.compile"
	ruleSetEntriesMethod   CoreMethod = "ruleSet.entries"
	ruleListMethod         CoreMethod = "rule.list"
	ruleLookupMethod       CoreMethod = "rule.lookup"
	geoUpdateMethod        CoreMethod = "geo.update"

	trafficCurrentMethod     CoreMethod = "traffic.current"
	trafficTotalMethod       CoreMethod = "traffic.total"
	trafficResetMethod       CoreMethod = "traffic.reset"
	connectionListMethod     CoreMethod = "connection.list"
	connectionCountMethod    CoreMethod = "connection.count"
	connectionCloseMethod    CoreMethod = "connection.close"
	connectionCloseAllMethod CoreMethod = "connection.closeAll"
	connectionResetMethod    CoreMethod = "connection.reset"
	dnsClearCacheMethod      CoreMethod = "dns.clearCache"
	networkChangedMethod     CoreMethod = "network.changed"

	logStartMethod      CoreMethod = "log.start"
	logStopMethod       CoreMethod = "log.stop"
	listenerStartMethod CoreMethod = "listener.start"
	listenerStopMethod  CoreMethod = "listener.stop"
	listenerMixedMethod CoreMethod = "listener.mixedPort"
	listenerPortsMethod CoreMethod = "listener.ports"
	routeWatchMethod    CoreMethod = "route.watch"
	routeCheckMethod    CoreMethod = "route.check"

	probeOutboundIPMethod CoreMethod = "probe.outboundIp"
	probeServicesMethod   CoreMethod = "probe.services"

	mitmCertificateMethod         CoreMethod = "mitm.certificate"
	mitmGenerateCertificateMethod CoreMethod = "mitm.generateCertificate"
	mitmValidateMethod            CoreMethod = "mitm.validate"
	mitmIssueCertificateMethod    CoreMethod = "mitm.issueCertificate"
	mitmRunScriptMethod           CoreMethod = "mitm.runScript"
	mitmExchangesMethod           CoreMethod = "mitm.exchanges"
	mitmExchangeMethod            CoreMethod = "mitm.exchange"
	mitmBodyMethod                CoreMethod = "mitm.body"
	mitmStatusMethod              CoreMethod = "mitm.status"
	mitmSignResultMethod          CoreMethod = "mitm.signResult"
	mitmDisableMethod             CoreMethod = "mitm.disable"
	mitmUpdateMethod              CoreMethod = "mitm.update"
	mitmRewriteStatusMethod       CoreMethod = "mitm.rewriteStatus"
	mitmRewriteParseMethod        CoreMethod = "mitm.rewriteParse"
	mitmSetCAMethod               CoreMethod = "mitm.setCA"
	mitmInspectCAMethod           CoreMethod = "mitm.inspectCA"
	mitmTrustLeaseMethod          CoreMethod = "mitm.trustLease"
	mitmCAStateMethod             CoreMethod = "mitm.caState"
	mitmStopSigningMethod         CoreMethod = "mitm.stopSigning"

	tailscaleNodesMethod         CoreMethod = "tailscale.nodes"
	tailscaleStatusMethod        CoreMethod = "tailscale.status"
	tailscaleStartMethod         CoreMethod = "tailscale.start"
	tailscaleLoginMethod         CoreMethod = "tailscale.login"
	tailscaleLogoutMethod        CoreMethod = "tailscale.logout"
	tailscaleSetPrefsMethod      CoreMethod = "tailscale.setPrefs"
	tailscaleMigrateLegacyMethod CoreMethod = "tailscale.migrateLegacy"
	tailscaleRoutesMethod        CoreMethod = "tailscale.routes"
	tailscaleAssignMethod        CoreMethod = "tailscale.assign"
	tailscaleForgetRoutesMethod  CoreMethod = "tailscale.forgetRoutes"
	tailscaleManagedStateMethod  CoreMethod = "tailscale.managedState"
	tailscaleRuntimeRulesMethod  CoreMethod = "tailscale.runtimeRules"
	tailscaleExitMethod          CoreMethod = "tailscale.exit"

	// The envelope of a batch of events, which the Core sends and never receives.
	messageMethod CoreMethod = "message"
)

type MessageType string

const (
	LogMessage       MessageType = "log"
	DelayMessage     MessageType = "delay"
	RequestMessage   MessageType = "request"
	DnsMessage       MessageType = "dns"
	LoadedMessage    MessageType = "loaded"
	GeoUpdateMessage MessageType = "geoUpdate"
	// Named after the Dart enum value, which is how CoreEvent.fromJson decodes it.
	RouteChangedMessage    MessageType = "routeChanged"
	DialerLoopMessage      MessageType = "dialerLoop"
	RequestTrafficMessage  MessageType = "requestTraffic"
	TailscaleStateMessage  MessageType = "tailscaleState"
	TailscaleRoutesMessage MessageType = "tailscaleRoutes"
	// Asks the app, which holds the CA key, for a leaf; answered by mitm.signResult.
	MitmSignMessage       MessageType = "mitmSign"
	MitmConnectionMessage MessageType = "mitmConnection"
	// A script's $notification.post, for the app to show as a system
	// notification.
	MitmNotificationMessage MessageType = "mitmNotification"
)

type Message struct {
	Type MessageType `json:"type"`
	Data any         `json:"data"`
}

type InitParams struct {
	HomeDir string `json:"home-dir"`
	Version int    `json:"version"`
}

type DecryptConfigParams struct {
	Path         string       `json:"path"`
	AgeSecretKey ageSecretKey `json:"age-secret-key"`
}

type SetupParams struct {
	mitmManaged bool

	Base        *SetupBase        `json:"base,omitempty"`
	SelectedMap map[string]string `json:"selected-map"`
	Options     CoreOptions       `json:"options"`
	Tailscale   *TailscaleSetup   `json:"tailscale,omitempty"`
	// Set for a profile with mounts, even none left: its failure must not
	// fall back to mihomo's direct-only default.
	Mounts *MountSetup `json:"mounts,omitempty"`
	Mitm   *MitmSetup  `json:"mitm,omitempty"`
}

type TailscaleSetup struct {
	ProfileID    int64                `json:"profile-id"`
	ConfigSource string               `json:"config-source"`
	Nodes        []TailscaleNodeSetup `json:"nodes"`
	// What the host keeps of a legacy login already moved to a node.
	LegacyMigration *TailscaleLegacyMigration `json:"legacy-migration,omitempty"`
	// The panel-added accounts of this profile, in sign-in order.
	Managed []TailscaleManagedSetup `json:"managed,omitempty"`
	// The host could not read its accounts: block every Tailscale target.
	ManagedUnknown bool `json:"managed-unknown,omitempty"`
	// The exit group's name in the host's language.
	ExitGroup string `json:"exit-group,omitempty"`
}

const tailscaleManagedBaseName = "Tailscale"

// A node the panel added; ID is the binding, Name only a label the Core may
// suffix to keep it unique.
type TailscaleManagedSetup struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	ControlURL   string  `json:"control-url"`
	ExitNode     *string `json:"exit-node,omitempty"`
	AcceptRoutes *bool   `json:"accept-routes,omitempty"`
	LoggedOut    bool    `json:"logged-out"`
	// Only an attached account gets routing rules.
	Attached bool `json:"attached"`
	// The exit node's member name in the exit group: device and account.
	ExitLabel string `json:"exit-label,omitempty"`
}

type TailscaleNodeSetup struct {
	Name       string `json:"name"`
	ControlURL string `json:"control-url"`
	// An empty one is the explicit choice of no exit node; nil leaves the config's.
	ExitNode     *string `json:"exit-node,omitempty"`
	AcceptRoutes *bool   `json:"accept-routes,omitempty"`
	LoggedOut    bool    `json:"logged-out"`
}

type TailscaleNodeParams struct {
	Name       string `json:"name"`
	ManagedID  string `json:"managed-id,omitempty"`
	Generation uint64 `json:"generation"`
}

type TailscaleLoginParams struct {
	Name       string `json:"name"`
	ManagedID  string `json:"managed-id,omitempty"`
	Generation uint64 `json:"generation"`
	// Asks for a new auth URL even while the node runs, to renew an expiring key.
	Reauth bool `json:"reauth"`
}

type TailscaleMigrateParams struct {
	Name       string `json:"name"`
	ManagedID  string `json:"managed-id,omitempty"`
	Generation uint64 `json:"generation"`
	// The legacy offer-token the user confirmed; any change since refuses.
	OfferToken string `json:"offer-token"`
}

type TailscalePrefsParams struct {
	Name         string  `json:"name"`
	ManagedID    string  `json:"managed-id,omitempty"`
	Generation   uint64  `json:"generation"`
	ExitNode     *string `json:"exit-node,omitempty"`
	ExitLabel    *string `json:"exit-label,omitempty"`
	AcceptRoutes *bool   `json:"accept-routes,omitempty"`
}

type TailscaleRoutesParams struct {
	ProfileID int64 `json:"profile-id"`
}

type TailscaleAssignParams struct {
	ProfileID   int64                      `json:"profile-id"`
	Assignments []TailscaleRouteAssignment `json:"assignments"`
}

type CoreOptions struct {
	// An empty one keeps the URL in force.
	TestURL        string `json:"test-url"`
	SkipCertVerify bool   `json:"skip-cert-verify"`
	// In milliseconds, for every delay test whose config names no timeout; zero
	// keeps the timeout in force.
	DelayTestTimeout int64 `json:"delay-test-timeout"`
	MITMCapture      bool  `json:"mitm-capture"`
}

type SetupBase struct {
	Path    string `json:"path"`
	Overlay string `json:"overlay"`
}

// Without a path, Config is the profile the host built, which the Core runs
// as config.yaml.
type BuildProfileParams struct {
	SetupBase
	Config string      `json:"config,omitempty"`
	Mounts *MountSetup `json:"mounts,omitempty"`
}

type ProfileBase struct {
	Config      map[string]any `json:"config"`
	Digest      string         `json:"digest"`
	MatchRules  []string       `json:"match-rules"`
	Proxies     int            `json:"proxies"`
	ProxyGroups int            `json:"proxy-groups"`
	Rules       int            `json:"rules"`
}

type ProfileOutbounds struct {
	Proxies     []ProfileOutbound `json:"proxies"`
	ProxyGroups []ProfileOutbound `json:"proxy-groups"`
}

type ProfileOutbound struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

type UpdateParams struct {
	Tun                *tunSchema         `json:"tun"`
	AllowLan           *bool              `json:"allow-lan"`
	MixedPort          *int               `json:"mixed-port"`
	FindProcessMode    *P.FindProcessMode `json:"find-process-mode"`
	Mode               *tunnel.TunnelMode `json:"mode"`
	LogLevel           *log.LogLevel      `json:"log-level"`
	IPv6               *bool              `json:"ipv6"`
	TCPConcurrent      *bool              `json:"tcp-concurrent"`
	ExternalController *string            `json:"external-controller"`
	Secret             *string            `json:"secret"`
	UnifiedDelay       *bool              `json:"unified-delay"`
	Authentication     *[]string          `json:"authentication"`
	GeoAutoUpdate      *bool              `json:"geo-auto-update"`
	GeoUpdateInterval  *int               `json:"geo-update-interval"`
	GeoXUrl            map[string]string  `json:"geox-url"`
	Options            *CoreOptions       `json:"options"`
}

type ListeningPorts struct {
	Port       int  `json:"port"`
	SocksPort  int  `json:"socks-port"`
	RedirPort  int  `json:"redir-port"`
	TProxyPort int  `json:"tproxy-port"`
	MixedPort  int  `json:"mixed-port"`
	Tun        bool `json:"tun"`
}

type tunSchema struct {
	Enable    *bool              `yaml:"enable" json:"enable"`
	Device    *string            `yaml:"device" json:"device"`
	Stack     *constant.TUNStack `yaml:"stack" json:"stack"`
	AutoRoute *bool              `yaml:"auto-route" json:"auto-route"`
}

type PathParams struct {
	Path string `json:"path"`
}

type NameParams struct {
	Name string `json:"name"`
}

type IDParams struct {
	ID string `json:"id"`
}

type WatchParams struct {
	Watch bool `json:"watch"`
}

type TrafficParams struct {
	OnlyProxy bool `json:"only-proxy"`
}

type ClearEffectParams struct {
	ProfileID int64 `json:"profile-id"`
}

type GeoUpdateParams struct {
	Type string `json:"type"`
}

type ProxiesParams struct {
	Proxies []map[string]any `json:"proxies"`
}

type LinesParams struct {
	Lines []string `json:"lines"`
}

type FiltersParams struct {
	Filters []string `json:"filters"`
}

type ValidationIssue struct {
	Index   int    `json:"index"`
	Message string `json:"message"`
}

type SideLoadParams struct {
	Name string `json:"name"`
	Data string `json:"data"`
}

type CompileRuleSetParams struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type RuleSetInfo struct {
	Behavior string `json:"behavior"`
	Format   string `json:"format"`
	// How many entries the set holds; zero for an empty set.
	Count int64 `json:"count"`
}

type ChangeProxyParams struct {
	GroupName string `json:"group-name"`
	ProxyName string `json:"proxy-name"`
}

type ChangeProxyResult struct {
	Message string `json:"message"`
	Changed bool   `json:"changed"`
}

type RouteState struct {
	CoreEpoch    uint64 `json:"core-epoch"`
	RouteVersion uint64 `json:"route-version"`
	Running      bool   `json:"running"`
}

type TestDelayParams struct {
	ProxyName string `json:"proxy-name"`
	TestUrl   string `json:"test-url"`
	Timeout   int64  `json:"timeout"`
}

type Delay struct {
	Url   string `json:"url"`
	Name  string `json:"name"`
	Value int32  `json:"value"`
}

type Traffic struct {
	Up   int64 `json:"up"`
	Down int64 `json:"down"`
}

type MemoryStats struct {
	Rss          uint64 `json:"rss"`
	HeapInuse    uint64 `json:"heap-inuse"`
	HeapIdle     uint64 `json:"heap-idle"`
	StackInuse   uint64 `json:"stack-inuse"`
	RuntimeOther uint64 `json:"runtime-other"`
}

type ExternalProvider struct {
	Name             string                     `json:"name"`
	Type             string                     `json:"type"`
	VehicleType      string                     `json:"vehicle-type"`
	Count            int                        `json:"count"`
	Path             string                     `json:"path"`
	UpdateAt         time.Time                  `json:"update-at"`
	SubscriptionInfo *provider.SubscriptionInfo `json:"subscription-info"`
}

type ProxiesData struct {
	TailscaleRevision uint64         `json:"tailscale-revision"`
	Proxies           map[string]any `json:"proxies"`
	All               []string       `json:"all"`
}

// A capability is present for every outbound and absent for an action such as
// REJECT or a group, so the host reads a missing key as unknown, never as false.
type nodeView struct {
	Name         string `json:"name"`
	Type         string `json:"type"`
	ProviderName string `json:"provider-name,omitempty"`
	UDP          *bool  `json:"udp,omitempty"`
	UoT          *bool  `json:"uot,omitempty"`
	XUDP         *bool  `json:"xudp,omitempty"`
	TFO          *bool  `json:"tfo,omitempty"`
	MPTCP        *bool  `json:"mptcp,omitempty"`
	SMUX         *bool  `json:"smux,omitempty"`
	DialerProxy  string `json:"dialer-proxy,omitempty"`
	Interface    string `json:"interface,omitempty"`
}

type GeoUpdateStatus struct {
	Type     string `json:"type"`
	Updating bool   `json:"updating"`
	Skipped  bool   `json:"skipped,omitempty"`
	Error    string `json:"error,omitempty"`
}
