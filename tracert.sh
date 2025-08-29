#!/bin/bash

# Script to perform traceroute analysis for CS 3873 Homework on Raspberry Pi
# Runs immediately and then every 2 hours, generating a report with error handling
# Requires: bc for calculations, sudo for traceroute

# Destinations
DEST1="www.nyse.com"          # Intra-continent (North America)
DEST2="www.londonstockexchange.com"  # Inter-continent (Europe)

# Log and report files
LOG_FILE="traceroute_analysis_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="traceroute_report_$(date +%Y%m%d_%H%M%S).txt"

# Function to check if traceroute is available
check_traceroute() {
    if ! command -v traceroute >/dev/null 2>&1; then
        echo "Error: traceroute is not installed. Please install it with 'sudo apt install traceroute'." >> "$LOG_FILE"
        exit 1
    fi
}

# Function to run traceroute and process results with enhanced error handling
run_traceroute_analysis() {
    local dest=$1
    local probe_type=$2
    local timestamp=$(date +%H:%M:%S)
    local output_file="traceroute_${dest}_${timestamp//:/-}_${probe_type}.txt"
    local hops=()

    echo "=== Traceroute Analysis for $dest at $timestamp (Probe: $probe_type) ===" >> "$LOG_FILE"
    echo "Running traceroute to $dest..." >> "$LOG_FILE"

    # Run traceroute with IPv4 and specified probe type, capturing detailed errors
    local traceroute_cmd=""
    case $probe_type in
        "icmp")
            traceroute_cmd="sudo traceroute -I -4 -q 5 -m 50 -w 5 -n \"$dest\""
            ;;
        "tcp")
            traceroute_cmd="sudo traceroute -T -4 -p 80 -q 5 -m 50 -w 5 -n \"$dest\""
            ;;
        "udp")
            traceroute_cmd="sudo traceroute -4 -q 5 -m 50 -w 5 -n \"$dest\""
            ;;
        *)
            echo "Invalid probe type. Use 'icmp', 'tcp', or 'udp'." >> "$LOG_FILE"
            exit 1
            ;;
    esac

    if ! eval "$traceroute_cmd" > "$output_file" 2>> "$LOG_FILE"; then
        echo "Traceroute failed with $probe_type. Check log for details." >> "$LOG_FILE"
    else
        echo "Traceroute completed successfully with $probe_type." >> "$LOG_FILE"
    fi

    # Process traceroute output with robust error checking
    local line_num=1
    if [ -s "$output_file" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+ ]]; then
                hop=$(echo "$line" | awk '{print $2}')
                if [[ ! $hop =~ ^\*$ ]]; then
                    # Extract RTTs, handling asterisks and invalid data
                    rtts=$(echo "$line" | awk '{for(i=3;i<=NF;i++) if($i~/^[0-9]+\.?[0-9]*$/ && $i!~/^\*$/){print $i}}')
                    rtt_count=$(echo "$rtts" | wc -w)
                    if [ $rtt_count -gt 0 ]; then
                        avg_rtt=$(echo "$rtts" | tr ' ' '\n' | awk '{sum+=$1} END {if (NR>0) print sum/NR}')
                        std_dev=$(echo "$rtts" | tr ' ' '\n' | awk -v avg="$avg_rtt" '{sum+=($1-avg)^2} END {if (NR>1) print sqrt(sum/(NR-1))}')
                        reverse_dns=$(nslookup "$hop" 2>/dev/null | awk '/name =/ {print $4}' | head -1 || echo "(No reverse DNS)")
                        hops+=("$line_num:$hop:$avg_rtt:$std_dev:$reverse_dns")
                        echo "Hop $line_num: IP $hop, Avg RTT $avg_rtt ms, Std Dev $std_dev ms, DNS $reverse_dns" >> "$LOG_FILE"
                    else
                        echo "No valid RTT data for Hop $line_num: $line" >> "$LOG_FILE"
                    fi
                else
                    echo "Hop $line_num timed out: $line" >> "$LOG_FILE"
                fi
                ((line_num++))
            fi
        done < "$output_file"
    else
        echo "No traceroute data captured in $output_file" >> "$LOG_FILE"
    fi

    # Calculate total routers and ISP count
    local router_count=$((line_num - 1))
    local isp_count=1
    local prev_isp_prefix=""
    for hop in "${hops[@]}"; do
        ip=$(echo "$hop" | cut -d':' -f2)
        if [[ $ip =~ ^[0-9]+\.[0-9]+\. ]]; then
            isp_prefix=$(echo "$ip" | cut -d'.' -f1-3)  # Use first three bytes
            if [ "$isp_prefix" != "$prev_isp_prefix" ] && [ -n "$prev_isp_prefix" ]; then
                ((isp_count++))
            fi
            prev_isp_prefix="$isp_prefix"
        fi
    done

    echo "Total Routers: $router_count" >> "$LOG_FILE"
    echo "ISP Networks: $isp_count" >> "$LOG_FILE"
    echo "------------------------------------------------" >> "$LOG_FILE"

    # Append to report
    echo "=== Report for $dest at $timestamp (Probe: $probe_type) ===" >> "$REPORT_FILE"
    echo "Total Routers: $router_count" >> "$REPORT_FILE"
    echo "ISP Networks: $isp_count" >> "$REPORT_FILE"
    for hop in "${hops[@]}"; do
        line_num=$(echo "$hop" | cut -d':' -f1)
        ip=$(echo "$hop" | cut -d':' -f2)
        avg_rtt=$(echo "$hop" | cut -d':' -f3)
        std_dev=$(echo "$hop" | cut -d':' -f4)
        dns=$(echo "$hop" | cut -d':' -f5)
        echo "Hop $line_num: IP $ip, Avg RTT $avg_rtt ms, Std Dev $std_dev ms, DNS $dns" >> "$REPORT_FILE"
    done
    echo "------------------------------------------------" >> "$REPORT_FILE"
}

# Main execution: run immediately and then every 2 hours
check_traceroute
timestamp=$(date +%H:%M:%S)
echo "Starting initial run at $timestamp" >> "$LOG_FILE"
for dest in "$DEST1" "$DEST2"; do
    for probe in "icmp" "tcp" "udp"; do
        run_traceroute_analysis "$dest" "$probe"
    done
done

# Schedule every 2 hours (7200 seconds) for two more runs
for i in {1..2}; do
    sleep 7200  # 2 hours
    timestamp=$(date +%H:%M:%S)
    echo "Starting run at $timestamp (Run $i)" >> "$LOG_FILE"
    for dest in "$DEST1" "$DEST2"; do
        for probe in "icmp" "tcp" "udp"; do
            run_traceroute_analysis "$dest" "$probe"
        done
    done
done >> "$LOG_FILE" 2>&1 &

echo "Traceroute analysis started in background. Log: $LOG_FILE, Report: $REPORT_FILE"
echo "Initial run completed, subsequent runs at approximately 07:54 PM and 09:54 PM CDT."
echo "Check files for results and capture screenshots for submission."