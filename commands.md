# Lab set-up

```
git clone https://github.com/korvus81/k8s-net-labs.git
cd k8s-net-labs
```

---
## Optional, if you want to run in Vagrant instead of Footloose/Docker

```
vagrant up
vagrant ssh
sudo -s
cd /labs
```

---


# Container networking

```
ip addr
```

```
apk add docker
/etc/init.d/docker start
ip addr
brctl show
```

```
docker run --rm -d --name my-alpine alpine sleep 1000
ip addr
brctl show
docker exec -it my-alpine sh
ip addr
exit
```

```
docker run --rm -d --name my-alpine2 alpine sleep 1000
ip addr
brctl show
docker exec -it my-alpine2 sh
ip addr
ping 172.17.0.2
ip neigh
exit
```

---
# Starting the cluster and services in iptables

If you haven't already, you probably need to be root to use Docker in most cases
```
sudo -s
```

```
cd flannel/
cat footloose.yaml
cat bootstrap.sh
```

```
./bootstrap.sh
footloose ssh root@node0
```

I ran this several times until the nodes fully came up:
```
kubectl get no
```

```
kubectl get no -o wide
kubectl get po --all-namespaces
kubectl apply -f hello-kubernetes.yaml
kubectl get po
kubectl get svc
kubectl get endpoints
```

Curl the service IP of the `hello-kubernetes` service -- I am demonstrating here how it will give us a random back-end pod (one of the "endpoints" for that service):
```
curl -s http://10.43.7.125
```

Same thing, but greps out the part of the HTML output that has the pod name in it:
```
curl -s http://10.43.7.125 | grep hello-kubernetes
```

