# TGLite Windows x64

基于 Unigram 的个人使用版 Telegram Windows 客户端。

## 功能

- 关闭聊天、频道及视频播放器中的赞助消息展示。
- 减少 Telegram Premium 订阅推广、赠送及购买界面。
- 保留普通聊天、群组、频道、媒体、文件以及 Stars 礼物相关功能。

## 安装

下载 `.msixbundle`、`TGLite-Signing-Certificate.cer` 和 `TGLite-Root-CA.cer`。核对 SHA-256 后，将签名证书添加到 Windows 的“受信任的人”证书存储区，将签发机构证书添加到“受信任的根证书颁发机构”证书存储区，然后安装 MSIXBundle。安装私有根证书会使系统信任该机构签发的其他证书，请仅在确认这是自己管理的证书后操作。

该安装包包含自己申请的 Telegram API 应用凭据；没有配置账号会话信息。

本版为早期自用测试版本。GitHub Actions 会检查 TDLib 本机接口、安装包签名、Windows 安装以及程序启动，并独立记录 Telegram 测试服务器登录和消息收发的实际结果。实际 Windows 界面操作、个人账号登录、通话、媒体传输与长期使用仍需人工测试。具体结果记录于 `TEST-RESULTS.json`。

构建版本信息及 GitHub Actions 运行地址记录在 `BUILD-INFO.json`。
