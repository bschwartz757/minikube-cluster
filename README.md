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

When we started the cluster above, we started with only one master that handles all 16384 slots in the cluster. We'll need to repurpose one of our slaves as a master. You can use the output of `kubectl exec -it redis-cluster-0 redis-cli cluster nodes` to find a slave node. You will need to look up its pod name and the corresponding ip address using `kubectl get pods --all-namespaces -a -o wide`:

```
# Reset one of the slaves to master
$ kubectl exec -it redis-cluster-2 redis-cli cluster reset soft
# Then rejoin it to the cluster
$ kubectl exec -it redis-cluster-2 redis-cli cluster meet 172.17.0.3 6379
```
You will want to repeat this with another slave, for a total of 3 masters.

## Use redis-trib

Now that we have another free master in the cluster, let's assign it some shards.
```
$ docker run --rm -it zvelo/redis-trib reshard --from f6752d1c571bf7aa6935597aabd9b0c5c47419bf --to f14dc883290304ad1c580e3db473bbffa8d75404 --slots 5461 --yes 172.17.0.4:6379
```
If the `zvelo/redis-trib` docker image is not found on your machine it will be downloaded so you can use it.

The pattern here is `cluster node id:from` to `cluster node id:to` and then the ip address of the destination pod at the end. `--slots 5461` is the number of memory slots to move to the new master (we divide the total number of slots roughly by 3.)

Repeat this for the third new master node.

Running `k exec -it redis-cluster-0 redis-cli cluster nodes` should now show something like the following:
```
44dc43c51b4d0125d35d412b381dbb604675c2a8 172.17.0.6:6379 slave 0e6878e4ea3f3e69b4cd89a8ed44c5f6ec6e3465 0 1508177328965 4 connected
297987961e581cc7cb0fcee2f4c49555bcb12289 172.17.0.10:6379 master - 0 1508177331985 5 connected 5461-10921
e62509bd122cc0cd255dadfb4b3a9ae5af360425 172.17.0.8:6379 myself,master - 0 0 0 connected 10922-16383
0e6878e4ea3f3e69b4cd89a8ed44c5f6ec6e3465 172.17.0.3:6379 master - 0 1508177330979 4 connected 0-5460
cf36f1fbcfb12ce287521fb05c5371d3894ae779 172.17.0.7:6379 slave e62509bd122cc0cd255dadfb4b3a9ae5af360425 0 1508177329971 0 connected
4617dfb59401a884ee649d8106c63a575551d65c 172.17.0.5:6379 slave 297987961e581cc7cb0fcee2f4c49555bcb12289 0 1508177327958 5 connected
```
Note that all master nodes now contain some slots.

## Cluster info
`docker run zvelo/redis-trib check <host-ip>:<port>`
Shows information about each cluster node & it's relationship to other nodes

`docker run zvelo/redis-trib info <host-ip>:<port>`
Shows an abbreviated list of only the master nodes & their slot configuration

## Rebalance the cluster

If needed, you can rebalance the cluster:
```
docker run zvelo/redis-trib info <host-ip>:<port>
172.17.0.8:6379 (e62509bd...) -> 0 keys | 5462 slots | 1 slaves.
172.17.0.10:6379 (29798796...) -> 0 keys | 5461 slots | 1 slaves.
172.17.0.3:6379 (0e6878e4...) -> 0 keys | 5461 slots | 1 slaves.
[OK] 0 keys in 3 masters.
0.00 keys per slot on average.
```
```
docker run zvelo/redis-trib rebalance --verbose --weight e62509bd=1.0 --weight 29798796=0.9 --weight 0e6878e4=1.1 172.17.0.10:6379
Connecting to node 172.17.0.10:6379: OK
Connecting to node 172.17.0.7:6379: OK
Connecting to node 172.17.0.3:6379: OK
Connecting to node 172.17.0.6:6379: OK
Connecting to node 172.17.0.5:6379: OK
Connecting to node 172.17.0.8:6379: OK
>>> Performing Cluster Check (using node 172.17.0.10:6379)
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
>>> Rebalancing across 3 nodes. Total weight = 3.0
172.17.0.3:6379 balance is -547 slots
172.17.0.8:6379 balance is 1 slots
172.17.0.10:6379 balance is 546 slots
Moving 546 slots from 172.17.0.10:6379 to 172.17.0.3:6379
##################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################################
Moving 1 slots from 172.17.0.8:6379 to 172.17.0.3:6379
```

# Create a dockerized app and connect to the Redis cluster
The example app is located at `app/index.js`. The app uses the Nodejs package `ioredis` to connect to the Redis cluster and provides a web interface.

From the root of your project:
- Ensure minikube is running and kubectl is referencing its context: `kubectl config use-context minikube` - ensure it can communicate with the cluster: `kubectl cluster-info`
- Ensure docker context is set to the minikube context: `eval $(minikube docker-env)` **Note: the following steps will not work unless docker is referencing the minikube context. Also, you will need to set this for each terminal window you use to run the docker commands.**
- Build the docker image: `docker build -t mkredis:v1 .`
- Create your deployment: `kubectl run mkredis --image=mkredis:v1 --port=4101`
- Verify the deployment: `kubectl get deployments`
- Create a service: `kubectl expose deployment mkredis --type=LoadBalancer` **While you specified a port in the Deployment step, the Service actually exposes the app publicly outside the cluster**
- Verify the service: `kubectl get services`
- Access the exposed app on the web: `minikube service mkredis`
- View the app's logs: `kubectl logs <POD-NAME>`

## Update the app
To update the app, simply repeat the steps:
- Build the app using docker, incrementing the version: `docker build -t mkredis:v2 .`
- Update the deployment: `kubectl set image deployment/mkredis mkredis=mkredis:v2`
- Run the app again to the see the changes: `minikube service mkredis`





To clean this mess off your Minikube VM:
```
# Delete service and statefulset
$ kubectl delete service,statefulsets redis-cluster

# To prevent potential data loss, deleting a statefulset doesn't delete the pods. Gotta do that manually.
$ kubectl delete pod redis-cluster-0 redis-cluster-1 redis-cluster-2 redis-cluster-3 redis-cluster-4 redis-cluster-5
```

## TODO
