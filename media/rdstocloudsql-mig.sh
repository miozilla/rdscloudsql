#!/bin/bash

# === USER CONFIGURATION ===
RDS_HOST="rds-endpoint.amazonaws.com"
RDS_USER="rds_username"
RDS_PASS="rds_password"
RDS_DB="database_name"

GCP_PROJECT="gcp-project-id"
GCS_BUCKET="gcs-bucket-name"          # Must already exist
CLOUD_SQL_INSTANCE="cloudsql-instance"
CLOUD_SQL_DB="target_database_name"        # Usually same as RDS_DB

DUMP_FILE="rds_dump.sql"
GCS_PATH="gs://${GCS_BUCKET}/${DUMP_FILE}"

# === Step 1: Dump RDS MySQL Data ===
echo "Dumping RDS MySQL database..."
mysqldump -h $RDS_HOST -u $RDS_USER -p$RDS_PASS $RDS_DB --single-transaction --quick --set-gtid-purged=OFF > $DUMP_FILE

if [[ $? -ne 0 ]]; then
  echo "mysqldump failed. Check credentials or network access."
  exit 1
fi

# === Step 2: Upload SQL dump to GCS ===
echo "Uploading dump file to Google Cloud Storage..."
gsutil cp $DUMP_FILE $GCS_PATH

if [[ $? -ne 0 ]]; then
  echo "Upload to GCS failed. Check bucket permissions."
  exit 1
fi

# === Step 3: Import into Cloud SQL ===
echo "Importing dump into Cloud SQL..."
gcloud sql import sql $CLOUD_SQL_INSTANCE $GCS_PATH \
  --database=$CLOUD_SQL_DB \
  --project=$GCP_PROJECT

if [[ $? -ne 0 ]]; then
  echo "Import into Cloud SQL failed. Check permissions or SQL syntax."
  exit 1
fi

# === Step 4: Clean Up (optional) ===
echo "Cleaning up local and GCS files..."
rm $DUMP_FILE
gsutil rm $GCS_PATH

echo "Migration Completed."

# verify migrated database
# gcloud sql connect $CLOUD_SQL_INSTANCE --user=root --database=$CLOUD_SQL_DB

