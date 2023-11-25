resource "google_service_account" "nomad" {
  account_id   = "nomad-sa-${var.nomad_dc}"
  display_name = "Custom Nomad and Consul service account"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_member
resource "google_project_iam_member" "nomad" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.nomad.email}"
}
