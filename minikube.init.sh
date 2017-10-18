#!/usr/bin/env bash

###########################################
# This is the project's developer toolkit #
# @author Blake Schwartz                  #
###########################################
read -r -p "need to install homebrew or check for upgrades? [y|N] " response
if [[ $response =~ ^(y|yes|Y) ]];then
  echo "checking homebrew install"
  brew_bin=$(which brew) 2>&1 > /dev/null
  if [[ $? != 0 ]]; then
    echo "installing homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    if [[ $? != 0 ]]; then
      error "unable to install homebrew, script $0 abort!"
      exit 2
    fi
  else
    # Make sure we’re using the latest Homebrew
    echo "updating homebrew..."
    brew update
    echo "before installing brew packages, we can upgrade any outdated packages."
    read -r -p "run brew upgrade? [y|N] " response
    if [[ $response =~ ^(y|yes|Y) ]];then
        # Upgrade any already-installed formulae
        echo "upgrade brew packages..."
        brew upgrade
        echo "brews updated..."
    else
        echo "skipped brew package upgrades.";
    fi
  fi
  echo "looking for nvm"
  brew list nvm > /dev/null 2>&1 | true
  if [[ ${PIPESTATUS[0]} != 0 ]]; then
      echo "brew install nvm"
      brew install nvm
      if [[ $? != 0 ]]; then
        error "failed to install nvm! aborting..."
        exit -1
      fi
  fi
  export NVM_DIR=~/.nvm
  source $(brew --prefix nvm)/nvm.sh
  nvm install $(cat app/.nvmrc)
else
  echo "skipping homebrew installation"
fi

reqs="kubectl docker minikube xhyve"
# grep for
read -r -p "first time running the script? [y|N] " response
if [[ $response =~ ^(y|yes|Y) ]];then
  for req in $reqs
  do
    echo "ensuring you have $req installed on your machine"
    brew list $req > /dev/null 2>&1 | true
    if [[ ${PIPESTATUS[0]} != 0 ]]; then
      if [[ $req == "kubectl" ]]; then
        echo "brew install $req"
      elif [[ $req == "xhyve" ]]; then
        echo "installing xhyve"
        brew install docker-machine-driver-xhyve
        echo "setting permissions on xhyve"
        sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
        sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
      else
        echo "brew install $req"
        brew cask install $req
      fi
      if [[ $? != 0 ]]; then
        error "failed to install $req! aborting..."
        exit -1
      fi
    fi
  done
  echo "all dependencies are up to date"
else
  echo "skipping depcheck"
fi

echo "starting minikube"
minikube start --vm-driver=xhyve
sleep 10

echo "setting the kubectl context to your minikube instance"
kubectl config use-context minikube

echo "setting the docker image context to your minikube instance"
eval $(minikube docker-env)

echo "here is your minikube:"
kubectl get pods --all-namespaces -a -o wide

echo "creating the redis cluster"
kubectl create -f redis-cluster.yml


echo "getting redis-trib..."
docker pull zvelo/redis-trib

echo "here is your new redis cluster:"
kubectl exec -it redis-cluster-0 redis-cli cluster nodes

echo "waiting for cluster to be ready..."
sleep 2m

echo "building v1 of minikube-redis image"
docker build -t mkredis:v1 .
sleep 10

# create the deployment
echo "creating a minikube-redis deployment"
kubectl run mkredis --image=mkredis:v1 --port=4101
sleep 10

# create the service
echo "creating a minikube-redis service"
kubectl expose deployment mkredis --type=LoadBalancer
sleep 15

# once the service is up and running, you can access it externally like this:
minikube service mkredis

ok
