---
name: Rust项目规范
description: "Use when: 改 Rust 代码/Cargo/构建与发布脚本、排查编译慢、拉新源码依赖、判断可复用实现时。"
applyTo: "**/*.rs,**/Cargo.toml,**/*.ps1,**/*.sh,**/Dockerfile"
---

# Rust项目规范（用户级 · 按技术栈按需加载）

## 打包、发版与覆盖升级（用户偏好 · 全项目适用）
- **打包即升版本**：发布打包脚本默认在打包时自动递升补丁版本号（每产出一次包版本唯一）；次版本升号用显式参数；版本守卫拦截「同版本内容变化」；需重打同版本时显式关闭（-NoBump 或 -Force，视脚本而定）。
- **工具链用最新**：系统 PATH 与构建脚本一律使用最新稳定工具链（如 zig 0.17.0）；旧版本仅留档，不作为默认。
- **打包部署一律走 zig 交叉编译**：对外部署包（Linux）必须用 `cargo zigbuild` 交叉编译产出（x64 = `x86_64-unknown-linux-musl`，arm64 = `aarch64-unknown-linux-musl`）；本机 Windows 的 `cargo build --release` 只作开发验证包，不作为交付物。打包脚本必须内置 zig 分支，zig 查找顺序 `CARGO_ZIGBUILD_ZIG_PATH` → `E:\Soft\zig-*`（取最新）→ 项目 `tools\zig`；缺 zig/cargo-zigbuild 时明确报错，不得静默退回本机编译。
- **升级一律走「覆盖替换」、免手动停启**：星尘（Pek.RAgent）默认**影子模式**（进程运行 `shadow/` 下的影子副本，源文件不被占用），Windows / Linux 均可直接覆盖源程序文件；代理按 5 秒周期检测变动 → 重建影子副本 → 自动重启（数秒级）。部署脚本与文档必须支持并说明该方式，不得要求「先停止 → 再替换 → 再启动」。
- **部署设计约束**：安装脚本以绝对路径注册子服务（`-AddService`，默认影子）；程序保持「配置就绪才运行」守卫（占位配置保持停用），避免无效配置被反复拉起。

## 编译提速规范（用户偏好 · 全项目适用）
- **分档选最快的构建方式**：写代码用 `cargo check`（增量秒级、**不做链接**、不产二进制）；本地调测 / 起服务验证用 `cargo build --profile fast`（或 `cargo run --profile fast`）；`--release` / zig 交叉只用于发布，不用于日常验证。
- **Windows 宿主一律用 `rust-lld` 链接**：`%USERPROFILE%\.cargo\config.toml` 加
  `[target.x86_64-pc-windows-msvc]` + `linker = "rust-lld.exe"`（随 rustup 工具链自带，无需另装）。
  实测本机增量 debug `cargo build` **13.76s → 2.66s**；瓶颈是 MSVC `link.exe`（PDB 写入 + Defender 实时扫描），不是 CPU。
  只作用于 MSVC host，`cargo zigbuild` 交叉编译不受影响（已回归验证 exit 0）。
- **每个 Rust 项目必须自带 `[profile.fast]`**：`inherits = "release"` + `lto = false` + `codegen-units = 16` + `incremental = true`。
  缺了它 `cargo build --profile fast` 直接 `exit 101`（PekSendToMo 踩过）。实测改一个文件：**fast ≈4s / 配 rust-lld 后增量仅 1.3~1.75s vs fat LTO ≈3m10s**；`--release`（fat LTO）只给发版，不要为了“快”而长期用 dev 跑压测。
  **★ 上面这组数字只适用于「小项目 / 已拆 crate」**：单 crate 大项目（如 HLZX.EIP，20 万行、`members = ["."]`）
  改一行 `--profile fast` 实测 **2m24s** —— 因为 **rustc 的增量单位是 crate**，改任意 `.rs` 都要重做整个 crate 的
  codegen + 链接。先确认自己是哪种，再决定跑哪个档；拿不准就先用 `cargo build`（dev）跑测试。
