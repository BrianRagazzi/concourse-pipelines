#!/bin/bash
fly -t core login -c http://concourse.ragazzilab.com -u myuser -p mypass -n download
PL=DOWNLOAD-PKS
fly -t core dp -p $PL
fly -t core sp -p $PL -c pipeline.yml -l params-homelab.yml
