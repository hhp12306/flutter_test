# DIWeb H5 性能优化参考（索引）

> 完整文档已按公司 skill 结构重组，请优先阅读 Skill 目录。

## 文档位置

| 文件 | 用途 |
|------|------|
| [.cursor/skills/harmony-flutter-diweb/SKILL.md](../.cursor/skills/harmony-flutter-diweb/SKILL.md) | **Cursor Skill 入口**（精简版 + 比对流程） |
| [.cursor/skills/harmony-flutter-diweb/harmony-flutter-diweb-optimization-analysis.md](../.cursor/skills/harmony-flutter-diweb/harmony-flutter-diweb-optimization-analysis.md) | **完整方案**（架构、瓶颈、分阶段优化、公司对照） |

## 给公司 AI 的提示词

```
阅读 harmony-flutter-diweb skill 及 harmony-flutter-diweb-optimization-analysis.md，
对照本仓库 Flutter→H5 实现，输出架构差异表、迁移 P0/P1/P2 清单、性能预期。
参考 Demo 实测：原生 ~8–60ms，远程 HTML ~300–800ms+。
```

## 快速结论

- **Demo 已做**：Overlay 单 WebView、预热、Bridge 分档、URL 遮罩、错误过滤、加载监控
- **Demo 待做 (P1)**：默认 bridge 改 community、Index 提前预热、各 Tab 显式传档
- **公司建议 (P1)**：WebViewPool + Bridge 分档 + URL 遮罩（不必一步到位 Overlay）
- **共同瓶颈**：远程 HTML 网络，需 H5/CDN 配合
