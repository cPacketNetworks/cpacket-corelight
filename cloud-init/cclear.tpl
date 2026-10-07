#cloud-config

write_files:
- path: /etc/cclear/cirrus/cclear.lic
  permissions: '0644'
  content: |
    ${cclear_license}
- path: /etc/cclear/cirrus/db.json
  permissions: '0644'
  content: |
    {
      "autoscaling_clusters": {
        "bcc3052a4d8bd95a04603e5a2": {
          "cloud_service_provider": "azure",
          "cpacket_device_type": "cvu",
          "autoscaling_cluster": {
            "vmss": "${vmss_name}",
            "resource_group": "${resource_group}",
            "subscription_id": "${subscription_id}"
          }
        }
      }
    }
runcmd:
%{ if auto_licensing }
  - systemctl enable --now auto-licensing.service
%{ endif }
%{ if managed_registration }
  - systemctl enable --now managed-device-registration.service
%{ endif }
