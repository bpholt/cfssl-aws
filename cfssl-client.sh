#/bin/sh

function usage {
  echo "Usage: cfssl-client.sh [options…] <service-name>"
  echo
  echo "    <service-name> is the name of the service as known to Consul,"
  echo "    and is a required argument."
  echo
  echo "Options:"
  echo "    -h    Show this help"
  echo "    -v    Verbose mode (echo commands issued by this script)"
  echo "    -c    Set the Consul host and port. Default value is localhost:8500"
  echo "    -f    Output prefix. Default value is ./local. Running the script"
  echo "          will generate files <output-prefix>.pem, <output-prefix>-key.pem,"
  echo "          and <output-prefix>.csr"
  echo
  echo "Return Codes:"
  echo "    0     Success!"
  echo "    1     Certificate Signing Request could not be generated"
  echo "    2     Certificate Signing Request could not be signed"
  echo "    3     Service name was not provided"
  echo "    4     One of the required tools could not be found on the path"
  echo
}

function check_deps {
  if command -v curl > /dev/null 2>&1 ; then
    local has_curl=true
  else
    local has_curl=false
    echo "Error: curl must be available on the path"
  fi

  if command -v jq > /dev/null 2>&1 ; then
    local has_jq=true
  else
    local has_jq=false
    echo "Error: jq must be available on the path"
  fi

  if [ "${has_curl}" != "true" ] || [ "${has_jq}" != "true" ]; then
    exit 4
  fi
}
check_deps

consul_host=localhost:8500
output_prefix=./local

while getopts "hvc:f:" opt; do
    case "$opt" in
    h)
        usage
        exit 0
        ;;
    v)  verbose=1
        ;;
    c)  consul_host=${OPTARG}
        ;;
    f)  output_prefix=${OPTARG}
        ;;
    esac
done

if [ "${verbose}" = "1" ]; then
  set -x
fi

shift $((OPTIND-1))

service_name=$1
if [ "${service_name}" = "" ]; then
  echo "Error: <service-name> argument is required."
  exit 3
fi

req_csr_filename=$(mktemp)
req_cert_filename=$(mktemp)
csr_filename=$(mktemp)
cert_filename=$(mktemp)

function cleanup {
  rm ${csr_filename} ${cert_filename} ${req_csr_filename} ${req_cert_filename}
  set +x
}
trap cleanup EXIT

function curls {
  curl --silent $*
}

service_discovery=$(curls http://${consul_host}/v1/catalog/service/cfssl-s3?healthy=true)
hostname=$(echo $service_discovery | jq -r .[0].Node)
port=$(echo $service_discovery | jq -r .[0].ServicePort)
cfssl_service="${hostname}:${port}"
local_hostname=$(curls http://169.254.169.254/latest/meta-data/local-hostname)
local_ipv4=$(curls http://169.254.169.254/latest/meta-data/local-ipv4)

cat << __EOF__ > ${req_csr_filename}
{
    "hostname": "${local_hostname}",
    "request": {
        "hosts": [
            "${local_hostname}",
            "${hostname}",
            "${local_ipv4}",
            "${service_name}",
            "${service_name}.service.consul"
        ],
        "key": {
            "algo": "rsa",
            "size": 2048
        },
        "names": [
            {
                "C": "US",
                "L": "Des Moines",
                "O": "Dwolla",
                "ST": "Iowa",
                "CN": "${hostname}"
            }
        ]
    },
    "profile": "www"
}
__EOF__
curls -XPOST -H "Content-Type: application/json" -d @${req_csr_filename} http://${cfssl_service}/api/v1/cfssl/newcert > ${csr_filename} 

if [ $? -ne 0 ] || jq --exit-status ".success != true" ${csr_filename} > /dev/null; then
  exit 1
fi

json_csr=$(jq -a .result.certificate_request ${csr_filename})

cat << __EOF__ > ${req_cert_filename} 
{
    "hosts": [
        "${local_hostname}",
        "${hostname}",
        "${local_ipv4}",
        "${service_name}",
        "${service_name}.service.consul"
    ],
    "certificate_request": ${json_csr},
    "profile": "www",
    "subject": {
        "hosts": [
            "${local_hostname}",
            "${hostname}",
            "${local_ipv4}",
            "${service_name}",
            "${service_name}.service.consul"
        ],                          
        "names": [
            {
                "C": "US",
                "L": "Des Moines",
                "O": "Dwolla",
                "ST": "Iowa"
            }
        ],
        "CN": "${hostname}"
    }
}
__EOF__
curls -XPOST -H "Content-Type: application/json" -d @${req_cert_filename} ${cfssl_service}/api/v1/cfssl/sign > ${cert_filename}

if [ $? -ne 0 ] || jq --exit-status ".success != true" ${cert_filename} > /dev/null; then
  exit 2
fi

jq -r .result.private_key ${csr_filename} > ${output_prefix}-key.pem
jq -r .result.certificate_request ${csr_filename} > ${output_prefix}.csr
jq -r .result.certificate ${cert_filename} > ${output_prefix}.pem

