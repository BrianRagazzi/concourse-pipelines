#!/bin/bash
fly -t core login -c http://concourse.ragazzilab.com -u myuser -p mypass -n platform-auto
PL=TestResources
fly -t core dp -p $PL
fly -t core sp -p $PL -c testresources.yml -l params-homelab.yml
