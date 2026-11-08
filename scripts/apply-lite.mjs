#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

function replaceOnce(source,oldText,newText,label="text") {
  const pos=source.indexOf(oldText);
  if(pos<0||source.indexOf(oldText,pos+oldText.length)>=0)throw Error("Expected one occurrence for "+label);
  return source.slice(0,pos)+newText+source.slice(pos+oldText.length);
}
function replaceMethod(source,signature,replacement) {
  const at=source.indexOf(signature);
  if(at<0||source.indexOf(signature,at+signature.length)>=0)throw Error("Method not uniquely found: "+signature);
  const brace=source.indexOf("{",at+signature.length);
  if(brace<0)throw Error("Method brace missing: "+signature);
  const lex=/\/\/[^\r\n]*|\/\*[\s\S]*?\*\/|@?"(?:""|\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[{}]/g;
  lex.lastIndex=brace;
  let depth=0, end=-1, match;
  while((match=lex.exec(source))!==null) {
    if(match[0]==="{")depth++;
    if(match[0]==="}") {
      depth--;
      if(depth===0){end=lex.lastIndex;break;}
    }
  }
  if(end<0||depth!==0)throw Error("Method braces mismatch: "+signature);
  return source.slice(0,at)+replacement+source.slice(end);
}
function removeBlock(source,pattern,label) {
  const matches=[...source.matchAll(pattern)];
  if(matches.length!==1)throw Error("Expected one block for "+label+", got "+matches.length);
  return source.replace(pattern,"");
}
function stripSettingsButton(source,attribute) {
  const at=source.indexOf(attribute);
  if(at<0||source.indexOf(attribute,at+1)>=0)throw Error("Settings entry must be unique: "+attribute);
  const start=source.lastIndexOf("<controls:SettingsButton",at);
  const tagEnd=source.indexOf(">",start);
  if(start<0||tagEnd<at)throw Error("Settings entry does not belong to the opening tag: "+attribute);
  const close="</controls:SettingsButton>";
  const end=source.indexOf(close,tagEnd);
  if(end<0)throw Error("Settings entry not closed: "+attribute);
  return source.slice(0,start)+source.slice(end+close.length);
}
function patchFile(file,source) {
 let result=source;
 switch(file){
 case "Telegram/ViewModels/DialogViewModel.cs":
   result=replaceMethod(result,"private async Task AddSponsoredMessagesAsync()",`private Task AddSponsoredMessagesAsync()\n        {\n            return Task.CompletedTask;\n        }`);
   result=replaceMethod(result,"public void HideSponsoredMessage(MessageViewModel message = null)",`public void HideSponsoredMessage(MessageViewModel message = null)\n        {\n            if (message != null)\n            {\n                Items.Remove(message);\n            }\n            for (int index = Items.Count - 1; index >= 0; index--)\n            {\n                if (Items[index].Content is MessageSponsored)\n                {\n                    Items.RemoveAt(index);\n                }\n            }\n            PendingSponsoredMessage = null;\n            SponsoredMessage = null;\n        }`);
   result=replaceMethod(result,"public void ViewSponsoredMessage()",`public void ViewSponsoredMessage()\n        {\n        }`);
   result=replaceMethod(result,"public void GiftPremium()",`public void GiftPremium()\n        {\n        }`);
   break;
 case "Telegram/ViewModels/Chats/ChatGalleryViewModel.cs": {
   const start=result.indexOf("        #region Advertisements");
   const end=result.indexOf("        #endregion",start);
   if(start<0||end<start||result.indexOf("        #region Advertisements",start+1)>=0)throw Error("Advertisement section not found");
   result=result.slice(0,start)+"        public override void PlaybackStarted(GalleryMedia item)\n        {\n        }\n\n        public override void PlaybackStopped()\n        {\n        }\n"+result.slice(end+"        #endregion".length);
   break;
 }
 case "Telegram/Controls/Chats/ChatHistoryView.cs": {
   result=replaceMethod(result,"private void OnTick(object sender, object e)",`private void OnTick(object sender, object e)\n        {\n            _scrollTracker.Stop();\n        }`);
   result=replaceOnce(result,`            // TODO: only start timer if close to bottom\n            if (ViewModel.PendingSponsoredMessage != null)\n            {\n                _scrollTracker.Start();\n            }\n`,"","chat history timer");
   const anchor=result.indexOf("private void OnPointerWheelChanged(object sender, PointerRoutedEventArgs e)");
   const start=result.indexOf("            var message = ViewModel.PendingSponsoredMessage;",anchor);
   const end=result.indexOf("        }\n\n        private void OnSizeChanged",start);
   if(anchor<0||start<anchor||end<start)throw Error("ChatHistory wheel advertising code not found");
   result=result.slice(0,start)+result.slice(end);
   break;
 }
 case "Telegram/Controls/Chats/ChatSponsoredHeader.xaml.cs":
   result=replaceMethod(result,"public void UpdateSponsoredMessage(IClientService clientService, Chat chat, SponsoredMessage message)",`public void UpdateSponsoredMessage(IClientService clientService, Chat chat, SponsoredMessage message)\n        {\n            _clientService = clientService;\n            ShowHide(false);\n        }`);
   break;
 case "Telegram/Controls/Gallery/GallerySponsoredContent.xaml.cs":
   result=replaceMethod(result,"public void UpdateAdvertisement(VideoMessageAdvertisement advertisement)",`public void UpdateAdvertisement(VideoMessageAdvertisement advertisement)\n        {\n            _advertisement = null;\n            _maxDisplayTimer?.Stop();\n            _minDisplayTimer?.Stop();\n            ShowHide(false);\n        }`);
   break;
 case "Telegram/Controls/Messages/MessageBubble.xaml.cs":
   result=replaceOnce(result,"MessageSponsored => new SponsoredContent(message),","MessageSponsored => null,","message content dispatch");
   break;
 case "Telegram/Services/ClientService.cs":
   result=replaceOnce(result,"public bool IsPremiumAvailable => _options.IsPremium || _options.IsPremiumAvailable;","public bool IsPremiumAvailable => false;","Premium availability");
   break;
 case "Telegram/Common/TLNavigationService.cs":
   result=replaceMethod(result,"public void ShowLimitReached(PremiumLimitType type)",`public void ShowLimitReached(PremiumLimitType type)\n        {\n        }`);
   result=replaceMethod(result,"public void ShowPromo(PremiumSource source = null)",`public void ShowPromo(PremiumSource source = null)\n        {\n        }`);
   result=replaceMethod(result,"public Task ShowPromoAsync(PremiumSource source = null, ElementTheme requestedTheme = ElementTheme.Default)",`public Task ShowPromoAsync(PremiumSource source = null, ElementTheme requestedTheme = ElementTheme.Default)\n        {\n            return Task.CompletedTask;\n        }`);
   result=replaceMethod(result,"public async void ShowPromo(PremiumFeature feature, PremiumSource source = null)",`public void ShowPromo(PremiumFeature feature, PremiumSource source = null)\n        {\n        }`);
   break;
 case "Telegram/Controls/ToastPopup.cs":
   result=replaceMethod(result,"public static void ShowOptionPromo(INavigationService navigationService)",`public static void ShowOptionPromo(INavigationService navigationService)\n        {\n        }`);
   result=replaceMethod(result,"public static void ShowFeaturePromo(INavigationService navigationService, PremiumFeature feature)",`public static void ShowFeaturePromo(INavigationService navigationService, PremiumFeature feature)\n        {\n        }`);
   result=replaceMethod(result,"public static void ShowFeaturePromo(INavigationService navigationService, string text, PremiumFeature feature)",`public static void ShowFeaturePromo(INavigationService navigationService, string text, PremiumFeature feature)\n        {\n        }`);
   result=replaceMethod(result,"public static async void ShowPromo(INavigationService navigationService, string text, string action, PremiumSource source, PremiumFeature feature = null)",`public static void ShowPromo(INavigationService navigationService, string text, string action, PremiumSource source, PremiumFeature feature = null)\n        {\n        }`);
   break;
 case "Telegram/Views/SettingsPage.xaml":
   result=stripSettingsButton(result,'Click="Premium_Click"');
   result=stripSettingsButton(result,'Click="Business_Click"');
   result=stripSettingsButton(result,'x:Name="PremiumGifting"');
   result=replaceOnce(result,`<StackPanel x:Name="PremiumRoot"\n                            x:Load="{x:Bind ViewModel.IsPremiumAvailable, Mode=OneWay}">`,`<StackPanel x:Name="ServicesRoot">`,"services navigation");
   break;
 case "Telegram/Views/SettingsPage.xaml.cs":
   result=replaceMethod(result,"private void Premium_Click(object sender, RoutedEventArgs e)","");
   break;
 case "Telegram/Controls/ProfileHeader.xaml.cs":
   result=removeBlock(result,/[ \t]*if \(user\.Type is UserTypeRegular && ViewModel\.IsPremiumAvailable\)\s*\{\s*flyout\.CreateFlyoutItem\(ViewModel\.GiftPremium,[^\n]+\);\s*\}/g,"profile gift menu");
   result=removeBlock(result,/[ \t]*if \(fullInfo != null && fullInfo\.CanSendGift\)\s*\{\s*flyout\.CreateFlyoutItem\(ViewModel\.GiftPremium,[^\n]+\);\s*\}/g,"profile secondary gift menu");
   break;
 case "Telegram/Views/ChatView.xaml.cs":
   result=removeBlock(result,/[ \t]*if \(ViewModel\.IsPremium && ViewModel\.ClientService\.Options\.GiftPremiumFromAttachmentMenu\)\s*\{\s*if \(ViewModel\.ClientService\.TryGetUser\(ViewModel\.Chat, out User receiver\)\)\s*\{\s*flyout\.CreateFlyoutItem\(ViewModel\.GiftPremium,[^\n]+\);\s*\}\s*\}/g,"chat attachment gift");
   result=removeBlock(result,/[ \t]*if \(message\.Content is MessageGift gift && ViewModel\.ClientService\.TryGetUser\(chat, out User user\)\)\s*\{\s*flyout\.CreateFlyoutItem\(ViewModel\.GiftPremium,[^\n]+\);\s*\}/g,"message gift menu");
   break;
 case "Telegram/ViewModels/ProfileViewModel.cs":
   result=replaceMethod(result,"public void GiftPremium()",`public void GiftPremium()\n        {\n        }`);
   break;
 case "Telegram/Controls/IdentityIcon.cs":
   result=replaceOnce(result,"var premium = user.IsPremium && clientService.IsPremiumAvailable && (!chatList || user.Id != clientService.Options.MyId);","var premium = false;","identity premium status");
   break;
 default:throw Error("Unexpected source file "+file);
 }
 if(result===source)throw Error("No changes for "+file);
 return result;
}

