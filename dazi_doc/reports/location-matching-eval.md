# 地点匹配评测摘要

最后更新：2026-06-05

## 1. 结论

当前推荐方案是 **规则/词典 + 区域知识 + 活动严格度 gate**。它比旧版 city-only 和纯文本向量更适合上线，因为地点相容性是强业务约束，不能只靠短文本相似度。

## 2. 已验证问题

旧版 city-only 的问题：

- 无法处理 `川西`、`江浙沪`、`珠三角`、`东京周边` 等区域表达。
- 无法理解 `四姑娘山`、`稻城亚丁`、`西湖` 等目的地和区域之间的包含关系。
- 对线上和不限地点表达不够稳定。

纯文本向量的问题：

- 容易把活动词相似误判成地点相容。
- 对地理包含关系缺乏可解释性。
- 最佳阈值在小样本上不稳定。

## 3. 当前评测结果

在地点解析与活动 pair 匹配用例上：

```text
Parse metrics
strategy                 exact   kind    place   city    region  scope
legacy_city_only         0.0357  0.0357  0.0357  0.7857  0.7143  0.0357
hybrid_rule_region       1.0000  1.0000  1.0000  1.0000  1.0000  1.0000

Match decision metrics
strategy                 acc     precision recall  f1      fp fn
legacy_city_only         0.7308  0.8571    0.7059  0.7742  2  5
full_text_ngram_vector   0.5769  0.7500    0.5294  0.6207  3  8
hybrid_rule_region       1.0000  1.0000    1.0000  1.0000  0  0
sentence_transformer     0.6538  0.6538    1.0000  0.7907  9  0
```

单字段 location 端到端实验中，Kimi 事件抽取整体可用，但线上/不限地点和“城市 + 地点可再约”的边界仍需产品规则兜底。

## 4. 上线判断

第一阶段上线不新增独立地点抽取链路，不引入地图 API。服务端从已入库的 `city`、`location`、`activity_type` 运行时计算地点相容性。

可以上线的理由：

- 可解释，可单测。
- 对严格本地活动有明确拦截。
- 对旅行/周边游支持区域包含。
- 不改变生产表结构，回滚成本低。

## 5. 复跑入口

相关实验和测试位于后端仓库：

```text
dazi-server/experiments/location_matching/
dazi-server/tests/test_event_location_vector_experiment.py
dazi-server/tests/test_location_policy.py
```

复跑前需要确认本地 Python 环境、sentence-transformers 和 Kimi key 配置在安全位置，不要写入文档。