This lists the iptables nat table, chain KUBE-SERVICES.  -n keeps addresses and ports numeric because sometimes using the names can actually be more confusing, in my opinion ([ExplainShell](https://explainshell.com/explain?cmd=iptables+-n+-t+nat+-L+KUBE-SERVICES))
```
iptables -n -t nat -L KUBE-SERVICES
```

This gets the chain for our service.  The name may be different for you, but it is the one with the comment `/* default/hello-kubernetes: cluster IP */` that *isn't* the KUBE-MARK-MASQ line:
```
iptables -n -t nat -L KUBE-SVC-HSXJWNVOHR2BCTLA
```

This will also be different for you, but it's one of the three chains that should come out of the KUBE-SVC-* chain.  I *think* SEP stands for Service EndPoint -- these correlate to what you see when you run `kubectl get endpoints <servicename>`
```
iptables -n -t nat -L KUBE-SEP-7X552I7U2AYRAY3A
```

This is just for showing the pod IPs so you can see how they correlate with the chains:
```
kubectl get po -o wide
```

```
iptables -n -t nat -L KUBE-POSTROUTING
iptables -n -t nat -L KUBE-MARK-MASQ
```


---
# Flannel

```
ip addr
brctl show
ip route 
```

Lookin at node yaml to look at the `spec.podCIDR` value, here it is `10.24.0.0/24` for `node0`
```
kubectl get no node0 -o yaml
```

```
kubectl get po -o wide
kubectl apply -f hello-kubernetes.yaml
kubectl get po -o wide
kubectl get svc
kubectl get po -o wide
```


I run this in one window while creating traffic in a different window.  ([ExplainShell](https://explainshell.com/explain?cmd=tshark+--color+-i+eth0+-f+%22port+8472%22))
```
tshark --color -i eth0 -f "port 8472"
```


The pod name below is the pod that is running on node0 -- I used that to make sure my tshark capture (also running on node0) would see it.  The IP in the wget command is our service IP for the `hello-kubernetes` service.
```
kubectl exec hello-kubernetes-844ccd668f-x5hj4 -- wget -q -O - http://10.43.190.81 | grep hello-kubernetes
```

This version of the tshark command parses VXLAN traffic properly.  Note that the reason we have to tell it port 8472 is VXLAN is that linux uses that port for historical reasons, but the official VXLAN port is 4789. ([ExplainShell](https://explainshell.com/explain?cmd=tshark+--color+-i+eth0+-d+udp.port%3D8472%2Cvxlan++-f+%22port+8472%22))
```
tshark --color -i eth0 -d udp.port=8472,vxlan  -f "port 8472"
```

Repeating this to get another set of data:
```
kubectl exec hello-kubernetes-844ccd668f-x5hj4 -- wget -q -O - http://10.43.190.81 | grep hello-kubernetes
```

This is the same as the last one but with `-V` for verbose mode and `-c 2` to limit the capture to two packets because verbose output gets out of control quickly ([ExplainShell](https://explainshell.com/explain?cmd=tshark+--color+-V+-i+eth0+-d+udp.port%3D8472%2Cvxlan++-c+2+-f+%22port+8472%22))
```
tshark --color -V -i eth0 -d udp.port=8472,vxlan  -c 2 -f "port 8472"
```


---
# Calico

For cleaning up flannel:
```
footloose delete
```

Depending on where you start, you want to go into the `calico` folder:
```
cd k8s-net-labs/calico
```

```
./bootstrap-calico.sh
cat footloose-calico.yaml
cat bootstrap-calico.sh
```

```
footloose -c footloose-calico.yaml ssh root@calico-node0
kubectl get no -o wide
kubectl get po --all-namespaces -o wide
```

Install Calico:
```
kubectl apply -f calico-k3s.yaml

```

```
diff calico-k3s.yaml calico.yaml
kubectl get po --all-namespaces -o wide
ip addr
brctl show
ip route
kubectl get po --all-namespaces -o wide |grep node0
kubectl get no -o wide

```

At this point I open up another terminal window and ssh into `calico-node0`.  This capture ended up picking interface `tunl0` to capture on, which could have been done explicitly with a `-i tunl0`
```
footloose -c footloose-calico.yaml ssh root@calico-node0
tshark -f "not port 22"
```

In the original window:
```
kubectl apply -f hello-kubernetes.yaml
kubectl get svc 
kubectl get po --all-namespaces -o wide |grep node0|grep hello
```

This pod name will be the one from the last command -- almost certainly different when you run it -- but it's the `hello-kubernetes` pod on `calico-node0`
```
kubectl exec hello-kubernetes-844ccd668f-6x5ms -- wget -O - -q http://hello-kubernetes |grep hello-kubernetes
```

Back in the tab where we were capturing traffic with `tshark`:
```
tshark -i eth0 -f "not port 22"
```

In the other tab to generate traffic (run until I saw it get a pod that wasn't on node0 -- I didn't want to see the pod name I'm execing into):
```
kubectl exec hello-kubernetes-844ccd668f-6x5ms -- wget -O - -q http://hello-kubernetes |grep hello-kubernetes
```

Back in the `tshark` tab, we capture using WireShark's packet dissector for HTTP (the second with verbose packet dissection on): 
```
tshark -i eth0 -Y "http"
tshark -i eth0 -V -Y "http"
```

```
grep -i bgp /etc/services
tcpdump -i eth0 port 179
tshark -i eth0 -Y "bgp"
```

In the original window:
```
kubectl delete po hello-kubernetes-844ccd668f-6x5ms
kubectl get po --all-namespaces -o wide |grep node0|grep hello
ip route
kubectl scale deploy hello-kubernetes --replicas=200
```

Note: at this point, I cut part of the video out because that cluster takes a long time to scale up 200 pods, so it may take a while if you try this.  The `kubectl` command below is just to count the number of running `hello-kubernetes` pods on `calico-node0`
```
kubectl get po --all-namespaces -o wide | grep node0 | grep hello | grep Running | wc -l
ip route | tail
ip route | grep tunl
```

Once we are done playing around, I scale the `hello-kubernetes` deployment back down so we aren't running hundreds of pods in a cluster made of Docker containers...
```
kubectl scale deploy hello-kubernetes --replicas=3
```

