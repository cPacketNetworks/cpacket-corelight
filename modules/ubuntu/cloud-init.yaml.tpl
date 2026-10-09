#cloud-config
# Terminates the traffic cVu-V mirrors to the Corelight sensors. Watch it with: sudo tcpdump -ni ${interface}
write_files:
  - path: /etc/systemd/system/vxlan-mirror.service
    content: |
      [Unit]
      Description=VXLAN interface for traffic mirrored from cVu-V
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=ip link add ${interface} type vxlan id ${vni} dstport ${port}
      ExecStart=ip link set ${interface} up
      ExecStop=ip link delete ${interface}

      [Install]
      WantedBy=multi-user.target

runcmd:
  - systemctl daemon-reload
  - systemctl enable --now vxlan-mirror.service
