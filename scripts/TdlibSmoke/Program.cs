using System.Runtime.InteropServices;
using System.Text.Json;

internal static class Native
{
    [DllImport("tdjson", CallingConvention = CallingConvention.Cdecl)]
    internal static extern int td_create_client_id();

    [DllImport("tdjson", CallingConvention = CallingConvention.Cdecl)]
    internal static extern void td_send(int clientId, [MarshalAs(UnmanagedType.LPUTF8Str)] string request);

    [DllImport("tdjson", CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint td_receive(double seconds);

    [DllImport("tdjson", CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint td_execute([MarshalAs(UnmanagedType.LPUTF8Str)] string request);
}

internal static class Program
{
    private static string TypeOf(JsonElement obj)
        => obj.TryGetProperty("@type", out var type) ? type.GetString() ?? "" : "";

    private static string ExtraOf(JsonElement obj)
        => obj.TryGetProperty("@extra", out var extra) ? extra.GetString() ?? "" : "";

    private static object Request(string type, string extra)
        => new Dictionary<string, object> { ["@type"] = type, ["@extra"] = extra };

    public static int Main()
    {
        try
        {
            Run();
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("FAIL TDLib integration: " + ex.GetType().Name + ": " + ex.Message);
            return 1;
        }
    }

    private static void Run()
    {
        var apiId = int.Parse(Environment.GetEnvironmentVariable("TG_API_ID")
            ?? throw new InvalidOperationException("Missing Telegram test API ID"));
        var apiHash = Environment.GetEnvironmentVariable("TG_API_HASH")
            ?? throw new InvalidOperationException("Missing Telegram test API hash");
        if (apiHash.Length != 32) throw new InvalidOperationException("Invalid Telegram API hash");
        var run = int.Parse(Environment.GetEnvironmentVariable("GITHUB_RUN_NUMBER") ?? "1");
        var phone = "+999661" + (run % 10_000).ToString("D4");
        var messageText = "TGLite test-DC message " + (run % 10_000).ToString("D4");
        var root = Path.Combine(Path.GetTempPath(), "tglite-testdc-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        Console.WriteLine("TDLib integration: using Telegram test DC 1 and a reserved test phone number");

        var logging = Native.td_execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");
        if (logging == 0) throw new InvalidOperationException("TDLib synchronous API returned no result");
        var clientId = Native.td_create_client_id();
        if (clientId <= 0) throw new InvalidOperationException("Could not create TDLib client");
        void Send(object body) => Native.td_send(clientId, JsonSerializer.Serialize(body));

        Send(new Dictionary<string, object> {
            ["@type"] = "getOption", ["name"] = "version", ["@extra"] = "version"
        });
        Send(new Dictionary<string, object?> {
            ["@type"] = "setTdlibParameters", ["@extra"] = "init",
            ["use_test_dc"] = true,
            ["database_directory"] = root,
            ["files_directory"] = Path.Combine(root, "files"),
            ["database_encryption_key"] = null,
            ["use_file_database"] = false,
            ["use_chat_info_database"] = false,
            ["use_message_database"] = false,
            ["use_secret_chats"] = false,
            ["api_id"] = apiId, ["api_hash"] = apiHash,
            ["system_language_code"] = "en",
            ["device_model"] = "TGLite GitHub Actions",
            ["system_version"] = "Windows CI",
            ["application_version"] = "TGLite test"
        });

        var versionOk = false;
        var authReady = false;
        var getMe = false;
        var createChat = false;
        var sent = false;
        var received = false;
        var sentConfirmed = false;
        var alreadyProcessed = new HashSet<string>();
        long chatId = 0;
        var start = DateTime.UtcNow;
        var deadline = start.AddSeconds(165);

        while (DateTime.UtcNow < deadline && !(versionOk && authReady && getMe && createChat && sent && received))
        {
            var ptr = Native.td_receive(1.0);
            if (ptr == 0) continue;
            var json = Marshal.PtrToStringUTF8(ptr);
            if (string.IsNullOrWhiteSpace(json)) continue;
            using var doc = JsonDocument.Parse(json);
            var obj = doc.RootElement;
            var type = TypeOf(obj);
            var extra = ExtraOf(obj);

            if (type == "error")
            {
                // A failure of the test DC's login, message or initialisation is a failed integration test.
                if (new[] { "init", "phone", "code", "register", "me", "chat", "send", "history" }.Contains(extra))
                {
                    var code = obj.TryGetProperty("code", out var c) ? c.ToString() : "?";
                    var message = obj.TryGetProperty("message", out var m) ? m.GetString() : "unknown";
                    throw new InvalidOperationException("Telegram test DC error for " + extra + ": " + code + " " + message);
                }
                continue;
            }

            if (extra == "version" && type == "optionValueString")
            {
                if (!obj.TryGetProperty("value", out var ver) || string.IsNullOrEmpty(ver.GetString()))
                    throw new InvalidOperationException("TDLib did not report its version");
                versionOk = true;
                Console.WriteLine("PASS TDLib native library and JSON request/response");
            }

            if (type == "updateAuthorizationState" || extra == "auth")
            {
                var state = type == "updateAuthorizationState"
                    ? obj.GetProperty("authorization_state")
                    : obj;
                var stateType = TypeOf(state);
                if (alreadyProcessed.Add(stateType))
                {
                    switch (stateType)
                    {
                        case "authorizationStateWaitTdlibParameters":
                            break;
                        case "authorizationStateWaitPhoneNumber":
                            Send(new Dictionary<string, object> {
                                ["@type"] = "setAuthenticationPhoneNumber",
                                ["phone_number"] = phone,
                                ["settings"] = new Dictionary<string, object> {
                                    ["@type"] = "phoneNumberAuthenticationSettings",
                                    ["allow_flash_call"] = false,
                                    ["allow_missed_call"] = false,
                                    ["is_current_phone_number"] = false,
                                    ["allow_sms_retriever_api"] = false
                                },
                                ["@extra"] = "phone"
                            });
                            Console.WriteLine("PASS TDLib reached the test DC authorization flow");
                            break;
                        case "authorizationStateWaitCode":
                            Send(new Dictionary<string, object> {
                                ["@type"] = "checkAuthenticationCode",
                                ["code"] = "11111",
                                ["@extra"] = "code"
                            });
                            break;
                        case "authorizationStateWaitRegistration":
                            Send(new Dictionary<string, object> {
                                ["@type"] = "registerUser",
                                ["first_name"] = "TGLite",
                                ["last_name"] = "CI",
                                ["disable_notification"] = true,
                                ["@extra"] = "register"
                            });
                            break;
                        case "authorizationStateReady":
                            authReady = true;
                            Console.WriteLine("PASS Telegram test DC authorization");
                            Send(Request("getMe", "me"));
                            break;
                        case "authorizationStateWaitPassword":
                        case "authorizationStateWaitEmailAddress":
                        case "authorizationStateWaitEmailCode":
                        case "authorizationStateWaitOtherDeviceConfirmation":
                            throw new InvalidOperationException("Test DC account requires an additional interactive authentication step");
                        case "authorizationStateClosed":
                            throw new InvalidOperationException("TDLib closed before integration tests completed");
                    }
                }
            }

            if (extra == "me" && type == "user")
            {
                var userId = obj.GetProperty("id").GetInt64();
                if (userId <= 0) throw new InvalidOperationException("Test DC returned an invalid account ID");
                getMe = true;
                Console.WriteLine("PASS getMe on test DC");
                Send(new Dictionary<string, object> {
                    ["@type"] = "createPrivateChat",
                    ["user_id"] = userId,
                    ["force"] = false,
                    ["@extra"] = "chat"
                });
            }

            if (extra == "chat" && type == "chat")
            {
                chatId = obj.GetProperty("id").GetInt64();
                createChat = true;
                Console.WriteLine("PASS Saved Messages chat creation");
                Send(new Dictionary<string, object> {
                    ["@type"] = "sendMessage",
                    ["chat_id"] = chatId,
                    ["input_message_content"] = new Dictionary<string, object?> {
                        ["@type"] = "inputMessageText",
                        ["text"] = new Dictionary<string, object> {
                            ["@type"] = "formattedText", ["text"] = messageText, ["entities"] = Array.Empty<object>()
                        },
                        ["link_preview_options"] = null,
                        ["clear_draft"] = false
                    },
                    ["@extra"] = "send"
                });
            }

            if (extra == "send" && type == "message")
            {
                sent = true;
                Console.WriteLine("PASS sendMessage request on test DC");
                Send(new Dictionary<string, object> {
                    ["@type"] = "getChatHistory",
                    ["chat_id"] = chatId,
                    ["from_message_id"] = 0,
                    ["offset"] = 0,
                    ["limit"] = 15,
                    ["only_local"] = false,
                    ["@extra"] = "history"
                });
            }

            if (type == "updateMessageSendSucceeded")
            {
                sentConfirmed = true;
            }

            if (extra == "history" && type == "messages")
            {
                if (obj.TryGetProperty("messages", out var messages) && messages.ValueKind == JsonValueKind.Array)
                {
                    foreach (var message in messages.EnumerateArray())
                    {
                        if (message.TryGetProperty("content", out var content) &&
                            content.TryGetProperty("text", out var textNode) &&
                            textNode.TryGetProperty("text", out var textValue) &&
                            textValue.GetString() == messageText)
                        {
                            received = true;
                            break;
                        }
                    }
                }
                if (!received && DateTime.UtcNow < deadline.AddSeconds(-10))
                {
                    Thread.Sleep(1500);
                    Send(new Dictionary<string, object> {
                        ["@type"] = "getChatHistory",
                        ["chat_id"] = chatId, ["from_message_id"] = 0,
                        ["offset"] = 0, ["limit"] = 15, ["only_local"] = false, ["@extra"] = "history"
                    });
                }
            }
        }
        Send(Request("close", "close"));
        if (!versionOk || !authReady || !getMe || !createChat || !sent || !received)
        {
            throw new TimeoutException("Test DC integration incomplete: version=" + versionOk +
                ", login=" + authReady + ", account=" + getMe + ", chat=" + createChat +
                ", send=" + sent + ", history=" + received);
        }
        Console.WriteLine("PASS test DC Saved Messages send and history read");
        Console.WriteLine("PASS all TDLib integration checks");
    }
}
