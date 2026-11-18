# Network Infrastructure & Out-of-Band Management Lab

![starting topology](/images/topology.png)

## Abstract

A production-grade, virtualized enterprise network environment architected to demonstrate core competencies in systems administration, network engineering, and secure infrastructure management. Built using Infrastructure-as-Code (IaC) and automated provisioning workflows, the architecture features a hardened, dual-NIC Ubuntu bastion and console server ensuring secure management access, an isolated out-of-band (OOB) management plane for administrative control, and integrated core network services anchored by a Windows Server Active Directory Domain Controller.
This lab mirrors real-world corporate IT environments, highlighting hands-on proficiency in identity services, virtualization, routing, and disciplined technical documentation

## 🎯 Objectives & Phased Architecture

1. **Bastion Host & Secure Edge Access (WAN)**: Configure the edge gateway (R1) for WAN connectivity, NAT overload (PAT), and inbound static port forwarding (TCP 2222) to establish a secure, controlled administrative entry point through a dual-NIC Ubuntu console server.
2. **OOB Mangagment Plane**: Establish a dedicated, segregated management network across switches and routers. This ensures administrative traffic, console access, and device management planes remain completely isolated from user data traffic for enhanced security and reliability.nagement planes, and downstream infrastructure out-of-band.
3. **Configure Network Service Vlan + Windows Domain Controller**: Deploy Service VLAN, dynamic routing, and a Windows Server workload configured as an Active Directory Domain Controller (AD DS) and DNS server to manage identity, name resolution, and core infrastructure services.:

4. **User Subnets & Redundant Core Services (DHCP)**: Deploy a secondary member server on a dedicated user VLAN (VLAN 20) to handle dynamic IP allocation, establishing a split-scope or secondary DHCP server to ensure high availability and network segmentation.

5. **Active Directory Architecture, OUs & Group Policy (GPO)**: Design a corporate Organizational Unit (OU) structure, populate test user and computer accounts, and implement Group Policy Objects (GPOs) for security baselines, password policies, and automated workstation configuration.

## Objective Progress

| Objective | Progress
|-----------|----------
|    1      | Complete
|    2      | Complete
|    3      | Complete
|    4      | Not Started
|    5      | InProgress

## Objective 1: Bastion Host / WAN Access

Configure the gateway router with DHCP WAN interface, NAT overload (PAT) and inbound static port forwarding for extenral ssh access

```bash
[CLOUD]-----[ R1 ]
            |    
            |  
            |  
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
vi /etc/netplan/00-installer-config-.yml
```

```yaml
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

**Objective Complete**:

![image objective 1 completed](/images/objective_1.png)

## Objective 2.1: OOB Mangagment Plane

Set up paths from Console server to each network device

```bash
[CLOUD]-----[ R1 ]  [ CD1 ]   [ ACC1 ]
            |    |    |          |
            |  [ MANGEMENT SWITCH (MGS) ]
            |        |
        [ Console Server (CS) ]
```

**Interface Plan**:

| DEVICE | Interface    |    IPv4           |    Description
|--------|--------------|-------------------|------------
|   CS   | ens3         | 192.168.100.99/24 |  static ip
|   MGS  | vlan 100     | 192.168.100.1/24  |  SVI
|   MGS  | eth 0/0      |     N/A           |  access port, vlan 100
|   MGS  | eth 1/0      |     N/A           |  trunk, allowed vlan 100
|   MGS  | eth 2/0      |     N/A           |  trunk, allowed vlan 100
|   MGS  | eth 0/1      | 10.1.100.1/31     |  p2p link, no switch port
|   R1   | eth 0/0      | 10.1.100.0/31     |  p2p link
|   R1   | loopback 100 | 192.168.100.254/32|  virtual interface
|   CD1  | eth 0/0      |      N/A          |  trunk, allowed vlan 100
|   CD1  | vlan 100     | 192.168.100.11/24 |  SVI
|   ACC1 | eth 0/0      |       N/A         |  trunk allowed vlan 100
|   ACC1 | vlan 100     | 192.168.100.21/24 |  SVI

**Console Server Configuration**:

```bash
sudo -i 
vi /etc/netplan/00-installer.yaml
```

```yaml
network:
    ethernets:
        ens3:
            dhcp4: no
            addresses:
                - 192.168.100.99/24
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
```

**Mangagment Switch Configuration**:

```bash
config t
vlan 100
name OOB

int vlan 100
ip address 192.168.100.1 255.255.255.0
no shutdown

int eth 0/0
switchport mode access
switchport access vlan 100
spanning-tree portfast
spanning tree bpdugaurd enable
no shutdown

int eth 0/1
no switchport
ip address 10.1.100.1 255.255.255.254
no shutdown
exit
ip routing
ip route 192.168.100.254 255.255.255.255 10.1.100.0

int eth 1/0
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 100
no shutdown

int eth 2/0
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 100
no shutdown
```

**Router Configuration**:

```bash router
config t
int loopback 100
ip address 192.168.100.254 255.255.255.2555
no shutdown

int eth 0/0
ip address 10.1.100.0 255.255.255.254
no shutdown
ip route 192.168.100.0 255.255.255.0 10.1.100.1
```

**CD1 Configuration**:

```bash
config t
vlan 100
name OOB
int vlan 100
ip address 192.168.100.1 255.255.255.0 
no shutdown
int eth 0/0
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 100
no shutdown
```

**ACC1 Configuration**:

```bash
config t
vlan 100
name OOB
int vlan 100
ip address 192.168.100.11 255.255.255.0 

no shutdown
int eth 0/0
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 100
no shutdown
```

**Objective 2.1 Complete**:

![image objetive 2.1](/images/objective_2.1.png)

## Objective 2.2: Set Up SSH Login on each Device

**device config**:

```bash
config t
ip domain-name netlab.local
crypto generate rsa modulus 2048
username ansible privilege 15 secret mysupersecret

line vty 0 4
transport input ssh
login local
end
write memory
```

**Objective 2.2 Complete**:
![image objetive 2.2](/images/objective_2.2.png)

## Objective 3: Network & Windows Server DC Configuration

```bash
[CLOUD]-----[ R1 ]--[ CD1 ]---[ ACC1 ]-----------[ DC1 ]
            |    |    |          |
            |  [ MANGEMENT SWITCH (MGS) ]
            |        |
        [ Console Server (CS) ]
```

**Interface Plan**:

| DEVICE | Interface    |    IPv4           |    Description  
|--------|--------------|-------------------|-----------------
| R1     |  eth 0/1     | 10.1.1.0/31       | p2p CD1
| CD1    |  eth 0/1     | 10.1.1.1/31       | p2p R1
| CD1    |  vlan 10     | 10.1.10.1/24      | Network Services VLAN
| CD1    |  eth 1/1     |   N/A             | trunk port allowed vlan 10
| ACC1   |  eth 0/1     |   N/A             | trunk port allowed vlan 10
| ACC1   |  eth 1/1-3   |   N/A             | Access port allowed vlan 10
| DC1    |  ens3        |  10.1.10.100/24   | Static IP

**Playbook**:

```yml
- hosts: all
  gather_facts: false
  roles:
    - role: vlans
    - role: interfaces
    - role: routing
    - role: nat
```

> *Note:* don't forget to configure a default route on CD1 to R1

**Windows Server Desktop Provision**:

> set static ipv4
> set name: WIN-DC1-25
> add ADDS Role & DNS Server Role
> Promote to Domain Controller

**Objective 3 Complete**:
![image objetive 3](/images/objective_3.png)
