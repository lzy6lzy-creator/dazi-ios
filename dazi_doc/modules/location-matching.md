# 地点匹配设计

最后更新：2026-06-05

## 1. 背景

早期匹配只依赖 `city_normalized`，适合“上海 vs 上海市”这类城市归一化，但不适合真实活动表达：

- 商圈/地标：陆家嘴、武康路、箱根。
- 区域：川西、江浙沪、珠三角、东京周边。
- 旅行目的地：四姑娘山、稻城亚丁、西湖。
- 线上/不限地点：线上桌游、地点再约。

地点匹配的目标不是把所有输入强行归成城市，而是判断两个活动在当前活动类型下地点是否相容。

## 2. 当前选择

第一阶段采用 **规则/词典 + 活动严格度 + 轻量 fallback**：

- 不新增生产表字段。
- 不新增独立 Kimi 地点抽取链路。
- 运行时从 `city`、`location`、`activity_type` 构造地点理解。
- 用地点相容性参与候选过滤。

## 3. Place Profile

逻辑模型：

```text
place_raw: 原始地点表达
place_kind: city / region / landmark / neighborhood / venue / online / flexible / unknown
place_normalized: 归一化地点名
admin_city: 行政城市
admin_region: 大区、省域或跨城区域
geo_scope: none / local / city / regional / cross_city / travel / unknown
aliases: 可兼容地点
confidence: 0 到 1
```

该模型当前只在服务端运行时使用。

## 4. 活动严格度

| 严格度 | 活动 | 策略 |
| --- | --- | --- |
| strict | 吃饭、咖啡、酒吧、看展、健身、运动 | 地点必须高度相容 |
| medium | 电影、桌游、city walk、公园、逛街 | 同城或近区域优先 |
| loose | 徒步、旅行、自驾、露营、周边游 | 允许区域和目的地包含关系 |
| none | 线上、闲聊、游戏 | 忽略地理位置 |

## 5. 为什么不只用 embedding

短文本 embedding 容易把活动相似误判成地点相容，例如“上海咖啡”和“北京咖啡”。地点相容性有明确地理硬约束，必须有可解释规则兜底。

Embedding 可以辅助未知地点召回，但不能替代地点硬过滤。

## 6. 当前结论

本地实验显示，混合规则/区域方案在现有地点解析和 pair 匹配用例上明显优于 city-only 与纯文本向量方案。详情见 [地点匹配评测摘要](../reports/location-matching-eval.md)。

## 7. 后续路线

1. 扩充地点词典和别名，覆盖更多内测城市、商圈和旅行区域。
2. 增加线上真实误判样本回流，避免只优化人工构造集。
3. 如果未知地点占比升高，再引入地图 API 或 Kimi profile 作为离线/低频补全。
4. 正式上线前补 DB 集成测试，覆盖主动匹配和被动邀请中的地点过滤。

## 8. 相关代码

- `dazi-server/app/services/location_normalizer.py`
- `dazi-server/app/services/location_policy.py`
- `dazi-server/experiments/location_matching/`
- `dazi-server/tests/test_event_location_vector_experiment.py`
- `dazi-server/tests/test_location_policy.py`

