# k8s-net-labs
Kubernetes networking labs for KubeCon EU 2020 talk


After cloning this repo, to follow along you **either** need to install:
- Docker [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)
- Footloose [https://github.com/weaveworks/footloose#install](https://github.com/weaveworks/footloose#install)

**Or** have a working Vagrant + VirtualBox setup -- the Vagrantfile in this repo has the appropriate Docker+Footloose setup already in it.

Running Docker+Footloose natively is prefered for resource consumption reasons.

---


Once you are either SSH'd in to the Vagrant box (`vagrant up && vagrant ssh`) or have Docker+Footloose set up, you will probably need to become root to fully support Footloose (`sudo -s`, `su -`, or however you prefer).  You need to be in the folder for this repo (mounted to `/labs/` if you are in the Vagrant box).

Then to start the different environments, you can `cd` to the directory you want (`flannel/` for k3s with Flannel or `calico/` for k3s with Calico), then run `./bootstrap.sh` (for the Flannel one) or `./bootstrap-calico.sh` (for the Calico one) to start the k3s install.

Once the cluster is up, you can SSH in with either `footloose ssh root@node0` (or `node1`, or `node2`) for the Flannel install or `footloose -c footloose-calico.yaml ssh root@calico-node0` (or `calico-node1`, or `calico-node2`) for the Calico install.

For the Calico install, you bring up Calico with `kubectl apply -f calico-k3s.yaml` when on `calico-node0`.
