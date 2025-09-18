This repository is for nordnet cert poc
Terraform –    Private CA and Certificate Issuance Config
This configuration provisions a cross-project Certificate Authority setup in Google Cloud:
	•	Project gouravhalder-sandbox
	◦	Enables the Private CA API
	◦	Creates a CA Pool (myroot-ca-pool)
	◦	Creates a Root Certificate Authority (myroot-ca)
	◦	Protects the CA Pool and Root CA from accidental deletion - made false
	•	Project gouravhalder-careq
	◦	Enables the Private CA API
	◦	Creates a Certificate Manager service account identity
	◦	Grants the service account roles/privateca.certificateRequester on the CA Pool in sandbox
	◦	Creates a Certificate Issuance Config that uses the Root CA from sandbox
This allows certificates in the gouravhalder-careq project to be issued securely from the Root CA managed in gouravhalder-sandbox. 


Google docs links
https://cloud.google.com/certificate-authority-service/docs/creating-ca-pool

Notes to provide permission to SA account - 
gourav_halder@cloudshell:~/ca_setup$ gcloud beta services identity create --service=certificatemanager.googleapis.com \
    --project=gouravhalder-sandbox
Service identity created: service-88700505705@gcp-sa-certificatemanager.iam.gserviceaccount.com

gcloud privateca pools add-iam-policy-binding myroot-ca-pool     --location europe-west4     --member "serviceAccount:service-88700505705@gcp-sa-certificatemanager.iam.gserviceaccount.com"     --role roles/privateca.certificateRequester

gcloud privateca pools add-iam-policy-binding myroot-ca-pool \
    --location europe-west4 \
    --member "serviceAccount:service-88700505705@gcp-sa-certificatemanager.iam.gserviceaccount.com" \
    --role roles/privateca.certificateRequester
