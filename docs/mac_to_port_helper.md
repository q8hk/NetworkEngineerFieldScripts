# MAC to Switch Port Helper

Use these copy/paste snippets to trace a MAC address to a switch port across common platforms. Normalize MACs first with `normalize_mac.cmd` to avoid format issues.

## Cisco IOS/NX-OS

```
show mac address-table | include <mac>
show arp | include <ip>
show interface status
show interface <port> description
```

Formats accepted: `aaaa.bbbb.cccc` (use `normalize_mac` Cisco output).

## HPE/Aruba (ProCurve)

```
show mac-address <mac>
show arp <ip>
show interface brief
show interface <port> description
```

Formats: `aa-bb-cc-dd-ee-ff` or `aaaa.bbbb.cccc`.

## Huawei

```
display mac-address | include <mac>
display arp | include <ip>
display interface brief
display interface GigabitEthernet0/0/1 | include Description
```

Formats: `aaaa-bbbb-cccc` or `aaaa.bbbb.cccc`.

## Tips

- Normalize input: `normalize_mac.cmd 00:11:22:33:44:55`
- Capture evidence: run `net_snapshot.cmd` before/after changes.
- When multiple MACs map to a port, inspect LLDP/CDP neighbors for downstream switches.
