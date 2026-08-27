#!/usr/bin/env bash
# ygo_deck_server → Google Cloud Run 一键部署
#
# 前置：
#   1. 安装 gcloud CLI（brew install --cask google-cloud-sdk）
#   2. gcloud auth login
#   3. export GCP_PROJECT_ID=<你的 GCP 项目 ID>
#
# 可选环境变量：
#   GCP_REGION     部署区域（默认 asia-east1，香港）
#   SERVICE_NAME   Cloud Run 服务名（默认 ygo-deck-server）
#   DECK_BUCKET    GCS bucket 名——设置后挂载到 /app/data/decks 做卡组持久化
#                  （不设置则数据存容器临时文件系统，实例回收即丢失）
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?请先 export GCP_PROJECT_ID=<GCP 项目 ID>}"
REGION="${GCP_REGION:-asia-east1}"
SERVICE="${SERVICE_NAME:-ygo-deck-server}"
BUCKET="${DECK_BUCKET:-}"

echo "==> 1/4 dart_frog 生产构建（生成含 Dockerfile 的 build/）"
dart_frog build

echo "==> 2/4 启用必要的 GCP API（重复执行无副作用）"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT_ID"

echo "==> 3/4 部署到 Cloud Run（Cloud Build 用 build/Dockerfile 构建镜像）"
DEPLOY_ARGS=(
  --source .
  --region "$REGION"
  --project "$PROJECT_ID"
  # 公网可访问；本服务当前无鉴权，公网部署意味着任何人可读写卡组。
  # 如需收紧：去掉本行，改用 IAM 调用或先给服务加 token 中间件。
  --allow-unauthenticated
)
if [[ -n "$BUCKET" ]]; then
  echo "    挂载 GCS bucket: $BUCKET -> /app/data/decks（卡组持久化）"
  DEPLOY_ARGS+=(
    --add-volume "name=decks,type=cloud-storage,bucket=$BUCKET"
    --add-volume-mount "volume=decks,mount-path=/app/data/decks"
    --set-env-vars "DECK_DATA_DIR=/app/data/decks"
  )
else
  echo "    ⚠ 未设置 DECK_BUCKET —— 卡组数据存容器临时文件系统，实例回收即丢失"
fi

cd build
gcloud run deploy "$SERVICE" "${DEPLOY_ARGS[@]}"

echo "==> 4/4 完成，服务地址："
gcloud run services describe "$SERVICE" \
  --region "$REGION" --project "$PROJECT_ID" \
  --format='value(status.url)'