const files = [
  "Telegram/ViewModels/DialogViewModel.cs",
  "Telegram/ViewModels/Chats/ChatGalleryViewModel.cs",
  "Telegram/Controls/Chats/ChatHistoryView.cs",
  "Telegram/Controls/Chats/ChatSponsoredHeader.xaml.cs",
  "Telegram/Controls/Gallery/GallerySponsoredContent.xaml.cs",
  "Telegram/Controls/Messages/MessageBubble.xaml.cs",
  "Telegram/Services/ClientService.cs",
  "Telegram/Common/TLNavigationService.cs",
  "Telegram/Controls/ToastPopup.cs",
  "Telegram/Views/SettingsPage.xaml",
  "Telegram/Views/SettingsPage.xaml.cs",
  "Telegram/Controls/ProfileHeader.xaml.cs",
  "Telegram/Views/ChatView.xaml.cs",
  "Telegram/ViewModels/ProfileViewModel.cs",
  "Telegram/Controls/IdentityIcon.cs"
];
const root = path.resolve(process.argv[2] ?? ".");
for (const file of files) {
  const filename = path.join(root, file);
  const original = fs.readFileSync(filename, "utf8");
  const changed = patchFile(file, original);
  fs.writeFileSync(filename, changed, "utf8");
  process.stdout.write("Updated " + file + "\n");
}
