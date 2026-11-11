# 选题与严格语义查重

检索日期：2026-11-11。按本地 moonbit-hackathon-builder 与 osc2026-guide 的 Project Research Guide 实际检索，先比较三个不同问题域，再实现、在发布前反向复核。本记录不是官方立项或查重认证。

## 需求依据与候选

| 候选 | 真实任务与成熟基线 | 完整核心/客观验收 | 决策 |
| --- | --- | --- | --- |
| 生存分析 | 研究分析者从删失记录计算生存曲线；Kaplan–Meier 等已有成熟方法 | 删失模型、估计、区间、表格；对照已知数值 | Lyl66655/moon-survival 与 wcx789ll/moon-reliability 已直接覆盖，硬失败 |
| 流式概率 sketches | 遥测系统对大规模流估计基数/频数；HLL/CountMin 为成熟算法 | 合并、序列化、误差与确定性对照 | hiroyannnn/sketch 已实现 HLL，当前候选直接重合，硬失败 |
| C3D 数据交换 | 采集/整理/分析工具在文件与同步点、模拟信号之间交换；C3D 格式与 py-c3d 为成熟基线 | 有界解析、参数/校准、规范写出、编辑、CSV；独立双向对照和三个集成例子 | 实际检查范围内未发现成熟直接替代，选用 |

评分 1–5，越高越适合本次交付；重合安全分越高表示风险越低。评分是工程判断，硬失败不能由总分抵消。

| 候选 | 生态广度 | 用户多样性 | 复用 | 重合安全 | 深度 | 可验证 | 工期可控 | 可维护 | 合计 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 生存分析 | 4 | 4 | 5 | 1 | 5 | 5 | 4 | 4 | 32，淘汰 |
| 概率 sketches | 5 | 4 | 5 | 1 | 4 | 5 | 5 | 4 | 33，淘汰 |
| C3D 交换 | 4 | 4 | 5 | 4 | 5 | 5 | 4 | 4 | 35，选用 |

已知事实：C3D 有公开格式文档，py-c3d 有真实读写器和测试，本地已运行固定实现的六组独立兼容对照。合理推断：MoonBit 数据工具可减少跨语言桥接及重复校准/打包逻辑。未验证假设：具体机构采用率、设备分布和真实性能收益；没有宣称访谈过用户。

## 最终能力指纹与三条闭环

核心输入是带参数块的二进制 C3D，数据模型为分组类型参数、点残差/相机位、同步模拟子帧及校准。输出为校准 Trial、规范 Intel float C3D、时间序列与长表 CSV。通过 Bytes API 与版本 JSON 协议复用，不依赖 GUI 或特定厂商。

1. 采集软件开发者将 Intel/MIPS C3D 交给 inspect/read，核对布局与采样关系，得到校准点/模拟序列和缺失摘要；examples/ingest 验证。
2. 数据整理者按帧裁剪、选通道、换算单位并写回，用 read 验证帧号、标签和模拟样本；examples/edit 验证。
3. 数据分析系统作者从 Trial 生成带时间戳 CSV、轨迹和质量统计，直接交给表格/绘图系统；examples/export 验证。

完成标准是这些流程、格式边界与独立兼容性检查均可运行；不是累计 API/行数。不做骨架 BVH、力台 DSP、临床解释、完整厂商扩展、DEC 数值或超 16 位帧号。参考基线为 https://www.c3d.org/HTML/default.htm 和 https://github.com/EmbodiedCognition/py-c3d ，后者固定提交及许可见 THIRD_PARTY.md。

## 实际搜索范围

MoonCakes 使用 moon search、每词 --limit 100，查询 C3D/c3d、motion-capture、biomechanics、mocap、Vicon、bvh、TRC、ezc3d、运动捕捉、marker-trajectories、analog-calibration、point-residual、read_frames、write_frames；备选查询 survival/kaplan/lifelines/censor/Nelson-Aalen/生存分析及 hyperloglog/CountMinSketch。检查返回包详情和关联源仓库。read_frames/write_frames 触及 100 上限，不能据此声称穷尽。

GitHub 检查 MoonBit C3D/mocap 代码与比赛方向、MoonBit 官方 awesome 清单、相关项目 README/树/源码/测试/生成接口；项目名称相近与否不作为决定依据。forceplate 的 C3D code search 返回 0 但 incomplete_results=true，明确不作为不存在证明。

本地共享注册表检索已预留、已交付、淘汰及 external-checked 指纹；实现前以共享排他锁原子预留 MoonC3D，发布前再次检查新增相关记录，未发现另一完整 C3D 交换能力预留。大量无关关键词结果不作为逐一源码审计的声明。

## 邻近项目逐项比较

| 项目与证据 | 用户/输入/行为/输出 | 分类、状态与独立建设理由 |
| --- | --- | --- |
| [moonbvhkit 0.2.0](https://github.com/zhangbowen2006/MoonBVHKit)：实际 parser、motion_tools_test、接口、README | 骨架动作开发者；ASCII BVH hierarchy/channels；解析、姿态与重定向；骨架/动作 | 高度相邻运动数据，核心格式与模型不同；C3D 的二进制参数、校准模拟流及写出不宜混入骨架工具 |
| [moonbit_forceplate 0.1.1](https://github.com/hnriiuu/moonbit-forceplate)：README、源树及 export/csv_json.mbt 实际源码 | 生物力学分析者；ForceTrial；COP/CMJ 与 CSV/JSON；分析结果 | 同领域不同功能；其 CSV/JSON 并非 C3D codec。交换层可被力台库调用，独立规范层优于加入临床/力学算法 |
| [moon-survival 0.2.4](https://github.com/Lyl66655/moon-survival)：实际 Kaplan–Meier 实现、测试、文档 | 删失记录->生存估计 | 对生存候选直接重合，淘汰；与最终二进制交换无实质重合 |
| [sketch 0.2.0](https://github.com/hiroyannnn/sketch)：实际 HLL 实现、测试及模块详情 | 数据流->概率统计状态/估计 | 对 sketches 候选直接重合，淘汰；不借换包名规避 |
| moonmcap 0.17.5（LilaLola67）：检索发现的描述/元数据 | 通用机器人日志容器 | 相邻格式发现，未完整源码审计，不宣称全面排除其内部所有功能；C3D 参数/采样校准任务有独立标准 |

版本是检索快照，不代表最新或持续维护保证。前两项有发布包及可读源，本次未把未核查的维护/下载指标写成评判数字。

## 交付前反向复核

2026-11-11 在独立无凭据 Moon Home 再检索 C3D、ezc3d、C3D biomechanics，均返回 No modules found；analog-calibration 返回 1 个 MCU HAL 模糊结果；decode_point_record 返回 52 个跨格式模糊结果。没有把后两者说成 0，也没有声称逐一精审全部 52 包。已检查的核心近邻区别仍成立，注册表未出现另一个 C3D 完整交换实现。

结论：在本次已记录来源、版本、接口及源码检查范围内，未发现可直接替代所交付核心的成熟 MoonBit 项目。搜索索引、源码可见性和结果上限有边界；不保证绝对唯一或官方审核通过。原始公开检索结果与 API 快照保存在本次本地交付证据目录，公开文档只保留可复核的来源与决策。
