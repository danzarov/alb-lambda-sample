# alb-lambda-sample

# This sample will:

 - use default vpc
 - use a very simple js [code](https://github.com/danzarov/alb-lambda-sample/blob/master/hello-world/hello.js) that will be archived and used as the lambda function
 - create an s3 bucket to store the lambda archived code
 - send the archived object to the s3 bucket
 - build a security group
   * for the ALB (port 80 opened)
 - build a target group (linked to the lambda function)
 - build a load balancer (application)
 - build a listener for the load balancer (forwards traffic to the target group)
 - create an iam role for the lambda function and attach the policy `AWSLambdaBasicExecutionRole` to the role.