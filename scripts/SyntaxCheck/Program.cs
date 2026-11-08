using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using System.Xml.Linq;

var root = Path.GetFullPath(args.Length > 0 ? args[0] : ".");
string[] csFiles =
[
    "Telegram/ViewModels/DialogViewModel.cs",
    "Telegram/ViewModels/Chats/ChatGalleryViewModel.cs",
    "Telegram/Controls/Chats/ChatHistoryView.cs",
    "Telegram/Controls/Chats/ChatSponsoredHeader.xaml.cs",
    "Telegram/Controls/Gallery/GallerySponsoredContent.xaml.cs",
    "Telegram/Controls/Messages/MessageBubble.xaml.cs",
    "Telegram/Services/ClientService.cs",
    "Telegram/Common/TLNavigationService.cs",
    "Telegram/Controls/ToastPopup.cs",
    "Telegram/Views/SettingsPage.xaml.cs",
    "Telegram/Controls/ProfileHeader.xaml.cs",
    "Telegram/Views/ChatView.xaml.cs",
    "Telegram/ViewModels/ProfileViewModel.cs",
    "Telegram/Controls/IdentityIcon.cs",
    "Telegram/Controls/Chats/ChatAccountInfoHeader.xaml.cs",
    "Telegram/Common/MessageHelper.cs",
    "Telegram/ViewModels/DialogViewModel.Messages.cs",
    "Telegram/Views/Premium/Popups/GiftPopup.xaml.cs",
    "Telegram/Controls/FormattedTextBox.cs",
    "Telegram/Controls/Cells/ChatCell.xaml.cs",
];
string[] xamlFiles =
[
    "Telegram/Views/SettingsPage.xaml",
];
var failed = false;
var parseOptions = CSharpParseOptions.Default.WithLanguageVersion(LanguageVersion.Preview);
foreach (var relative in csFiles)
{
    var path = Path.Combine(root, relative);
    var tree = CSharpSyntaxTree.ParseText(File.ReadAllText(path), parseOptions, path);
    var errors = tree.GetDiagnostics().Where(d => d.Severity == DiagnosticSeverity.Error).ToList();
    if (errors.Count == 0)
    {
        Console.WriteLine($"PASS {relative}");
        continue;
    }
    failed = true;
    foreach (var issue in errors.Take(8))
    {
        Console.Error.WriteLine($"FAIL {relative}: {issue}");
    }
}
foreach (var relative in xamlFiles)
{
    try
    {
        XDocument.Load(Path.Combine(root, relative));
        Console.WriteLine($"PASS {relative}");
    }
    catch (Exception error)
    {
        failed = true;
        Console.Error.WriteLine($"FAIL {relative}: {error.Message}");
    }
}
return failed ? 1 : 0;
