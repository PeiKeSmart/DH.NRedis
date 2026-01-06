# PeiKeSmart Copilot 协作指令

本说明适用于沛柯智能（PeiKeSmart）及其全部开源/衍生项目，规范 Copilot 及类似智能助手在 C#/.NET 项目中的协作行为。

---

## 1. 核心原则

| 原则 | 说明 |
|------|------|
| **提效** | 减少机械样板劳动，聚焦业务/核心算法 |
| **一致** | 风格、结构、命名、API 行为稳定 |
| **可控** | 限制改动影响面，可审计，兼容友好，不引入隐患 |
| **可靠** | 先检索再生成，不虚构，不破坏现有合约，保持性能 |

---

## 2. 适用范围

- 含 PeiKeSmart 组件或衍生的全部 C#/.NET 仓库
- 不含纯前端/非 .NET/市场文案
- 存在本文件 → 必须遵循

---

## 3. 角色与职责

- **开发者**：提出清晰需求（功能/缺陷/性能/重构/文档）
- **Copilot**：先检索再生成；输出必要且影响面受控的改动；不虚构；简体中文回复
- **审核关键点**：公共 API、一致性、性能影响

---

## 4. 工作流

```
需求分类 → 检索 → 评估 → 设计 → 实施 → 验证 → 说明 → 提交
```

1. **需求分类**：功能/修复/性能/重构/文档
2. **检索**：相关类型、目录、方法、已有扩展/工具（**优先复用**）
3. **评估**：是否公共 API？是否性能热点？
4. **设计**：列出改动点 + 兼容/降级策略
5. **实施**：局部编辑，限制改动影响面；保留原注释与结构
6. **验证**：通过编译；自动运行与本次改动相关的单元测试；若未发现任何相关测试，在结果中明确说明；不得自动新增测试项目
7. **说明**：变更摘要/影响范围/风险点
8. **提交**：统一格式，整理中文提交日志；禁止夹带无关格式化

---

## 5. 编码规范

### 5.1 基础规范

| 项目 | 规范 |
|------|------|
| 语言版本 | `<LangVersion>latest</LangVersion>`，所有目标框架均使用最新 C# 语法 |
| 命名空间 | file-scoped namespace |
| 类型名 | **必须**使用 .NET 正式名 `String`/`Int32`/`Boolean` 等，避免 `string`/`int`/`bool` |
| 单文件 | 每文件一个主要公共类型；较大平台差异使用 `partial` |

### 5.2 命名规范

| 成员类型 | 命名规则 | 示例 |
|---------|---------|------|
| 类型/公共成员 | PascalCase | `UserService`、`GetName()` |
| 参数/局部变量 | camelCase | `userName`、`count` |
| 私有字段（实例/静态） | `_camelCase` | `_cache`、`_instance` |
| 属性/方法（实例/静态） | PascalCase | `Name`、`Default`、`Create()` |
| 扩展方法类 | `xxxHelper` 或 `xxxExtensions` | `StringHelper`、`CollectionExtensions` |

### 5.3 代码风格

```csharp
// ✅ 单行 if：单语句且整行不过长时同行
if (value == null) return;
if (key == null) throw new ArgumentNullException(nameof(key));

// ✅ 单行 if：语句较长时另起一行
if (value == null)
    throw new ArgumentNullException(nameof(value), "Value cannot be null");

// ✅ 多分支单语句：不加花括号
if (count > 0)
    DoSomething();
else
    DoOther();

// ✅ 循环必须保留花括号（即使单语句）
foreach (var item in list)
{
    Process(item);
}
```

**风格要求**：
- 忌全量重排、无差异格式化提交
- Linq、反射仅用于非高频路径；热点使用手写循环/缓存
- 禁止擅自删除已有代码注释（含单行 // 与 XML 文档注释），可以修改或追加
- 不得仅为对齐或所谓美观批量移除、合并空白行；保留有意的逻辑分隔空行

### 5.4 可读性优先（就近规则）

- **局部变量就近声明**：在首次使用前的最近位置声明，避免集中在方法开头
- **字段紧邻属性**：私有字段命名 `_xxx`，并紧贴使用它的属性之前，减少跨距阅读
- **按用途放置字段**：若某私有字段仅被单一方法使用（如 `TimerX _timer`），优先放在该方法之前；若被多方法共享，则集中放在 `#region 属性` 段的末尾，便于统一浏览与维护
- **成组排布**：相关成员按依赖顺序成组摆放，降低跳转成本
- **合理例外**：如会导致重复声明、闭包捕获或影响性能/生命周期，可权衡位置并加简短注释

冲突时以"易读易懂"为先。

### 5.5 Region 组织结构

较长的类使用 `#region` 分段组织，遵循以下顺序：

