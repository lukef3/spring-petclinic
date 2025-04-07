output "instance_external_ip" {
  description = "External IP address of the GCE VM instance"
  value       = google_compute_instance.docker_host.network_interface[0].access_config[0].nat_ip
}
