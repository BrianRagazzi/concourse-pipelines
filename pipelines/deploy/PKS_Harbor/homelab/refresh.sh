#!/bin/bash
fly -t core login -c http://concourse.ragazzilab.com -u myuser -p mypass -n pks
PL=DEPLOY-PKS
fly -t core dp -p $PL
fly -t core sp -p $PL -c pipeline-singleAZ-S3.yml -l params-creds.yml -l params-om.yml -l params-pks.yml -l params-harbor.yml
