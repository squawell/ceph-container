#!/bin/bash
set -e


#############
# VARIABLES #
#############
CEPH_DEMO_UID=demo
CEPH_DEMO_ACCESS_KEY=
CEPH_DEMO_SECRET_KEY=
RGW_CIVETWEB_PORT=8000


#############
# FUNCTIONS #
#############
function show_usage {
	cat <<EOM
Usage: ./$(basename "$0") start|stop|status|purge|help

      start: stars Ceph container.
      stop: stops Ceph container.
      status: shows useful information about Ceph container.
      purge: DANGEROUS, removes the Ceph container and all its data.
      help: shows this help.


Interact with S3:
      Make bucket
        ./$(basename "$0") mb s3://BUCKET
      Remove bucket
        ./$(basename "$0") rb s3://BUCKET
      List objects or buckets
        ./$(basename "$0") ls [s3://BUCKET[/PREFIX]]
      List all object in all buckets
        ./$(basename "$0") la
      Put file into bucket
        ./$(basename "$0") put FILE [FILE...] s3://BUCKET[/PREFIX]
      Get file from bucket
        ./$(basename "$0") get s3://BUCKET/OBJECT LOCAL_FILE
      Delete file from bucket
        ./$(basename "$0") del s3://BUCKET/OBJECT
      Synchronize a directory tree to S3 (checks files freshness using size and md5 checksum, unless overridden by options, see below)
        ./$(basename "$0") sync LOCAL_DIR s3://BUCKET[/PREFIX] or s3://BUCKET[/PREFIX] LOCAL_DIR
      Disk usage by buckets
        ./$(basename "$0") du [s3://BUCKET[/PREFIX]]
      Get various information about Buckets or Files
        ./$(basename "$0") info s3://BUCKET[/OBJECT]
      Copy object
        ./$(basename "$0") cp s3://BUCKET1/OBJECT1 s3://BUCKET2[/OBJECT2]
      Modify object metadata
        ./$(basename "$0") modify s3://BUCKET1/OBJECT
      Move object
        ./$(basename "$0") mv s3://BUCKET1/OBJECT1 s3://BUCKET2[/OBJECT2]
      Modify Access control list for Bucket or Files
        ./$(basename "$0") setacl s3://BUCKET[/OBJECT]
      Modify Bucket Policy
        ./$(basename "$0") setpolicy FILE s3://BUCKET
      Delete Bucket Policy
        ./$(basename "$0") delpolicy s3://BUCKET
      Modify Bucket CORS
        ./$(basename "$0") setcors FILE s3://BUCKET
      Delete Bucket CORS
        ./$(basename "$0") delcors s3://BUCKET
      Show multipart uploads
        ./$(basename "$0") multipart s3://BUCKET [Id]
      Abort a multipart upload
        ./$(basename "$0") abortmp s3://BUCKET/OBJECT Id
      List parts of a multipart upload
        ./$(basename "$0") listmp s3://BUCKET/OBJECT Id
EOM
}

function test_args {
  if [ $# -ne 1 ]; then
    show_usage
    exit 1
  fi
}

function docker_exist {
  if ! command -v docker &> /dev/null; then
    echo "Docker CLI is not available."
    echo "Please follow instructions to install Docker: https://docs.docker.com/engine/installation/"
    exit 1
  fi
}

function find_local_ip {
  RGW_IP=$(netstat -pltn | awk -v pattern=$RGW_CIVETWEB_PORT '$0 ~ pattern {sub (":[0-9]{4}", "", $4); print $4}')
}

function create_ceph_demo_volumes {
  for vol in varlibceph etcceph; do
    if ! docker volume ls | grep -sq "$vol"; then
      docker volume create --name "$vol"
    fi
  done
}

function start_ceph_demo {
  if ! docker ps | grep -sq ceph-demo; then
    docker run -d \
    --name ceph-demo \
    -v etcceph:/etc/ceph \
    -v varlibceph:/var/lib/ceph \
    -e CEPH_DEMO_UID=$CEPH_DEMO_UID \
    -e NETWORK_AUTO_DETECT=4 \
    -e RGW_CIVETWEB_PORT=8000 \
    -p 8000:8000 \
    -p 6789:6789 \
    -p 7000:7000 \
    ceph/daemon demo &> /dev/null
    echo -n "Starting Ceph container..."
    until docker logs ceph-demo | grep -sq SUCCESS; do
      sleep 1 && echo -n "."
    done
    echo_info
  else
    echo "Ceph container is already running!"
    echo_info
  fi
}

function stop_demo_demo {
  docker rm -f ceph-demo &> /dev/null
}

function remove_ceph_demo_volumes {
  docker volume rm -f etcceph varlibceph &> /dev/null
}

function s3cmd_wrap {
  docker exec ceph-demo s3cmd "$@"
}

function echo_info {
  if docker ps | grep ceph-demo; then
    find_local_ip
    echo "Ceph Rados Gateway is available at: http://$RGW_IP:$RGW_CIVETWEB_PORT"
    echo "Acess key is: $CEPH_DEMO_ACCESS_KEY"
    echo "Secret key is: $CEPH_DEMO_SECRET_KEY"
    echo ""
    echo "Ceph Manager dashboard: http://$RGW_IP:7000"
    echo ""
  else
    echo "Ceph container is not running, start it with:"
    echo "./$(basename "$0") start"
  fi
}


########
# MAIN #
########
test_args  "$@"
docker_exist

case "$1" in
  start)
    create_ceph_demo_volumes
    start_ceph_demo
    echo_info
    ;;
  status)
    echo_info
    ;;
  stop)
    echo "Stopping Ceph container..."
    stop_ceph_demo
    ;;
  purge)
    echo "Purging Ceph container..."
    stop_ceph_demo
    remove_ceph_demo_volumes
    ;;
  help)
    show_usage
    ;;
esac
