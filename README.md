# docker-ubuntu
[![License][license-img]][license-href]
[![pipeline][pipeline-img]][pipeline-href]
[![docker][docker-img]][docker-href]

## Overview

Ubuntu is  a Debian-based  free operating  system (OS)  for your  computer.  An
operating system  is the  set of  basic programs and  utilities that  make your
computer run.

[ubuntu.com](https://www.ubuntu.com/)

## Description

Use this script to build your own base system.

We've included the last ca-certificates files  in the repository to ensure that
all of our images are accurates.

## Tags

Supported tags.

- 10.04, lucid
- 12.04, precise
- 14.04, trusty
- 16.04, xenial, latest

## Requirements

On Debian you need sudo permissions and the following packages:

```bash
# if you build on wheezy please use backports version of debootstrap
sudo apt-get install debootstrap ubuntu-archive-keyring
```

On Devuan you need sudo permissions and the following packages:

```bash
sudo apt-get -qq -y install debootstrap ubuntu-archive-keyring
```

On Ubuntu you need sudo permissions and the following packages:

```bash
sudo apt-get install debootstrap
```

You also need to be in the docker group to use Docker.

```bash
sudo usermod -a -G docker ${USER}
```

Finally you need to login on Docker Hub.

```bash
docker login
```

## Usage

You first need to choose which dist between precise (12.04), trusty (14.04) and
xenial (16.04)  you want  (xenial will  be the  'latest' tag)  and you  need to
choose you user (or organization) name on Docker Hub.

Show help.

```bash
./build.sh -h
```

Build your own Ubuntu image (eg. trusty).

```bash
./build.sh -d trusty -u vpgrp
```

Build your own Ubuntu image (eg. xenial) and push it on the Docker Hub.

```bash
./build.sh -d xenial -u vpgrp -p
```

## Limitations

Only work on Debian, Devuan and Ubuntu.

## Development

Please read carefully [CONTRIBUTING.md][contribute-href]  before making a merge
request.

## Miscellaneous

```
    ╚⊙ ⊙╝
  ╚═(███)═╝
 ╚═(███)═╝
╚═(███)═╝
 ╚═(███)═╝
  ╚═(███)═╝
   ╚═(███)═╝
```

[license-img]: https://img.shields.io/badge/license-Apache-blue.svg
[license-href]: /LICENSE
[pipeline-img]: https://git.vpgrp.io/docker/docker-ubuntu/badges/master/pipeline.svg
[pipeline-href]: https://git.vpgrp.io/docker/docker-ubuntu/commits/master
[docker-img]: https://img.shields.io/docker/pulls/vpgrp/ubuntu.svg
[docker-href]: https://registry.hub.docker.com/u/vpgrp/ubuntu
[contribute-href]: /CONTRIBUTING.md
