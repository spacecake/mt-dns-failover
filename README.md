# MikroTik DNS Failover Watchdog

A deterministic RouterOS script that monitors the health of internal DNS resolvers and automatically fails over to secure public providers (Quad9, NextDNS, Control D) if internal infrastructure is unreachable.

## Features
- **Tiered Priority**: Sequentially checks internal nodes; selects the first responsive IP.
- **Secure Fallback**: Switches to high-privacy public resolvers if all internal nodes fail.
- **Deterministic Logic**: Maintains exactly one active resolver to eliminate "timeout stacking" delays.
- **Dedicated Logging**: Writes events to a persistent disk file (`dns-changes.0.txt`).
- **Cache Management**: Flushes the DNS cache on every switch to ensure immediate effect.

---

## 1. Logging Configuration
Run these commands in the MikroTik terminal to create the dedicated log file and filter.

```routeros
/system logging action 
add name=dnsaction target=disk disk-file-name=dns-changes disk-lines-per-file=1000

/system logging 
add action=dnsaction prefix="DNS-WATCH" topics=script,info
```

## 2. The Script (dns-failover)
Create a new script named dns-failover and paste the following code.

Note: Update the InternalNodes IPs to match your specific network.

```routeros
:local InternalNodes {"10.0.0.10"; "10.0.0.11"; "10.0.0.12"; "10.0.0.13"}
:local SafeExternal {"9.9.9.9"; "45.90.28.242"; "76.76.19.19"}
:local TargetIP ""
:local CurrentDNS [/ip dns get servers]

# 1. Check Internal Nodes
:foreach IP in=$InternalNodes do={
    :if ([:len $TargetIP] = 0) do={
        :if ([/ping $IP count=2] > 0) do={ :set TargetIP $IP }
    }
}

# 2. Check External Fallback
:if ([:len $TargetIP] = 0) do={
    :foreach IP in=$SafeExternal do={
        :if ([:len $TargetIP] = 0) do={
            :if ([/ping $IP count=2] > 0) do={ :set TargetIP $IP }
        }
    }
}

# 3. Apply and Log
:if ([:len $TargetIP] > 0 && $TargetIP != $CurrentDNS) do={
    /ip dns set servers=$TargetIP
    /ip dns cache flush
    :log info "DNS-WATCH: Switched to $TargetIP"
}
```
## 3. Automation
Add a scheduler to execute the check every 30 seconds.

```routeros
/system scheduler
add interval=30s name=DNS_Watchdog_Task on-event=dns-failover policy=read,write,test
```

## 4. Monitoring
Check the status and history with these commands:
| Task | Command |
| :--- | :--- |
| **Check Current DNS** | `/ip dns print` |
| **View Failover Logs** | `/log print where buffer=dnsaction` |
| **Check Log File** | `/file print where name~"dns-changes"` |
| **Manual Script Run** | `/system script run dns-failover` |

## 5. License
Distributed under the MIT License. See LICENSE for more information.
