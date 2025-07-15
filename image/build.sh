#!/bin/bash

DATE_STRING=$(date +%F-%H%M%S)
docker rmi ragazzilab/pipelineimage:latest
docker rmi harbor.lab.brianragazzi.com/library/pipelineimage:latest

docker build -t ragazzilab/pipelineimage:$DATE_STRING  -f ./Dockerfile .
docker tag ragazzilab/pipelineimage:$DATE_STRING harbor.lab.brianragazzi.com/library/pipelineimage:$DATE_STRING
docker tag ragazzilab/pipelineimage:$DATE_STRING harbor.lab.brianragazzi.com/library/pipelineimage:latest
docker push harbor.lab.brianragazzi.com/library/pipelineimage:$DATE_STRING
docker push harbor.lab.brianragazzi.com/library/pipelineimage:latest


