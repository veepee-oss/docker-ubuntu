#!/usr/bin/env bash

set -e

PATH='/usr/sbin:/usr/bin:/sbin:/bin'

arch='amd64'
version='3.0'

function usage()
{
    cat <<EOF

NAME:
   build.sh - Docker images' builder of Ubuntu.

USAGE:
   build.sh -d <dist>

OPTIONS:
   -h, --help           Show help

   -d, --dist           Choose Ubuntu distribution
                        eg: lucid, precise, trusty, xenial

   -m, --mirror         Choose your preferred mirror
                        default: archive.ubuntu.com

   -t, --timezone       Choose your preferred timezone
                        default: Europe/Amsterdam

   -u, --user           Docker Hub username or organisation
                        default: $USER

   -p, --push           Docker Hub push
                        default: no

   -l, --latest         Force the "latest"
                        default: xenial

   -v, --verbose        Verbose mode

   -V, --version        Show version

VERSION:
   docker-debian version: ${version}

EOF
}

function docker_debootstrap()
{
    # variables
    image="/tmp/image-${distname}-${arch}"
    include="${include} apt-transport-https,apt-utils,ca-certificates,curl,git-core,locales"
    exclude='debconf-i18n,dmsetup,git-man,info,initramfs-tools,man-db,manpages'
    components='main multiverse restricted universe'

    echo "-- bootstrap ${distname}" 1>&3

    if [ "$(id -u)" -ne 0 ]
    then
        sudo='sudo'
    fi

    # clean old image
    if [ -d "/tmp/image-${distname}-${arch}" ]
    then
        ${sudo} rm -fr "${image}"
    fi

    # create minimal debootstrap image
    echo " * debootstrap" 1>&3
    if [ ! -f "/usr/share/debootstrap/scripts/${distname}" ] || [ ! -h "/usr/share/debootstrap/scripts/${distname}" ]
    then
	echo "/!\ File /usr/share/debootstrap/scripts/${distname} is missing." 1>&3
        echo "1.) did you install backports version of debootstrap ?" 1>&3
	echo "2.) run sudo ln -s gutsy /usr/share/debootstrap/scripts/${distname}" 1>&3
        exit 1
    else
        ${sudo} debootstrap \
                --arch="${arch}" \
                --include="${include}" \
                --exclude="${exclude}" \
                --variant=minbase \
                "${distname}" \
                "${image}" \
                "http://${mirror}/ubuntu"
        if [ ${?} -ne 0 ]
        then
	    echo "/!\ There is an issue with debootstrap, please run again with -v (verbose)." 1>&3
            exit 1
        fi
    fi

    # create /etc/default/locale
    echo ' * /etc/default/locale' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/default/locale"
LANG=en_US.UTF-8
LANGUAGE=en_US.UTF-8
LC_COLLATE=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

    # create /etc/timezone
    echo ' * /etc/timezone' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/timezone"
${timezone}
EOF

    # create /etc/resolv.conf
    echo ' * /etc/resolv.conf' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/resolv.conf"
nameserver 8.8.4.4
nameserver 8.8.8.8
EOF

    # create /etc/apt/sources.list
    echo ' * /etc/apt/sources.list' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list"
deb http://${mirror}/ubuntu ${distname} ${components}
deb http://${mirror}/ubuntu ${distname}-updates ${components}
EOF

    # create /etc/apt/sources.list.d/backports.list
    echo ' * /etc/apt/sources.list.d/backports.list' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list.d/backports.list"
deb http://${mirror}/ubuntu ${distname}-backports ${components}
EOF

    # create /etc/apt/sources.list.d/security.list
    echo ' * /etc/apt/sources.list.d/security.list' 1>&3
    if [ "${distname}" != 'lucid' ]
    then
        cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list.d/security.list"
deb http://security.ubuntu.com/ubuntu ${distname}-security ${components}
EOF
    else
        cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list.d/security.list"
deb http://old-releases.ubuntu.com/ubuntu ${distname}-security ${components}
EOF
    fi

    if [ "${distname}" != 'lucid' ]
    then
       # create /etc/dpkg/dpkg.cfg.d/disable-doc
       # thanks to http://askubuntu.com/questions/129566/remove-documentation-to-save-hard-drive-space
       echo ' * /etc/dpkg/dpkg.cfg.d/disable-doc' 1>&3
       cat <<EOF | ${sudo} tee "${image}/etc/dpkg/dpkg.cfg.d/disable-doc"
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF
    fi

    # create /etc/apt/apt.conf.d/force-ipv4
    # thanks to https://github.com/cw-ansible/cw.apt/
    echo ' * /etc/apt/apt.conf.d/force-ipv4' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/force-ipv4"
Acquire::ForceIPv4 "true";
EOF

    # create /etc/apt/apt.conf.d/disable-auto-install
    # thanks to https://github.com/cw-ansible/cw.apt/
    echo ' * /etc/apt/apt.conf.d/disable-auto-install' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/disable-auto-install"
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

    # create /etc/apt/apt.conf.d/disable-cache
    # thanks to https://github.com/docker/docker/blob/master/contrib/mkimage-debootstrap.sh
    echo ' * /etc/apt/apt.conf.d/disable-cache' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/disable-cache"
Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";
EOF

    # create /etc/apt/apt.conf.d/force-conf
    # thanks to https://raphaelhertzog.com/2010/09/21/debian-conffile-configuration-file-managed-by-dpkg/
    echo ' * /etc/apt/apt.conf.d/force-conf' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/force-conf"
Dpkg::Options {
   "--force-confnew";
   "--force-confmiss";
}
EOF

    # create /etc/apt/apt.conf.d/disable-languages
    # thanks to https://github.com/docker/docker/blob/master/contrib/mkimage-debootstrap.sh
    echo ' * /etc/apt/apt.conf.d/disable-languages' 1>&3
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/disable-languages"
Acquire::Languages "none";
EOF

    # create /usr/bin/apt-clean
    echo ' * /usr/bin/apt-clean' 1>&3
    cat <<EOF | ${sudo} tee "${image}/usr/bin/apt-clean"
#!/bin/bash

# Please read https://wiki.ubuntu.com/ReducingDiskFootprint

find /usr/share/doc     -type f ! -name copyright -delete
find /usr/share/i18n    -type f -delete
find /usr/share/locale  -type f -delete
find /usr/share/man     -type f -delete
find /var/cache/apt     -type f -delete
find /var/lib/apt/lists -type f -delete
apt-get autoclean -qq -y
apt-get autoremove -qq -y
apt-get clean -qq -y
# EOF
EOF
    ${sudo} chmod 755 "${image}/usr/bin/apt-clean"

    # create /usr/sbin/policy-rc.d
    # thanks to https://github.com/docker/docker/blob/master/contrib/mkimage-debootstrap.sh
    echo ' * /usr/sbin/policy-rc.d' 1>&3
    cat <<EOF | ${sudo} tee "${image}/usr/sbin/policy-rc.d"
#!/bin/bash

exit 101
# EOF
EOF
    ${sudo} chmod 755 "${image}/usr/sbin/policy-rc.d"

    if [ "${distname}" != 'lucid' ]
    then
        # update initctl
	# thanks to https://github.com/docker/docker/blob/master/contrib/mkimage-debootstrap.sh
        echo ' * /sbin/initctl' 1>&3
        ${sudo} chroot "${image}" bash -c \
                "dpkg-divert --local --rename --add /sbin/initctl \
                 ln -sf /bin/true sbin/initctl" 2>&1
    fi

    # mount
    ${sudo} mount --bind /dev     "${image}/dev"
    ${sudo} mount --bind /dev/pts "${image}/dev/pts"
    ${sudo} mount --bind /proc    "${image}/proc"
    ${sudo} mount --bind /sys     "${image}/sys"

    # update root certificates
    ${sudo} mkdir -p "${image}/usr/local/share/"
    ${sudo} cp -r ca-certificates "${image}/usr/local/share/"

    # upgrade (without output...)
    echo ' * apt-get upgrade' 1>&3
    ${sudo} chroot "${image}" bash -c \
            "export DEBIAN_FRONTEND=noninteractive && \
             export LC_ALL=en_US.UTF-8 && \
             update-ca-certificates -f && \
             apt-get update -qq && \
             apt-get upgrade -qq -y && \
             apt-get dist-upgrade -qq -y && \
             apt-get autoclean -qq -y && \
             apt-get autoremove -qq -y && \
             apt-get clean -qq -y" 2>&1

    # unmount
    ${sudo} umount "${image}/dev/pts"
    ${sudo} umount "${image}/dev"
    ${sudo} umount "${image}/proc"
    ${sudo} umount "${image}/sys"

    # clean
    ${sudo} find   "${image}/usr/share/doc"     -type f ! -name copyright -delete
    ${sudo} find   "${image}/usr/share/i18n"    -type f -delete
    ${sudo} find   "${image}/usr/share/locale"  -type f -delete
    ${sudo} find   "${image}/usr/share/man"     -type f -delete
    ${sudo} find   "${image}/var/cache/apt"     -type f -delete
    ${sudo} find   "${image}/var/lib/apt/lists" -type f -delete

    # create archive
    if [ -f "${image}.tar" ]
    then
        ${sudo} rm "${image}.tar"
    fi
    ${sudo} tar --numeric-owner -cf "${image}.tar" -C "${image}" .
}

