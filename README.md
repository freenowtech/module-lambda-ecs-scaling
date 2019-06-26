# module-lambda-ecs-scaling

This Terraform module will create the Lambda function, the CloudWatch triggers and the required IAM permissions for ECS and DynamoDB.

## Overview
AWS does not provide a simple way to scale services in ECS on a predefined schedule. This Lamdba function will scale all services on the cluster down to 0 on a configurable schedule and scale up again to whatever was the desired count before downscaling.

Please note that this Lambda function will not scale down or up the number of ECS instances. This requires another mechanism which is not covered in this project.

The Lambda funtion is triggered by two CloudWatch rules, one for down- and one for up-scaling. Both trigger the same Lambda function on a regular schedule which will then scale down or up based on the name of the calling CloudWatch rule.
Before scaling down, a dynamodb table will be updated with the desired count of the service. If the DynamoDB table does not exist, the Lambda function will create it. While scaling up, the desired count will be read from DynamoDB and the service will be updated accordingly.

```
module "module-lambda-ecs-scaling" {
  source = "github.com/mytaxi/module-lambda-ecs-scaling"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| ecs\_cluster | The name of the ECS Cluster to scale | string | n/a | yes |
| ecs\_scheduled\_downscaling\_expression | The scheduling expression for the CloudWatch rule that triggers scheduled ECS Service downscaling (GMT) | string | `"cron(00 21 * * ? *)"` | no |
| ecs\_scheduled\_upscaling\_expression | The scheduling expression for the CloudWatch rule that triggers scheduled ECS Service upscalin (GMT) | string | `"cron(00 5 * * ? *)"` | no |

## Contributing

Contributions are welcome! See our [CONTRIBUTING.md](CONTRIBUTING.md) for more information.

## Maintainers

See [MAINTAINERS.md](MAINTAINERS.md)
