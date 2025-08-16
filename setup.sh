#!/bin/bash

echo "Welcome to the XDC ShopBot setup script."
echo "This will configure your bot. You'll need your Telegram Bot Token (from BotFather), your XDC seller address, and your Telegram User ID (for admin access)."
echo "You can find your Telegram User ID by talking to @userinfobot or similar."
echo ""

read -p "Enter Telegram Bot Token: " TELEGRAM_TOKEN
read -p "Enter Seller XDC Address (starting with 'xdc' or '0x'): " SELLER_ADDRESS
read -p "Enter your Telegram User ID (numeric): " OWNER_ID
read -p "Enter excluded countries (comma-separated, e.g., 'US,CA,RU'; leave empty to skip country check): " EXCLUDED_COUNTRIES
read -p "Enter welcome title (default: 'Welcome to My XDC Shop!'): " WELCOME_TITLE_INPUT
WELCOME_TITLE_INPUT=${WELCOME_TITLE_INPUT:-"Welcome to My XDC Shop!"}
read -p "Enter privacy policy text (default: 'Our privacy policy: We collect minimal data (Telegram user ID, purchase details) for legal compliance. Data is retained for 7 years per our local compliance obligations. No sharing with third parties without consent. Accept? (Yes/No)'): " PRIVACY_POLICY_INPUT
PRIVACY_POLICY_INPUT=${PRIVACY_POLICY_INPUT:-"Our privacy policy: We collect minimal data (Telegram user ID, purchase details) for legal compliance. Data is retained for 7 years per our local compliance obligations. No sharing with third parties without consent. Accept? (Yes/No)"}

# Normalize SELLER_ADDRESS to 'xdc' prefix
SELLER_ADDRESS=$(echo "$SELLER_ADDRESS" | tr 'A-F' 'a-f')  # Lowercase hex
if [[ "$SELLER_ADDRESS" == 0x* ]]; then
    SELLER_ADDRESS="xdc${SELLER_ADDRESS#0x}"
elif [[ "$SELLER_ADDRESS" != xdc* ]]; then
    SELLER_ADDRESS="xdc$SELLER_ADDRESS"
fi

# Create directories
mkdir -p messages pending states

# Initialize files
echo "id,name,price,currency,message_basename" > items.csv
echo "$EXCLUDED_COUNTRIES" > excluded_countries.txt
echo "$WELCOME_TITLE_INPUT" > welcome_title.txt
echo "$PRIVACY_POLICY_INPUT" > privacy_policy.txt
touch success_log.csv
echo "timestamp,user_id,item_id,amount_xdc,tx_hash" > success_log.csv

# Example items (optional; user can add via bot)
echo "1,Product A,1,XDC,product_a_success" >> items.csv
echo "2,Service B,2,USD,service_b_success" >> items.csv

# Example messages
echo "Thanks for buying Product A! Your access code is XYZ." > messages/product_a_success.txt
echo "Thanks for buying Product B! Your access code is XYZ." > messages/service_b_success.txt

# Generate config.sh
cat > config.sh <<EOF
#!/bin/bash

# Telegram Bot API Token from BotFather
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"

# Seller's XDC address (xdc prefix; script will handle 0x conversion)
SELLER_ADDRESS="$SELLER_ADDRESS"

# Owner's Telegram User ID (for admin commands)
OWNER_ID="$OWNER_ID"

# RPC URL for XDC network (use a public one or your own node)
RPC_URL="https://rpc.ankr.com/xdc"

# Bitrue API for USD to XDC conversion
PRICE_API="https://openapi.bitrue.com/api/v1/ticker/price?symbol=XDCUSDT"

# Items CSV path
ITEMS_CSV="items.csv"

# Messages directory
MESSAGES_DIR="messages"

# Payment timeout in seconds
PAYMENT_TIMEOUT=600  # 10 minutes

# Poll interval for Telegram updates (seconds)
POLL_INTERVAL=2

# Monitor interval for RPC (seconds)
MONITOR_INTERVAL=5

# Number of recent blocks to check per monitor cycle
BLOCKS_TO_CHECK=10

# Log file and max size (bytes; e.g., 500MB)
LOG_FILE="bot_log.txt"
MAX_LOG_SIZE=524288000

# Success log CSV
SUCCESS_LOG="success_log.csv"

# Pending payments dir
PENDING_DIR="pending"
EOF

chmod +x config.sh bot.sh monitor.sh start.sh stop.sh reset.sh

echo ""
echo "####################"
echo ""
echo "Setup complete! Configuration saved to config.sh."
echo ""
echo "####################"
echo ""
echo "You can now run './start.sh' to start the bot."
echo ""
echo "To configure items and messages, use admin commands in Telegram (e.g., /additem, /setmessage) as the owner."
echo ""
echo "Run './reset.sh' on the VPS to clear logs and states if needed."
echo ""
echo "####################"