- **先分清「下载慢」还是「编译慢」**：`cargo build -v` 看是 `Downloading` 还是 `Compiling`；只有 `Compiling` 占大头才去调 profile / 换链接器 / 换编译目标，否则白忙。
- **保存即检查 / 自动重启**：Rust 项目装 `cargo-watch`，用 `cargo watch -x check`（或 `-x run`）代替手动重复构建。
- **前端改动不重编后端**：Vue/Vite 项目开发期用 `vite dev`（热更新 + /api 代理）；构建产物目录（如 `wwwroot`）是独立资源、刷新页面即生效；只有后端源码变化才需要 cargo。
- **sccache 按需**：仅在经常 `cargo clean`、频繁切 target/profile 或 CI 共享缓存时启用（`[build] rustc-wrapper = "sccache"`）；它不缓存本 crate 重编与 LTO 链接，不能解决「改一个文件两分钟」。
- **杀软排除**：代码目录与 `CARGO_TARGET_DIR` 建议加入 Defender 实时扫描排除（本机已排除 `F:\Soft\...`），否则每个 obj/pdb 落盘都要过一遍扫描。
- **口径纠正**：**`ziglang` 与编译速度无关** —— `cargo zigbuild` 是**交叉编译工具链**（产出 Linux musl 包），不是提速手段；WSL2 也不是通用银弹，见下一节。
- **★ 验证一律走分档，不要动不动打包（用户已 3 次强调：2026-10-27「先不要打包，不要动不动就打包，这样很浪费时间，都没有完全确认我的信息」；2026-10-28「不要动不动又打包」；2026-11-05「先不要动不动就打包，我记得我提过很多次了，你要验证不是应该按快速运行验证的方式么？」）**：
  - **自测 = 快速运行**：`cargo check`（看错误）→ `cargo build`（dev 档出 exe）→ **起本地实例实测**（换端口 + 临时数据目录 / `--data-dir`；前端用 `vite dev` 或构建脚本按需）→ 浏览器/接口验证。
  - `--profile fast` 只用于**交付前**验证；`--release` / `cargo zigbuild` 交叉**只用于发版**。
  - **打包脚本只在用户明确说「打包 / 出包 / 我要部署」时才跑** —— 打包会递升版本号、`dist/` 越堆越多，且耗时远大于验证；汇报里也不要写「顺手打了个包」。

## WSL2 规范（用户偏好 · 全项目适用）

- **WSL2 不是「编译更快」的银弹**：收益来自 **ext4 本机盘 + Linux 原生工具链 + 与部署环境一致**。源码放 `/mnt/<盘>`（Windows 盘）跨文件系统访问**比 Windows 原生更慢**；要对比就把仓库镜像到 `~/work` 再构建。
- **离线安装（不依赖 Microsoft Store，2026-11-05 实测）**：`dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart` + 同名 `VirtualMachinePlatform`（返回 **3010 = 成功、需重启**）→ 装 WSL msi → `wsl --import <名> <目录> <rootfs.tar.gz> --version 2`。重启前 `wsl --update` 会**挂住**、`wsl --import` 报 `HCS_E_SERVICE_NOT_AVAILABLE`，均属正常。
- **`/etc/wsl.conf` 必须 `appendWindowsPath=false`**：否则可能调到 Windows 版 `cargo` / `rustc`，报莫名错误；需要时用绝对路径。
- **参考实现**：`PekSendToMo/scripts/setup-wsl.ps1`（幂等 7 步：自检功能 → 装 WSL → 校验 rootfs → 导入 → 建用户 → apt 换源装依赖 → 装 rustup），其它项目可直接复制改参数。

## 国内镜像与 Windows 脚本约定（用户偏好 · 全项目适用）

