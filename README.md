# pwshcfg - PowerShell 可复制工作环境

一键部署 PowerShell 开发环境，换新电脑也能快速恢复工作状态。

## 快速开始

### 新电脑部署

**准备工作：**
1. 开代理软件，确保端口 10809 可用
2. 安装 Git（如果没有）
3. 安装 PowerShell 7（可选）

**部署步骤：**
```powershell
# 1. 克隆仓库
git clone <your-repo> pwshcfg
cd pwshcfg

# 2. 双击 deploy.bat 或执行
.\deploy.ps1
```

### 日常使用

```powershell
# 导出当前 Scoop 配置
.\export.bat

# 部署最新配置
.\deploy.bat
```

## 目录结构

```
pwshcfg/
├── deploy.bat                    # 双击部署
├── deploy.ps1                    # 部署脚本
├── export.bat                    # 双击导出配置
├── export-scoop.ps1              # 导出 Scoop 配置
├── Microsoft.PowerShell_profile.ps1  # PowerShell 主配置
├── buckets.txt                   # Scoop Bucket 列表
├── installed_apps.json           # 已安装应用列表
├── _scripts/                     # 功能脚本（自动加载）
│   ├── Utils.ps1                 # 基础工具函数
│   ├── proxy.ps1                 # 代理开关
│   ├── lsd.ps1                   # 目录美化
│   ├── start.ps1                 # 快捷启动
│   ├── scoop.ps1                 # Scoop 管理
│   ├── dotnet.ps1                # .NET 补全
│   ├── lazygit.ps1               # LazyGit 快捷
│   ├── rust.ps1                  # Rust 环境
│   └── python.ps1                # Python 环境
├── _modules/                     # 模块（懒加载）
│   ├── android.ps1               # Android 工具集
│   ├── Test-Emulator.ps1         # 模拟器测试
│   ├── Test-Lib.ps1              # APK 安全检测
│   └── Test-RebuiltApk.ps1       # APK 重打包测试
└── README.md
```

## 部署流程

```
deploy.bat
    │
    ▼
┌─────────────────────────┐
│ 1. 安装 Scoop（如果需要）│
│   自动设置代理 10809     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 2. 恢复 Buckets          │
│   读取 buckets.txt       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 3. 恢复已安装应用        │
│   读取 installed_apps.json│
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 4. 部署 PowerShell 配置  │
│   ├── 备份旧配置         │
│   ├── 复制新 profile     │
│   ├── 复制 _scripts/     │
│   └── 复制 _modules/     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 5. 部署 Starship 主题    │
│   应用 pure-preset       │
└───────────┬─────────────┘
            │
            ▼
          完成
```

## 命令列表

### 基础工具

| 别名 | 说明 |
|------|------|
| `myip` | 查询外网 IP |
| `ex` / `owp` | 资源管理器打开当前目录 |
| `b64e` | Base64 编码 |
| `b64d` | Base64 解码 |
| `md5sum` | MD5 哈希 |
| `sha1sum` | SHA1 哈希 |
| `sha256sum` | SHA256 哈希 |
| `proxy` | 启用代理 |
| `unproxy` | 禁用代理 |
| `cmds` | 列出所有命令 |
| `s` | 查看历史命令 |
| `env` | 列出环境变量 |
| `aria2` | 启用 aria2 加速 |
| `aria2off` | 禁用 aria2 |

### 搜索工具

| 别名 | 说明 |
|------|------|
| `ff` | fd 快速查找文件 |
| `rg` | ripgrep 快速搜索内容 |
| `touch` | 创建文件/修改时间戳 |
| `Ctrl+R` | fzf 搜索历史命令 |
| `Ctrl+T` | fzf 搜索文件并插入路径 |

### 目录列表

| 别名 | 说明 |
|------|------|
| `ll` | 长列表 |
| `la` | 完整列表 |
| `l` | 简洁列表 |
| `lt` | 树形显示 |
| `lS` | 文件大小 |
| `lsg` | 显示 git 状态 |
| `lsrt` | 按时间排序 |
| `lsz` | 按大小排序 |

### 版本切换

| 别名 | 说明 |
|------|------|
| `jv 17` | 切换 Java 17 |
| `jv 8` | 切换 Java 8 |
| `pv 312` | 切换 Python 3.12 |
| `pv 38` | 切换 Python 3.8 |
| `py-list` | 列出已安装 Python |
| `jdk-list` | 列出已安装 JDK |

### 快捷启动

| 别名 | 说明 |
|------|------|
| `burp` | 启动 Burp Suite |
| `vs` | 启动 VS Code |
| `sudo` | 管理员提权 |
| `sand` | 启动 Sandboxie |
| `lg` | lazygit |

### Android 工具（懒加载）

| 命令 | 别名 | 说明 |
|------|------|------|
| `Get-ApkInfo` | `apkinfo` | 获取 APK 信息 |
| `Get-ApkSignInfo` | `apksign` | 获取 APK 签名 |
| `Get-JarSignInfo` | `jarsign` | 获取 JAR 签名 |
| `Get-ApkLibs` | `apklibs` | 获取 APK 中的 so 文件 |
| `Get-ApkProtectInfo` | `apkprotect` | 查看加固信息 |
| `Get-AppObfuscInfo` | `appinfo` | APK 混淆检测 |
| `Get-DeviceApk` | `pullapk` | 从设备提取 APK（支持 `-Foreground`） |
| `Get-AppData` | `pulldata` | 提取应用沙箱数据 |
| `Get-AppSandbox` | `sandbox` | 查看沙箱权限/敏感文件（`-Files`） |
| `Decompile-Apk` | `decompile` | 反编译 APK |
| `Recompile-Apk` | `recompile` | 重编译 APK |
| `Sign-Apk` | `signapk` | 签名 APK |
| `Test-RebuiltApk` | `testapk` | 重打包测试 |
| `Test-EmulatorApk` | `testemu` | 模拟器测试 |
| `Test-ApkLib` | `testlib` | APK 安全检测 |

## 新电脑需要手动配置

部署完成后会提示：

```powershell
# APK 混淆检测工具路径
$Env:APPOBFUSC_TOOL = "D:\SecTools\...\appinfo.py"

# 模拟器路径
$Env:EMULATOR_PATH = "D:\Soft\...\dnplayer.exe"

# 永久保存
[Environment]::SetEnvironmentVariable('变量名', '值', 'User')
```

## 更新配置

```powershell
# 1. 修改 _scripts/ 或 _modules/ 中的脚本
# 2. 导出 Scoop 配置
.\export.bat

# 3. 提交到 Git
git add -A
git commit -m "update"
git push

# 4. 新电脑同步
git pull
.\deploy.bat
```

## 故障排除

### Scoop 安装失败
确保代理已开启（端口 10809）

### 命令不生效
重启 PowerShell 或执行 `. $PROFILE`

### 查看所有命令
执行 `cmds`
