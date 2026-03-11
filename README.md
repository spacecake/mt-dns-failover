# mt-dns-failover
MikroTik RouterOS script for tiered DNS failover. Sequentially monitors internal health via ICMP and dynamically switches the local resolver between 4 internal nodes and secure public fallbacks (Quad9/NextDNS/ControlD) to eliminate timeout-stacking delays.
