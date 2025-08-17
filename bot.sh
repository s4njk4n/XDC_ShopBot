#!/bin/bash
source config.sh

# Function to log events (with size check)
log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    if [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"  # Rotate; delete old if needed
        touch "$LOG_FILE"
    fi
}

# Function to send Telegram message (sanitize text, but preserve newlines)
send_message() {
    local chat_id=$1
    local text=$(echo "$2" | sed 's/[\"\\]/\\&/g')  # Escape quotes/backslashes, no tr -d \n
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d chat_id="$chat_id" -d text="$text" > /dev/null
    log_event "Sent to $chat_id: $text"
}

# Overload for HTML messages
send_html_message() {
    local chat_id=$1
    local text="$2"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
         -d chat_id="$chat_id" -d text="$text" -d parse_mode="HTML" > /dev/null
    log_event "Sent HTML to $chat_id: $text (raw: $text)"
}

# Function to get or set user state (with flock for concurrency)
get_state() {
    local user_id=$1
    local state_file="states/$user_id.state"
    (
    flock -x 200  # Lock
    if [ -f "$state_file" ]; then
        cat "$state_file"
    else
        echo "state:start"
    fi
    ) 200>"$state_file.lock"
}

set_state() {
    local user_id=$1
    local new_state=$2
    local state_file="states/$user_id.state"
    (
    flock -x 200
    echo "$new_state" > "$state_file"
    ) 200>"$state_file.lock"
    log_event "Set state for $user_id: $new_state"
}

# Function to sanitize user input (prevent injection; alphanum + basic chars)
sanitize_input() {
    echo "$1" | sed 's/[^a-zA-Z0-9 .,:_/!\-]//g'  # Moved - to the end
}

