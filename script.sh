#!/bin/bash

zip function.zip api-lambda.py
ZIP_FILE=function.zip
LAMBDA=api-lambda


awslocal lambda create-function \
	--function-name ${LAMBDA} \
	--runtime python3.12 \
	--handler api-lambda.handler \
	--zip-file fileb://${ZIP_FILE} \
	--role arn:aws:iam::000000000000:role/lambda-role
echo "Function created successfully"

sleep 5s

awslocal lambda invoke --function-name ${LAMBDA} \
	output.txt
output=$(cat output.txt)
echo $output

function_url=$(awslocal lambda create-function-url-config --function-name ${LAMBDA} --auth-type NONE --query "FunctionUrl" --output text)
echo "function url is"
echo ${function_url}


LAMBDA_ARN=$(awslocal lambda list-functions --query "Functions[?FunctionName=='api-lambda'].FunctionArn" --output text) 

#configure the apigateway to access lambda
#create the api
awslocal apigateway create-rest-api --name ${LAMBDA} 

API_ID=$(awslocal apigateway get-rest-apis --query "items[?name=='api-lambda'].id" --output text)
PARENT_RESOURCE_ID=$(awslocal apigateway get-resources --rest-api-id ${API_ID} --query "items[?path=='/'].id" --output text)

awslocal apigateway create-resource \
    --rest-api-id ${API_ID} \
    --parent-id ${PARENT_RESOURCE_ID} \
    --path-part "{somethingId}"


RESOURCE_ID=$(awslocal apigateway get-resources --rest-api-id ${API_ID} --query 'items[?path==`/{somethingId}`].id' --output text)
awslocal apigateway put-method \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --request-parameters "method.request.path.somethingId=true" \
    --http-method GET \
    --authorization-type "NONE" \

awslocal apigateway put-integration \
    --rest-api-id ${API_ID} \
    --resource-id ${RESOURCE_ID} \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations \
    --passthrough-behavior WHEN_NO_MATCH \

result=$(awslocal apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name dev)

echo "The URL is"
echo "http://localhost:4566/_aws/execute-api/${API_ID}/dev/test"
