#!/bin/bash
kubectl create sa elasticsearch && \
kubectl create --save-config -f accounts/role.yml && \
kubectl create -f services/es-connect.yml && \
kubectl create -f services/discovery.yml && \
kubectl create -f deployments/es-coord.yml && \
sleep 10 && \
kubectl create -f deployments/es-data.yml