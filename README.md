# Redis Cluster on Kubernetes

This k8s module is intended to simplify the creation and operation of a Redis Cluster deployment in Kubernetes.

## Requirements

- Kubernetes 1.5.0+
- Minikube to run the module locally

## How it works

These directions assume some familiarity with [Redis Cluster](http://redis.io/topics/cluster-tutorial).

When you create the resources in Kubernetes, it will create a 6-member (the minimum recommended size) [Stateful Set](https://kubernetes.io/docs/concepts/abstractions/controllers/statefulsets/) cluster where the first (0th) member is the master and all other members are slaves.
While that's sufficient for getting a cluster up and running, it doesn't distribute cluster slots like you would expect from a real deployment. In addition, automatic failover won't work because the cluster requires at least 2 masters to form a quorum.

## Setup

Run the init script in the project root
```
./minikube.init.sh
```
This will perform the necessary steps to download kubectl, docker, minikube, and xhyve. The setup script uses Homebrew, which will make it easy to manage and update these resources as needed.

Once all the pods are initialized, you can use `kubectl exec` commands to examine the redis cluster:
```
$ kubectl exec -it redis-cluster-0 redis-cli cluster nodes
075293dd82cee03749b983de78cce0ae16b6fc9b 172.17.0.7:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198032209 1 connected
a329f22420fa5ad50184ad8ae4dfcc81092f0e07 172.17.0.5:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198028663 1 connected
ee3e96e11961a24ea705dfdcd53d507bd491a57e 172.17.0.8:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198033717 1 connected
4fa0955c6bd58d66ede613bed512a7244c84b34e 172.17.0.3:6379 myself,master - 0 0 1 connected 0-16383
73c02583f854f65e47a2389419c9a89be3733491 172.17.0.4:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198031701 1 connected
413898a0f8b835e0f8856798300f3451d8211ff4 172.17.0.6:6379 slave 4fa0955c6bd58d66ede613bed512a7244c84b34e 0 1468198032713 1 connected
```

```
# Also, you should be able to use redis-cli to connect to a cluster node we just created
$ kubectl exec -t -i redis-cluster-0 redis-cli
```

# To reshard a cluster

When we started the cluster above, we started with only one master that handles all 16384 slots in the cluster. We'll need to repurpose one of our slaves as a master:

```
# Reset one of the slaves to master
$ kubectl exec -it redis-cluster-2 redis-cli cluster reset soft
# Then rejoin it to the cluster
$ kubectl exec -it redis-cluster-2 redis-cli cluster meet 172.17.0.3 6379
```
You will want to repeat this twice, for a total of 3 masters.

## Use redis-trib

The setup script will also install redis-trib, a useful command-line tool for managing your Redis cluster.

Now that we have another free master in the cluster, let's assign it some shards.
```
$ docker run --rm -it zvelo/redis-trib reshard --from f6752d1c571bf7aa6935597aabd9b0c5c47419bf --to f14dc883290304ad1c580e3db473bbffa8d75404 --slots 8192 --yes 172.17.0.4:6379
```




To clean this mess off your Minikube VM:
```
# Delete service and statefulset
$ kubectl delete service,statefulsets redis-cluster

# To prevent potential data loss, deleting a statefulset doesn't delete the pods. Gotta do that manually.
$ kubectl delete pod redis-cluster-0 redis-cluster-1 redis-cluster-2 redis-cluster-3 redis-cluster-4 redis-cluster-5
```

## TODO
