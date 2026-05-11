# Yulyph v1.6 — 版权水印功能 + UI 重构设计

## 1. 概述

在 Yulyph 中新增版权水印模块，支持摄影师在图片中嵌入不可见版权信息，并通过摄像头扫描识别含水印的图片。同步重构首页 UI，采用 Segmented Picker 切换「隐藏」/「版权」两大模块。

---

## 2. UI 重构

### 2.1 首页结构

在 `HomeView` 顶部新增 Segmented Picker，切换「隐藏」和「版权」两个模块：

```
[ 隐藏 🔒 ]  [ 版权 📷 ]
```

两个模块均展示 2×2 功能卡片，底部保留「模版库」和「最近活动」。

| 模块 | 卡片 1 | 卡片 2 |
|------|--------|--------|
| 隐藏 | 嵌入信息 | 提取信息 |
| 版权 | 标记版权 | 扫描识别 |

### 2.2 版权模块页面

- **标记版权** → `CopyrightEmbedView`
- **扫描识别** → `CopyrightScanView`

---

## 3. 功能详细设计

### 3.1 版权元数据格式

```json
{"c":"创作者名称","y":2026,"l":"CC-BY"}
```

| 字段 | 含义 | 示例 |
|------|------|------|
| c | Creator，创作者 | 张三 |
| y | Year，年份 | 2026 |
| l | License，许可证 | CC-BY / CC-BY-SA / ARR |

大小约 30-50 bytes，单个 8×8 块即可承载。

### 3.2 标记版权（CopyrightEmbedView）

**输入字段：**
- 创作者名称（必填，最多 50 字符）
- 版权年份（必填，默认当前年）
- 许可证类型（必填，下拉选择：CC-BY / CC-BY-SA / All Rights Reserved / 自定义）
- 可选密钥（留空=公开版权；填密钥=私有版权，需密钥才能识别）

**流程：**
1. 构建 JSON 元数据
2. 如填写密钥 → 用 CryptoService 加密；否则明文
3. 选图（支持 PHPicker 多选）
4. 对每张图调用 `embedCopyright(data:into:strength:)` → 嵌入 DCT-QIM
5. 保存/分享

### 3.3 扫描识别（CopyrightScanView）

**两种模式，通过 Tab 切换：**
- 摄像头实时扫描
- 从相册选择图片批量检测

**摄像头模式：**
- 使用 `AVCaptureSession` 捕获视频帧
- 每帧做 DCT 检测（仅检测第一个 8×8 块）
- 检测到水印 → 在画面上叠加绿色边框 + 底部弹出创作者信息
- 识别结果自动记录到「最近活动」

**相册模式：**
- 使用 `PHPicker` 多选图片
- 批量检测，显示结果列表
- 每项：图片缩略图 + 创作者 + 年份 + 许可证 + 识别时间

**检测逻辑：**
- 尝试用 `StegoMode.copyright` 版本字节 `0x02` 提取
- 读取 strength 索引 → 获取 delta → 提取完整元数据
- 尝试解密（如果元数据被加密）
- 返回 `CopyrightInfo` 结构：creator / year / license / isPublic

### 3.4 StegoMode 扩展

```swift
enum StegoMode: UInt8 {
    case lsb = 0x00
    case dct = 0x01
    case copyright = 0x02  // 新增
}
```

### 3.5 Header 格式

| 模式 | 版本 | Strength | 长度 | Magic | 总字节 |
|------|------|----------|------|-------|--------|
| LSB | 1 | — | 4 | 4 | 9 |
| DCT | 1 | 1 | 4 | 4 | 10 |
| Copyright | 1 | 1 | 4 | 4 | 10 |

### 3.6 嵌入实现

```swift
// StegoService
func embedCopyright(data: Data, into image: UIImage, strength: StrengthLevel? = nil) throws -> UIImage
func extractCopyright(from image: UIImage) throws -> CopyrightInfo
```

`embedCopyright` 调用现有的 `embedDCT`，使用 `StegoMode.copyright` 版本字节。元数据加密可选（用户填密钥时加密）。

`extractCopyright` 调用现有的 `extractDCT` 读取数据，然后：
- 尝试 JSON 解析（公开版权）
- 失败则尝试用用户提供的密钥解密（私有版权）
- 返回 `CopyrightInfo` 或抛错

### 3.7 CopyrightInfo 模型

```swift
struct CopyrightInfo: Codable {
    let creator: String
    let year: Int
    let license: String
    let isPublic: Bool  // true=无密钥，false=私有
    let imageName: String?
    let detectedAt: Date
}
```

---

## 4. 依赖和权限

- **摄像头权限**：`NSCameraUsageDescription` — "用于扫描识别图片中的版权水印"
- **相册读取权限**：`NSPhotoLibraryUsageDescription` — "用于选择图片嵌入或检测版权水印"
- 相册写入权限：复用现有 `NSPhotoLibraryAddUsageDescription`

---

## 5. 文件变更清单

### 新增文件
- `Yulyph/Views/CopyrightEmbedView.swift` — 标记版权页面
- `Yulyph/Views/CopyrightScanView.swift` — 扫描识别页面
- `Yulyph/Models/CopyrightInfo.swift` — 版权信息模型

### 修改文件
- `Yulyph/Views/HomeView.swift` — 新增 Segmented Picker + 版权模块卡片
- `Yulyph/Services/StegoService.swift` — 新增 embedCopyright / extractCopyright / StegoMode.copyright

### Info.plist
- 添加 `NSCameraUsageDescription`

---

## 6. 实现顺序

1. `StegoMode.copyright` + `embedCopyright` + `extractCopyright`
2. `CopyrightInfo` 模型
3. `CopyrightEmbedView`（标记版权）
4. `CopyrightScanView`（扫描识别）
5. `HomeView` UI 重构 + Segmented Picker
6. Info.plist 权限配置