# Function to escape HTML special chars
escape_html() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# Main loop for polling Telegram updates
offset=0
while true; do
    updates=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getUpdates?offset=$offset&timeout=30")
    if [ -z "$updates" ] || [ "$(echo "$updates" | jq '.ok')" != "true" ]; then
        sleep $POLL_INTERVAL
        continue
    fi

    mapfile -t results < <(echo "$updates" | jq -c '.result[]' 2>/dev/null)
    for update in "${results[@]}"; do
        update_id=$(echo "$update" | jq '.update_id')

        message=$(echo "$update" | jq '.message')
        [ "$message" = "null" ] && continue

        chat_id=$(echo "$message" | jq '.chat.id')
        user_id=$(echo "$message" | jq '.from.id')
        raw_text=$(echo "$update" | jq -r '.message.text')  # Raw for commands

        log_event "Raw text received from $user_id: $raw_text"

        # Handle /start reset at any point (using raw_text)
        if [[ "${raw_text,,}" == "/start" ]]; then
            # Clear pending if exists
            pending_file="$PENDING_DIR/$user_id.pending"
            [ -f "$pending_file" ] && rm "$pending_file"
            # Send welcome message immediately
            WELCOME_TITLE=$(cat welcome_title.txt)
            PRIVACY_POLICY=$(cat privacy_policy.txt)
            welcome_message=$(printf '<b>%s</b>\n\nYou can type /start at any time to restart the conversation.\n\n%s' "$WELCOME_TITLE" "$PRIVACY_POLICY")
            send_html_message "$chat_id" "$welcome_message"
            set_state "$user_id" "state:await_policy"
            continue  # Skip to next update
        fi

        text=$(sanitize_input "$raw_text")

        log_event "Sanitized text: $text"

        if [ -z "$text" ] || [ "$text" = "null" ]; then
            send_message "$chat_id" "Please respond with text (Yes/No)."
            continue
        fi

        current_state=$(get_state "$user_id")

        # Handle /cancel in admin states
        if [[ "${raw_text,,}" == "/cancel" ]] && [[ "$current_state" == admin* ]]; then
            send_message "$chat_id" "Admin action cancelled."
            set_state "$user_id" "state:start"
            continue
        fi

        # Admin commands (only for owner)
        if [ "$user_id" == "$OWNER_ID" ]; then
            if [[ "$raw_text" == "/additem" ]]; then
                send_message "$chat_id" "Enter the item ID (numeric, unique):"
                set_state "$user_id" "admin:add_item_id"
                continue
            elif [[ "$raw_text" == "/delitem "* ]]; then
                id="${raw_text#/delitem }"
                id=$(sanitize_input "$id")
                if grep -q "^$id," "$ITEMS_CSV"; then
                    sed -i "/^$id,/d" "$ITEMS_CSV"
                    send_message "$chat_id" "Item $id deleted."
                else
                    send_message "$chat_id" "Item $id not found."
                fi
                continue
            elif [[ "$raw_text" == "/setmessage" ]]; then
                send_message "$chat_id" "Enter the message basename (e.g., product_a_success):"
                set_state "$user_id" "admin:set_message_basename"
                continue
            elif [[ "$raw_text" == "/listitems" ]]; then
                items_list=$(awk -F, 'NR>1 && $1 ~ /^[0-9]+$/ {
                    name = $2
                    gsub(/&/, "&amp;", name); gsub(/</, "&lt;", name); gsub(/>/, "&gt;", name); gsub(/"/, "&quot;", name)
                    printf "- <b>ID %s:</b> %s - %s %s\n", $1, name, $3, $4
                }' "$ITEMS_CSV")
                if [ -z "$items_list" ]; then
                    send_message "$chat_id" "No items available."
                else
                    full_message=$'Current items:\n'"$items_list"
                    send_html_message "$chat_id" "$full_message"
                fi
                continue
            elif [[ "$raw_text" == "/setwelcometitle" ]]; then
                send_message "$chat_id" "Enter the new welcome title:"
                set_state "$user_id" "admin:set_welcome_title"
                continue
            elif [[ "$raw_text" == "/setpolicy" ]]; then
                send_message "$chat_id" "Enter the new privacy policy text (multi-line OK):"
                set_state "$user_id" "admin:set_policy"
                continue
            elif [[ "$raw_text" == "/setexcluded" ]]; then
                send_message "$chat_id" "Enter excluded countries (comma-separated, empty for none):"
                set_state "$user_id" "admin:set_excluded"
                continue
            fi
        fi

        # State machine
        case "$current_state" in
            state:start)
                WELCOME_TITLE=$(cat welcome_title.txt)
                PRIVACY_POLICY=$(cat privacy_policy.txt)
                welcome_message=$(printf '<b>%s</b>\n\nYou can type /start at any time to restart the conversation.\n\n%s' "$WELCOME_TITLE" "$PRIVACY_POLICY")
                send_html_message "$chat_id" "$welcome_message"
                set_state "$user_id" "state:await_policy"
                ;;
            state:await_policy)
                text_lower="${text,,}"

                if [ "$text_lower" = "yes" ]; then
                    EXCLUDED_COUNTRIES=$(cat excluded_countries.txt)
                    if [ -z "$EXCLUDED_COUNTRIES" ]; then
                        # Proceed to items
                        items_list=$(awk -F, 'NR>1 && $1 ~ /^[0-9]+$/ {
                            name = $2
                            gsub(/&/, "&amp;", name); gsub(/</, "&lt;", name); gsub(/>/, "&gt;", name); gsub(/"/, "&quot;", name)
                            printf "- <b>ID %s:</b> %s - %s %s\n", $1, name, $3, $4
                        }' "$ITEMS_CSV")

                        if [ -z "$items_list" ]; then
                            full_message=$'No items currently available. Check back later!'
                        else
                            full_message=$'Available items:\n'"$items_list"$'\n\nReply with the ID number (e.g., \'1\') to select and purchase an item.'
                        fi

                        send_html_message "$chat_id" "$full_message"
                        set_state "$user_id" "state:select_item"
                    else
                        country_message="Are you a resident of any of the following countries: $EXCLUDED_COUNTRIES? (Yes/No)"
                        send_message "$chat_id" "$country_message"
                        set_state "$user_id" "state:await_country_check"
                    fi
                elif [ "$text_lower" = "no" ]; then
                    send_message "$chat_id" "Declined. Goodbye."
                    set_state "$user_id" "state:start"
                else
                    send_message "$chat_id" "Please reply with 'Yes' to accept or 'No' to decline the privacy policy."
                fi
                ;;
            state:await_country_check)
                text_lower="${text,,}"
                if [ "$text_lower" = "yes" ]; then
                    send_message "$chat_id" "Sorry, we cannot serve residents of those countries. Goodbye."
                    set_state "$user_id" "state:start"
                elif [ "$text_lower" = "no" ]; then
                    items_list=$(awk -F, 'NR>1 && $1 ~ /^[0-9]+$/ {
                        name = $2
                        gsub(/&/, "&amp;", name); gsub(/</, "&lt;", name); gsub(/>/, "&gt;", name); gsub(/"/, "&quot;", name)
                        printf "- <b>ID %s:</b> %s - %s %s\n", $1, name, $3, $4
                    }' "$ITEMS_CSV")

                    if [ -z "$items_list" ]; then
                        full_message=$'No items currently available. Check back later!'
                    else
                        full_message=$'Available items:\n\n'"$items_list"$'\n\nReply with the ID number (e.g., \'1\') to select and purchase an item.'
                    fi

                    send_html_message "$chat_id" "$full_message"
                    set_state "$user_id" "state:select_item"
                else
                    send_message "$chat_id" "Please reply with 'Yes' or 'No'."
                fi
                ;;
            state:select_item)
                item_id=$(sanitize_input "$text")
                item=$(grep "^$item_id," "$ITEMS_CSV")
                if [ -z "$item" ]; then
                    send_message "$chat_id" "Invalid item. Try again."
                    continue
                fi

                price=$(echo "$item" | cut -d, -f3)
                currency=$(echo "$item" | cut -d, -f4)

                if [ "$currency" = "USD" ]; then
                    xdc_usd=$(curl -s "$PRICE_API" | jq -r '.price')
                    if [ -z "$xdc_usd" ] || [ "$xdc_usd" = "null" ] || ! echo "$xdc_usd" | grep -qE '^[0-9]+\.[0-9]+$'; then
                        send_message "$chat_id" "Price fetch failed. Please try again later."
                        continue
                    fi
                    xdc_amount=$(echo "scale=5; $price / $xdc_usd" | bc)
                    if [ -z "$xdc_amount" ] || [ $(echo "$xdc_amount < 1" | bc) -eq 1 ]; then
                        send_message "$chat_id" "Price calculation error."
                        continue
                    fi
                else
                    xdc_amount="$price"
                fi

                # Random subtract (e.g., 0.00001 to 0.99999 XDC, 5 decimals)
                random_sub=$(awk -v seed=$RANDOM 'BEGIN {srand(seed); printf "%.5f", rand()}')
                expected_amount=$(echo "scale=5; $xdc_amount - $random_sub" | bc | sed 's/^\./0./')

                # Convert to wei for RPC (XDC has 18 decimals)
                expected_wei=$(echo "$expected_amount * 10^18" | bc | cut -d. -f1)

                # Save pending
                pending_file="$PENDING_DIR/$user_id.pending"
                (
                flock -x 200
                echo "expected_amount:$expected_amount" > "$pending_file"
                echo "expected_wei:$expected_wei" >> "$pending_file"
                echo "timeout:$(($(date +%s) + $PAYMENT_TIMEOUT))" >> "$pending_file"
                echo "item_id:$item_id" >> "$pending_file"
                ) 200>"$pending_file.lock"

                # Payment instructions
                o_address="0x${SELLER_ADDRESS#xdc}"
                send_message "$chat_id" "Send exactly $expected_amount XDC to $SELLER_ADDRESS (or $o_address if your wallet requires 0x). You have 10 minutes."
                set_state "$user_id" "state:await_payment"
                ;;
            state:await_payment)
                send_message "$chat_id" "Payment pending. Wait for confirmation."
                ;;
            admin:add_item_id)
                id="$raw_text"  # No sanitize for admin
                if ! [[ "$id" =~ ^[0-9]+$ ]] || grep -q "^$id," "$ITEMS_CSV"; then
                    send_message "$chat_id" "Invalid or duplicate ID. Try again or /cancel."
                else
                    send_message "$chat_id" "Enter item name:"
                    set_state "$user_id" "admin:add_item_name:$id"
                fi
                ;;
            admin:add_item_name:*)
                name="$raw_text"
                id="${current_state#admin:add_item_name:}"
                if [[ "$name" == *","* ]]; then
                    send_message "$chat_id" "Name cannot contain commas. Try again or /cancel."
                else
                    send_message "$chat_id" "Enter price (numeric):"
                    set_state "$user_id" "admin:add_item_price:$id:$name"
                fi
                ;;
            admin:add_item_price:*)
                price="$raw_text"
                params="${current_state#admin:add_item_price:}"
                id="${params%%:*}"
                name="${params#*:}"
                if ! echo "$price" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                    send_message "$chat_id" "Invalid price. Try again or /cancel."
                else
                    send_message "$chat_id" "Enter currency (XDC or USD):"
                    set_state "$user_id" "admin:add_item_currency:$id:$name:$price"
                fi
                ;;
            admin:add_item_currency:*)
                currency="${raw_text^^}"
                params="${current_state#admin:add_item_currency:}"
                id="${params%%:*}"
                params="${params#*:}"
                name="${params%%:*}"
                price="${params#*:}"
                if [ "$currency" != "XDC" ] && [ "$currency" != "USD" ]; then
                    send_message "$chat_id" "Invalid currency. Try again or /cancel."
                else
                    send_message "$chat_id" "Enter message basename (e.g., product_c_success):"
                    set_state "$user_id" "admin:add_item_basename:$id:$name:$price:$currency"
                fi
                ;;
            admin:add_item_basename:*)
                basename="$raw_text"
                params="${current_state#admin:add_item_basename:}"
                id="${params%%:*}"
                params="${params#*:}"
                name="${params%%:*}"
                params="${params#*:}"
                price="${params%%:*}"
                currency="${params#*:}"
                echo "$id,$name,$price,$currency,$basename" >> "$ITEMS_CSV"
                send_message "$chat_id" "Item added: ID $id - $name - $price $currency ($basename)"
                set_state "$user_id" "state:start"
                ;;
            admin:set_message_basename)
                basename="$raw_text"
                send_message "$chat_id" "Enter the success message text (multi-line OK):"
                set_state "$user_id" "admin:set_message_text:$basename"
                ;;
            admin:set_message_text:*)
                text="$raw_text"
                basename="${current_state#admin:set_message_text:}"
                echo "$text" > "$MESSAGES_DIR/$basename.txt"
                send_message "$chat_id" "Success message set for $basename."
                set_state "$user_id" "state:start"
                ;;
            admin:set_welcome_title)
                text="$raw_text"
                echo "$text" > welcome_title.txt
                send_message "$chat_id" "Welcome title updated."
                set_state "$user_id" "state:start"
                ;;
            admin:set_policy)
                text="$raw_text"
                echo "$text" > privacy_policy.txt
                send_message "$chat_id" "Privacy policy updated."
                set_state "$user_id" "state:start"
                ;;
            admin:set_excluded)
                text="$raw_text"
                echo "$text" > excluded_countries.txt
                send_message "$chat_id" "Excluded countries updated."
                set_state "$user_id" "state:start"
                ;;
            *)
                send_message "$chat_id" "Unknown state. /start to reset."
                set_state "$user_id" "state:start"
                ;;
        esac
    done

    if [ ${#results[@]} -gt 0 ]; then
        last_id=$(echo "${results[${#results[@]}-1]}" | jq '.update_id')
        offset=$((last_id + 1))
        log_event "Updated offset to $offset after processing batch"
    fi

    sleep $POLL_INTERVAL
done
