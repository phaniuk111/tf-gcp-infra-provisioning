# GKE Node Pool Monitoring Alerts - Filtered by tenant_nar_id
# Production thresholds: CPU 85%, Memory 90%, Disk 85%

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
# CPU ALERT - Node CPU > 85% for 10 minutes
# ====================================================================
resource "google_monitoring_alert_policy" "nodepool_cpu_high" {
  project      = var.project_id
  display_name = "GKE Tenant ${var.tenant_nar_id} - High CPU Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "CPU utilization exceeded 85% for 10+ minutes on tenant ${var.tenant_nar_id} nodes. Check pod resource usage and consider scaling."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Node CPU > 85% for 10 minutes"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/cpu/allocatable_utilization"
        AND metadata.user_labels.tenant_nar_id = "${var.tenant_nar_id}"
      EOT

      duration        = "600s"
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
    alert_type    = "node_cpu"
  }
}

# ====================================================================
# MEMORY ALERT - Node Memory > 90% for 10 minutes
# ====================================================================
resource "google_monitoring_alert_policy" "nodepool_memory_high" {
  project      = var.project_id
  display_name = "GKE Tenant ${var.tenant_nar_id} - High Memory Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Memory utilization exceeded 90% for 10+ minutes on tenant ${var.tenant_nar_id} nodes. Risk of pod evictions and OOMKilled containers."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Node Memory > 90% for 10 minutes"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/memory/allocatable_utilization"
        AND metadata.user_labels.tenant_nar_id = "${var.tenant_nar_id}"
      EOT

      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.90

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
  }
}

# ====================================================================
# DISK ALERT - Node Disk > 85% for 10 minutes
# ====================================================================
resource "google_monitoring_alert_policy" "nodepool_disk_high" {
  project      = var.project_id
  display_name = "GKE Tenant ${var.tenant_nar_id} - High Disk Utilization"
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "Ephemeral storage exceeded 85% for 10+ minutes on tenant ${var.tenant_nar_id} nodes. This can cause pod evictions due to disk pressure."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Node Disk > 85% for 10 minutes"

    condition_threshold {
      filter = <<-EOT
        resource.type = "k8s_node"
        AND resource.labels.cluster_name = "${var.cluster_name}"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "kubernetes.io/node/ephemeral_storage/allocatable_utilization"
        AND metadata.user_labels.tenant_nar_id = "${var.tenant_nar_id}"
      EOT

      duration        = "600s"
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
    alert_type    = "node_disk"
  }
}

# ====================================================================
# OUTPUTS
# ====================================================================
output "cpu_alert_policy_id" {
  value = google_monitoring_alert_policy.nodepool_cpu_high.id
}

output "memory_alert_policy_id" {
  value = google_monitoring_alert_policy.nodepool_memory_high.id
}

output "disk_alert_policy_id" {
  value = google_monitoring_alert_policy.nodepool_disk_high.id
}
```

## 🎯 Updated Thresholds

| Alert | Old | New | Reason |
|-------|-----|-----|--------|
| **CPU** | 80% | **85%** | Normal to run nodes at 80-85% utilization |
| **Memory** | 85% | **90%** | Kubernetes handles memory well up to 90% |
| **Disk** | 80% | **85%** | More headroom before disk pressure |

## 💡 Threshold Recommendations by Environment

### Conservative (More Alerts)
```
CPU:    80%
Memory: 85%
Disk:   80%
```

### **Balanced (Recommended)** ✅
```
CPU:    85%
Memory: 90%
Disk:   85%
```

### Aggressive (Fewer Alerts)
```
CPU:    90%
Memory: 92%
Disk:   90%
