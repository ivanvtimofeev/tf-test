#!/bin/bash -e

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"
source "$my_dir/../common/common.sh"
source "$my_dir/../common/functions.sh"

# 
TF_TEST_NAME="contrail-test"
if [ -z "$TF_TEST_IMAGE" ] ; then
    TF_TEST_IMAGE="${TF_TEST_NAME}-test:${OPENSTACK_VERSION}-${CONTRAIL_CONTAINER_TAG}"
    [ -n "$CONTAINER_REGISTRY" ] && TF_TEST_IMAGE="${CONTAINER_REGISTRY}/${TF_TEST_IMAGE}"
fi


TF_TEST_PROJECT="Juniper/$TF_TEST_NAME.git"
TF_TEST_TARGET=${TF_TEST_TARGET:-'ci_k8s_sanity'}
TF_TEST_INPUT_TEMPLATE=${TF_TEST_INPUT_TEMPLATE:-"$my_dir/contrail_test_input.$ORCHESTRATOR.yaml.j2"}

export DOMAINSUFFIX=${DOMAINSUFFIX:-$(hostname -f | cut -s -d '.' -f 2-)}

pushd $WORKSPACE

echo 
echo "[$TF_TEST_NAME]"

# prerequisites
# (expected pip is already installed)
# conflict with ansible-deployer which setups docker (might be deps for docker-compose)
#pip install docker-py


# prepare ssh keys for local connect
set_ssh_keys

# get test project
echo get $TF_TEST_NAME project
[ -d ./$TF_TEST_NAME ] &&  rm -rf ./$TF_TEST_NAME
git clone --depth 1 --single-branch https://github.com/$TF_TEST_PROJECT $TF_TEST_NAME

# run tests:

echo "prepare input parameters from template $TF_TEST_INPUT_TEMPLATE"
"$my_dir/../common/jinja2_render.py" < $TF_TEST_INPUT_TEMPLATE > ./contrail_test_input.yaml

echo "TF test input:"
cat ./contrail_test_input.yaml

echo "run tests"

time EXTRA_RUN_TEST_ARGS="-t" sudo -E ${TF_TEST_NAME}/testrunner.sh run \
    -P ./contrail_test_input.yaml \
    -k ~/.ssh/id_rsa \
    -f $TF_TEST_TARGET \
    $TF_TEST_IMAGE

popd

# check for failures
[ x\"$(grep testsuite /root/contrail-test-runs/*/reports/TESTS-TestSuites.xml  | grep -o  'failures=\\S\\+' | uniq)\" = x'failures=\"0\"' ]
exit $?