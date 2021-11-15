provider "aws" {}

### get default vpc
data "aws_vpc" "selected" {
  default = true
}

data "aws_subnet_ids" "example" {
  vpc_id = data.aws_vpc.selected.id
}

data "aws_subnet" "example" {
  for_each = data.aws_subnet_ids.example.ids
  id       = each.value
}

### archiving local lambda code
data "archive_file" "lambda_hello_world" {
  type = "zip"

  source_dir  = "${path.module}/hello-world"
  output_path = "${path.module}/hello-world.zip"
}

### creating the bucket that will store the lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-bucket-sample-xxx9"
  acl    = "private"
}

### sending the archived lambda to the s3 bucket
resource "aws_s3_bucket_object" "lambda_hello_world" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "hello-world.zip"
  source = data.archive_file.lambda_hello_world.output_path

  etag = filemd5(data.archive_file.lambda_hello_world.output_path)
}

### alb security group - allowing port 80
resource "aws_security_group" "alb_security_group" {
  vpc_id      = data.aws_vpc.selected.id
  name        = "alb_security_group"
  description = "security group for the application load balancer"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb_sample" {
  name               = "alb-sample"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [for s in data.aws_subnet.example : s.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "target_group_lambda" {
  name     = "target-group-lambda"
  vpc_id   = data.aws_vpc.selected.id
  target_type = "lambda"
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb_sample.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_lambda.arn
  }
}

### lambda
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "test_lambda" {
  function_name = "HelloWorld"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_bucket_object.lambda_hello_world.key

  runtime = "nodejs12.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_permission" "lb_lambda_permission" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.target_group_lambda.arn
}

resource "aws_lb_target_group_attachment" "attach_tgtgroup_to_lambda" {
  target_group_arn = aws_lb_target_group.target_group_lambda.arn
  target_id        = aws_lambda_function.test_lambda.arn
  depends_on       = [aws_lambda_permission.lb_lambda_permission]
}