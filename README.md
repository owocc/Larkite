# Larkite 🐦

> **极简 · 现代 · 高性能 macOS 原生飞书客户端**  
> 基于 Swift 6 + SwiftUI 构建，专为 macOS 设计的极简飞书客户端。
---

## 🌟 核心特性

- 🚀 **极简极速**：纯原生 Swift / SwiftUI 打造，超低内存占用，秒级冷启动。
- 🔐 **多模式登录认证**：
  - **飞书网页授权登录 (OAuth 2.0)**：内置本地 Loopback HTTP 回调服务（`http://127.0.0.1:8989/callback`），一键在浏览器授权并自动捕获 Token，完成身份交换。
  - **自建应用免登录 (Tenant Access Token)**：配置 `App ID` 与 `App Secret` 即可直接以机器人身份连接。
  - **Direct Access Token**：支持直接粘贴现有 `user_access_token` 或 `tenant_access_token` 快速调试体验。
  - **安全存储**：基于 macOS Keychain 对应用密钥与 Session Token 进行安全加密持久化。
- 💬 **群组与会话列表**：
  - 调用飞书 `GET /open-apis/im/v1/chats` 官方接口，支持实时分页拉取与加载更多。
  - 内部群 / 外部群分类过滤与状态徽章（正常 / 已解散 / 外部群）。
  - 全局搜索：支持按群名称、群介绍或 Chat ID 实时搜索过滤。
  - 群详情检查器：查看群 ID、群主信息、Tenant Key、描述，一键复制字段，并附带原始 OpenAPI JSON 载荷解析查看器。
- 🛠️ **OpenAPI 调试台**：
  - 内置 API 调试器，可携带当前登录凭证直接测试飞书任意 OpenAPI 端点，查看 HTTP 状态、延迟与格式化 JSON 返回。

---

## 📁 目录架构

```
Larkite/
├── Package.swift               # SPM 配置
├── build_app.sh                # 原生 macOS .app 打包脚本
├── build_dmg.sh                # 制作官方拖拽安装包 .dmg 脚本
├── Larkite.dmg                 # 生成的 macOS 安装镜像包
├── Larkite.app/                # 编译生成的 macOS 应用包
    │   ├── LarkiteApp.swift    # 应用入口
    │   └── AppState.swift      # 全局响应式状态管理 (Auth & Chat)
    │   ├── AuthModels.swift    # OAuth / Token / Session 数据结构
    │   ├── UserModels.swift    # 飞书用户与个人资料模型
    │   └── ChatModels.swift    # 群组 / 会话数据结构
    ├── Services/
    │   ├── FeishuAPIClient.swift # 飞书 OpenAPI & OAuth 网络客户端
    │   ├── OAuthServer.swift   # 本地 Loopback 回调服务 (Network NWListener)
    │   ├── KeychainHelper.swift # macOS Keychain 加密存储
    │   └── ConfigManager.swift # 凭证配置持久化管理器
    └── Views/
        ├── MainView.swift      # 主窗口分栏布局 (Sidebar + Content)
        ├── LoginView.swift     # 多模式登录授权视图
        ├── SidebarView.swift   # 现代化侧边栏与用户卡片
        ├── ChatListView.swift  # 群列表、搜索栏与分类过滤器
        ├── ChatRowView.swift   # 单条群会话单元格
        ├── ChatDetailView.swift# 群属性详情面板与 JSON 预览
        ├── SettingsView.swift  # 凭证与 Scope 设置中心
        ├── DebugView.swift     # OpenAPI 实时调试器
        └── Components/
            ├── GlassCard.swift # 毛玻璃磨砂卡片与渐变按钮
            ├── AvatarView.swift# 异步头像与渐变首字母备用头像
            └── StatusBadge.swift # 状态与权限徽章
```

---

## ⚙️ 快速上手与编译

### 1. 编译并运行

```bash
cd LarkNative
./build_app.sh       # 快速编译为 Larkite.app
open Larkite.app

# 或一键打包为官方 DMG 拖拽安装镜像 (带背景图与 Applications 替身)
./build_dmg.sh
open Larkite.dmg
```
1. 登录 [飞书开放平台开发者后台](https://open.feishu.cn/app) 创建或选择自建应用；
2. 在 **开发配置 -> 安全设置 -> 重定向 URL** 中添加：
   ```
   http://127.0.0.1:8989/callback
   ```
3. 在 **开发配置 -> 权限管理** 中申请以下权限：
   - 获取群信息: `im:chat:readonly` 或 `im:chat`
   - 获取用户基本信息: `contact:user.base:readonly`
   - 获取离线刷新 Token: `offline_access`
4. 在 **添加能力** 中添加「机器人」能力并发布版本。
5. 在应用中输入 `App ID` 和 `App Secret`，点击「启动飞书授权登录」即可！
