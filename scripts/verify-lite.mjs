#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.argv[2] ?? ".");
const get = (file) => fs.readFileSync(path.join(root, file), "utf8");
const cases = [
  ["All original project files exist", () => {
    assert.ok(fs.existsSync(path.join(root,"Telegram/Telegram.csproj")));
    assert.ok(fs.existsSync(path.join(root,"Telegram/Telegram.WinUI.csproj")));
    assert.ok(fs.existsSync(path.join(root,"LICENSE")));
    assert.ok(fs.existsSync(path.join(root,".gitmodules")));
  }],
  ["Chat advertising fetch disabled", () => assert.doesNotMatch(get("Telegram/ViewModels/DialogViewModel.cs"), /new GetChatSponsoredMessages\s*\(/)],
  ["Video advertising fetch disabled", () => assert.doesNotMatch(get("Telegram/ViewModels/Chats/ChatGalleryViewModel.cs"), /GetVideoMessageAdvertisements\s*\(/)],
  ["No chat ad injection on scroll", () => assert.doesNotMatch(get("Telegram/Controls/Chats/ChatHistoryView.cs"), /InsertMessageInOrder\([^\n]*MessageSponsored/)],
  ["Sponsored content renderer disabled", () => assert.match(get("Telegram/Controls/Messages/MessageBubble.xaml.cs"), /MessageSponsored => null/)],
  ["Ad overlays are explicitly hidden", () => {
    assert.match(get("Telegram/Controls/Chats/ChatSponsoredHeader.xaml.cs"), /ShowHide\(false\)/);
    assert.match(get("Telegram/Controls/Gallery/GallerySponsoredContent.xaml.cs"), /_advertisement = null;/);
  }],
  ["Premium subscription navigation disabled", () => {
    const s=get("Telegram/Common/TLNavigationService.cs");
    assert.doesNotMatch(s,/ShowPopup\(new PromoPopup\(\), source\)/);
    assert.doesNotMatch(s,/GetPremiumFeatures\s*\(/);
    assert.match(s,/public Task ShowPromoAsync\([^\n]+\)\s*\{\s*return Task.CompletedTask;/);
  }],
  ["Premium availability hidden", () => assert.match(get("Telegram/Services/ClientService.cs"), /public bool IsPremiumAvailable => false;/)],
  ["Premium and business entries absent from settings", () => {
    const xml=get("Telegram/Views/SettingsPage.xaml");
    assert.doesNotMatch(xml,/Click="Premium_Click"|x:Name="PremiumGifting"|Click="Business_Click"/);
    assert.match(xml,/Click="Stars_Click"/);
  }],
  ["Paid-feature promotional toasts disabled", () => {
    const s=get("Telegram/Controls/ToastPopup.cs");
    assert.doesNotMatch(s,/Show\(navigationService.XamlRoot, CreatePromoLabel/);
    assert.doesNotMatch(s,/ShowActionAsync\(navigationService.XamlRoot, markdown, action, ToastPopupIcon.Premium\)/);
  }],
  ["Direct Premium purchase presentations are inactive", () => {
    assert.ok(!get("Telegram/ViewModels/ProfileViewModel.cs").includes("NavigationService.ShowPopup(new PromoPopup"));
    assert.ok(!get("Telegram/Controls/Chats/ChatAccountInfoHeader.xaml.cs").includes("ViewModel.NavigationService.ShowPopup(new PromoPopup"));
    assert.ok(!get("Telegram/Common/MessageHelper.cs").includes("navigation.ShowPopup(new PromoPopup"));
    assert.ok(!get("Telegram/ViewModels/DialogViewModel.Messages.cs").includes("ShowPopup(new Views.Premium.Popups.PromoPopup"));
  }],
  ["Gift browser keeps Stars items and omits Premium purchases", () => {
    const s=get("Telegram/Views/Premium/Popups/GiftPopup.xaml.cs");
    assert.ok(!s.includes("new GetPremiumGiftPaymentOptions("));
    assert.ok(!s.includes("ShowPopupAsync(new Views.Premium.Popups.PromoPopup"));
    assert.ok(s.includes("if (gift.Gift.IsPremium)"));
    assert.ok(s.includes("new GetAvailableGifts("));
  }],
  ["Message editor date selector is available", () => {
    const s=get("Telegram/Controls/FormattedTextBox.cs");
    const popup=get("Telegram/Views/Popups/ChooseDateTimePopup.xaml.cs");
    assert.ok(s.includes("ChooseDateTimePopup.ChooseDateUrlAsync(XamlRoot)"));
    assert.ok(popup.includes("public static async Task<string> ChooseDateUrlAsync(XamlRoot xamlRoot)"));
  }],
  ["Chat previews use defined icon glyphs", () => {
    const s=get("Telegram/Controls/Cells/ChatCell.xaml.cs");
    const icons=get("Telegram/Controls/Media/Icons.cs");
    for(const name of ["ArrowForward24","ArrowReply24"]) {
      assert.ok(s.includes("Icons." + name + " + Icons.Space"));
      assert.ok(icons.includes("const string " + name + " ="));
    }
  }],
  ["Standard sign-in remains configured", () => {
    const s=get("Telegram/Services/ClientService.cs");
    assert.match(s,/apiId:\s*Constants.ApiId/);
    assert.match(s,/apiHash:\s*Constants.ApiHash/);
  }],
];
let failed=0;
for(const [name,run] of cases) {
 try { run(); console.log("PASS "+name); }
 catch(error) { failed++; console.error("FAIL "+name+": "+error.message); }
}
if(failed)process.exit(1);
