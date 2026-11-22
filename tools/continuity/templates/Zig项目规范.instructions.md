---
name: Zig项目规范
description: "Use when: 改 Zig 代码/构建、设计并发模型、做串口或硬件调测时。"
applyTo: "**/*.zig,**/build.zig,**/build.zig.zon"
---

# Zig项目规范（用户级 · 按技术栈按需加载）

## Zig 项目：异步与并发必须进设计（用户偏好 · 全 Zig 项目）

- **每个 Zig 项目在架构阶段就要给异步/并发一个明确结论**（用不用、为什么、什么平台能真异步），不能默认「同步阻塞 + 每连接一线程」就算完。用户 2026-11-12 原话：**「ziglang的实现都必须要考虑异步」**。
- **先分清平台能力，别把「做不了」当「不用考虑」**：Zig 0.17 的 std 在 Windows 上 socket 读是同步 `deviceIoControl`（`operateTimeout` 报 `ConcurrencyUnavailable`），真异步要自己做 **AFD overlapped + IOCP**；POSIX 侧 std 才有 epoll/io_uring。
- **参考 `E:\Code\Zig\lighting`**（`zio` 运行时 + `std.Io` 双后端，Linux io_uring 峰值 710k QPS）：学它的**模型与基准方法论**，不抄代码、不给零依赖项目引 zio。
- **定方案必须给四组实测数**：单请求延迟、长连接 QPS、短连接 QPS、并发连接上限。经验值：每连接一线程 ≈ **86~147 us** 固定成本（创建+销毁；128 KiB 栈优于 16 MiB）；小包协议不关 Nagle 会差 **10 倍**。
- **落地顺序（由易到难）**：① 关 `TCP_NODELAY`（gRPC / WebSocket / 长连接必做）→ ② 线程栈压小 + 线程池化 → ③ 事件驱动（IOCP / epoll）→ ④ 全异步状态机改造。

## 串口 / 硬件调测（用户偏好 · 全项目适用）

- **凡是要用串口调测设备硬件，一律直接用本机的 ZZCOM（`G:\Code\Zig\ZZCOM`），不要临时写脚本、不要装第三方串口工具、不要让用户手工点界面**。用户 2026-11-08 原话：「如果要使用串口来调测设备硬件的话是不是直接使用当前我们这个串口项目」。
- **优先走它的 MCP，让 AI 自己收发**：
  - **stdio**（推荐，客户端直接拉起）：`G:\Code\Zig\ZZCOM\zig-out\bin\zzcom-mcp-x64.exe`（32 位用 `-x86`）。
  - **HTTP**（GUI 内嵌，需 `zzcom.ini` 里 `mcp=1`、`mcp_port`、`mcp_token`）：`POST http://127.0.0.1:<port>/mcp`，头 `Authorization: Bearer <token>`，先 `initialize` 再 `tools/list` / `tools/call`。
  - 工具：`serial_list_ports` / `serial_open` / `serial_close` / `serial_write`（`text` 或 `hex`，`newline` 0无 1CR 2LF 3CRLF）/ `serial_read`（`timeout_ms`、`max_bytes`）/ `serial_status` / `serial_set_lines`（DTR/RTS）。
- **串口是独占资源**：MCP 占用时不要在 GUI 里再开同一个口；需要人工看界面就用 GUI 的同一实例（HTTP MCP），需要脚本/Agent 长时间占用就用 stdio 版。
- **产物缺失先构建**：`zig-out\bin\` 下没有 exe 时在项目根跑 `zig build`（Zig 0.17.0；产物 GUI 子系统、Win7+、不链 libc/UCRT）。
- **开不了口按顺序排查**：`serial_list_ports` 看枚举 → 是否被其它进程占用（`zzcom.log` / `zzcom-mcp.log` 里有具体错误与错误码）→ 再怀疑线序/供电/波特率。
- **报告结论要带实测数据**：实际发送的字节（hex）、收到的原始字节、超时值；不要只写「通信正常」这类无证据结论。

<!-- 版本：2026.11.22.1（content 变更请递增；本文件按 applyTo 按需加载，勿把细则塞回 "**" 版） -->
