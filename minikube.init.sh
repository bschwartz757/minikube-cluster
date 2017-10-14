#!/usr/bin/env bash

###########################################
# This is the project's developer toolkit #
# @author Blake Schwartz                  #
###########################################

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

# make sure user has the needed resources
sysctl -a | grep machdep.cpu.features | grep VMX

reqs="kubectl docker minikube virtualbox"
# grep for
for req in $reqs
do
  echo "ensuring you have $req installed on your machine"
  brew list $req > /dev/null 2>&1 | true
  if [[ ${PIPESTATUS[0]} != 0]]; then
    if [[ $req == "kubectl" ]]; then
      echo "brew install $req"
      brew install $req; else
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

echo "starting minikube"
minikube start
sleep 30

echo "setting the kubectl context to your minikube instance"
kubectl config use-context minikube

echo "setting the docker image context to your minikube instance"
eval $(minikube docker-env)

echo "Now the fun part... creating the redis cluster"
k create -f redis-cluster.yml
echo "waiting for cluster to be ready..."

sleep 1m

echo "getting redis-trib..."
docker pull zvelo/redis-trib

echo "here is your new redis cluster:"
k exec -it redis-cluster-0 redis-cli cluster nodes

echo "building v1 of minikube-redis image"
docker build -t mkredis:v1 .
sleep 30

# create the deployment
echo "creating a minikube-redis deployment"
kubectl run mkredis --image=mkredis:v1 --port=4101
sleep 30


# create the service
echo "creating a minikube-redis service"
kubectl expose deployment mkredis --type=LoadBalancer
sleep 30

# once the service is up and running, you can run it on localhost like this:
# minikube service mkredis

ok
