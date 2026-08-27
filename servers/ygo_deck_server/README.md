# ygo_deck_server

卡组云函数服务（Dart Frog）：把 packages/ygo_deck_mycard 的 IDeckService
六能力暴露为 HTTP API。纯 Dart，零 Flutter 依赖，独立于 Flutter workspace。

## 端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /decks | 卡组列表 |
| POST | /decks | 保存卡组（body=卡组 JSON，deckName 为 key） |
| GET | /decks/:key | 卡组详情（不存在 404） |
| PUT | /decks/:key | 保存卡组（路径 key 为权威名） |
| DELETE | /decks/:key | 删除（不存在 404） |
| GET | /decks/:key/ydk | 导出 YDK（text/plain） |
| POST | /decks/:key/ydk | 导入 YDK 纯文本并保存，返回卡组 JSON |

卡组 JSON 与 packages/ygo_data DeckInfo 结构一致；存储文件
（data/decks/{deckName}.json）与 ygo_deck_mycard DeckService.saveDeck 的
写入格式完全一致，本地 ↔ 云端可直接互通。

## 运行

```bash
dart_frog dev                                  # 开发（默认 8080）
dart_frog build && dart build/bin/server.dart  # 生产（PORT 环境变量）
DECK_DATA_DIR=/path/to/decks dart_frog dev     # 覆盖存储目录（默认 data/decks）
dart test                                      # 测试
```

## 部署到 Cloud Run

```bash
# 前置：brew install --cask google-cloud-sdk && gcloud auth login
export GCP_PROJECT_ID=<你的 GCP 项目 ID>
./deploy_cloud_run.sh                     # 临时存储（演示可用，实例回收数据丢失）
DECK_BUCKET=<你的 GCS bucket> ./deploy_cloud_run.sh   # 挂载 bucket 持久化卡组
```

脚本流程：`dart_frog build`（生成含 Dockerfile 的 build/）→ 启用 run/cloudbuild/
artifactregistry API → `gcloud run deploy --source .`（Cloud Build 用 Dockerfile 构建镜像并部署）。

注意事项：
- **持久化**：Cloud Run 容器文件系统是临时的，不挂 `DECK_BUCKET`（GCS FUSE 卷）
  卡组数据会随实例回收丢失；挂载后数据落在 bucket 的 `*.json` 对象里。
- **鉴权**：脚本默认 `--allow-unauthenticated`（公网可读写）。本服务当前无鉴权，
  公网部署前请评估风险：收紧 IAM（去掉该参数）或先给服务加 token 中间件。
- **区域**：默认 `asia-east1`（香港），用 `GCP_REGION` 覆盖。
- 服务监听 `PORT` 环境变量（默认 8080），与 Cloud Run 注入的端口天然兼容。
