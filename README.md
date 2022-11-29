# terraform-aws-ecs-scheduler

schedule ecs tasks using eventbridge and lambda

## Example

```terraform
module "ecs-schedule" {
  source = "git::https://github.com/rssnyder/terraform-aws-ecs-scheduler.git"
  prefix = "myservice_"
  services = [
    {
      cluster_arn = aws_ecs_cluster.dev.id,
      service_arn = aws_ecs_service.myservice.id,
      start_cron  = "cron(0 13 ? * MON-FRI *)",
      stop_cron   = "cron(0 21 ? * MON-FRI *)"
    },
    {
      cluster_arn = aws_ecs_cluster.dev.id,
      service_arn = aws_ecs_service.myotherservice.id,
      start_cron  = "cron(0 13 ? * MON-FRI *)",
      stop_cron   = "cron(0 21 ? * MON-FRI *)"
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| prefix | Prefix to add to all resources | `string` | | no |
| services | ECS services and their cron schedules | `list(object({cluster_arn = string, service_arn = string, start_cron  = string, stop_cron   = string}))` | | yes |


## Resources

| Name | Type |
|------|------|
|ecs_scheduler_lambda|aws_iam_role|
|ecs_scheduler_lambda_logs|aws_iam_role_policy_attachment|
|ecs_scheduler_lambda|aws_iam_policy|
|ecs_scheduler_lambda_ecs|aws_iam_role_policy_attachment|
|ecs_scheduler|aws_lambda_function|
|ecs_scheduler|aws_iam_role|
|ecs_scheduler|aws_iam_policy|
|ecs_scheduler|aws_iam_role_policy_attachment|
|ecs_scheduler_start|aws_scheduler_schedule|
|ecs_scheduler_stop|aws_scheduler_schedule|
