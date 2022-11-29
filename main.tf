data "aws_iam_policy_document" "ecs_scheduler_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ecs_scheduler_lambda" {
  name               = "${var.prefix}ecs_scheduler_lambda"
  assume_role_policy = data.aws_iam_policy_document.ecs_scheduler_lambda.json
}

resource "aws_iam_role_policy_attachment" "ecs_scheduler_lambda_logs" {
  role       = aws_iam_role.ecs_scheduler_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "ecs_scheduler_lambda" {
  name        = "${var.prefix}ecs_scheduler_lambda"
  description = "Policy for modifying ecs service"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Sid": "Invoke",
           "Effect": "Allow",
           "Action": [
               "ecs:UpdateService"
           ],
           "Resource": ${jsonencode([for service in var.services : service.service_arn])}
       }
   ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_scheduler_lambda_ecs" {
  role       = aws_iam_role.ecs_scheduler_lambda.name
  policy_arn = aws_iam_policy.ecs_scheduler_lambda.arn
}

data "archive_file" "ecs_scheduler" {
  type        = "zip"
  output_path = "${path.module}/.ecs_scheduler.zip"
  source {
    content  = <<EOF
import boto3


def lambda_handler(event, context):

    cluster = event.get("cluster")
    service = event.get("service")

    action = event.get("action", "start")

    client = boto3.client("ecs")

    if action == "start":
        print(f"starting {cluster}->{service}")
        client.update_service(
            cluster=cluster,
            service=service,
            desiredCount=1,
        )
    else:
        print(f"stopping {cluster}->{service}")
        client.update_service(
            cluster=cluster,
            service=service,
            desiredCount=0,
        )
EOF
    filename = "main.py"
  }
}

resource "aws_lambda_function" "ecs_scheduler" {
  filename         = data.archive_file.ecs_scheduler.output_path
  source_code_hash = data.archive_file.ecs_scheduler.output_base64sha256
  function_name    = "${var.prefix}ecs_scheduler"
  role             = aws_iam_role.ecs_scheduler_lambda.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
}

data "aws_iam_policy_document" "ecs_scheduler" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "scheduler.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ecs_scheduler" {
  name               = "${var.prefix}ecs_scheduler"
  assume_role_policy = data.aws_iam_policy_document.ecs_scheduler.json
}

resource "aws_iam_policy" "ecs_scheduler" {
  name        = "${var.prefix}ecs_scheduler"
  description = "Policy for triggering lambda"

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
       {
           "Sid": "Invoke",
           "Effect": "Allow",
           "Action": [
               "lambda:InvokeFunction"
           ],
           "Resource": [
              "${aws_lambda_function.ecs_scheduler.arn}"
           ]
       }
   ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_scheduler" {
  role       = aws_iam_role.ecs_scheduler.name
  policy_arn = aws_iam_policy.ecs_scheduler.arn
}

resource "aws_scheduler_schedule" "ecs_scheduler_start" {
  count = length(var.services)

  name = "${var.prefix}${reverse(split("/", var.services[count.index].cluster_arn))[0]}_${reverse(split("/", var.services[count.index].service_arn))[0]}_start"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.services[count.index].start_cron

  target {
    arn      = aws_lambda_function.ecs_scheduler.arn
    role_arn = aws_iam_role.ecs_scheduler.arn
    input = jsonencode({
      action  = "start"
      cluster = var.services[count.index].cluster_arn,
      service = var.services[count.index].service_arn
    })
  }
}

resource "aws_scheduler_schedule" "ecs_scheduler_stop" {
  count = length(var.services)

  name = "${var.prefix}${reverse(split("/", var.services[count.index].cluster_arn))[0]}_${reverse(split("/", var.services[count.index].service_arn))[0]}_stop"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.services[count.index].stop_cron

  target {
    arn      = aws_lambda_function.ecs_scheduler.arn
    role_arn = aws_iam_role.ecs_scheduler.arn
    input = jsonencode({
      action  = "stop",
      cluster = var.services[count.index].cluster_arn,
      service = var.services[count.index].service_arn
    })
  }
}