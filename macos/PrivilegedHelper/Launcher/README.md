# FlashHelperLauncher（固定启动器）

`com.layoute.flash.daemon.plist` 的 `BundleProgram` 将改为指向本启动器。启动器把包内真正的 `FlashHelper`
复制到 root 专属目录，校验副本后 `execv` 副本。它本身永远不变。

## 为什么需要它

Flash 用自签证书签名，没有 Apple Team ID。`SMAppService.daemon` 登记时，系统把启动约束（LWCR）钉在当时那份
可执行文件的 cdhash 上，并缓存在后台项（BTM）记录里。覆盖更新换了 `FlashHelper` 后，launchd 报
`Launch Constraint Violation` / `needs LWCR update`，重新登记也沿用旧约束（真机证据）。让 `BundleProgram` 指向
一个 cdhash 永不变化的启动器，约束就一直成立；每次更新真正变化的 `FlashHelper` 由启动器负责校验后启动。

## 流程

启动器只做四件事：复制、校验、防降级、启动。任何一步不过就不启动 helper，写状态文件、写一行 os_log，
以该原因固定的退出码退出。

0. 前置检查
   - `getuid() == 0 && geteuid() == 0`，否则 `not_root`。
   - `proc_pidpath` + `realpath` 得到自身真实路径，必须以 `.app/Contents/Library/HelperTools/FlashHelperLauncher`
     结尾，否则 `location`。去掉后缀即包路径，源文件为 `<包>/Contents/Library/HelperTools/FlashHelper`。
1. 复制（失败均为 `copy`）
   - `open("/Library/Application Support", O_DIRECTORY|O_NOFOLLOW)`，`fstat` 要求：目录、uid 0、`mode & 022 == 0`。
     本机实测为 `root:admin 0755`，满足。
   - `mkdirat(parent, "com.layoute.flash.helperd", 0700)`（已存在可以）；`fstatat(..., AT_SYMLINK_NOFOLLOW)` 要求
     不是符号链接、是目录、uid 0、`mode & 077 == 0`；再 `openat(O_DIRECTORY|O_NOFOLLOW)`，`fstat` 的 dev/ino 必须与
     lstat 结果相同。权限过宽不自动修正，直接拒绝。
   - 源 `open(O_RDONLY|O_NOFOLLOW|O_NONBLOCK)`，`fstat` 必须是普通文件，0 < 大小 ≤ 256 MiB。
   - 先 `unlinkat` 残留的 `.FlashHelper.tmp`，再 `openat(O_CREAT|O_EXCL|O_NOFOLLOW, 0500)`；完整拷贝且字节数必须
     等于源的 `st_size`；`fchmod 0500`、`fsync`、`renameat` 为 `FlashHelper`、`fsync` 目录。
2. 校验（失败为 `signature`）
   - 先 `openat(state, "FlashHelper", O_NOFOLLOW)` 拿 fd，记下 dev/ino/size/mtime（且必须是普通文件、uid 0）。
   - `SecStaticCodeCreateWithPath(副本)` + `SecStaticCodeCheckValidityWithErrors`，flags 为
     `kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode`（与 `HelperTrust.m` 的 `FCCheckCode`
     相同），要求串与生产 `FCSigningRequirement(@"com.layoute.flash.helper")` 逐字一致：

     ```text
     anchor H"BBA7F8529FD271B9848EC03A2CE3F4780F585556" and certificate leaf = H"BBA7F8529FD271B9848EC03A2CE3F4780F585556" and identifier "com.layoute.flash.helper"
     ```

     `Tests/test_launcher.py` 从 `HelperIdentity.h` 与 `HelperTrust.m` 重建这一串并与 `main.c` 比对。
3. 防降级
   - 从已校验 static code 的 `kSecCodeInfoPList` 取 `CFBundleVersion`。必须是字符串、纯十进制数字、1–20 位、
     不溢出 `uint64`，否则 `version_unreadable`。
   - 读 `<状态目录>/max-version`（`O_NOFOLLOW`，普通文件、uid 0，内容为十进制数字加可选换行）。不存在视为首次；
     存在但不可信（符号链接、非普通文件、内容非法）为 `version_unreadable`，不会当作缺失处理。
   - 新版本 < 记录：`downgrade`。新版本 > 记录或记录缺失：原子写入（`.max-version.tmp`，0600，`fsync`，
     `renameat`，`fsync` 目录）后继续；写失败为 `version_unreadable`。相等：直接继续。
