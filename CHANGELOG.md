# Changelog

## v1.6 (开发中)

### 新增功能

- **版权水印模块** — 在图片中嵌入不可见版权信息，支持创作者、年份、许可证类型
- **版权扫描识别** — 支持摄像头实时扫描和相册批量检测含版权水印的图片
- **嵌入强度滑块** — DCT 模式支持 4 档强度调节（精细/标准/增强/最强）
- **实时容量预览** — 嵌入前实时显示图片容量和消息大小对比

### UI 重构

- **首页 Tab 切换** — Segmented Picker 切换「隐藏」和「版权」两大模块
- **最近活动功能** — 记录并展示最近 10 条嵌入/提取操作
- **保存并分享** — ResultView 合并保存和分享为一键操作

### 技术改进

- **QIM 算法重写** — 使用标准 QIM 公式，提升鲁棒性
- **DCT 两阶段嵌入** — header 用固定 delta，数据用用户指定 delta
- **版权元数据格式** — JSON 格式 {c:creator, y:year, l:license}

## v1.5 (2026-05-09)

### 新增功能

- **频域 DCT-QIM 水印算法** — 全新的抗压缩嵌入模式，基于离散余弦变换 + 量化索引调制，可抵御 JPEG quality 50+ 压缩，适合社交媒体传输
- **双模式嵌入** — 用户可在「抗压缩模式」(DCT-QIM) 和「高容量模式」(LSB) 之间自由选择
- **自动模式检测** — 提取时系统自动识别编码模式（DCT/LSB/旧版），完全向后兼容
- **Header 版本字节** — 新增 1 字节版本标识，区分不同编码格式

### Bug 修复

- 修复 stride 边界错误导致图片边缘像素数据丢失（StegoService 3 处）
- 修复 normalizeOrientation 引入 alpha 通道导致像素格式不匹配
- 修复 Header 使用主机字节序的跨平台兼容性问题（改为 bigEndian）
- 修复 FECService.tryCorrect 始终返回 nil 的问题（实现单字节纠错）
- 修复 FEC 开关为死代码的问题（接入 embed/extract 管线）
- 修复 SettingsView 设置不持久化的问题（改用 @AppStorage）
- 修复硬编码版本号问题（改为读取 Bundle）

### 安全改进

- 密钥派生从 HKDF 改为 PBKDF2（100,000 迭代），大幅提升抗暴力破解能力
- 每次加密随机生成 16 字节 salt，消除跨用户彩虹表攻击风险
- Salt 前置于密文，解密时自动提取

### UI 美化

- 新增渐变预设系统（ThemeGradient）— primary/hero/warmSunset/ocean/tipCard
- 新增阴影预设系统（ThemeShadow）— card/elevated/blueGlow
- 新增动画预设系统（ThemeAnimation）— spring/springBouncy/easeOut/easeInOut
- 新增 CardStyle ViewModifier 统一卡片样式
- HomeView 入场动画（渐入 + 上移）
- 核心功能卡片使用渐变图标背景
- 嵌入模式选择器 UI（抗压缩 / 高容量）
- 统一圆角和阴影风格

### 其他

- 新增 .gitignore 排除构建产物和缓存文件
- 版本号更新至 1.5 (Build 3)

---

## v1.1 (2026-04-08)

- 初始 App Store 发布版本

## v1.0 (2026-03-28)

- Yulyph 初始版本 — 图片隐写加密应用
- LSB 空间域隐写术
- AES-256-GCM 加密
- XOR 校验纠错
- 小红书/社交媒体海报模板
- 相框模板
- 多语言支持（中文/英文）
- 隐私政策
