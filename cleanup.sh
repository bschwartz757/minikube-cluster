
# cleanup the minikube so we have a fresh slate for next run
echo "removing the minikube and resetting the environment"
kubectl delete service,statefulsets redis-cluster

kubectl delete configmaps redis-cluster-config

kubectl delete deployment mkredis

kubectl delete service mkredis

for i in `docker image ls | grep 'mkredis'`
  do docker rmi $i
done

echo "stopping the minikube"
minikube stop