4. 启动
   - 写 `ok` 状态。
   - `fstatat(state, "FlashHelper", AT_SYMLINK_NOFOLLOW)` 的 dev/ino/size/mtime 必须与第 2 步记录一致，否则 `exec`。
   - `execv(副本, ["/Library/Application Support/com.layoute.flash.helperd/FlashHelper", "--flash-bundle", <包路径>])`，
     环境原样继承。`execv` 返回即 `exec`（状态覆盖为 `exec`）。

签名校验与 `execv` 用的是同一个路径上的同一个 inode：该目录只有 root 可写，dev/ino/size/mtime 在校验前后比对。

## 状态文件与退出码

`/Library/Application Support/com.layoute.flash.helperd-status/launcher.json`：目录 root 0755（每次 `fchmod`
到 0755），文件 root 0644，经 `.launcher.json.tmp` 原子替换，全部 `O_NOFOLLOW`。单行 JSON，键顺序固定：

```json
{"v":1,"result":"downgrade","detail":"helper is older than the highest version run","helperVersion":2026111707,"recordedVersion":2026111709,"launcherVersion":1,"time":1794902400}
```

- `helperVersion`：本次副本的 `CFBundleVersion`；尚未读到（版本之前的步骤失败、或解析失败）时为 `null`。
- `recordedVersion`：本次运行前 `max-version` 的值；缺失或不可信时为 `null`。升级成功后文件里是新值，
  状态里仍是旧值。
- `detail`：短英文原因加 `errno=` / `OSStatus=`，只由字面量和数字组成，不含路径。

| result | 退出码 | 典型 detail |
| --- | --- | --- |
| `ok` | —（随后 exec） | `verified` |
| `not_root` | 81 | `uid=501 euid=501` |
| `location` | 82 | `launcher is not inside an app bundle`、`realpath errno=…` |
| `copy` | 83 | `state directory is a symlink errno=0`、`state directory mode too wide errno=0`、`open source errno=62`、`parent directory unsafe errno=1` |
| `signature` | 84 | `copy rejected OSStatus=-67061` |
| `version_unreadable` | 85 | `CFBundleVersion is not an unsigned integer`、`max-version unreadable errno=0`、`max-version write errno=…` |
| `downgrade` | 86 | `helper is older than the highest version run` |
| `exec` | 87 | `copy changed before exec errno=…`、`execv errno=…` |

退出码避开 78（`EX_CONFIG`，helper 自身在用）。以下情况无法安全写状态文件，只有 os_log（subsystem
`com.layoute.flash.launcher`，category `launcher`，失败为 error 级，`ok` 为 default 级）：`not_root`；
`/Library/Application Support` 不满足检查；状态目录是符号链接、不归 root 或可被 group/other 写。

## 常量（一次定死）

| 项 | 值 |
| --- | --- |
| 签名标识 | `com.layoute.flash.helper-launcher` |
| 自身位置 | `<包>/Contents/Library/HelperTools/FlashHelperLauncher`，包名须以 `.app` 结尾 |
| 源 | `<包>/Contents/Library/HelperTools/FlashHelper` |
| root 目录 | `/Library/Application Support/com.layoute.flash.helperd`（0700） |
| 副本 / 记录 | 上述目录下 `FlashHelper`（0500）/ `max-version`（0600） |
| 状态 | `/Library/Application Support/com.layoute.flash.helperd-status/launcher.json` |
| helper 参数 | `--flash-bundle <包路径>` |
| 要求串 | 见上文，固定证书 SHA1 `BBA7F8529FD271B9848EC03A2CE3F4780F585556` + `com.layoute.flash.helper` |
| 版本 | `launcherVersion` 1，状态格式 `v` 1 |
| 部署目标 | macOS 12.0，arm64 + x86_64 |

## 威胁模型

- 对手：与 App 同 uid 的本地代码。`/Applications/Flash.app` 归用户、可写，所以包内任何文件（含 `FlashHelper`）
  随时可能被换掉。root 与签名私钥不在对手能力内；私钥泄露时一切校验都失效。
