# Telegram Bot Token

Required to use DroidClaw as a Telegram bot. Allows remote access from any device (PC, tablet, another phone).

## Get a Token

1. Open **Telegram** on your phone or desktop
2. Search for **@BotFather** and start a conversation
3. Send `/newbot`
4. Choose a **name** for the bot (e.g. "My DroidClaw")
5. Choose a **username** (must end with `bot`, e.g. `my_droidclaw_bot`)
6. BotFather will reply with the **bot token** (format: `123456789:ABCdef...`)
7. Copy the token

## Configure in DroidClaw

1. **Settings > Telegram Bot**
2. Paste the token
3. Click **Test** to verify
4. Toggle **Enable** to start the bot

## Security

- **Whitelist**: add Telegram usernames (without @) to restrict who can talk to the bot. If the whitelist is empty, anyone who finds the bot can use it.
- The bot token is stored in FlutterSecureStorage on the device
- Long polling is used (no webhook, no server needed)

## Optional: Customize the Bot

Send these commands to @BotFather:
- `/setdescription` -- set what users see before starting a conversation
- `/setabouttext` -- set the "About" section
- `/setuserpic` -- set the bot's profile picture
- `/setcommands` -- not needed (DroidClaw processes natural language)

## Notes

- The bot runs via the Android foreground service (persistent notification)
- It works even when the app is in the background or the screen is off
- Each Telegram chat gets its own session (`telegram_<chat_id>`)
