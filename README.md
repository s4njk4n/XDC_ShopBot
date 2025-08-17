Experimental project released under MIT license. Feel free to build or improve further.

# XDC_ShopBot

![XDC ShopBot Logo](XDC_ShopBot.jpg)

## What is XDC_ShopBot?

XDC_ShopBot is a simple, beginner-friendly Telegram bot that lets you sell digital products (like access codes, files, or services) and accept payments in XDC cryptocurrency. It's designed for hobbyists wanting to set up or play with an online shop without needing advanced coding skills. 

The bot handles:
- Showing a list of your products to customers.
- Guiding customers through purchase (including privacy policy acceptance and country checks if needed).
- Generating unique payment amounts in XDC (or converted from USD).
- Monitoring the XDC blockchain for incoming payments.
- Automatically delivering a success message (e.g., an access code or digital product download links) to the customer after payment has been received at your address.

Everything runs on your own server (like a cheap VPS), and you control it all. No third-party services required beyond Telegram and a free XDC RPC endpoint.

I've specifically made it ultra-simple: Clone it, run a setup script, and you're ready to sell.

**Important Disclaimer:** This project is provided "as is" under the MIT License. The author makes no warranties, and you use it at your own risk. Always test thoroughly, comply with local laws, and consider consulting a professional for payment systems. Cryptocurrency transactions are irreversible—handle with care.

## Who is this for?
- Hobbyists who want to accept XDC payments.
- People with basic computer skills – we'll guide you step-by-step.
- No coding needed after setup; manage products via Telegram commands.

## Features
- **Easy Setup:** A script asks for your details and configures everything.
- **Product Management:** Add/remove products and set delivery messages right from Telegram (only you, the owner, can do this).
- **Payments:** Customers pay exact amounts to your XDC wallet; bot auto-detects their payment and delivers.
- **USD Support:** Price items in USD; bot converts to XDC using real-time rates.
- **Privacy & Restrictions:** Customizable privacy policy and excluded countries.
- **Logging:** Keeps basic records of sales for your records (e.g., compliance) - This part needs further developemnt.
- **Secure:** Runs on your server; no sharing sensitive data.

## Prerequisites
Before starting, you'll need:
1. A **VPS (Virtual Private Server)**: Rent a cheap Linux server (e.g., from DigitalOcean, Vultr, or Linode for ~$5/month). It needs Ubuntu or Debian (most common). Make sure you can SSH into it.
2. **Telegram Account:** For creating the bot and managing it.
3. **XDC Wallet Address:** Get one from a wallet like XDCPay or MetaMask (set to XDC network). It starts with "xdc..." or "0x...".
4. **Basic Command-Line Knowledge:** We'll provide exact commands to copy-paste.

If you're new to VPS:
- Sign up for a provider.
- Create a server (choose Ubuntu 24.04 or similar).
- SSH in: On Windows, use PuTTY; on Mac/Linux, use terminal with `ssh user@ip-address`.

## Installation

### Step 1: Clone the Repository
Use your terminal application to connect to your VPS via SSH and then run this command on the VPS. It will update your system and copy the XDC ShopBot to your server:

```bash
sudo apt update -y && sudo apt install git bash curl jq bc -y && sudo apt autoremove -y && git clone https://github.com/s4njk4n/XDC_ShopBot.git && cd ~/XDC_ShopBot
```

This downloads all the files to a folder called `XDC_ShopBot`.

### Step 2: Create a Telegram Bot
You need a Telegram bot token. This is like a password for your bot.

1. Open Telegram on your phone or desktop.
2. Search for `@BotFather` (official Telegram bot creator).
3. Start a chat and type `/newbot`.
4. Follow prompts: Give your bot a name (e.g., "MyXDCSHopBot") and username (ends with "bot", e.g., "my_xdc_shop_bot").
5. BotFather will give you a **token** like `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`. Copy it safely.

### Step 3: Get Your Telegram User ID
This is your personal ID, so only you can manage the bot.

1. In Telegram, search for `@userinfobot`.
2. Start a chat and send `/start`.
3. It will reply with your User ID (a number like `123456789`). Copy it.

### Step 4: Run the Setup Script
Back in your VPS terminal (inside the `XDC_ShopBot` folder) we'll now run the setup script:

```bash
cd ~/XDC_ShopBot && chmod +x setup.sh && bash ./setup.sh
```

The script will ask questions:
- Telegram Bot Token: Paste the one from BotFather.
- Seller XDC Address: Your wallet address (starts with "xdc" or "0x").
- Your Telegram User ID: The number from @userinfobot.
- Excluded Countries: Enter comma-separated like "Australia, Antarctica" or leave blank.
- Welcome Title: e.g., "Welcome to My XDC Shop!" (optional, press Enter for default).
- Privacy Policy: Custom text (optional, press Enter for default).

It will create config files, example products, and directories. Setup complete!

## Starting the Bot
To run the bot:

```bash
./start.sh
```

This starts two background processes: the bot (handles Telegram messages) and the monitor (checks for incoming payments on XDC blockchain).

To stop:

```bash
./stop.sh
```

To reset logs/states (if something goes wrong):

```bash
./reset.sh
```

## Usage

### For Customers
1. They start chatting with your bot on Telegram (share the bot username).
2. Type `/start` (or any random text really).
3. Accept privacy policy.
4. If excluded countries set, get the user to confirm they're not from there.
5. See product list.
6. Reply with product ID to buy.
7. Send exact XDC amount to your address (bot gives instructions).
8. After payment has been received, bot sends success message (e.g., access code or digital product download links).

### For You (Admin/Owner)
Chat with your bot on Telegram. Only your User ID can use the special `/admin` command to open the Admin menu through which you can:

1. List all items (shows IDs, names, prices, and success messages).
2. Add an item (prompts for ID, name, currency (XDC/USD), price, and success message).
3. Delete an item (by ID).
4. Set new success message (for an existing item ID).
5. Set new welcome title.
6. Set new privacy policy.
7. Set excluded countries (comma-separated or "none").
0. Exit admin menu.

Products are stored in `items.csv` (but edit via commands to avoid mistakes). Success messages in `messages/` folder as `.txt` files.

Sales logged in `success_log.csv` for your records.

## Troubleshooting
- Bot not responding? Check `bot_output.log`, `monitor_output.log` and `bot_log.txt` for errors.
- Payment not detecting? Ensure your RPC_URL in `config.sh` works (default is public).
- Need to change config? Edit `config.sh` manually or re-run `setup.sh`. This will be refined further as we go along.

## Security Notes
- Keep your bot token private.
- Run on a secure VPS with firewall (e.g., `ufw allow ssh; ufw enable`).
- Bot uses flock for concurrency

## License
MIT License – free to use and modify.

Happy selling with XDC! If you get stuck, ask in XDC communities (Or contact me thru [XDC Outpost](https://s4njk4n.github.io/XDCOutpost/)  ). 🚀
