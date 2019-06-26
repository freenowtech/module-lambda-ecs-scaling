/* create IAM ROLE */
resource "aws_iam_role" "lambda_ecs_scheduled_scaling" {
  name = "lambda_ecs_scheduled_scaling"
  path = "/"

  assume_role_policy = <<POLICY
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Principal": {
         "Service": "lambda.amazonaws.com"
       },
       "Action": "sts:AssumeRole"
     }
   ]
}
POLICY
}

/* Policy attachements */
resource "aws_iam_role_policy_attachment" "CloudWatchLogs-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = "${aws_iam_role.lambda_ecs_scheduled_scaling.name}"
}

resource "aws_iam_role_policy" "lambda_ecs_scheduled_scaling_policy" {
  name = "lambda_ecs_scheduled_scaling_policy"
  role = "${aws_iam_role.lambda_ecs_scheduled_scaling.name}"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:ListServices",
                "ecs:UpdateService",
                "dynamodb:ListTables",
                "ecs:DescribeServices",
                "ecs:ListClusters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:CreateTable",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "arn:aws:dynamodb:eu-west-1:*:table/services-desiredCount"
        }
    ]
}
POLICY
}

/* Lambda function */

data "archive_file" "source" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "lambda-ecs_scheduled_scaling" {
  description      = "Lambda function for scheduled ECS service scaling."
  filename         = "${path.module}/lambda_function.zip"
  function_name    = "ECSScheduledScaling"
  handler          = "lambda_function.handler"
  role             = "${aws_iam_role.lambda_ecs_scheduled_scaling.arn}"
  runtime          = "python3.7"
  source_code_hash = "${data.archive_file.source.output_base64sha256}"
  timeout          = "900"

  environment {
    variables = {
      ECS_CLUSTER = "${var.ecs_cluster}"
    }
  }
}

/* CloudWatch */
resource "aws_cloudwatch_event_rule" "event_rule-downscaling" {
  description         = "trigger scheduled ECS downscaling"
  name                = "ECSScheduledScaling-Down"
  schedule_expression = "${var.ecs_scheduled_downscaling_expression}"
}

resource "aws_cloudwatch_event_rule" "event_rule-upscaling" {
  description         = "trigger scheduled ECS upscaling"
  name                = "ECSScheduledScaling-Up"
  schedule_expression = "${var.ecs_scheduled_upscaling_expression}"
}

resource "aws_cloudwatch_event_target" "event_target-downscaling" {
  arn       = "${aws_lambda_function.lambda-ecs_scheduled_scaling.arn}"
  rule      = "${aws_cloudwatch_event_rule.event_rule-downscaling.name}"
  target_id = "lambda-ecs_scheduled_scaling-downscaling"
}

resource "aws_cloudwatch_event_target" "event_target-upscaling" {
  arn       = "${aws_lambda_function.lambda-ecs_scheduled_scaling.arn}"
  rule      = "${aws_cloudwatch_event_rule.event_rule-upscaling.name}"
  target_id = "lambda-ecs_scheduled_scaling-upscaling"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda-downscaling" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda-ecs_scheduled_scaling.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.event_rule-downscaling.arn}"
  statement_id  = "AllowECSDownscalingFromCloudWatch"

  depends_on = [
    "aws_lambda_function.lambda-ecs_scheduled_scaling",
  ]
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda-upscaling" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda-ecs_scheduled_scaling.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.event_rule-upscaling.arn}"
  statement_id  = "AllowECSUpscalingFromCloudWatch"

  depends_on = [
    "aws_lambda_function.lambda-ecs_scheduled_scaling",
  ]
}
