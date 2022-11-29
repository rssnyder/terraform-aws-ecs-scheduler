variable "prefix" {
  description = "Prefix to add to all resources"
  type        = string
  default     = ""
}

variable "services" {
  description = "ECS services and their cron schedules"
  type = list(object({
    cluster_arn = string
    service_arn = string
    start_cron  = string
    stop_cron   = string
  }))
}