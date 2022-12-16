# Data_Analytics_Solution_in_AWS
This repository provides the instructions for building a data analytics solution.

I have designed an architecture of an analytics solution to ingest, store, and visualize clickstream data which has been created by API Gateway Post method. 



This architecture has interactions between these services in AWS:
- AWS Identity and Access Management (IAM) policy, role and attaching IAM policies to IAM Role.
- Amazon Simple Storage Service (Amazon S3) to store clickstream data.
- AWS Lambda function for Amazon Kinesis Data Firehose to transform data.
- Amazon Kinesis Data Firehose delivery stream to deliver real-time streaming data to Amazon S3.
- Amazon API Gateway to insert data.
- Ireland (eu-west-1) Region has been used for the architecture.

The following architectural diagram shows the flow that I created:

![Architecture](https://github.com/hameddavoudabadi/Data_Analytics_Solution_in_AWS/png/architecture.png "Architecture")
