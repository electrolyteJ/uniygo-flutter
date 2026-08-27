# uniygopro

coding agent完成一个需求需要如下要素 
- 网络接口定义
- 设计稿(ui 、ux)
- 产品逻辑(玩法、业务)

## Getting Started

git submodule update --init --recursive
git clone --recursive git@github.com:ProjectIgnis/CardScripts.git

https://spacecraft-67664.web.app/

https://electrolytej.github.io/uniygo-flutter/

https://uniygopro.electrolytej.workers.dev/

## 代码生成（build_runner）

`*.g.dart` 已加入 .gitignore，**不要手写、不要提交**，一律由生成器产出。

含代码生成的包：
- `packages/biz`、`modules/deck_editor3` — riverpod_generator（`@riverpod` / `@Riverpod(keepAlive: true)`）
- `apps/uniygopro` — service_loader_gen

clone 后或修改注解代码后，在对应包目录执行：

```sh
dart run build_runner build   # 一次性生成
dart run build_runner watch   # 开发时持续监听
```

CI / 测试前同样需要先生成，否则 analyze 与编译会因缺少 part 文件失败。