- **crates 镜像**：每个 Rust 项目根目录放 `.cargo/config.toml`，配 `[source.crates-io] replace-with = "rsproxy-sparse"`（`sparse+https://rsproxy.cn/index/`）—— 缺这个文件的仓库首次编译会从 crates.io 慢速拉包（同一台机器上实测卡十几分钟）；`replace-with` 是透明替换，Cargo.lock 里的源地址不变、不产生锁拖动。
- **rustup 镜像**：`RUSTUP_DIST_SERVER=https://rsproxy.cn`、`RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup`。
- **系统镜像必须实测再选（2026-11-05，同一文件）**：`mirror.nju.edu.cn` **36 MB/s** > `mirrors.ustc.edu.cn` 12 MB/s > 官方 `cloud-images.ubuntu.com` **0.58 MB/s**；TUNA / BFSU / SJTU 的 `ubuntu-cloud-images` 路径 **404**（不镜像该子目录）。GitHub releases ≈ 1.5 MB/s。不要默认「清华一定行」。
- **`curl` 报 `CRYPT_E_NO_REVOCATION_CHECK (0x80092012)`**：Windows schannel 查不到吊销列表，加 `--ssl-no-revoke`；**不要**改用 `-k` 关掉证书校验。
- **含中文的 `.ps1` 用 UTF-8 with BOM**（PS 5.1 按 ANSI 读无 BOM 文件，中文会乱码）；跑 python 前设 `$env:PYTHONIOENCODING='utf-8'`。
- **PS 5.1 调外部命令**：`$ErrorActionPreference = 'Stop'` 会把外部程序写 stderr 当成**终止错误**，`wsl.exe` / `cargo` / `git` 的正常报错会直接把脚本炸掉且不给提示。必须封装：临时 `Continue` → 执行 → 取 `$LASTEXITCODE` 与输出 → 还原。
- **`WSL_UTF8=1`** 让 `wsl.exe` 输出 UTF-8，但 PS 5.1 仍按 ANSI 解码 → 中文全乱码；同时要把 `[Console]::OutputEncoding` 设成 UTF-8（用完还原）。

## 复用优先 · 禁止重复造轮子（用户偏好 · 全项目适用）

- **任何功能、任何大小的改动，写码前的第一动作都是检索**——不是只有“重启/升级/影子”这类才查：加一个接口、加一个字段、做一个弹窗、写一段部署脚本、改一行前端，都先检索。顺序固定：**公共库 → 兄弟项目 → 本仓库既有实现**，三处都查过才允许新写；查不到也要在交付说明里写一句「查过 X / Y / Z，无可复用实现」。
- **按功能域查，别只按功能名查**（同一能力常叫别的名字）。先认领域，再按该域的常见同义词检索：

  | 功能域 | 必查关键词（命中任一就去看实现） | 通常的落点 |
  |---|---|---|
  | 数据库 / ORM / 建表 / 迁移 | `Dal`、`EntityModel`、`sync_schema`、`Database.toml`、`db_admin`、`Query`、`Where`、`readwrite`、`shards` | `Pek.RCode` |
  | 鉴权 / 会话 / 令牌 | `panel_auth`、`AuthLevel`、`PanelSession`、`jwt`、`claims`、`revoke` | `dhrust::net::panel_auth`、`Pek.RPermissions` |
  | 登录口令 / 加密 / 挑战式登录 | `sign::password`、`challenge`、`salted_sha256_hex`、`secret`、`enc:v1` | `dhrust::sign`、`dhrust::secret` |
  | 限流 / 防爆破 | `login_guard`、`rate_limit`、`封禁` | `dhrust::net::login_guard` |
  | WAF / 机器人 / 注入 / CSRF | `Waf`、`WafConfig`、`csrf`、`bot`、`block_malicious` | `Pek.RWaf` |
  | 审计 / 操作日志 / 脱敏 | `AuditEntry`、`audit`、`redact`、`记录` | `Pek.RAdmin` |
  | 配置读写 / 热重载 / 迁移 | `TomlConfig`、`Config<`、`reload_if_changed`、`backup_and_write`、`DatabaseFile` | `dhrust::config` |
  | 日志 | `logs::`、`init_console_and_file`、`log_format`、`read_tail` | `dhrust::logs`、`dhrust::io` |
  | HTTP 服务 / 路由 / 静态资源 | `HttpServer`、`router`、`Controller`、`StaticFiles`、`ETag`、`gzip`、`early_guard` | `dhrust::net::{http,router,controller,static_files}` |
  | HTTP 客户端 / 出网 | `blocking_request`、`http_client`、`ca_pem`、`offthread` | `dhrust::net::http_client` |
  | 星尘（托管 / 启停 / 重启） | `staragent`、`api_rpc`、`GetServices`、`RestartService`、`shadow` | `dhrust::{staragent,net::api_rpc}` |
  | 升级 / 部署 / 自重启 | `upgrade::`、`extract_archive`、`shadow_deploy_base`、`actual_program`、`handoff` | `dhrust::upgrade` |
  | 文件管理 / 上传下载 / ZIP | `fileman`、`extract_zip`、`Guarded`、`enclosed_name` | `dhrust::{fileman,zip}` |
  | 定时 / 周期任务 | `Timer`、`Cron`、`TimerScheduler`、`interval` | `dhrust::threading` |
  | 缓存 / TTL / 整表缓存 | `TtlCache`、`EntityCache`、`SingleCache`、`FieldCache` | `dhrust::cache`、`Pek.RCode` |
  | 进程 / 服务 / 终端 / 机器信息 | `sys::process`、`ServiceManager`、`Terminal`、`machine_guid` | `dhrust::{sys,service,term}` |
  | 协议 / 序列化 / 分帧 / MQTT | `framing`、`api_rpc`、`mqtt::`、`StandardCodec` | `dhrust::net` |
  | 分页 / 导出 / Excel / 批次 | `MSPageSplit`、`PageSplit`、`excel`、`insert_batch` | `dhrust::excel`、`Pek.RCode` |
  | 通知（短信 / 邮件 / 企业微信） | `wecom`、`send_markdown`、`sms`、`mail` | `dhrust::wecom`、`Pek.RSms`、`Pek.RMail` |
  | 组件 / 驱动分发 / 签名 | `driver_pack`、`plugin::`、`Manifest`、`verify_base64` | `Pek.RCode`、`dhrust::plugin` |
  | 前端版式 / 组件 / 交互 | `dialogOpen`、`dlgConfirm`、`dlgPrompt`、`toast`、`document.hidden`、`.modal-mask`、深色主题变量 | 各项目 `web/`、`res/`、`web-admin/`（RPanlServer / RDbProxy / RAgent / RCard） |
  | **面板弹窗（最易重造）** | `alert(`、`confirm(`、`prompt(`、`#dlg-overlay`、`perm-modal`、`modal-box` | 同上；**原生弹窗一律禁用**，细则见「面板前端交互规范」 |
  | 部署脚本 | `install-*.sh`、`_lib.sh`、`detect_agent_config`、`agent_register` | 本项目 `deploy/` |

  上表是**入口不是全集**：按域先找到候选，再用「功能名 + 同义词」全盘 grep 一遍（中文/英文各来一次）。
