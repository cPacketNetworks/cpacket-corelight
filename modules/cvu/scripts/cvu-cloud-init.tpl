#!/bin/bash
# shellcheck disable=SC2154
set -ex

mtu_size="9000"

downstream_ip1="${downstream_tool_ip1}"

gateway_load_balancer_ip="${gwlb_ip}"

capture_nic="eth0"
capture_nic_ip=$(ip a show dev "$capture_nic" | awk -F'[ /]' '/inet /{print $6}')

# Set the MTU size to overcome Microsoft Azure limitation?
mtu_size="9000"
ip li set mtu "$mtu_size" dev "$capture_nic"

config_file="/home/cpacket/boot_config.toml"
touch "$config_file"
chmod a+w /home/cpacket/boot_config.toml

cat >/home/cpacket/boot_config.toml <<EOF_BOOTCFG
vm_type = "azure"
cvuv_mode = "inline"
cvuv_mirror_eth_0 = "$capture_nic"

cvuv_vxlan_id_0 = 1337
cvuv_vxlan_srcip_0 = "$capture_nic_ip"
cvuv_vxlan_remoteip_0 = "$downstream_ip1"

cvuv_gwlb_ip = "$gateway_load_balancer_ip"

[[cvuv_gwlb_vxlans]]
port_dst = 10800
vni = 900
ip_dst = "$gateway_load_balancer_ip"

[[cvuv_gwlb_vxlans]]
port_dst = 10801
vni = 901
ip_dst = "$gateway_load_balancer_ip"
EOF_BOOTCFG