# create image from bootstrap archive
function docker_import()
{
    echo "-- docker import ubuntu:${distname} (from ${image}.tgz)" 1>&3
    docker import "${image}.tar" "${user}/ubuntu:${distname}"
    docker run "${user}/ubuntu:${distname}" echo "Successfully build ${user}/ubuntu:${distname}" 1>&3
    docker tag "${user}/ubuntu:${distname}" "${user}/ubuntu:${distid}"
    docker run "${user}/ubuntu:${distid}" echo "Successfully build ${user}/ubuntu:${distid}" 1>&3
}

# push image to docker hub
function docker_push()
{
    echo "-- docker push ubuntu:${distname}" 1>&3
    docker push "${user}/ubuntu:${distname}"
    echo "-- docker push ubuntu:${distid}" 1>&3
    docker push "${user}/ubuntu:${distid}"
}

while getopts 'hd:m:t:u:plvV' OPTIONS
do
    case ${OPTIONS} in
        h)
            # -h / --help
            usage
            exit 0
            ;;
        d)
            # -d / --dist
            dist=${OPTARG}
            ;;
        m)
            # -m / --mirror
            mirror=${OPTARG}
            ;;
        t)
            # -t / --timezone
            timezone=${OPTARG}
            ;;
        u)
            # -u / --user
            user=${OPTARG}
            ;;
        p)
            # -p / --push
            push='true'
            ;;
        l)
            # -l / --latest
            latest=${OPTARG}
            ;;
        v)
            # -v / --verbose
            verbose='true'
            ;;
        V)
            # -V / --version
            echo "${version}"
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [ ! -x "$(command -v sudo)" ]
then
    echo "Please install sudo (see README.md)"
    exit 1
