#! /usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_DIR="$( cd ${SCRIPT_DIR}/../ &> /dev/null && pwd )"

die() { echo "$*" 1>&2 ; exit 1; }

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kustomize"

if [ -z "$1" ] || [ -z "$2" ]; then
    die "CHART_NAME: $1 or CHART_VERSION: $2 is missing"
fi

CHART_NAME=${1}
CHART_VERSION=${2}

# Setup Vars
BUILD_DIR="${REPO_DIR}/tmp_release/build"
MANIFESTS_DIR="${REPO_DIR}/tmp_release/manifests"

TMP_IMAGES="${BUILD_DIR}/tmp_images.yaml"
IMAGE_TPL="${BUILD_DIR}/images.tpl"
IMAGE_YAML="${BUILD_DIR}/images.yaml"
KOTS_APP="${BUILD_DIR}/kots_app.yaml"
KOTS_HELM="${MANIFESTS_DIR}/kots_helm.yaml"
VALUES_FILE="${REPO_DIR}/charts/${CHART_NAME}/values.yaml"

# Create the necessary directories & build files
mkdir -p "${BUILD_DIR}"
mkdir -p "${MANIFESTS_DIR}"
cp "${REPO_DIR}/replicated-releases/templates/"* "${BUILD_DIR}/"
cp "${REPO_DIR}/replicated-releases/${CHART_NAME}/"* "${BUILD_DIR}/"
touch "${TMP_IMAGES}"
ls -la "${BUILD_DIR}"


# First, extract all unique values for `.image.name` that are not null
yq '.*.*.components?.*.deployment?.containers?.*.image?.name? | select(. != null)' "$VALUES_FILE" | sort -u | while IFS= read -r value; do
    # Find all paths for the specific value
    paths=$(yq "... | select(. == \"${value}\") | path | join(\".\")" "$VALUES_FILE")

    image_name=$(basename "${value}")
    repo_path=$(dirname "${value}")
    sub_chart=${image_name}

    if [ $(yq ".spec.values.${sub_chart}.enabled" ${BUILD_DIR}/enabled_apps.yaml) == "true" ]; then
        repl_value="repl{{ HasLocalRegistry | ternary LocalRegistryHost proxy.replicated.com }}/{{repl HasLocalRegistry | ternary LocalRegistryNamespace \`proxy/${CHART_NAME}/${repo_path}\` }}/${image_name}"
        # Loop through each path for the current value
        while IFS= read -r path; do
            # Use yq to construct the YAML structure for this path and set the value
            yq -i "(.${path}) = \"${repl_value}\"" -o=yaml "${TMP_IMAGES}"
        done <<< "${paths}"
    fi
done

# We also have to do the same for the older helm charts
yq '.*.*.image?.name? | select(. != null)' "$VALUES_FILE" | sort -u | while IFS= read -r value; do
    # Find all paths for the specific value
    paths=$(yq "... | select(. == \"${value}\") | path | join(\".\")" "$VALUES_FILE")

    image_name=$(basename "${value}")
    repo_path=$(dirname "${value}")
    sub_chart=${image_name}

    if [ $(yq ".spec.values.${sub_chart}.enabled" ${BUILD_DIR}/enabled_apps.yaml) == "true" ]; then
        repl_value="repl{{ HasLocalRegistry | ternary LocalRegistryHost proxy.replicated.com }}/{{repl HasLocalRegistry | ternary LocalRegistryNamespace \`proxy/${CHART_NAME}/${repo_path}\` }}/${image_name}"
        # Loop through each path for the current value
        while IFS= read -r path; do
            # Use yq to construct the YAML structure for this path and set the value
            yq -i "(.${path}) = \"${repl_value}\"" -o=yaml "${TMP_IMAGES}"
        done <<< "${paths}"
    fi
done

# Cuz quoting is hard and repl only likes " and not ' or none
if [ $(uname) == "Darwin" ]; then
    sed -i '' 's/proxy\.replicated\.com/"proxy.replicated.com"/g' "${TMP_IMAGES}"
else
    sed -i 's/proxy\.replicated\.com/"proxy.replicated.com"/g' "${TMP_IMAGES}"
fi

# Merge only the content of $TMP_IMAGES into the spec.values key in $IMAGE_TPL
yq eval-all '.spec.values *= load("'"${TMP_IMAGES}"'")' "${IMAGE_TPL}" > "${IMAGE_YAML}"

# Ensure the `builder` key has the correct set of apps enabled
yq -i '.spec.builder = .spec.values' ${BUILD_DIR}/enabled_apps.yaml

# Template out the statusInformers in the kots app
enabled_apps=$(yq eval '.spec.values | to_entries | map(select(.value.enabled == true)) | .[].key' ${BUILD_DIR}/enabled_apps.yaml)
for app in $enabled_apps; do
    yq eval ".spec.statusInformers += [\"deployment/${app}\"]" -i ${KOTS_APP}
done

# Merge our optional values into a single file
yq -i eval-all '
  (select(fi == 0) *+ select(fi == 1) *+ select(fi == 2))
  | .spec.optionalValues = (select(fi == 0).spec.optionalValues + select(fi == 1).spec.optionalValues + select(fi == 2).spec.optionalValues) 
' ${BUILD_DIR}/merged_values.yaml ${BUILD_DIR}/aws_values.yaml ${BUILD_DIR}/gcp_values.yaml

# Generate our release files
kustomize build ${REPO_DIR}/tmp_release/build/ -o ${KOTS_HELM}
cp ${BUILD_DIR}/config.yaml ${MANIFESTS_DIR}/config.yaml
cp ${BUILD_DIR}/kots_app.yaml ${MANIFESTS_DIR}/kots_app.yaml

# Update the chart name and version
yq -i ".metadata.name = \"${CHART_NAME}\"" ${KOTS_HELM}
yq -i ".spec.chart.name = \"${CHART_NAME}\"" ${KOTS_HELM}
yq -i ".spec.releaseName = \"${CHART_NAME}\"" ${KOTS_HELM}
yq -i ".spec.chart.chartVersion = \"${CHART_VERSION}\"" ${KOTS_HELM}
