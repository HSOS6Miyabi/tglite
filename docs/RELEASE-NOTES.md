# TGLite Windows x64

基于 Unigram 的个人使用版 Telegram Windows 客户端。

## 功能

- 关闭聊天、频道及视频播放器中的赞助消息展示。
- 减少 Telegram Premium 订阅推广、赠送及购买界面。
- 保留普通聊天、群组、频道、媒体、文件以及 Stars 礼物相关功能。

## 安装

下载 `.msixbundle` 安装包及 `TGLite-Signing-Certificate.cer` 公共证书。对于自签名证书，在 Windows 中安装并信任公开证书后，再安装 MSIXBundle。请先检查 SHA-256 校验和。

该安装包包含自己申请的 Telegram API 应用凭据；没有配置账号会话信息。

本版为早期自用测试版本。首次安装请特别检查登录、收发消息、音视频和文件功能。

构建版本信息及 GitHub Actions 运行地址记录在 `BUILD-INFO.json`。