```csharp
public class MyService : DisposeBase
{
    #region 属性
    /// <summary>名称</summary>
    public String Name { get; set; }

    /// <summary>是否启用</summary>
    public Boolean Enabled { get; set; }

    // 私有字段放在属性段末尾
    private ConcurrentDictionary<String, Object> _cache = new();
    private TimerX? _timer;
    #endregion

    #region 构造
    /// <summary>实例化</summary>
    public MyService() { }

    /// <summary>销毁资源</summary>
    /// <param name="disposing">是否释放托管资源</param>
    protected override void Dispose(Boolean disposing)
    {
        base.Dispose(disposing);
        _timer.TryDispose();
    }
    #endregion

    #region 方法
    /// <summary>启动服务</summary>
    public void Start() { }
    #endregion

    #region 辅助
    /// <summary>日志</summary>
    public ILog Log { get; set; } = Logger.Null;

    /// <summary>写日志</summary>
    /// <param name="format">格式化字符串</param>
    /// <param name="args">参数</param>
    protected void WriteLog(String format, params Object[] args) => Log?.Info(format, args);
    #endregion
}
```

**Region 顺序**：`属性` → `静态`（如有）→ `构造` → `方法` → `辅助`/`日志`

### 5.6 现代 C# 语法偏好

优先使用最新 C# 语法，即使目标框架是 net45（Visual Studio 支持）：

- 使用 switch 表达式与模式匹配（含 relational、logical、property/positional patterns）
- 使用集合表达式与简化初始化（C# 12）：`[]`、`[..spread]`、`"key" => value`
- 使用目标类型 new、文件作用域命名空间、`init`/`required` 成员、record/record struct
- 使用插值原始多行字符串与 `using var` 声明减少样板代码

示例：

```csharp
// 文件作用域命名空间
namespace Demo;

public readonly record struct User(String Name, Int32 Age);

static String Describe(Int32 code) => code switch
{
    200 => "OK",
    >= 400 and < 500 => "ClientError",
    >= 500 => "ServerError",
    _ => "Other"
};

// 集合表达式（C# 12）
var baseList = [1, 2, 3];
List<Int32> list = [..baseList, 4];
Dictionary<String, Int32> map = ["a" => 1, "b" => 2];

// 目标类型 new 与 using 声明
using var ms = new MemoryStream();
List<User> users = [];
```

### 5.7 多目标框架

支持 `net45` 到 `net10`，使用条件编译处理 API 差异：

```csharp
// 常用条件符号
#if NETFRAMEWORK          // net45/net461/net462
#if NETSTANDARD2_0        // netstandard2.0
#if NETCOREAPP            // netcoreapp3.1+
#if NET5_0_OR_GREATER     // net5.0+
#if NET6_0_OR_GREATER     // net6.0+
#if NET8_0_OR_GREATER     // net8.0+
```

**注意**：新增 API 时需评估各框架兼容性，必要时提供降级实现。

---

## 6. 文档注释

```csharp
/// <summary>执行指定操作</summary>
/// <param name="action">操作委托</param>
/// <param name="timeout">超时时间，单位毫秒</param>
/// <returns>执行是否成功</returns>
public Boolean Execute(Action action, Int32 timeout) { }

/// <summary>初始化服务</summary>
/// <remarks>
/// 复杂方法可增加详细说明。
/// 中文优先，必要时补精简英文。
/// </remarks>
/// <param name="config">配置对象</param>
/// <param name="log">日志接口</param>
public MyService(Config config, ILog log) { }
```

| 规则 | 说明 |
|------|------|
| `<summary>` | **必须同一行闭合**，简短描述方法用途 |
| `<param>` | **必须为每个参数添加**，无论方法可见性如何 |
| `<returns>` | 有返回值时必须添加 |
| `<remarks>` | 复杂方法可增加详细说明（可多行） |
| 覆盖范围 | `public`/`protected` 成员必须注释，包括构造函数；`private`/`internal` 方法建议添加 |
| `[Obsolete]` | 必须包含迁移建议 |

### 6.1 注释完整性检查清单

生成或修改方法注释时，**必须逐项检查**：

1. ✅ `<summary>` 是否单行闭合？
2. ✅ 是否为**每个参数**都添加了 `<param>`？
3. ✅ 有返回值时是否添加了 `<returns>`？
4. ✅ 泛型方法是否添加了 `<typeparam>`？

**正确示例**：
```csharp
/// <summary>获取或设置名称</summary>
public String Name { get; set; }

/// <summary>创建客户端连接</summary>
/// <param name="host">服务器地址</param>
/// <param name="port">端口号</param>
/// <returns>客户端实例</returns>
public TcpClient Create(String host, Int32 port) { }

/// <summary>启动服务</summary>
/// <remarks>
/// 启动后将开始监听端口，支持多次调用（幂等）。
/// 建议在应用启动时调用一次。
/// </remarks>
public void Start() { }

/// <summary>映射配置到对象</summary>
/// <param name="reader">Xml读取器</param>
/// <param name="section">目标配置节</param>
private void ReadNode(XmlReader reader, IConfigSection section) { }
```

