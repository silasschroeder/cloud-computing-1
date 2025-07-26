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

- Task 4

  - Install Hadoop HDFS as Datalake on the Multi-Node Architecture
  - Save and edit a dummy Dataset using PySpark

  - terraform init
  - export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
    export OS_USERNAME="pfisterer-cloud-lecture"
    export OS_PASSWORD="ss2025"
    export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
    export OS_USER_DOMAIN_NAME="default"
  - terraform apply #creating the instances
  - cd ansible
  - ansible-playbook -i terraform_inventory.sh hadoop.yml #hadoop datalake implementation
  - cd ../
  - scp data/beispiel.csv ubuntu@{master-ip}:/tmp/beispiel.csv #copy dummy csv from local to the master instance
  - ssh@ubuntu{master-ip}
  - hdfs dfs -mkdir -p /user/ubuntu #create directory if not already there
  - hdfs dfs -put /tmp/beispiel.csv /user/ubuntu/beispiel.csv #put the csv from tmp into the datalake
  - Edit the data:
    - source ~/venv/bin/activate #start venv
    - pyspark #start pyspark environment
    - df = spark.read.option("header", "true").csv("/user/ubuntu/beispiel.csv") #read csv from datalake
    - from pyspark.sql.functions import col
    - df2 = df.withColumn("new_column", col("id") * 2) #create new column which doubles the value of id column
    - df2.write.mode("overwrite").option("header", "true").csv("/tmp/beispiel_tmp") #spark exports data in a directory with part-csv files
    - exit() #leave pyspark environment
    - cat /tmp/beispiel_tmp/part-*.csv > /user/ubuntu/beispiel.csv #fuse the temporary part-csv files into a csv file to write back into the lake