# MikroTik DNS Failover Watchdog

A deterministic RouterOS script that monitors the health of internal DNS resolvers and automatically fails over to secure public providers (Quad9, NextDNS, Control D) if internal infrastructure is unreachable.

## Features
- **Real DNS Health Check**: Each resolver is tested with an actual DNS query, not a ping. A host that answers ping but runs a dead DNS service is skipped.
- **Tiered Priority**: Sequentially checks internal nodes; selects the first resolver that answers.
- **Secure Fallback**: Switches to high-privacy public resolvers if all internal nodes fail.
- **Automatic Return**: Internal nodes are always checked first, so the router switches back as soon as one recovers.
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

Note: Update the InternalNodes IPs to match your specific network. Set TestName to a stable domain that always resolves.

```routeros
:local InternalNodes {"10.0.0.10"; "10.0.0.11"; "10.0.0.12"; "10.0.0.13"}
:local SafeExternal {"9.9.9.9"; "45.90.28.242"; "76.76.19.19"}
:local TestName "www.example.com"
:local TargetIP ""
:local CurrentDNS [/ip dns get servers]

# 1. Check Internal Nodes with a real DNS query
:foreach IP in=$InternalNodes do={
    :if ([:len $TargetIP] = 0) do={
        :do {
            :local r [:resolve $TestName server=$IP]
            :set TargetIP $IP
        } on-error={}
    }
}

# 2. Check External Fallback
:if ([:len $TargetIP] = 0) do={
    :foreach IP in=$SafeExternal do={
        :if ([:len $TargetIP] = 0) do={
            :do {
                :local r [:resolve $TestName server=$IP]
                :set TargetIP $IP
            } on-error={}
        }
    }
}

# 3. Apply and Log
:if ([:len $TargetIP] > 0 && $TargetIP != $CurrentDNS) do={
    /ip dns set servers=$TargetIP
    /ip dns cache flush
    :log info ("DNS-WATCH: Switched to " . $TargetIP)
}
```

Requirements: RouterOS v7 (the `server=` parameter of `:resolve`).

## 3. Automation
Add a scheduler to execute the check every 30 seconds.

```routeros
/system scheduler
add interval=30s name=DNS_Watchdog_Task on-event=dns-failover policy=read,write,test
```

## 4. Testing
Verify the health check before relying on it.

```routeros
# Should return an IP
:put [:resolve www.example.com server=9.9.9.9]

# Should fail with a timeout (unused address)
:put [:resolve www.example.com server=10.0.0.99]
```

To simulate an outage, stop the DNS service on the first internal node and run the script manually. The router should switch to the next healthy node.

## 5. Monitoring
Check the status and history with these commands:
| Task | Command |
| :--- | :--- |
| **Check Current DNS** | `/ip dns print` |
| **View Failover Logs** | `/log print where buffer=dnsaction` |
| **Check Log File** | `/file print where name~"dns-changes"` |
| **Manual Script Run** | `/system script run dns-failover` |

## 6. Limitations
- Health is judged on one test name. A server that resolves it but fails for other domains is still treated as healthy.
- If `/ip dns servers` holds more than one address, the script sees a mismatch on every run and flushes the cache each time. Keep a single active server.

## 7. License
Distributed under the MIT License. See LICENSE for more information.
