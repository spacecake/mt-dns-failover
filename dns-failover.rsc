#-------------------------------------------------------------------------------
# MikroTik DNS Failover Watchdog
# Source: https://github.com/[your-username]/[your-repo]
#-------------------------------------------------------------------------------

:local InternalNodes {"10.0.0.10"; "10.0.0.11"; "10.0.0.12"; "10.0.0.13"}
:local SafeExternal {"9.9.9.9"; "45.90.28.242"; "76.76.19.19"}
:local TargetIP ""
:local CurrentDNS [/ip dns get servers]

# 1. Check Internal Nodes sequentially
:foreach IP in=$InternalNodes do={
    :if ([:len $TargetIP] = 0) do={
        :if ([/ping $IP count=2] > 0) do={ 
            :set TargetIP $IP 
        }
    }
}

# 2. Check External Fallback if all internal nodes are down
:if ([:len $TargetIP] = 0) do={
    :foreach IP in=$SafeExternal do={
        :if ([:len $TargetIP] = 0) do={
            :if ([/ping $IP count=2] > 0) do={ 
                :set TargetIP $IP 
            }
        }
    }
}

# 3. Apply change only if a healthy node is found and differs from current config
:if ([:len $TargetIP] > 0 && $TargetIP != $CurrentDNS) do={
    /ip dns set servers=$TargetIP
    /ip dns cache flush
    :log info ("DNS-WATCH: Switched to " . $TargetIP)
}