fi

if [ ! -x "$(command -v debootstrap)" ]
then
    echo "Please install debootstrap (see README.md)"
    exit 1
fi

# -d / --dist
if [ -n "${dist}" ]
then
    case ${dist} in
        lucid|10.04|10.04-lts)
            distname='lucid'
            distid='10.04'
            mirror='old-releases.ubuntu.com'
            include='gpgv'
            ;;
        precise|12.04|12.04-lts)
            distname='precise'
            distid='12.04'
            ;;
        trusty|14.04|14.04-lts)
            distname='trusty'
            distid='14.04'
            ;;
        xenial|16.04|16.04-lts)
            distname='xenial'
            distid='16.04'
            ;;
        *)
            usage
            exit 1
            ;;
    esac
else
    usage
    exit 1
fi

# -m / --mirror
if [ -z "${mirror}" ]
then
    mirror='archive.ubuntu.com'
fi

# -t / --timezone
if [ -z "${timezone}" ]
then
    timezone='Europe/Amsterdam'
fi

# -u / --user
if [ -z "${user}" ]
then
    user=${USER}
fi

# -l / --latest
if [ -z "${latest}" ]
then
    latest='xenial'
fi

# -v / --verbose
if [ -z "${verbose}" ]
then
    exec 3>&1
    exec 1>/dev/null
    exec 2>/dev/null
else
    exec 3>&1
fi

docker_debootstrap
docker_import

if [ -n "${push}" ]
then
    docker_push
fi
# EOF
