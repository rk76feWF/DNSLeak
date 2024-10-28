#!/bin/bash

TLD_LIST="tld.txt"
LOG_FILE="log.txt"

# Clear the log file at the start
> "$LOG_FILE"

while read -r tld; do
    echo "Checking AXFR for $tld" >> "$LOG_FILE"

    # Get the authoritative name servers for the TLD
    auth_servers=$(dig $tld -t ns +short)

    for server in $auth_servers; do
        # Get the IP address of the name server
        ip=$(dig $server -t a +short | head -n 1)

        if [ -n "$ip" ]; then
            echo "Trying AXFR on $server ($ip) for $tld" >> "$LOG_FILE"
            
            # Attempt zone transfer and store the output in a temporary file
            tmp_output=$(mktemp)
            dig $tld @$ip axfr > "$tmp_output"
            
            # Check if the AXFR was successful (non-empty file)
            if grep -q "Transfer failed." "$tmp_output"; then
                echo "AXFR failed for $tld on $server ($ip)" >> "$LOG_FILE"
            else
                # Save the zone data if AXFR was successful
                if [ "$tld" == "." ]; then
                    zone_file="root.zone"
                else
                    zone_file="${tld}.zone"
                fi
                mv "$tmp_output" "records/$zone_file"
                echo "AXFR succeeded for $tld. Zone data saved to $zone_file" >> "$LOG_FILE"
            fi
        else
            echo "No IPv4 address found for $server" >> "$LOG_FILE"
        fi
        sleep 0.1
    done
    sleep 2
done < "$TLD_LIST"

