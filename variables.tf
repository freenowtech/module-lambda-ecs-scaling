variable "ecs_cluster" {
  description = "The name of the ECS Cluster to scale"
}

variable "ecs_scheduled_downscaling_expression" {
  description = "The scheduling expression for the CloudWatch rule that triggers scheduled ECS Service downscaling (GMT)"
  default     = "cron(00 21 * * ? *)"
}

variable "ecs_scheduled_upscaling_expression" {
  description = "The scheduling expression for the CloudWatch rule that triggers scheduled ECS Service upscalin (GMT)"
  default     = "cron(00 5 * * ? *)"
}
