# GKE Node Pool Monitoring Alerts - Filtered by tenant_nar_id
# Using Heredoc (EOT) syntax for better readability
# Filter validated: metadata.user_labels.tenant_nar_id

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
}

variable "tenant_nar_id" {
  description = "Tenant NAR ID (e.g., 173952-1)"
  type        = string
}

variable "notification_channels" {
  description = "List of notification channel IDs"
  type        = list(string)
  default     = []
}

# ====================================================================
# CPU ALERT - Node CPU Utilization > 80%
# ====================================================================
resource "google_monitoring_alert_policy" "nodepool_cpu_high" {
  project      = var.project_id
  display_name = "GKE Tenant ${var.tenant_nar_id} - High CPU Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = <<-EOT
      CPU utilization for tenant ${var.tenant_nar_id} nodes has exceeded 80% for more than 5 minutes.
      
      **Alert Details:**
      - Threshold: 80%
      - Duration: 5 minutes
      - Tenant NAR ID: ${var.tenant_nar_id}
      - Cluster: ${var.cluster_name}
      
      **Actions:**
      1. Check node CPU usage in GKE console
      2. Review pod resource requests/limits
      3. Consider scaling up or adding nodes
    EOT
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Node CPU > 80%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/cpu/allocatable_utilization"
        AND metadata.user_labels.tenant_nar_id = "${var.tenant_nar_id}"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "86400s" # 24 hours
    
    notification_rate_limit {
      period = "3600s" # Re-notify every hour
    }
  }

  user_labels = {
    severity      = "warning"
    tenant_nar_id = var.tenant_nar_id
    alert_type    = "node_cpu"
    managed_by    = "terraform"
  }
}

# ====================================================================
# MEMORY ALERT - Node Memory Utilization > 85%
# ====================================================================
resource "google_monitoring_alert_policy" "nodepool_memory_high" {
  project      = var.project_id
  display_name = "GKE Tenant ${var.tenant_nar_id} - High Memory Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = <<-EOT
      Memory utilization for tenant ${var.tenant_nar_id} nodes has exceeded 85% for more than 5 minutes.
      This may cause pod evictions and OOMKilled containers.
      
      **Alert Details:**
      - Threshold: 85%
      - Duration: 5 minutes
      - Tenant NAR ID: ${var.tenant_nar_id}
      - Cluster: ${var.cluster_name}
      
      **Actions:**
      1. Check for memory leaks in applications
      2. Review pod memory requests/limits
      3. Check for OOMKilled pods
      4. Consider scaling up nodes or adding memory
    EOT
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Node Memory > 85%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/memory/allocatable_utilization"
        AND metadata.user_labels.tenant_nar_id = "${var.tenant_nar_id}"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "86400s"
    
    notification_rate_limit {
      period = "3600s"
    }
  }

  user_labels = {
    severity      = "warning"
    tenant_nar_id = var.tenant_nar_id
    alert_type    = "node_memory"
    managed_by    = "terraform"
  }
}

# ====================================================================
# DISK ALERT - Node Ephemeral Storage > 80%
# ====================================================================
resource "google_monitoring_alert_policy" "nodepool_disk_high" {
  project      = var.project_id
  display_name = "GKE Tenant ${var.tenant_nar_id} - High Disk Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = <<-EOT
      Ephemeral storage utilization for tenant ${var.tenant_nar_id} nodes has exceeded 80%.
      This can cause pod evictions due to disk pressure.
      
      **Alert Details:**
      - Threshold: 80%
      - Duration: 5 minutes
      - Tenant NAR ID: ${var.tenant_nar_id}
      - Cluster: ${var.cluster_name}
      
      **Actions:**
      1. Check which pods are consuming disk space
      2. Review container logs size
      3. Clean up unused images/containers
      4. Consider increasing node disk size
    EOT
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Node Disk > 80%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/ephemeral_storage/allocatable_utilization"
        AND metadata.user_labels.tenant_nar_id = "${var.tenant_nar_id}"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "86400s"
    
    notification_rate_limit {
      period = "3600s"
    }
  }

  user_labels = {
    severity      = "warning"
    tenant_nar_id = var.tenant_nar_id
    alert_type    = "node_disk"
    managed_by    = "terraform"
  }
}

# ====================================================================
# OUTPUTS
# ====================================================================
output "cpu_alert_policy_id" {
  description = "CPU alert policy ID"
  value       = google_monitoring_alert_policy.nodepool_cpu_high.id
}

output "memory_alert_policy_id" {
  description = "Memory alert policy ID"
  value       = google_monitoring_alert_policy.nodepool_memory_high.id
}

output "disk_alert_policy_id" {
  description = "Disk alert policy ID"
  value       = google_monitoring_alert_policy.nodepool_disk_high.id
}

output "alert_policy_names" {
  description = "All alert policy display names"
  value = [
    google_monitoring_alert_policy.nodepool_cpu_high.display_name,
    google_monitoring_alert_policy.nodepool_memory_high.display_name,
    google_monitoring_alert_policy.nodepool_disk_high.display_name
  ]
}
