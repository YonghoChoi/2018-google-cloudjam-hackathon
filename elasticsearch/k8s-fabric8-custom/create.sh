#!/bin/bash
kubectl create sa elasticsearch && \
kubectl create --save-config -f services/role.yml && \
kubectl create -f services/loadbalancer.yml && \
kubectl create -f services/discovery.yml && \
kubectl create -f deployments/es-master.yml && \
kubectl create -f deployments/es-coord.yml && \
kubectl create -f deployments/es-data.yml