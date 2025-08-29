#!/bin/bash

# Enhanced Network Analysis Tool with AI Integration
# For CS3873 Network Measurement Lab - Wheeler

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Global variables
RESULTS=""
SAVE_TO_FILE="no"
OUTPUT_FILE=""

# Function to add results
add_result() {
    local message="$1"
    echo -e "$message"
    RESULTS+="$message\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get user input
get_user_input() {
    local prompt="$1"
    local default="$2"
    local input

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        input=${input:-$default}
    else
        read -p "$prompt: " input
    fi

    echo "$input"
}

# Function to validate IP address or hostname
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    elif [[ $ip =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test basic connectivity
test_basic_connectivity() {
    local target="$1"

    add_result "${YELLOW}Testing connectivity to $target...${NC}"

    if ! command_exists ping; then
        add_result "${RED}ERROR: ping command not found${NC}"
        return 1
    fi

    # Quick ping test (3 packets)
    PING_OUTPUT=$(ping -c 3 -W 2 "$target" 2>&1)

    if echo "$PING_OUTPUT" | grep -q "3 received\|2 received\|1 received"; then
        add_result "${GREEN}✓ Host $target is reachable${NC}"
        return 0
    else
        add_result "${RED}✗ Host $target is unreachable${NC}"
        return 1
    fi
}

# Function to run comprehensive network scan
run_comprehensive_scan() {
    local target="$1"

    add_result "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
    add_result "${BOLD}${BLUE}    COMPREHENSIVE NETWORK ANALYSIS: $target${NC}"
    add_result "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
    add_result "Generated: $(date)"
    add_result ""

    # 1. PING TEST - RTT Analysis
    add_result "${BOLD}${CYAN}[1] PING TEST - RTT MEASUREMENT${NC}"
    add_result "Running extended ping test (10 packets)..."

    if command_exists ping; then
        PING_OUTPUT=$(ping -c 10 -i 0.5 "$target" 2>&1)

        if echo "$PING_OUTPUT" | grep -q "10 received\|[0-9] received"; then
            add_result "${GREEN}✓ Ping successful${NC}"

            # Extract RTT statistics
            RTT_LINE=$(echo "$PING_OUTPUT" | grep "min/avg/max/mdev\|min/avg/max/stddev")
            if [ -n "$RTT_LINE" ]; then
                RTT_STATS=$(echo "$RTT_LINE" | cut -d'=' -f2)
                MIN_RTT=$(echo "$RTT_STATS" | cut -d'/' -f1 | tr -d ' ')
                AVG_RTT=$(echo "$RTT_STATS" | cut -d'/' -f2)
                MAX_RTT=$(echo "$RTT_STATS" | cut -d'/' -f3)
                STDDEV_RTT=$(echo "$RTT_STATS" | cut -d'/' -f4)

                add_result "  RTT Statistics:"
                add_result "    Minimum: ${MIN_RTT} ms"
                add_result "    Average: ${AVG_RTT} ms"
                add_result "    Maximum: ${MAX_RTT} ms"
                add_result "    Std Dev: ${STDDEV_RTT} ms"
            fi

            # Packet loss
            LOSS_LINE=$(echo "$PING_OUTPUT" | grep "packet loss")
            if [ -n "$LOSS_LINE" ]; then
                LOSS_PERCENT=$(echo "$LOSS_LINE" | grep -o "[0-9]*%" | head -1)
                add_result "    Packet Loss: ${LOSS_PERCENT}"
            fi
        else
            add_result "${RED}✗ Ping failed${NC}"
        fi
    else
        add_result "${RED}✗ ping command not available${NC}"
    fi

    add_result ""

    # 2. PORT SCAN - Service Discovery
    add_result "${BOLD}${CYAN}[2] PORT SCAN - SERVICE DISCOVERY${NC}"
    add_result "Scanning for open ports..."

    if command_exists nmap; then
        # Quick scan of common ports first
        NMAP_OUTPUT=$(nmap -F --open "$target" 2>/dev/null)
        OPEN_PORTS=$(echo "$NMAP_OUTPUT" | grep "^[0-9]" | wc -l)

        if [ "$OPEN_PORTS" -gt 0 ]; then
            add_result "${GREEN}✓ Found $OPEN_PORTS open port(s)${NC}"
            echo "$NMAP_OUTPUT" | grep "^[0-9]" | while read -r line; do
                add_result "    $line"
            done

            # Check specifically for iperf3 server
            IPERF_CHECK=$(nmap -p 5201 --open "$target" 2>/dev/null | grep "^5201")
            if [ -n "$IPERF_CHECK" ]; then
                add_result "${GREEN}    iperf3 server detected on port 5201${NC}"
            fi

            # Scan high ports for additional iperf3 servers (as mentioned in lab)
            add_result "  Scanning high ports (1025-65535) for additional iperf3 servers..."
            HIGH_PORT_SCAN=$(nmap -p 1025-65535 --open "$target" 2>/dev/null | grep "^[0-9]" | head -5)
            if [ -n "$HIGH_PORT_SCAN" ]; then
                add_result "    Additional open high ports:"
                echo "$HIGH_PORT_SCAN" | while read -r line; do
                    add_result "      $line"
                done
            fi
        else
            add_result "${YELLOW}⚠ No open ports found in common range${NC}"
        fi
    else
        add_result "${RED}✗ nmap command not available${NC}"
    fi

    add_result ""

    # 3. IPERF3 TEST - Throughput Measurement
    add_result "${BOLD}${CYAN}[3] IPERF3 TEST - THROUGHPUT MEASUREMENT${NC}"
    add_result "Testing TCP throughput..."

    if command_exists iperf3; then
        # Test default port first
        IPERF_OUTPUT=$(timeout 30 iperf3 -c "$target" -t 10 -i 2 2>&1)

        if echo "$IPERF_OUTPUT" | grep -q "bits/sec" && [ $? -eq 0 ]; then
            add_result "${GREEN}✓ iperf3 TCP test successful (port 5201)${NC}"

            # Extract throughput data
            SENDER_LINE=$(echo "$IPERF_OUTPUT" | grep "sender" | tail -1)
            RECEIVER_LINE=$(echo "$IPERF_OUTPUT" | grep "receiver" | tail -1)

            if [ -n "$SENDER_LINE" ]; then
                SENDER_SPEED=$(echo "$SENDER_LINE" | awk '{for(i=1;i<=NF;i++) if($i ~ /bits\/sec/) print $(i-1), $i}' | head -1)
                add_result "    Upload (Sender): ${SENDER_SPEED}"
            fi

            if [ -n "$RECEIVER_LINE" ]; then
                RECEIVER_SPEED=$(echo "$RECEIVER_LINE" | awk '{for(i=1;i<=NF;i++) if($i ~ /bits\/sec/) print $(i-1), $i}' | head -1)
                add_result "    Download (Receiver): ${RECEIVER_SPEED}"
            fi

            # UDP test
            add_result "  Testing UDP throughput..."
            UDP_OUTPUT=$(timeout 15 iperf3 -c "$target" -u -t 5 2>&1)
            if echo "$UDP_OUTPUT" | grep -q "bits/sec"; then
                UDP_SPEED=$(echo "$UDP_OUTPUT" | grep "receiver" | awk '{for(i=1;i<=NF;i++) if($i ~ /bits\/sec/) print $(i-1), $i}' | head -1)
                add_result "    UDP Throughput: ${UDP_SPEED}"

                # Check packet loss
                if echo "$UDP_OUTPUT" | grep -q "(.*%)"; then
                    LOSS=$(echo "$UDP_OUTPUT" | grep -o "([^)]*%)" | head -1)
                    add_result "    UDP Packet Loss: ${LOSS}"
                fi
            fi

        else
            add_result "${RED}✗ iperf3 test failed on default port${NC}"
            add_result "    No iperf3 server found on port 5201"
        fi
    else
        add_result "${RED}✗ iperf3 command not available${NC}"
    fi

    add_result ""

    # 4. TRACEROUTE - Path Analysis
    add_result "${BOLD}${CYAN}[4] TRACEROUTE - NETWORK PATH ANALYSIS${NC}"
    add_result "Tracing network path..."

    if command_exists traceroute; then
        TRACE_OUTPUT=$(traceroute -n "$target" 2>&1)

        if echo "$TRACE_OUTPUT" | grep -q "traceroute to"; then
            add_result "${GREEN}✓ Traceroute completed${NC}"

            # Count hops
            HOP_COUNT=$(echo "$TRACE_OUTPUT" | grep -E "^\s*[0-9]+" | wc -l)
            add_result "    Number of hops: ${HOP_COUNT}"

            # Calculate RTT statistics from traceroute
            RTT_VALUES=$(echo "$TRACE_OUTPUT" | grep -oE "[0-9]+\.[0-9]+ ms" | grep -oE "[0-9]+\.[0-9]+")
            if [ -n "$RTT_VALUES" ]; then
                RTT_COUNT=$(echo "$RTT_VALUES" | wc -l)
                if [ "$RTT_COUNT" -gt 0 ]; then
                    MIN_TRACE_RTT=$(echo "$RTT_VALUES" | sort -n | head -1)
                    MAX_TRACE_RTT=$(echo "$RTT_VALUES" | sort -n | tail -1)
                    AVG_TRACE_RTT=$(echo "$RTT_VALUES" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')

                    add_result "    Traceroute RTT Range: ${MIN_TRACE_RTT} - ${MAX_TRACE_RTT} ms"
                    add_result "    Traceroute RTT Average: ${AVG_TRACE_RTT} ms"
                fi
            fi

            # Show first and last few hops
            add_result "  Path Summary (first 3 and last 3 hops):"
            FIRST_HOPS=$(echo "$TRACE_OUTPUT" | grep -E "^\s*[1-3]\s" | head -3)
            LAST_HOPS=$(echo "$TRACE_OUTPUT" | grep -E "^\s*[0-9]+\s" | tail -3)

            if [ -n "$FIRST_HOPS" ]; then
                echo "$FIRST_HOPS" | while read -r line; do
                    add_result "    $line"
                done
            fi

            if [ "$HOP_COUNT" -gt 6 ]; then
                add_result "    ..."
            fi

            if [ -n "$LAST_HOPS" ] && [ "$HOP_COUNT" -gt 3 ]; then
                echo "$LAST_HOPS" | while read -r line; do
                    add_result "    $line"
                done
            fi
        else
            add_result "${RED}✗ Traceroute failed${NC}"
        fi
    else
        add_result "${RED}✗ traceroute command not available${NC}"
    fi

    add_result ""

    # 5. PING THROUGHPUT ESTIMATION (as required by lab)
    add_result "${BOLD}${CYAN}[5] PING THROUGHPUT ESTIMATION${NC}"
    add_result "Estimating throughput using variable ping packet sizes..."

    if command_exists ping; then
        SIZES=(64 256 512 1024 1472)
        declare -a ping_results

        for size in "${SIZES[@]}"; do
            PING_SIZE_OUTPUT=$(ping -c 3 -s "$size" "$target" 2>&1)

            if echo "$PING_SIZE_OUTPUT" | grep -q "min/avg/max"; then
                AVG_RTT=$(echo "$PING_SIZE_OUTPUT" | grep "min/avg/max" | cut -d'=' -f2 | cut -d'/' -f2)
                ping_results+=("${size}:${AVG_RTT}")
                add_result "    ${size}B packets: ${AVG_RTT} ms average RTT"
            else
                add_result "    ${size}B packets: Failed"
            fi
        done

        # Calculate throughput estimates
        if [ ${#ping_results[@]} -ge 2 ]; then
            add_result "  Throughput Estimates:"

            for ((i=1; i<${#ping_results[@]}; i++)); do
                prev_data="${ping_results[$((i-1))]}"
                curr_data="${ping_results[$i]}"

                prev_size=$(echo "$prev_data" | cut -d':' -f1)
                prev_rtt=$(echo "$prev_data" | cut -d':' -f2)
                curr_size=$(echo "$curr_data" | cut -d':' -f1)
                curr_rtt=$(echo "$curr_data" | cut -d':' -f2)

                if [[ "$prev_rtt" =~ ^[0-9]*\.?[0-9]+$ ]] && [[ "$curr_rtt" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                    size_diff=$((curr_size - prev_size))
                    if command_exists bc; then
                        rtt_diff=$(echo "$curr_rtt - $prev_rtt" | bc -l 2>/dev/null)

                        if [ "$(echo "$rtt_diff > 0" | bc -l 2>/dev/null)" = "1" ]; then
                            throughput_bps=$(echo "scale=0; ($size_diff * 8) / ($rtt_diff / 1000)" | bc -l 2>/dev/null)
                            throughput_mbps=$(echo "scale=2; $throughput_bps / 1000000" | bc -l 2>/dev/null)
                            add_result "      ${prev_size}B→${curr_size}B: ~${throughput_mbps} Mbps"
                        fi
                    fi
                fi
            done
            add_result "  Note: These are rough estimates based on ping RTT differences"
        fi
    fi

    add_result ""

    # 6. PACKET SIZE IMPACT ANALYSIS
    add_result "${BOLD}${CYAN}[6] PACKET SIZE IMPACT ANALYSIS${NC}"
    add_result "Testing packet loss patterns with different sizes..."

    if command_exists ping; then
        sizes=(64 256 512 1024 1472 8192)
        for size in "${sizes[@]}"; do
            result=$(ping -c 10 -s "$size" "$target" 2>&1)
            loss=$(echo "$result" | grep -o "[0-9]*% packet loss")
            avg_rtt=$(echo "$result" | grep -o "min/avg/max" | head -1)
            if [ -n "$avg_rtt" ]; then
                rtt_val=$(echo "$result" | grep "min/avg/max" | cut -d'=' -f2 | cut -d'/' -f2)
                add_result "  ${size}B packets: $loss (RTT: ${rtt_val} ms)"
            else
                add_result "  ${size}B packets: $loss"
            fi
        done
    fi

    add_result ""

    # 7. RATE-DEPENDENT TESTING
    add_result "${BOLD}${CYAN}[7] RATE-DEPENDENT TESTING${NC}"
    add_result "Testing packet loss at different sending rates..."

    if command_exists ping; then
        # Fast rate test
        fast_result=$(ping -c 20 -i 0.01 "$target" 2>&1 | grep "packet loss")
        add_result "  Fast rate (100 pps): $fast_result"

        # Medium rate test
        medium_result=$(ping -c 20 -i 0.1 "$target" 2>&1 | grep "packet loss")
        add_result "  Medium rate (10 pps): $medium_result"

        # Slow rate test
        slow_result=$(ping -c 20 -i 1 "$target" 2>&1 | grep "packet loss")
        add_result "  Slow rate (1 pps): $slow_result"
    fi

    add_result ""

    # 8. ENHANCED TRACEROUTE ANALYSIS
    add_result "${BOLD}${CYAN}[8] ENHANCED TRACEROUTE ANALYSIS${NC}"
    add_result "Multiple traceroute techniques for path analysis..."

    if command_exists traceroute; then
        # ICMP traceroute (default)
        add_result "  ICMP Traceroute:"
        ICMP_TRACE=$(traceroute -I "$target" 2>&1 | head -10)
        echo "$ICMP_TRACE" | while read -r line; do
            if echo "$line" | grep -q "traceroute to\|^\s*[0-9]"; then
                add_result "    $line"
            fi
        done

        # UDP traceroute to port 53 (DNS)
        add_result "  UDP Traceroute (port 53):"
        UDP_TRACE=$(traceroute -U -p 53 "$target" 2>&1 | head -10)
        echo "$UDP_TRACE" | while read -r line; do
            if echo "$line" | grep -q "traceroute to\|^\s*[0-9]"; then
                add_result "    $line"
            fi
        done
    fi

    add_result ""

    # 9. PROTOCOL-SPECIFIC CONNECTIVITY
    add_result "${BOLD}${CYAN}[9] PROTOCOL-SPECIFIC CONNECTIVITY${NC}"
    add_result "Testing different protocols and ports..."

    if command_exists nmap; then
        # TCP SYN scan on common ports
        add_result "  TCP connectivity test (common ports):"
        TCP_PORTS=$(nmap -sS -p 22,80,443,53 "$target" 2>/dev/null | grep "tcp")
        if [ -n "$TCP_PORTS" ]; then
            echo "$TCP_PORTS" | while read -r line; do
                add_result "    $line"
            done
        else
            add_result "    No TCP ports responded"
        fi

        # UDP scan on common services
        add_result "  UDP connectivity test:"
        UDP_SCAN=$(nmap -sU -p 53,123,161 "$target" 2>/dev/null | grep "udp")
        if [ -n "$UDP_SCAN" ]; then
            echo "$UDP_SCAN" | while read -r line; do
                add_result "    $line"
            done
        else
            add_result "    No UDP services detected"
        fi
    fi

    add_result ""

    # 10. FRAGMENTATION TESTING
    add_result "${BOLD}${CYAN}[10] FRAGMENTATION TESTING${NC}"
    add_result "Testing Path MTU and fragmentation behavior..."

    if command_exists ping; then
        # Don't fragment test
        DF_TEST=$(ping -c 5 -M do -s 1472 "$target" 2>&1)
        DF_LOSS=$(echo "$DF_TEST" | grep -o "[0-9]*% packet loss")
        add_result "  Don't Fragment (1472B): $DF_LOSS"

        # Larger packet with fragmentation allowed
        FRAG_TEST=$(ping -c 5 -s 2000 "$target" 2>&1)
        FRAG_LOSS=$(echo "$FRAG_TEST" | grep -o "[0-9]*% packet loss")
        add_result "  Large packets (2000B, fragmentation allowed): $FRAG_LOSS"

        # Jumbo frame test
        if ping -c 1 -s 8192 "$target" >/dev/null 2>&1; then
            JUMBO_TEST=$(ping -c 5 -s 8192 "$target" 2>&1)
            JUMBO_LOSS=$(echo "$JUMBO_TEST" | grep -o "[0-9]*% packet loss")
            add_result "  Jumbo frames (8192B): $JUMBO_LOSS"
        else
            add_result "  Jumbo frames (8192B): Not supported or blocked"
        fi
    fi

    add_result ""

    # 11. TIMING VARIANCE ANALYSIS
    add_result "${BOLD}${CYAN}[11] TIMING VARIANCE ANALYSIS${NC}"
    add_result "Analyzing RTT consistency and jitter..."

    if command_exists ping; then
        # Extended ping for jitter analysis
        JITTER_TEST=$(ping -c 50 -i 0.2 "$target" 2>&1)
        if echo "$JITTER_TEST" | grep -q "min/avg/max"; then
            RTT_STATS=$(echo "$JITTER_TEST" | grep "min/avg/max")
            PACKET_LOSS=$(echo "$JITTER_TEST" | grep -o "[0-9]*% packet loss")
            add_result "  50-packet jitter test:"
            add_result "    $RTT_STATS"
            add_result "    Packet loss: $PACKET_LOSS"

            # Calculate jitter if possible
            RTT_VALUES=$(echo "$JITTER_TEST" | grep "time=" | grep -o "time=[0-9.]*" | cut -d'=' -f2)
            if [ -n "$RTT_VALUES" ]; then
                RTT_COUNT=$(echo "$RTT_VALUES" | wc -l)
                if [ "$RTT_COUNT" -gt 10 ]; then
                    MIN_RTT=$(echo "$RTT_VALUES" | sort -n | head -1)
                    MAX_RTT=$(echo "$RTT_VALUES" | sort -n | tail -1)
                    if command_exists bc; then
                        JITTER=$(echo "scale=3; $MAX_RTT - $MIN_RTT" | bc -l 2>/dev/null)
                        add_result "    Calculated jitter: ${JITTER} ms"
                    fi
                fi
            fi
        fi
    fi

    add_result ""

    # Analysis Summary
    add_result "${BOLD}${YELLOW}DIAGNOSTIC SUMMARY${NC}"
    add_result "================================================================"

    # Determine network characteristics based on tests
    add_result "Network Characteristics Analysis:"

    # Check if packet loss increases with size
    if command_exists ping; then
        small_loss=$(ping -c 5 -s 64 "$target" 2>&1 | grep -o "[0-9]*%" | head -1 | tr -d '%')
        large_loss=$(ping -c 5 -s 1472 "$target" 2>&1 | grep -o "[0-9]*%" | head -1 | tr -d '%')

        if [ -n "$small_loss" ] && [ -n "$large_loss" ]; then
            if [ "$large_loss" -gt "$small_loss" ]; then
                add_result "• Size-dependent packet loss detected - suggests buffer/bandwidth constraints"
            elif [ "$large_loss" -eq 0 ] && [ "$small_loss" -eq 0 ]; then
                add_result "• No packet loss detected - network path appears stable"
            else
                add_result "• Inconsistent packet loss pattern - may indicate intermittent issues"
            fi
        fi
    fi

    # Check RTT consistency
    if [ -n "$MIN_RTT" ] && [ -n "$MAX_RTT" ] && command_exists bc; then
        RTT_VARIATION=$(echo "scale=1; ($MAX_RTT - $MIN_RTT) / $MIN_RTT * 100" | bc -l 2>/dev/null)
        if [ -n "$RTT_VARIATION" ]; then
            add_result "• RTT variation: ${RTT_VARIATION}% (lower is more consistent)"
        fi
    fi

    add_result ""
    add_result "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
    add_result "${BOLD}${BLUE}    COMPREHENSIVE ANALYSIS COMPLETE${NC}"
    add_result "${BOLD}${BLUE}════════════════════════════════════════════════${NC}"
}

# Function to get AI evaluation specifically for comparison results
get_comparison_ai_evaluation() {
    local target1="$1"
    local target2="$2"
    local comparison_summary="$3"


    GEMINI_API_KEY="${GEMINI_API_KEY:-}"
    if [ -z "$GEMINI_API_KEY" ]; then
        add_result "${RED}✗ GEMINI_API_KEY environment variable not set${NC}"
        rm "$TMP_REQUEST" "$TMP_RESPONSE" 2>/dev/null
        return 1
    fi

    TMP_REQUEST=$(mktemp)
    TMP_RESPONSE=$(mktemp)

    cat > "$TMP_REQUEST" << EOF
{
  "contents": [
    {
      "parts": [
        {
          "text": "As a network analyst, briefly summarize the most important performance differences between $target1 and $target2 based on the following results. Explain why these differences exist and what they mean for practical network use. Limit your response to key insights and recommendations:\n\n$comparison_summary"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.2,
    "maxOutputTokens": 4098
  }
}
EOF

    # Use wget for the API request
    wget -q --header="Content-Type: application/json" \
         --post-file="$TMP_REQUEST" \
         -O "$TMP_RESPONSE" \
         "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY"

    if [ $? -ne 0 ]; then
        add_result "${RED}✗ Failed to connect to Gemini API${NC}"
        rm "$TMP_REQUEST" "$TMP_RESPONSE" 2>/dev/null
        return 1
    fi

    AI_RESPONSE=$(grep -o '"text": "[^"]*' "$TMP_RESPONSE" | sed 's/"text": "//')

    if [ -z "$AI_RESPONSE" ]; then
        add_result "${RED}✗ Failed to get proper response from Gemini API${NC}"
        add_result "API Error: $(grep -o 'error' "$TMP_RESPONSE" || echo 'Unknown error')"
    else
        add_result "${GREEN}✓ AI Analysis Complete${NC}"
        add_result ""
        add_result "${BOLD}${YELLOW}GEMINI AI NETWORK ANALYSIS:${NC}"
        add_result "--------------------------------------------------"
        AI_RESPONSE=$(echo "$AI_RESPONSE" | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
        add_result "$AI_RESPONSE"
        add_result "--------------------------------------------------"
    fi

    rm "$TMP_REQUEST" "$TMP_RESPONSE" 2>/dev/null
}

# Function to run comparison between two hosts
# Function to run comparison between two hosts
run_comparison() {
    local target1="$1"
    local target2="$2"

    add_result "${BOLD}${BLUE}===================================================${NC}"
    add_result "${BOLD}${BLUE}    NETWORK COMPARISON: $target1 vs $target2${NC}"
    add_result "${BOLD}${BLUE}===================================================${NC}"
    add_result "Generated: $(date)"
    add_result ""

    # First, test connectivity to both hosts
    add_result "${BOLD}${CYAN}CONNECTIVITY CHECK${NC}"

    if ! test_basic_connectivity "$target1"; then
        add_result "${RED}Cannot proceed - $target1 is unreachable${NC}"
        return 1
    fi

    if ! test_basic_connectivity "$target2"; then
        add_result "${RED}Cannot proceed - $target2 is unreachable${NC}"
        return 1
    fi

    add_result "${GREEN}Both hosts are reachable - proceeding with comparison${NC}"
    add_result ""

    # Save current results and run comprehensive scans
    local comparison_header="$RESULTS"

    # Scan first target
    RESULTS=""
    add_result "${BOLD}${YELLOW}[SCANNING $target1]${NC}"
    run_comprehensive_scan "$target1"
    local results1="$RESULTS"

    # Scan second target
    RESULTS=""
    add_result "${BOLD}${YELLOW}[SCANNING $target2]${NC}"
    run_comprehensive_scan "$target2"
    local results2="$RESULTS"

    # Restore header and add both results
    RESULTS="$comparison_header"
    RESULTS+="\n${BOLD}TARGET 1 RESULTS:${NC}\n"
    RESULTS+="$results1\n"
    RESULTS+="\n${BOLD}TARGET 2 RESULTS:${NC}\n"
    RESULTS+="$results2\n"

    # Add comparison summary with simpler formatting
    add_result ""
    add_result "${BOLD}${CYAN}COMPARISON SUMMARY${NC}"
    add_result "--------------------------------------------------"

    # Extract metrics with improved patterns
    target1_ping_avg=$(echo "$results1" | grep -o "Average: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $2}')
    target2_ping_avg=$(echo "$results2" | grep -o "Average: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $2}')

    target1_ping_min=$(echo "$results1" | grep -o "Minimum: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $2}')
    target2_ping_min=$(echo "$results2" | grep -o "Minimum: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $2}')

    target1_ping_max=$(echo "$results1" | grep -o "Maximum: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $2}')
    target2_ping_max=$(echo "$results2" | grep -o "Maximum: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $2}')

    target1_packet_loss=$(echo "$results1" | grep -o "Packet Loss: [0-9]*%" | head -1 | awk '{print $3}')
    target2_packet_loss=$(echo "$results2" | grep -o "Packet Loss: [0-9]*%" | head -1 | awk '{print $3}')

    target1_tcp_download=$(echo "$results1" | grep -o "Download (Receiver): [0-9.]* [MG]bits/sec" | head -1 | awk '{print $3" "$4}')
    target2_tcp_download=$(echo "$results2" | grep -o "Download (Receiver): [0-9.]* [MG]bits/sec" | head -1 | awk '{print $3" "$4}')

    target1_tcp_upload=$(echo "$results1" | grep -o "Upload (Sender): [0-9.]* [MG]bits/sec" | head -1 | awk '{print $3" "$4}')
    target2_tcp_upload=$(echo "$results2" | grep -o "Upload (Sender): [0-9.]* [MG]bits/sec" | head -1 | awk '{print $3" "$4}')

    target1_udp_speed=$(echo "$results1" | grep -o "UDP Throughput: [0-9.]* [MG]bits/sec" | head -1 | awk '{print $3" "$4}')
    target2_udp_speed=$(echo "$results2" | grep -o "UDP Throughput: [0-9.]* [MG]bits/sec" | head -1 | awk '{print $3" "$4}')

    target1_udp_loss=$(echo "$results1" | grep -o "UDP Packet Loss: [0-9]*%" | head -1 | awk '{print $4}')
    target2_udp_loss=$(echo "$results2" | grep -o "UDP Packet Loss: [0-9]*%" | head -1 | awk '{print $4}')

    target1_hops=$(echo "$results1" | grep -o "Number of hops: [0-9]*" | head -1 | awk '{print $4}')
    target2_hops=$(echo "$results2" | grep -o "Number of hops: [0-9]*" | head -1 | awk '{print $4}')

    target1_trace_avg=$(echo "$results1" | grep -o "Traceroute RTT Average: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $4}')
    target2_trace_avg=$(echo "$results2" | grep -o "Traceroute RTT Average: [0-9]*\.[0-9]* ms" | head -1 | awk '{print $4}')

    target1_open_ports=$(echo "$results1" | grep -o "Found [0-9]* open port" | head -1 | awk '{print $2}')
    target2_open_ports=$(echo "$results2" | grep -o "Found [0-9]* open port" | head -1 | awk '{print $2}')

    target1_iperf_available=$(echo "$results1" | grep -q "iperf3 TCP test successful" && echo "Yes" || echo "No")
    target2_iperf_available=$(echo "$results2" | grep -q "iperf3 TCP test successful" && echo "Yes" || echo "No")

    # Simple text-based comparison with clear labels
    add_result "PING LATENCY"
    add_result "  $target1: ${target1_ping_avg:-N/A} ms (min/max: ${target1_ping_min:-N/A}/${target1_ping_max:-N/A} ms)"
    add_result "  $target2: ${target2_ping_avg:-N/A} ms (min/max: ${target2_ping_min:-N/A}/${target2_ping_max:-N/A} ms)"
    add_result "  Packet Loss: $target1: ${target1_packet_loss:-0%}, $target2: ${target2_packet_loss:-0%}"
    add_result ""

    add_result "THROUGHPUT MEASUREMENTS"
    add_result "  TCP Download: $target1: ${target1_tcp_download:-N/A}, $target2: ${target2_tcp_download:-N/A}"
    add_result "  TCP Upload:   $target1: ${target1_tcp_upload:-N/A}, $target2: ${target2_tcp_upload:-N/A}"
    add_result "  UDP Speed:    $target1: ${target1_udp_speed:-N/A}, $target2: ${target2_udp_speed:-N/A}"
    add_result "  UDP Loss:     $target1: ${target1_udp_loss:-N/A}, $target2: ${target2_udp_loss:-N/A}"
    add_result "  iperf3 Available: $target1: $target1_iperf_available, $target2: $target2_iperf_available"
    add_result ""

    add_result "NETWORK PATH"
    add_result "  Network Hops: $target1: ${target1_hops:-N/A}, $target2: ${target2_hops:-N/A}"
    add_result "  Trace RTT:    $target1: ${target1_trace_avg:-N/A} ms, $target2: ${target2_trace_avg:-N/A} ms"
    add_result "  Open Ports:   $target1: ${target1_open_ports:-0}, $target2: ${target2_open_ports:-0}"
    add_result ""

    # Performance Analysis
    add_result "${BOLD}${YELLOW}PERFORMANCE ANALYSIS${NC}"
    add_result "--------------------------------------------------"

    # Determine better RTT
    if [ -n "$target1_ping_avg" ] && [ -n "$target2_ping_avg" ]; then
        if command_exists bc; then
            comparison=$(echo "$target1_ping_avg < $target2_ping_avg" | bc -l 2>/dev/null)
            if [ "$comparison" = "1" ]; then
                diff=$(echo "scale=2; $target2_ping_avg - $target1_ping_avg" | bc -l 2>/dev/null)
                add_result "${GREEN}✓ Lower Latency: $target1 (${diff}ms faster)${NC}"
            else
                diff=$(echo "scale=2; $target1_ping_avg - $target2_ping_avg" | bc -l 2>/dev/null)
                add_result "${GREEN}✓ Lower Latency: $target2 (${diff}ms faster)${NC}"
            fi
        fi
    fi

    # Determine better throughput
    if [ "$target1_iperf_available" = "Yes" ] && [ "$target2_iperf_available" = "No" ]; then
        add_result "${GREEN}✓ Throughput Testing: Only $target1 available${NC}"
    elif [ "$target1_iperf_available" = "No" ] && [ "$target2_iperf_available" = "Yes" ]; then
        add_result "${GREEN}✓ Throughput Testing: Only $target2 available${NC}"
    elif [ "$target1_iperf_available" = "Yes" ] && [ "$target2_iperf_available" = "Yes" ]; then
        add_result "${GREEN}✓ Throughput Testing: Both targets support iperf3${NC}"
    else
        add_result "${YELLOW}⚠ Throughput Testing: Neither target has iperf3 server${NC}"
    fi

    # Determine better path
    if [ -n "$target1_hops" ] && [ -n "$target2_hops" ]; then
        if [ "$target1_hops" -lt "$target2_hops" ]; then
            diff=$((target2_hops - target1_hops))
            add_result "${GREEN}✓ Shorter Path: $target1 (${diff} fewer hops)${NC}"
        elif [ "$target2_hops" -lt "$target1_hops" ]; then
            diff=$((target1_hops - target2_hops))
            add_result "${GREEN}✓ Shorter Path: $target2 (${diff} fewer hops)${NC}"
        else
            add_result "○ Network Path: Both targets have identical path length"
        fi
    fi

    # Service availability comparison
    if [ -n "$target1_open_ports" ] && [ -n "$target2_open_ports" ]; then
        if [ "$target1_open_ports" -gt "$target2_open_ports" ]; then
            diff=$((target1_open_ports - target2_open_ports))
            add_result "${GREEN}✓ More Services: $target1 (${diff} additional ports)${NC}"
        elif [ "$target2_open_ports" -gt "$target1_open_ports" ]; then
            diff=$((target2_open_ports - target1_open_ports))
            add_result "${GREEN}✓ More Services: $target2 (${diff} additional ports)${NC}"
        fi
    fi

    # Final recommendation
    add_result ""
    add_result "${BOLD}${CYAN}RECOMMENDATION${NC}"
    add_result "--------------------------------------------------"

    # Simple scoring for overall recommendation
    score1=0
    score2=0

    # Score for RTT (lower is better)
    if [ -n "$target1_ping_avg" ] && [ -n "$target2_ping_avg" ]; then
        if command_exists bc; then
            if [ "$(echo "$target1_ping_avg < $target2_ping_avg" | bc -l 2>/dev/null)" = "1" ]; then
                score1=$((score1 + 2))
            else
                score2=$((score2 + 2))
            fi
        fi
    fi

    # Score for iperf3 availability
    [ "$target1_iperf_available" = "Yes" ] && score1=$((score1 + 1))
    [ "$target2_iperf_available" = "Yes" ] && score2=$((score2 + 1))

    # Score for network path (fewer hops is better)
    if [ -n "$target1_hops" ] && [ -n "$target2_hops" ]; then
        if [ "$target1_hops" -lt "$target2_hops" ]; then
            score1=$((score1 + 1))
        elif [ "$target2_hops" -lt "$target1_hops" ]; then
            score2=$((score2 + 1))
        fi
    fi

    if [ $score1 -gt $score2 ]; then
        add_result "${GREEN}→ $target1 shows better overall network performance${NC}"
        add_result "  (Score: $score1 vs $score2 based on latency, services, and path efficiency)"
    elif [ $score2 -gt $score1 ]; then
        add_result "${GREEN}→ $target2 shows better overall network performance${NC}"
        add_result "  (Score: $score2 vs $score1 based on latency, services, and path efficiency)"
    else
        add_result "${YELLOW}→ Both targets show comparable network performance${NC}"
        add_result "  (Equal scores: $score1 each)"
    fi
    add_result ""
    add_result "${BOLD}${BLUE}===================================================${NC}"

    # Capture the comparison summary to send to Gemini
    local comparison_summary=$(echo -e "$RESULTS" | sed 's/\x1b\[[0-9;]*m//g' | grep -A 50 "COMPARISON SUMMARY" | grep -B 50 "RECOMMENDATION" | grep -v "RECOMMENDATION")

    # Get AI evaluation if jq is available
    get_comparison_ai_evaluation "$target1" "$target2" "$comparison_summary"

    add_result ""
    add_result "${BOLD}${BLUE}===================================================${NC}"
    add_result "${BOLD}${BLUE}    COMPARISON COMPLETE${NC}"
    add_result "${BOLD}${BLUE}===================================================${NC}"
}

# Function to save results
save_results() {
    if [ "$SAVE_TO_FILE" = "yes" ] && [ -n "$OUTPUT_FILE" ]; then
        echo -e "$RESULTS" | sed 's/\x1b\[[0-9;]*m//g' > "$OUTPUT_FILE"
        echo -e "\n${GREEN}Results saved to: $OUTPUT_FILE${NC}"
    fi
}

# Main menu
main_menu() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║     Network Analysis Tool - CS3873      ║${NC}"
    echo -e "${BOLD}${CYAN}║   Network Measurement and Probing Lab   ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}Available Options:${NC}"
    echo "  1) Comprehensive Network Scan (single target)"
    echo "  2) Compare Two Hosts (dual target analysis)"
    echo ""

    choice=$(get_user_input "Select option (1 or 2)" "1")
    echo ""

    # Ask about saving results
    save_choice=$(get_user_input "Save results to file? (y/n)" "y")
    if [[ "$save_choice" =~ ^[Yy] ]]; then
        SAVE_TO_FILE="yes"
        if [ "$choice" = "2" ]; then
            default_filename="network_comparison_$(date +%Y%m%d_%H%M%S).txt"
        else
            default_filename="network_analysis_$(date +%Y%m%d_%H%M%S).txt"
        fi
        OUTPUT_FILE=$(get_user_input "Enter filename" "$default_filename")
    fi
    echo ""

    case $choice in
        1)
            while true; do
                target=$(get_user_input "Enter target IP address or hostname")
                if validate_ip "$target"; then
                    break
                else
                    echo -e "${RED}Invalid format. Please try again.${NC}"
                fi
            done

            echo ""
            echo -e "${BOLD}Starting comprehensive scan...${NC}"
            run_comprehensive_scan "$target"
            ;;

        2)
            while true; do
                target1=$(get_user_input "Enter first target IP address or hostname")
                if validate_ip "$target1"; then
                    break
                else
                    echo -e "${RED}Invalid format. Please try again.${NC}"
                fi
            done

            while true; do
                target2=$(get_user_input "Enter second target IP address or hostname")
                if validate_ip "$target2"; then
                    if [ "$target1" != "$target2" ]; then
                        break
                    else
                        echo -e "${RED}Second target must be different from first. Please try again.${NC}"
                    fi
                else
                    echo -e "${RED}Invalid format. Please try again.${NC}"
                fi
            done

            echo ""
            echo -e "${BOLD}Starting comparison analysis...${NC}"
            run_comparison "$target1" "$target2"
            ;;

        *)
            echo -e "${RED}Invalid selection. Defaulting to comprehensive scan.${NC}"
            while true; do
                target=$(get_user_input "Enter target IP address or hostname")
                if validate_ip "$target"; then
                    break
                else
                    echo -e "${RED}Invalid format. Please try again.${NC}"
                fi
            done

            echo ""
            run_comprehensive_scan "$target"
            ;;
    esac

    save_results

    echo ""
    echo -e "${BOLD}${GREEN}Analysis complete!${NC}"

    # Ask to run another analysis
    echo ""
    another=$(get_user_input "Run another analysis? (y/n)" "n")
    if [[ "$another" =~ ^[Yy] ]]; then
        RESULTS=""
        main_menu
    fi
}

# Check for required tools
check_tools() {
    echo -e "${YELLOW}Checking required tools...${NC}"

    local tools=("ping" "nmap" "iperf3" "traceroute")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            echo -e "${GREEN}✓ $tool${NC}"
        else
            missing_tools+=("$tool")
            echo -e "${RED}✗ $tool${NC}"
        fi
    done

    echo ""

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing tools can be installed with:${NC}"
        echo "  Ubuntu/Debian: sudo apt install ${missing_tools[*]}"
        echo "  RHEL/CentOS:   sudo yum install ${missing_tools[*]}"
        echo ""

        continue_choice=$(get_user_input "Continue with available tools? (y/n)" "y")
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            echo "Please install missing tools and run again."
            exit 1
        fi
        echo ""
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_tools
    main_menu
fi

