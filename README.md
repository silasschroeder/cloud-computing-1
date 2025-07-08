# Cloud-Computing-und-Big-Data

STEPS:

- Configure `env.sh`:

```sh
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"
# TODO: export OS_KEY="silasschroeder"
```

- `$ source env.sh`
- `$ terraform init`
- `$ terraform apply`
- `$ ansible-playbook -i openstack-inventory.txt ansible-config.yml`

TODO:

- Comment code / update comments
- Check if terraform key of instance is needed

- Task 1

  - Demonstrate immutable update
  - Nach Änderung:

    - terraform plan <-- Zeigt Änderungen, oder "No changes. Your infrastructure matches the configuration."
    - terraform apply <-- Löscht aktuelle Instanz und erstellt Neue

- Task 2

  - Create versiond infrastructures
  - Demonstrate rollback

- Task 3

  - Install kubernetes
