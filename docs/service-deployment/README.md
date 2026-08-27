# 服务部署方案调研（免费 / 付费）

> 调研时间：2026-08 · 适用对象：uniygopro 项目后端服务（账号/房间/匹配/战绩等 API、管理后台）
> 目标：对比主流的无服务器 / PaaS / 自托管部署方案，给出免费起步与付费上量的完整路径。

---

## 一、结论速览（TL;DR）

| 需求 | 推荐方案（免费起步） | 上量后（付费） |
|---|---|---|
| 无状态 API / BFF / 鉴权网关 | **Cloudflare Workers 免费版**（10 万请求/天） | Workers Paid **$5/月** |
| 带数据库的后端（关系型） | **Cloudflare D1 / 阿里云 FC 免费额度** | D1 付费 / 云数据库 |
| 前端 + 全栈托管 | **Vercel Hobby / Cloudflare Pages**（免费） | Vercel Pro **$20/月** |
| 长驻进程 / WebSocket 实时服务 | **Fly.io / Railway 试用额度** | 按用量计费（约 **$1~7/月** 起） |
| 国内合规 / 低延迟 | **阿里云 FC 或轻量服务器**（备案） | 资源包 / 轻量 ¥50~100/月 |
| 纯静态站 / 文档 | **GitHub Pages / Cloudflare Pages**（免费） | —（几乎无需付费） |

**一句话**：新项目先 Workers/Vercel/Pages 免费额度跑通，流量起来再按需升级付费；有实时长连接需求再引入 Fly.io/Railway；国内用户多则考虑阿里云/腾讯云。

---

## 二、方案全景对比表

### 2.1 海外 Serverless / PaaS

| 平台 | 免费额度 | 付费价格 | 特点 | 适合 |
|---|---|---|---|---|
| **Cloudflare Workers** | 10 万请求/天、10ms CPU/请求、128MB 内存、100 个 Worker、3MB 打包 | **$5/月**（无请求限制、CPU 5min） | 边缘计算、全球 330+ 节点、冷启动极快；配套 KV / D1 / R2 / Durable Objects | 无状态 API、BFF、鉴权、网关、静态托管 |
| **Vercel** | Hobby：Functions 4h Active CPU/月、100GB 带宽、静态托管免费 | **Pro $20/月**（含更多用量额度） | Next.js 原生、Git 自动部署、Preview URL | 前端/全栈（尤其 Next.js）、个人站点 |
| **Cloudflare Pages** | 无限静态请求、500 次构建/月、Functions 10 万/天 | 随 Workers Paid 升级 | 与 Workers 同生态，Pages Functions 可写后端 | 静态站 + 轻后端 |
| **Netlify** | 免费版 100GB 带宽、300 构建分钟/月、Functions 12.5 万次/月 | Pro 起 **约 $19/月**（credit-based 新计划） | 老牌静态托管 + 表单/身份 | 静态站、营销页 |
| **Render** | Hobby：Web Service 免费（**空闲休眠**）、512MB 内存 | Pro **$25/月** + compute 按量 | 传统 PaaS、支持 Docker、Postgres 托管 | 常驻 Web 服务、数据库 |
| **Railway** | 30 天试用 **$5 额度**（无需信用卡） | 按用量：内存 $0.00000386/GB·s、CPU $0.00000772/vCPU·s、流量 $0.05/GB；Hobby 起 **$1/月** | 按秒计费、部署简单、模板多 | 试用探索、小规模常驻服务 |
| **Fly.io** | 需绑信用卡；曾有免费额度（现政策收紧，按组织用量计费） | 按用量（shared-cpu 起步约 **$2~3/月**） | 全球 Anycast、Fly Machines、原生支持 WebSocket/长连接 | **实时服务、WebSocket、游戏服务器** |

### 2.2 国内云厂商

| 平台 | 免费额度 | 付费价格 | 特点 | 适合 |
|---|---|---|---|---|
| **阿里云函数计算 FC** | 新用户免费试用额度（有每月免费调用量/资源额度，见官方页） | CU 计费 + 资源包，小额项目约 **几元~几十元/月** | 国内节点低延迟、事件驱动、免运维 | 国内 API、定时任务 |
| **腾讯云云函数 SCF** | **已取消免费额度**（2022 年起），最低需购资源包 | 基础资源包 **约 ¥12.8/月起** | 生态与微信/小程序打通 | 微信小程序后端 |
| **阿里云/腾讯云轻量服务器** | 无免费（新用户常 1~3 折促销） | **¥50~100/月**（2C2G 级别） | 完整 Linux 环境、可部署任意语言/数据库/WebSocket | 需要完全掌控、常驻进程 |
| **国内静态托管**（阿里 OSS+CDN 等） | OSS 有少量免费额度 | 按量，个人站约几元/月 | 需 ICP 备案（大陆节点） | 静态站（已备案域名） |

> ⚠️ **国内节点硬性要求**：使用大陆机房部署服务/网站必须 **ICP 备案**（免费但需 1~2 周，需域名 + 服务器）；域名也已要求实名。若不想备案可用香港/海外节点（Cloudflare/Vercel 等）。

### 2.3 数据库 / 存储配套（免费→付费）