- 只执行校验过的那一份：校验与执行都针对 root 专属目录里的副本，不针对包内原件；校验之后改包内文件不影响
  这次启动。目录 root 0700、不是符号链接，父目录 root 所有且 group/other 不可写，全部操作基于目录 fd，
  文件 `O_NOFOLLOW`；校验前后比对 dev/ino/size/mtime。
- 只执行我们签的 helper：锚定原自签证书（anchor + 叶证书 SHA1）+ identifier `com.layoute.flash.helper`，
  严格校验全部架构。
- 防降级：签名合法的旧 helper（可能带已修复的漏洞）不能被喂给 root。`max-version` 只有 root 能写。
  判断依据是版本号而不是 cdhash，所以同一版本号的不同构建都允许；版本号必须逐次发布严格递增。
- 包路径只通过 argv 传给 helper，不读写环境变量；helper 必须把它当不可信输入并自行再校验包（见集成清单）。
- 不变的部分：App ↔ helper 的对端认证（XPC peer requirement、`FCGUIMessageValidator`、App 侧
  `FCMessageValidator`）、helper 启动时及每次特权操作前的自检、Core 的复制 + 哈希 + 签名校验都保留，
  启动器不替代其中任何一项；它只决定“哪一份 helper 可以以 root 开始运行”。
- 启动器自身：launchd 的 LWCR 钉住其 cdhash，App 的签名封印也覆盖它；被替换后不会被 launchd 启动。

## 已知限制

- 降级安装旧版 Flash：旧 helper 版本低于 `max-version`，启动器拒绝（`downgrade`），辅助程序不会运行，直到装回
  不低于记录的版本。有意降级只能由 root 手动删除 `max-version`；启动器不提供降级通道。
- 启动器有缺陷只能换登记名：LWCR 钉在启动器 cdhash 上，重新登记沿用旧约束，所以改动启动器 = 新 plist 名
  （以及可能的新 Label / MachService）+ 迁移旧登记。基于同一证据推断：从现在“直接指向 FlashHelper”的登记切到
  启动器时，同名 plist 的旧约束（钉在旧 FlashHelper 的 cdhash）很可能仍被沿用，首次切换大概率也要换登记名。
  未真机验证。
- exec 之后约束是否还生效（推断，未真机验证）：Apple 文档
  <https://developer.apple.com/documentation/security/defining-launch-environment-and-library-constraints>
  把 spawn constraint 描述为由发起启动的一方（`posix_spawn` 属性，或 launchd plist 的 `SpawnConstraint`）附加在
  一次启动上、由系统在这次启动时评估；self / parent / responsible 约束则写在被执行文件自己的签名里。文档没有说
  spawn constraint 会延续到该进程之后的 `execve`。据此推断，launchd 的 LWCR 只作用于启动器这次 spawn，不作用于
  启动器 exec 的副本；副本自身不带 self 约束。若推断错误，副本会在 exec 时被系统终止，状态文件停在 `ok`；
  App 看到 `ok` 但 helper 无响应时应提示这种可能，而不是当作成功。
- `not_root`、父目录或状态目录不安全时只有 os_log，没有状态文件。
- 校验失败的副本留在 root 目录（root 0500，从不执行），下次启动时被覆盖。
- 启动器不检查 helper 的 hardened runtime 和 entitlements，这些仍由 helper 自检（`FCCodeEntitlementsAllowed`）负责。
- 部署目标 macOS 12，但 `SMAppService.daemon` 需要 13，现有 helper 运行时要求 14；在 12/13 上启动器能跑，helper
  会自行以 `EX_CONFIG` 退出。
- 卸载不会清理 `com.layoute.flash.helperd` 与 `-status` 两个 root 目录；删除 `max-version` 等于重新允许降级。

## 构建、签名与固定

```sh
macos/PrivilegedHelper/Launcher/build.sh <输出路径>
```

产物是无签名（仅链接器 ad-hoc）的 arm64 + x86_64 通用二进制，`-Os -mmacosx-version-min=12.0 -Wall -Wextra -Werror`，
只链接 CoreFoundation 与 Security。签名由签名负责人一次性完成，命令要求如下（本工作未执行，也未接触钥匙串）：

