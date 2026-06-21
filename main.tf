resource "google_compute_network" "vpc_network" {
  name                    = "gke-vpc-1"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet-1"
  region        = "us-east4"
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = "10.2.0.0/24"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.3.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.4.0.0/20"
  }
}

resource "google_compute_firewall" "allow-internal" {
  name    = "internal-firewall"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "all"
  }

  source_ranges = ["10.2.0.0/24", "10.3.0.0/16", "10.4.0.0/20"]
}

resource "google_compute_router" "router" {
  name    = "gke-router-1"
  region  = "us-east4"
  network = google_compute_network.vpc_network.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "gke-cloud-nat-1"
  router                             = google_compute_router.router.name
  region                             = "us-east4"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_container_cluster" "primary" {

  name                     = "gke-cluster-1"
  location                 = "us-east4"
  network                  = google_compute_network.vpc_network.id
  subnetwork               = google_compute_subnetwork.subnet.id
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"

  ip_allocation_policy {

    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {

    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  deletion_protection = false
}

resource "google_container_node_pool" "primary_preemptible_nodes" {

  name       = "node-pool-1"
  cluster    = google_container_cluster.primary.name
  location   = "us-east4"
  node_count = 2

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {

    machine_type = "e2-medium"
    image_type   = "ubuntu_containerd"
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }
}









  