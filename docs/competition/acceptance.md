# 工程验收方法

本文件给出可复现方法，不代替赛事官方审核。精确发布提交的远端结果以相应 GitHub Actions 和 Release 为准。

| 要求 | 文件/可复现验证 |
| --- | --- |
| MoonBit 主要实现，编译器不低于 0.10.16 | 根 *.mbt、moon.mod；CI 固定 0.10.17+093cb8f9c 并打印版本 |
| 公开仓库与真实历史 | GitHub main、`git log --reverse`、`python scripts/audit.py` |
| 核心可用 | reader/writer/操作模块，三个 examples，独立兼容性脚本 |
| 完整中文 README | 根 README：目标、精确安装、完整可运行例子、API、命令、限制 |
| CI 检查/构建/测试 | .github/workflows/ci.yml 四后端矩阵，严格 warning gate |
| 可运行例子 | examples/ingest、edit、export，均含实际断言 |
| 核心测试 | 根 *_test.mbt、*_wbtest.mbt，共 33 个 test block |
| 实际包发布 | 精确 red6667/moonc3d@0.1.0 公开 manifest、源文件及干净外部消费者 |
| OSI 许可证/归属 | LICENSE（MIT）、THIRD_PARTY.md、保留 py-c3d MIT 许可证 |

## 测试语义

正常/错误路径包括二进制边界、linked parameter 偏移、字节序、浮点/整数点、packed residual/camera、signed/unsigned 模拟校准、头部与参数冲突、同步裁剪、通道顺序、单位/刚体变换、CSV 引号和缺失值、JSON 错误、残差可表示性和保留元数据。640 次单字节变异回归要求不 panic，不作为随机安全证明。

`python scripts/differential.py` 固定 py-c3d 提交、校验每个文件 SHA256，以六组合成 fixture 对比读取和独立反读。包含非默认通道/全局 scale、offset、采样比、缺失点和原始帧号；有效数值容差 1e-6。MIPS 来自 Python 转换，不等于真实硬件样本。`python scripts/cli_smoke.py` 实际启动 Node：4 个成功操作、3 个非法 JSON 请求、1 个缺参数，共 8 个进程结果，检查 JSON 与退出码。

## 源码量与提交审计

`scripts/audit.py` 只统计根非测试 *.mbt，排除 tests、examples、cmd、脚本、生成接口、文档、fixture。输出物理行及非空行。主要模块分别处理二进制、布局/参数、采样解码、写出、编辑、序列、质量、CSV 和宿主协议，不靠生成静态内容扩充。

历史按提交路径和差异人工复核：从有界二进制到规范写出、编辑、导出、独立验证、安全修复及 CI，每一步都有可区分工程作用。非空提交仅是自动筛查，不能机械视为有效提交。前 23 个提交均对应实际能力或回归修复；最终计数可从 audit 输出复现。

## 发布后验证

发布前执行全部本地严格门禁、文档快速开始、申报书与完整历史隐私扫描、真实 ZIP 内容清单；上传后要求相同提交的实际 CI 绿色，再创建匹配 tag/Release 和发布包。随后检查精确版本公开 manifest/README/源内容，并在无账号凭据、无旧依赖缓存的独立消费者目录执行精确安装、检查及运行。未完成这些不能报告全部交付完成。