**错误示例**（禁止）：
```csharp
// ❌ summary 拆成多行
/// <summary>
/// 获取或设置名称
/// </summary>
public String Name { get; set; }

// ❌ 缺少参数注释（即使是私有方法也不允许）
/// <summary>创建客户端连接</summary>
public TcpClient Create(String host, Int32 port) { }

// ❌ 有参数但没有 param 标签
/// <summary>递归读取节点</summary>
private void ReadNode(XmlReader reader, IConfigSection section) { }
```

---

## 7. 异步与性能

| 规范 | 说明 |
|------|------|
| 方法命名 | 异步方法后缀 `Async` |
| ConfigureAwait | 库内部默认 `ConfigureAwait(false)` |
| 高频路径 | 优先对象池/`ArrayPool<T>`/`Span`，避免多余分配 |
| 反射/Linq | 仅用于非热点路径；热点使用手写循环/缓存 |
| 池化资源 | 明确获取/归还；异常分支不遗失归还 |

### 内置工具优先

```csharp
// ✅ 使用 Pool.StringBuilder 避免频繁分配
var sb = Pool.StringBuilder.Get();
sb.Append("Hello");
return sb.Return(true);

// ✅ 使用 Runtime.TickCount64 避免时间回拨
var tick = Runtime.TickCount64;

// ✅ 使用扩展方法进行类型转换
var num = str.ToInt();
var flag = str.ToBoolean();
```

---

## 8. 日志与追踪

```csharp
#region 辅助
/// <summary>日志</summary>
public ILog Log { get; set; } = Logger.Null;

/// <summary>链路追踪</summary>
public ITracer? Tracer { get; set; }

/// <summary>写日志</summary>
/// <param name="format">格式化字符串</param>
/// <param name="args">参数</param>
protected void WriteLog(String format, params Object?[] args) => Log?.Info(format, args);
#endregion

// ✅ 关键过程埋点（简易版，不关注异常）
using var span = Tracer?.NewSpan("ProcessData");
// 业务逻辑

// ✅ 关键过程埋点（标准版，需要捕获异常）
using var span = Tracer?.NewSpan("ProcessData");
try
{
    // 业务逻辑
}
catch (Exception ex)
{
    span?.SetError(ex, null);
    throw;
}
```

---

## 9. 错误处理

- **精准异常类型**：`ArgumentNullException`/`InvalidOperationException` 等
- **参数校验**：空/越界/格式
- **TryXxx 模式**：不用异常作常规分支
- **类型转换**：优先使用 `ToInt()`/`ToBoolean()` 等扩展方法
- **对外异常**：不暴露内部实现/路径

---

## 10. 测试规范

| 项目 | 规范 |
|------|------|
| 框架 | xUnit |
| 命名 | `{ClassName}Tests` |
| 描述 | `[DisplayName("中文描述意图")]` |
| IO | 使用临时目录；端口用 0/随机 |
| 覆盖 | 正常/边界/异常/并发（必要时） |

### 测试执行策略

1. 优先检索 `{ClassName}` 引用，若落入测试项目则运行
2. 未命中则查找 `{ClassName}Tests.cs`
3. **未发现相关测试需明确说明**，不自动创建测试项目

---

## 11. NuGet 发布规范

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| 正式版 | `{主版本}.{子版本}.{年}.{月日}` | `11.9.2025.0701` |
| 测试版 | `{主版本}.{子版本}.{年}.{月日}-beta{时分}` | `11.9.2025.0701-beta0906` |

- **正式版**：每月月初发布
- **测试版**：提交代码到 GitHub 时自动发布

---

## 12. Copilot 行为守则

### 必须

- 简体中文回复
- 输出前检索现有实现，**禁止重复造轮子**
- 先列方案再实现
- 标记不确定上下文为"需查看文件"

### 禁止

- 虚构 API/文件/类型
- 伪造测试结果/性能数据
- 擅自删除公共/受保护成员
- 擅自删除已有代码注释
- 仅删除空白行制造"格式优化"提交
- 删除循环体的花括号
- 将 `<summary>` 拆成多行
- 将 `String`/`Int32` 改为 `string`/`int`
- 新增外部依赖（除非说明理由并给出权衡）
- 在热点路径添加未缓存反射/复杂 Linq
- 输出敏感凭据/内部地址

---

## 13. 变更说明模板

提交或答复需包含：

```markdown
## 概述
做了什么 / 为什么

## 影响
- 公共 API：是/否
- 性能影响：无/有（说明）

## 兼容性
降级策略 / 条件编译点

## 风险
潜在回归 / 性能开销

## 后续
是否补测试 / 文档
```

---

## 14. 术语说明

| 术语 | 定义 |
|------|------|
| **热点路径** | 经性能分析或高频调用栈确认的关键执行段 |
| **基线** | 变更前的功能/性能参考数据 |

---

（完）
