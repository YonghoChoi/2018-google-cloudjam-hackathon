#!/bin/bash
kubectl delete sa elasticsearch && \
kubectl delete clusterrolebindings elasticsearch && \
kubectl delete services elasticsearch-connector && \
kubectl delete services elasticsearch-cluster && \
kubectl delete deployments elasticsearch-coordinating-only && \
kubectl delete deployments elasticsearch-data