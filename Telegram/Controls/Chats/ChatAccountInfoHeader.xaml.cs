//
// Copyright (c) Fela Ameghino 2015-2026
//
// Distributed under the GNU General Public License v3.0. (See accompanying
// file LICENSE or copy at https://www.gnu.org/licenses/gpl-3.0.txt)
//

using Telegram.Common;
using Telegram.Controls.Media;
using Telegram.Services;
using Telegram.Streams;
using Telegram.Td;
using Telegram.Td.Api;
using Telegram.ViewModels;
using Telegram.Views;
using Telegram.Views.Premium.Popups;
using Windows.Foundation;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Documents;

namespace Telegram.Controls.Chats
{
    public sealed partial class ChatAccountInfoHeader : Grid
    {
        public DialogViewModel ViewModel => DataContext as DialogViewModel;

        private IClientService _clientService;

        private ChatView _chatView;

        private long _thumbnailToken;

        public ChatAccountInfoHeader()
        {
            InitializeComponent();

            _collapsed = new SlidePanel.SlideState(this, false, 0);
        }

        private float _animatedHeight;
        public float AnimatedHeight => _collapsed ? 0 : ActualSize.Y;

        public void InitializeParent(ChatView chatView)
        {
            _chatView = chatView;
        }

        public void UpdateUser(IClientService clientService, Chat chat, User user, UserFullInfo fullInfo)
        {
            _clientService = clientService;

            if (fullInfo == null || fullInfo.IncomingPaidMessageStarCount == 0)
            {
                ShowHide(false);
                return;
            }

            ShowHide(true);

            PremiumUserRoot.Visibility = Visibility.Collapsed;

            if (fullInfo.IncomingPaidMessageStarCount > 0)
            {
                PayingUser.Visibility = Visibility.Visible;
                PayingUserText.Inlines.Clear();

                var text = string.Format(Strings.MessageLockedStarsRemoveFee.ReplaceStar(Icons.Premium), "{0}", fullInfo.IncomingPaidMessageStarCount.ToString("N0"));

                var markdown = ClientEx.ParseMarkdown(text);
                if (markdown.Entities.Count == 1)
                {
                    var e1 = markdown.Entities[0];
                    if (e1.Offset > 0)
                    {
                        PayingUserText.Inlines.Add(string.Format(markdown.Text.Substring(0, e1.Offset), user.FirstName));
                    }

                    if (e1.Type is TextEntityTypeBold)
                    {
                        var hyperlink = new Hyperlink();
                        hyperlink.Click += RemoveFee_Click;
                        hyperlink.UnderlineStyle = UnderlineStyle.None;
                        hyperlink.Inlines.Add(markdown.Text.Substring(e1.Offset, e1.Length));

                        PayingUserText.Inlines.Add(hyperlink);
                    }

                    if (e1.Offset + e1.Length < markdown.Text.Length)
                    {
                        PayingUserText.Inlines.Add(markdown.Text.Substring(e1.Offset + e1.Length));
                    }
                }
            }
            else
            {
                PayingUser.Visibility = Visibility.Collapsed;
            }
        }

        private void Premium_Click(Hyperlink sender, HyperlinkClickEventArgs args)
        {
        }

        private async void RemoveFee_Click(Hyperlink sender, HyperlinkClickEventArgs args)
        {
            if (ViewModel.Chat.Type is not ChatTypePrivate privata)
            {
                return;
            }

            var response = await ViewModel.ClientService.SendAsync(new GetPaidMessageRevenue(privata.UserId));
            if (response is not StarCount starCount)
            {
                return;
            }

            var popup = new MessagePopup
            {
                Title = Strings.RemoveMessageFeeTitle,
                Message = string.Format(Strings.RemoveMessageFeeMessage, ViewModel.Chat.Title),
                PrimaryButtonText = Strings.Confirm,
                SecondaryButtonText = Strings.Cancel
            };

            if (starCount.StarCountValue > 0)
            {
                popup.CheckBoxLabel = Locale.Declension(Strings.R.RemoveMessageFeeRefund, starCount.StarCountValue);
            }

            var confirm = await ViewModel.ShowPopupAsync(popup);
            if (confirm == ContentDialogResult.Primary)
            {
                ViewModel.ClientService.Send(new AllowUnpaidMessagesFromUser(privata.UserId, popup.IsChecked is true));
            }
        }

        private SlidePanel.SlideState _collapsed;

        private void ShowHide(bool show)
        {
            if (_collapsed != show)
            {
                return;
            }

            _collapsed.IsVisible = show;
            _chatView.UpdateMessagesHeaderPadding();
        }
    }
}
