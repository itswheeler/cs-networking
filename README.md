# Network Analysis Tool - CS3873

## Overview
`netscan.sh` is a comprehensive network analysis and comparison tool for the CS3873 Network Measurement Lab. It performs connectivity checks, port scans, throughput tests, traceroute analysis, packet loss and jitter measurements, and can compare two hosts. Optionally, it integrates with Gemini AI for automated result interpretation.

## Features
- Single-target comprehensive network scan
- Dual-target comparison with performance summary
- RTT, packet loss, throughput (TCP/UDP), traceroute, fragmentation, and jitter analysis
- Service discovery via port scanning
- AI-powered summary (requires Gemini API key)
- Results can be saved to a file

## Requirements
- Bash (Linux/macOS)
- Tools: `ping`, `nmap`, `iperf3`, `traceroute`
- Optional: `bc`, `wget`
- For AI analysis: Gemini API key (`GEMINI_API_KEY` environment variable)

## Usage

Make the script executable:

- chmod +x cs-networking/netscan.sh

- Run the script: ./cs-networking/netscan.sh

## Follow the interactive prompts to:

- Scan a single target
- Compare two hosts
- Save results to a file
## AI Integration

To enable AI-powered analysis, set your Gemini API key: 

- export GEMINI_API_KEY=your_api_key_here

Example

$ ./cs-networking/netscan.sh

Select scan type, enter target(s), and view results.


## Notes
Missing tools will be reported at startup.
Results are color-coded for clarity.
For best results, run with root privileges if required by some tools.

## License
For educational use in CS3873 Network Measurement Lab.



## Running tracert.sh

The `tracert.sh` script is a helper tool for running traceroute on a set of **predefined destinations**.  
The destinations are hardcoded inside the script, so you do not need to pass any arguments.

### Usage
```bash
chmod +x tracert.sh      # Make the script executable (only needed once)
./tracert.sh

### Example
```bash
./tracert.sh 
```

This will run traceroute on the specified host and create logs for the hardcoded destinations.
