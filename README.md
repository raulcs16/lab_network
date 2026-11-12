# Network Infrastructure & Out-of-Band Management Lab

## Abstract

A fully automated, virtualized enterprise network environment built using Infrastructure-as-Code (IaC) principles. The architecture features a dual-NIC Ubuntu bastion and console server ensuring secure management access, an isolated out-of-band (OOB) management plane, and integrated core network services hosted via Windows Server workloads.

---

## 🎯 Objectives & Phased Architecture

1. **Bastion & Console Server:** Establish a secure gateway server with dual network interfaces (`ens3` for OOB, `ens4` for transit) to strictly separate transit traffic from internal management.
2. **Out-of-Band (OOB) Management Plane:** Isolate switch management traffic onto VLAN 100 so that only the console server can directly access and configure network devices via automated control planes.
3. **Network Services VLAN & Windows Server:** Integrate Windows Server workloads into a dedicated services segment to host core infrastructure roles:
   - **DHCP / DNS:** Automated client address assignment and name resolution.
   - **NTP:** Centralized time synchronization across all network gear and servers.
   - **AAA:** Centralized device authentication and access control.
4. **User VLAN Segmentation:** Implement multi-tier user and device VLANs with inter-VLAN routing controls.
5. **Network Infrastructure Redundancy:** Introduce high-availability topologies, redundant core switching, STP hardening, and gateway failover protocols.

---

## Objective 1:  Bastion & Console Server

configure the gateway router with DHCP WAN interface, NAT overload (PAT) and inbound static port forwarding for extenral ssh access

```bash
[CLOUD]-----[ R1 ]----[ CD1 ]----[ ACC1 ]
            |    |    |          |
            |  [ MANGEMENT SWITCH ]
            |        |
        [ Console Server ]
```

**Interface Plan**:

| DEVICE | Interface |    IPv4          |    Description
|--------|-----------|------------------|------------
|   R1   | eth 1/3   | ip address DHCP  | nat outside
|   R1   | eth 1/2   | 192.168.200.1/30 | nat inside, OOB link
|   CS*  | ens4      | 192.168.200.2/30 | static ip

*CS: Console Server

**Router Configuration**:

```bash
config t

int eth 1/3
ip address dhcp 
no shutdown 
ip nat outside

int eth 1/2
ip address 192.168.200.1 255.255.255.252
no shutdown
ip nat inside
exit
# PAT 
access-list 1 permit 192.168.200.0 0.0.0.3 
ip nat inside source list 1 interface eth 1/3 
## SSH Fowarded to Console Server
ip nat inside source static tcp 192.168.200.2 22 int eth 1/3 2222
# Route back to Console Server
ip route 192.168.200.0 255.255.255.252 192.168.200.1
```

**Console Server Configuration**:

```bash
sudo -i 
vi /etc/netplan/00-config.yml
```

```yaml netplan/00-config.yml
network:
    ethernets:
        ens4:
            dhcp4: no 
            addresses:
                - 192.168.200.2/30
            routes:  
                - to: default
                  via: 192.168.200.1
            nameservers:
                addresses:
                    - 8.8.8.8
version: 2
```

```bash
netplan try
netplan apply
sudo apt update
sudo apt install -y git
git clone htts://github.com/raulcs16/lab_network_infra.git repo
## Set Up Ansible + SSH Public Key 
cd repo/boostrap
chmod +x ansible.sh
./ansible.sh
```
