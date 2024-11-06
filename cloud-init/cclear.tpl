#cloud-config

# chpasswd:
#   expire: false
#   users:
#   - {name: ubuntu, password: "something-secure", type: text}  # Replace "something-secure" with a strong password.
#   # Alternatively, you can use a hashed password:
#   # - {name: ubuntu, password: "<hash of user password>"}  # Generate a hash using: $ openssl passwd "something-secure"

write_files:
- path: /opt/bin/deploy-time-setup.sh
  permissions: '0755'
  content: |
    #!/bin/bash
    set -ex

    wait_for_cclear() {
      local timeout
      local start_time
      local current_time
      local elapsed_time
      local status

      timeout=600 # 10 minutes

      start_time=$(date +%s)

      # Wait for cClear to be available, poll the healthcheck endpoint to verify cClear is up and running.
      while true; do
        set +e
        status=$(curl -s -k -o /dev/null -w "%%{http_code}" --request GET --url https://localhost/api/info/v1)
        set -e
        echo "cClear status: $status"
        if [ "$status" -eq 200 ]; then
          echo "cClear is up and running!"
          break
        fi

        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -ge $timeout ]; then
          echo "Timeout reached. cClear is not up and running."
          exit 1
        fi

        sleep 15
      done
    }

    while true; do
      if [ -d /media/data/cpacket ]; then
        break
      fi
      sleep 1
    done

    cclear_license="${cclear_license}"
    web_password="${web_password}"

    echo "${inclusions}" >/media/data/cpacket/networks-to-scan
    echo "${cvu_lb_ip}" >/media/data/cpacket/networks-to-exclude
    echo "$web_password" >/media/data/cpacket/http-basic-auth

    if [ -n "${cstor_lb_ip}" ]; then
      echo "${cstor_lb_ip}" >>/media/data/cpacket/networks-to-exclude
    fi

    # Ensure cClear APIs are available before proceeding with key activation.
    wait_for_cclear

    # Try to license cClear using the provided license key.
    if [[ -n "$cclear_license" && -n "$web_password" ]]; then
      payload='{"key": "'"$cclear_license"'", "method": ["online", "offline"]}'
      max_retries=5
      retry_count=0

      while [ $retry_count -lt $max_retries ]; do
        set +e

        curl --fail -s -k \
          -u "cpacket:$web_password" \
          -H "Content-Type: application/json" -d "$payload" https://localhost/api/licensing/v2/activation/key

        if [ $? -eq 0 ]; then
          break
        fi

        set -e

        retry_count=$((retry_count + 1))
        sleep 90
      done

      if [ $retry_count -eq $max_retries ]; then
        echo "Key activation failed after $max_retries attempts."
        exit 1
      fi
    fi

    systemctl enable --now managed-device-registration.service
runcmd:
  - /opt/bin/deploy-time-setup.sh
