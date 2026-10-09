#cloud-config
#
# # SSH password authentication is disabled by default for security reasons.
# # Enabling SSH password authentication is not recommended as it can expose your system to brute-force attacks.
#
# # If you still want to enable password authentication for SSH, you can do so by uncommenting the following lines and updating them as needed:
# ssh_pwauth: true
#
# # To set a password for a user, uncomment and update the following section:
# chpasswd:
#   expire: false  # This ensures the password does not expire.
#   users:
#   - {name: ubuntu, password: "something-secure", type: text}  # Replace "something-secure" with a strong password.
#   # Alternatively, you can use a hashed password:
#   # - {name: ubuntu, password: "<hash of user password>"}  # Generate a hash using: $ openssl passwd "something-secure"

write_files:
  - path: /home/cpacket/write_to_boot_config.sh
    permissions: '0744'
    content: | 
      #!/bin/bash
      set -ex

      bootconfig_file="/home/cpacket/boot_config.toml"

      # Comma-separated list of IPV4 addresses
      downstream_tools="${DOWNSTREAM_IPV4_ADDRESSES}"

      # Convert the comma-separated list into an array
      IFS=',' read -r -a downstream_tool_addresses <<<"$(echo "$downstream_tools" | tr -d '[:space:]')"

      capture_nic="$(ip -j a | jq -r '[.[] | select(.flags | all(. != "SLAVE")) | select(.flags | all(. != "LOOPBACK")) | select(.qdisc == "mq")] | .[-1]')"
      capture_nic_name="$(echo "$capture_nic" | jq -r '.ifname')"
      capture_nic_ip=$(echo "$capture_nic" | jq -r '.addr_info | .[] | select(.family == "inet").local')
      
      # In order to set the web password, set web_hash_value equal to the a hash generated using : htpasswd -bnBC 12 "" <password> | sed 's/^://; s/\n//;s/^\$2y/\$2b/'
      # web_hash_value='$2b$12$nNv0nTrLnnBv2ClKi/jTqO..zBdR45hkuB3/TcEpJaYZwSkLU0k9W'
      
      touch "$bootconfig_file"
      chmod a+w "$bootconfig_file"

      cat >"$bootconfig_file" <<BOOTCFG_HEADER
      vm_type = "azure"
    %{ if MIRROR }
      cvuv_mode = "endpoint"
      cvuv_capture_eth_mtu = 1508
    %{ else }
      cvuv_mode = "inline"
    %{ if GWLB }
      # As confirmed by Microsoft, the MTU must be increased when using a GWLB and configuring an outbound route
      # for workload machines behind a load balancer.
      # Recommended value for the MTU is 4000.
      cvuv_capture_eth_mtu = 4000
    %{ endif }
    %{ endif }
      cvuv_capture_dev = "$capture_nic_name"
      web_hash = "$web_hash_value"
      BOOTCFG_HEADER

      # In the source, before Terraform templates have replaced values,
      # the double dollar signs are necessary to escape the template interpolation.
      # (The cloud init script will not have double dollar signs.)
      for tools_index in "$${!downstream_tool_addresses[@]}"; do
        name_index=$((tools_index))
        leet_index=$((tools_index + 1337))
        cat >>"$bootconfig_file" <<ADDITIONAL_TOOLS
      cvuv_vxlan_id_$${name_index} = $leet_index
      cvuv_vxlan_srcip_$${name_index} = "$capture_nic_ip"
      cvuv_vxlan_remoteip_$${name_index} = "$${downstream_tool_addresses[$tools_index]}"
    %{ if MIRROR }
      cvuv_endpoint_vxlan_id_$${name_index} = 27
    %{ endif }
      ADDITIONAL_TOOLS
      done

      if [ -n "${STATS_DB_IP}" ]; then
        cat >>"$bootconfig_file" <<STATS
      stats_db_server = "${STATS_DB_IP}"
      STATS
      fi

      if [ -n "${GWLB_IPV4_ADDRESS}" ]; then
        cat >>"$bootconfig_file" <<GWLB
      cvuv_gwlb_ip = "${GWLB_IPV4_ADDRESS}"
      [[cvuv_gwlb_vxlans]]
      port_dst = ${GWLB_INTERNAL_VXLAN_PORT}
      vni = ${GWLB_INTERNAL_VXLAN_VNI}
      ip_dst = "${GWLB_IPV4_ADDRESS}"
      [[cvuv_gwlb_vxlans]]
      port_dst = ${GWLB_EXTERNAL_VXLAN_PORT}
      vni = ${GWLB_EXTERNAL_VXLAN_VNI}
      ip_dst = "${GWLB_IPV4_ADDRESS}"
      GWLB
      fi

runcmd:
  - /home/cpacket/write_to_boot_config.sh