```sh
codesign --force --sign BBA7F8529FD271B9848EC03A2CE3F4780F585556 \
  --keychain "<FlashSigning.keychain-db>" --timestamp=none --options runtime \
  --identifier com.layoute.flash.helper-launcher \
  --requirements '=designated => anchor H"BBA7F8529FD271B9848EC03A2CE3F4780F585556" and certificate leaf = H"BBA7F8529FD271B9848EC03A2CE3F4780F585556" and identifier "com.layoute.flash.helper-launcher"' \
  --entitlements <空 entitlements plist> FlashHelperLauncher
codesign --verify --strict --all-architectures \
  -R='=anchor H"BBA7F8529FD271B9848EC03A2CE3F4780F585556" and certificate leaf = H"BBA7F8529FD271B9848EC03A2CE3F4780F585556" and identifier "com.layoute.flash.helper-launcher"' \
  FlashHelperLauncher
codesign --display --verbose=4 --arch arm64 FlashHelperLauncher    # 记录 CDHash
codesign --display --verbose=4 --arch x86_64 FlashHelperLauncher   # 记录 CDHash
```

- 要求：hardened runtime（flags 只有 `runtime`）、无 entitlements、无时间戳、非 ad-hoc、TeamIdentifier 未设置，
  与 `sign_fixed_payload.py` 对 helper 的要求一致。
- 通用二进制每个架构一份 cdhash，两份都要固定。
- clang 产物不可复现（工具链、LC_UUID），签名后的那份字节就是唯一正本：记录其 sha256 与两份 cdhash，作为受审
  资产保存（存放位置由集成方决定），之后永不重新构建、永不重签。

## 测试

```sh
cd macos/PrivilegedHelper/Launcher/Tests && /usr/bin/python3 -m unittest -v test_launcher
```

测试版用同一个 `build.sh` 加 `-DFLASH_LAUNCHER_TEST -DFL_TEST_UID=<当前 uid> -DFL_TEST_PARENT="<临时目录>"` 编译。
`FLASH_LAUNCHER_TEST` 只替换三个常量：属主 uid（0 → 当前 uid）、父目录（→ 临时目录）、要求串（→
`identifier "com.layoute.flash.helper"`，ad-hoc 签名可满足）；逻辑代码不分叉，`test_test_build_changes_constants_only`
检查这一点。测试 helper 是内嵌 `__info_plist`（带 `CFBundleVersion`）、`codesign -s -` 签名的小程序，打印自身路径、
一个环境变量和 argv。

覆盖：正常复制 + 校验 + exec（argv、环境、副本内容与权限、记录）、状态文件内容与权限、签名被篡改、要求不符、
降级、同版本、升级更新记录、`CFBundleVersion` 不可解析、`max-version` 损坏、root 目录是符号链接、root 目录权限过宽、
源是符号链接、父目录不安全（不写状态）、启动器不在包内、生产要求串与 `HelperTrust.m` 一致。

未覆盖：`not_root`（需要另一个 uid）、`execv` 失败与 exec 前副本被换（需要在两次系统调用之间注入）、真实 root
目录、真实证书签名、launchd/SMAppService 下的行为。

## 集成清单

1. 登记
   - `com.layoute.flash.daemon.plist`、`HelperTrust.m` 的 `FCCanonicalDaemonPlist`、`stage_bundle_payload.py` 的
     `DAEMON_SCHEMA`：`BundleProgram` 改为 `Contents/Library/HelperTools/FlashHelperLauncher`。
   - 按“已知限制”，大概率需要新的 plist 名（`FCDaemonPlistName`、`FCDaemonPlistRelativePath`、`LaunchDaemons/`
     下的文件名及其检查），并在 App 里注销旧登记、登记新名。需真机确认。