| 服务 | 免费额度 | 付费 | 适合 |
|---|---|---|---|
| **Cloudflare D1**（SQLite） | 5GB 数据库、500 万行读/天、10 万行写/天 | 按量，极低 | Workers 配套关系型 |
| **Cloudflare KV** | 10 万读/天、1000 写/天 | 按量 | 键值缓存、配置 |
| **Cloudflare R2** | 10GB 存储、免费流出流量 | $0.015/GB·月 | 文件/静态资源 |
| **Neon**（Postgres） | 0.5GB 存储、190 小时计算/月 | 约 **$19/月** 起 | 服务端 Postgres |
| **Supabase**（Postgres） | 500MB 数据库、50K MAU | **$25/月** 起 | 带 Auth/Storage 的一站式 BaaS |
| **Railway Postgres** | 含在试用额度 | 按用量 | Railway 生态 |

---

## 三、分场景详细评估

### 3.1 Cloudflare Workers（最推荐的无状态后端）

**免费版限制**（来源：[官方 Limits](https://developers.cloudflare.com/workers/platform/limits/)）：
- 请求：10 万/天（UTC 重置）
- CPU：**10ms/请求**（网络等待不计入）
- 内存 128MB、Worker 打包 ≤3MB、100 个 Worker
- 子请求 50/请求、并发出站连接 6
- WebSocket：支持但受 CPU 预算限制，**不适合长时间保持的对战连接**

**付费版 $5/月**：无请求限制、CPU 5min/请求、500 个 Worker、10MB 打包、Cron 250 个。

**优点**：免费额度慷慨、全球边缘、零冷启动、生态完善（D1/KV/R2/DO/静态托管）。
**缺点**：10ms CPU 对重计算不友好；WebSocket 长连接受限；国内访问受网络环境影响（可用自有域名 + 优选 IP 改善）。

> 对本项目：MyCard 账号/密钥接口、房间 ID 派生校验、战绩查询这类**短请求 API 非常适合**；实时对战不建议。

### 3.2 Vercel / Netlify / Pages（前端 + 轻后端）

- **Vercel** Hobby 免费版即可支撑个人项目；Functions 有 4h CPU/月额度，够个人站；Pro $20/月。
- **Netlify** 新 credit-based 计费，免费版带宽 100GB，够用；Pro ~$19/月。
- **Cloudflare Pages** 免费版最慷慨（无限静态请求），Functions 额度与 Workers 共享。

### 3.3 Render / Railway / Fly.io（常驻进程与实时服务）

| | Render | Railway | Fly.io |
|---|---|---|---|
| 免费 | Web Service 空闲休眠 | 30 天 $5 试用 | 需信用卡，额度收紧 |
| 起步价 | Pro $25/月 | $1/月 Hobby | ~$2~3/月 shared-cpu |
| 常驻 | ✅ | ✅ | ✅ |
| WebSocket 长连接 | ✅ | ✅ | ✅（最佳，Anycast 全球） |
| 数据库 | 托管 Postgres | Postgres/MySQL | 无内置（可挂 Neon） |

**对实时对战场景**：Fly.io 的全球 Anycast + 原生 WebSocket 支持最适合游戏房间这类长连接服务；预算敏感可用 Railway 按量。

### 3.4 国内方案（阿里云 / 腾讯云）

- **函数计算 FC**：新用户有免费试用额度；按 CU 计费。适合国内 API 服务、定时任务（如每日战绩聚合）。
- **云函数 SCF**：免费额度已取消，最低 ¥12.8/月资源包；与微信生态打通是最大优势。
- **轻量服务器**：¥50~100/月 拿下 2C2G，可跑任意服务（含 YGOMobile 服务端、Docker），最灵活；需备案。

---

## 四、推荐落地路径（结合 uniygopro）

### 路径 A：纯海外免费（个人开发 / 验证）
1. **API 服务** → Cloudflare Workers 免费版（MyCard 账号、房间 ID、战绩接口）
2. **管理后台/前端** → Cloudflare Pages 或 Vercel Hobby
3. **数据库** → D1（关系型）+ KV（缓存）+ R2（资源）
4. **实时对战（如有）** → 暂用自有服务器；或 Fly.io 按量起步
5. **成本**：**$0**（域名除外，约 ¥50~80/年）

### 路径 B：国内合规（面向国内玩家）
1. **域名**：实名 + ICP 备案（免费，1~2 周）
2. **API 服务** → 阿里云 FC（免费额度内）或轻量服务器 ¥50~100/月
3. **静态/后台** → OSS + CDN（备案后）
4. **数据库** → 云数据库 RDS 基础版或自建（轻量服务器内）
5. **成本**：**¥0~100/月**（备案期间几乎为 0）

### 路径 C：混合（推荐，兼顾体验与成本）
- 海外 API（Cloudflare Workers 免费）处理非敏感逻辑
- 国内入口用轻量服务器 + 备案域名做代理/静态
- 实时对战放 Fly.io（按量）

---

## 五、参考资料

- Cloudflare Workers 限制与定价：https://developers.cloudflare.com/workers/platform/limits/ · https://developers.cloudflare.com/workers/platform/pricing/
- Vercel 定价：https://vercel.com/pricing · https://vercel.com/docs/plans/hobby
- Render 定价：https://render.com/pricing
- Railway 定价：https://railway.com/pricing · https://docs.railway.com/pricing/free-trial
- Fly.io 定价：https://fly.io/docs/about/pricing/
- Netlify 定价：https://www.netlify.com/pricing/
- 阿里云函数计算计费：https://help.aliyun.com/zh/functioncompute/billing-overview-of-fc
- 腾讯云云函数定价：https://buy.cloud.tencent.com/price/scf
- 关于 SCF 取消免费额度的讨论：https://www.zhihu.com/question/533580659

> ⚠️ 定价会随时间调整，付费前请以各平台官方页面为准。
