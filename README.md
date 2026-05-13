<p align="center">
  <img src="Yulyph/Assets.xcassets/logo.imageset/logo.png" width="120" alt="Yulyph Logo" />
</p>

<h1 align="center">Yulyph</h1>

<p align="center">
  <strong>数字隐写与版权保护的 iOS 工具</strong>
  <br />
  将秘密藏于图片，将版权刻于像素
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS 17.0+" />
  <img src="https://img.shields.io/badge/Swift-6.3-orange.svg" alt="Swift 6.3" />
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License" />
</p>

---

## ✨ 功能亮点

<table>
<tr>
<td width="50%" valign="top">

### 🔒 双模式隐写
- **频域 DCT-QIM** — 基于离散余弦变换 + 量化索引调制，抗 JPEG 压缩，适合社交媒体分享
- **空域 LSB** — 高容量模式，每像素可藏 3 比特，适合无损传输场景
- **自动模式检测** — 提取时智能识别编码模式，完全向后兼容

</td>
<td width="50%" valign="top">

### ⚖️ 版权水印
- **不可见嵌入** — 在图片中嵌入创作者、年份、许可证等信息
- **公开/私有模式** — 留空密钥则公开可见，填密钥则 AES-256-GCM 加密
- **批量扫描识别** — 支持相册批量检测和摄像头实时扫描（含进度显示）

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🛡️ 安全体系
- **AES-256-GCM** — 军事级加密标准，认证加密防篡改
- **PBKDF2 密钥派生** — 100,000 次迭代抗暴力破解，随机 salt 防彩虹表
- **FEC 前向纠错** — Reed-Solomon 风格纠错码，抵抗数据损坏

</td>
<td width="50%" valign="top">

### 🎨 精美界面
- **渐变主题系统** — 多套预设渐变（hero/ocean/warmSunset/tipCard）
- **入场动画** — Spring 弹性动画，逐元素渐入
- **最近活动** — 记录最近操作，方便追踪使用历史

</td>
</tr>
</table>

---

## 📸 界面预览

| 首页 | 隐写嵌入 | DCT 模式检测 |
|:---:|:---:|:---:|
| 渐变卡片 + 模块切换 + 活动记录 | 选择图片、输入信息、调节强度 | 自动检测 LSB/DCT/Copyright |
| 海报模板库 | 版权嵌入 | 版权扫描 |
| 小红书/相框模板 | 创作者信息 + 许可证 + 强度滑块 | 相册批量 / 摄像头实时识别 |

> 截图暂缺，欢迎贡献 Screenshots！

---

## 🚀 使用方法

### 隐藏信息到图片

```
1. 打开 App → 点击「隐藏信息」
2. 选择嵌入模式：抗压缩 (DCT) / 高容量 (LSB)
3. 可选：设置解密密码 → 选择图片
4. 调节嵌入强度（精细 → 最强）
5. 点击「嵌入」→ 保存并分享
```

### 提取隐藏信息

```
1. 打开 App → 点击「提取信息」
2. 选择已嵌入数据的图片
3. 如有密码保护则输入密码
4. 系统自动检测编码模式并提取
```

### 添加版权水印

```
1. 打开 App → 切换到「版权」模块 →「嵌入版权」
2. 输入创作者名称、年份、选择许可证（CC-BY / CC-BY-SA / ARR）
3. 可选：设置访问密钥（留空=公开版权）
4. 选择图片 → 调节嵌入强度 → 一键批量嵌入
5. 分享已标记版权的水印图片
```

### 扫描版权信息

```
1. 打开 App →「版权」→「版权扫描」
2. 选择模式：
   · 相册：批量选择图片 → 自动扫描（并行处理，实时进度）
   · 摄像头：实时取景 → 自动识别版权信息
3. 查看识别结果
```

---

## 🧠 技术架构

```
Yulyph
├── YulyphApp.swift              # App 入口
├── Views
│   ├── HomeView.swift           # 首页（模块切换 + 活动记录）
│   ├── EmbedView.swift          # 隐藏信息
│   ├── ExtractView.swift        # 提取信息
│   ├── CopyrightEmbedView.swift # 版权水印嵌入
│   ├── CopyrightScanView.swift  # 版权扫描（相册 + 摄像头）
│   ├── SettingsView.swift       # 设置
│   └── TemplateLibraryView.swift# 海报模板库
├── Services
│   ├── StegoService.swift       # 隐写核心（DCT-QIM + LSB）
│   ├── CryptoService.swift      # 加密（AES-256-GCM + PBKDF2）
│   ├── FECService.swift         # 前向纠错（单字节纠错）
│   ├── WatermarkService.swift   # 可见水印
│   ├── TemplateService.swift    # 模板渲染
│   └── ActivityStore.swift      # 活动记录
└── Models
    └── CopyrightInfo.swift      # 版权数据模型
```

### 核心算法

| 算法 | 用途 | 说明 |
|------|------|------|
| **DCT-QIM** | 抗压缩隐写 | 8×8 分块 DCT，中频系数对量化索引调制，Header 固定 delta=24 |
| **LSB** | 高容量隐写 | RGB 三通道最低比特位替换，每像素 3 比特 |
| **AES-256-GCM** | 数据加密 | 认证加密模式，防篡改 |
| **PBKDF2-HMAC-SHA256** | 密钥派生 | 100,000 次迭代，随机 16 字节 salt |
| **FEC (XOR Parity)** | 纠错编码 | 32 字节奇偶校验，支持单字节纠错 |

---

## 📋 环境要求

- **iOS** 17.0+
- **Xcode** 16.0+（推荐 26.5）
- **Swift** 6.0+

### 构建

```bash
git clone https://github.com/Mibslee/Yulyph.git
cd Yulyph
xcodebuild -project Yulyph.xcodeproj -scheme Yulyph -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### 测试

```bash
xcodebuild test -project Yulyph.xcodeproj -scheme Yulyph \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YulyphTests
```

---

## 📜 版本历史

| 版本 | 亮点 |
|------|------|
| **v1.7** | 并行扫描加速、对称 QIM 图片质量优化、测试架构迁移 |
| **v1.6** | 版权水印模块、嵌入强度滑块、实时容量预览、摄像头扫描 |
| **v1.5** | DCT-QIM 频域隐写、双模式嵌入、自动模式检测、PBKDF2 加固 |
| **v1.1** | App Store 首发、LSB 隐写 + AES-256-GCM + 社交媒体模板 |
| **v1.0** | 初始版本，图片隐写加密应用 |

> 完整日志请参阅 [CHANGELOG.md](CHANGELOG.md)

---

## 🛠 技术栈

<p>
  <img src="https://img.shields.io/badge/SwiftUI-f05138?logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/CryptoKit-000?logo=apple&logoColor=white" alt="CryptoKit" />
  <img src="https://img.shields.io/badge/AVFoundation-000?logo=apple&logoColor=white" alt="AVFoundation" />
  <img src="https://img.shields.io/badge/CoreImage-000?logo=apple&logoColor=white" alt="CoreImage" />
  <img src="https://img.shields.io/badge/PHPhotoLibrary-000?logo=apple&logoColor=white" alt="PHPhotoLibrary" />
</p>

---

## 📄 许可

本项目基于 MIT 协议开源。详细信息请参见 [License](./LICENSE) 文件（如未提供则默认 MIT）。

---

<p align="center">
  用 ❤️ 和 Swift 构建<br />
  <sub>© 2026 ShaneStudio</sub>
</p>
