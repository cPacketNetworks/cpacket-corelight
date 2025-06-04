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
