# GKE Nodepool Monitoring Alerts - WITH CONCISE DOCUMENTATION
# Based on official GCP documentation

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
}

variable "nodepool_name" {
  description = "GKE Nodepool Name"
  type        = string
}

variable "notification_channels" {
  description = "List of notification channel IDs"
  type        = list(string)
  default     = []
}

# Node CPU Allocatable Utilization Alert (Average across all nodes)
resource "google_monitoring_alert_policy" "nodepool_cpu_high" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - High CPU Utilization (Avg)"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nAverage CPU utilization across nodepool has exceeded 80% for more than 10 minutes."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Nodepool Avg CPU Utilization > 80%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/cpu/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "600s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = [
          "resource.labels.cluster_name",
          "metadata.user_labels.\"cloud.google.com/gke-nodepool\""
        ]
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
    severity    = "warning"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "aggregate"
  }
}

# Node CPU - Any Single Node Alert (for hotspot detection)
resource "google_monitoring_alert_policy" "nodepool_cpu_high_single_node" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - Single Node High CPU"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nAt least one node has CPU utilization exceeding 90% for more than 10 minutes."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Any Node CPU Utilization > 90%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/cpu/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "600s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.9

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
    severity    = "warning"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "per_node"
  }
}

# Node Memory Allocatable Utilization Alert (Average across all nodes)
resource "google_monitoring_alert_policy" "nodepool_memory_high" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - High Memory Utilization (Avg)"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nAverage memory utilization across nodepool has exceeded 85% for more than 10 minutes."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Nodepool Avg Memory Utilization > 85%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/memory/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "600s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.85

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = [
          "resource.labels.cluster_name",
          "metadata.user_labels.\"cloud.google.com/gke-nodepool\""
        ]
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
    severity    = "warning"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "aggregate"
  }
}

# Node Memory - Any Single Node Alert
resource "google_monitoring_alert_policy" "nodepool_memory_high_single_node" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - Single Node High Memory"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nAt least one node has memory utilization exceeding 92% for more than 10 minutes. Risk of pod evictions."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Any Node Memory Utilization > 92%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/memory/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "600s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.92

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
    severity    = "warning"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "per_node"
  }
}

# Critical CPU Alert (Maximum across nodes)
resource "google_monitoring_alert_policy" "nodepool_cpu_critical" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - Critical CPU Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nCRITICAL: Maximum CPU utilization in nodepool has exceeded 95% for more than 5 minutes. Immediate action required."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Nodepool Max CPU Utilization > 95%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/cpu/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "300s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.95

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = [
          "resource.labels.cluster_name",
          "metadata.user_labels.\"cloud.google.com/gke-nodepool\""
        ]
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
      period = "1800s"
    }
  }

  user_labels = {
    severity    = "critical"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "aggregate"
  }
}

# Critical Memory Alert (Maximum across nodes)
resource "google_monitoring_alert_policy" "nodepool_memory_critical" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - Critical Memory Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nCRITICAL: Maximum memory utilization in nodepool has exceeded 95% for more than 5 minutes. Pod evictions likely."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Nodepool Max Memory Utilization > 95%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/memory/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "300s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.95

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = [
          "resource.labels.cluster_name",
          "metadata.user_labels.\"cloud.google.com/gke-nodepool\""
        ]
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
      period = "1800s"
    }
  }

  user_labels = {
    severity    = "critical"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "aggregate"
  }
}

# Node Disk Utilization Alert (Maximum across nodes)
resource "google_monitoring_alert_policy" "nodepool_disk_high" {
  project      = var.project_id
  display_name = "GKE Nodepool ${var.nodepool_name} - High Disk Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Project: ${var.project_id} | Cluster: ${var.cluster_name} | Nodepool: ${var.nodepool_name}\nMaximum ephemeral storage utilization in nodepool has exceeded 80% for more than 10 minutes. May cause pod evictions."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Nodepool Max Disk Utilization > 80%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/ephemeral_storage/allocatable_utilization"
        AND metadata.user_labels."cloud.google.com/gke-nodepool" = "${var.nodepool_name}"
      EOT

      duration   = "600s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = [
          "resource.labels.cluster_name",
          "metadata.user_labels.\"cloud.google.com/gke-nodepool\""
        ]
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
    severity    = "warning"
    component   = "gke"
    nodepool    = var.nodepool_name
    cluster     = var.cluster_name
    project     = var.project_id
    environment = "production"
    alert_type  = "aggregate"
  }
}

# Outputs
output "cpu_high_alert_id" {
  description = "ID of the CPU high utilization alert policy (average)"
  value       = google_monitoring_alert_policy.nodepool_cpu_high.id
}

output "cpu_high_single_node_alert_id" {
  description = "ID of the CPU high single node alert policy"
  value       = google_monitoring_alert_policy.nodepool_cpu_high_single_node.id
}

output "memory_high_alert_id" {
  description = "ID of the memory high utilization alert policy (average)"
  value       = google_monitoring_alert_policy.nodepool_memory_high.id
}

output "memory_high_single_node_alert_id" {
  description = "ID of the memory high single node alert policy"
  value       = google_monitoring_alert_policy.nodepool_memory_high_single_node.id
}

output "cpu_critical_alert_id" {
  description = "ID of the CPU critical utilization alert policy (maximum)"
  value       = google_monitoring_alert_policy.nodepool_cpu_critical.id
}

output "memory_critical_alert_id" {
  description = "ID of the memory critical utilization alert policy (maximum)"
  value       = google_monitoring_alert_policy.nodepool_memory_critical.id
}

output "disk_high_alert_id" {
  description = "ID of the disk high utilization alert policy (maximum)"
  value       = google_monitoring_alert_policy.nodepool_disk_high.id
}
```

**Email notification will now show:**
```
Project: my-project-123 | Cluster: prod-cluster | Nodepool: production-pool
Average CPU utilization across nodepool has exceeded 80% for more than 10 minutes.