- **全盘检索命令（每轮至少跑一条，把输出当证据留着）**：
  ```powershell
  Get-ChildItem 'G:\Code\Rust','G:\Project' -Recurse -Filter '*.rs' -ErrorAction SilentlyContinue |
      Select-String -Pattern '<关键词1>|<关键词2>|<关键词3>'
  ```
- **命中之后看什么**：① 签名是否可直接用；② 是否只差参数/选项/feature；③ 需要改动就**改公共库并连带回归其它消费方**，不要“复制一份再改”；确需特化只留薄壳胶水（参考 Pek.RAgent 的 `service.rs` / `sys.rs`）。
- **`dhrust` 能力对照（别再手写这些；完整清单见库 README）**：
  - 日志/配置/时间/签名/加密：`logs`、`config::{toml,xml}`、`web`、`sign::{password,challenge,salted_sha256_hex}`、`secret`、`version`、`times`、`io::{read_tail,base_dir,safe_replace_file,write_all_text_atomic}`；
  - 网络：`net::{http,http_client,router,controller,static_files,listener,panel_auth,panel,login_guard,port_available,tcp_check,api_rpc}`；
  - **星尘**：`staragent`（注册/注销/`handle_cli`）+ **`staragent::{services,local_port,locate_config,find_by_program,operate,restart_program}`**——本地控制客户端（查子服务/启停重启，走 `net::api_rpc` UDP 规范通道，与 C# 星尘字节级互通；**面板“重启服务”一律用它，不要自己拼 HTTP `/RestartService`**）；
  - **升级/部署**：`upgrade::{extract_archive,extract_program,backup_file,replace_file,shadow_deploy_base,actual_program,handoff,spawn_helper}`（`actual_program`：影子副本 → 源程序路径，升级/重启都必须落到源程序）、`zip`、`patch`、`service`、`fileman`、`term`、`plugin`、`sys::*`、`threading`、`cache::TtlCache`。
