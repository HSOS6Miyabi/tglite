# TGLite

TGLite 是基于 [Unigram](https://github.com/UnigramDev/Unigram) 的个人使用版 Windows Telegram 客户端。保留 Telegram 登录、普通聊天、文件和媒体功能，并精简付费推广相关界面。

## 功能

- 关闭频道、机器人会话的赞助消息获取和展示。
- 关闭视频播放界面的广告获取和展示。
- 隐藏 Premium 订阅、赠送及 Telegram Business 的设置入口。
- 关闭应用内 Premium 购买介绍、会员功能推广提示。
- 保留 Telegram 协议类型和账号权限判断，确保普通聊天及来自服务器的消息仍能正常处理。
- 保留 Stars、消息收发、文件、频道和群组等原有功能。

## 获取源代码

本仓库保留了源代码及 Git 子模块的引用。克隆时请使用：

```powershell
git clone --recursive https://github.com/HSOS6Miyabi/tglite.git
```

如果已经克隆，可以运行：

```powershell
git submodule update --init --recursive
```

## 编译

按 [Unigram 官方编译说明](Documentation/Build-instructions.md) 安装 Visual Studio 2026、Windows SDK，以及 C++、CMake、PHP 等相关组件。

前往 [Telegram API Development Tools](https://my.telegram.org/apps) 注册应用，并在 `Telegram/Constants.Secret.cs` 中写入自己的 `ApiId` 和 `ApiHash`。此文件已经在 `.gitignore` 中排除，不应提交到仓库。

完整的 `Constants.Secret.cs` 示例：

```csharp
namespace Telegram
{
    public static partial class Constants
    {
        static Constants()
        {
            ApiId = 12345678;
            ApiHash = "replace_with_your_api_hash";
            AppChannel = "";
        }
    }
}
```

之后可在 Visual Studio 中打开 `Telegram.slnx`，按原项目说明生成 Windows 程序；项目还包含 `Build.WinUI.ps1`、`Build.Modern.ps1` 等构建脚本。

## 项目来源与许可

基于 Unigram `develop` 分支指定版本制作，版本号见 `scripts/upstream-ref.txt`。源代码延续上游的 GNU GPL v3 许可证，详见 `LICENSE`。

Telegram 对第三方客户端展示赞助消息有专门的 API 使用规则。自行申请的 API 凭据可能受到规则约束，请在使用前阅读 [Telegram API 使用条款](https://core.telegram.org/api/terms)。

本仓库用于个人维护，不包含 Telegram API 私有凭据。