2. 打包
   - `stage_bundled_daemon.sh`：把已固定的、已签名的启动器正本原样拷入 `Contents/Library/HelperTools/`（`cp`，
     不编译、不改字节），保持 0755。
   - `stage_bundle_payload.py`：`HelperTools` 内容改为 `['FlashHelper', 'FlashHelperLauncher']`；`check_layout` 对
     启动器做 Mach-O、权限、非符号链接检查；`verify_signed` 增加启动器 sha256 与两个架构 cdhash 等于固定值、
     `codesign --verify -R` 启动器要求串。
   - `sign_fixed_payload.py`：启动器不进 `FIXED`，不得重签；`signing_targets` 现在要求包内 Mach-O 集合恰好等于签名
     目标，需把启动器列为“已签名、只校验”；`check_signing_delta` 要证明启动器字节未变；“所有嵌套代码架构必须与 GUI
     完全一致”的检查要与启动器的 arm64 + x86_64 对齐。App 封印（CodeResources）会覆盖启动器文件，这是期望的。
   - `PrivilegedHelper/Info.plist` 的 `CFBundleVersion` 现在是字面量 `1`。必须在构建时写入发布构建号（如 pubspec 的
     `2026111708`），且逐次发布严格递增；否则防降级形同虚设。第一个带启动器的版本起就要写真实构建号：一旦记录过
     `2026111708`，之后任何写成 `1` 的构建都会被当作降级拒绝。
3. App
   - helper 无响应时读状态文件（world-readable）。先 `lstat` 确认目录与文件归 root、不可被 group/other 写、不是符号
     链接，再严格解析（`v == 1`、`result` 在上表内），按 `result` 显示明确状态。缺文件 = 启动器从未运行或无法写入。
     `ok` 但 helper 无响应（尤其 `time` 早于本次尝试）时提示可能在 exec 后被系统终止。
   - `ManagedHelperBridge.m` 用 `FCMessageValidator` 时把 `FCInstalledExecutable(FCHelperIdentifier)` 当作 daemon 的
     执行路径；现在 daemon 从 `/Library/Application Support/com.layoute.flash.helperd/FlashHelper` 运行，
     `FCExecutableMatches` 会失败。App 侧要改为期望副本路径，但期望的 cdhash 仍从包内 `FlashHelper` 算（副本目录
     0700，App 读不到；字节相同所以 cdhash 相同）。`currentHelperHash` 保持基于包内文件。
4. helper（只列清单，本工作未改 helper 代码）
   - `main`：argv 必须恰好是 `[副本路径, "--flash-bundle", <包路径>]`，否则以 `EX_CONFIG` 退出；不读环境变量。
   - 包路径：把参数当不可信输入，`realpath` 后必须等于 `FCGUIBundle`（`/Applications/Flash.app`，现有策略），并通过
     `FCGUIBundleTrust`（封印覆盖 plist、helper、启动器、Core、兼容契约）与 `FCBundledDaemonPresent`（新的
     `BundleProgram`，启动器存在）。
   - 自检 `FCHelperSelfCheck`：运行路径的期望值从包内 `FlashHelper` 改为副本路径（`FCExecutableMatches` 同步改）；
     “磁盘上同路径文件严格校验且 cdhash 与运行中相同”改为两条：副本路径的静态 cdhash 等于运行中 cdhash，且
     `<包>/Contents/Library/HelperTools/FlashHelper` 严格校验通过且 cdhash 也相等（证明运行的就是已封印 App 携带的那份）。
   - Core 暂存与兼容契约：`Supervisor.m` 里 `FCGUIBundle` 拼 Core 路径、`FCReadCompatibility(FCGUIBundle)` 改为读已
     校验的包参数（或在断言参数等于常量后继续用常量）。Core 运行目录 `com.layoute.flash.daemon` 不变，helper 不得
     读写启动器的 `com.layoute.flash.helperd` 与 `-status` 目录。
   - GUI 包信任 `FCGUIBundleTrust` 与每次特权操作前的 `selfCheck` 用同一个包参数。
   - 空闲退出后由启动器重新复制，“下次启动拿到新二进制”的行为不变；`helperCDHash` 上报值不变。
   - 遗留清理（`LegacyResidue`、卸载流程）要把两个新目录列为已知项，并明确是否清理（清理 `max-version` 会重新允许
     降级）。
5. 测试：`Tests/test_runtime_paths.py`、`test_split_gui_trust.py`、`stage_bundle_payload` 相关测试里断言
   `BundleProgram`、`HelperTools` 内容、daemon 执行路径的地方随上述改动更新。