- **同一逻辑出现第二份就下沉**：两个项目各写一份同款实现 → 下沉到公共库（`dhrust` / `Pek.RCode` 等），**两个消费方一起切换**并跑回归；下沉时把坑与边界写进文档/注释（如「tokio 运行时内不得 block_on」「toml_edit 删键会带走注释」这类教训）。
- **不要用“复制一份再改”解决差异**：差异用参数/选项/feature 表达。
- **交付前自检（硬性）**：本轮新增/修改的每个函数、结构、脚本函数，都要能回答「公共库里为什么没有可复用的」，并给出**检索证据**（命令 + 命中/未命中）；面板类功能逐项过一遍：日志、鉴权、限流、静态资源、配置回写、升级重启、文件管理、ZIP、审计、WAF、用户与权限——这些在生态里都已存在。
- **反例（2026-10-27，必须记住）**：给 hlktech-iot-mqtt 面板做「重启服务」时没先检索，自写了一整套 HTTP `/GetServices` + `/RestartService` 客户端，还为此多引入一个 feature；实际上 `dhrust::net::api_rpc`（UDP，与 C# 星尘互通）、`Pek.RPanlServer/src/restart.rs`、DHDeploy `star_agent::operate` 早有同款能力。用户当场质问：**「目前做的这些都是没有参考我们自己的Rust项目么？要不然为什么每个项目感觉都是单独实现的」**，随后补充：**「写码前的第一动作就是检索不是只有重启这一块吧」**——即检索必须覆盖**所有功能域**，不是只为某一个功能补作业。当天已把能力下沉为 `dhrust::staragent` 客户端 + `dhrust::upgrade::actual_program`，Pek.RPanlServer 与 HlktechIoT 一起切换。

## 源码依赖自动拉新（用户偏好 · 全项目适用）
- **触发条件（满足任一条即先拉新）**：
  ① **要动它** —— 本机以**源码/路径引用**的依赖库（如 DH.RustBase、Pek.RCode、Pek.RAdmin 等）编译报「缺少被引用的 API/函数」或疑似落后；
  ② **要评它** —— **凡要对已装备 / 依赖仓库做分析、判断、对比之前，先 `git fetch` 看清远端**。只看本地工作树 = 拿「落后的本地」当基准，结论必错（2026-10-12 因此误判 DH.RustBase「缺件」并越界写入，事后 `reset --hard` + 快进才平掉）。
- **做法**：在**原仓库内增量拉新（fetch + 快进）后**再继续（复测 / 分析）；不重克隆（避免大件重下与丢失本地状态）。
- **分支也要看全**：对比 / 判断「有没有」之前先 `git branch -r`；实现可能只在非默认分支（例：HlktechIoT 的 Broker RPC 配置只在 `origin/2.0`，当前 `dev` 没有）。用 `git show origin/<分支>:<路径>` 或 `git grep <符号> origin/<分支>` 核对，不能只搜当前检出分支。
- 拉新纪律：先查工作区状态（有本地改动先说明/stash）；只做快进（--ff-only）；GitHub 直连受限时按既有约定用 IP 直连（http.curloptResolve）；拉新得到的提交号写入当轮收尾台账。
- **边界**：拉新是「读」，**不等于可以写** —— 要改别的仓库时**另问**；各自项目各自仓库处理。

## MVC 目录与控制器（C# 对齐 · 全项目通用）

- **一个控制器一个 `.rs` 文件**：`XxxController.rs` + 类型 `XxxController`；禁止把多个控制器塞进同一文件，也禁止叫 `xxx.rs` 这种看不出是控制器的名字。
- 目录：
  - 区域（后台）控制器 → `Areas/{Area}/Controllers/XxxController.rs`，视图 → `Areas/{Area}/Views/{Controller}/{Action}.cshtml`；
  - 根级（前台/非区域）控制器 → `Controllers/XxxController.rs`，视图 → `Views/{Controller}/{Action}.cshtml`。
- Rust 模块名必须是 snake_case：用 `#[path = "XxxController.rs"] pub mod xxx_controller;` 保住 C# 文件名，
  目录里放 `mod.rs` 统一 `pub use`；`main.rs` 挂载区域模块时路径相对 `src/`，要写 `#[path = "../Areas/{Area}/Controllers/mod.rs"]`。
- 新建控制器时先按上面位置落文件再写路由，**不要**先塞进已有文件再拆。

<!-- 版本：2026.11.22.1（content 变更请递增；本文件按 applyTo 按需加载，勿把细则塞回 "**" 版） -->
