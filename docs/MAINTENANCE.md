# TGLite 上游更新与维护记录

## 当前版本来源

- 上游仓库：[UnigramDev/Unigram](https://github.com/UnigramDev/Unigram)
- 上游分支：`develop`
- 当前采用的上游提交：`a0a837159005b2d93dbee6416e81095f724d3d9b`
- 上游版本文件：`scripts/upstream-ref.txt`
- TGLite 分支：`main`
- 使用许可：GNU GPL v3（保留上游许可与版权信息）
- Windows 构建：Visual Studio 2026、WinUI 3、x64
- 签名来源：GitHub Actions 仓库 Secret `PFX`；可选 `PFX_PASSWORD`。

## 个人版本修改范围

| 模块 | 维护目标 | 关键文件 |
| --- | --- | --- |
| 聊天广告 | 取消获取频道与机器人赞助消息，取消界面显示 | `Telegram/ViewModels/DialogViewModel.cs`、`Telegram/Controls/Chats/ChatHistoryView.cs` |
| 视频广告 | 取消请求和播放器中的广告展示 | `Telegram/ViewModels/Chats/ChatGalleryViewModel.cs` |
| 广告视图 | 保持广告界面隐藏 | `Telegram/Controls/Chats/ChatSponsoredHeader.xaml.cs`、`Telegram/Controls/Gallery/GallerySponsoredContent.xaml.cs` |
| 聊天内容 | 不创建赞助消息显示组件 | `Telegram/Controls/Messages/MessageBubble.xaml.cs` |
| Premium 展示 | 移除推广入口、赠送会员界面及相关提示 | `Telegram/Common/TLNavigationService.cs`、`Telegram/Controls/ToastPopup.cs`、`Telegram/Views/SettingsPage.xaml` |
| 个人资料 | 保留常规资料功能并关闭会员购买推广 | `Telegram/ViewModels/ProfileViewModel.cs`、`Telegram/Controls/Chats/ChatAccountInfoHeader.xaml.cs` |
| 礼物 | 保留 Stars 礼物，去除 Premium 购买入口 | `Telegram/Views/Premium/Popups/GiftPopup.xaml.cs` |
| 消息编辑与聊天摘要 | 使用已有的日期选择窗口，并显示消息转发与回复标识 | `Telegram/Controls/FormattedTextBox.cs`、`Telegram/Controls/Cells/ChatCell.xaml.cs` |
| 安装包 | 使用专属安装包名称以及用户提供的 PFX 证书 | `Telegram/Telegram.WinUI.csproj`、`Build.WinUI.ps1` |
| 自动检查 | 检查修改结果、编译语法、签名证书与安装包身份、Windows 安装包签名 | `scripts/verify-lite.mjs`、`scripts/SyntaxCheck/`、`scripts/ci/preflight-windows.ps1`、`.github/workflows/windows-release.yml` |

完整的源码修改以 `scripts/apply-lite.mjs` 为准。不能根据当前目录是否存在某项 Premium 代码，就推断它可以任意删除：例如 Stars 的交易记录会使用部分付费相关消息类型。

## 合并上游更新

1. 查看上游 `develop` 分支新提交，确定目标提交 SHA，并阅读新增的功能和变更。
2. 在临时目录获取目标版本的源代码及子模块。
3. 使用 `node scripts/apply-lite.mjs <临时目录>` 应用个人修改。修改脚本会在无法唯一定位目标代码时停止。
4. 逐项检查修改内容是否覆盖了上游新增的广告展示入口、Premium 购买入口，以及用户可见的设置项。
5. 使用 `node scripts/verify-lite.mjs <临时目录>` 检查修改；执行 Roslyn 语法检查，并完成 Windows Release 编译。
6. 验证登录、普通聊天、媒体下载、文件发送、群组和频道、Stars 礼物等功能。
7. 更新 `scripts/upstream-ref.txt`、维护记录和源码；通过 GitHub Actions 发布新版本。

每次引入上游新版本时，使用独立 Git 提交记录采用的上游 SHA、实际修改的文件及测试结果。建议将 Release 附带的 `BUILD-INFO.json`、`SHA256SUMS.txt` 作为版本记录的一部分。

## 发布安全

- `API_ID` 与 `API_HASH` 通过 GitHub Actions Secrets 注入编译所需的 `Telegram/Constants.Secret.cs`。
- `PFX` 是 Base64 编码的签名证书，构建时导入 Windows 当前用户证书存储区。
- 私钥、证书密码与 `Constants.Secret.cs` 均不提交到仓库。
- Release 只提供签名安装包、公钥证书和校验文件。
- 同一个应用标识应持续使用相同的证书。更换证书可能影响安装包升级。
- 普通 Telegram 用户登录、网络连接及界面功能仍需要在实际 Windows 环境中测试。

## GitHub Actions 自动化测试

Windows 工作流程使用官方 Telegram 测试服务器创建临时测试账号，只在测试环境中进行授权、Saved Messages 发送及历史记录查询。测试手机号使用 Telegram 保留的测试号码范围，不会登录个人 Telegram 账号。

编译成功后，工作流程还检查签名、安装包版本、安装注册以及进程启动。只有这些必需检查全部通过才发布 Release。测试服务器登录结果单独记录在发布文件中；测试号码可能被服务器拒绝。Release 中的 `TEST-RESULTS.json` 区分自动化测试和仍需人工操作的功能。

首次正式使用时，应另行检查用户界面、个人账号登录、两步验证、群组与频道的真实消息收发、图片和视频、语音和视频通话，以及广告和 Premium 相关界面。

## Windows 原生依赖

`scripts/ci/configure-vcpkg-sources.ps1` 为 GitHub 公开源码归档增加 `codeload.github.com` 下载地址。文件仍由 vcpkg 按项目指定的 SHA-512 校验值进行完整性检查。改动只应用于 GitHub Actions 的临时运行环境，不会修改仓库使用的 vcpkg 版本。

GitHub Actions 缓存已下载的源码归档，以及成功构建的 TDLib 与 vcpkg 依赖。引入上游变更时，应同时检查 `vcpkg.json`、`Libraries/tdjson/build.ps1` 和归档下载脚本。Windows 构建脚本的语法检查见 `.github/workflows/windows-script-check.yml`。

## TDLib 构建文件

Windows 编译所需的 `Libraries/tdjson/td_api.tl` 与原生 `tdjson.dll` 来自相同的上游 TDLib 源码。`scripts/ci/prepare-tdlib-artifacts.ps1` 在编译前将上游协议文件复制到生成器预期的路径，并检查缓存恢复的 DLL、PDB 和依赖文件。每次构建前验证协议文件与上游源码的 SHA-256 一致，避免使用不完整或不同版本的缓存。

## 钱包原生组件

Windows x64 构建使用 [i582/wallet-engine](https://github.com/i582/wallet-engine) 的 `v0.0.7` 版本。其二进制文件以 MIT / Apache-2.0 双许可证发布。构建脚本 `scripts/ci/prepare-wallet-engine.ps1` 下载 Windows x64 发布包，对 ZIP 文件执行 SHA-256 校验，并检查导出的原生函数是否与仓库内的 UniFFI C# 接口一致。版本号和下载文件的 SHA-256 固定在脚本中。

重新采用新的钱包组件版本时，应同步检查 C# 接口、原生函数和实际钱包操作。该组件涉及密钥与转账，正式使用前需要单独验证钱包创建、密钥保存和恢复、转账确认及异常处理。

## Windows 安装包签名

`scripts/ci/prepare-windows.ps1` 从 `PFX` 中提取公开的根证书，将其安装到 Windows 的受信任根证书颁发机构存储区，并将应用签名证书添加到受信任的人存储区。`scripts/ci/verify-code-signing.ps1` 在编译原生依赖前实际签名和验证 Windows 测试程序。

发布文件包含 `TGLite-Signing-Certificate.cer` 和 `TGLite-Root-CA.cer`。这两个文件仅包含公钥。私钥仍由仓库的 `PFX` Secret 保存。使用者需要确认私有签发机构由本人管理，再决定是否信任根证书。
