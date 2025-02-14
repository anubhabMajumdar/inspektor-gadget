#!/bin/sh

# Copyright 2019-2023 The Inspektor Gadget authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

if [ ! -d /host/bin ] ; then
  echo "$0 must be executed in a pod with access to the host via /host" >&2
  exit 1
fi

# In some distributions /host/etc/os-release is a symlink that can't be read from the container. For
# instance, NixOS -> https://github.com/NixOS/nixpkgs/issues/28833.
if [ ! -r /host/etc/os-release ] ; then
  echo "os-release information not available. Some features could not work" >&2
else
  . /host/etc/os-release
fi

echo -n "OS detected: "
echo $PRETTY_NAME

KERNEL=$(uname -r)
echo -n "Kernel detected: "
echo $KERNEL

# The gadget-core image does not provide bcc.
if [ "$GADGET_IMAGE_FLAVOUR" = "bcc" ] ; then
	echo -n "bcc detected: "
	dpkg-query --show libbcc | awk '{print $2}' || true
fi

echo -n "Gadget image: "
echo $GADGET_IMAGE

echo "Gadget image flavour: ${GADGET_IMAGE_FLAVOUR}"

echo "Deployment options:"
env | grep '^INSPEKTOR_GADGET_OPTION_.*='

echo -n "Inspektor Gadget version: "
echo $INSPEKTOR_GADGET_VERSION

CRIO=0
if grep -q '^1:name=systemd:.*/crio-[0-9a-f]*\.scope$' /proc/self/cgroup > /dev/null ; then
    echo "CRI-O detected."
    CRIO=1
fi

## Hooks Begins ##

# Choose what hook mode to use based on the configuration detected
HOOK_MODE="$INSPEKTOR_GADGET_OPTION_HOOK_MODE"

if [ "$HOOK_MODE" = "auto" ] || [ -z "$HOOK_MODE" ] ; then
  if [ "$CRIO" = 1 ] ; then
    echo "Hook mode CRI-O detected"
    HOOK_MODE="crio"
  fi
fi

if [ "$HOOK_MODE" = "crio" ] ; then
  echo "Installing hooks scripts on host..."

  mkdir -p /host/opt/hooks/oci/
  for i in ocihookgadget prestart.sh poststop.sh ; do
    echo "Installing $i..."
    cp /opt/hooks/oci/$i /host/opt/hooks/oci/
  done

  for HOOK_PATH in "/host/etc/containers/oci/hooks.d" \
                   "/host/usr/share/containers/oci/hooks.d/"
  do
    echo "Installing OCI hooks configuration in $HOOK_PATH"
    mkdir -p $HOOK_PATH
    cp /opt/hooks/crio/gadget-prestart.json $HOOK_PATH 2>/dev/null || true
    cp /opt/hooks/crio/gadget-poststop.json $HOOK_PATH 2>/dev/null || true

    if ! ls $HOOK_PATH/gadget-{prestart,poststop}.json > /dev/null 2>&1; then
      echo "Couldn't install OCI hooks configuration" >&2
    else
      echo "Hooks installation done"
    fi
  done
fi

if [ "$HOOK_MODE" = "nri" ] ; then
  echo "Installing NRI hooks"

  # first install the binary
  mkdir -p /host/opt/nri/bin/
  cp /opt/hooks/nri/nrigadget /host/opt/nri/bin/

  # then install the configuration
  # if the configuration already exists append a new plugin
  if [ -f "/host/etc/nri/conf.json" ] ; then
    jq '.plugins += [{"type": "nrigadget"}]' /host/etc/nri/conf.json > /tmp/conf.json
    mv /tmp/conf.json /host/etc/nri/conf.json
  else
    mkdir -p /host/etc/nri/
    cp /opt/hooks/nri/conf.json /host/etc/nri/
  fi
fi

if [ "$HOOK_MODE" = "crio" ] || [ "$HOOK_MODE" = "nri" ] ; then
  # For crio and nri, the gadgettracermanager process can passively wait for
  # the gRPC calls without monitoring containers itself.
  GADGET_TRACER_MANAGER_HOOK_MODE=none
elif [ "$HOOK_MODE" = "fanotify" ] || [ "$HOOK_MODE" = "fanotify+ebpf" ] || [ "$HOOK_MODE" = "podinformer" ] ; then
  # fanotify, fanotify+ebpf and podinformer are implemented in the
  # gadgettracermanager process.
  GADGET_TRACER_MANAGER_HOOK_MODE="$HOOK_MODE"
else
  # Use fanotify if possible, or fall back on podinformer
  GADGET_TRACER_MANAGER_HOOK_MODE="auto"
fi

echo "Gadget Tracer Manager hook mode: ${GADGET_TRACER_MANAGER_HOOK_MODE}"

## Hooks Ends ##

echo "Starting the Gadget Tracer Manager..."
# change directory before running gadgettracermanager
cd /
rm -f /run/gadgettracermanager.socket
rm -f /run/gadgetservice.socket
exec /bin/gadgettracermanager -serve -hook-mode=$GADGET_TRACER_MANAGER_HOOK_MODE \
    -controller -fallback-podinformer=$INSPEKTOR_GADGET_OPTION_FALLBACK_POD_INFORMER
