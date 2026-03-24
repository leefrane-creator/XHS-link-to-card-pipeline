# xhs-link-to-card-pipeline

把“链接 / 文档”转换成“小红书可发布素材包”：结构化摘要、系列 SVG 知识卡片、PNG 发布图、发布文案（标题/标签/简介/正文骨架/CTA）。

## About
这是一个 Codex Skill 仓库，用于把「链接/本地 Markdown」快速转成可直接发布的小红书资产包，并且内置 4 套风格预设（先选风格 → 再生成全套卡片）。

## 示例预览（4 种风格）
下面是同一主题在 4 种风格下的封面预览（用于“先选风格再制作”）：

| Cyber Dark（暗黑霓虹） | Editorial Paper（杂志纸感） |
|---|---|
| ![](assets/previews/openclaw_cc_preview_01_cyber_dark.png) | ![](assets/previews/openclaw_cc_preview_02_editorial_paper.png) |

| Swiss Minimal（瑞士极简） | Bold Gradient Poster（大胆渐变海报） |
|---|---|
| ![](assets/previews/openclaw_cc_preview_03_swiss_minimal.png) | ![](assets/previews/openclaw_cc_preview_04_bold_gradient.png) |

## Demo（界面截图嵌入卡片）
原始操作界面截图：

![](assets/demo/openclaw_control_center_ui.jpg)

嵌入到封面卡片中的效果示例（自动铺满无留白）：

![](assets/demo/demo_card_embed_example.png)

## 目录说明
- `SKILL.md`：Skill 工作流与卡片规范（包含“先选风格”与“满铺无留白”要求）
- `agents/openai.yaml`：Codex Skill 元信息
- `scripts/convert_svg_to_png.ps1`：SVG → PNG（强制输出 `1242x1660`，避免留白/黑边）

## 本地转换（SVG → PNG）
在包含 `.svg` 的目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/convert_svg_to_png.ps1
```

默认输出到 `png_output/`。
