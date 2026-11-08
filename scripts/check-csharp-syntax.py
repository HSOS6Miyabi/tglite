#!/usr/bin/env python3
"""Parse edited C# files and XML views before publishing."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

from tree_sitter import Language, Parser
import tree_sitter_c_sharp

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
CS_FILES = (
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
)
XAML_FILES = ("Telegram/Views/SettingsPage.xaml",)

parser = Parser(Language(tree_sitter_c_sharp.language()))
failed = False
for relative in CS_FILES:
    tree = parser.parse((ROOT / relative).read_bytes())
    if tree.root_node.has_error:
        failed = True
        errors = []
        stack = [tree.root_node]
        while stack and len(errors) < 8:
            node = stack.pop()
            if node.type == "ERROR" or node.is_missing:
                errors.append(f"{node.type} at {node.start_point.row + 1}:{node.start_point.column + 1}")
            stack.extend(reversed(node.children))
        print(f"FAIL {relative}: " + ", ".join(errors))
    else:
        print(f"PASS {relative}")

for relative in XAML_FILES:
    try:
        ET.parse(ROOT / relative)
        print(f"PASS {relative}")
    except ET.ParseError as exc:
        failed = True
        print(f"FAIL {relative}: {exc}")

sys.exit(1 if failed else 0)
